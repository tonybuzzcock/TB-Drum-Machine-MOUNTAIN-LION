// Wav.cpp

#include "Wav.h"

#include <cstdio>
#include <cstring>
#include <cstdlib>

namespace tbdm
{

static unsigned rd16 (const unsigned char* p) { return (unsigned) p[0] | ((unsigned) p[1] << 8); }
static unsigned rd32 (const unsigned char* p)
{
    return (unsigned) p[0] | ((unsigned) p[1] << 8) | ((unsigned) p[2] << 16) | ((unsigned) p[3] << 24);
}

bool parseWav (const unsigned char* b, long size, float*& data, int& frames, double& rate)
{
    data = 0;
    frames = 0;
    if (size < 12 || std::memcmp (b, "RIFF", 4) != 0 || std::memcmp (b + 8, "WAVE", 4) != 0) return false;

    int format = 0, channels = 0, bits = 0;
    unsigned sr = 0;
    const unsigned char* pcm = 0;
    long pcmBytes = 0;

    long p = 12;
    while (p + 8 <= size)
    {
        const unsigned char* ck = b + p;
        long len = (long) rd32 (ck + 4);
        long body = p + 8;
        if (len < 0 || body + len > size) len = size - body;   // tolerate a short last chunk
        if (std::memcmp (ck, "fmt ", 4) == 0 && len >= 16)
        {
            format = (int) rd16 (b + body);
            channels = (int) rd16 (b + body + 2);
            sr = rd32 (b + body + 4);
            bits = (int) rd16 (b + body + 14);
            if (format == 0xFFFE && len >= 26) format = (int) rd16 (b + body + 24);   // extensible: sub-format
        }
        else if (std::memcmp (ck, "data", 4) == 0)
        {
            pcm = b + body;
            pcmBytes = len;
        }
        p = body + len + (len & 1);
    }

    if (! pcm || channels <= 0 || channels > 16 || sr == 0) return false;
    const bool isFloat = (format == 3);
    if (! isFloat && format != 1) return false;
    if (isFloat && bits != 32 && bits != 64) return false;
    if (! isFloat && bits != 8 && bits != 16 && bits != 24 && bits != 32) return false;

    const int bytesPer = bits / 8;
    const long frameBytes = (long) bytesPer * channels;
    const long n = pcmBytes / frameBytes;
    if (n <= 0) return false;

    float* out = new float[n];
    for (long i = 0; i < n; ++i)
    {
        double sum = 0.0;
        for (int c = 0; c < channels; ++c)
        {
            const unsigned char* q = pcm + i * frameBytes + (long) c * bytesPer;
            double v = 0.0;
            if (isFloat)
            {
                if (bits == 32)
                {
                    unsigned u = rd32 (q);
                    float f;
                    std::memcpy (&f, &u, 4);
                    v = f;
                }
                else
                {
                    unsigned long long u = (unsigned long long) rd32 (q) | ((unsigned long long) rd32 (q + 4) << 32);
                    double d;
                    std::memcpy (&d, &u, 8);
                    v = d;
                }
            }
            else if (bits == 8) v = ((int) q[0] - 128) / 128.0;
            else if (bits == 16) v = (short) rd16 (q) / 32768.0;
            else if (bits == 24)
            {
                int s = (int) (q[0] | (q[1] << 8) | (q[2] << 16));
                if (s & 0x800000) s -= 0x1000000;
                v = s / 8388608.0;
            }
            else v = (int) rd32 (q) / 2147483648.0;
            if (v != v) v = 0.0;
            sum += v;
        }
        out[i] = (float) (sum / channels);
    }
    data = out;
    frames = (int) n;
    rate = (double) sr;
    return true;
}

bool readWav (const char* path, float*& data, int& frames, double& rate)
{
    data = 0;
    frames = 0;
    FILE* f = std::fopen (path, "rb");
    if (! f) return false;
    std::fseek (f, 0, SEEK_END);
    const long size = std::ftell (f);
    std::fseek (f, 0, SEEK_SET);
    if (size <= 12 || size > 512L * 1024 * 1024) { std::fclose (f); return false; }
    unsigned char* buf = new unsigned char[size];
    const bool ok = std::fread (buf, 1, (size_t) size, f) == (size_t) size;
    std::fclose (f);
    bool parsed = ok && parseWav (buf, size, data, frames, rate);
    delete[] buf;
    return parsed;
}

static void wr16 (FILE* f, unsigned v) { unsigned char b[2] = { (unsigned char) v, (unsigned char) (v >> 8) }; std::fwrite (b, 1, 2, f); }
static void wr32 (FILE* f, unsigned v)
{
    unsigned char b[4] = { (unsigned char) v, (unsigned char) (v >> 8), (unsigned char) (v >> 16), (unsigned char) (v >> 24) };
    std::fwrite (b, 1, 4, f);
}

bool writeWav24 (const char* path, const float* L, const float* R, long frames, int rate)
{
    FILE* f = std::fopen (path, "wb");
    if (! f) return false;
    const unsigned dataBytes = (unsigned) (frames * 6);
    std::fwrite ("RIFF", 1, 4, f);
    wr32 (f, 36 + dataBytes);
    std::fwrite ("WAVEfmt ", 1, 8, f);
    wr32 (f, 16);
    wr16 (f, 1);
    wr16 (f, 2);
    wr32 (f, (unsigned) rate);
    wr32 (f, (unsigned) rate * 6);
    wr16 (f, 6);
    wr16 (f, 24);
    std::fwrite ("data", 1, 4, f);
    wr32 (f, dataBytes);

    unsigned char buf[6 * 512];
    long i = 0;
    while (i < frames)
    {
        int n = 0;
        for (; n < 512 && i < frames; ++n, ++i)
        {
            for (int c = 0; c < 2; ++c)
            {
                double v = c == 0 ? L[i] : R[i];
                if (v != v) v = 0.0;
                if (v > 1.0) v = 1.0;
                if (v < -1.0) v = -1.0;
                int s = (int) (v * 8388607.0 + (v >= 0 ? 0.5 : -0.5));
                unsigned char* q = buf + n * 6 + c * 3;
                q[0] = (unsigned char) s;
                q[1] = (unsigned char) (s >> 8);
                q[2] = (unsigned char) (s >> 16);
            }
        }
        std::fwrite (buf, 1, (size_t) n * 6, f);
    }
    const bool ok = std::ferror (f) == 0;
    std::fclose (f);
    return ok;
}

} // namespace tbdm
