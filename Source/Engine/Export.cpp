// Export.cpp

#include "Export.h"
#include "Wav.h"

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>
#include <string>
#include <algorithm>

namespace tbdm
{

//==============================================================================
// Session text file

char encodeStep (const Step& s)
{
    if (! s.on) return '.';
    int sub = s.sub < 1 ? 1 : (s.sub > 4 ? 4 : s.sub);
    int v = 1 | ((s.choice & 1) << 1) | ((s.flam > 2 ? 0 : s.flam) << 2) | ((sub - 1) << 4);
    return (char) ('0' + v);
}

Step decodeStep (char c)
{
    Step s;
    s.on = 0;
    s.choice = 0;
    s.flam = 0;
    s.sub = 1;
    const int v = (int) c - '0';
    if (c == '.' || v < 0 || v > 63 || ! (v & 1)) return s;
    s.on = 1;
    s.choice = (unsigned char) ((v >> 1) & 1);
    s.flam = (unsigned char) ((v >> 2) & 3);
    if (s.flam > 2) s.flam = 0;
    s.sub = (unsigned char) (((v >> 4) & 3) + 1);
    return s;
}

static float clampf (float v, float lo, float hi)
{
    if (v != v) return lo;
    return v < lo ? lo : (v > hi ? hi : v);
}

static int clampi (int v, int lo, int hi) { return v < lo ? lo : (v > hi ? hi : v); }

bool saveSession (const char* path, const Song& s, const SessionState& st)
{
    char tmp[2100];
    std::snprintf (tmp, sizeof (tmp), "%s.tmp", path);
    FILE* f = std::fopen (tmp, "w");
    if (! f) return false;
    std::fprintf (f, "TB Drum Machine 2\n");
    std::fprintf (f, "tempo %.3f\nswing %.4f\naccent %.4f\nmaster %.4f\n", s.tempo, s.swing, s.accent, s.master);
    std::fprintf (f, "songname %s\n", s.name);
    std::fprintf (f, "current %d\nsongmode %d\nsync %d\npage %d\n", st.currentPattern, st.songMode ? 1 : 0,
                  st.externalSync ? 1 : 0, st.page);
    for (int c = 0; c < kNumPads; ++c)
    {
        const Channel& ch = s.channels[c];
        std::fprintf (f, "channel %d %.4f %.4f %.4f %.4f %d %d\n", c, ch.level, ch.pan, ch.tune, ch.decay,
                      ch.mute ? 1 : 0, ch.solo ? 1 : 0);
    }
    for (int p = 0; p < kNumPatterns; ++p)
    {
        const Pattern& P = s.patterns[p];
        std::fprintf (f, "pattern %d %d %d\n", p, P.kit, P.length);
        std::fprintf (f, "name %s\n", P.name);
        for (int t = 0; t < kNumTracks; ++t)
        {
            char line[kMaxSteps + 1];
            for (int k = 0; k < kMaxSteps; ++k) line[k] = encodeStep (P.tracks[t].steps[k]);
            line[kMaxSteps] = 0;
            std::fprintf (f, "track %d %d %s\n", t, P.tracks[t].length, line);
        }
    }
    std::fprintf (f, "song %d\n", s.numEntries);
    for (int i = 0; i < s.numEntries; ++i)
        std::fprintf (f, "entry %d %d\n", s.entries[i].pattern, s.entries[i].repeats);
    std::fprintf (f, "end\n");
    const bool ok = std::ferror (f) == 0;
    std::fclose (f);
    if (! ok) { std::remove (tmp); return false; }
    return std::rename (tmp, path) == 0;
}

bool loadSession (const char* path, Song& out, SessionState& st)
{
    FILE* f = std::fopen (path, "r");
    if (! f) return false;
    char line[512];
    if (! std::fgets (line, sizeof (line), f) || std::strncmp (line, "TB Drum Machine", 15) != 0)
    {
        std::fclose (f);
        return false;
    }
    int version = 1;
    std::sscanf (line, "TB Drum Machine %d", &version);
    Song s;
    s.setDefaults();
    SessionState ss;
    int curP = -1;
    bool sawEnd = false;
    while (std::fgets (line, sizeof (line), f))
    {
        line[sizeof (line) - 1] = 0;
        char* nl = std::strchr (line, '\n');
        if (nl) *nl = 0;
        nl = std::strchr (line, '\r');
        if (nl) *nl = 0;
        float a, b, c, d;
        int i, j, k, m, n;
        char buf[64];
        if (std::sscanf (line, "tempo %f", &a) == 1) s.tempo = clampf (a, 30.0f, 300.0f);
        else if (std::sscanf (line, "swing %f", &a) == 1) s.swing = clampf (a, 0.0f, 0.5f);
        else if (std::sscanf (line, "accent %f", &a) == 1) s.accent = clampf (a, 0.0f, 1.0f);
        else if (std::sscanf (line, "master %f", &a) == 1) s.master = clampf (a, 0.0f, 1.0f);
        else if (std::sscanf (line, "current %d", &i) == 1) ss.currentPattern = clampi (i, 0, kNumPatterns - 1);
        else if (std::sscanf (line, "songmode %d", &i) == 1) ss.songMode = i != 0;
        else if (std::sscanf (line, "sync %d", &i) == 1) ss.externalSync = i != 0;
        else if (std::sscanf (line, "page %d", &i) == 1) ss.page = clampi (i, 0, 3);
        else if (std::sscanf (line, "channel %d %f %f %f %f %d %d", &i, &a, &b, &c, &d, &m, &n) == 7)
        {
            if (i < 0 || i >= kNumPads) continue;
            Channel& ch = s.channels[i];
            ch.level = clampf (a, 0.0f, 1.0f);
            ch.pan = clampf (b, -1.0f, 1.0f);
            ch.tune = clampf (c, -12.0f, 12.0f);
            ch.decay = clampf (d, 0.0f, 1.0f);
            ch.mute = m != 0;
            ch.solo = n != 0;
        }
        else if (std::sscanf (line, "pattern %d %d %d", &i, &j, &k) == 3)
        {
            curP = (i >= 0 && i < kNumPatterns) ? i : -1;
            if (curP >= 0)
            {
                s.patterns[curP].kit = clampi (j, 0, kNumKits - 1);
                s.patterns[curP].length = clampi (k, 1, kMaxSteps);
            }
        }
        else if (std::strncmp (line, "songname ", 9) == 0)
        {
            std::memset (s.name, 0, kNameLen);
            size_t len = std::strlen (line + 9);
            if (len > 40) len = 40;
            std::memcpy (s.name, line + 9, len);
        }
        else if (std::strncmp (line, "name ", 5) == 0 && curP >= 0)
        {
            std::memset (s.patterns[curP].name, 0, kNameLen);
            size_t len = std::strlen (line + 5);
            if (len > 40) len = 40;
            std::memcpy (s.patterns[curP].name, line + 5, len);
        }
        else if (std::sscanf (line, "track %d %d %63s", &i, &j, buf) == 3 && curP >= 0)
        {
            if (version < 2 && i == 10) i = kAccentTrack;     // version 1 had ten pads, accent was track 10
            if (i < 0 || i >= kNumTracks) continue;
            Track& T = s.patterns[curP].tracks[i];
            T.length = clampi (j, 1, kMaxSteps);
            const int len = (int) std::strlen (buf);
            for (int q = 0; q < kMaxSteps; ++q) T.steps[q] = decodeStep (q < len ? buf[q] : '.');
        }
        else if (std::sscanf (line, "song %d", &i) == 1) s.numEntries = 0;
        else if (std::sscanf (line, "entry %d %d", &i, &j) == 2)
        {
            if (s.numEntries < kMaxSong)
            {
                s.entries[s.numEntries].pattern = clampi (i, 0, kNumPatterns - 1);
                s.entries[s.numEntries].repeats = clampi (j, 1, 16);
                ++s.numEntries;
            }
        }
        else if (std::strcmp (line, "end") == 0) { sawEnd = true; break; }
    }
    std::fclose (f);
    if (! sawEnd) return false;     // half-written file: keep what we have
    out = s;
    st = ss;
    return true;
}

//==============================================================================
// Export ranges

int exportPatternCount (const Song& s, const ExportRange& r)
{
    if (r.wholeSong && s.numEntries > 0)
    {
        int n = 0;
        for (int i = 0; i < s.numEntries; ++i) n += s.entries[i].repeats;
        return n;
    }
    return r.loops < 1 ? 1 : r.loops;
}

// The pattern played at the n-th pattern play of the range
static int patternAt (const Song& s, const ExportRange& r, int n)
{
    if (r.wholeSong && s.numEntries > 0)
    {
        for (int i = 0; i < s.numEntries; ++i)
        {
            if (n < s.entries[i].repeats) return s.entries[i].pattern;
            n -= s.entries[i].repeats;
        }
        return s.entries[s.numEntries - 1].pattern;
    }
    return clampi (r.pattern, 0, kNumPatterns - 1);
}

//==============================================================================
// MIDI

struct MidiEv
{
    long tick;
    int order;      // note-offs before note-ons at the same tick
    unsigned char a, b, c;
};

static bool evLess (const MidiEv& x, const MidiEv& y)
{
    if (x.tick != y.tick) return x.tick < y.tick;
    return x.order < y.order;
}

static void putVar (std::vector<unsigned char>& v, unsigned long x)
{
    unsigned char tmp[5];
    int n = 0;
    tmp[n++] = (unsigned char) (x & 0x7F);
    while (x >>= 7) tmp[n++] = (unsigned char) ((x & 0x7F) | 0x80);
    while (n) v.push_back (tmp[--n]);
}

bool exportMidi (const char* path, const Song& s, const ExportRange& r)
{
    const int ppqn = 96;
    const int perStep = ppqn / 4;   // 16th notes
    std::vector<MidiEv> ev;
    long base = 0;
    const int plays = exportPatternCount (s, r);
    const double sw = clampf (s.swing, 0.0f, 0.5f);
    for (int n = 0; n < plays; ++n)
    {
        const Pattern& P = s.patterns[patternAt (s, r, n)];
        const int Lp = clampi (P.length, 1, kMaxSteps);
        const KitDef& kd = kitDef (P.kit);
        for (int k = 0; k < Lp; ++k)
        {
            const double st = stepStart (k, Lp, sw);
            const double dur = stepStart (k + 1, Lp, sw) - st;
            const Track& AT = P.tracks[kAccentTrack];
            const bool acc = AT.steps[k % clampi (AT.length, 1, kMaxSteps)].on != 0;
            for (int t = 0; t < kNumPads; ++t)
            {
                const Track& T = P.tracks[t];
                const Step& stp = T.steps[k % clampi (T.length, 1, kMaxSteps)];
                if (! stp.on || kd.pads[t].numChoices == 0) continue;
                const int ch = stp.choice < kd.pads[t].numChoices ? stp.choice : 0;
                const int note = kd.pads[t].midiNote[ch];
                if (note <= 0) continue;
                const int sub = clampi (stp.sub, 1, 4);
                for (int j = 0; j < sub; ++j)
                {
                    const long tk = base + (long) std::floor ((st + dur * j / sub) * perStep + 0.5);
                    const long len = (long) (dur * perStep / sub * 0.5) < 1 ? 1 : (long) (dur * perStep / sub * 0.5);
                    MidiEv on = { tk, 1, 0x99, (unsigned char) note, (unsigned char) (acc ? kVelAccent : kVelNormal) };
                    MidiEv off = { tk + len, 0, 0x89, (unsigned char) note, 64 };
                    ev.push_back (on);
                    ev.push_back (off);
                }
            }
        }
        base += (long) Lp * perStep;
    }
    std::stable_sort (ev.begin(), ev.end(), evLess);

    std::vector<unsigned char> trk;
    // tempo, time signature, track name
    const unsigned long uspq = (unsigned long) (60000000.0 / clampf (s.tempo, 30.0f, 300.0f) + 0.5);
    const unsigned char tempoEv[] = { 0x00, 0xFF, 0x51, 0x03, (unsigned char) (uspq >> 16), (unsigned char) (uspq >> 8), (unsigned char) uspq };
    trk.insert (trk.end(), tempoEv, tempoEv + sizeof (tempoEv));
    const unsigned char sig[] = { 0x00, 0xFF, 0x58, 0x04, 0x04, 0x02, 0x18, 0x08 };
    trk.insert (trk.end(), sig, sig + sizeof (sig));
    const char* nm = "TB Drum Machine";
    trk.push_back (0x00);
    trk.push_back (0xFF);
    trk.push_back (0x03);
    trk.push_back ((unsigned char) std::strlen (nm));
    trk.insert (trk.end(), nm, nm + std::strlen (nm));

    long last = 0;
    for (size_t i = 0; i < ev.size(); ++i)
    {
        putVar (trk, (unsigned long) (ev[i].tick - last));
        last = ev[i].tick;
        trk.push_back (ev[i].a);
        trk.push_back (ev[i].b);
        trk.push_back (ev[i].c);
    }
    // end of track at the end of the last pattern
    putVar (trk, (unsigned long) (base > last ? base - last : 0));
    trk.push_back (0xFF);
    trk.push_back (0x2F);
    trk.push_back (0x00);

    FILE* f = std::fopen (path, "wb");
    if (! f) return false;
    const unsigned char hdr[] = { 'M', 'T', 'h', 'd', 0, 0, 0, 6, 0, 0, 0, 1, (unsigned char) (ppqn >> 8), (unsigned char) ppqn };
    std::fwrite (hdr, 1, sizeof (hdr), f);
    const unsigned long tl = (unsigned long) trk.size();
    const unsigned char th[] = { 'M', 'T', 'r', 'k', (unsigned char) (tl >> 24), (unsigned char) (tl >> 16), (unsigned char) (tl >> 8), (unsigned char) tl };
    std::fwrite (th, 1, sizeof (th), f);
    std::fwrite (&trk[0], 1, trk.size(), f);
    const bool ok = std::ferror (f) == 0;
    std::fclose (f);
    return ok;
}

//==============================================================================
// WAV

// Renders the range offline into L/R. onlyPad: -1 = the mix, else that pad
// alone. fixedFrames > 0: exactly that long; otherwise until the tail dies away.
static long renderRange (const Song& song, const KitBank& kits, const ExportRange& r, int rate, double tailSeconds,
                         int onlyPad, long fixedFrames, std::vector<float>& L, std::vector<float>& R)
{
    Engine* e = new Engine (&kits);
    e->setSampleRate (rate);
    e->song() = song;
    e->setOnlyPad (onlyPad);
    const bool whole = r.wholeSong && song.numEntries > 0;
    e->setSongMode (whole);
    if (! whole) e->selectPattern (clampi (r.pattern, 0, kNumPatterns - 1));
    e->setStopAfterPatterns (exportPatternCount (song, r));
    e->play();

    double steps = 0.0;
    for (int n = 0; n < exportPatternCount (song, r); ++n)
        steps += clampi (song.patterns[patternAt (song, r, n)].length, 1, kMaxSteps);
    const double secs = steps * 15.0 / clampf (song.tempo, 30.0f, 300.0f);
    const long maxFrames = fixedFrames > 0 ? fixedFrames : (long) ((secs + tailSeconds) * rate) + 4096;
    L.assign ((size_t) maxFrames, 0.0f);
    R.assign ((size_t) maxFrames, 0.0f);

    const int block = 256;
    long done = 0;
    long silentRun = 0;
    while (done < maxFrames)
    {
        const int n = (int) std::min ((long) block, maxFrames - done);
        e->render (&L[(size_t) done], &R[(size_t) done], n);
        done += n;
        if (fixedFrames <= 0 && e->sequencerFinished())
        {
            float peak = 0.0f;
            for (int i = 0; i < n; ++i) peak = std::max (peak, std::max (std::fabs (L[(size_t) (done - n + i)]), std::fabs (R[(size_t) (done - n + i)])));
            silentRun = (peak < 1e-5f || e->voicesSilent()) ? silentRun + n : 0;
            if (e->voicesSilent() || silentRun > rate / 10) break;
        }
    }
    delete e;
    return done;
}

bool exportWav (const char* path, const Song& song, const KitBank& kits, const ExportRange& r,
                int rate, double tailSeconds, long* framesOut)
{
    std::vector<float> L, R;
    const long done = renderRange (song, kits, r, rate, tailSeconds, -1, 0, L, R);
    if (framesOut) *framesOut = done;
    return writeWav24 (path, &L[0], &R[0], done, rate);
}

// Does this pad play anywhere in the range (a step on, in its track, in a kit that has it)?
static bool padPlays (const Song& s, const KitBank& kits, const ExportRange& r, int pad)
{
    for (int n = 0; n < exportPatternCount (s, r); ++n)
    {
        const Pattern& P = s.patterns[patternAt (s, r, n)];
        if (! kits.padAvailable (P.kit, pad)) continue;
        const Track& T = P.tracks[pad];
        const int tl = clampi (T.length, 1, kMaxSteps);
        const int Lp = clampi (P.length, 1, kMaxSteps);
        for (int k = 0; k < Lp; ++k)
            if (T.steps[k % tl].on) return true;
    }
    return false;
}

int exportWavTracks (const char* dir, const Song& song, const KitBank& kits, const ExportRange& r,
                     int rate, double tailSeconds, const int* order, long* framesOut)
{
    // the mix sets the length every track gets
    std::vector<float> L, R;
    const long frames = renderRange (song, kits, r, rate, tailSeconds, -1, 0, L, R);
    if (framesOut) *framesOut = frames;

    // names from the kit, when the whole range uses one kit
    int kit = -1;
    bool oneKit = true;
    for (int n = 0; n < exportPatternCount (song, r); ++n)
    {
        const int k = song.patterns[patternAt (song, r, n)].kit;
        if (kit < 0) kit = k;
        else if (k != kit) oneKit = false;
    }
    static const char* const generic[kNumPads] = { "KICK", "SNARE", "LOW TOM", "MID TOM", "HI TOM", "RIM-COW", "CLAP-TAMB",
                                                   "HI-HAT", "CRASH", "RIDE", "MID TOM 2" };
    int written = 0;
    for (int i = 0; i < kNumPads; ++i)
    {
        const int pad = order ? order[i] : i;
        if (pad < 0 || pad >= kNumPads || ! padPlays (song, kits, r, pad)) continue;
        std::string name = (oneKit && kit >= 0 && kitDef (kit).pads[pad].numChoices > 0) ? kitDef (kit).pads[pad].label : generic[pad];
        // "CLAP / TAMB" -> "CLAP-TAMB" (no slashes in file names)
        std::string clean;
        for (size_t c = 0; c < name.size(); ++c)
        {
            if (name[c] == '/') { while (! clean.empty() && clean[clean.size() - 1] == ' ') clean.erase (clean.size() - 1); clean += '-'; while (c + 1 < name.size() && name[c + 1] == ' ') ++c; }
            else clean += name[c];
        }
        // mono: the pad centred (pan is for the stereo mix; at centre both sides
        // carry the pad at its full level), written as one channel
        Song solo = song;
        solo.channels[pad].pan = 0.0f;
        renderRange (solo, kits, r, rate, tailSeconds, pad, frames, L, R);
        char path[2300];
        std::snprintf (path, sizeof (path), "%s/%02d %s.wav", dir, written + 1, clean.c_str());
        if (! writeWav24 (path, &L[0], 0, frames, rate)) return -1;
        ++written;
    }
    return written;
}

} // namespace tbdm
