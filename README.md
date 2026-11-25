**English** | [Русский](README.ru.md)

# DDJ-SB3 for rekordbox

A MIDI mapping and a small macOS bridge that let you play the Pioneer DJ DDJ-SB3, a Serato-only controller, in rekordbox 7, jog wheels included.

```
DDJ-SB3 (USB MIDI) ──► sb3bridge ──► virtual port "DDJ-SB2" ──► rekordbox
        ◄── LEDs ──────────┘ ◄──────────── LED feedback ◄──────────┘
```

rekordbox accepts a user MIDI mapping for any controller, but it silently ignores jog wheel rows (`JogRotate`, `JogTouch`) for devices that are not on its supported list. The DDJ-SB3 is not on that list, the DDJ-SB2 is, and both send the same jog codes. `sb3bridge` republishes the SB3 under the name `DDJ-SB2` and forwards everything in both directions, so rekordbox treats the jogs as real jogs.

Tested on macOS 26.2 with rekordbox 7.2.19, Apple Silicon, 25 November 2026.

## Contents

- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Everyday use](#everyday-use)
- [Controls](#controls)
- [How it works](#how-it-works)
- [Repository layout](#repository-layout)
- [Changing the mapping](#changing-the-mapping)
- [Debugging tools](#debugging-tools)
- [Troubleshooting](#troubleshooting)
- [Limitations](#limitations)

## Requirements

| What | Version | Why |
| --- | --- | --- |
| macOS | tested on 26.2 | the bridge uses CoreMIDI and CoreAudio |
| Xcode Command Line Tools | Swift 5.9 or newer (tested on 6.3) | builds the bridge and tools; install with `xcode-select --install` |
| rekordbox | 7 (tested on 7.2.19) | the mapping format and function names come from its bundled mappings |
| Python | 3.9 or newer | only to regenerate the CSV mappings |

No driver is needed: macOS sees the SB3 as a class-compliant USB audio device with 4 outputs (1–2 master, 3–4 headphones).

> [!NOTE]
> Whether MIDI mapping is available on the free rekordbox plan was not checked. If the MIDI button in rekordbox is greyed out, the plan is the reason.

## Quick start

1. Build everything:

   ```bash
   git clone https://github.com/om1ji/ddj-sb3-rekordbox.git
   cd ddj-sb3-rekordbox
   make
   make install    # optional: copies the bridge to /Applications/sb3bridge
   ```

2. Connect the SB3 and start the bridge. Keep its Terminal window open:

   ```bash
   adapter/sb3bridge
   ```

   It prints `DDJ-SB3 подключён` (connected) and `виртуальный порт «DDJ-SB2» готов` (virtual port ready).

3. Start rekordbox. In **Preferences → Audio** select `DDJ-SB3 Audio Out`, set Master output to channels 1 & 2 and Headphones output to 3 & 4.

4. Switch to **PERFORMANCE** mode, press **MIDI** in the top right corner, choose **DDJ-SB2** in the device list, press **IMPORT** and pick [`mappings/DDJ-SB2.midi.csv`](mappings/DDJ-SB2.midi.csv).

5. In the same MIDI window select **DDJ-SB3** and delete all of its assignments, if it has any. Otherwise every press reaches rekordbox twice, see [Troubleshooting](#troubleshooting).

## Everyday use

1. Connect the SB3.
2. Start `sb3bridge`, in one window only.
3. Start rekordbox.

The order matters: rekordbox only picks up MIDI ports that exist when it starts. If you restart the bridge, restart rekordbox too.

Stop the bridge with `Ctrl+C` or by closing its window.

## Controls

The SB3 switches pad modes itself: in each mode the pads send a different block of notes, so every mode maps to its own rekordbox function. Four Serato modes have no rekordbox equivalent and were assigned to the closest rekordbox mode.

| SB3 control | rekordbox |
| --- | --- |
| HOT CUE pads | Hot Cue 1–8, `SHIFT` + pad deletes |
| `SHIFT` + HOT CUE: BEAT JUMP | Beat Jump; `SHIFT` + pads 7/8 change the jump size |
| FX FADE | Pad FX 1 (`SHIFT` + pad: slots 9–16) |
| `SHIFT` + FX FADE: ROLL | Beat Loop |
| PAD SCRATCH | Pad FX 2 (`SHIFT` + pad: slots 9–16) |
| `SHIFT` + PAD SCRATCH: SLICER | Slicer |
| SAMPLER | Sampler, `SHIFT` + pad stops the slot |
| `SHIFT` + SAMPLER: TRANS | Key Shift; `SHIFT` + pads 7/8 change the range |
| Jog, top | Pitch bend; scratch when VINYL is on |
| Jog, side ring | Pitch bend |
| `SHIFT` + jog | Fast search |
| AUTO LOOP, 1/2X, 2X | 4-beat loop, halve, double; with `SHIFT`: Reloop/Exit, Loop In, Loop Out |
| VINYL / `SHIFT` + VINYL | Vinyl mode / Slip |
| KEY LOCK / `SHIFT` + KEY LOCK | Master Tempo / Tempo Range |
| SYNC / `SHIFT` + SYNC | Sync / Master |
| FILTER | Sound Color FX of the channel |
| FX buttons 1–3 | Beat FX slots on/off; with `SHIFT`: select effect |
| FX knob / `SHIFT` + FX knob | Slot 1 depth / beat |
| CUE (headphones) / `SHIFT` + CUE | Headphone cue of the channel / Tap BPM |
| MASTER (headphones) | Master into headphones, see below |
| `SHIFT` + MASTER | Resyncs the MASTER state, handled by the bridge only |
| `SHIFT` + LOAD | Sort by BPM / Artist |

## How it works

### Why a virtual "DDJ-SB2"

rekordbox reserves the jog wheels for controllers it supports natively. A mapping for the SB3 imports fine and every button works, but the jog rows do nothing. On the [Pioneer DJ community forum](https://community.pioneerdj.com/hc/en-us/community/posts/22979790097945-MIDI-Learn-Jog-wheel) the answer is that jogs of non-Pioneer controllers cannot be mapped; the SB3 is a Pioneer controller, but not one rekordbox supports.

The DDJ-SB2 is supported, and its jog messages match the SB3 byte for byte (`B0n 22`, `B0n 23`, `9n 36`, `B0n 21`). A virtual port with that name is enough for rekordbox to accept the jog data. The same mapping is then imported for the `DDJ-SB2` device.

This does not unlock any paid feature: rekordbox checks hardware unlock over USB, not by MIDI port name.

### Vinyl mode

The SB3 always sends jog rotation as `B0n 23` (pitch bend), whatever the VINYL button says. The DDJ-SB2 firmware switches to `B0n 22` (scratch) when the software lights its VINYL LED. The bridge does the same: it watches the VINYL LED message that rekordbox sends (`9n 17`) and, while it is on, rewrites `B0n 23` into `B0n 22` for that deck.

### MASTER in the headphones

The SB3 toggles the MASTER LED on its own, with every press, but it is rekordbox (`MasterCue`) that mixes the master into the headphone channels. The two states can end up one press apart, which looks like an inverted button. After every press rekordbox reports its state (`96 5B 7F` or `96 5B 00`); if it differs from the LED, the bridge sends rekordbox one more press. The bridge assumes the LED is off when it starts. `SHIFT` + MASTER flips that assumption, for the case when the bridge was started with MASTER already lit, and is not forwarded to rekordbox.

### Single instance

A second bridge would create a second `DDJ-SB2` port and rekordbox would receive every message twice. On start the bridge checks for an existing `DDJ-SB2` source and exits if there is one.

### Where the MIDI codes come from

The SB3 codes were taken from the open Mixxx mapping (`res/controllers/Pioneer-DDJ-SB3.midi.xml` in [mixxxdj/mixxx](https://github.com/mixxxdj/mixxx)), which follows Pioneer's official MIDI message list. Function names and the CSV format come from the mappings bundled with rekordbox 7 (`DDJ-SB2.midi.csv`, `DDJ-400.midi.csv`). The pad notes of FX FADE (`0x10`), PAD SCRATCH (`0x20`) and TRANS (`0x70`) were inferred from the LED layout and then confirmed on the hardware.

## Repository layout

| Path | What it is |
| --- | --- |
| [`gen_mapping.py`](gen_mapping.py) | generates both CSV mappings |
| [`mappings/DDJ-SB2.midi.csv`](mappings/DDJ-SB2.midi.csv) | mapping for use with the bridge (main one) |
| [`mappings/DDJ-SB3.midi.csv`](mappings/DDJ-SB3.midi.csv) | same mapping for a direct connection: everything but the jogs works |
| [`adapter/sb3bridge.swift`](adapter/sb3bridge.swift) | the bridge |
| [`tools/`](tools/) | MIDI and audio debugging tools |
| [`Makefile`](Makefile) | `make`, `make mappings`, `make install`, `make clean` |

## Changing the mapping

Edit [`gen_mapping.py`](gen_mapping.py) and regenerate:

```bash
make mappings
```

Then import `mappings/DDJ-SB2.midi.csv` again in the rekordbox MIDI window.

Each CSV row has 15 columns: rekordbox function, control label, type, input code, four deck columns, output code, four deck columns, options, comment. A deck column is a MIDI channel offset: `0`–`3` for decks, `7`–`10` for pads. Input `900B` with deck `1` means `91 0B` on the wire. The generator refuses commas inside fields, because rekordbox has no quoting and a comma shifts every column after it.

## Debugging tools

All tools talk to the device by name, so they work while rekordbox and the bridge are running.

```bash
tools/midimon 30 ddj                    # print every MIDI message from ports matching "ddj" for 30 s
tools/midisend "90 17 7F"               # send raw bytes to the DDJ-SB3
tools/ledscan                           # binary search for the note that lights an LED (asks y/n)
tools/tonetest "DDJ-SB3 Audio Out" 3 1  # 440 Hz for 3 s on outputs 1-2 (master)
tools/tonetest "DDJ-SB3 Audio Out" 3 2  # same on outputs 3-4 (headphones)
```

`midimon` shows both the SB3 and the bridge's `DDJ-SB2` port, which is how you tell whether a message was lost on the way or ignored by rekordbox. `adapter/sb3bridge -v` additionally logs what rekordbox sends back to the controller.

`tonetest` exists because `afplay` plays to the system default output, which is not necessarily the SB3, and `say -a '?'` does not list the SB3 at all.

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| Jogs do nothing, all buttons work | the bridge is not running, or rekordbox was started before it | start `sb3bridge`, then restart rekordbox |
| VINYL, CUE, KEY LOCK work every other time, flash on and off, or ignore presses | rekordbox gets each press twice: from the bridge and directly from the SB3 | in the MIDI window delete all assignments of `DDJ-SB3`; see below |
| The same, right after starting the bridge from a second window | two bridges, two `DDJ-SB2` ports | close one; the current version refuses to start twice |
| `порт «DDJ-SB2» уже есть: мост уже запущен в другом окне. Выход.` | the bridge is already running | use the running one |
| MASTER in the headphones works the other way round | the bridge started with MASTER already lit | press `SHIFT` + MASTER once |
| No sound, `AudioQueueStart failed ('what')` from `afplay` | rekordbox holds the device, or the default output is not the SB3 | test with `tools/tonetest` instead |
| Sound drops out, intermittent errors | the SB3 is bus powered; a chain of USB hubs is a likely cause | connect it directly or through a powered hub |

rekordbox keeps its own copy of user mappings and may recreate `~/Library/Application Support/Pioneer/rekordbox6/MidiMappings/DDJ-SB3.midi.csv` after you delete or rename it. That brings back the double input. A mapping without assignments is a one-line file, and this is what rekordbox writes for a device with nothing mapped:

```bash
# with rekordbox closed
printf '@file,1,DDJ-SB3\r\n' > ~/Library/Application\ Support/Pioneer/rekordbox6/MidiMappings/DDJ-SB3.midi.csv
```

## Limitations

- **macOS only.** The bridge relies on CoreMIDI virtual ports.
- **The bridge has to be started by hand**, before rekordbox. It can be installed as a LaunchAgent, but the repository does not do that for you.
- **Four pad modes differ from Serato.** FX FADE, PAD SCRATCH, ROLL and TRANS run rekordbox's closest modes. Muscle memory carries over, the result of a press does not.
- **The master level and headphone level knobs** (`B6 08`, `B6 0D`) are mapped to no function. Whether the SB3 applies them in hardware was not checked.
- **Intermittent noise in the headphones**, sounding like data transfer, was heard during testing and is not solved. USB power and ground loops are the usual suspects: try the battery instead of the charger, a direct USB connection, and pausing playback to see whether it follows the level meter LEDs.
- **rekordbox may change.** The jog restriction and the CSV format are undocumented behaviour of rekordbox 7.2.

This project is not affiliated with Pioneer DJ or AlphaTheta.
