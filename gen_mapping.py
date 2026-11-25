#!/usr/bin/env python3
"""Генерирует маппинг rekordbox (MIDI LEARN CSV) для Pioneer DDJ-SB3.

Источники:
  * MIDI-коды SB3: маппинг Mixxx (res/controllers/Pioneer-DDJ-SB3.midi.xml),
    составленный по официальной таблице Pioneer «DDJ-SB3 List of MIDI messages».
  * Формат CSV и имена функций rekordbox: встроенные маппинги rekordbox 7
    (DDJ-SB2.midi.csv, DDJ-400.midi.csv) из rekordbox.app/Contents/Resources/MidiMappings.

Формат строки (15 колонок):
  name(функция rekordbox), function(контрол), type, input, deck1..deck4,
  output, deck1..deck4, option, comment
Колонки deck1..deck4: смещение MIDI-канала для каждой деки (0..3 для дек,
7..10 для пэдов). input "900B" + deck 1 -> на проводе 0x91 0x0B.
"""

import os

DECKS = ["0", "1", "2", "3"]  # каналы 1-4: деки 1-4
PADS = ["7", "8", "9", "10"]  # каналы 8-11: пэды дек 1-4
NONE = ["", "", "", ""]

rows: list[list[str]] = []


def row(
    name,
    control,
    typ,
    inp="",
    in_decks=NONE,
    out="",
    out_decks=NONE,
    option="",
    comment="",
):
    r = [name, control, typ, inp, *in_decks, out, *out_decks, option, comment]
    assert not any("," in x for x in r), f"запятая сломает CSV: {r}"
    rows.append(r)


def section(title):
    rows.append([""] * 15)
    rows.append([f"# {title}"] + [""] * 14)


def deck_btn(name, control, code, option="", comment="", led=True):
    """Кнопка деки: вход и (опционально) подсветка на том же коде."""
    row(
        name,
        control,
        "Button",
        code,
        DECKS,
        code if led else "",
        DECKS if led else NONE,
        option,
        comment,
    )


# ---------------------------------------------------------------- Browser
section("Browser")
row("Browse", "Browse", "Rotary", "B640", comment="Browse (Track/Folder Select)")
row("Zoom", "Browse+Shift", "Rotary", "B664", comment="Waveform zoom")
row(
    "Forward", "Browse+Press", "Button", "9641", comment="Library Forward (Folder Open)"
)
row(
    "Back",
    "Browse+Press+Shift",
    "Button",
    "9642",
    comment="Library Back (Folder Close)",
)
row(
    "Load",
    "Load",
    "Button",
    "",
    ["9646", "9647", "9648", "9649"],
    comment="Load to Deck / Instant Double (double click)",
)
row("SortBPM", "Load1+Shift", "Button", "9658", comment="Sort by BPM")
row("SortARTIST", "Load2+Shift", "Button", "9659", comment="Sort by ARTIST")
row("SortBPM", "Load3+Shift", "Button", "9660", comment="Sort by BPM")
row("SortARTIST", "Load4+Shift", "Button", "9661", comment="Sort by ARTIST")

