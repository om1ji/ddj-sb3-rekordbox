// Отправляет сырые MIDI-байты на выход DDJ-SB3. Для экспериментов с подсветкой.
// Сборка: swiftc -O tools/midisend.swift -o tools/midisend
// Пример: tools/midisend "90 17 7F"   или   tools/midisend "F0 00 20 7F 03 01 F7"
import CoreMIDI
import Foundation

let bytes = CommandLine.arguments.dropFirst().joined(separator: " ")
    .split(separator: " ").compactMap { UInt8($0, radix: 16) }
guard !bytes.isEmpty else { print("укажи байты в hex"); exit(1) }

var client = MIDIClientRef()
MIDIClientCreateWithBlock("midisend" as CFString, &client, nil)
var port = MIDIPortRef()
MIDIOutputPortCreate(client, "out" as CFString, &port)

func displayName(_ obj: MIDIObjectRef) -> String {
    var cf: Unmanaged<CFString>?
    MIDIObjectGetStringProperty(obj, kMIDIPropertyDisplayName, &cf)
    return (cf?.takeRetainedValue() as String?) ?? ""
}

guard let dest = (0..<MIDIGetNumberOfDestinations()).map(MIDIGetDestination)
    .first(where: { displayName($0) == "DDJ-SB3" }) else { print("DDJ-SB3 не найден"); exit(1) }

// старый MIDIPacketList API: SysEx отправляется без ручной упаковки в UMP
var list = MIDIPacketList()
let pkt = MIDIPacketListInit(&list)
MIDIPacketListAdd(&list, MemoryLayout<MIDIPacketList>.size, pkt, 0, bytes.count, bytes)
MIDISend(port, dest, &list)
usleep(100_000)
print("отправлено:", bytes.map { String(format: "%02X", $0) }.joined(separator: " "))
