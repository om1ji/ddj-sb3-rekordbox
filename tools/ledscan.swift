// Поиск MIDI-ноты светодиода бинарным поиском.
// Зажигает группы нот на SB3 и спрашивает, горит ли нужный светодиод.
// Сборка: swiftc -O tools/ledscan.swift -o tools/ledscan
// Запуск: tools/ledscan        (в обычном окне Терминала: нужен ввод y/n)
import CoreMIDI
import Foundation

var client = MIDIClientRef()
MIDIClientCreateWithBlock("ledscan" as CFString, &client, nil)
var port = MIDIPortRef()
MIDIOutputPortCreate(client, "out" as CFString, &port)

func displayName(_ obj: MIDIObjectRef) -> String {
    var cf: Unmanaged<CFString>?
    MIDIObjectGetStringProperty(obj, kMIDIPropertyDisplayName, &cf)
    return (cf?.takeRetainedValue() as String?) ?? ""
}

guard let dest = (0..<MIDIGetNumberOfDestinations()).map(MIDIGetDestination)
    .first(where: { displayName($0) == "DDJ-SB3" }) else { print("DDJ-SB3 не найден"); exit(1) }

func send(_ bytes: [UInt8]) {
    var list = MIDIPacketList()
    let pkt = MIDIPacketListInit(&list)
    MIDIPacketListAdd(&list, MemoryLayout<MIDIPacketList>.size, pkt, 0, bytes.count, bytes)
    MIDISend(port, dest, &list)
    usleep(1500)  // не заваливаем контроллер
}

typealias Led = (status: UInt8, number: UInt8)

func set(_ leds: [Led], _ on: Bool) {
    for l in leds { send([l.status, l.number, on ? 0x7F : 0x00]) }
}

func ask(_ q: String) -> Bool {
    while true {
        print("\(q) [y/n]: ", terminator: "")
        fflush(stdout)
        guard let a = readLine()?.lowercased() else { exit(0) }
        if a.hasPrefix("y") || a.hasPrefix("д") { return true }
        if a.hasPrefix("n") || a.hasPrefix("н") { return false }
    }
}

func all(_ status: UInt8) -> [Led] { (0..<128).map { (status, UInt8($0)) } }

func lit(_ leds: [Led]) -> Bool {
    set(leds, true)
    defer { set(leds, false) }
    return ask("Горит ли VINYL на ЛЕВОЙ деке?")
}

print("Смотри только на кнопку VINYL левой деки. Остальные кнопки будут мигать, это нормально.\n")

// 1. Ищем канал и тип сообщения: ноты (9n) и CC (Bn) на каналах 1-16
var found: [Led]? = nil
outer: for kind: UInt8 in [0x90, 0xB0] {
    for ch: UInt8 in 0..<16 {
        let status = kind | ch
        print(String(format: "Проверяю %@ канал %d (%02X xx 7F)", kind == 0x90 ? "ноты" : "CC", ch + 1, status))
        if lit(all(status)) { found = all(status); break outer }
    }
}
guard var candidates = found else { print("Не нашлось ни на одном канале."); exit(1) }

// 2. Бинарный поиск внутри канала
while candidates.count > 1 {
    let half = Array(candidates.prefix(candidates.count / 2))
    candidates = lit(half) ? half : Array(candidates.suffix(candidates.count - half.count))
}
let led = candidates[0]
print(String(format: "\nНайдено: %02X %02X", led.status, led.number))
set([led], true)
if ask("Проверка: VINYL сейчас горит?") {
    print(String(format: "Готово. Светодиод VINYL: %02X %02X — пришли это Claude.", led.status, led.number))
}
set([led], false)
