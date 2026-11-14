// Engine.h
// TB Drum Machine: the sound and sequencer core. Plain C++98, no Apple code, so
// it builds and is tested on Linux too.
//
// Layout follows the Roland TR-707: ten instrument pads in the 707's order, where
// some pads hold two sounds on one voice (Bass Drum 1/2, Snare 1/2, Rim/Cowbell,
// Clap/Tambourine, Closed/Open hat). The two sounds of a pad cut each other off,
// like the 707. Above the pads is an Accent track.
//
// The sequencer follows DM2's: every track has its own length (polymetric), and
// every step can be split into 2, 3 or 4 hits. Patterns chain into a song.

#ifndef TBDM_ENGINE_H
#define TBDM_ENGINE_H

#include <pthread.h>

namespace tbdm
{

const int kNumPads = 10;
const int kAccentTrack = 10;            // track index of the accent row
const int kNumTracks = 11;              // ten pads + accent
const int kMaxSteps = 32;
const int kNumPatterns = 16;
const int kMaxSong = 64;
const int kNumKits = 3;
const int kNameLen = 48;                // pattern names: up to 40 characters, plus room
const int kNumFlams = 3;                // normal, Flam A, Flam B

enum { kKit707 = 0, kKitCR78 = 1, kKitLM1 = 2 };

//------------------------------------------------------------------------------
// Kits

struct Sample
{
    float* data;        // mono
    int frames;
    double rate;
    Sample() : data (0), frames (0), rate (44100.0) {}
};

struct PadDef
{
    const char* label;                  // pad name in this kit ("KICK", "CONGA")
    int numChoices;                     // 0 = pad not used in this kit, 1 or 2
    const char* choiceLabel[2];         // "BD A" / "BD B", "CLOSED" / "OPEN"
    const char* file[2][kNumFlams];     // sample file names (no folder), 0 = none
    int midiNote[2];                    // note for MIDI in and MIDI export
};

struct KitDef
{
    const char* name;                   // "707", "CR-78", "LM-1"
    const char* folder;                 // folder name under Kits/
    PadDef pads[kNumPads];
};

const KitDef& kitDef (int kit);

// Every kit's samples, loaded once from the Kits folder.
class KitBank
{
public:
    KitBank();
    ~KitBank();
    // Loads every kit found under dir; returns the number of samples loaded.
    int load (const char* dir);
    void clear();
    const Sample* sample (int kit, int pad, int choice, int flam) const;
    bool padAvailable (int kit, int pad) const;
    bool flamAvailable (int kit, int pad, int choice) const;
    int samplesLoaded (int kit) const { return (kit >= 0 && kit < kNumKits) ? loaded[kit] : 0; }
    int samplesExpected (int kit) const;
    // Replace one sample (tests): takes ownership of data (new[]).
    void setSample (int kit, int pad, int choice, int flam, float* data, int frames, double rate);
private:
    Sample s[kNumKits][kNumPads][2][kNumFlams];
    int loaded[kNumKits];
    KitBank (const KitBank&);
    KitBank& operator= (const KitBank&);
};

//------------------------------------------------------------------------------
// Patterns and song

struct Step
{
    unsigned char on;       // 0/1
    unsigned char choice;   // 0 = A, 1 = B
    unsigned char flam;     // 0 normal, 1 Flam A, 2 Flam B
    unsigned char sub;      // hits in the step: 1..4
};

struct Track
{
    int length;             // 1..32 steps, own length per track (polymetric)
    Step steps[kMaxSteps];
};

struct Pattern
{
    char name[kNameLen];
    int kit;
    int length;             // pattern length in steps (1..32): where the song moves on
    Track tracks[kNumTracks];
    void clear();
    bool isEmpty() const;
};

struct SongEntry
{
    int pattern;            // 0..15
    int repeats;            // 1..16
};

struct Channel
{
    float level;            // 0..1 (fader)
    float pan;              // -1..+1
    float tune;             // semitones -12..+12
    float decay;            // 0..1, 1 = the whole sample
    bool mute, solo;
};

// Everything that is saved: patterns, song, mixer, tempo.
struct Song
{
    Pattern patterns[kNumPatterns];
    SongEntry entries[kMaxSong];
    int numEntries;
    Channel channels[kNumPads];
    float tempo;            // BPM 30..300
    float swing;            // 0..0.5 of a step (50%..75% shuffle)
    float accent;           // 0..1 accent amount
    float master;           // 0..1 master volume
    void setDefaults();
};

// When step k of a pattern of length L starts, in steps, with swing (odd 16ths
// late by swing steps), and how long it lasts.
double stepStart (int k, int L, double swing);

// Velocity used for MIDI export and live play (accented / normal)
const int kVelNormal = 100;
const int kVelAccent = 127;

//------------------------------------------------------------------------------
// The engine

class Engine
{
public:
    explicit Engine (const KitBank* kits);
    ~Engine();

