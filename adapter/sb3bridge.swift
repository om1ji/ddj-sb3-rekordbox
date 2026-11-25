// sb3bridge: мост DDJ-SB3 -> rekordbox через виртуальный MIDI-порт.
//
// Зачем: rekordbox игнорирует строки джогов (JogRotate/JogTouch) у устройств,
// которых нет в его списке поддерживаемых контроллеров. SB3 в нём нет, SB2 есть,
// а джоги у них шлют одинаковые коды. Мост публикует виртуальный порт с
// именем DDJ-SB2 и пересылает в него всё, что шлёт SB3, в обе стороны.
//
// Дополнительно: SB3 всегда шлёт вращение джога как B0n 23 (pitch bend).
// Когда rekordbox зажигает VINYL на деке (9n 17 7F), мост переписывает
// вращение в B0n 22 (scratch), как это делает прошивка SB2.
//
// Сборка: swiftc -O adapter/sb3bridge.swift -o adapter/sb3bridge
// Запуск: adapter/sb3bridge [-v]
import CoreMIDI
import Foundation

let hardwareName = "DDJ-SB3"
let virtualName = "DDJ-SB2"
let verbose = CommandLine.arguments.contains("-v")

func log(_ s: String) {
    let t = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    // пишем напрямую в дескриптор: без буферизации stdio, лог виден сразу
    FileHandle.standardOutput.write("[\(t)] \(s)\n".data(using: .utf8)!)
}

func check(_ status: OSStatus, _ what: String) {
    if status != noErr {
        log("ошибка \(what): \(status)")
        exit(1)
    }
}

func displayName(_ obj: MIDIObjectRef) -> String {
    var cf: Unmanaged<CFString>?
    MIDIObjectGetStringProperty(obj, kMIDIPropertyDisplayName, &cf)
    return (cf?.takeRetainedValue() as String?) ?? ""
}

func findEndpoint(_ count: Int, _ get: (Int) -> MIDIEndpointRef) -> MIDIEndpointRef? {
    for i in 0..<count {
        let e = get(i)
        if displayName(e) == hardwareName { return e }
    }
    return nil
}

// Состояние VINYL по декам 1-4 (каналы 0-3), ведёт rekordbox через подсветку.
var vinyl = [Bool](repeating: false, count: 4)
let lock = NSLock()

/// Копирует event list, пропуская каждое MIDI 1.0 слово через transform.
func rewrite(_ list: UnsafePointer<MIDIEventList>, _ transform: (UInt32) -> UInt32) -> [UInt32] {
    var out: [UInt32] = []
    for packet in list.unsafeSequence() {
        let words = Array(packet.words())
        var i = 0
        while i < words.count {
            let w = words[i]
            let type = w >> 28
            // размер UMP-пакета в словах по типу сообщения
            let size: Int = switch type {
            case 0x0, 0x1, 0x2, 0x6, 0x7: 1
            case 0x3, 0x4, 0x8, 0x9, 0xA: 2
            case 0xB, 0xC: 3
            default: 4
            }
            if type == 0x2 {
                out.append(transform(w))
            } else {
                out.append(contentsOf: words[i..<min(i + size, words.count)])
            }
            i += size
        }
    }
    return out
}

func send(_ words: [UInt32], _ sink: (UnsafePointer<MIDIEventList>) -> Void) {
    guard !words.isEmpty else { return }
    let bufSize = 64 + words.count * 4 * 2
    let raw = UnsafeMutableRawPointer.allocate(byteCount: bufSize, alignment: 8)
    defer { raw.deallocate() }
    let list = raw.bindMemory(to: MIDIEventList.self, capacity: 1)
    var pkt = MIDIEventListInit(list, ._1_0)
    // группируем по одному UMP-сообщению; время 0 = отправить сразу
    var i = 0
    while i < words.count {
        let type = words[i] >> 28
        let size: Int = switch type {
        case 0x0, 0x1, 0x2, 0x6, 0x7: 1
        case 0x3, 0x4, 0x8, 0x9, 0xA: 2
        case 0xB, 0xC: 3
        default: 4
        }
        let chunk = Array(words[i..<min(i + size, words.count)])
        pkt = chunk.withUnsafeBufferPointer {
            MIDIEventListAdd(list, bufSize, pkt, 0, chunk.count, $0.baseAddress!)
        }
        i += size
    }
    sink(UnsafePointer(list))
}

func hex(_ w: UInt32) -> String {
    String(format: "%02X %02X %02X", (w >> 16) & 0xFF, (w >> 8) & 0xFF, w & 0xFF)
}

// ---------------------------------------------------------------- setup
var client = MIDIClientRef()
check(MIDIClientCreateWithBlock("sb3bridge" as CFString, &client, nil), "MIDIClientCreate")

// Второй экземпляр создал бы второй порт DDJ-SB2: rekordbox получал бы каждое
// нажатие дважды (VINYL включается и сразу выключается).
if (0..<MIDIGetNumberOfSources()).contains(where: { displayName(MIDIGetSource($0)) == virtualName }) {
    log("порт «\(virtualName)» уже есть: мост уже запущен в другом окне. Выход.")
    exit(1)
}

var virtualSource = MIDIEndpointRef()
check(MIDISourceCreateWithProtocol(client, virtualName as CFString, ._1_0, &virtualSource),
      "создания виртуального источника")

