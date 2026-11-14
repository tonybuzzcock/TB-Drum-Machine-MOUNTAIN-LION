// Export.h: saving and opening sessions, and exporting audio (WAV) and MIDI
// (Standard MIDI File) from patterns or the whole song.

#ifndef TBDM_EXPORT_H
#define TBDM_EXPORT_H

#include "Engine.h"

namespace tbdm
{

// What the app keeps besides the song itself, so it reopens where it was left
struct SessionState
{
    int currentPattern;
    bool songMode;
    bool externalSync;
    int page;
    SessionState() : currentPattern (0), songMode (false), externalSync (false), page (0) {}
};

bool saveSession (const char* path, const Song& song, const SessionState& st);
bool loadSession (const char* path, Song& song, SessionState& st);

// Text form used by save/load (exposed for tests)
char encodeStep (const Step& s);
Step decodeStep (char c);

// Where an export covers
struct ExportRange
{
    bool wholeSong;      // the song once through (falls back to the pattern if the song is empty)
    int pattern;         // otherwise this pattern...
    int loops;           // ...this many times
};

// Number of pattern plays the range covers
int exportPatternCount (const Song& song, const ExportRange& r);

// MIDI: type 0, 96 PPQN, channel 10, General MIDI drum notes; accents at velocity
// 127, other hits 100. Returns false if the file can't be written.
bool exportMidi (const char* path, const Song& song, const ExportRange& r);

// Audio: renders offline with the same engine (24-bit stereo WAV), plus the
// ringing tail of the last hits (up to tailSeconds).
bool exportWav (const char* path, const Song& song, const KitBank& kits, const ExportRange& r,
                int sampleRate, double tailSeconds, long* framesOut = 0);

// Separate tracks: one 24-bit MONO WAV per pad that plays in the range, each
// the full length of the mix (so they line up from bar 1 in a DAW), with the
// pad's level, tune and decay (pan is left to the DAW; only the mix is stereo). Written into dir as "01 KICK.wav" etc.,
// numbered in `order` (pad indices in panel order; 0 = 0..10). Returns the
// number of tracks written, or -1 if a file can't be written.
int exportWavTracks (const char* dir, const Song& song, const KitBank& kits, const ExportRange& r,
                     int sampleRate, double tailSeconds, const int* order = 0, long* framesOut = 0);

} // namespace tbdm

#endif
