// engine_test.cpp: tests for the TB Drum Machine engine (C++98, Linux and Mac).
//
//   engine_test [render dir]
//
// If TBDM_TEST_KITS points at a Kits folder (the user's samples), the real kits are
// loaded and checked too, and a demo beat is rendered from each kit.

#include "../Source/Engine/Engine.h"
#include "../Source/Engine/Export.h"
#include "../Source/Engine/Wav.h"
#include "../Source/Engine/Master.h"

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <ctime>
#include <string>
#include <vector>
#include <sys/stat.h>

using namespace tbdm;

static int failures = 0;
static void check (bool ok, const char* what)
{
    std::printf ("  %s  %s\n", ok ? "ok  " : "FAIL", what);
    if (! ok) ++failures;
}

static float* tone (int frames, double freq, double fs, double decaySecs)
{
    float* d = new float[frames];
    for (int i = 0; i < frames; ++i)
        d[i] = (float) (0.5 * std::sin (2.0 * M_PI * freq * i / fs) * std::exp (-i / (decaySecs * fs)));
    return d;
}

// A synthetic kit: every pad and choice gets a short tone (different pitches)
static void fillKit (KitBank& kb)
{
    for (int k = 0; k < kNumKits; ++k)
        for (int p = 0; p < kNumPads; ++p)
            for (int c = 0; c < 2; ++c)
                for (int f = 0; f < kNumFlams; ++f)
                    if (kitDef (k).pads[p].file[c][f])
                        kb.setSample (k, p, c, f, tone (8000, 100.0 + 40.0 * p + 7.0 * c + 3.0 * f, 44100.0, 0.05), 8000, 44100.0);
}

static void runFor (Engine& e, double seconds, int block = 256)
{
    std::vector<float> L (block), R (block);
    long n = (long) (seconds * e.sampleRate());
    while (n > 0)
    {
        const int b = (int) (n < block ? n : block);
        e.render (&L[0], &R[0], b);
        n -= b;
    }
}

static void setStep (Pattern& P, int track, int k, int choice = 0, int flam = 0, int sub = 1)
{
    Step& s = P.tracks[track].steps[k];
    s.on = 1;
    s.choice = (unsigned char) choice;
    s.flam = (unsigned char) flam;
    s.sub = (unsigned char) sub;
}

static bool near (long long a, double b, double tol) { return std::fabs ((double) a - b) <= tol; }

