// Engine.cpp

#include "Engine.h"
#include "Wav.h"

#include <cmath>
#include <cstdio>
#include <cstring>

namespace tbdm
{

//==============================================================================
// The three kits, in the 707's pad order, plus an 11th pad for the LM-1's
// fourth tom:
//   0 Kick  1 Snare  2 Low Tom  3 Mid Tom (1)  4 Hi Tom  5 Rim/Cowbell
//   6 Clap/Tambourine  7 Hi-Hat (closed/open)  8 Crash  9 Ride  10 Mid Tom 2
// File names are the user's own sample names. MIDI notes follow the General
// MIDI drum map, so exported files play the right sounds in any GM drum kit.

#define NOFILE { 0, 0, 0 }
#define UNUSED { "", 0, { 0, 0 }, { NOFILE, NOFILE }, { 0, 0 } }

static const KitDef kKits[kNumKits] = {
    { "707", "TB 707", {
        { "KICK",        2, { "BD A", "BD B" },      { { "BD A 707.wav", 0, 0 }, { "BD B 707.wav", 0, 0 } }, { 36, 35 } },
        { "SNARE",       2, { "SD A", "SD B" },      { { "SD A 707.wav", 0, 0 },
                                                       { "SD B 707.wav", "SD B 707 Flam A.wav", "SD B 707 Flam B.wav" } }, { 38, 40 } },
        { "LOW TOM",     1, { "", "" },              { { "Tom Lo 707.wav", "Tom Lo 707 Flam A.wav", "Tom Lo 707 Flam B.wav" }, NOFILE }, { 45, 0 } },
        { "MID TOM",     1, { "", "" },              { { "Tom Mid 707.wav", "Tom Mid 707 Flam A.wav", "Tom Mid 707 Flam B.wav" }, NOFILE }, { 47, 0 } },
        { "HI TOM",      1, { "", "" },              { { "Tom Hi 707.wav", "Tom Hi 707 Flam A.wav", "Tom Hi 707 Flam B.wav" }, NOFILE }, { 50, 0 } },
        { "RIM / COW",   2, { "RIM", "COW" },        { { "Rimshot 707.wav", 0, 0 }, { "Cowbell 707.wav", 0, 0 } }, { 37, 56 } },
        { "CLAP / TAMB", 2, { "CLAP", "TAMB" },      { { "Clap 707.wav", 0, 0 }, { "Tambourine 707.wav", 0, 0 } }, { 39, 54 } },
        { "HI-HAT",      2, { "CLOSED", "OPEN" },    { { "CH 707.wav", 0, 0 }, { "OH 707.wav", 0, 0 } }, { 42, 46 } },
        { "CRASH",       1, { "", "" },              { { "Crash 707.wav", 0, 0 }, NOFILE }, { 49, 0 } },
        { "RIDE",        1, { "", "" },              { { "Ride 707.wav", 0, 0 }, NOFILE }, { 51, 0 } },
        UNUSED }, { 0 } },

    { "CR-78", "TB CR78", {
        { "KICK",        1, { "", "" },              { { "Kick CR78.wav", 0, 0 }, NOFILE }, { 36, 0 } },
        { "SNARE",       1, { "", "" },              { { "Snare CR78.wav", 0, 0 }, NOFILE }, { 38, 0 } },
        { "CONGA",       1, { "", "" },              { { "Conga CR78.wav", 0, 0 }, NOFILE }, { 64, 0 } },
        UNUSED,
        { "BONGO",       1, { "", "" },              { { "Bongo CR78.wav", 0, 0 }, NOFILE }, { 60, 0 } },
        UNUSED,
        { "CABASSA",     1, { "", "" },              { { "Cabassa CR78.wav", 0, 0 }, NOFILE }, { 69, 0 } },
        { "HI-HAT",      2, { "CLOSED", "OPEN" },    { { "Closed HiHat CR78.wav", 0, 0 }, { "Open HiHat CR78.wav", 0, 0 } }, { 42, 46 } },
        UNUSED,
        UNUSED,
        UNUSED }, { 0 } },

    { "LM-1", "TB LM1", {
        { "KICK",        1, { "", "" },              { { "Kick LM1.wav", 0, 0 }, NOFILE }, { 36, 0 } },
        { "SNARE",       2, { "SN 01", "SN 02" },    { { "Snare 01 LM1.wav", 0, 0 }, { "Snare 02 LM1.wav", 0, 0 } }, { 38, 40 } },
        { "LOW TOM",     1, { "", "" },              { { "Tom 3 LM1.wav", 0, 0 }, NOFILE }, { 45, 0 } },
        { "MID TOM 1",   1, { "", "" },              { { "Mid Tom 1 LM1.wav", 0, 0 }, NOFILE }, { 48, 0 } },
        { "HI TOM",      1, { "", "" },              { { "Tom 1 LM1.wav", 0, 0 }, NOFILE }, { 50, 0 } },
        UNUSED,
        UNUSED,
        { "HI-HAT",      2, { "CLOSED", "OPEN" },    { { "Closed HiHat LM1.wav", 0, 0 }, { "Open HiHat LM1.wav", 0, 0 } }, { 42, 46 } },
        { "CRASH",       1, { "", "" },              { { "Crash LM1.wav", 0, 0 }, NOFILE }, { 49, 0 } },
        { "RIDE",        1, { "", "" },              { { "Ride LM1.wav", 0, 0 }, NOFILE }, { 51, 0 } },
        { "MID TOM 2",   1, { "", "" },              { { "Tom 2 LM1.wav", 0, 0 }, NOFILE }, { 47, 0 } } }, { 0 } },

    // 8 Bit: two kicks on the Kick pad, the effects on the toms (shortest to
    // longest) and the long ones on Crash, Ride and Clap/Tamb
    { "8 BIT", "TB 8 Bit", {
        { "KICK",        2, { "KICK", "ELECTRO" },   { { "TB_8Bit_Kick.wav", 0, 0 }, { "TB_8Bit_Kick_Electro.wav", 0, 0 } }, { 36, 35 } },
        { "ELECTRO SNARE", 1, { "", "" },            { { "TB_8Bit_Snare_Electro.wav", 0, 0 }, NOFILE }, { 38, 0 } },
        { "SPACE HIT",   1, { "", "" },              { { "TB_8Bit_Space_Hit.wav", 0, 0 }, NOFILE }, { 45, 0 } },
        { "WONKY",       1, { "", "" },              { { "TB_8Bit_Wonky.wav", 0, 0 }, NOFILE }, { 48, 0 } },
        { "BLIP",        1, { "", "" },              { { "TB_8Bit_Blip.wav", 0, 0 }, NOFILE }, { 50, 0 } },
        UNUSED,
        { "DISCHORDANT", 1, { "", "" },              { { "TB_8Bit_Dischordant.wav", 0, 0 }, NOFILE }, { 39, 0 } },
        { "COIN",        1, { "", "" },              { { "TB_8Bit_HiHat_Coin.wav", 0, 0 }, NOFILE }, { 42, 0 } },
        { "WHIPLASH",    1, { "", "" },              { { "TB_8Bit_Whiplash.wav", 0, 0 }, NOFILE }, { 49, 0 } },
        { "NAG REPEAT",  1, { "", "" },              { { "TB_8Bit_Nag_Repeat.wav", 0, 0 }, NOFILE }, { 51, 0 } },
        { "ALARMING",    1, { "", "" },              { { "TB_8Bit_Alarming.wav", 0, 0 }, NOFILE }, { 47, 0 } } }, { 0 } },

    // TVOD: every sound on its own pad, in the user's order: Kick, Snare,
    // Intendo, Noise 1, Noise 2, Noise Long, Whiplash
    { "TVOD", "TB TVOD Kit", {
        { "KICK",        1, { "", "" },              { { "TB TVOD Kick.wav", 0, 0 }, NOFILE }, { 36, 0 } },
        { "SNARE",       1, { "", "" },              { { "TB TVOD Snare.wav", 0, 0 }, NOFILE }, { 38, 0 } },
        UNUSED,
        UNUSED,
        UNUSED,
        { "INTENDO",     1, { "", "" },              { { "TB TVOD Snare Intendo.wav", 0, 0 }, NOFILE }, { 40, 0 } },
        { "NOISE 2",     1, { "", "" },              { { "TB TVOD White Noise Medium 2.wav", 0, 0 }, NOFILE }, { 46, 0 } },
        { "NOISE 1",     1, { "", "" },              { { "TB TVOD White Noise Medium 1.wav", 0, 0 }, NOFILE }, { 42, 0 } },
        { "NOISE LONG",  1, { "", "" },              { { "TB TVOD White Noise Long 01.wav", 0, 0 }, NOFILE }, { 49, 0 } },
        { "WHIPLASH",    1, { "", "" },              { { "TB TVOD Whiplash.wav", 0, 0 }, NOFILE }, { 51, 0 } },
        UNUSED },
      { 0, 1, 5, 7, 6, 8, 9, 4, 3, 10, 2 } }
};

#undef NOFILE
#undef UNUSED

const KitDef& kitDef (int kit)
{
    if (kit < 0 || kit >= kNumKits) kit = 0;
    return kKits[kit];
}

// Generic pad notes: a controller playing these reaches the pad in any kit
static const int kPadNotes[kNumPads][2] = {
    { 36, 35 }, { 38, 40 }, { 45, 41 }, { 47, 0 }, { 50, 43 }, { 37, 56 }, { 39, 54 }, { 42, 46 }, { 49, 57 }, { 51, 59 }, { 48, 0 }
};

bool noteToPad (int kit, int note, int& pad, int& choice)
{
    const KitDef& k = kitDef (kit);
    for (int p = 0; p < kNumPads; ++p)
        for (int c = 0; c < k.pads[p].numChoices; ++c)
            if (k.pads[p].midiNote[c] == note) { pad = p; choice = c; return true; }
    for (int p = 0; p < kNumPads; ++p)
        for (int c = 0; c < 2; ++c)
            if (kPadNotes[p][c] == note && note > 0 && k.pads[p].numChoices > 0)
            {
                pad = p;
                choice = c < k.pads[p].numChoices ? c : 0;
                return true;
            }
    return false;
}

//==============================================================================
// KitBank

KitBank::KitBank()
{
    for (int k = 0; k < kNumKits; ++k) loaded[k] = 0;
}

KitBank::~KitBank() { clear(); }

void KitBank::clear()
{
    for (int k = 0; k < kNumKits; ++k)
    {
        loaded[k] = 0;
        for (int p = 0; p < kNumPads; ++p)
            for (int c = 0; c < 2; ++c)
                for (int f = 0; f < kNumFlams; ++f)
                {
                    delete[] s[k][p][c][f].data;
                    s[k][p][c][f] = Sample();
                }
    }
}

static bool tryLoad (const char* dir, const char* folder, const char* file, Sample& out)
{
    char path[2048];
    // the folder as named, without "TB ", and with or without " Kit" on the end
    char f[4][256];
    const char* bare = folder + (std::strncmp (folder, "TB ", 3) == 0 ? 3 : 0);
    const size_t fl = std::strlen (folder);
    const bool hasKit = fl > 4 && std::strcmp (folder + fl - 4, " Kit") == 0;
    std::snprintf (f[0], sizeof (f[0]), "%s", folder);
    std::snprintf (f[1], sizeof (f[1]), "%s", bare);
    if (hasKit)
    {
        std::snprintf (f[2], sizeof (f[2]), "%.*s", (int) (fl - 4), folder);
        std::snprintf (f[3], sizeof (f[3]), "%.*s", (int) (std::strlen (bare) - 4), bare);
    }
    else
    {
        std::snprintf (f[2], sizeof (f[2]), "%s Kit", folder);
        std::snprintf (f[3], sizeof (f[3]), "%s Kit", bare);
    }
    const char* folders[4] = { f[0], f[1], f[2], f[3] };
    // the file as named, or with underscores for spaces (as some uploads arrive)
    char alt[256];
    std::snprintf (alt, sizeof (alt), "%s", file);
    for (char* c = alt; *c; ++c) if (*c == ' ') *c = '_';
    for (int i = 0; i < 8; ++i)
    {
        std::snprintf (path, sizeof (path), "%s/%s/%s", dir, folders[i & 3], i < 4 ? file : alt);
        float* d = 0;
        int n = 0;
        double r = 44100.0;
        if (readWav (path, d, n, r))
        {
            out.data = d;
            out.frames = n;
            out.rate = r;
            return true;
        }
    }
    return false;
}

int KitBank::load (const char* dir)
{
    clear();
    int total = 0;
    if (! dir) return 0;
    for (int k = 0; k < kNumKits; ++k)
        for (int p = 0; p < kNumPads; ++p)
            for (int c = 0; c < 2; ++c)
                for (int f = 0; f < kNumFlams; ++f)
                {
                    const char* file = kKits[k].pads[p].file[c][f];
                    if (file && tryLoad (dir, kKits[k].folder, file, s[k][p][c][f]))
                    {
                        ++loaded[k];
                        ++total;
                    }
                }
    return total;
}

int KitBank::samplesExpected (int kit) const
{
    int n = 0;
    const KitDef& k = kitDef (kit);
    for (int p = 0; p < kNumPads; ++p)
        for (int c = 0; c < 2; ++c)
            for (int f = 0; f < kNumFlams; ++f)
                if (k.pads[p].file[c][f]) ++n;
    return n;
}

const Sample* KitBank::sample (int kit, int pad, int choice, int flam) const
{
    if (kit < 0 || kit >= kNumKits || pad < 0 || pad >= kNumPads) return 0;
    if (choice < 0 || choice > 1) choice = 0;
    if (flam < 0 || flam >= kNumFlams) flam = 0;
    const Sample* x = &s[kit][pad][choice][flam];
    if (x->data) return x;
    x = &s[kit][pad][choice][0];
    if (x->data) return x;
    x = &s[kit][pad][0][0];
    return x->data ? x : 0;
}

bool KitBank::padAvailable (int kit, int pad) const
{
    return sample (kit, pad, 0, 0) != 0;
}

bool KitBank::flamAvailable (int kit, int pad, int choice) const
{
    if (kit < 0 || kit >= kNumKits || pad < 0 || pad >= kNumPads || choice < 0 || choice > 1) return false;
    return s[kit][pad][choice][1].data != 0 || s[kit][pad][choice][2].data != 0;
}

void KitBank::setSample (int kit, int pad, int choice, int flam, float* d, int frames, double rate)
{
    Sample& x = s[kit][pad][choice][flam];
    if (! x.data && d) ++loaded[kit];
    if (x.data && ! d) --loaded[kit];
    delete[] x.data;
    x.data = d;
    x.frames = frames;
    x.rate = rate;
}

//==============================================================================
// Patterns and song

static const SigDef kSigs[kNumSigs] = {
    { "4/4", 16, 4, 4, 2 },
    { "3/4", 12, 4, 3, 2 },
    { "6/4", 24, 4, 6, 2 },
    { "6/8", 12, 6, 6, 3 },
    { "12/8", 24, 6, 12, 3 }
};

const SigDef& sigDef (int sig)
{
    if (sig < 0 || sig >= kNumSigs) sig = 0;
    return kSigs[sig];
}

void Pattern::clear()
{
    std::memset (name, 0, sizeof (name));
    kit = kKit707;
    length = 16;
    sig = kSig44;
    for (int t = 0; t < kNumTracks; ++t)
    {
        tracks[t].length = 16;
        for (int s = 0; s < kMaxSteps; ++s)
        {
            Step& st = tracks[t].steps[s];
            st.on = 0;
            st.choice = 0;
            st.flam = 0;
            st.sub = 1;
        }
    }
}

bool Pattern::isEmpty() const
{
    for (int t = 0; t < kNumTracks; ++t)
        for (int s = 0; s < kMaxSteps; ++s)
            if (tracks[t].steps[s].on) return false;
    return true;
}

void Song::setDefaults()
{
    for (int p = 0; p < kNumPatterns; ++p) patterns[p].clear();
    for (int i = 0; i < kMaxSong; ++i) { entries[i].pattern = 0; entries[i].repeats = 1; }
    numEntries = 0;
    for (int c = 0; c < kNumPads; ++c)
    {
        channels[c].level = 0.8f;
        channels[c].pan = 0.0f;
        channels[c].tune = 0.0f;
        channels[c].decay = 1.0f;
        channels[c].mute = false;
        channels[c].solo = false;
    }
    tempo = 120.0f;
    swing = 0.0f;
    accent = 0.5f;
    master = 0.375f;     // 0 dB into the M-50 sidecar
    std::memset (name, 0, sizeof (name));
    for (int b = 0; b < 3; ++b) { eqFreq[b] = 0.5f; eqGain[b] = 0.5f; }
    eqBypass = false;
    fader = 0.75f;
}

double stepStart (int k, int L, double swing)
{
    if (k >= L) return (double) L;
    if (k < 0) return 0.0;
    return (double) k + ((k & 1) ? swing : 0.0);
}

//==============================================================================
// Engine

Engine::Engine (const KitBank* k)
    : kits (k), fs (44100.0),
      playing (false), recording (false), songOn (false),
      curPattern (0), queued (-1), songIndex (0), songRepeat (0),
      pos (0.0), lastStep (0), stopAfter (0), patternEnds (0), onlyPad (-1), seqFinished (false),
      extSync (false), extRunning (false), extClocks (0), extAbs (0.0), extTempo (0.0f), clockAvg (0.0),
      sampleClock (0), fired (0), log (0), logCap (0), logCount (0)
{
    pthread_mutex_init (&mtx, 0);
    data.setDefaults();
    std::memset (voices, 0, sizeof (voices));
    for (int p = 0; p < kNumPads; ++p)
    {
        numPend[p] = 0;
        skipStep[p] = -1;
        flash[p] = 0.0f;
        flashChoice[p] = 0;
    }
}

Engine::~Engine() { pthread_mutex_destroy (&mtx); }

void Engine::setSampleRate (double sr) { fs = (sr > 1000.0 && sr < 1.0e6) ? sr : 44100.0; master.setSampleRate (fs); master.reset(); }

void Engine::play()
{
    playing = true;
    seqFinished = false;
    patternEnds = 0;
    pos = 0.0;
    lastStep = 0;
    extAbs = 0.0;
    for (int p = 0; p < kNumPads; ++p) skipStep[p] = -1;
    if (songOn && data.numEntries > 0)
    {
        if (songIndex < 0 || songIndex >= data.numEntries) songIndex = 0;
        songRepeat = 0;
        curPattern = data.entries[songIndex].pattern;
        queued = -1;
    }
    else if (queued >= 0)
    {
        curPattern = queued;
        queued = -1;
    }
}

void Engine::stop()
{
    playing = false;
    if (queued >= 0) { curPattern = queued; queued = -1; }
    if (songOn && data.numEntries > 0) { songIndex = 0; songRepeat = 0; curPattern = data.entries[0].pattern; }
}

void Engine::setSongMode (bool on)
{
    songOn = on;
    queued = -1;
    if (on && data.numEntries > 0)
    {
        songIndex = 0;
        songRepeat = 0;
        if (! playing) curPattern = data.entries[0].pattern;
    }
}

void Engine::selectPattern (int p)
{
    if (p < 0 || p >= kNumPatterns) return;
    if (! playing) { curPattern = p; queued = -1; }
    else if (! songOn) queued = (p == curPattern) ? -1 : p;
}

void Engine::setSongPosition (int i)
{
    if (i < 0 || i >= data.numEntries) return;
    songIndex = i;
    songRepeat = 0;
    if (! playing) curPattern = data.entries[i].pattern;
}

void Engine::setExternalSync (bool on)
{
    extSync = on;
    extRunning = false;
    extClocks = 0;
    extAbs = 0.0;
}

void Engine::midiStart()
{
    if (! extSync) return;
    extClocks = 0;
    extRunning = true;
    play();
}

void Engine::midiContinue()
{
    if (! extSync) return;
    extRunning = true;
    if (! playing) { playing = true; seqFinished = false; }
}

void Engine::midiStop()
{
    if (! extSync) return;
    extRunning = false;
    playing = false;
}

void Engine::midiClock (double dt)
{
    if (! extSync) return;
    ++extClocks;
    if (dt > 0.0005 && dt < 0.25)
    {
        clockAvg = clockAvg <= 0.0 ? dt : clockAvg + (dt - clockAvg) * 0.1;
        extTempo = (float) (60.0 / (clockAvg * 24.0));
    }
}

double Engine::stepsPerSample() const
{
    double bpm = data.tempo;
    if (extSync && extTempo > 1.0f) bpm = extTempo;
    if (bpm < 20.0) bpm = 20.0;
    if (bpm > 400.0) bpm = 400.0;
    return bpm * 4.0 / 60.0 / fs;       // 16th-note steps per sample
}

bool Engine::padAudible (int pad) const
{
    bool anySolo = false;
    for (int c = 0; c < kNumPads; ++c) anySolo = anySolo || data.channels[c].solo;
    const Channel& ch = data.channels[pad];
    if (ch.mute) return false;
    return anySolo ? ch.solo : true;
}

void Engine::schedule (int pad, int choice, int flam, float gain, int delay)
{
    if (numPend[pad] >= 8) return;
    Pending& q = pend[pad][numPend[pad]++];
    q.choice = choice;
    q.flam = flam;
    q.gain = gain;
    q.delay = delay < 0 ? 0 : delay;
    ++fired;
    if (log && logCount < logCap)
    {
        HitLog& h = log[logCount++];
        h.pad = pad;
        h.choice = choice;
        h.flam = flam;
        h.accent = gain >= 0.999f;
        h.sampleTime = sampleClock + q.delay;
    }
}

void Engine::startVoice (int pad, int choice, int flam, float gain)
{
    const int kit = data.patterns[curPattern].kit;
    const Sample* s = kits ? kits->sample (kit, pad, choice, flam) : 0;
    if (! s) return;
    // The pad's previous sound is cut off quickly (one voice per pad, as on the 707)
    voices[pad][1] = voices[pad][0];
    if (voices[pad][1].active) voices[pad][1].fading = true;
    Voice& v = voices[pad][0];
    const Channel& ch = data.channels[pad];
    v.s = s;
    v.pos = 0.0;
    v.inc = s->rate / fs * std::pow (2.0, ch.tune / 12.0);
    v.gain = gain;
    v.fade = 1.0f;
    v.fading = false;
    v.age = 0;
    v.active = true;
    if (ch.decay < 0.999f)
    {
        const double outLen = s->frames / v.inc;
        const double d = ch.decay < 0.0f ? 0.0 : ch.decay;
        v.envTau = outLen * (0.03 + 0.97 * d * d) / 4.0;
    }
    else v.envTau = 0.0;
    flash[pad] = 1.0f;
    flashChoice[pad] = choice;
}

void Engine::hitPad (int pad, int choice, int flam, bool accent)
{
    if (pad < 0 || pad >= kNumPads) return;
    if (choice < 0 || choice > 1) choice = 0;
    if (flam < 0 || flam >= kNumFlams) flam = 0;
    const float normal = 1.0f - 0.5f * data.accent;
    schedule (pad, choice, flam, accent ? 1.0f : normal, 0);

    if (recording && playing)
    {
        Pattern& P = data.patterns[curPattern];
        int k = (int) std::floor (pos + 0.5);
        bool ahead = stepStart (k, P.length, data.swing) > pos;
        if (k >= P.length) { k = 0; ahead = true; }
        Track& T = P.tracks[pad];
        Step& st = T.steps[k % T.length];
        st.on = 1;
        st.choice = (unsigned char) choice;
        st.flam = (unsigned char) flam;
        st.sub = 1;
        skipStep[pad] = ahead ? k : -1;
    }
}

void Engine::midiNote (int note, int velocity)
{
    if (velocity <= 0) return;
    int pad = 0, choice = 0;
    if (noteToPad (data.patterns[curPattern].kit, note, pad, choice))
        hitPad (pad, choice, 0, velocity >= 112);
}

int Engine::trackStep (int track) const
{
    if (! playing || track < 0 || track >= kNumTracks) return -1;
    const int tl = data.patterns[curPattern].tracks[track].length;
    return tl > 0 ? lastStep % tl : -1;
}

void Engine::advancePattern()
{
    ++patternEnds;
    for (int p = 0; p < kNumPads; ++p) skipStep[p] = -1;
    if (stopAfter > 0 && patternEnds >= stopAfter)
    {
        seqFinished = true;
        playing = false;
        return;
    }
    if (songOn && data.numEntries > 0)
    {
        if (songIndex < 0 || songIndex >= data.numEntries) songIndex = 0;
        if (++songRepeat >= data.entries[songIndex].repeats)
        {
            songRepeat = 0;
            songIndex = (songIndex + 1) % data.numEntries;
        }
        curPattern = data.entries[songIndex].pattern;
    }
    else if (queued >= 0)
    {
        curPattern = queued;
        queued = -1;
    }
}

void Engine::render (float* L, float* R, int n)
{
    lock();
    for (int i = 0; i < n; ++i) { L[i] = 0.0f; R[i] = 0.0f; }

    // Sequencer: find the hits in this block
    if (playing && ! seqFinished && n > 0)
    {
        double w = stepsPerSample() * n;
        if (extSync)
        {
            const double allowed = extClocks / 6.0;
            double room = allowed - extAbs;
            if (! extRunning || room < 0.0) room = 0.0;
            if (room > 0.5) w = room;          // far behind the clock: catch up
            else if (w > room) w = room;
            extAbs += w;
        }
        const double inc = w > 0.0 ? w / n : 1.0;
        double p = pos, remaining = w, off = 0.0;
        int guard = 0;
        while (remaining > 1e-12 && playing && ++guard < 64)
        {
            Pattern& P = data.patterns[curPattern];
            if (P.length < 1) P.length = 1;
            if (P.length > kMaxSteps) P.length = kMaxSteps;
            const int Lp = P.length;
            const double end = (p + remaining < Lp) ? p + remaining : (double) Lp;
            const double sw = data.swing < 0.0f ? 0.0 : (data.swing > 0.5f ? 0.5 : data.swing);
            const float normal = 1.0f - 0.5f * data.accent;

            int k0 = (int) std::floor (p) - 1;
            if (k0 < 0) k0 = 0;
            int k1 = (int) std::floor (end);
            if (k1 > Lp - 1) k1 = Lp - 1;
            for (int k = k0; k <= k1; ++k)
            {
                const double st = stepStart (k, Lp, sw);
                const double dur = stepStart (k + 1, Lp, sw) - st;
                const Track& AT = P.tracks[kAccentTrack];
                const int al = AT.length < 1 ? 1 : AT.length;
                const bool acc = AT.steps[k % al].on != 0;
                for (int t = 0; t < kNumPads; ++t)
                {
                    const Track& T = P.tracks[t];
                    const int tl = T.length < 1 ? 1 : (T.length > kMaxSteps ? kMaxSteps : T.length);
                    const Step& s = T.steps[k % tl];
                    if (! s.on) continue;
                    const int sub = s.sub < 1 ? 1 : (s.sub > 4 ? 4 : s.sub);
                    for (int j = 0; j < sub; ++j)
                    {
                        const double ht = st + dur * j / sub;
                        if (ht < p || ht >= end) continue;
                        if (j == 0 && skipStep[t] == k) { skipStep[t] = -1; continue; }
                        const int delay = (int) ((off + (ht - p)) / inc + 0.5);
                        schedule (t, s.choice, s.flam, acc ? 1.0f : normal, delay);
                    }
                }
            }
            remaining -= end - p;
            off += end - p;
            p = end;
            lastStep = (int) std::floor (p);
            if (lastStep >= Lp) lastStep = Lp - 1;
            if (p >= Lp - 1e-9)
            {
                advancePattern();
                p = 0.0;
                lastStep = 0;
            }
        }
        pos = p;
    }

    // Voices
    bool anySolo = false;
    for (int c = 0; c < kNumPads; ++c) anySolo = anySolo || data.channels[c].solo;
    const float fadeStep = (float) (1.0 / (0.003 * fs));
    for (int pad = 0; pad < kNumPads; ++pad)
    {
        const Channel& ch = data.channels[pad];
        const bool audible = onlyPad >= 0 ? pad == onlyPad : (! ch.mute && (anySolo ? ch.solo : true));
        const float pan = ch.pan < -1.0f ? -1.0f : (ch.pan > 1.0f ? 1.0f : ch.pan);
        const double ang = (pan + 1.0) * 0.25 * M_PI;
        const float lvl = audible ? ch.level * ch.level : 0.0f;    // MASTER is the sidecar's drive now
        const float gl = (float) (lvl * std::cos (ang) * 1.41421356);
        const float gr = (float) (lvl * std::sin (ang) * 1.41421356);

        // pending starts, in order
        for (int i = 1; i < numPend[pad]; ++i)
            for (int j = i; j > 0 && pend[pad][j].delay < pend[pad][j - 1].delay; --j)
            {
                Pending tmp = pend[pad][j];
                pend[pad][j] = pend[pad][j - 1];
                pend[pad][j - 1] = tmp;
            }
        int pi = 0;
        int t = 0;
        while (t < n)
        {
            while (pi < numPend[pad] && pend[pad][pi].delay <= t)
            {
                startVoice (pad, pend[pad][pi].choice, pend[pad][pi].flam, pend[pad][pi].gain);
                ++pi;
            }
            int segEnd = n;
            if (pi < numPend[pad] && pend[pad][pi].delay < n) segEnd = pend[pad][pi].delay;
            for (int vi = 0; vi < 2; ++vi)
            {
                Voice& v = voices[pad][vi];
                if (! v.active) continue;
                const float* x = v.s->data;
                const int N = v.s->frames;
                for (int i = t; i < segEnd; ++i)
                {
                    const int idx = (int) v.pos;
                    if (idx >= N) { v.active = false; break; }
                    const float fr = (float) (v.pos - idx);
                    const float xm1 = x[idx > 0 ? idx - 1 : 0];
                    const float x0 = x[idx];
                    const float x1 = idx + 1 < N ? x[idx + 1] : 0.0f;
                    const float x2 = idx + 2 < N ? x[idx + 2] : 0.0f;
                    // 4-point Hermite
                    const float c1 = 0.5f * (x1 - xm1);
                    const float c2 = xm1 - 2.5f * x0 + 2.0f * x1 - 0.5f * x2;
                    const float c3 = 0.5f * (x2 - xm1) + 1.5f * (x0 - x1);
                    float y = ((c3 * fr + c2) * fr + c1) * fr + x0;
                    float g = v.gain * v.fade;
                    if (v.envTau > 0.0)
                    {
                        const double e = std::exp (-(double) v.age / v.envTau);
                        if (e < 1e-4) { v.active = false; break; }
                        g *= (float) e;
                    }
                    y *= g;
                    L[i] += y * gl;
                    R[i] += y * gr;
                    v.pos += v.inc;
                    ++v.age;
                    if (v.fading)
                    {
                        v.fade -= fadeStep;
                        if (v.fade <= 0.0f) { v.active = false; break; }
                    }
                }
            }
            t = segEnd;
        }
        // later starts move to the next block
        int keep = 0;
        for (int i = pi; i < numPend[pad]; ++i)
        {
            pend[pad][keep] = pend[pad][i];
            pend[pad][keep].delay -= n;
            ++keep;
        }
        numPend[pad] = keep;
        flash[pad] *= (float) std::exp (-n / (0.15 * fs));
    }

    // The M-50 Master sidecar: EQ, STEREO MASTER fader, VUs (not on single-pad renders)
    if (onlyPad < 0) master.process (L, R, n, data);

    // Gentle limiter above -2 dB so loud kits never wrap round
    for (int i = 0; i < n; ++i)
    {
        float* o[2] = { &L[i], &R[i] };
        for (int c = 0; c < 2; ++c)
        {
            float v = *o[c];
            if (v != v) v = 0.0f;
            const float a = v < 0.0f ? -v : v;
            if (a > 0.8f)
            {
                const float m = 0.8f + 0.2f * (float) std::tanh ((a - 0.8f) / 0.2f);
                v = v < 0.0f ? -m : m;
            }
            *o[c] = v;
        }
    }
    sampleClock += n;
    unlock();
}

bool Engine::voicesSilent() const
{
    for (int p = 0; p < kNumPads; ++p)
    {
        if (numPend[p] > 0) return false;
        if (voices[p][0].active || voices[p][1].active) return false;
    }
    return true;
}

} // namespace tbdm
