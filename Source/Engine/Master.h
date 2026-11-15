// Master.h: the M-50 Master sidecar on the drum machine's stereo output.
// From the approved TB M50 Dual Channel Strip: the drum machine's MASTER knob
// drives the M-50 preamp (like the strip's TRIM on LINE, -15..+25 dB, 0 dB at
// 0.375), whose op-amps round the peaks just before the OVERLOAD LED lights (25 dB
// over nominal, held 120 ms); then the three-section sweep EQ
// (LOW 50 Hz-1 kHz, MID 500 Hz-5 kHz, HIGH 2.5-15 kHz, +-15 dB, Q 0.9) with EQ
// BYPASS, then the STEREO MASTER fader (M-50 law: 7.5 = 0 dB, 10 = +8 dB), and
// L / R VU meters (0 VU = a -18 dBFS rms sine, 300 ms ballistics).

#ifndef TBDM_MASTER_H
#define TBDM_MASTER_H

namespace tbdm
{

struct Song;

class MasterSection
{
public:
    enum { kLow = 0, kMid = 1, kHigh = 2, kNumBands = 3 };
    MasterSection();
    void setSampleRate (double sr);
    void reset();
    // In place, with the settings in s (eqFreq, eqGain, eqBypass, fader)
    void process (float* L, float* R, int n, const Song& s);
    float vuDb (int ch) const;        // VU reading, dB re 0 VU (-60 when silent)
    bool overload() const { return olCount > 0; }   // OVERLOAD LED
    static double driveDb (double v);             // MASTER 0..1 -> -15..+25 dB

    static double eqHz (int band, double v);      // 0..1 over the band's sweep
    static double eqDb (double v);                // 0..1 -> -15..+15 dB (0.5 flat)
    static double faderDb (double v);             // 0..1 = marks 0..10

private:
    struct Bq { double b0, b1, b2, a1, a2; double z1[2], z2[2]; };
    double fs;
    Bq eq[kNumBands];
    float lastF[kNumBands], lastG[kNumBands];
    double byp;           // 0 = EQ in, 1 = bypassed (crossfades)
    double gain;          // master fader gain (smoothed)
    double vuA[2], vuB[2], vuK;
    double drive;         // MASTER drive gain (smoothed)
    int olCount, olHold;
    void design (int band, double f, double db);
};

} // namespace tbdm

#endif