int main (int argc, char** argv)
{
    const std::string renders = argc > 1 ? argv[1] : "";
    KitBank kb;
    fillKit (kb);
    const double fs = 44100.0;
    const double stepSamples = fs * 15.0 / 120.0;   // 16th at 120 BPM

    std::printf ("Kits\n");
    {
        check (kitDef (kKit707).pads[0].numChoices == 2, "707 kick has BD A / BD B");
        check (std::strcmp (kitDef (kKitCR78).pads[2].label, "CONGA") == 0, "CR-78 low tom pad is CONGA");
        check (std::strcmp (kitDef (kKitCR78).pads[4].label, "BONGO") == 0, "CR-78 hi tom pad is BONGO");
        check (std::strcmp (kitDef (kKitLM1).pads[4].file[0][0], "Tom 1 LM1.wav") == 0, "LM-1 hi tom is Tom 1");
        check (std::strcmp (kitDef (kKitLM1).pads[2].file[0][0], "Tom 3 LM1.wav") == 0, "LM-1 low tom is Tom 3");
        check (kb.samplesExpected (kKit707) == 23 && kb.samplesExpected (kKitCR78) == 7 && kb.samplesExpected (kKitLM1) == 11,
               "kit tables list 23 + 7 + 11 samples");
        check (std::strcmp (kitDef (kKitLM1).pads[3].label, "MID TOM 1") == 0 && std::strcmp (kitDef (kKitLM1).pads[10].label, "MID TOM 2") == 0
               && std::strcmp (kitDef (kKitLM1).pads[3].file[0][0], "Mid Tom 1 LM1.wav") == 0
               && std::strcmp (kitDef (kKitLM1).pads[10].file[0][0], "Tom 2 LM1.wav") == 0, "LM-1: MID TOM 1 = new sample, MID TOM 2 = Tom 2");
        check (! kb.padAvailable (kKit707, 10) && ! kb.padAvailable (kKitCR78, 10), "707 and CR-78 have no 11th pad");
        check (kb.flamAvailable (kKit707, 1, 1) && ! kb.flamAvailable (kKit707, 1, 0), "707 flams on SD B only");
        check (! kb.padAvailable (kKitCR78, 3) && kb.padAvailable (kKitCR78, 2), "CR-78 unused pads are empty");
        int pad = -1, ch = -1;
        check (noteToPad (kKit707, 46, pad, ch) && pad == 7 && ch == 1, "note 46 -> open hat");
        check (noteToPad (kKitCR78, 64, pad, ch) && pad == 2, "note 64 -> CR-78 conga");
        check (noteToPad (kKitCR78, 45, pad, ch) && pad == 2, "generic low tom note reaches the conga");
    }

    std::printf ("Timing\n");
    {
        Engine e (&kb);
        e.setSampleRate (fs);
        Pattern& P = e.song().patterns[0];
        for (int k = 0; k < 16; k += 4) setStep (P, 0, k);
        Engine::HitLog lg[256];
        e.setHitLog (lg, 256);
        e.play();
        runFor (e, 2.01);
        // 2 s = 1 bar at 120 BPM: kicks at 0, 4, 8, 12 then the next bar's 0
        bool ok = e.hitLogCount() >= 5;
        for (int i = 0; ok && i < 5; ++i) ok = near (lg[i].sampleTime, i * 4 * stepSamples, 1.0);
        check (ok, "four-on-the-floor kicks land on the sample");
    }
    {
        Engine e (&kb);
        e.setSampleRate (fs);
        Pattern& P = e.song().patterns[0];
        P.tracks[7].length = 3;
        setStep (P, 7, 0);
        Engine::HitLog lg[256];
        e.setHitLog (lg, 256);
        e.play();
        runFor (e, 2.0 + 0.01);
        // track of 3 steps in a 16-step pattern: 0 3 6 9 12 15, then 0 again
        const int want[7] = { 0, 3, 6, 9, 12, 15, 16 };
        bool ok = e.hitLogCount() == 7;
        for (int i = 0; ok && i < 7; ++i) ok = near (lg[i].sampleTime, want[i] * stepSamples, 1.0);
        check (ok, "polymetric track (3 steps) restarts with the pattern");
    }
    {
        Engine e (&kb);
        e.setSampleRate (fs);
        setStep (e.song().patterns[0], 1, 0, 0, 0, 4);
        setStep (e.song().patterns[0], 2, 2, 0, 0, 3);
        Engine::HitLog lg[64];
        e.setHitLog (lg, 64);
        e.play();
        runFor (e, 0.5);
        bool ok = e.hitLogCount() == 7;
        for (int j = 0; ok && j < 4; ++j) ok = near (lg[j].sampleTime, j * stepSamples / 4, 1.0);
        for (int j = 0; ok && j < 3; ++j) ok = near (lg[4 + j].sampleTime, (2 + j / 3.0) * stepSamples, 1.0);
        check (ok, "steps split into 4 and 3 hits");
    }
    {
        Engine e (&kb);
        e.setSampleRate (fs);
        e.song().swing = 0.25f;
        setStep (e.song().patterns[0], 7, 0);
        setStep (e.song().patterns[0], 7, 1);
        setStep (e.song().patterns[0], 7, 2);
        Engine::HitLog lg[64];
        e.setHitLog (lg, 64);
        e.play();
        runFor (e, 0.4);
        check (e.hitLogCount() == 3 && near (lg[1].sampleTime, 1.25 * stepSamples, 1.0) && near (lg[2].sampleTime, 2 * stepSamples, 1.0),
               "swing delays the odd 16ths only");
    }
    {
        Engine e (&kb);
        e.setSampleRate (fs);
        e.song().tempo = 300.0f;
        for (int k = 0; k < 16; ++k) setStep (e.song().patterns[0], 7, k, 0, 0, 4);
        Engine::HitLog lg[1024];
        e.setHitLog (lg, 1024);
        e.play();
        runFor (e, 1.6, 1024);   // two bars at 300 BPM with big blocks
        const double st = fs * 15.0 / 300.0;
        bool ok = e.hitLogCount() >= 128;
        for (int i = 0; ok && i < 128; ++i) ok = near (lg[i].sampleTime, i * st / 4, 1.0);
        check (ok, "300 BPM 64ths stay sample-accurate with 1024-sample blocks");
    }

    std::printf ("Accent, choices, flams\n");
    {
        Engine e (&kb);
        e.setSampleRate (fs);
        Pattern& P = e.song().patterns[0];
        setStep (P, 0, 0, 1);
        setStep (P, 1, 4, 1, 2);
        setStep (P, kAccentTrack, 4);
        Engine::HitLog lg[16];
        e.setHitLog (lg, 16);
        e.play();
        runFor (e, 1.0);
        check (e.hitLogCount() == 2 && lg[0].choice == 1 && ! lg[0].accent, "BD B, unaccented");
        check (e.hitLogCount() == 2 && lg[1].flam == 2 && lg[1].accent, "SD B Flam B, accented");
    }
    {
        // open hat cut by closed hat (same pad)
        KitBank k2;
        float* longTone = tone (88200, 1000.0, fs, 10.0);
        k2.setSample (kKit707, 7, 1, 0, longTone, 88200, fs);
        float* zero = new float[2000];
        std::memset (zero, 0, sizeof (float) * 2000);
        k2.setSample (kKit707, 7, 0, 0, zero, 2000, fs);
        Engine e (&k2);
        e.setSampleRate (fs);
        setStep (e.song().patterns[0], 7, 0, 1);
        setStep (e.song().patterns[0], 7, 4, 0);
        e.play();
        std::vector<float> L (44100), R (44100);
        e.render (&L[0], &R[0], 44100);
        double before = 0.0, after = 0.0;
        for (int i = 1000; i < 10000; ++i) before += L[i] * L[i];
        const int cut = (int) (4 * stepSamples) + (int) (0.004 * fs);
        for (int i = cut; i < cut + 9000; ++i) after += L[i] * L[i];
        check (before > 1.0 && after < 1e-9, "closed hat chokes the open hat");
    }

    std::printf ("Patterns and song\n");
    {
        Engine e (&kb);
        e.setSampleRate (fs);
        setStep (e.song().patterns[0], 0, 0, 0);
        setStep (e.song().patterns[1], 0, 0, 1);
        e.song().patterns[1].length = 8;
        e.song().entries[0].pattern = 0; e.song().entries[0].repeats = 2;
        e.song().entries[1].pattern = 1; e.song().entries[1].repeats = 1;
        e.song().numEntries = 2;
        e.setSongMode (true);
        Engine::HitLog lg[16];
        e.setHitLog (lg, 16);
        e.play();
        runFor (e, 2.0 * 2 + 1.0 + 0.05);   // 2 bars, a half bar, then the song loops
        bool ok = e.hitLogCount() == 4 && lg[0].choice == 0 && lg[1].choice == 0 && lg[2].choice == 1 && lg[3].choice == 0;
        ok = ok && near (lg[2].sampleTime, 32 * stepSamples, 1.0) && near (lg[3].sampleTime, 40 * stepSamples, 1.0);
        check (ok, "song plays pattern 1 twice, pattern 2 (8 steps) once, loops");
    }
    {
        Engine e (&kb);
        e.setSampleRate (fs);
        setStep (e.song().patterns[0], 0, 0, 0);
        setStep (e.song().patterns[2], 0, 0, 1);
        Engine::HitLog lg[16];
        e.setHitLog (lg, 16);
        e.play();
        runFor (e, 0.5);
        e.lock();
        e.selectPattern (2);
        e.unlock();
        check (e.currentPattern() == 0 && e.queuedPattern() == 2, "pattern change waits for the end of the bar");
        runFor (e, 1.6);
        check (e.currentPattern() == 2 && e.hitLogCount() == 2 && lg[1].choice == 1, "next bar plays the new pattern");
    }
    {
        Engine e (&kb);
        e.setSampleRate (fs);
        Engine::HitLog lg[16];
        e.setHitLog (lg, 16);
        e.setRecording (true);
        e.play();
        runFor (e, 3.9 * stepSamples / fs);
        e.lock();
        e.hitPad (0, 1, 0, false);           // just before step 4
        e.unlock();
        runFor (e, 1.0);
        const Step& s = e.song().patterns[0].tracks[0].steps[4];
        check (s.on && s.choice == 1, "live hit recorded on the nearest step");
        check (e.hitLogCount() == 1, "recorded hit isn't played twice");
    }

    std::printf ("MIDI clock\n");
    {
        Engine e (&kb);
        e.setSampleRate (fs);
        setStep (e.song().patterns[0], 0, 0);
        setStep (e.song().patterns[0], 0, 4);
        e.setExternalSync (true);
        Engine::HitLog lg[16];
        e.setHitLog (lg, 16);
        e.midiStart();
        // DAW at 100 BPM: a clock every 60 / 100 / 24 s
        const double clk = 60.0 / 100.0 / 24.0 * fs;
        double nextClock = 0.0;
        long t = 0;
        std::vector<float> L (64), R (64);
        while (t < (long) (fs * 0.8))
        {
            while (nextClock <= t) { e.midiClock (60.0 / 100.0 / 24.0); nextClock += clk; }
            e.render (&L[0], &R[0], 64);
            t += 64;
        }
        const double step100 = fs * 15.0 / 100.0;
        check (std::fabs (e.externalTempo() - 100.0f) < 0.5f, "tempo read from the clock");
        check (e.hitLogCount() == 2 && near (lg[1].sampleTime, 4 * step100, 200.0), "steps follow the clock (step 4 within 5 ms)");
        e.midiStop();
        check (! e.isPlaying(), "MIDI stop stops");
    }

    std::printf ("Session file\n");
    {
        Song s;
        s.setDefaults();
        s.tempo = 133.5f;
        s.swing = 0.125f;
        s.channels[3].tune = -5.0f;
        s.channels[7].mute = true;
        std::strcpy (s.patterns[5].name, "A forty character name for the readout!!");
        std::strcpy (s.name, "Saturday Night Song");
        s.patterns[5].kit = kKitLM1;
        s.patterns[5].length = 24;
        s.patterns[5].sig = kSig128;
        s.patterns[5].tracks[2].length = 7;
        setStep (s.patterns[5], 2, 6, 1, 2, 3);
        setStep (s.patterns[5], kAccentTrack, 0);
        s.numEntries = 3;
        s.entries[2].pattern = 5;
        s.entries[2].repeats = 4;
        SessionState st;
        st.currentPattern = 5;
        st.songMode = true;
        st.page = 2;
        const char* path = "/tmp/tbdm_session_test.txt";
        check (saveSession (path, s, st), "save");
        Song t;
        SessionState st2;
        check (loadSession (path, t, st2), "load");
        bool same = std::memcmp (s.patterns, t.patterns, sizeof (s.patterns)) == 0;
        same = same && t.tempo == s.tempo && t.numEntries == 3 && t.entries[2].pattern == 5 && t.entries[2].repeats == 4;
        same = same && std::fabs (t.channels[3].tune + 5.0f) < 1e-4f && t.channels[7].mute && std::fabs (t.swing - 0.125f) < 1e-4f;
        same = same && std::strcmp (t.name, "Saturday Night Song") == 0 && st2.currentPattern == 5 && st2.songMode && st2.page == 2;
        check (same, "everything comes back the same");
        bool codes = true;
        for (int ch = 0; ch < 2; ++ch)
            for (int fl = 0; fl < 3; ++fl)
                for (int sub = 1; sub <= 4; ++sub)
                {
                    Step a = { 1, (unsigned char) ch, (unsigned char) fl, (unsigned char) sub };
                    Step b = decodeStep (encodeStep (a));
                    codes = codes && b.on && b.choice == ch && b.flam == fl && b.sub == sub;
                }
        check (codes, "every step setting survives the text form");
        FILE* f = std::fopen (path, "w");
        std::fprintf (f, "TB Drum Machine 1\ntempo 90\n");
        std::fclose (f);
        check (! loadSession (path, t, st2), "half-written file is refused");
        f = std::fopen (path, "w");
        std::fprintf (f, "TB Drum Machine 2\nmaster 0.8\nend\n");
        std::fclose (f);
        check (loadSession (path, t, st2) && std::fabs (MasterSection::driveDb (t.master) - 20.0 * std::log10 (0.8)) < 0.01,
               "older session: MASTER volume becomes the same level of drive");
        f = std::fopen (path, "w");
        std::fprintf (f, "TB Drum Machine 1\npattern 0 0 16\nname OLD\ntrack 10 16 1...............................\ntrack 0 16 .1..............................\nend\n");
        std::fclose (f);
        check (loadSession (path, t, st2) && t.patterns[0].tracks[kAccentTrack].steps[0].on && ! t.patterns[0].tracks[10].steps[0].on
               && t.patterns[0].tracks[0].steps[1].on, "old (10-pad) session: accent row comes back as accent");
        std::remove (path);
    }

    std::printf ("MIDI export\n");
    {
        Song s;
        s.setDefaults();
        s.tempo = 125.0f;
        setStep (s.patterns[0], 0, 0);
        setStep (s.patterns[0], 7, 2, 1, 0, 2);
        setStep (s.patterns[0], kAccentTrack, 0);
        ExportRange r = { false, 0, 2 };
        const char* path = "/tmp/tbdm_test.mid";
        check (exportMidi (path, s, r), "write");
        FILE* f = std::fopen (path, "rb");
        unsigned char buf[4096];
        const size_t n = std::fread (buf, 1, sizeof (buf), f);
        std::fclose (f);
        check (n > 22 && std::memcmp (buf, "MThd", 4) == 0 && buf[13] == 96 && std::memcmp (buf + 14, "MTrk", 4) == 0, "header: type 0, 96 PPQN");
        // walk the track
        size_t p = 22;
        long tick = 0;
        int ons = 0;
        long onTicks[16];
        int vels[16], notes[16];
        double tempoBpm = 0.0;
        unsigned char run = 0;
        while (p < n)
        {
            unsigned long d = 0;
            while (p < n) { unsigned char c = buf[p++]; d = (d << 7) | (c & 0x7F); if (! (c & 0x80)) break; }
            tick += (long) d;
            unsigned char st = buf[p];
            if (st == 0xFF)
            {
                const unsigned char type = buf[p + 1], len = buf[p + 2];
                if (type == 0x51) tempoBpm = 60000000.0 / ((buf[p + 3] << 16) | (buf[p + 4] << 8) | buf[p + 5]);
                p += 3 + len;
                if (type == 0x2F) break;
                continue;
            }
            run = st;
            if ((run & 0xF0) == 0x90 && buf[p + 2] > 0 && ons < 16)
            {
                onTicks[ons] = tick;
                notes[ons] = buf[p + 1];
                vels[ons] = buf[p + 2];
                ++ons;
            }
            p += 3;
        }
        check (std::fabs (tempoBpm - 125.0) < 0.01, "tempo 125");
        check (ons == 6, "6 notes (2 bars of kick + double hat)");
        check (ons == 6 && onTicks[0] == 0 && notes[0] == 36 && vels[0] == kVelAccent, "accented kick on 1");
        check (ons == 6 && onTicks[1] == 48 && onTicks[2] == 60 && notes[1] == 46 && vels[1] == kVelNormal, "open hat split in 2 on step 3");
        check (ons == 6 && onTicks[3] == 384, "second bar starts at 384 ticks");
        check (tick == 768, "file ends at the end of bar 2");
        std::remove (path);
    }

    std::printf ("Time signatures\n");
    {
        check (sigDef (kSig44).steps == 16 && sigDef (kSig34).steps == 12 && sigDef (kSig64).steps == 24
               && sigDef (kSig68).steps == 12 && sigDef (kSig128).steps == 24, "4/4 16, 3/4 12, 6/4 24, 6/8 12, 12/8 24 steps");
        Song s;
        s.setDefaults();
        s.patterns[0].sig = kSig68;
        s.patterns[0].length = 12;
        setStep (s.patterns[0], 0, 0);
        ExportRange r = { false, 0, 2 };
        check (exportMidi ("/tmp/tbdm_sig.mid", s, r), "6/8 pattern exports");
        FILE* f = std::fopen ("/tmp/tbdm_sig.mid", "rb");
        unsigned char buf[512];
        const size_t n = std::fread (buf, 1, sizeof (buf), f);
        std::fclose (f);
        bool found = false;
        for (size_t i = 0; i + 6 < n; ++i)
            if (buf[i] == 0xFF && buf[i + 1] == 0x58 && buf[i + 2] == 4 && buf[i + 3] == 6 && buf[i + 4] == 3) found = true;
        check (found, "MIDI file says 6/8");
        Engine e (&kb);
        e.setSampleRate (fs);
        e.song() = s;
        Engine::HitLog lg[8];
        e.setHitLog (lg, 8);
        e.play();
        runFor (e, 12 * stepSamples / fs + 0.01);
        check (e.hitLogCount() == 2 && near (lg[1].sampleTime, 12 * stepSamples, 1.0), "a 6/8 bar is 12 sixteenths long");
        std::remove ("/tmp/tbdm_sig.mid");
    }

    std::printf ("M-50 Master sidecar\n");
    {
        // a steady sine through the section: gain at a frequency, after it settles
        struct Probe
        {
            static double gainDb (Song& s, double freq, double level = 0.1)
            {
                MasterSection m;
                m.setSampleRate (48000.0);
                m.reset();
                const int n = 48000;
                std::vector<float> L (n), R (n);
                for (int i = 0; i < n; ++i) L[i] = R[i] = (float) (level * std::sin (2.0 * M_PI * freq * i / 48000.0));
                for (int b = 0; b < n; b += 256) m.process (&L[b], &R[b], std::min (256, n - b), s);
                double pk = 0.0;
                for (int i = n / 2; i < n; ++i) pk = std::max (pk, (double) std::fabs (L[i]));
                return 20.0 * std::log10 (pk / level);
            }
        };
        Song s;
        s.setDefaults();
        check (std::fabs (Probe::gainDb (s, 1000.0)) < 0.05, "flat EQ, fader 7.5: unity");
        s.eqGain[MasterSection::kHigh] = 1.0f;
        s.eqFreq[MasterSection::kHigh] = 0.5f;
        const double fc = MasterSection::eqHz (MasterSection::kHigh, 0.5);
        const double up = Probe::gainDb (s, fc);
        char msg[96];
        std::snprintf (msg, sizeof (msg), "HIGH +15 dB at %.0f Hz (measured %+.1f dB)", fc, up);
        check (std::fabs (up - 15.0) < 0.5, msg);
        check (std::fabs (Probe::gainDb (s, 100.0)) < 0.5, "...and leaves the lows alone");
        s.eqBypass = true;
        check (std::fabs (Probe::gainDb (s, fc)) < 0.05, "EQ BYPASS: flat again");
        s.eqBypass = false;
        s.eqGain[MasterSection::kHigh] = 0.5f;
        s.eqGain[MasterSection::kLow] = 0.0f;
        check (std::fabs (Probe::gainDb (s, MasterSection::eqHz (MasterSection::kLow, s.eqFreq[0])) + 15.0) < 0.5, "LOW -15 dB");
        s.eqGain[MasterSection::kLow] = 0.5f;
        s.fader = 1.0f;
        check (std::fabs (Probe::gainDb (s, 1000.0) - 8.0) < 0.1, "fader at 10: +8 dB");
        s.fader = 0.5f;
        check (std::fabs (Probe::gainDb (s, 1000.0) + 10.0) < 0.1, "fader at 5: -10 dB");
        s.fader = 0.75f;
        // MASTER drives the M-50 preamp: clean at nominal, OVERLOAD LED and rounding when pushed
        {
            MasterSection d;
            d.setSampleRate (48000.0);
            d.reset();
            std::vector<float> a (4800), b (4800);
            for (int i = 0; i < 4800; ++i) a[i] = b[i] = (float) (0.4 * std::sin (2.0 * M_PI * 200.0 * i / 48000.0));
            Song q;
            q.setDefaults();
            d.process (&a[0], &b[0], 4800, q);
            double pk = 0.0;
            for (int i = 2400; i < 4800; ++i) pk = std::max (pk, (double) std::fabs (a[i]));
            check (! d.overload () && std::fabs (pk - 0.4) < 0.005, "MASTER at nominal: clean, no OVERLOAD");
            q.master = (float) ((18.0 + 15.0) / 40.0);       // +18 dB
            for (int i = 0; i < 4800; ++i) a[i] = b[i] = (float) (0.6 * std::sin (2.0 * M_PI * 200.0 * i / 48000.0));
            d.reset();
            d.process (&a[0], &b[0], 4800, q);
            pk = 0.0;
            for (int i = 2400; i < 4800; ++i) pk = std::max (pk, (double) std::fabs (a[i]));
            const double clean = 0.6 * std::pow (10.0, 18.0 / 20.0);
            char m2[120];
            std::snprintf (m2, sizeof (m2), "MASTER +18 dB: OVERLOAD lights, peaks rounded (%.2f instead of %.2f)", pk, clean);
            check (d.overload () && pk < clean * 0.95 && pk > 1.9, m2);
            check (std::fabs (MasterSection::driveDb (0.375) - 0.0) < 1e-9 && std::fabs (MasterSection::driveDb (1.0) - 25.0) < 1e-9, "MASTER range -15..+25 dB, 0 dB at 3.75");
        }
        MasterSection m;
        m.setSampleRate (48000.0);
        m.reset();
        std::vector<float> L (48000), R (48000);
        const double amp = 0.125892541 * std::sqrt (2.0);     // -18 dBFS rms
        for (int i = 0; i < 48000; ++i) { L[i] = (float) (amp * std::sin (2.0 * M_PI * 1000.0 * i / 48000.0)); R[i] = L[i] * 0.5f; }
        m.process (&L[0], &R[0], 48000, s);
        std::snprintf (msg, sizeof (msg), "VU: -18 dBFS rms reads 0 VU (L %.2f), half level reads -6 (R %.2f)", m.vuDb (0), m.vuDb (1));
        check (std::fabs (m.vuDb (0)) < 0.2 && std::fabs (m.vuDb (1) + 6.0) < 0.2, msg);
    }

    std::printf ("WAV export\n");
    {
        Song s;
        s.setDefaults();
        for (int k = 0; k < 16; k += 2) setStep (s.patterns[0], 7, k);
        s.numEntries = 2;
        s.entries[0].pattern = 0; s.entries[0].repeats = 1;
        s.entries[1].pattern = 0; s.entries[1].repeats = 2;
        ExportRange r = { true, 0, 1 };
        const char* path = "/tmp/tbdm_test.wav";
        long frames = 0;
        check (exportWav (path, s, kb, r, 44100, 3.0, &frames), "write");
        // 3 bars of 2 s plus a short tail of the last hat
        check (frames >= 6 * 44100 && frames < 6 * 44100 + 44100, "length: the song plus its tail");
        float* d = 0;
        int nf = 0;
        double rate = 0;
        check (readWav (path, d, nf, rate) && nf == frames && rate == 44100.0, "reads back as 44.1 kHz");
        double e = 0.0;
        for (int i = 0; i < nf; ++i) e += d[i] * d[i];
        check (e > 1.0, "has sound");
        delete[] d;
        std::remove (path);
    }

    std::printf ("Separate tracks\n");
    {
        Song s;
        s.setDefaults();
        s.channels[0].level = 0.5f;      // quiet enough that the sidecar stays clean
        s.channels[7].level = 0.5f;
        for (int k = 0; k < 16; k += 4) setStep (s.patterns[0], 0, k);
        setStep (s.patterns[0], 7, 2, 1);
        setStep (s.patterns[0], 6, 12, 0);
        s.channels[7].pan = -0.6f;       // the mix is panned; the mono track isn't
        s.channels[6].mute = true;       // muted in the mix, but still gets its own track
        ExportRange r = { false, 0, 2 };
        const char* dir = "/tmp/tbdm_tracks";
        mkdir (dir, 0755);
        const int order[kNumPads] = { 0, 1, 7, 4, 3, 10, 2, 8, 9, 6, 5 };
        long frames = 0;
        const int n = exportWavTracks (dir, s, kb, r, 44100, 2.0, order, &frames);
        check (n == 3, "three pads play: three tracks");
        float *a = 0, *b = 0, *c = 0;
        int na = 0, nb = 0, nc = 0;
        double ra, rb, rc;
        const bool ok = readWav ("/tmp/tbdm_tracks/01 KICK.wav", a, na, ra) && readWav ("/tmp/tbdm_tracks/02 HI-HAT.wav", b, nb, rb)
                        && readWav ("/tmp/tbdm_tracks/03 CLAP-TAMB.wav", c, nc, rc);
        check (ok, "named 01 KICK, 02 HI-HAT, 03 CLAP-TAMB in panel order");
        check (ok && na == frames && nb == frames && nc == frames, "every track as long as the mix");
        FILE* tf = std::fopen ("/tmp/tbdm_tracks/01 KICK.wav", "rb");
        unsigned char hdr[44];
        const bool mono = tf && std::fread (hdr, 1, 44, tf) == 44 && hdr[22] == 1 && hdr[34] == 24;
        if (tf) std::fclose (tf);
        check (mono, "tracks are 24-bit mono");
        // the unmuted tracks add up to the mix (levels low enough that the limiter stays out)
        s.channels[6].mute = false;
        s.channels[6].level = 0.0f;
        s.channels[7].pan = 0.0f;
        exportWav ("/tmp/tbdm_tracks/mix.wav", s, kb, r, 44100, 2.0);
        float* m = 0;
        int nm = 0;
        double rm;
        double err = 0.0, tot = 0.0;
        if (ok && readWav ("/tmp/tbdm_tracks/mix.wav", m, nm, rm))
            for (int i = 0; i < nm && i < na; ++i) { err += std::fabs (m[i] - (a[i] + b[i])); tot += std::fabs (m[i]); }
        check (tot > 1.0 && err / tot < 0.001, "kick + hat tracks sum to the mix");
        delete[] a; delete[] b; delete[] c; delete[] m;
        std::system ("rm -rf /tmp/tbdm_tracks");
    }

    std::printf ("WAV reading\n");
    {
        // 16-bit stereo and 32-bit float mono images built in memory
        unsigned char img[44 + 8];
        std::memset (img, 0, sizeof (img));
        std::memcpy (img, "RIFF", 4);
        img[4] = 44;
        std::memcpy (img + 8, "WAVEfmt ", 8);
        img[16] = 16; img[20] = 1; img[22] = 2;
        img[24] = 0x80; img[25] = 0xBB;   // 48000
        img[34] = 16;
        std::memcpy (img + 36, "data", 4);
        img[40] = 8;
        // frame 0: L = 16384, R = 0 ; frame 1: L = -32768, R = -32768
        img[45] = 0x40; img[50] = 0x00; img[51] = 0x80; img[48] = 0x00; img[49] = 0x80;
        float* d = 0;
        int n = 0;
        double r = 0;
        check (parseWav (img, sizeof (img), d, n, r) && n == 2 && r == 48000.0 && std::fabs (d[0] - 0.25f) < 1e-6f && std::fabs (d[1] + 1.0f) < 1e-6f,
               "16-bit stereo mixed to mono");
        delete[] d;
        check (! parseWav (img, 20, d, n, r), "truncated file refused");
    }

    std::printf ("Stability\n");
    {
        Engine e (&kb);
        e.setSampleRate (96000.0);
        unsigned seed = 7;
        for (int p = 0; p < kNumPatterns; ++p)
        {
            Pattern& P = e.song().patterns[p];
            P.kit = p % 3;
            P.length = 1 + (int) ((seed = seed * 1103515245u + 12345u) >> 16) % 32;
            for (int t = 0; t < kNumTracks; ++t)
            {
                P.tracks[t].length = 1 + (int) ((seed = seed * 1103515245u + 12345u) >> 16) % 32;
                for (int k = 0; k < kMaxSteps; ++k)
                    if (((seed = seed * 1103515245u + 12345u) >> 16) % 3 == 0)
                        setStep (P, t, k, (seed >> 3) & 1, (seed >> 5) % 3, 1 + (seed >> 9) % 4);
            }
        }
        for (int c = 0; c < kNumPads; ++c) { e.song().channels[c].tune = -12.0f + 3.0f * c; e.song().channels[c].decay = 0.1f * c; }
        e.song().channels[2].level = 1.0f;
        for (int i = 0; i < kNumPatterns; ++i) { e.song().entries[i].pattern = i; e.song().entries[i].repeats = 1 + i % 3; }
        e.song().numEntries = kNumPatterns;
        e.setSongMode (true);
        e.song().tempo = 300.0f;
        e.song().swing = 0.5f;
        e.play();
        std::vector<float> L (512), R (512);
        bool finite = true;
        float peak = 0.0f;
        const clock_t c0 = std::clock();
        const int blocks = (int) (60.0 * 96000.0 / 256);
        long total = 0;
        for (int b = 0; b < blocks; ++b)
        {
            const int n = 1 + (b * 37) % 512;
            e.render (&L[0], &R[0], n);
            total += n;
            if (b % 50 == 0) { e.lock(); e.hitPad (b % kNumPads, b & 1, b % 3, (b & 4) != 0); e.unlock(); }
            for (int i = 0; i < n; ++i)
            {
                finite = finite && L[i] == L[i] && R[i] == R[i] && std::fabs (L[i]) <= 1.0f && std::fabs (R[i]) <= 1.0f;
                peak = std::max (peak, std::fabs (L[i]));
            }
        }
        const double cpu = (double) (std::clock() - c0) / CLOCKS_PER_SEC;
        std::printf ("  (%.1f s of dense 96 kHz audio in %.2f s CPU, peak %.2f)\n", total / 96000.0, cpu, peak);
        check (finite, "random patterns at 300 BPM, full swing, odd blocks: finite, within +-1");
        check (e.hitsFired() > 1000, "lots of hits fired");
    }

    // The user's own kits, when available
    const char* real = std::getenv ("TBDM_TEST_KITS");
    if (real && *real)
    {
        std::printf ("Real kits from %s\n", real);
        KitBank rk;
        const int n = rk.load (real);
        char msg[128];
        std::snprintf (msg, sizeof (msg), "loaded %d of 41 samples (707 %d, CR-78 %d, LM-1 %d)", n,
                       rk.samplesLoaded (0), rk.samplesLoaded (1), rk.samplesLoaded (2));
        check (n == 41, msg);
        if (! renders.empty())
        {
            for (int k = 0; k < kNumKits; ++k)
            {
                Song s;
                s.setDefaults();
                s.tempo = 112.0f;
                Pattern& P = s.patterns[0];
                P.kit = k;
                setStep (P, 0, 0); setStep (P, 0, 6); setStep (P, 0, 10);
                setStep (P, 1, 4); setStep (P, 1, 12, 1, 1);
                for (int q = 0; q < 16; q += 2) setStep (P, 7, q, q == 14 ? 1 : 0);
                setStep (P, 7, 15, 0, 0, 2);
                setStep (P, 6, 12, 0);
                setStep (P, 2, 13, 0, 1); setStep (P, 3, 14); setStep (P, 4, 15);
                setStep (P, 8, 0);
                setStep (P, kAccentTrack, 0); setStep (P, kAccentTrack, 12);
                ExportRange r = { false, 0, 4 };
                const std::string path = renders + "/demo_" + std::string (k == 0 ? "707" : (k == 1 ? "CR78" : "LM1")) + ".wav";
                long frames = 0;
                check (exportWav (path.c_str(), s, rk, r, 44100, 3.0, &frames), ("render " + path).c_str());
            }
        }
    }

    std::printf (failures ? "\n%d FAILED\n" : "\nAll engine tests passed\n", failures);
    return failures ? 1 : 0;
}