    void setSampleRate (double sr);
    double sampleRate() const { return fs; }

    // Lock around any edit of song() from another thread. render() takes it itself.
    void lock() { pthread_mutex_lock (&mtx); }
    void unlock() { pthread_mutex_unlock (&mtx); }
    Song& song() { return data; }
    const Song& song() const { return data; }

    // Transport (call with the lock held, or from the audio thread)
    void play();
    void stop();
    bool isPlaying() const { return playing; }
    void setRecording (bool r) { recording = r; }
    bool isRecording() const { return recording; }
    void setSongMode (bool on);
    bool songMode() const { return songOn; }

    // Pattern being played / edited; when playing (not song mode) a change waits
    // for the end of the pattern, like the 707.
    void selectPattern (int p);
    int currentPattern() const { return curPattern; }
    int queuedPattern() const { return queued; }
    int songPosition() const { return songIndex; }
    void setSongPosition (int i);

    // External MIDI clock (24 per quarter note)
    void setExternalSync (bool on);
    bool externalSync() const { return extSync; }
    void midiStart();
    void midiContinue();
    void midiStop();
    void midiClock (double secondsSinceLast);   // <= 0 if unknown
    float externalTempo() const { return extTempo; }

    // Play a pad now (pad keys, MIDI in). Records into the pattern when recording.
    void hitPad (int pad, int choice, int flam, bool accent);
    // MIDI note in: finds pad and choice for the note in the current kit
    void midiNote (int note, int velocity);

    // Render n samples, adding nothing: overwrites L and R.
    void render (float* L, float* R, int n);

    // Playhead (for the panel): master step in the pattern and each track's step
    int playStep() const { return playing ? lastStep : -1; }
    int trackStep (int track) const;
    // 0..1 flash per pad, decays after a hit
    float padFlash (int pad) const { return (pad >= 0 && pad < kNumPads) ? flash[pad] : 0.0f; }
    int padFlashChoice (int pad) const { return (pad >= 0 && pad < kNumPads) ? flashChoice[pad] : 0; }

    // Offline: stop the sequencer after this many pattern ends (0 = run forever);
    // finished() turns true when it has stopped.
    void setStopAfterPatterns (int n) { stopAfter = n; patternEnds = 0; }
    bool sequencerFinished() const { return seqFinished; }
    bool voicesSilent() const;

    // For tests
    int hitsFired() const { return fired; }
    struct HitLog { int pad, choice, flam; bool accent; long long sampleTime; };
    void setHitLog (HitLog* buf, int cap) { log = buf; logCap = cap; logCount = 0; }
    int hitLogCount() const { return logCount; }

private:
    struct Pending { int choice, flam; float gain; int delay; };
    struct Voice
    {
        const Sample* s;
        double pos, inc;
        float gain, fade;         // fade: 1 = playing, drops to 0 when cut
        bool fading;
        double envTau;            // samples, <= 0: no decay envelope
        long long age;
        bool active;
    };

    const KitBank* kits;
    double fs;
    Song data;
    pthread_mutex_t mtx;

    bool playing, recording, songOn;
    int curPattern, queued;
    int songIndex, songRepeat;
    double pos;                    // position in the current pattern, in steps
    int lastStep;
    int stopAfter, patternEnds;
    bool seqFinished;

    bool extSync, extRunning;
    long long extClocks;           // clocks received since start
    double extAbs;                 // steps advanced since start
    float extTempo;
    double clockAvg;

    Voice voices[kNumPads][2];     // [0] current, [1] the one being cut off
    Pending pend[kNumPads][8];
    int numPend[kNumPads];
    int skipStep[kNumPads];        // a step just recorded live: don't retrigger it
    float flash[kNumPads];
    int flashChoice[kNumPads];
    long long sampleClock;
    int fired;
    HitLog* log;
    int logCap, logCount;

    void advancePattern();
    void schedule (int pad, int choice, int flam, float gain, int delay);
    void startVoice (int pad, int choice, int flam, float gain);
    double stepsPerSample() const;
    bool padAudible (int pad) const;

    Engine (const Engine&);
    Engine& operator= (const Engine&);
};

// Note -> pad/choice in a kit; false if the note isn't used
bool noteToPad (int kit, int note, int& pad, int& choice);

} // namespace tbdm

#endif
