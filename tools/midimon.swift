// Мини-монитор CoreMIDI: печатает все MIDI-сообщения со всех входов.
// Слушает параллельно с rekordbox (CoreMIDI разрешает нескольких клиентов).
// Сборка: swiftc -O tools/midimon.swift -o tools/midimon
// Запуск: tools/midimon [секунды] [фильтр-по-имени-порта]
import CoreMIDI
import Foundation

let args = CommandLine.arguments
let seconds = args.count > 1 ? Double(args[1]) ?? 15 : 15
let filter = args.count > 2 ? args[2].lowercased() : ""

func name(_ obj: MIDIObjectRef) -> String {
    var cf: Unmanaged<CFString>?
    MIDIObjectGetStringProperty(obj, kMIDIPropertyDisplayName, &cf)
    return (cf?.takeRetainedValue() as String?) ?? "?"
}

var client = MIDIClientRef()
MIDIClientCreateWithBlock("midimon" as CFString, &client, nil)
var port = MIDIPortRef()
MIDIInputPortCreateWithProtocol(client, "in" as CFString, ._1_0, &port) { list, src in
    let tag = src.map { Unmanaged<NSString>.fromOpaque($0).takeUnretainedValue() as String } ?? ""
    for packet in list.unsafeSequence() {
        let words = packet.words()
        for w in words {
            let b1 = (w >> 16) & 0xFF, b2 = (w >> 8) & 0xFF, b3 = w & 0xFF
            print(String(format: "%@  %02X %02X %02X", tag, b1, b2, b3))
        }
    }
    fflush(stdout)
}

print("Источники MIDI:")
for i in 0..<MIDIGetNumberOfSources() {
    let src = MIDIGetSource(i)
    let n = name(src)
    print("  [\(i)] \(n)")
    if filter.isEmpty || n.lowercased().contains(filter) {
        let ref = Unmanaged.passRetained(n as NSString).toOpaque()
        MIDIPortConnectSource(port, src, ref)
    }
}
print("Слушаю \(Int(seconds)) с...")
fflush(stdout)
RunLoop.main.run(until: Date().addingTimeInterval(seconds))