# ---------------------------------------------------------------- Deck
section("Deck")
deck_btn("PlayPause", "PlayPause", "900B", "Fast;Priority=50", "Play/Pause")
deck_btn("PlayPause", "PlayPause+Shift", "9047", "Fast;Priority=50", "Play/Pause")
deck_btn("Cue", "Cue", "900C", "Fast;Priority=50", "Cue Set/Play Cue Back")
deck_btn(
    "JumpToTrackStart", "Cue+Shift", "9048", "Fast;Priority=50", "Jump to track start"
)
rows.append([""] * 15)
row(
    "JogScratch",
    "JogScratch",
    "JogRotate",
    "B022",
    DECKS,
    option="RO",
    comment="Scratch (Vinyl on)",
)
row(
    "JogPitchBend",
    "JogPitchBend",
    "JogRotate",
    "B023",
    DECKS,
    option="RO",
    comment="Pitch Bend (Vinyl off)",
)
row(
    "JogSearch",
    "JogSearch",
    "Difference",
    "B01F",
    DECKS,
    option="RO",
    comment="Search (Shift + jog)",
)
row(
    "JogTouch",
    "JogTouch",
    "JogTouch",
    "9036",
    DECKS,
    option="RO",
    comment="Touch (Vinyl on)",
)
row(
    "JogTouch",
    "JogTouch",
    "JogTouch",
    "9035",
    DECKS,
    option="RO",
    comment="Touch (Vinyl off)",
)
row(
    "JogTouch",
    "JogTouch+Shift",
    "JogTouch",
    "9067",
    DECKS,
    option="RO",
    comment="Touch (Shift)",
)
row(
    "WheelPitchBend",
    "WheelPitchBend",
    "JogRotate",
    "B021",
    DECKS,
    option="RO",
    comment="Jog side: Pitch Bend",
)
row(
    "WheelSearch",
    "WheelSearch",
    "JogRotate",
    "B026",
    DECKS,
    option="RO",
    comment="Jog side + Shift: Search",
)
rows.append([""] * 15)
row(
    "TempoSlider",
    "TempoSlider",
    "KnobSliderHiRes",
    "B000",
    DECKS,
    option="Fast",
    comment="Tempo Control",
)
row(
    "TempoSlider",
    "TempoSlider+Shift",
    "KnobSliderHiRes",
    "B005",
    DECKS,
    option="Fast",
    comment="Tempo Control",
)
deck_btn("MasterTempo", "KeyLock", "901A", comment="Master Tempo (Key Lock) On/Off")
deck_btn("TempoRange", "KeyLock+Shift", "9060", comment="Tempo Range")
deck_btn("Sync", "Sync", "9058", "Blink=600", "Sync On/Off")
deck_btn("Master", "Sync+Shift", "905C", comment="Master On/Off")
deck_btn("Vinyl", "Vinyl", "9017", comment="Vinyl Mode On/Off (for JOG)")
deck_btn("Slip", "Vinyl+Shift", "9040", comment="SLIP mode On/Off")
row("Shift", "Shift", "Button", "903F", DECKS, option="RO", comment="Shift")
row(
    "DeckState",
    "DeckState",
    "Button",
    "9072",
    DECKS,
    option="RO",
    comment="Deck 1/3 and 2/4 select",
)

# ---------------------------------------------------------------- Loop
section("Loop")
deck_btn("4BeatLoop", "AutoLoop", "9014", "Fast", "Auto Loop (4 beat) On/Off")
deck_btn("ReloopExit", "AutoLoop+Shift", "9050", "Fast", "Reloop/Exit")
deck_btn("LoopHalf", "LoopHalf", "9012", "Fast", "Loop 1/2X")
deck_btn("LoopIn", "LoopHalf+Shift", "9061", "Fast", "Loop In")
deck_btn("LoopDouble", "LoopDouble", "9013", "Fast", "Loop 2X")
deck_btn("LoopOut", "LoopDouble+Shift", "9062", "Fast", "Loop Out")

# ---------------------------------------------------------------- Mixer
section("Mixer")
row(
    "CrossFader",
    "CrossFader",
    "KnobSliderHiRes",
    "B61F",
    option="Fast",
    comment="Crossfader",
)
row(
    "ChannelFader", "ChannelFader", "KnobSliderHiRes", "B013", DECKS, comment="CH Fader"
)
row("Gain", "Gain", "KnobSliderHiRes", "B004", DECKS, option="Fast", comment="Trim")
row(
    "EQHigh",
    "EQHigh",
    "KnobSliderHiRes",
    "B007",
    DECKS,
    option="Fast",
    comment="EQ High",
)
row("EQMid", "EQMid", "KnobSliderHiRes", "B00B", DECKS, option="Fast", comment="EQ Mid")
row("EQLow", "EQLow", "KnobSliderHiRes", "B00F", DECKS, option="Fast", comment="EQ Low")
deck_btn("HeadphoneCue", "HeadphoneCue", "9054", comment="Headphone CUE On/Off")
deck_btn("TapBpm", "HeadphoneCue+Shift", "9068", comment="TAP BPM")
row("MasterCue", "MasterCue", "Button", "965B", out="965B", comment="Master CUE")
row(
    "PanelForward",
    "MasterCue+Shift",
    "Button",
    "9678",
    comment="Toggles through panels",
)
for ch, code in zip("1234", ["B617", "B618", "B619", "B61A"]):
    row(
        f"CFXParameterCH{ch}",
        f"FilterCH{ch}",
        "KnobSliderHiRes",
        code,
        option="Fast",
        comment=f"CH{ch} Filter (Sound Color FX)",
    )
