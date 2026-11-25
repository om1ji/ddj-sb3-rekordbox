// Тестовый тон 440 Гц напрямую на аудиоустройство по имени, через CoreAudio IOProc
// (не через «выход по умолчанию»).
// Сборка: swiftc -O tools/tonetest.swift -o tools/tonetest
// Запуск: tools/tonetest ["DDJ-SB3 Audio Out"] [секунды] [пара каналов: 1 = 1-2, 2 = 3-4]
import CoreAudio
import Foundation

let args = CommandLine.arguments
let wanted = args.count > 1 ? args[1] : "DDJ-SB3 Audio Out"
let seconds = args.count > 2 ? Double(args[2]) ?? 2 : 2
let pair = args.count > 3 ? Int(args[3]) ?? 1 : 1

func address(_ sel: AudioObjectPropertySelector,
             _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: sel, mScope: scope, mElement: kAudioObjectPropertyElementMain)
}

func devices() -> [AudioDeviceID] {
    var addr = address(kAudioHardwarePropertyDevices)
    var size: UInt32 = 0
    AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size)
    var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
    AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids)
    return ids
}

func name(_ id: AudioDeviceID) -> String {
    var addr = address(kAudioObjectPropertyName)
    var cf: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &cf)
    return (cf?.takeRetainedValue() as String?) ?? "?"
}

let all = devices()
print("Устройства:", all.map(name).joined(separator: ", "))
guard let dev = all.first(where: { name($0) == wanted }) else {
    print("Не найдено: \(wanted)"); exit(1)
}

var rate: Float64 = 44100
var addr = address(kAudioDevicePropertyNominalSampleRate)
var size = UInt32(MemoryLayout<Float64>.size)
AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, &rate)

// Каналы 1..N сквозной нумерацией по всем выходным буферам устройства
let first = pair * 2 - 2
var phase = 0.0
let step = 2 * Double.pi * 440 / rate
var procID: AudioDeviceIOProcID?
let status = AudioDeviceCreateIOProcIDWithBlock(&procID, dev, nil) { _, _, _, outData, _ in
    let bufs = UnsafeMutableAudioBufferListPointer(outData)
    guard let b0 = bufs.first else { return }
    let frames = Int(b0.mDataByteSize) / (Int(max(b0.mNumberChannels, 1)) * MemoryLayout<Float32>.size)
    for f in 0..<frames {
        let v = Float32(sin(phase) * 0.3)
        phase += step
        var chBase = 0
        for b in bufs {
            let n = Int(b.mNumberChannels)
            let p = b.mData!.assumingMemoryBound(to: Float32.self)
            for c in 0..<n {
                let global = chBase + c
                p[f * n + c] = (global == first || global == first + 1) ? v : 0
            }
            chBase += n
        }
    }
}
guard status == noErr, let proc = procID else { print("не удалось создать IOProc: \(status)"); exit(1) }

print("Играю 440 Гц на \(wanted), каналы \(first + 1)-\(first + 2), \(Int(rate)) Гц, \(seconds) с")
let st = AudioDeviceStart(dev, proc)
guard st == noErr else { print("AudioDeviceStart ошибка: \(st) (устройство занято?)"); exit(1) }
Thread.sleep(forTimeInterval: seconds)
AudioDeviceStop(dev, proc)
AudioDeviceDestroyIOProcID(dev, proc)
print("готово")
