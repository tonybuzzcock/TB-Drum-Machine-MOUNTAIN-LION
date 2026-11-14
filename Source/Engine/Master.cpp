// Master.cpp

#include "Master.h"
#include "Engine.h"

#include <cmath>

namespace tbdm
{

namespace
{
    const double kPi = 3.14159265358979323846;
    const double kEqRangeDb = 15.0;
    const double kEqLo[3] = { 50.0, 500.0, 2500.0 };
    const double kEqHi[3] = { 1000.0, 5000.0, 15000.0 };
    const double kEqQ = 0.9;                 // the M-50's bell width
    const double kVuTauS = 0.065;            // two poles: about 300 ms, as a VU
    const double kZeroVuRms = 0.125892541;   // -18 dBFS rms = 0 VU
    const double kFaderMarks[7] = { 0.0, 0.5, 1.0, 2.5, 5.0, 7.5, 10.0 };
    const double kFaderDb[7]    = { -200.0, -60.0, -40.0, -25.0, -10.0, 0.0, 8.0 };

    inline double clamp01 (double v) { return v < 0.0 ? 0.0 : (v > 1.0 ? 1.0 : v); }
}

double MasterSection::eqHz (int band, double v)
{
    if (band < 0) band = 0;
    if (band > 2) band = 2;
    return kEqLo[band] * std::pow (kEqHi[band] / kEqLo[band], clamp01 (v));
}

double MasterSection::eqDb (double v) { return (clamp01 (v) * 2.0 - 1.0) * kEqRangeDb; }

double MasterSection::faderDb (double v)
{
    const double m = clamp01 (v) * 10.0;
    if (m <= 0.0) return -200.0;
    for (int k = 1; k < 7; ++k)
        if (m <= kFaderMarks[k])
        {
            const double t = (m - kFaderMarks[k - 1]) / (kFaderMarks[k] - kFaderMarks[k - 1]);
            return kFaderDb[k - 1] + t * (kFaderDb[k] - kFaderDb[k - 1]);
        }
    return kFaderDb[6];
}

static double faderGain (double v)
{
    if (v <= 0.0) return 0.0;
    double g = std::pow (10.0, MasterSection::faderDb (v) / 20.0);
    if (v < 0.05) g *= v / 0.05;
    return g;
}

MasterSection::MasterSection() : fs (44100.0), byp (0.0), gain (1.0), vuK (0.0)
{
    reset();
}

void MasterSection::setSampleRate (double sr)
{
    fs = sr > 1000.0 ? sr : 44100.0;
    vuK = 1.0 - std::exp (-1.0 / (kVuTauS * fs));
    for (int b = 0; b < kNumBands; ++b) lastF[b] = lastG[b] = -1.0f;
}

void MasterSection::reset()
{
    for (int b = 0; b < kNumBands; ++b)
    {
        eq[b].b0 = 1.0; eq[b].b1 = eq[b].b2 = eq[b].a1 = eq[b].a2 = 0.0;
        for (int c = 0; c < 2; ++c) { eq[b].z1[c] = 0.0; eq[b].z2[c] = 0.0; }
        lastF[b] = lastG[b] = -1.0f;
    }
    for (int c = 0; c < 2; ++c) { vuA[c] = 0.0; vuB[c] = 0.0; }
    byp = 0.0;
    gain = -1.0;      // jump to the fader on the first block
    vuK = 1.0 - std::exp (-1.0 / (kVuTauS * fs));
}

void MasterSection::design (int band, double f, double db)
{
    if (f > 0.45 * fs) f = 0.45 * fs;
    const double A = std::pow (10.0, db / 40.0);
    const double w0 = 2.0 * kPi * f / fs;
    const double alpha = std::sin (w0) / (2.0 * kEqQ);
    const double c = std::cos (w0);
    const double a0 = 1.0 + alpha / A;
    Bq& q = eq[band];
    q.b0 = (1.0 + alpha * A) / a0;
    q.b1 = (-2.0 * c) / a0;
    q.b2 = (1.0 - alpha * A) / a0;
    q.a1 = (-2.0 * c) / a0;
    q.a2 = (1.0 - alpha / A) / a0;
}

void MasterSection::process (float* L, float* R, int n, const Song& s)
{
    for (int b = 0; b < kNumBands; ++b)
        if (s.eqFreq[b] != lastF[b] || s.eqGain[b] != lastG[b])
        {
            design (b, eqHz (b, s.eqFreq[b]), eqDb (s.eqGain[b]));
            lastF[b] = s.eqFreq[b];
            lastG[b] = s.eqGain[b];
        }
    const double target = faderGain (s.fader);
    if (gain < 0.0) gain = target;
    const double gStep = n > 0 ? (target - gain) / n : 0.0;
    const double bTarget = s.eqBypass ? 1.0 : 0.0;
    const double bStep = n > 0 ? (bTarget - byp) / n : 0.0;
    float* io[2] = { L, R };
    for (int i = 0; i < n; ++i)
    {
        gain += gStep;
        byp += bStep;
        for (int c = 0; c < 2; ++c)
        {
            const double x = io[c][i];
            double y = x;
            for (int b = 0; b < kNumBands; ++b)
            {
                Bq& q = eq[b];
                const double out = q.b0 * y + q.z1[c];
                q.z1[c] = q.b1 * y - q.a1 * out + q.z2[c];
                q.z2[c] = q.b2 * y - q.a2 * out;
                y = out;
            }
            double o = (y * (1.0 - byp) + x * byp) * gain;
            if (o != o) o = 0.0;
            io[c][i] = (float) o;
            const double a = o < 0.0 ? -o : o;
            vuA[c] += (a - vuA[c]) * vuK;
            vuB[c] += (vuA[c] - vuB[c]) * vuK;
        }
    }
    for (int b = 0; b < kNumBands; ++b)
        for (int c = 0; c < 2; ++c)
        {
            if (std::fabs (eq[b].z1[c]) < 1e-20) eq[b].z1[c] = 0.0;
            if (std::fabs (eq[b].z2[c]) < 1e-20) eq[b].z2[c] = 0.0;
        }
}

float MasterSection::vuDb (int ch) const
{
    const double zero = kZeroVuRms * 2.0 * std::sqrt (2.0) / kPi;     // rectified average of a 0 VU sine
    const double v = vuB[ch & 1];
    if (v < 1e-7) return -60.0f;
    const double db = 20.0 * std::log10 (v / zero);
    return (float) (db < -60.0 ? -60.0 : db);
}

} // namespace tbdm