row(
    "MasterLevel",
    "",
    "KnobSliderHiRes",
    "B608",
    comment="Hardware master level (no function)",
)
row(
    "HeadphonesVolume",
    "",
    "KnobSliderHiRes",
    "B60D",
    comment="Hardware headphones level (no function)",
)
row(
    "ChannelLevel",
    "ChannelLevel",
    "Indicator",
    out="B002",
    out_decks=DECKS,
    option="RO;Priority=50",
    comment="CH Level Indicator",
)

# ---------------------------------------------------------------- Beat FX
section("Effect")
for unit in ("1", "2"):
    hi = "4" if unit == "1" else "5"
    row(
        f"FX{unit}-1",
        f"FX{unit}Knob",
        "KnobSliderHiRes",
        f"B{hi}06",
        comment=f"FX{unit} knob: slot 1 depth",
    )
    row(
        f"FX{unit}BeatUpDown",
        f"FX{unit}Knob+Shift",
        "KnobSliderHiRes",
        f"B{hi}12",
        comment=f"FX{unit} beat down/up",
    )
    for slot, (on, sel) in enumerate(
        (("47", "63"), ("48", "64"), ("49", "65")), start=1
    ):
        row(
            f"FX{unit}-{slot}On",
            f"FX{unit}-{slot}",
            "Button",
            f"9{hi}{on}",
            out=f"9{hi}{on}",
            comment=f"FX{unit}-{slot} On/Off",
        )
        row(
            f"FX{unit}-{slot}Select",
            f"FX{unit}-{slot}+Shift",
            "Button",
            f"9{hi}{sel}",
            comment=f"FX{unit}-{slot} select",
        )

# ---------------------------------------------------------------- Pad modes
# Режим пэдов SB3 переключает сам: пэды шлют разные ноты в зависимости от режима.
#   HOT CUE      0x00-0x07 (+Shift 0x08-0x0F)
#   FX FADE      0x10-0x17 (+Shift 0x18-0x1F)  -> rekordbox PAD FX 1
#   PAD SCRATCH  0x20-0x27 (+Shift 0x28-0x2F)  -> rekordbox PAD FX 2
#   SAMPLER      0x30-0x37 (+Shift 0x38-0x3F)
#   BEAT JUMP    0x40-0x47 (+Shift 0x48-0x4F)  (Shift + HOT CUE)
#   ROLL         0x50-0x57                     -> rekordbox BEAT LOOP (Shift + FX FADE)
#   SLICER       0x60-0x67                     (Shift + PAD SCRATCH)
#   TRANS        0x70-0x77 (+Shift 0x78-0x7F)  -> rekordbox KEY SHIFT (Shift + SAMPLER)
section("Pad mode buttons")
deck_btn("HotCue", "HotCueMode", "901B", "Fast", "HOT CUE Mode")
deck_btn("BeatJump", "HotCueMode+Shift", "9069", "Fast", "BEAT JUMP Mode")
deck_btn("PadFx1", "FxFadeMode", "901E", "Fast", "PAD FX1 Mode (SB3: FX FADE)")
deck_btn("BeatLoop", "FxFadeMode+Shift", "906B", "Fast", "BEAT LOOP Mode (SB3: ROLL)")
deck_btn("PadFx2", "PadScratchMode", "9020", "Fast", "PAD FX2 Mode (SB3: PAD SCRATCH)")
deck_btn("Slicer", "PadScratchMode+Shift", "906D", "Fast", "SLICER Mode")
deck_btn("Sampler", "SamplerMode", "9022", "Fast", "SAMPLER Mode")
deck_btn("KeyShift", "SamplerMode+Shift", "906E", "Fast", "KEY SHIFT Mode (SB3: TRANS)")


