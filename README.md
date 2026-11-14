# TB Drum Machine (Mountain Lion)

A stand-alone drum machine app for **Mac OS X 10.8.5 Mountain Lion** (64-bit Intel), with three
sampled kits: **707**, **CR-78** and **LM-1**. The pages follow the DM2 drum machine app
(PADS, STEPS, MIXER, SONG). The pads are laid out like the Roland TR-707. The panel is
an original design in the TB style, with the TB electronic logo. For personal use; the
modern Mac version lives in `TB-Drum-Machine-2026-MAC`.

## Install

1. Actions → latest successful run → Artifacts → **TB-Drum-Machine-mountain-lion-app** → download.
2. Unzip it twice, then drag **TB Drum Machine.app** into **Applications**.
3. First launch: right-click the app → **Open** → **Open** (it isn't signed by Apple).
4. **Kits ▸ Show Kits Folder** opens
   `~/Library/Application Support/TB/TB Drum Machine/Kits`. Drag the three sample
   folders in (**TB 707**, **TB CR78**, **TB LM1**, as supplied), then choose **Kits ▸ Reload Kits**.
   The readout shows how many samples each kit loaded (707 23, CR-78 7, LM-1 11 with Tom 4).
   A `Kits` folder next to the app works too.

The samples aren't in this public repo; the app reads them from the Kits folder.

## The pads (TR-707 layout, plus a second mid tom)

| Pad | 707 | CR-78 | LM-1 |
|---|---|---|---|
| Kick | BD A / BD B | Kick | Kick |
| Snare | SD A / SD B (SD B has Flam A/B) | Snare | Snare 01 / Snare 02 |
| Low Tom | Tom Lo (+ flams) | **Conga** | Tom 3 |
| Mid Tom (1) | Tom Mid (+ flams) | – | Mid Tom 1: Tom 2 |
| Mid Tom 2 | – | – | Mid Tom 2: Tom 4 |
| Hi Tom | Tom Hi (+ flams) | **Bongo** | Tom 1 |
| Rim / Cow | Rimshot / Cowbell | – | – |
| Clap / Tamb | Clap / Tambourine | **Cabassa** | – |
| Hi-Hat | Closed / Open | Closed / Open | Closed / Open |
| Crash | Crash | – | Crash |
| Ride | Ride | – | Ride |

The two sounds on a pad share one voice, as on the 707, so the closed hat chokes the open hat.
Pad names come from the loaded kit. A kit can be chosen for each pattern.

## Pages

- **PADS**: eleven pads. A two-sound pad is split down the middle, left = A and right = B.
  NORMAL / FLAM A / FLAM B buttons appear under pads that have flam samples.
  Option-click plays the hit accented. With **REC** on while playing, hits go into the
  pattern on the nearest step.
- **STEPS**: an Accent row plus the eleven pads, up to 32 steps.
  - The **A / B** switch on a row picks the sound that new steps get.
  - Each row has its own **length**, so tracks can run against each other (polymetric).
  - The red line marks the **pattern length** (LENGTH ◀ ▶), where the song moves on.
  - **M / S** mute and solo the row.
  - Click mode: **STEP** turns steps on and off (drag to paint). **A / B** swaps a step's
    sound. **FLAM** cycles normal → Flam A → Flam B. **HITS** splits a step into 1–4 hits.
- **MIXER**: TUNE (±12 semitones), DECAY (shortens the sample; 10 = full), PAN, LEVEL fader,
  MUTE and SOLO for every pad.
- **SONG**: up to 64 steps, each a pattern played 1–16 times. Use **SONG MODE ON** to play it,
  and **PLAY FROM HERE** to start partway through.

Top bar: PLAY/STOP (space bar), REC (R key), TEMPO 30–300 BPM, SWING (50–75%, delays the
odd 16ths), ACCENT amount, MASTER, SYNC **INT / MIDI**, and KIT.

The strip holds the 16 **pattern** keys: lime = the pattern playing, charcoal = has steps,
blinking = next. Picking a pattern while playing waits for the end of the bar, like the 707.
**NAME** names a pattern; so does clicking the readout. Type up to 40 characters and press
Return, or Esc to keep the old name. **COPY / PASTE / CLEAR** work on the current pattern;
CLEAR needs a second click.

Knobs: drag up and down (hold Shift for fine changes), double-click to reset, or use the scroll wheel.

## Sync, MIDI in, exports

- **SYNC MIDI** follows MIDI clock plus Start / Stop / Continue from Pro Tools, Reaper or anything
  else on any MIDI input. The tempo box shows the incoming tempo.
- **MIDI notes in** (any channel) play the pads, using General MIDI drum notes: 36/35 kick,
  38/40 snare, 45/47/48/50 toms, 37 rim, 56 cowbell, 39 clap, 54 tamb, 42/46 hats, 49 crash, 51 ride
  (CR-78 conga 64, bongo 60, cabassa 69). Velocity 112 and up counts as accented.
- **EXPORT WAV**: the song once through, or the current pattern 1–32 times, rendered
  offline as 24-bit stereo (44.1 or 48 kHz, following the audio device), with the last hits'
  tail.
- **EXPORT MIDI**: the same choice as a Standard MIDI File (type 0, 96 PPQN, channel 10,
  GM drum notes). Accents are velocity 127, other hits 100, and the tempo is included.
  Flams export as one note.

## Sessions

Everything (patterns, names, song, mixer, tempo, page) is saved automatically to
`~/Library/Application Support/TB/TB Drum Machine/Session.txt`, so the app reopens where it was
left. **File ▸ Save Session As / Open Session** keep extra sessions as `.tbdm` files.

## Build

GitHub Actions builds on `macos-15-intel` with `-mmacosx-version-min=10.8.5`. The build fails
unless the binary declares 10.8.5 and links only system frameworks that exist on 10.8.5
(Cocoa, AudioUnit, AudioToolbox, CoreAudio, CoreMIDI). The engine is plain C++98 and is tested
on Linux (`make -C Tests run`, also under AddressSanitizer). The app's `--selftest` mode
drives the panel offscreen and publishes screenshots to the `gui-preview` branch. GitHub has
no 10.8 machines, so the first launch on the Mac Pro is the real test.
