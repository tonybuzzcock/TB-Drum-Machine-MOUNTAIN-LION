// Wav.h: read WAV files (PCM 8/16/24/32-bit, 32/64-bit float, mono or more
// channels, mixed to mono) and write 24-bit stereo WAV files.

#ifndef TBDM_WAV_H
#define TBDM_WAV_H

namespace tbdm
{

// On success: data = new float[frames] (caller delete[]s), returns true.
bool readWav (const char* path, float*& data, int& frames, double& rate);

// Parses a WAV image in memory (used by readWav and the tests).
bool parseWav (const unsigned char* bytes, long size, float*& data, int& frames, double& rate);

// 24-bit stereo, samples clipped to +-1. R = 0: a mono file from L.
bool writeWav24 (const char* path, const float* L, const float* R, long frames, int rate);

} // namespace tbdm

#endif