def pad(name, control, note, comment=""):
    code = f"90{note:02X}"
    row(name, control, "Pad", code, PADS, code, PADS, "Fast", comment)


section("Performance pads")
for i in range(8):
    n = i + 1
    pad(f"PAD{n}_HotCue", f"PAD{n}.HotCue", 0x00 + i, f"HOT CUE {n}")
    pad(f"PAD{n}_HotCue+Shift", f"PAD{n}.HotCue+Shift", 0x08 + i, f"Delete HOT CUE {n}")
    pad(f"PAD{n}_PadFx1", f"PAD{n}.FxFade", 0x10 + i, f"PAD FX1 slot {n} (momentary)")
    pad(
        f"PAD{n + 8}_PadFx1",
        f"PAD{n}.FxFade+Shift",
        0x18 + i,
        f"PAD FX1 slot {n + 8} (momentary)",
    )
    pad(
        f"PAD{n}_PadFx2",
        f"PAD{n}.PadScratch",
        0x20 + i,
        f"PAD FX2 slot {n} (momentary)",
    )
    pad(
        f"PAD{n + 8}_PadFx2",
        f"PAD{n}.PadScratch+Shift",
        0x28 + i,
        f"PAD FX2 slot {n + 8} (momentary)",
    )
    pad(f"PAD{n}_Sampler", f"PAD{n}.Sampler", 0x30 + i, f"Sample slot {n} play")
    pad(
        f"PAD{n}_Sampler+Shift",
        f"PAD{n}.Sampler+Shift",
        0x38 + i,
        f"Sample slot {n} stop",
    )
    pad(f"PAD{n}_BeatJump", f"PAD{n}.BeatJump", 0x40 + i, "BEAT JUMP")
    pad(f"PAD{n}_BeatLoop", f"PAD{n}.Roll", 0x50 + i, "BEAT LOOP")
    pad(f"PAD{n}_Slicer", f"PAD{n}.Slicer", 0x60 + i, f"SLICER {n}")
    pad(f"PAD{n}_KeyShift", f"PAD{n}.Trans", 0x70 + i, "KEY SHIFT")
    rows.append([""] * 15)

# Shift + пэды 7/8 в BEAT JUMP и KEY SHIFT меняют параметр (как на DDJ-400)
pad("Parameter2Left_BeatJump", "PAD7.BeatJump+Shift", 0x4E, "Beat jump range down")
pad("Parameter2Right_BeatJump", "PAD8.BeatJump+Shift", 0x4F, "Beat jump range up")
pad("Parameter1Left_KeyShift", "PAD7.Trans+Shift", 0x7E, "Key shift range down")
pad("Parameter1Right_KeyShift", "PAD8.Trans+Shift", 0x7F, "Key shift range up")

# ---------------------------------------------------------------- Parameters
section("Parameter")
row("JogRatency", "JogRatency", "Parameter", "FFF2", option="Value=4", comment="unused")
row("MidiOutInterval", "MidiOutInterval", "Parameter", "FFF3", option="Value=2")

HEADER = [
    "#name,function,type,input,deck1,deck2,deck3,deck4,output,deck1,deck2,deck3,deck4,option,comment",
]

if __name__ == "__main__":
    # DDJ-SB3: прямое подключение (джоги rekordbox игнорирует).
    # DDJ-SB2: для работы через мост adapter/sb3bridge (джоги работают).
    here = os.path.dirname(os.path.abspath(__file__))
    for device in ("DDJ-SB3", "DDJ-SB2"):
        out = os.path.join(here, "mappings", f"{device}.midi.csv")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, "w", encoding="utf-8", newline="") as f:
            # rekordbox пишет свои CSV с CRLF
            lines = [f"@file,1,{device}", *HEADER] + [",".join(r) for r in rows]
            f.write("\r\n".join(lines) + "\r\n")
        n = sum(1 for r in rows if r[0] and not r[0].startswith("#"))
        print(f"{out}: {n} mappings")