var hwSource: MIDIEndpointRef? = nil
var hwDest: MIDIEndpointRef? = nil

// MASTER у наушников (96 5B): светодиод контроллер переключает сам, а мастер в
// наушники подмешивает rekordbox (MasterCue). Если их состояния разошлись, мост
// досылает rekordbox лишнее нажатие, чтобы rekordbox совпадал со светодиодом.
// SHIFT + MASTER (96 78) меняет предполагаемое состояние светодиода на обратное:
// на случай, если мост запустили, когда MASTER уже горел.
var masterLed = false  // после включения питания SB3 светодиод MASTER не горит
var lastMasterSync = Date.distantPast

func pressMasterInRekordbox() {
    // 0x2 = MIDI 1.0 channel voice, группа 0
    let words: [UInt32] = [0x2096_5B7F, 0x2096_5B00]
    send(words) { MIDIReceivedEventList(virtualSource, $0) }
}

// SB3 -> rekordbox
var inPort = MIDIPortRef()
check(MIDIInputPortCreateWithProtocol(client, "from-sb3" as CFString, ._1_0, &inPort) { list, _ in
    var resync = false
    let all = rewrite(list) { w in
        let status = (w >> 16) & 0xFF
        let d1 = (w >> 8) & 0xFF
        let ch = Int(status & 0x0F)
        if status == 0x96, (d1 == 0x5B || d1 == 0x78), (w & 0xFF) > 0 {
            lock.lock(); masterLed.toggle(); let led = masterLed; lock.unlock()
            if d1 == 0x78 {
                resync = true
                log("SHIFT + MASTER: считаю, что светодиод MASTER \(led ? "горит" : "не горит")")
            }
        }
        // B0-B3 23 -> 22, если на деке включён VINYL
        if status & 0xF0 == 0xB0, ch < 4, d1 == 0x23 {
            lock.lock(); let on = vinyl[ch]; lock.unlock()
            if on { return (w & 0xFFFF00FF) | (0x22 << 8) }
        }
        return w
    }
    // SHIFT + MASTER нужен только мосту: в rekordbox его не пускаем
    let words = all.filter { !($0 >> 28 == 2 && ($0 >> 8) & 0xFFFF == 0x9678) }
    if verbose { words.filter { $0 >> 28 == 2 }.forEach { log("SB3 -> rb  \(hex($0))") } }
    send(words) { MIDIReceivedEventList(virtualSource, $0) }
    if resync { pressMasterInRekordbox() }
}, "создания входного порта")

// rekordbox -> SB3 (подсветка)
var outPort = MIDIPortRef()
check(MIDIOutputPortCreate(client, "to-sb3" as CFString, &outPort), "создания выходного порта")

var virtualDest = MIDIEndpointRef()
check(MIDIDestinationCreateWithProtocol(client, virtualName as CFString, ._1_0, &virtualDest) { list, _ in
    let words = rewrite(list) { w in
        let status = (w >> 16) & 0xFF
        let d1 = (w >> 8) & 0xFF
        let ch = Int(status & 0x0F)
        // rekordbox сообщает состояние VINYL подсветкой кнопки 9n 17
        if status & 0xF0 == 0x90, ch < 4, d1 == 0x17 {
            let on = (w & 0xFF) > 0
            lock.lock(); let changed = vinyl[ch] != on; vinyl[ch] = on; lock.unlock()
            if changed { log("дека \(ch + 1): VINYL \(on ? "вкл, джог = scratch" : "выкл, джог = pitch bend")") }
        }
        // rekordbox сообщает состояние MasterCue: выравниваем по светодиоду
        if status == 0x96, d1 == 0x5B {
            let rbOn = (w & 0xFF) > 0
            lock.lock()
            let mismatch = rbOn != masterLed
            // не чаще раза в 300 мс: защита от зацикливания
            let allowed = Date().timeIntervalSince(lastMasterSync) > 0.3
            if mismatch && allowed { lastMasterSync = Date() }
            lock.unlock()
            if mismatch && allowed {
                log("MASTER: rekordbox \(rbOn ? "вкл" : "выкл"), светодиод \(rbOn ? "не горит" : "горит"), выравниваю")
                pressMasterInRekordbox()
            }
        }
        return w
    }
    if verbose { words.filter { $0 >> 28 == 2 }.forEach { log("rb -> SB3  \(hex($0))") } }
    if let dest = hwDest { send(words) { MIDISendEventList(outPort, dest, $0) } }
}, "создания виртуального приёмника")

func connectHardware() {
    let src = findEndpoint(MIDIGetNumberOfSources(), MIDIGetSource)
    let dst = findEndpoint(MIDIGetNumberOfDestinations(), MIDIGetDestination)
    if src != hwSource {
        if let old = hwSource { MIDIPortDisconnectSource(inPort, old) }
        hwSource = src
        if let s = src {
            MIDIPortConnectSource(inPort, s, nil)
            log("\(hardwareName) подключён")
        } else {
            log("жду \(hardwareName)...")
        }
    }
    hwDest = dst
}

connectHardware()
// переподключение при выдёргивании и втыкании кабеля
let timer = Timer(timeInterval: 2, repeats: true) { _ in connectHardware() }
RunLoop.main.add(timer, forMode: .common)

log("виртуальный порт «\(virtualName)» готов. Ctrl+C для выхода.")
signal(SIGINT) { _ in exit(0) }
RunLoop.main.run()
