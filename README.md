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
   The readout shows how many samples each kit loaded (707 23, CR-78 7, LM-1 11).
   A `Kits` folder next to the app works too.

The samples aren't in this public repo; the app reads them from the Kits folder.

## The pads (TR-707 layout, plus a second mid tom)

| Pad | 707 | CR-78 | LM-1 |
|---|---|---|---|
| Kick | BD A / BD B | Kick | Kick |
| Snare | SD A / SD B (SD B has Flam A/B) | Snare | Snare 01 / Snare 02 |
| Low Tom | Tom Lo (+ flams) | **Conga** | Tom 3 |
| Mid Tom (1) | Tom Mid (+ flams) | – | Mid Tom 1 (the added sample) |
| Mid Tom 2 | – | – | Tom 2 |
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
  - **TIME** drop-down: 4/4 (16 steps), 3/4 (12), 6/4 (24), 6/8 (12, grouped in 6s) or 12/8 (24, grouped
    in 6s). It sets the pattern and every track to that bar and lights only those steps. Tempo stays
    in quarter-note BPM, and exported MIDI files carry the time signature.
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

## M-50 Master sidecar

A second mahogany-framed unit bolted on the right, in the TB M50 Dual Channel Strip's look and
sound, on the drum machine's stereo output:
- **MASTER drives the M-50**: the drum machine's MASTER knob is the drive into the sidecar's M-50
  preamp, like the strip's TRIM on LINE: -15 to +25 dB, with 0 dB at 3.75. Pushed up, the preamp's
  op-amps round the peaks, with the same slightly lopsided character as the Dual Channel Strip.
- **OVERLOAD LED** under the VUs lights 25 dB over nominal, just past where the rounding starts,
  and holds 120 ms so each flash shows. Pull STEREO MASTER back to keep the level while you drive it.
- **L / R VUs** at the top: 0 VU = a -18 dBFS rms sine, with 300 ms VU ballistics.
- **EQUALIZER**: HIGH 2.5–15 kHz, MID 500 Hz–5 kHz, LOW 50 Hz–1 kHz, ±15 dB, Q 0.9 (the M-50's).
  The orange ring sets the frequency and the dark cap boost/cut. **EQ BYPASS** lights red when the
  EQ is out.
- **STEREO MASTER** fader, M-50 law: 7.5 = 0 dB, 10 = +8 dB, 5 = -10 dB.

The exported stereo mix goes through the sidecar. The separate mono tracks stay dry, for mixing in
the DAW. Settings are saved with the session.

## Sync, MIDI in, exports

- **SYNC MIDI** follows MIDI clock plus Start / Stop / Continue from Pro Tools, Reaper or anything
  else on any MIDI input. The tempo box shows the incoming tempo.
- **MIDI notes in** (any channel) play the pads, using General MIDI drum notes: 36/35 kick,
  38/40 snare, 45/47/48/50 toms, 37 rim, 56 cowbell, 39 clap, 54 tamb, 42/46 hats, 49 crash, 51 ride
  (CR-78 conga 64, bongo 60, cabassa 69). Velocity 112 and up counts as accented.
- **EXPORT AUDIO**: the song once through, or the current pattern 1–32 times, rendered offline
  as 24-bit stereo at **44.1 or 48 kHz**. You can export a **stereo mix**, **separate tracks** or
  **both**. Only the overall mix is stereo. Separate tracks are one **mono** WAV per pad that plays
  (`01 KICK.wav`, `02 SNARE.wav`… in panel order), each with its own level, tune and decay (pan is
  left to the DAW), and all the full length of the mix so they
  line up from bar 1 in a DAW. The pop-up asks for the song's and the pattern's names. The name you choose names the stereo mix (`My Song.wav`) and the folder of mono tracks (`My Song`). The song name is kept with the session; the pattern name becomes the pattern's name. Muted
  pads still get a track. The last hits' tail is included.
- **EXPORT MIDI**: the same choice as a Standard MIDI File (type 0, 96 PPQN, channel 10,
  GM drum notes). Accents are velocity 127, other hits 100, and the tempo is included.
  Flams export as one note.

## Window size

Drag the window's corner to scale the whole panel, sidecar included, from 50 % to 200 % of full
size. It keeps its proportions and redraws sharp at the new size. The size and position are
remembered. On first launch it opens as large as fits the screen.

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
