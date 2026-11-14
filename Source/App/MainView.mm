// MainView.mm
// TB Drum Machine panel: an original TB design in the user's standard look
// (silver face, black lettering, grey knurled knobs with red lines, switches
// that light up where they're engaged, lime readout, TB electronic logo in the
// strip), laid out after DM2's pages: PADS, STEPS, MIXER, SONG.
// The pads follow the TR-707: ten instruments, with a two-sound choice where the
// 707 has one. Everything is drawn in code; manual retain/release (10.8.5).

#import "MainView.h"

#include "AppCore.h"
#include "TBLogo.h"

#include <cmath>
#include <cstdio>
#include <cstring>
#include <string>

using namespace tbdm;

namespace
{

//------------------------------------------------------------------------------
// Geometry (flipped: y grows down)

const CGFloat W = kFaceWidth;
const CGFloat F = kPanelFrame;
const CGFloat kTopH = 104.0;
const CGFloat kTabY = 114.0, kTabH = 32.0;
const CGFloat kStripTop = 636.0;

const NSRect kPlayRect = { { 20.0, 24.0 }, { 96.0, 52.0 } };
const NSRect kRecRect = { { 126.0, 24.0 }, { 76.0, 52.0 } };
const NSRect kTempoBox = { { 296.0, 30.0 }, { 84.0, 30.0 } };
const NSRect kSyncRect = { { 690.0, 32.0 }, { 112.0, 28.0 } };
const CGFloat kTopKnobY = 46.0, kTopKnobR = 22.0, kCaptionY = 90.0;
const CGFloat kTopKnobX[4] = { 254.0, 440.0, 530.0, 620.0 };   // tempo, swing, accent, master

inline NSRect kitRect (int i) { return NSMakeRect (840.0 + i * 108.0, 26.0, 100.0, 40.0); }
inline NSRect tabRect (int i) { return NSMakeRect (20.0 + i * 122.0, kTabY, 116.0, kTabH); }
const NSRect kTimeRect = { { 520.0, 114.0 }, { 118.0, 32.0 } };     // time signature drop-down
const NSRect kLengthRect = { { 646.0, 114.0 }, { 116.0, 32.0 } };
inline NSRect modeRect (int i) { return NSMakeRect (770.0 + i * 98.0, kTabY, 90.0, kTabH); }

// Every page shows the pads in the user's order: Kick, Snare, Hi-Hat, Hi Tom,
// Mid Tom (1), Mid Tom 2, Low Tom, Crash, Ride, Clap/Tamb, Rim/Cow
// Pad order on every page: Kick, Snare, Hi-Hat, Hi Tom, Mid Tom 1, Mid Tom 2,
// Low Tom, Crash, Ride, Clap/Tamb, Rim/Cow, with any pad the kit doesn't have
// moved to the end (the user's rule: unused slots always last).
const int kBaseOrder[kNumPads] = { 0, 1, 7, 4, 3, 10, 2, 8, 9, 6, 5 };
int gOrder[kNumPads] = { 0, 1, 7, 4, 3, 10, 2, 8, 9, 6, 5 };   // for the kit on show
void setOrderForKit (int kit)
{
    const KitDef& kd = kitDef (kit);
    int n = 0;
    for (int pass = 0; pass < 2; ++pass)
        for (int i = 0; i < kNumPads; ++i)
        {
            const bool used = kd.pads[kBaseOrder[i]].numChoices > 0;
            if (used == (pass == 0)) gOrder[n++] = kBaseOrder[i];
        }
}
inline int padAt (int i) { return gOrder[i]; }
inline int padPos (int pad)
{
    for (int i = 0; i < kNumPads; ++i) if (gOrder[i] == pad) return i;
    return pad;
}

// Steps page
const CGFloat kRowY0 = 184.0, kRowPitch = 36.0, kCellH = 28.0;
const CGFloat kGridX0 = 356.0, kStepPitch = 24.0, kCellW = 21.0;
int gGroup = 4;      // steps per beat in the pattern on show (4, or 6 for 6/8 and 12/8)
inline CGFloat cellX (int k) { return kGridX0 + k * kStepPitch + (k / gGroup) * 3.0; }
inline NSRect cellRect (int row, int k) { return NSMakeRect (cellX (k), kRowY0 + row * kRowPitch + 4.0, kCellW, kCellH); }
inline NSRect rowChoiceRect (int row) { return NSMakeRect (140.0, kRowY0 + row * kRowPitch + 6.0, 94.0, 24.0); }
inline NSRect rowLenRect (int row) { return NSMakeRect (240.0, kRowY0 + row * kRowPitch + 6.0, 58.0, 24.0); }
inline NSRect rowMuteRect (int row) { return NSMakeRect (303.0, kRowY0 + row * kRowPitch + 6.0, 22.0, 24.0); }
inline NSRect rowSoloRect (int row) { return NSMakeRect (328.0, kRowY0 + row * kRowPitch + 6.0, 22.0, 24.0); }
// rows top to bottom (the user's order): Accent, Kick, Snare, Hi-Hat, Hi Tom,
// Mid Tom 1, Mid Tom 2, Low Tom, Crash, Ride, Clap/Tamb, Rim/Cow
inline int rowTrack (int row) { return row == 0 ? kAccentTrack : padAt (row - 1); }

// Pads page
inline NSRect padRect (int pad)
{
    const int i = padPos (pad);
    // six pads on the top row, five below
    const int col = i < 6 ? i : i - 6;
    const CGFloat x0 = i < 6 ? 42.0 : 135.0;
    return NSMakeRect (x0 + col * 186.0, (i < 6 ? 194.0 : 428.0), 166.0, 146.0);
}
inline NSRect padFlamRect (int pad, int i)
{
    const NSRect p = padRect (pad);
    return NSMakeRect (p.origin.x + i * 56.0, NSMaxY (p) + 10.0, 54.0, 24.0);
}

// Mixer page
const CGFloat kMixPitch = 103.0, kMixCx = 48.0;   // eleven channel strips
inline CGFloat mixX (int ch) { return 24.0 + padPos (ch) * kMixPitch; }
const CGFloat kMixTuneY = 238.0, kMixDecayY = 326.0, kMixPanY = 414.0, kMixKnobR = 20.0;
const CGFloat kFaderTop = 458.0, kFaderBot = 582.0;
inline NSRect faderRect (int ch) { return NSMakeRect (mixX (ch) + kMixCx - 16.0, kFaderTop - 10.0, 32.0, kFaderBot - kFaderTop + 20.0); }
inline NSRect mixMuteRect (int ch) { return NSMakeRect (mixX (ch) + 3.0, 596.0, 43.0, 24.0); }
inline NSRect mixSoloRect (int ch) { return NSMakeRect (mixX (ch) + 50.0, 596.0, 43.0, 24.0); }

// Song page
inline NSRect songCell (int i) { return NSMakeRect (24.0 + (i % 8) * 118.0, 170.0 + (i / 8) * 57.0, 112.0, 52.0); }
const NSRect kSongModeRect = { { 990.0, 186.0 }, { 170.0, 30.0 } };
const NSRect kSongAdd = { { 990.0, 232.0 }, { 170.0, 34.0 } };
const NSRect kSongInsert = { { 990.0, 274.0 }, { 170.0, 34.0 } };
const NSRect kSongDelete = { { 990.0, 316.0 }, { 170.0, 34.0 } };
const NSRect kSongPattern = { { 990.0, 382.0 }, { 170.0, 32.0 } };
const NSRect kSongRepeats = { { 990.0, 444.0 }, { 170.0, 32.0 } };
const NSRect kSongStart = { { 990.0, 496.0 }, { 170.0, 34.0 } };
const NSRect kSongClear = { { 990.0, 584.0 }, { 170.0, 34.0 } };

// Strip
const NSRect kLogoBox = { { 14.0, 650.0 }, { 130.0, 72.0 } };
inline NSRect slotRect (int i) { return NSMakeRect (170.0 + i * 36.0, 664.0, 32.0, 28.0); }
inline NSRect patBtnRect (int i) { return NSMakeRect (762.0 + i * 100.0, 664.0, 92.0, 28.0); }
const NSRect kReadout = { { 170.0, 708.0 }, { 640.0, 52.0 } };
const NSRect kExportWav = { { 826.0, 708.0 }, { 160.0, 52.0 } };
const NSRect kExportMidi = { { 996.0, 708.0 }, { 160.0, 52.0 } };

// M-50 Master sidecar (its own face coordinates, 216 wide)
const CGFloat kSW = kSideFaceWidth, kSCx = 108.0;
const NSRect kVuRect[2] = { { { 14.0, 30.0 }, { 88.0, 60.0 } }, { { 114.0, 30.0 }, { 88.0, 60.0 } } };
const NSRect kBypassRect = { { 92.0, 140.0 }, { 32.0, 22.0 } };
const CGFloat kRingR = 31.0, kCapR = 18.0;
inline CGFloat bandY (int b) { return 392.0 - 84.0 * b; }        // LOW 392, MID 308, HIGH 224
const CGFloat kSFaderTop = 492.0, kSFaderBot = 600.0;
inline CGFloat sFaderY (float v) { return kSFaderBot - (kSFaderBot - kSFaderTop) * v; }
inline NSPoint viewToSide (NSPoint vp) { return NSMakePoint (vp.x - kSideX - kPanelFrame, vp.y - kPanelFrame); }
inline NSPoint sideToView (NSPoint sp) { return NSMakePoint (sp.x + kSideX + kPanelFrame, sp.y + kPanelFrame); }
const char* const kBandName[3] = { "LOW", "MID", "HIGH" };
const char* const kBandLo[3] = { "50", "500", "2.5K" };
const char* const kBandHi[3] = { "1K", "5K", "15K" };

enum { kModeStep = 0, kModeChoice, kModeFlam, kModeHits };

// Knob ids
enum { kKTempo = 0, kKSwing = 1, kKAccent = 2, kKMaster = 3, kKTune = 16, kKDecay = 32, kKPan = 48, kKLevel = 64,
       kKEqFreq = 80, kKEqGain = 84, kKFader = 88 };

//------------------------------------------------------------------------------
// Drawing helpers

NSColor* rgb (int r, int g, int b) { return [NSColor colorWithCalibratedRed: r / 255.0 green: g / 255.0 blue: b / 255.0 alpha: 1.0]; }

NSFont* boldFont (CGFloat size)
{
    NSFont* f = [NSFont fontWithName: @"Helvetica-Bold" size: size];
    return f ? f : [NSFont boldSystemFontOfSize: size];
}

NSFont* plainFont (CGFloat size)
{
    NSFont* f = [NSFont fontWithName: @"Helvetica" size: size];
    return f ? f : [NSFont systemFontOfSize: size];
}

NSDictionary* attrs (NSFont* font, NSColor* color)
{
    return [NSDictionary dictionaryWithObjectsAndKeys: font, NSFontAttributeName, color, NSForegroundColorAttributeName, nil];
}

NSString* str (const char* s)
{
    NSString* x = [NSString stringWithUTF8String: s ? s : ""];
    return x ? x : @"";
}

// align: 0 left, 0.5 centre, 1 right (at x)
void drawText (const char* s, NSFont* font, NSColor* color, CGFloat x, CGFloat cy, CGFloat align = 0.5)
{
    NSDictionary* a = attrs (font, color);
    NSString* t = str (s);
    const NSSize sz = [t sizeWithAttributes: a];
    [t drawAtPoint: NSMakePoint (x - sz.width * align, cy - sz.height * 0.5) withAttributes: a];
}

CGFloat textWidth (const char* s, NSFont* font)
{
    return [str (s) sizeWithAttributes: attrs (font, [NSColor blackColor])].width;
}

// the largest size up to `size` at which s fits in maxW
CGFloat fitSize (const char* s, CGFloat size, CGFloat maxW, bool bold = true)
{
    const CGFloat w = textWidth (s, bold ? boldFont (size) : plainFont (size));
    if (w <= maxW || w <= 0.0) return size;
    const CGFloat f = size * maxW / w;
    return f < 7.0 ? 7.0 : f;
}

inline CGFloat valueAngle (CGFloat v) { return (CGFloat) ((-150.0 + 300.0 * v) * M_PI / 180.0); }
inline NSPoint polar (CGFloat cx, CGFloat cy, CGFloat r, CGFloat a) { return NSMakePoint (cx + r * std::sin (a), cy - r * std::cos (a)); }

void setGlow (NSColor* c, CGFloat blur)
{
    NSShadow* g = [[[NSShadow alloc] init] autorelease];
    [g setShadowOffset: NSMakeSize (0.0, 0.0)];
    [g setShadowBlurRadius: blur];
    [g setShadowColor: c];
    [g set];
}

struct Lit { int r, g, b; };
const Lit kRed = { 236, 44, 34 };
const Lit kAmber = { 255, 150, 20 };
const Lit kYellow = { 255, 214, 40 };
const Lit kOrange = { 255, 112, 12 };    // PLAY/STOP when engaged

NSColor* litColor (Lit c) { return rgb (c.r, c.g, c.b); }
NSColor* litLight (Lit c) { return rgb (c.r + (255 - c.r) * 2 / 3, c.g + (255 - c.g) * 2 / 3, c.b + (255 - c.b) * 2 / 3); }
NSColor* litDark (Lit c) { return rgb (c.r * 2 / 3, c.g * 2 / 3, c.b * 2 / 3); }

// A push button: silver when off, lit from inside (with a glow round it) when on
void drawButton (NSRect r, const char* label, bool lit, Lit c, CGFloat fontSize = 12.0, bool enabled = true)
{
    NSBezierPath* p = [NSBezierPath bezierPathWithRoundedRect: r xRadius: 4 yRadius: 4];
    if (lit)
    {
        [NSGraphicsContext saveGraphicsState];
        setGlow (litColor (c), 12.0);
        [litColor (c) set];
        [p fill];
        [p fill];
        [NSGraphicsContext restoreGraphicsState];
        NSGradient* g = [[[NSGradient alloc] initWithColorsAndLocations:
                            litLight (c), 0.0, litColor (c), 0.45, litDark (c), 1.0, nil] autorelease];
        [g drawInBezierPath: p angle: -90.0];
    }
    else
    {
        NSGradient* g = [[[NSGradient alloc] initWithStartingColor: rgb (232, 228, 218) endingColor: rgb (172, 168, 160)] autorelease];
        [g drawInBezierPath: p angle: -90.0];
    }
    [rgb (44, 45, 48) set];
    [p setLineWidth: 1.0];
    [p stroke];
    if (label && label[0])
    {
        const CGFloat fs = fitSize (label, fontSize, r.size.width - 8.0);
        NSColor* ink = ! enabled ? rgb (140, 142, 146) : (lit ? ((c.r + c.g + c.b) > 560 ? [NSColor blackColor] : [NSColor whiteColor]) : [NSColor blackColor]);
        drawText (label, boldFont (fs), ink, NSMidX (r), NSMidY (r));
    }
}

// Two-position slide switch: the engaged half is raised and lit with its legend
// glowing, the other half dark with a grey legend.
void drawSlide2 (NSRect slot, const char* left, const char* right, bool rightOn, Lit c, bool enabled = true)
{
    NSBezierPath* sp = [NSBezierPath bezierPathWithRoundedRect: slot xRadius: 3 yRadius: 3];
    [rgb (16, 16, 18) set];
    [sp fill];
    const NSRect in = NSInsetRect (slot, 2.0, 2.0);
    const CGFloat half = in.size.width * 0.5;
    for (int side = 0; side < 2; ++side)
    {
        const NSRect h = NSMakeRect (in.origin.x + side * half, in.origin.y, half, in.size.height);
        const bool on = enabled && ((side == 1) == rightOn);
        NSBezierPath* hp = [NSBezierPath bezierPathWithRoundedRect: NSInsetRect (h, 0.5, 0.5) xRadius: 2 yRadius: 2];
        if (on)
        {
            [NSGraphicsContext saveGraphicsState];
            setGlow (litColor (c), 12.0);
            [litColor (c) set];
            [hp fill];
            [NSGraphicsContext restoreGraphicsState];
            NSGradient* g = [[[NSGradient alloc] initWithColorsAndLocations:
                                litLight (c), 0.0, litColor (c), 0.5, litDark (c), 1.0, nil] autorelease];
            [g drawInBezierPath: hp angle: -90.0];
        }
        else
        {
            [rgb (52, 54, 58) set];
            [hp fill];
        }
        const char* lab = side ? right : left;
        if (lab && lab[0])
        {
            const CGFloat fs = fitSize (lab, 10.5, half - 6.0);
            if (on)
            {
                [NSGraphicsContext saveGraphicsState];
                setGlow ([NSColor whiteColor], 5.0);
                drawText (lab, boldFont (fs), (c.r + c.g + c.b) > 560 ? [NSColor blackColor] : [NSColor whiteColor], NSMidX (h), NSMidY (h));
                [NSGraphicsContext restoreGraphicsState];
            }
            else
                drawText (lab, plainFont (fs), rgb (130, 132, 136), NSMidX (h), NSMidY (h));
        }
    }
    [rgb (60, 62, 66) set];
    [sp setLineWidth: 1.0];
    [sp stroke];
}

// M-50 style knob: charcoal knurled skirt (40 ridges) with a coloured cap and
// a pointer line. cap: 0 dark grey, 1 red (like the M-50's TRIM), 2 cream
// (like its PAN), 3 orange (like its EQ rings).
enum { kCapDark = 0, kCapRed = 1, kCapCream = 2, kCapOrange = 3 };

void drawKnob (NSPoint c, CGFloat r, CGFloat v, int capKind = kCapDark)
{
    const CGFloat a = valueAngle (v);
    NSBezierPath* skirt = [NSBezierPath bezierPath];
    const int ridges = 40;
    for (int k = 0; k <= ridges * 4; ++k)
    {
        const CGFloat t = (CGFloat) (2.0 * M_PI * k / (ridges * 4));
        const CGFloat rr = r * (1.0 - 0.04 * (0.5 - 0.5 * std::cos (ridges * t)));
        const NSPoint p = polar (c.x, c.y, rr, t + a);
        if (k == 0) [skirt moveToPoint: p]; else [skirt lineToPoint: p];
    }
    [skirt closePath];
    NSColor* skirtCol = rgb (78, 76, 72);
    NSColor* skirtDark = rgb (30, 29, 27);
    [NSGraphicsContext saveGraphicsState];
    NSShadow* sh = [[[NSShadow alloc] init] autorelease];
    [sh setShadowOffset: NSMakeSize (1.5, -3.0)];
    [sh setShadowBlurRadius: 4.0];
    [sh setShadowColor: [NSColor colorWithCalibratedWhite: 0.0 alpha: 0.55]];
    [sh set];
    [skirtDark set];
    [skirt fill];
    [NSGraphicsContext restoreGraphicsState];
    NSGradient* sk = [[[NSGradient alloc] initWithColorsAndLocations: skirtCol, 0.0, skirtDark, 1.0, nil] autorelease];
    [sk drawInBezierPath: skirt relativeCenterPosition: NSMakePoint (-0.35, 0.5)];
    [[NSColor colorWithCalibratedWhite: 0.0 alpha: 0.35] set];
    for (int k = 0; k < ridges; ++k)
    {
        const CGFloat t = (CGFloat) (2.0 * M_PI * k / ridges) + a;
        NSBezierPath* l = [NSBezierPath bezierPath];
        [l moveToPoint: polar (c.x, c.y, r * 0.82, t)];
        [l lineToPoint: polar (c.x, c.y, r * 0.97, t)];
        [l setLineWidth: 0.7];
        [l stroke];
    }
    NSColor* capCol = capKind == kCapRed ? rgb (206, 38, 34) : (capKind == kCapCream ? rgb (234, 228, 208)
                    : (capKind == kCapOrange ? rgb (236, 120, 28) : rgb (92, 90, 86)));
    NSColor* capDark = capKind == kCapRed ? rgb (120, 16, 12) : (capKind == kCapCream ? rgb (168, 160, 138)
                     : (capKind == kCapOrange ? rgb (150, 64, 8) : rgb (40, 39, 37)));
    NSColor* ptr = capKind == kCapCream ? rgb (20, 20, 20) : rgb (250, 248, 240);
    const CGFloat rc = r * 0.66;
    NSBezierPath* cap = [NSBezierPath bezierPathWithOvalInRect: NSMakeRect (c.x - rc, c.y - rc, 2 * rc, 2 * rc)];
    [NSGraphicsContext saveGraphicsState];
    NSShadow* cs = [[[NSShadow alloc] init] autorelease];
    [cs setShadowOffset: NSMakeSize (0.8, -1.5)];
    [cs setShadowBlurRadius: 2.0];
    [cs setShadowColor: [NSColor colorWithCalibratedWhite: 0.0 alpha: 0.6]];
    [cs set];
    [capDark set];
    [cap fill];
    [NSGraphicsContext restoreGraphicsState];
    NSGradient* cg = [[[NSGradient alloc] initWithColorsAndLocations:
                         [capCol blendedColorWithFraction: 0.35 ofColor: [NSColor whiteColor]], 0.0, capCol, 0.5, capDark, 1.0, nil] autorelease];
    [cg drawInBezierPath: cap relativeCenterPosition: NSMakePoint (-0.3, 0.45)];
    [[NSColor colorWithCalibratedWhite: 0.0 alpha: 0.5] set];
    [cap setLineWidth: 0.8];
    [cap stroke];
    // pointer across the cap and on over the skirt
    [ptr set];
    NSBezierPath* p = [NSBezierPath bezierPath];
    [p moveToPoint: polar (c.x, c.y, rc * 0.25, a)];
    [p lineToPoint: polar (c.x, c.y, rc * 0.92, a)];
    [p setLineWidth: 2.2];
    [p setLineCapStyle: NSRoundLineCapStyle];
    [p stroke];
    [rgb (250, 248, 240) set];
    NSBezierPath* q = [NSBezierPath bezierPath];
    [q moveToPoint: polar (c.x, c.y, rc + 1.5, a)];
    [q lineToPoint: polar (c.x, c.y, r * 0.98, a)];
    [q setLineWidth: 2.2];
    [q setLineCapStyle: NSRoundLineCapStyle];
    [q stroke];
}

NSColor* rgba (int r, int g, int b, CGFloat al) { return [NSColor colorWithCalibratedRed: r / 255.0 green: g / 255.0 blue: b / 255.0 alpha: al]; }

void strokeLine (CGFloat x0, CGFloat y0, CGFloat x1, CGFloat y1, CGFloat w)
{
    NSBezierPath* p = [NSBezierPath bezierPath];
    [p moveToPoint: NSMakePoint (x0, y0)];
    [p lineToPoint: NSMakePoint (x1, y1)];
    [p setLineWidth: w];
    [p stroke];
}

// One mahogany board (from TB M50 Dual Channel Strip): deep red-brown, wavy
// grain along its length, pores
void drawMahoganyBoard (NSRect r, bool vertical, unsigned seed)
{
    NSGradient* base = [[[NSGradient alloc] initWithColorsAndLocations:
                           rgb (122, 46, 26), 0.0, rgb (104, 36, 20), 0.5, rgb (88, 30, 16), 1.0, nil] autorelease];
    [base drawInRect: r angle: vertical ? 0.0 : 90.0];
    const CGFloat len = vertical ? r.size.height : r.size.width;
    const CGFloat across = vertical ? r.size.width : r.size.height;
    for (int k = 0; k < (int) (across * 3.0); ++k)
    {
        seed = seed * 1664525u + 1013904223u;
        const CGFloat pos = (seed >> 8) / 16777216.0 * across;
        seed = seed * 1664525u + 1013904223u;
        const double q = (seed >> 8) / 16777216.0;
        seed = seed * 1664525u + 1013904223u;
        const CGFloat phase = (seed >> 8) / 16777216.0 * 6.283;
        const CGFloat amp = 0.6 + 1.6 * q, wave = 0.004 + 0.01 * q;
        NSColor* c = q < 0.55 ? rgba (40, 10, 4, 0.10 + 0.16 * q) : rgba (196, 92, 52, 0.05 + 0.10 * (q - 0.55));
        NSBezierPath* g = [NSBezierPath bezierPath];
        for (int i = 0; i <= 60; ++i)
        {
            const CGFloat t = len * i / 60.0;
            const CGFloat off = pos + amp * std::sin (t * wave * 6.283 + phase) + 0.8 * std::sin (t * 0.031 + phase * 2.0);
            const NSPoint pt = vertical ? NSMakePoint (r.origin.x + off, r.origin.y + t) : NSMakePoint (r.origin.x + t, r.origin.y + off);
            if (i == 0) [g moveToPoint: pt]; else [g lineToPoint: pt];
        }
        [g setLineWidth: 0.5 + 1.4 * (1.0 - q)];
        [c set];
        [g stroke];
    }
    for (int k = 0; k < (int) (len * across / 60.0); ++k)
    {
        seed = seed * 1664525u + 1013904223u; const CGFloat a = (seed >> 8) / 16777216.0 * len;
        seed = seed * 1664525u + 1013904223u; const CGFloat b = (seed >> 8) / 16777216.0 * across;
        [rgba (30, 6, 2, 0.35) set];
        NSRectFillUsingOperation (vertical ? NSMakeRect (r.origin.x + b, r.origin.y + a, 0.8, 3.0)
                                           : NSMakeRect (r.origin.x + a, r.origin.y + b, 3.0, 0.8), NSCompositeSourceOver);
    }
}

// Four boards mitred at the corners, lacquered, a dark bevel where they meet the face
void drawMahoganyFrame (CGFloat ox, CGFloat VW)
{
    const CGFloat VH = kViewHeight;
    [NSGraphicsContext saveGraphicsState];
    NSAffineTransform* ft = [NSAffineTransform transform];
    [ft translateXBy: ox yBy: 0.0];
    [ft concat];
    for (int side = 0; side < 4; ++side)
    {
        NSBezierPath* clip = [NSBezierPath bezierPath];
        NSRect board;
        bool vertical;
        switch (side)
        {
            case 0:
                [clip moveToPoint: NSMakePoint (0, 0)]; [clip lineToPoint: NSMakePoint (VW, 0)];
                [clip lineToPoint: NSMakePoint (VW - F, F)]; [clip lineToPoint: NSMakePoint (F, F)];
                board = NSMakeRect (0, 0, VW, F); vertical = false; break;
            case 1:
                [clip moveToPoint: NSMakePoint (0, VH)]; [clip lineToPoint: NSMakePoint (VW, VH)];
                [clip lineToPoint: NSMakePoint (VW - F, VH - F)]; [clip lineToPoint: NSMakePoint (F, VH - F)];
                board = NSMakeRect (0, VH - F, VW, F); vertical = false; break;
            case 2:
                [clip moveToPoint: NSMakePoint (0, 0)]; [clip lineToPoint: NSMakePoint (F, F)];
                [clip lineToPoint: NSMakePoint (F, VH - F)]; [clip lineToPoint: NSMakePoint (0, VH)];
                board = NSMakeRect (0, 0, F, VH); vertical = true; break;
            default:
                [clip moveToPoint: NSMakePoint (VW, 0)]; [clip lineToPoint: NSMakePoint (VW - F, F)];
                [clip lineToPoint: NSMakePoint (VW - F, VH - F)]; [clip lineToPoint: NSMakePoint (VW, VH)];
                board = NSMakeRect (VW - F, 0, F, VH); vertical = true; break;
        }
        [clip closePath];
        [NSGraphicsContext saveGraphicsState];
        [clip addClip];
        drawMahoganyBoard (board, vertical, 3301u + 977u * (unsigned) side);
        NSGradient* sheen = [[[NSGradient alloc] initWithColorsAndLocations:
                                rgba (255, 236, 220, 0.20), 0.0, rgba (255, 236, 220, 0.04), 0.35,
                                rgba (0, 0, 0, 0.0), 0.6, rgba (0, 0, 0, 0.22), 1.0, nil] autorelease];
        const CGFloat ang = side == 0 ? 90.0 : (side == 1 ? -90.0 : (side == 2 ? 0.0 : 180.0));
        [sheen drawInRect: board angle: ang];
        [NSGraphicsContext restoreGraphicsState];
    }
    [rgba (30, 8, 2, 0.75) set];
    strokeLine (0, 0, F, F, 1.0);  strokeLine (VW, 0, VW - F, F, 1.0);
    strokeLine (0, VH, F, VH - F, 1.0);  strokeLine (VW, VH, VW - F, VH - F, 1.0);
    [rgba (255, 220, 200, 0.18) set];
    strokeLine (1, 0.5, VW - 1, 0.5, 1.0);  strokeLine (0.5, 1, 0.5, VH - 1, 1.0);
    [rgba (255, 240, 228, 0.10) set];
    NSRectFillUsingOperation (NSMakeRect (5, F, 3, VH - 2 * F), NSCompositeSourceOver);
    NSRectFillUsingOperation (NSMakeRect (F, 5, VW - 2 * F, 3), NSCompositeSourceOver);
    [rgba (20, 6, 2, 0.9) set];
    NSFrameRectWithWidth (NSMakeRect (F - 2, F - 2, VW - 2 * F + 4, VH - 2 * F + 4), 2.0);
    [rgba (0, 0, 0, 0.85) set];
    NSFrameRectWithWidth (NSMakeRect (0, 0, VW, VH), 1.0);
    [NSGraphicsContext restoreGraphicsState];
}

// Heavy wide lettering like the M-50's own model name (Arial Black stretched
// 1.25x; Helvetica Bold thickened if Arial Black is missing)
void drawModelName (const char* text, CGFloat cx, CGFloat cy, CGFloat size)
{
    const CGFloat stretch = 1.25;
    NSFont* f = [NSFont fontWithName: @"Arial-Black" size: size];
    const bool black = f != nil;
    if (! f) f = boldFont (size);
    NSString* s = [NSString stringWithUTF8String: text];
    NSColor* ink = rgb (28, 28, 26);
    NSMutableDictionary* at = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                 f, NSFontAttributeName, ink, NSForegroundColorAttributeName,
                                 [NSNumber numberWithDouble: 0.5], NSKernAttributeName, nil];
    if (! black)
    {
        [at setObject: ink forKey: NSStrokeColorAttributeName];
        [at setObject: [NSNumber numberWithDouble: -9.0] forKey: NSStrokeWidthAttributeName];
    }
    const NSSize sz = [s sizeWithAttributes: at];
    [NSGraphicsContext saveGraphicsState];
    NSAffineTransform* t = [NSAffineTransform transform];
    [t translateXBy: cx yBy: cy];
    [t scaleXBy: stretch yBy: 1.0];
    [t concat];
    [s drawAtPoint: NSMakePoint (-sz.width * 0.5, -sz.height * 0.5) withAttributes: at];
    [NSGraphicsContext restoreGraphicsState];
}

// The M-50's EQ control: an orange FREQUENCY ring with a white line, and a dark
// BOOST / CUT cap in the middle with its own line
void drawConcentric (NSPoint c, CGFloat rr, CGFloat fv, CGFloat rc, CGFloat gv)
{
    const CGFloat fa = valueAngle (fv), ga = valueAngle (gv);
    NSBezierPath* ring = [NSBezierPath bezierPath];
    const int ridges = 40;
    for (int k = 0; k <= ridges * 4; ++k)
    {
        const CGFloat t = (CGFloat) (2.0 * M_PI * k / (ridges * 4));
        const CGFloat r = rr * (1.0 - 0.04 * (0.5 - 0.5 * std::cos (ridges * t)));
        const NSPoint p = polar (c.x, c.y, r, t + fa);
        if (k == 0) [ring moveToPoint: p]; else [ring lineToPoint: p];
    }
    [ring closePath];
    [NSGraphicsContext saveGraphicsState];
    NSShadow* sh = [[[NSShadow alloc] init] autorelease];
    [sh setShadowOffset: NSMakeSize (1.5, -3.0)];
    [sh setShadowBlurRadius: 4.0];
    [sh setShadowColor: [NSColor colorWithCalibratedWhite: 0.0 alpha: 0.55]];
    [sh set];
    [rgb (150, 64, 8) set];
    [ring fill];
    [NSGraphicsContext restoreGraphicsState];
    NSGradient* rg = [[[NSGradient alloc] initWithColorsAndLocations: rgb (250, 150, 60), 0.0, rgb (150, 64, 8), 1.0, nil] autorelease];
    [rg drawInBezierPath: ring relativeCenterPosition: NSMakePoint (-0.35, 0.5)];
    [[NSColor colorWithCalibratedWhite: 0.0 alpha: 0.3] set];
    for (int k = 0; k < ridges; ++k)
    {
        const CGFloat t = (CGFloat) (2.0 * M_PI * k / ridges) + fa;
        strokeLine (polar (c.x, c.y, rr * 0.84, t).x, polar (c.x, c.y, rr * 0.84, t).y,
                    polar (c.x, c.y, rr * 0.97, t).x, polar (c.x, c.y, rr * 0.97, t).y, 0.7);
    }
    [[NSColor whiteColor] set];
    {
        NSBezierPath* p = [NSBezierPath bezierPath];
        [p moveToPoint: polar (c.x, c.y, rc + 2.0, fa)];
        [p lineToPoint: polar (c.x, c.y, rr * 0.98, fa)];
        [p setLineWidth: 2.6];
        [p setLineCapStyle: NSRoundLineCapStyle];
        [p stroke];
    }
    NSBezierPath* cap = [NSBezierPath bezierPathWithOvalInRect: NSMakeRect (c.x - rc, c.y - rc, 2 * rc, 2 * rc)];
    [NSGraphicsContext saveGraphicsState];
    NSShadow* cs = [[[NSShadow alloc] init] autorelease];
    [cs setShadowOffset: NSMakeSize (0.8, -1.5)];
    [cs setShadowBlurRadius: 2.0];
    [cs setShadowColor: [NSColor colorWithCalibratedWhite: 0.0 alpha: 0.6]];
    [cs set];
    [rgb (36, 35, 33) set];
    [cap fill];
    [NSGraphicsContext restoreGraphicsState];
    NSGradient* cg = [[[NSGradient alloc] initWithColorsAndLocations: rgb (120, 118, 112), 0.0, rgb (70, 68, 64), 0.5, rgb (34, 33, 31), 1.0, nil] autorelease];
    [cg drawInBezierPath: cap relativeCenterPosition: NSMakePoint (-0.3, 0.45)];
    [[NSColor colorWithCalibratedWhite: 0.0 alpha: 0.5] set];
    [cap setLineWidth: 0.8];
    [cap stroke];
    [rgb (250, 248, 240) set];
    NSBezierPath* q = [NSBezierPath bezierPath];
    [q moveToPoint: polar (c.x, c.y, rc * 0.2, ga)];
    [q lineToPoint: polar (c.x, c.y, rc * 0.92, ga)];
    [q setLineWidth: 2.2];
    [q setLineCapStyle: NSRoundLineCapStyle];
    [q stroke];
}

// Small backlit VU (from TB M50 Dual Channel Strip): cream face, -20..+3, red over 0
void drawVU (NSRect r, float db)
{
    NSColor* ink = rgb (28, 28, 26);
    NSBezierPath* bezel = [NSBezierPath bezierPathWithRoundedRect: NSInsetRect (r, -3.0, -3.0) xRadius: 3.0 yRadius: 3.0];
    [rgb (26, 25, 24) set];
    [bezel fill];
    NSBezierPath* face = [NSBezierPath bezierPathWithRect: r];
    NSGradient* fg = [[[NSGradient alloc] initWithColorsAndLocations:
                         rgb (255, 244, 206), 0.0, rgb (246, 226, 168), 0.7, rgb (226, 200, 140), 1.0, nil] autorelease];
    [fg drawInBezierPath: face relativeCenterPosition: NSMakePoint (0.0, -0.3)];
    [NSGraphicsContext saveGraphicsState];
    [face addClip];
    const NSPoint pivot = NSMakePoint (NSMidX (r), NSMaxY (r) + 26.0);
    const CGFloat rad = r.size.height + 6.0;
    struct T { float db; const char* txt; } ticks[] = {
        { -20, "20" }, { -10, "10" }, { -7, "7" }, { -5, "5" }, { -3, "3" }, { -2, "" }, { -1, "" },
        { 0, "0" }, { 1, "" }, { 2, "" }, { 3, "+3" } };
    const CGFloat v0 = std::pow (10.0, -20.0 / 20.0), v1 = std::pow (10.0, 3.0 / 20.0);
    #define VU_ANGLE(d) ((CGFloat) ((-40.0 + 80.0 * (std::pow (10.0, (d) / 20.0) - v0) / (v1 - v0)) * M_PI / 180.0))
    {
        NSBezierPath* arc = [NSBezierPath bezierPath];
        [arc appendBezierPathWithArcWithCenter: pivot radius: rad - 9.0
                                    startAngle: (CGFloat) (-90.0 + VU_ANGLE (0) * 180.0 / M_PI) endAngle: (CGFloat) (-90.0 + 40.0) clockwise: NO];
        [arc setLineWidth: 4.0];
        [rgb (204, 30, 24) set];
        [arc stroke];
        NSBezierPath* arc2 = [NSBezierPath bezierPath];
        [arc2 appendBezierPathWithArcWithCenter: pivot radius: rad - 9.0
                                     startAngle: -130.0 endAngle: (CGFloat) (-90.0 + VU_ANGLE (0) * 180.0 / M_PI) clockwise: NO];
        [arc2 setLineWidth: 1.0];
        [ink set];
        [arc2 stroke];
    }
    for (size_t k = 0; k < sizeof (ticks) / sizeof (ticks[0]); ++k)
    {
        const CGFloat a = VU_ANGLE (ticks[k].db);
        [(ticks[k].db > 0 ? rgb (204, 30, 24) : ink) set];
        strokeLine (polar (pivot.x, pivot.y, rad - 11.0, a).x, polar (pivot.x, pivot.y, rad - 11.0, a).y,
                    polar (pivot.x, pivot.y, rad - 5.0, a).x, polar (pivot.x, pivot.y, rad - 5.0, a).y, 1.0);
        if (ticks[k].txt[0])
        {
            const NSPoint p = polar (pivot.x, pivot.y, rad + 1.0, a);
            drawText (ticks[k].txt, boldFont (7.0), ticks[k].db > 0 ? rgb (190, 26, 20) : ink, p.x, p.y);
        }
    }
    drawText ("VU", boldFont (9.0), ink, NSMidX (r), NSMaxY (r) - 13.0);
    float d = db < -22.0f ? -22.0f : (db > 4.0f ? 4.0f : db);
    CGFloat a = VU_ANGLE (d);
    if (db <= -59.0f) a = (CGFloat) (-43.0 * M_PI / 180.0);
    [rgb (16, 16, 16) set];
    strokeLine (pivot.x, pivot.y, polar (pivot.x, pivot.y, rad - 2.0, a).x, polar (pivot.x, pivot.y, rad - 2.0, a).y, 1.2);
    #undef VU_ANGLE
    [NSGraphicsContext restoreGraphicsState];
    [rgba (255, 255, 255, 0.18) set];
    NSRectFillUsingOperation (NSMakeRect (NSMinX (r), NSMinY (r), r.size.width, r.size.height * 0.35), NSCompositeSourceOver);
    [rgb (20, 20, 20) set];
    NSFrameRectWithWidth (r, 1.0);
}

inline NSPoint viewToFace (NSPoint p) { return NSMakePoint (p.x - F, p.y - F); }
inline NSRect faceToView (NSRect r) { return NSOffsetRect (r, F, F); }

// Tick scale with labels at the two ends (and the middle if given)
void drawEnds (NSPoint c, CGFloat r, const char* lo, const char* mid, const char* hi)
{
    [[NSColor blackColor] set];
    const int n = 11;
    for (int k = 0; k < n; ++k)
    {
        const CGFloat a = valueAngle ((CGFloat) k / (n - 1));
        NSBezierPath* t = [NSBezierPath bezierPath];
        [t moveToPoint: polar (c.x, c.y, r + 3.0, a)];
        [t lineToPoint: polar (c.x, c.y, r + ((k == 0 || k == n - 1 || k == 5) ? 8.0 : 6.0), a)];
        [t setLineWidth: 1.1];
        [t stroke];
    }
    NSFont* f = plainFont (9.5);
    if (lo) { const NSPoint p = polar (c.x, c.y, r + 12.0, valueAngle (0.0)); drawText (lo, f, [NSColor blackColor], p.x - 2.0, p.y + 4.0, 1.0); }
    if (hi) { const NSPoint p = polar (c.x, c.y, r + 12.0, valueAngle (1.0)); drawText (hi, f, [NSColor blackColor], p.x + 2.0, p.y + 4.0, 0.0); }
    if (mid) drawText (mid, f, [NSColor blackColor], c.x, c.y - r - 13.0);
}

void drawLed (NSPoint c, CGFloat level, Lit col)
{
    const CGFloat r = 5.0;
    NSBezierPath* p = [NSBezierPath bezierPathWithOvalInRect: NSMakeRect (c.x - r, c.y - r, 2 * r, 2 * r)];
    [rgb (40, 12, 10) set];
    [p fill];
    if (level > 0.02)
    {
        [NSGraphicsContext saveGraphicsState];
        setGlow ([litColor (col) colorWithAlphaComponent: level], 10.0);
        [[litColor (col) colorWithAlphaComponent: 0.3 + 0.7 * level] set];
        [p fill];
        [NSGraphicsContext restoreGraphicsState];
    }
    [rgb (30, 30, 32) set];
    [p setLineWidth: 0.8];
    [p stroke];
}

// "◀ value ▶" box: click the arrows to change
void drawStepper (NSRect r, const char* value, bool enabled = true)
{
    NSBezierPath* p = [NSBezierPath bezierPathWithRoundedRect: r xRadius: 3 yRadius: 3];
    NSGradient* g = [[[NSGradient alloc] initWithStartingColor: rgb (232, 228, 218) endingColor: rgb (178, 174, 166)] autorelease];
    [g drawInBezierPath: p angle: -90.0];
    [rgb (44, 45, 48) set];
    [p setLineWidth: 1.0];
    [p stroke];
    NSColor* ink = enabled ? [NSColor blackColor] : rgb (140, 142, 146);
    const CGFloat aw = r.size.height * 0.8 < 24.0 ? r.size.height * 0.8 : 24.0;
    for (int s = 0; s < 2; ++s)
    {
        const CGFloat cx = s ? NSMaxX (r) - aw * 0.5 - 2.0 : r.origin.x + aw * 0.5 + 2.0;
        const CGFloat cy = NSMidY (r);
        NSBezierPath* t = [NSBezierPath bezierPath];
        const CGFloat d = 4.5;
        if (s) { [t moveToPoint: NSMakePoint (cx - d * 0.7, cy - d)]; [t lineToPoint: NSMakePoint (cx + d * 0.8, cy)]; [t lineToPoint: NSMakePoint (cx - d * 0.7, cy + d)]; }
        else { [t moveToPoint: NSMakePoint (cx + d * 0.7, cy - d)]; [t lineToPoint: NSMakePoint (cx - d * 0.8, cy)]; [t lineToPoint: NSMakePoint (cx + d * 0.7, cy + d)]; }
        [t closePath];
        [ink set];
        [t fill];
    }
    drawText (value, boldFont (fitSize (value, 12.0, r.size.width - 2 * aw - 4.0)), ink, NSMidX (r), NSMidY (r));
}

int stepperSide (NSRect r, NSPoint p)
{
    if (! NSPointInRect (p, r)) return 0;
    return p.x < NSMidX (r) ? -1 : 1;
}

bool inRect (NSPoint p, NSRect r) { return NSPointInRect (p, r) ? true : false; }

int clampi (int v, int lo, int hi) { return v < lo ? lo : (v > hi ? hi : v); }
float clampf (float v, float lo, float hi) { return v < lo ? lo : (v > hi ? hi : v); }

const char* kTabNames[4] = { "PADS", "STEPS", "MIXER", "SONG" };
const char* kModeNames[4] = { "STEP", "A / B", "FLAM", "HITS" };

} // namespace

//==============================================================================

@implementation TBDrumMachineView
{
    int page;
    int editMode;
    int rowChoice[kNumPads];      // sound new steps get on two-sound pads (A / B)
    int padFlam[kNumPads];        // pads page: normal, Flam A, Flam B
    int dragKind;                 // 0 none, 1 knob/fader, 2 painting steps
    int dragId;
    CGFloat dragStartY;
    float dragStartV;
    bool paintOn;
    int paintRow;
    char readout[160];
    char message[160];
    NSTimeInterval messageUntil;
    bool showPatternInReadout;
    NSTextField* nameField;
    NSTextField* retiredField;
    int namingPattern;
    int selEntry;
    tbdm::Pattern clipboard;
    bool clipboardFull;
    NSTimeInterval clearArmedUntil, clearSongArmedUntil;
    NSImage* backdrop;
    long lastSig;
    float flashWas;
    float vuWas[2];
    NSTimer* timer;
}

- (id) initWithFrame: (NSRect) frame core: (AppCore*) c
{
    self = [super initWithFrame: frame];
    if (self)
    {
        core = c;
        page = kPageSteps;
        editMode = kModeStep;
        for (int i = 0; i < kNumPads; ++i) { rowChoice[i] = 0; padFlam[i] = 0; }
        dragKind = 0;
        dragId = -1;
        readout[0] = 0;
        messageUntil = 0.0;
        nameField = nil;
        retiredField = nil;
        namingPattern = -1;
        selEntry = 0;
        clipboardFull = false;
        clearArmedUntil = 0.0;
        clearSongArmedUntil = 0.0;
        showPatternInReadout = false;
        backdrop = nil;
        lastSig = -1;
        flashWas = 0.0f;
        vuWas[0] = vuWas[1] = -60.0f;
        paintOn = false;
        paintRow = -1;
        dragStartY = 0.0;
        dragStartV = 0.0f;
        message[0] = 0;
        clipboard.clear();
        timer = [[NSTimer timerWithTimeInterval: 1.0 / 30.0 target: self selector: @selector (tick:) userInfo: nil repeats: YES] retain];
        [[NSRunLoop currentRunLoop] addTimer: timer forMode: NSDefaultRunLoopMode];
        [[NSRunLoop currentRunLoop] addTimer: timer forMode: NSEventTrackingRunLoopMode];
        [[NSRunLoop currentRunLoop] addTimer: timer forMode: NSModalPanelRunLoopMode];
    }
    return self;
}

- (void) shutdown
{
    [NSObject cancelPreviousPerformRequestsWithTarget: self];
    namingPattern = -1;
    [self dropRetired];
    if (nameField)
    {
        [nameField setDelegate: nil];
        [nameField setTarget: nil];
        [nameField removeFromSuperview];
        [nameField release];
        nameField = nil;
    }
    if (timer) { [timer invalidate]; [timer release]; timer = nil; }
    if (backdrop) { [backdrop release]; backdrop = nil; }
    core = 0;
}

- (void) dealloc
{
    [self shutdown];
    [super dealloc];
}

- (void) syncOrder
{
    if (! core) return;
    const tbdm::Pattern& P = core->engine.song().patterns[core->engine.currentPattern()];
    setOrderForKit (P.kit);
    gGroup = sigDef (P.sig).group;
}

// The window scales from its corner: the frame follows the window, the bounds
// stay at the panel's own size, so drawing and mouse points scale together.
- (void) setFrameSize: (NSSize) sz
{
    [super setFrameSize: sz];
    [self setBoundsSize: NSMakeSize (kViewWidth, kViewHeight)];
}

- (void) viewDidEndLiveResize
{
    [super viewDidEndLiveResize];
    [self setNeedsDisplay: YES];     // the backdrop is remade sharp at the new size
}

- (BOOL) isFlipped { return YES; }
- (BOOL) isOpaque { return YES; }
- (BOOL) acceptsFirstResponder { return YES; }
- (BOOL) acceptsFirstMouse: (NSEvent*) e { (void) e; return YES; }

- (int) page { return page; }
- (void) setPage: (int) p
{
    page = clampi (p, 0, 3);
    [self setNeedsDisplay: YES];
}

- (void) refreshAll
{
    lastSig = -1;
    [self setNeedsDisplay: YES];
}

- (void) touched
{
    if (core) core->dirty = true;
    showPatternInReadout = false;
    [self setNeedsDisplay: YES];
}

- (void) showMessage: (const char*) text
{
    std::snprintf (message, sizeof (message), "%s", text ? text : "");
    messageUntil = [NSDate timeIntervalSinceReferenceDate] + 4.0;
    [self setNeedsDisplay: YES];
}

- (void) setReadout: (const char*) text
{
    std::snprintf (readout, sizeof (readout), "%s", text ? text : "");
    messageUntil = 0.0;
    showPatternInReadout = false;
}

// What the readout shows: a message, the last thing touched, or the pattern
- (void) composeReadout: (char*) text size: (size_t) size
{
    tbdm::Engine& e = core->engine;
    const int cp = e.currentPattern();
    if (messageUntil > [NSDate timeIntervalSinceReferenceDate]) std::snprintf (text, size, "%s", message);
    else if (showPatternInReadout || ! readout[0])
    {
        const tbdm::Pattern& P = e.song().patterns[cp];
        if (P.name[0]) std::snprintf (text, size, "%d   %s", cp + 1, P.name);
        else std::snprintf (text, size, "PATTERN %d   %s KIT", cp + 1, kitDef (P.kit).name);
    }
    else std::snprintf (text, size, "%s", readout);
}

- (const char*) readoutText
{
    static char t[160];
    [self composeReadout: t size: sizeof (t)];
    return t;
}

- (NSTextField*) nameField { return nameField; }

// Redraw while playing (playhead, pad lights) and when anything moves
- (void) tick: (NSTimer*) t
{
    (void) t;
    if (! core) return;
    tbdm::Engine& e = core->engine;
    long sig = (long) e.playStep() * 7919 + e.currentPattern() * 131 + e.queuedPattern() * 17 + (e.isPlaying() ? 3 : 0)
             + (e.isRecording() ? 5 : 0) + e.songPosition() * 104729L;
    float fl = 0.0f;
    for (int p = 0; p < kNumPads; ++p) fl += e.padFlash (p);
    const bool blinking = e.queuedPattern() >= 0;
    if (sig != lastSig || fl > 0.01f || flashWas > 0.01f || blinking || (messageUntil > 0.0 && messageUntil < [NSDate timeIntervalSinceReferenceDate] + 0.1))
    {
        lastSig = sig;
        [self setNeedsDisplay: YES];
    }
    flashWas = fl;
    const float vl = e.vuDb (0), vr = e.vuDb (1);
    if (std::fabs (vl - vuWas[0]) > 0.2f || std::fabs (vr - vuWas[1]) > 0.2f)
    {
        vuWas[0] = vl;
        vuWas[1] = vr;
        [self setNeedsDisplayInRect: NSMakeRect (kSideX + F, F, kSW, 100.0)];
    }
    if (messageUntil > 0.0 && messageUntil < [NSDate timeIntervalSinceReferenceDate]) messageUntil = 0.0;
}

//------------------------------------------------------------------------------
// Values behind the knobs and faders

- (float) knobValue: (int) k
{
    const tbdm::Song& s = core->engine.song();
    if (k >= kKFader) return s.fader;
    if (k >= kKEqGain) return s.eqGain[(k - kKEqGain) % 3];
    if (k >= kKEqFreq) return s.eqFreq[(k - kKEqFreq) % 3];
    if (k == kKTempo) return (s.tempo - 30.0f) / 270.0f;
    if (k == kKSwing) return s.swing / 0.5f;
    if (k == kKAccent) return s.accent;
    if (k == kKMaster) return s.master;
    const int ch = k & 15;
    if (ch >= kNumPads) return 0.0f;
    if (k >= kKLevel) return s.channels[ch].level;
    if (k >= kKPan) return (s.channels[ch].pan + 1.0f) * 0.5f;
    if (k >= kKDecay) return s.channels[ch].decay;
    return (s.channels[ch].tune + 12.0f) / 24.0f;
}

- (void) setKnob: (int) k value: (float) v
{
    v = clampf (v, 0.0f, 1.0f);
    tbdm::Engine& e = core->engine;
    e.lock();
    tbdm::Song& s = e.song();
    if (k >= kKFader) s.fader = v;
    else if (k >= kKEqGain) s.eqGain[(k - kKEqGain) % 3] = (std::fabs (v - 0.5f) < 0.008f) ? 0.5f : v;
    else if (k >= kKEqFreq) s.eqFreq[(k - kKEqFreq) % 3] = v;
    else if (k == kKTempo) s.tempo = (float) (std::floor ((30.0f + 270.0f * v) * 10.0f + 0.5f) / 10.0f);
    else if (k == kKSwing) s.swing = 0.5f * v;
    else if (k == kKAccent) s.accent = v;
    else if (k == kKMaster) s.master = v;
    else
    {
        const int ch = k & 15;
        if (ch < kNumPads)
        {
            if (k >= kKLevel) s.channels[ch].level = v;
            else if (k >= kKPan) s.channels[ch].pan = (std::fabs (v - 0.5f) < 0.01f) ? 0.0f : v * 2.0f - 1.0f;
            else if (k >= kKDecay) s.channels[ch].decay = v;
            else s.channels[ch].tune = (float) (std::floor ((v * 24.0f - 12.0f) * 2.0f + 0.5f) / 2.0f);
        }
    }
    e.unlock();
    [self describeKnob: k];
    [self touched];
}

- (float) knobDefault: (int) k
{
    if (k >= kKFader) return 0.75f;
    if (k >= kKEqFreq) return 0.5f;
    if (k == kKTempo) return (120.0f - 30.0f) / 270.0f;
    if (k == kKSwing) return 0.0f;
    if (k == kKAccent) return 0.5f;
    if (k == kKMaster) return 0.8f;
    if (k >= kKLevel) return 0.8f;
    if (k >= kKPan) return 0.5f;
    if (k >= kKDecay) return 1.0f;
    return 0.5f;
}

- (const char*) padName: (int) pad
{
    const tbdm::PadDef& d = kitDef (core->engine.song().patterns[core->engine.currentPattern()].kit).pads[pad];
    return d.numChoices ? d.label : "---";
}

- (void) describeKnob: (int) k
{
    const tbdm::Song& s = core->engine.song();
    char t[128];
    const int ch = k & 15;
    if (k >= kKFader)
    {
        const double db = MasterSection::faderDb (s.fader);
        if (s.fader <= 0.0f) std::snprintf (t, sizeof (t), "STEREO MASTER   OFF");
        else std::snprintf (t, sizeof (t), "STEREO MASTER   %.1f   (%+.1f dB)", s.fader * 10.0f, db);
    }
    else if (k >= kKEqGain)
    {
        const int b = (k - kKEqGain) % 3;
        std::snprintf (t, sizeof (t), "%s   %+.1f dB%s", kBandName[b], MasterSection::eqDb (s.eqGain[b]), s.eqBypass ? "   (EQ BYPASSED)" : "");
    }
    else if (k >= kKEqFreq)
    {
        const int b = (k - kKEqFreq) % 3;
        const double hz = MasterSection::eqHz (b, s.eqFreq[b]);
        if (hz >= 1000.0) std::snprintf (t, sizeof (t), "%s FREQ   %.2f kHz", kBandName[b], hz / 1000.0);
        else std::snprintf (t, sizeof (t), "%s FREQ   %.0f Hz", kBandName[b], hz);
    }
    else if (k == kKTempo) std::snprintf (t, sizeof (t), "TEMPO   %.1f BPM", s.tempo);
    else if (k == kKSwing) std::snprintf (t, sizeof (t), "SWING   %d%%", (int) (50.0f + s.swing * 50.0f + 0.5f));
    else if (k == kKAccent) std::snprintf (t, sizeof (t), "ACCENT   %.1f", s.accent * 10.0f);
    else if (k == kKMaster) std::snprintf (t, sizeof (t), "MASTER   %.1f", s.master * 10.0f);
    else if (k >= kKLevel)
    {
        const float lv = s.channels[ch].level;
        if (lv < 0.001f) std::snprintf (t, sizeof (t), "%s LEVEL   OFF", [self padName: ch]);
        else std::snprintf (t, sizeof (t), "%s LEVEL   %.1f dB", [self padName: ch], 40.0 * std::log10 (lv / 0.8));
    }
    else if (k >= kKPan)
    {
        const float p = s.channels[ch].pan;
        if (std::fabs (p) < 0.005f) std::snprintf (t, sizeof (t), "%s PAN   CENTRE", [self padName: ch]);
        else std::snprintf (t, sizeof (t), "%s PAN   %s %d", [self padName: ch], p < 0 ? "L" : "R", (int) (std::fabs (p) * 100.0f + 0.5f));
    }
    else if (k >= kKDecay)
    {
        if (s.channels[ch].decay >= 0.999f) std::snprintf (t, sizeof (t), "%s DECAY   FULL", [self padName: ch]);
        else std::snprintf (t, sizeof (t), "%s DECAY   %.1f", [self padName: ch], s.channels[ch].decay * 10.0f);
    }
    else std::snprintf (t, sizeof (t), "%s TUNE   %+.1f semitones", [self padName: ch], s.channels[ch].tune);
    [self setReadout: t];
}

// Knob under the mouse (top bar always, mixer knobs on the mixer page), or -1
- (int) knobAt: (NSPoint) p
{
    for (int i = 0; i < 4; ++i)
    {
        const CGFloat dx = p.x - kTopKnobX[i], dy = p.y - kTopKnobY;
        if (dx * dx + dy * dy <= (kTopKnobR + 6) * (kTopKnobR + 6)) return i;
    }
    if (page == kPageMixer)
    {
        for (int ch = 0; ch < kNumPads; ++ch)
        {
            const CGFloat cx = mixX (ch) + kMixCx;
            const CGFloat ys[3] = { kMixTuneY, kMixDecayY, kMixPanY };
            const int base[3] = { kKTune, kKDecay, kKPan };
            for (int j = 0; j < 3; ++j)
            {
                const CGFloat dx = p.x - cx, dy = p.y - ys[j];
                if (dx * dx + dy * dy <= (kMixKnobR + 5) * (kMixKnobR + 5)) return base[j] + ch;
            }
            if (inRect (p, faderRect (ch))) return kKLevel + ch;
        }
    }
    return -1;
}

//------------------------------------------------------------------------------
// Drawing

// The sidecar's fixed parts, drawn into the backdrop (called inside its lockFocus)
- (void) drawSidecarBackdrop
{
    [NSGraphicsContext saveGraphicsState];
    NSAffineTransform* tr = [NSAffineTransform transform];
    [tr translateXBy: kSideX + F yBy: F];
    [tr concat];
    NSRectClip (NSMakeRect (0, 0, kSW, kFaceHeight));
    NSColor* ink = rgb (28, 28, 26);
    NSGradient* face = [[[NSGradient alloc] initWithStartingColor: rgb (204, 200, 191) endingColor: rgb (182, 178, 169)] autorelease];
    [face drawInRect: NSMakeRect (0, 0, kSW, kStripTop) angle: 90.0];
    unsigned seed = 51u;
    for (int k = 0; k < 3000; ++k)
    {
        seed = seed * 1664525u + 1013904223u; const CGFloat x = (seed >> 8) / 16777216.0 * kSW;
        seed = seed * 1664525u + 1013904223u; const CGFloat y = (seed >> 8) / 16777216.0 * kStripTop;
        seed = seed * 1664525u + 1013904223u; const double q = (seed >> 8) / 16777216.0;
        [[NSColor colorWithCalibratedWhite: q < 0.5 ? 1.0 : 0.0 alpha: 0.035 + 0.04 * q] set];
        NSRectFillUsingOperation (NSMakeRect (x, y, 3.0, 1.0), NSCompositeSourceOver);
    }
    drawText ("L", boldFont (11.0), ink, NSMidX (kVuRect[0]), 106.0);
    drawText ("R", boldFont (11.0), ink, NSMidX (kVuRect[1]), 106.0);
    drawText ("PROGRAM", boldFont (8.0), ink, kSCx, 106.0);
    [ink set];
    strokeLine (20.0, 116.0, kSW - 20.0, 116.0, 1.0);
    drawText ("EQUALIZER", boldFont (10.0), ink, kSCx, 128.0);
    drawText ("BYPASS", boldFont (8.0), ink, kSCx, 173.0);
    drawText ("FREQ", plainFont (7.5), ink, kSW - 24.0, bandY (2) - 34.0);
    drawText ("BOOST", plainFont (7.5), ink, kSW - 24.0, bandY (2) - 25.0);
    drawText ("CUT", plainFont (7.5), ink, kSW - 24.0, bandY (2) - 16.0);
    for (int b = 0; b < 3; ++b)
    {
        const NSPoint c = NSMakePoint (kSCx, bandY (b));
        drawText (kBandName[b], boldFont (9.0), ink, 30.0, bandY (b) - 30.0);
        drawEnds (c, kRingR, kBandLo[b], 0, kBandHi[b]);
    }
    [ink set];
    strokeLine (20.0, 450.0, kSW - 20.0, 450.0, 1.0);
    drawText ("STEREO MASTER", boldFont (11.0), ink, kSCx, 464.0);
    NSBezierPath* slot = [NSBezierPath bezierPathWithRoundedRect: NSMakeRect (kSCx - 3.0, kSFaderTop - 12.0, 6.0, kSFaderBot - kSFaderTop + 24.0) xRadius: 3.0 yRadius: 3.0];
    [rgb (24, 23, 22) set];
    [slot fill];
    for (int k = 0; k <= 10; ++k)
    {
        const CGFloat y = sFaderY (k / 10.0f);
        [ink set];
        strokeLine (kSCx - 30.0, y, kSCx - 18.0, y, k == 0 || k == 10 || k == 5 ? 1.4 : 0.9);
        strokeLine (kSCx + 18.0, y, kSCx + 30.0, y, k == 0 || k == 10 || k == 5 ? 1.4 : 0.9);
        char n[4];
        std::snprintf (n, sizeof (n), "%d", k);
        drawText (n, boldFont (8.0), ink, kSCx - 40.0, y + 0.5);
    }
    {
        const NSRect lip = NSMakeRect (0, kStripTop - 12.0, kSW, 12.0);
        NSGradient* lg = [[[NSGradient alloc] initWithColorsAndLocations:
                             rgb (40, 38, 36), 0.0, rgb (40, 38, 36), 0.25, rgb (214, 52, 30), 0.3,
                             rgb (186, 40, 24), 0.7, rgb (40, 38, 36), 0.75, rgb (30, 29, 27), 1.0, nil] autorelease];
        [lg drawInRect: lip angle: 90.0];
    }
    NSGradient* strip = [[[NSGradient alloc] initWithStartingColor: rgb (168, 164, 156) endingColor: rgb (150, 146, 139)] autorelease];
    [strip drawInRect: NSMakeRect (0, kStripTop, kSW, kFaceHeight - kStripTop) angle: 90.0];
    [rgb (30, 29, 27) set];
    NSRectFill (NSMakeRect (0, kStripTop, kSW, 1.5));
    drawModelName ("M-50", kSCx, 694.0, 26.0);
    drawText ("MASTER", boldFont (10.0), ink, kSCx, 730.0);
    [rgba (0, 0, 0, 0.6) set];
    NSFrameRectWithWidth (NSMakeRect (0, 0, kSW, kFaceHeight), 1.0);
    [NSGraphicsContext restoreGraphicsState];
    for (int k = 0; k < 6; ++k)
    {
        [rgba (0, 0, 0, 0.22 - 0.035 * k) set];
        NSFrameRectWithWidth (NSMakeRect (kSideX + F + k, F + k, kSW - 2 * k, kFaceHeight - 2 * k), 1.0);
    }
}

// The sidecar's moving parts: VUs, EQ BYPASS, the EQ controls, the fader
- (void) drawSidecar
{
    tbdm::Engine& e = core->engine;
    const tbdm::Song& s = e.song();
    [NSGraphicsContext saveGraphicsState];
    NSAffineTransform* tr = [NSAffineTransform transform];
    [tr translateXBy: kSideX + F yBy: F];
    [tr concat];
    NSRectClip (NSMakeRect (0, 0, kSW, kFaceHeight));
    for (int c = 0; c < 2; ++c) drawVU (kVuRect[c], e.vuDb (c));
    {
        const NSRect r = kBypassRect;
        NSBezierPath* bp = [NSBezierPath bezierPathWithRoundedRect: NSInsetRect (r, -2.5, -2.5) xRadius: 2.0 yRadius: 2.0];
        [rgb (30, 29, 28) set];
        [bp fill];
        NSBezierPath* cp = [NSBezierPath bezierPathWithRoundedRect: r xRadius: 1.5 yRadius: 1.5];
        if (s.eqBypass)
        {
            [NSGraphicsContext saveGraphicsState];
            setGlow (rgb (255, 40, 24), 14.0);
            [rgb (255, 40, 24) set];
            [cp fill];
            [NSGraphicsContext restoreGraphicsState];
            NSGradient* g = [[[NSGradient alloc] initWithColorsAndLocations: rgb (255, 230, 214), 0.0, rgb (255, 110, 86), 0.35, rgb (232, 30, 18), 1.0, nil] autorelease];
            [g drawInBezierPath: cp relativeCenterPosition: NSMakePoint (0.0, 0.0)];
        }
        else
        {
            NSGradient* g = [[[NSGradient alloc] initWithStartingColor: rgb (226, 222, 212) endingColor: rgb (170, 166, 158)] autorelease];
            [g drawInBezierPath: cp angle: -90.0];
        }
        [rgba (0, 0, 0, 0.5) set];
        [cp setLineWidth: 0.8];
        [cp stroke];
    }
    for (int b = 0; b < 3; ++b) drawConcentric (NSMakePoint (kSCx, bandY (b)), kRingR, s.eqFreq[b], kCapR, s.eqGain[b]);
    {
        const CGFloat y = sFaderY (s.fader);
        const NSRect r = NSMakeRect (kSCx - 22.0, y - 9.0, 44.0, 18.0);
        NSBezierPath* cp = [NSBezierPath bezierPathWithRoundedRect: r xRadius: 2.5 yRadius: 2.5];
        [NSGraphicsContext saveGraphicsState];
        NSShadow* sh = [[[NSShadow alloc] init] autorelease];
        [sh setShadowOffset: NSMakeSize (2.0, -4.0)];
        [sh setShadowBlurRadius: 5.0];
        [sh setShadowColor: [NSColor colorWithCalibratedWhite: 0.0 alpha: 0.6]];
        [sh set];
        [rgb (150, 146, 132) set];
        [cp fill];
        [NSGraphicsContext restoreGraphicsState];
        NSGradient* g = [[[NSGradient alloc] initWithColorsAndLocations:
                            rgb (250, 246, 232), 0.0, rgb (234, 228, 208), 0.45, rgb (190, 184, 164), 0.55, rgb (226, 220, 200), 1.0, nil] autorelease];
        [g drawInBezierPath: cp angle: -90.0];
        [rgb (60, 58, 52) set];
        [cp setLineWidth: 0.8];
        [cp stroke];
        [rgb (20, 20, 20) set];
        strokeLine (kSCx - 19.0, y, kSCx + 19.0, y, 2.0);
    }
    [NSGraphicsContext restoreGraphicsState];
}

// Sidecar control under a point (sidecar face coordinates): knob id, -2 for
// EQ BYPASS, -1 for nothing
- (int) sideControlAt: (NSPoint) sp
{
    if (inRect (sp, NSInsetRect (kBypassRect, -4.0, -4.0))) return -2;
    for (int b = 0; b < 3; ++b)
    {
        const CGFloat dx = sp.x - kSCx, dy = sp.y - bandY (b);
        const CGFloat d = std::sqrt (dx * dx + dy * dy);
        if (d <= kCapR) return kKEqGain + b;
        if (d <= kRingR + 4.0) return kKEqFreq + b;
    }
    if (inRect (sp, NSMakeRect (kSCx - 26.0, kSFaderTop - 14.0, 52.0, kSFaderBot - kSFaderTop + 28.0))) return kKFader;
    return -1;
}

- (NSImage*) backdropImage
{
    // Drawn at the window's current size (so it stays sharp at any scale), then
    // scaled back into the panel's own coordinates. Remade when the size settles.
    const NSSize fsz = [self frame].size;
    if (backdrop && ! [self inLiveResize] && (std::fabs ([backdrop size].width - fsz.width) > 0.5 || std::fabs ([backdrop size].height - fsz.height) > 0.5))
    {
        [backdrop release];
        backdrop = nil;
    }
    if (backdrop) return backdrop;
    backdrop = [[NSImage alloc] initWithSize: fsz];
    [backdrop lockFocusFlipped: YES];
    {
        NSAffineTransform* sc = [NSAffineTransform transform];
        [sc scaleXBy: fsz.width / kViewWidth yBy: fsz.height / kViewHeight];
        [sc concat];
    }
    drawMahoganyFrame (0.0, kMainWidth);
    drawMahoganyFrame (kSideX, kViewWidth - kSideX);
    [self drawSidecarBackdrop];
    [NSGraphicsContext saveGraphicsState];
    NSAffineTransform* tr = [NSAffineTransform transform];
    [tr translateXBy: F yBy: F];
    [tr concat];
    NSRectClip (NSMakeRect (0, 0, W, kFaceHeight));

    // the M-50's warm grey face with a faint grain
    NSGradient* face = [[[NSGradient alloc] initWithStartingColor: rgb (204, 200, 191) endingColor: rgb (182, 178, 169)] autorelease];
    [face drawInRect: NSMakeRect (0, 0, W, kStripTop) angle: 90.0];
    unsigned seed = 50u;
    for (int k = 0; k < 16000; ++k)
    {
        seed = seed * 1664525u + 1013904223u; const CGFloat x = (seed >> 8) / 16777216.0 * W;
        seed = seed * 1664525u + 1013904223u; const CGFloat y = (seed >> 8) / 16777216.0 * kStripTop;
        seed = seed * 1664525u + 1013904223u; const double q = (seed >> 8) / 16777216.0;
        [[NSColor colorWithCalibratedWhite: q < 0.5 ? 1.0 : 0.0 alpha: 0.035 + 0.04 * q] set];
        NSRectFillUsingOperation (NSMakeRect (x, y, 3.0, 1.0), NSCompositeSourceOver);
    }
    // top bar ledge
    [rgba (0, 0, 0, 0.45) set];
    NSRectFillUsingOperation (NSMakeRect (0, kTopH, W, 1.2), NSCompositeSourceOver);
    [rgba (255, 255, 255, 0.45) set];
    NSRectFillUsingOperation (NSMakeRect (0, kTopH + 1.4, W, 1.0), NSCompositeSourceOver);
    // the red lip along the front, as on the console
    {
        const NSRect lip = NSMakeRect (0, kStripTop - 12.0, W, 12.0);
        NSGradient* lg = [[[NSGradient alloc] initWithColorsAndLocations:
                             rgb (40, 38, 36), 0.0, rgb (40, 38, 36), 0.25, rgb (214, 52, 30), 0.3,
                             rgb (186, 40, 24), 0.7, rgb (40, 38, 36), 0.75, rgb (30, 29, 27), 1.0, nil] autorelease];
        [lg drawInRect: lip angle: 90.0];
    }
    // plugin strip: a darker grey, a dark rule above
    NSGradient* strip = [[[NSGradient alloc] initWithStartingColor: rgb (168, 164, 156) endingColor: rgb (150, 146, 139)] autorelease];
    [strip drawInRect: NSMakeRect (0, kStripTop, W, kFaceHeight - kStripTop) angle: 90.0];
    [rgb (30, 29, 27) set];
    NSRectFill (NSMakeRect (0, kStripTop, W, 1.5));

    // the user's TB electronic logo, red and black, straight on the grey
    tblogo::drawTBLogo (kLogoBox);
    drawModelName ("DRUM MACHINE", NSMidX (kLogoBox), 744.0, 11.0);

    NSColor* ink = rgb (28, 28, 26);
    drawText ("TEMPO", boldFont (11.0), ink, kTopKnobX[0], kCaptionY);
    drawText ("BPM", boldFont (10.0), ink, NSMidX (kTempoBox), kCaptionY);
    drawText ("SWING", boldFont (11.0), ink, kTopKnobX[1], kCaptionY);
    drawText ("ACCENT", boldFont (11.0), ink, kTopKnobX[2], kCaptionY);
    drawText ("MASTER", boldFont (11.0), ink, kTopKnobX[3], kCaptionY);
    drawText ("SYNC", boldFont (11.0), ink, NSMidX (kSyncRect), kCaptionY);
    drawText ("KIT", boldFont (11.0), ink, NSMidX (kitRect (1)), kCaptionY);
    drawEnds (NSMakePoint (kTopKnobX[0], kTopKnobY), kTopKnobR, "30", 0, "300");
    drawEnds (NSMakePoint (kTopKnobX[1], kTopKnobY), kTopKnobR, "50%", 0, "75%");
    drawEnds (NSMakePoint (kTopKnobX[2], kTopKnobY), kTopKnobR, "0", 0, "10");
    drawEnds (NSMakePoint (kTopKnobX[3], kTopKnobY), kTopKnobR, "0", 0, "10");
    drawText ("PATTERNS", boldFont (10.0), ink, (NSMinX (slotRect (0)) + NSMaxX (slotRect (15))) * 0.5, 653.0);
    drawText ("PATTERN", boldFont (10.0), ink, (NSMinX (patBtnRect (0)) + NSMaxX (patBtnRect (3))) * 0.5, 653.0);
    [rgba (0, 0, 0, 0.6) set];
    NSFrameRectWithWidth (NSMakeRect (0, 0, W, kFaceHeight), 1.0);
    [NSGraphicsContext restoreGraphicsState];
    // the frame's shadow falling on the face's edge
    for (int k = 0; k < 6; ++k)
    {
        [rgba (0, 0, 0, 0.22 - 0.035 * k) set];
        NSFrameRectWithWidth (NSMakeRect (F + k, F + k, W - 2 * k, kFaceHeight - 2 * k), 1.0);
    }
    [backdrop unlockFocus];
    return backdrop;
}

- (void) drawLimeBox: (NSRect) box text: (const char*) t size: (CGFloat) size
{
    NSBezierPath* p = [NSBezierPath bezierPathWithRoundedRect: box xRadius: 4 yRadius: 4];
    NSGradient* glow = [[[NSGradient alloc] initWithStartingColor: rgb (232, 212, 170) endingColor: rgb (204, 178, 130)] autorelease];
    [glow drawInBezierPath: p relativeCenterPosition: NSMakePoint (0.0, 0.0)];
    [rgb (60, 62, 65) set];
    [p setLineWidth: 1.0];
    [p stroke];
    if (t && t[0]) drawText (t, boldFont (fitSize (t, size, box.size.width - 16.0)), [NSColor blackColor], NSMidX (box), NSMidY (box));
}

- (void) drawTopBar
{
    tbdm::Engine& e = core->engine;
    drawButton (kPlayRect, e.isPlaying() ? "STOP" : "PLAY", e.isPlaying(), kOrange, 15.0);
    drawButton (kRecRect, "REC", e.isRecording(), kRed, 15.0);
    const int caps[4] = { kCapCream, kCapDark, kCapDark, kCapRed };
    for (int i = 0; i < 4; ++i) drawKnob (NSMakePoint (kTopKnobX[i], kTopKnobY), kTopKnobR, [self knobValue: i], caps[i]);
    char t[32];
    if (e.externalSync())
    {
        if (e.externalTempo() > 1.0f) std::snprintf (t, sizeof (t), "%.1f", e.externalTempo());
        else std::snprintf (t, sizeof (t), "MIDI");
    }
    else std::snprintf (t, sizeof (t), "%.1f", e.song().tempo);
    [self drawLimeBox: kTempoBox text: t size: 17.0];
    drawSlide2 (kSyncRect, "INT", "MIDI", e.externalSync(), kAmber);
    const int kit = e.song().patterns[e.currentPattern()].kit;
    for (int k = 0; k < kNumKits; ++k)
    {
        char lab[48];
        const bool missing = core->kits.samplesLoaded (k) == 0;
        std::snprintf (lab, sizeof (lab), "%s", kitDef (k).name);
        drawButton (kitRect (k), lab, k == kit, kRed, 16.0, ! missing);
    }
}

- (void) drawTabs
{
    for (int i = 0; i < 4; ++i) drawButton (tabRect (i), kTabNames[i], page == i, kRed, 13.0);
    if (page == kPageSteps)
    {
        const tbdm::Pattern& P = core->engine.song().patterns[core->engine.currentPattern()];
        char t[32];
        std::snprintf (t, sizeof (t), "LENGTH  %d", P.length);
        drawStepper (kLengthRect, t);
        // time signature drop-down
        std::snprintf (t, sizeof (t), "TIME  %s", sigDef (P.sig).name);
        drawButton (NSMakeRect (kTimeRect.origin.x, kTimeRect.origin.y, kTimeRect.size.width - 20.0, kTimeRect.size.height), "", false, kRed);
        drawButton (kTimeRect, "", false, kRed);
        drawText (t, boldFont (12.0), [NSColor blackColor], kTimeRect.origin.x + 10.0, NSMidY (kTimeRect), 0.0);
        NSBezierPath* tri = [NSBezierPath bezierPath];
        const CGFloat tx = NSMaxX (kTimeRect) - 14.0, ty = NSMidY (kTimeRect);
        [tri moveToPoint: NSMakePoint (tx - 5.0, ty - 3.0)];
        [tri lineToPoint: NSMakePoint (tx + 5.0, ty - 3.0)];
        [tri lineToPoint: NSMakePoint (tx, ty + 4.0)];
        [tri closePath];
        [[NSColor blackColor] set];
        [tri fill];
        for (int i = 0; i < 4; ++i) drawButton (modeRect (i), kModeNames[i], editMode == i, kAmber, 12.0);
    }
    else if (page == kPagePads)
        drawText ("Click a pad to play it.  REC + PLAY records your hits.  Option-click: accent.", plainFont (11.5),
                  rgb (40, 41, 44), 560.0, kTabY + kTabH * 0.5, 0.0);
}

- (void) drawStepsPage
{
    tbdm::Engine& e = core->engine;
    const int cp = e.currentPattern();
    const tbdm::Pattern& P = e.song().patterns[cp];
    const tbdm::KitDef& kd = kitDef (P.kit);
    NSColor* ink = [NSColor blackColor];

    // step numbers
    for (int k = 0; k < kMaxSteps; ++k)
    {
        char n[4];
        std::snprintf (n, sizeof (n), "%d", k + 1);
        const bool beat = (k % gGroup) == 0;
        drawText (n, beat ? boldFont (9.5) : plainFont (9.0), k < P.length ? ink : rgb (130, 132, 136), cellX (k) + kCellW * 0.5, 174.0);
    }
    const int ps = e.playStep();
    bool anySolo = false;
    for (int c = 0; c < kNumPads; ++c) anySolo = anySolo || e.song().channels[c].solo;

    for (int row = 0; row < kNumTracks; ++row)
    {
        const int tr = rowTrack (row);
        const tbdm::Track& T = P.tracks[tr];
        const CGFloat y = kRowY0 + row * kRowPitch;
        const bool used = tr == kAccentTrack || (kd.pads[tr].numChoices > 0 && core->kits.padAvailable (P.kit, tr));
        // name
        const char* nm = tr == kAccentTrack ? "ACCENT" : (kd.pads[tr].numChoices ? kd.pads[tr].label : "---");
        drawText (nm, boldFont (fitSize (nm, 12.5, 116.0)), used ? ink : rgb (130, 132, 136), 20.0, y + 18.0, 0.0);
        if (tr != kAccentTrack && kd.pads[tr].numChoices == 2)
            drawSlide2 (rowChoiceRect (row), kd.pads[tr].choiceLabel[0], kd.pads[tr].choiceLabel[1], rowChoice[tr] == 1, kAmber, used);
        char lt[8];
        std::snprintf (lt, sizeof (lt), "%d", T.length);
        drawStepper (rowLenRect (row), lt);
        if (tr != kAccentTrack)
        {
            const tbdm::Channel& ch = e.song().channels[tr];
            drawButton (rowMuteRect (row), "M", ch.mute, kRed, 10.5);
            drawButton (rowSoloRect (row), "S", ch.solo, kYellow, 10.5);
        }

        // the steps
        const int tstep = ps >= 0 ? ps % (T.length < 1 ? 1 : T.length) : -1;
        for (int k = 0; k < kMaxSteps; ++k)
        {
            const NSRect r = cellRect (row, k);
            const tbdm::Step& s = T.steps[k];
            const bool inTrack = k < T.length;
            NSBezierPath* p = [NSBezierPath bezierPathWithRoundedRect: r xRadius: 3 yRadius: 3];
            const bool active = inTrack && s.on;
            if (active)
            {
                Lit c = tr == kAccentTrack ? kYellow : (s.choice ? kAmber : kRed);
                const bool dim = tr != kAccentTrack && (! used || e.song().channels[tr].mute || (anySolo && ! e.song().channels[tr].solo));
                if (dim) c.r = c.r * 2 / 3, c.g = c.g * 2 / 3, c.b = c.b * 2 / 3;
                [NSGraphicsContext saveGraphicsState];
                if (! dim) setGlow (litColor (c), 7.0);
                [litColor (c) set];
                [p fill];
                [NSGraphicsContext restoreGraphicsState];
                NSGradient* g = [[[NSGradient alloc] initWithColorsAndLocations: litLight (c), 0.0, litColor (c), 0.5, litDark (c), 1.0, nil] autorelease];
                [g drawInBezierPath: p angle: -90.0];
            }
            else if (inTrack)
            {
                NSGradient* g = [[[NSGradient alloc] initWithStartingColor: ((k / gGroup) & 1) ? rgb (212, 208, 198) : rgb (234, 230, 220)
                                                                endingColor: ((k / gGroup) & 1) ? rgb (168, 164, 156) : rgb (190, 186, 177)] autorelease];
                [g drawInBezierPath: p angle: -90.0];
            }
            else
            {
                [rgb (150, 146, 139) set];
                [p fill];
            }
            [((k == tstep && inTrack && e.isPlaying()) ? rgb (255, 255, 255) : rgb (60, 62, 66)) set];
            [p setLineWidth: (k == tstep && inTrack && e.isPlaying()) ? 2.4 : 0.8];
            [p stroke];
            if (active && tr != kAccentTrack)
            {
                // hits in the step as little bars, flams as a letter
                const int sub = s.sub < 1 ? 1 : s.sub;
                if (sub > 1)
                    for (int j = 0; j < sub; ++j)
                    {
                        [[NSColor colorWithCalibratedWhite: 0.0 alpha: 0.75] set];
                        const CGFloat bw = (kCellW - 6.0) / sub;
                        NSRectFill (NSMakeRect (r.origin.x + 3.0 + j * bw + 0.5, NSMaxY (r) - 7.0, bw - 1.5, 4.0));
                    }
                if (s.flam)
                    drawText (s.flam == 1 ? "A" : "B", boldFont (10.5), [NSColor blackColor], NSMidX (r), r.origin.y + 10.0);
            }
        }
    }
    // pattern end marker
    if (P.length < kMaxSteps)
    {
        const CGFloat x = cellX (P.length) - 3.0;
        [rgb (200, 30, 30) set];
        NSRectFill (NSMakeRect (x, kRowY0 + 2.0, 2.0, kNumTracks * kRowPitch - 4.0));
    }
}

- (void) drawPadsPage
{
    tbdm::Engine& e = core->engine;
    const tbdm::Pattern& P = e.song().patterns[e.currentPattern()];
    const tbdm::KitDef& kd = kitDef (P.kit);
    for (int pad = 0; pad < kNumPads; ++pad)
    {
        const tbdm::PadDef& d = kd.pads[pad];
        const NSRect r = padRect (pad);
        const bool used = d.numChoices > 0 && core->kits.padAvailable (P.kit, pad);
        drawText (d.numChoices ? d.label : "---", boldFont (14.0), used ? [NSColor blackColor] : rgb (130, 132, 136), NSMidX (r), r.origin.y - 14.0);
        const float fl = e.padFlash (pad);
        const int halves = d.numChoices == 2 ? 2 : 1;
        for (int h = 0; h < halves; ++h)
        {
            const NSRect hr = halves == 2 ? NSMakeRect (r.origin.x + h * (r.size.width * 0.5 + 2.0), r.origin.y, r.size.width * 0.5 - 2.0, r.size.height) : r;
            NSBezierPath* p = [NSBezierPath bezierPathWithRoundedRect: hr xRadius: 8 yRadius: 8];
            const float lit = (halves == 1 || e.padFlashChoice (pad) == h) ? fl : 0.0f;
            [NSGraphicsContext saveGraphicsState];
            NSShadow* sh = [[[NSShadow alloc] init] autorelease];
            [sh setShadowOffset: NSMakeSize (1.5, -3.0)];
            [sh setShadowBlurRadius: 5.0];
            [sh setShadowColor: [NSColor colorWithCalibratedWhite: 0.0 alpha: 0.5]];
            [sh set];
            [rgb (34, 35, 38) set];
            [p fill];
            [NSGraphicsContext restoreGraphicsState];
            NSGradient* g = [[[NSGradient alloc] initWithStartingColor: used ? rgb (78, 80, 86) : rgb (120, 122, 126)
                                                           endingColor: used ? rgb (36, 37, 41) : rgb (98, 100, 104)] autorelease];
            [g drawInBezierPath: p angle: -90.0];
            if (lit > 0.02f && used)
            {
                [NSGraphicsContext saveGraphicsState];
                setGlow ([litColor (kRed) colorWithAlphaComponent: lit], 16.0);
                [[litColor (kRed) colorWithAlphaComponent: 0.25 + 0.75 * lit] set];
                [p fill];
                [NSGraphicsContext restoreGraphicsState];
            }
            [rgb (20, 20, 22) set];
            [p setLineWidth: 1.2];
            [p stroke];
            if (halves == 2)
                drawText (d.choiceLabel[h], boldFont (fitSize (d.choiceLabel[h], 15.0, hr.size.width - 12.0)),
                          used ? rgb (236, 238, 240) : rgb (170, 172, 176), NSMidX (hr), NSMidY (hr));
        }
        // flam selector (707 SD B and toms)
        const bool flams = core->kits.flamAvailable (P.kit, pad, 0) || core->kits.flamAvailable (P.kit, pad, 1);
        if (flams)
        {
            const char* labs[3] = { "NORMAL", "FLAM A", "FLAM B" };
            for (int i = 0; i < 3; ++i) drawButton (padFlamRect (pad, i), labs[i], padFlam[pad] == i, kAmber, 10.5);
        }
    }
}

- (void) drawMixerPage
{
    tbdm::Engine& e = core->engine;
    const tbdm::Pattern& P = e.song().patterns[e.currentPattern()];
    const tbdm::KitDef& kd = kitDef (P.kit);
    NSColor* ink = [NSColor blackColor];
    for (int ch = 0; ch < kNumPads; ++ch)
    {
        const CGFloat x = mixX (ch), cx = x + kMixCx;
        const tbdm::Channel& c = e.song().channels[ch];
        // strip divider
        if (padPos (ch) > 0)
        {
            [rgba (0, 0, 0, 0.45) set];
            NSRectFill (NSMakeRect (x - 6.0, 162.0, 1.0, 452.0));
            [[NSColor colorWithCalibratedWhite: 1.0 alpha: 0.6] set];
            NSRectFill (NSMakeRect (x - 5.0, 162.0, 1.0, 452.0));
        }
        const char* nm = kd.pads[ch].numChoices ? kd.pads[ch].label : "---";
        drawText (nm, boldFont (fitSize (nm, 12.0, 78.0)), ink, cx - 6.0, 172.0);
        drawLed (NSMakePoint (x + 90.0, 172.0), e.padFlash (ch), kRed);
        drawText ("TUNE", boldFont (10.0), ink, cx, kMixTuneY - 36.0);
        drawKnob (NSMakePoint (cx, kMixTuneY), kMixKnobR, [self knobValue: kKTune + ch], kCapOrange);
        drawEnds (NSMakePoint (cx, kMixTuneY), kMixKnobR, "-12", 0, "+12");
        drawText ("DECAY", boldFont (10.0), ink, cx, kMixDecayY - 36.0);
        drawKnob (NSMakePoint (cx, kMixDecayY), kMixKnobR, [self knobValue: kKDecay + ch]);
        drawEnds (NSMakePoint (cx, kMixDecayY), kMixKnobR, "0", 0, "10");
        drawText ("PAN", boldFont (10.0), ink, cx, kMixPanY - 36.0);
        drawKnob (NSMakePoint (cx, kMixPanY), kMixKnobR, [self knobValue: kKPan + ch], kCapCream);
        drawEnds (NSMakePoint (cx, kMixPanY), kMixKnobR, "L", 0, "R");

        // fader: slot, scale and a cap
        NSBezierPath* slot = [NSBezierPath bezierPathWithRoundedRect: NSMakeRect (cx - 3.0, kFaderTop, 6.0, kFaderBot - kFaderTop) xRadius: 3 yRadius: 3];
        [rgb (20, 20, 22) set];
        [slot fill];
        for (int k = 0; k <= 10; ++k)
        {
            const CGFloat ty = kFaderBot - (kFaderBot - kFaderTop) * k / 10.0;
            [ink set];
            NSRectFill (NSMakeRect (cx - 20.0, ty - 0.5, k % 5 == 0 ? 9.0 : 6.0, 1.0));
            NSRectFill (NSMakeRect (cx + (k % 5 == 0 ? 11.0 : 14.0), ty - 0.5, k % 5 == 0 ? 9.0 : 6.0, 1.0));
        }
        drawText ("10", plainFont (8.5), ink, cx - 24.0, kFaderTop, 1.0);
        drawText ("0", plainFont (8.5), ink, cx - 24.0, kFaderBot, 1.0);
        const CGFloat fy = kFaderBot - (kFaderBot - kFaderTop) * c.level;
        const NSRect capR = NSMakeRect (cx - 15.0, fy - 8.0, 30.0, 16.0);
        NSBezierPath* cap = [NSBezierPath bezierPathWithRoundedRect: capR xRadius: 2 yRadius: 2];
        [NSGraphicsContext saveGraphicsState];
        NSShadow* sh = [[[NSShadow alloc] init] autorelease];
        [sh setShadowOffset: NSMakeSize (1.0, -2.0)];
        [sh setShadowBlurRadius: 3.0];
        [sh setShadowColor: [NSColor colorWithCalibratedWhite: 0.0 alpha: 0.5]];
        [sh set];
        NSGradient* cg = [[[NSGradient alloc] initWithColorsAndLocations:
                             rgb (250, 246, 232), 0.0, rgb (234, 228, 208), 0.45, rgb (190, 184, 164), 0.55, rgb (226, 220, 200), 1.0, nil] autorelease];
        [cg drawInBezierPath: cap angle: -90.0];
        [NSGraphicsContext restoreGraphicsState];
        [rgb (60, 58, 52) set];
        [cap setLineWidth: 0.8];
        [cap stroke];
        [rgb (20, 20, 20) set];
        NSRectFill (NSMakeRect (cx - 12.0, fy - 1.0, 24.0, 2.0));
        drawButton (mixMuteRect (ch), "MUTE", c.mute, kRed, 10.0);
        drawButton (mixSoloRect (ch), "SOLO", c.solo, kYellow, 10.0);
    }
}

- (void) drawSongPage
{
    tbdm::Engine& e = core->engine;
    const tbdm::Song& s = e.song();
    NSColor* ink = [NSColor blackColor];
    const bool songPlaying = e.isPlaying() && e.songMode();
    for (int i = 0; i < kMaxSong; ++i)
    {
        const NSRect r = songCell (i);
        NSBezierPath* p = [NSBezierPath bezierPathWithRoundedRect: r xRadius: 4 yRadius: 4];
        if (i < s.numEntries)
        {
            const bool now = songPlaying && e.songPosition() == i;
            if (now)
            {
                [NSGraphicsContext saveGraphicsState];
                setGlow (litColor (kRed), 10.0);
                [litColor (kRed) set];
                [p fill];
                [NSGraphicsContext restoreGraphicsState];
            }
            else
            {
                NSGradient* g = [[[NSGradient alloc] initWithStartingColor: rgb (78, 80, 86) endingColor: rgb (40, 41, 45)] autorelease];
                [g drawInBezierPath: p angle: -90.0];
            }
            NSColor* tc = rgb (236, 238, 240);
            char n[16];
            std::snprintf (n, sizeof (n), "%d", s.entries[i].pattern + 1);
            drawText (n, boldFont (20.0), tc, r.origin.x + 10.0, r.origin.y + 18.0, 0.0);
            std::snprintf (n, sizeof (n), "x%d", s.entries[i].repeats);
            drawText (n, boldFont (13.0), tc, NSMaxX (r) - 10.0, r.origin.y + 18.0, 1.0);
            const tbdm::Pattern& P = s.patterns[s.entries[i].pattern];
            char sub[64];
            std::snprintf (sub, sizeof (sub), "%s  %s", kitDef (P.kit).name, P.name);
            drawText (sub, plainFont (fitSize (sub, 10.0, r.size.width - 16.0, false)), tc, r.origin.x + 8.0, NSMaxY (r) - 12.0, 0.0);
        }
        else
        {
            [rgb (196, 192, 183) set];
            [p fill];
            if (i == s.numEntries)
                drawText ("+ ADD", boldFont (11.0), rgb (90, 92, 96), NSMidX (r), NSMidY (r));
        }
        if (i == selEntry && i < s.numEntries)
        {
            [rgb (230, 30, 30) set];
            [p setLineWidth: 3.0];
        }
        else
        {
            [rgb (60, 62, 66) set];
            [p setLineWidth: 1.0];
        }
        [p stroke];
    }

    drawText ("SONG MODE", boldFont (11.0), ink, NSMidX (kSongModeRect), kSongModeRect.origin.y - 10.0);
    drawSlide2 (kSongModeRect, "OFF", "ON", e.songMode(), kAmber);
    char t[48];
    std::snprintf (t, sizeof (t), "ADD PATTERN %d", e.currentPattern() + 1);
    drawButton (kSongAdd, t, false, kRed, 12.0);
    std::snprintf (t, sizeof (t), "INSERT PATTERN %d", e.currentPattern() + 1);
    drawButton (kSongInsert, t, false, kRed, 12.0, s.numEntries > 0);
    drawButton (kSongDelete, "DELETE", false, kRed, 12.0, s.numEntries > 0);
    const bool have = selEntry < s.numEntries;
    drawText ("PATTERN", boldFont (11.0), ink, NSMidX (kSongPattern), kSongPattern.origin.y - 10.0);
    std::snprintf (t, sizeof (t), "%d", have ? s.entries[selEntry].pattern + 1 : 0);
    drawStepper (kSongPattern, have ? t : "-", have);
    drawText ("REPEATS", boldFont (11.0), ink, NSMidX (kSongRepeats), kSongRepeats.origin.y - 10.0);
    std::snprintf (t, sizeof (t), "x%d", have ? s.entries[selEntry].repeats : 0);
    drawStepper (kSongRepeats, have ? t : "-", have);
    drawButton (kSongStart, "PLAY FROM HERE", false, kRed, 12.0, have);
    const bool armed = clearSongArmedUntil > [NSDate timeIntervalSinceReferenceDate];
    drawButton (kSongClear, armed ? "CLICK AGAIN" : "CLEAR SONG", armed, kRed, 12.0, s.numEntries > 0);
}

- (void) drawStrip
{
    tbdm::Engine& e = core->engine;
    const int cp = e.currentPattern();
    const int q = e.queuedPattern();
    const bool blinkOn = std::fmod ([NSDate timeIntervalSinceReferenceDate], 0.5) < 0.25;
    for (int i = 0; i < kNumPatterns; ++i)
    {
        const NSRect r = slotRect (i);
        NSBezierPath* p = [NSBezierPath bezierPathWithRoundedRect: r xRadius: 3 yRadius: 3];
        const bool used = ! e.song().patterns[i].isEmpty();
        const bool current = i == cp;
        const bool lime = current || (i == q && blinkOn);
        NSColor* fill = lime ? litColor (kRed) : (used ? rgb (46, 47, 50) : rgb (216, 212, 203));
        if (lime)
        {
            [NSGraphicsContext saveGraphicsState];
            setGlow (litColor (kRed), 10.0);
            [fill set];
            [p fill];
            [NSGraphicsContext restoreGraphicsState];
        }
        else
        {
            [fill set];
            [p fill];
        }
        [rgb (40, 41, 43) set];
        [p setLineWidth: 1.0];
        [p stroke];
        char n[4];
        std::snprintf (n, sizeof (n), "%d", i + 1);
        drawText (n, boldFont (12.0), lime ? [NSColor whiteColor] : (used ? [NSColor whiteColor] : rgb (120, 117, 110)), NSMidX (r), NSMidY (r));
    }
    const char* labs[4] = { "NAME", "COPY", "PASTE", "CLEAR" };
    const bool armed = clearArmedUntil > [NSDate timeIntervalSinceReferenceDate];
    for (int i = 0; i < 4; ++i)
        drawButton (patBtnRect (i), (i == 3 && armed) ? "AGAIN" : labs[i], i == 3 && armed, kRed, 11.5, i != 2 || clipboardFull);

    char text[160];
    [self composeReadout: text size: sizeof (text)];
    if (! nameField) [self drawLimeBox: kReadout text: text size: 18.0];
    else [self drawLimeBox: kReadout text: 0 size: 18.0];

    drawButton (kExportWav, "EXPORT AUDIO", false, kRed, 14.0);
    drawButton (kExportMidi, "EXPORT MIDI", false, kRed, 14.0);
}

- (void) drawRect: (NSRect) dirty
{
    (void) dirty;
    if (! core) return;
    [self syncOrder];
    [[self backdropImage] drawInRect: [self bounds] fromRect: NSZeroRect operation: NSCompositeCopy fraction: 1.0 respectFlipped: YES hints: nil];
    [NSGraphicsContext saveGraphicsState];
    NSAffineTransform* tr = [NSAffineTransform transform];
    [tr translateXBy: F yBy: F];
    [tr concat];
    NSRectClip (NSMakeRect (0, 0, W, kFaceHeight));
    [self drawTopBar];
    [self drawTabs];
    if (page == kPageSteps) [self drawStepsPage];
    else if (page == kPagePads) [self drawPadsPage];
    else if (page == kPageMixer) [self drawMixerPage];
    else [self drawSongPage];
    [self drawStrip];
    [NSGraphicsContext restoreGraphicsState];
    [self drawSidecar];
}

//------------------------------------------------------------------------------
// Pattern naming (the user's preset-naming standard)

- (void) dropRetired
{
    if (retiredField)
    {
        [retiredField removeFromSuperview];
        [retiredField release];
        retiredField = nil;
        if ([self window]) [[self window] makeFirstResponder: self];
    }
}

- (void) startNamingPattern
{
    if (! core) return;
    [self finishNaming: YES];
    namingPattern = core->engine.currentPattern();
    NSTextField* f = [[NSTextField alloc] initWithFrame: faceToView (NSInsetRect (kReadout, 8.0, 12.0))];
    [f setBezeled: NO];
    [f setBordered: NO];
    [f setDrawsBackground: YES];
    [f setBackgroundColor: rgb (222, 200, 154)];
    [f setFont: boldFont (18.0)];
    [f setTextColor: [NSColor blackColor]];
    [f setAlignment: NSCenterTextAlignment];
    [f setFocusRingType: NSFocusRingTypeNone];
    [[f cell] setScrollable: YES];
    char ph[64];
    std::snprintf (ph, sizeof (ph), "NAME PATTERN %d, THEN RETURN", namingPattern + 1);
    [[f cell] setPlaceholderString: str (ph)];
    [f setStringValue: str (core->engine.song().patterns[namingPattern].name)];
    [f setTarget: self];
    [f setAction: @selector (nameEntered:)];
    [f setDelegate: self];
    [self addSubview: f];
    nameField = f;
    messageUntil = 0.0;
    if ([self window]) [[self window] makeFirstResponder: nameField];
    [self setNeedsDisplay: YES];
}

// one line, trimmed, at most 40 bytes without splitting a UTF-8 character
static std::string cleanName (const char* s)
{
    std::string out;
    for (const char* p = s ? s : ""; *p; ++p)
    {
        unsigned char c = (unsigned char) *p;
        if (c == '\t' || c == '\n' || c == '\r') c = ' ';
        if (c < 32 || c == 127) continue;
        out += (char) c;
    }
    size_t a = out.find_first_not_of (' ');
    if (a == std::string::npos) return std::string();
    size_t b = out.find_last_not_of (' ');
    out = out.substr (a, b - a + 1);
    if (out.size() > 40)
    {
        size_t cut = 40;
        while (cut > 0 && (((unsigned char) out[cut]) & 0xC0) == 0x80) --cut;
        out = out.substr (0, cut);
        size_t e2 = out.find_last_not_of (' ');
        out = e2 == std::string::npos ? std::string() : out.substr (0, e2 + 1);
    }
    return out;
}

- (void) finishNaming: (BOOL) keep
{
    if (namingPattern < 0 || ! nameField) return;
    const int slot = namingPattern;
    namingPattern = -1;
    if (keep && core)
    {
        const std::string nm = cleanName ([[nameField stringValue] UTF8String]);
        core->engine.lock();
        tbdm::Pattern& P = core->engine.song().patterns[slot];
        std::memset (P.name, 0, sizeof (P.name));
        std::memcpy (P.name, nm.c_str(), nm.size() < 40 ? nm.size() : 40);
        core->engine.unlock();
        core->dirty = true;
    }
    readout[0] = 0;
    showPatternInReadout = true;
    [self dropRetired];
    retiredField = nameField;
    nameField = nil;
    [retiredField setDelegate: nil];
    [retiredField setTarget: nil];
    [self performSelector: @selector (dropRetired) withObject: nil afterDelay: 0.0];
    [self setNeedsDisplay: YES];
}

- (void) nameEntered: (id) sender { (void) sender; [self finishNaming: YES]; }
- (void) controlTextDidEndEditing: (NSNotification*) n { (void) n; [self finishNaming: YES]; }
- (BOOL) control: (NSControl*) c textView: (NSTextView*) tv doCommandBySelector: (SEL) sel
{
    (void) c; (void) tv;
    if (sel == @selector (cancelOperation:)) { [self finishNaming: NO]; return YES; }
    return NO;
}

//------------------------------------------------------------------------------
// Actions

- (void) togglePlay
{
    tbdm::Engine& e = core->engine;
    if (e.externalSync())
    {
        [self showMessage: "SYNC IS ON MIDI: START AND STOP FROM THE DAW"];
        return;
    }
    e.lock();
    if (e.isPlaying()) e.stop();
    else e.play();
    e.unlock();
    [self setNeedsDisplay: YES];
}

- (void) selectPatternSlot: (int) i
{
    tbdm::Engine& e = core->engine;
    if (e.songMode() && e.isPlaying())
    {
        [self showMessage: "SONG MODE: THE SONG CHOOSES THE PATTERNS"];
        return;
    }
    e.lock();
    e.selectPattern (i);
    e.unlock();
    readout[0] = 0;
    showPatternInReadout = true;
    messageUntil = 0.0;
    if (e.queuedPattern() >= 0)
    {
        char t[64];
        std::snprintf (t, sizeof (t), "PATTERN %d NEXT", i + 1);
        [self showMessage: t];
    }
    core->dirty = true;
    [self setNeedsDisplay: YES];
}

- (void) setKit: (int) k
{
    tbdm::Engine& e = core->engine;
    if (core->kits.samplesLoaded (k) == 0)
    {
        char t[128];
        std::snprintf (t, sizeof (t), "%s KIT NOT FOUND: KITS MENU > SHOW KITS FOLDER", kitDef (k).name);
        [self showMessage: t];
    }
    e.lock();
    e.song().patterns[e.currentPattern()].kit = k;
    e.unlock();
    char t[64];
    std::snprintf (t, sizeof (t), "PATTERN %d   %s KIT", e.currentPattern() + 1, kitDef (k).name);
    [self setReadout: t];
    [self touched];
}

- (void) timeSigChosen: (NSMenuItem*) item { [self setTimeSignature: (int) [item tag]]; }

// A time signature sets the bar: the pattern and every track take its length,
// and the grid groups by its beats; only those steps stay lit.
- (void) setTimeSignature: (int) sig
{
    if (! core || sig < 0 || sig >= kNumSigs) return;
    tbdm::Engine& e = core->engine;
    e.lock();
    tbdm::Pattern& P = e.song().patterns[e.currentPattern()];
    P.sig = sig;
    P.length = sigDef (sig).steps;
    for (int t = 0; t < kNumTracks; ++t) P.tracks[t].length = P.length;
    e.unlock();
    char t[64];
    std::snprintf (t, sizeof (t), "TIME SIGNATURE   %s   %d STEPS", sigDef (sig).name, sigDef (sig).steps);
    [self setReadout: t];
    [self touched];
}

- (void) stepClick: (int) row step: (int) k
{
    tbdm::Engine& e = core->engine;
    const int cp = e.currentPattern();
    const int tr = rowTrack (row);
    e.lock();
    tbdm::Pattern& P = e.song().patterns[cp];
    tbdm::Track& T = P.tracks[tr];
    if (k >= T.length) { T.length = k + 1; }       // clicking past the end lengthens the track
    tbdm::Step& s = T.steps[k];
    const tbdm::KitDef& kd = kitDef (P.kit);
    char t[128];
    t[0] = 0;
    const char* nm = tr == kAccentTrack ? "ACCENT" : kd.pads[tr].label;
    if (editMode == kModeStep || tr == kAccentTrack)
    {
        paintOn = ! s.on;
        s.on = paintOn;
        if (paintOn && tr != kAccentTrack)
        {
            s.choice = (unsigned char) (kd.pads[tr].numChoices == 2 ? rowChoice[tr] : 0);
            s.flam = 0;
            s.sub = 1;
        }
        dragKind = 2;
        paintRow = row;
        std::snprintf (t, sizeof (t), "%s   STEP %d %s", nm, k + 1, s.on ? "ON" : "OFF");
    }
    else if (editMode == kModeChoice)
    {
        if (kd.pads[tr].numChoices == 2)
        {
            if (! s.on) { s.on = 1; s.choice = 1; s.sub = 1; s.flam = 0; }
            else s.choice = s.choice ? 0 : 1;
            std::snprintf (t, sizeof (t), "%s   STEP %d   %s", nm, k + 1, kd.pads[tr].choiceLabel[s.choice]);
        }
        else std::snprintf (t, sizeof (t), "%s HAS ONE SOUND", nm);
    }
    else if (editMode == kModeFlam)
    {
        const int ch = s.on ? s.choice : (kd.pads[tr].numChoices == 2 ? rowChoice[tr] : 0);
        if (core->kits.flamAvailable (P.kit, tr, ch))
        {
            if (! s.on) { s.on = 1; s.choice = (unsigned char) ch; s.sub = 1; s.flam = 1; }
            else s.flam = (unsigned char) ((s.flam + 1) % 3);
            const char* fn[3] = { "NORMAL", "FLAM A", "FLAM B" };
            std::snprintf (t, sizeof (t), "%s   STEP %d   %s", nm, k + 1, fn[s.flam]);
        }
        else std::snprintf (t, sizeof (t), "NO FLAM SAMPLES FOR %s %s", nm, kd.pads[tr].numChoices == 2 ? kd.pads[tr].choiceLabel[ch] : "");
    }
    else
    {
        if (! s.on) { s.on = 1; s.choice = (unsigned char) (kd.pads[tr].numChoices == 2 ? rowChoice[tr] : 0); s.flam = 0; s.sub = 2; }
        else s.sub = (unsigned char) (s.sub >= 4 ? 1 : s.sub + 1);
        std::snprintf (t, sizeof (t), "%s   STEP %d   %d HIT%s", nm, k + 1, s.sub, s.sub > 1 ? "S" : "");
    }
    e.unlock();
    [self setReadout: t];
    [self touched];
}

- (void) paintAt: (NSPoint) p
{
    if (paintRow < 0) return;
    for (int k = 0; k < kMaxSteps; ++k)
    {
        NSRect r = cellRect (paintRow, k);
        r.origin.y -= 6.0;
        r.size.height += 12.0;
        r.size.width += 3.0;
        if (! inRect (p, r)) continue;
        tbdm::Engine& e = core->engine;
        e.lock();
        tbdm::Pattern& P = e.song().patterns[e.currentPattern()];
        const int tr = rowTrack (paintRow);
        tbdm::Track& T = P.tracks[tr];
        if (k < T.length)
        {
            tbdm::Step& s = T.steps[k];
            if ((s.on != 0) != paintOn)
            {
                s.on = paintOn;
                if (paintOn && tr != kAccentTrack)
                {
                    s.choice = (unsigned char) (kitDef (P.kit).pads[tr].numChoices == 2 ? rowChoice[tr] : 0);
                    s.flam = 0;
                    s.sub = 1;
                }
                core->dirty = true;
            }
        }
        e.unlock();
        [self setNeedsDisplay: YES];
        return;
    }
}

- (void) songAction: (NSPoint) p
{
    tbdm::Engine& e = core->engine;
    tbdm::Song& s = e.song();
    const NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    char t[96];
    t[0] = 0;
    e.lock();
    for (int i = 0; i < kMaxSong; ++i)
        if (inRect (p, songCell (i)))
        {
            if (i < s.numEntries) selEntry = i;
            else if (s.numEntries < kMaxSong)
            {
                s.entries[s.numEntries].pattern = e.currentPattern();
                s.entries[s.numEntries].repeats = 1;
                selEntry = s.numEntries++;
                std::snprintf (t, sizeof (t), "SONG   PATTERN %d ADDED AT %d", e.currentPattern() + 1, selEntry + 1);
            }
            break;
        }
    if (inRect (p, kSongModeRect))
    {
        e.setSongMode (p.x >= NSMidX (kSongModeRect));
        std::snprintf (t, sizeof (t), "SONG MODE   %s", e.songMode() ? (s.numEntries ? "ON" : "ON (ADD PATTERNS TO THE SONG)") : "OFF");
    }
    else if (inRect (p, kSongAdd) && s.numEntries < kMaxSong)
    {
        s.entries[s.numEntries].pattern = e.currentPattern();
        s.entries[s.numEntries].repeats = 1;
        selEntry = s.numEntries++;
        std::snprintf (t, sizeof (t), "SONG   PATTERN %d ADDED AT %d", e.currentPattern() + 1, selEntry + 1);
    }
    else if (inRect (p, kSongInsert) && s.numEntries > 0 && s.numEntries < kMaxSong)
    {
        const int at = clampi (selEntry, 0, s.numEntries);
        for (int i = s.numEntries; i > at; --i) s.entries[i] = s.entries[i - 1];
        s.entries[at].pattern = e.currentPattern();
        s.entries[at].repeats = 1;
        ++s.numEntries;
        std::snprintf (t, sizeof (t), "SONG   PATTERN %d INSERTED AT %d", e.currentPattern() + 1, at + 1);
    }
    else if (inRect (p, kSongDelete) && s.numEntries > 0 && selEntry < s.numEntries)
    {
        for (int i = selEntry; i < s.numEntries - 1; ++i) s.entries[i] = s.entries[i + 1];
        --s.numEntries;
        if (selEntry >= s.numEntries && selEntry > 0) --selEntry;
        if (e.songPosition() >= s.numEntries) e.setSongPosition (0);
        std::snprintf (t, sizeof (t), "SONG   STEP DELETED");
    }
    else if (selEntry < s.numEntries && stepperSide (kSongPattern, p))
    {
        tbdm::SongEntry& en = s.entries[selEntry];
        en.pattern = (en.pattern + stepperSide (kSongPattern, p) + kNumPatterns) % kNumPatterns;
        std::snprintf (t, sizeof (t), "SONG %d   PATTERN %d", selEntry + 1, en.pattern + 1);
    }
    else if (selEntry < s.numEntries && stepperSide (kSongRepeats, p))
    {
        tbdm::SongEntry& en = s.entries[selEntry];
        en.repeats = clampi (en.repeats + stepperSide (kSongRepeats, p), 1, 16);
        std::snprintf (t, sizeof (t), "SONG %d   PLAYS %d TIME%s", selEntry + 1, en.repeats, en.repeats > 1 ? "S" : "");
    }
    else if (inRect (p, kSongStart) && selEntry < s.numEntries)
    {
        e.setSongMode (true);
        e.setSongPosition (selEntry);
        if (! e.externalSync()) e.play();
        std::snprintf (t, sizeof (t), "SONG   PLAYING FROM %d", selEntry + 1);
    }
    else if (inRect (p, kSongClear) && s.numEntries > 0)
    {
        if (clearSongArmedUntil > now)
        {
            s.numEntries = 0;
            selEntry = 0;
            clearSongArmedUntil = 0.0;
            std::snprintf (t, sizeof (t), "SONG CLEARED");
        }
        else
        {
            clearSongArmedUntil = now + 3.0;
            std::snprintf (t, sizeof (t), "CLICK CLEAR SONG AGAIN TO CLEAR THE SONG");
        }
    }
    e.unlock();
    if (t[0]) [self setReadout: t];
    [self touched];
}

- (void) patternButton: (int) i
{
    tbdm::Engine& e = core->engine;
    const int cp = e.currentPattern();
    char t[96];
    if (i == 0) { [self startNamingPattern]; return; }
    if (i == 1)
    {
        clipboard = e.song().patterns[cp];
        clipboardFull = true;
        std::snprintf (t, sizeof (t), "PATTERN %d COPIED", cp + 1);
        [self setReadout: t];
    }
    else if (i == 2)
    {
        if (! clipboardFull) return;
        e.lock();
        e.song().patterns[cp] = clipboard;
        e.unlock();
        std::snprintf (t, sizeof (t), "PASTED INTO PATTERN %d", cp + 1);
        [self setReadout: t];
    }
    else
    {
        const NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
        if (clearArmedUntil > now)
        {
            e.lock();
            const int kit = e.song().patterns[cp].kit;
            e.song().patterns[cp].clear();
            e.song().patterns[cp].kit = kit;
            e.unlock();
            clearArmedUntil = 0.0;
            std::snprintf (t, sizeof (t), "PATTERN %d CLEARED", cp + 1);
        }
        else
        {
            clearArmedUntil = now + 3.0;
            std::snprintf (t, sizeof (t), "CLICK CLEAR AGAIN TO CLEAR PATTERN %d", cp + 1);
        }
        [self setReadout: t];
    }
    [self touched];
}

//------------------------------------------------------------------------------
// Export

// Which range: the whole song or the current pattern (times n), and for audio
// what to write (stereo mix, separate tracks or both) at 44.1 or 48 kHz. Test
// mode skips the questions and the save panel.
- (BOOL) askRange: (tbdm::ExportRange&) r path: (std::string&) path type: (NSString*) ext title: (NSString*) title
             audio: (bool) audio mode: (int&) mode rate: (int&) rate
{
    tbdm::Engine& e = core->engine;
    r.wholeSong = false;
    r.pattern = e.currentPattern();
    r.loops = 1;
    mode = 0;
    rate = 44100;
    if (core->testMode)
    {
        r.wholeSong = e.song().numEntries > 0;
        r.loops = 2;
        mode = 2;
        rate = 48000;
        path = core->testExportDir + (r.wholeSong ? "/song." : "/pattern.") + [ext UTF8String];
        return YES;
    }
    NSAlert* a = [[[NSAlert alloc] init] autorelease];
    [a setMessageText: title];
    [a setInformativeText: e.song().numEntries > 0 ? @"Export the whole song once through, or the current pattern repeated?"
                                                    : @"The song is empty, so the current pattern is exported."];
    if (e.song().numEntries > 0) [a addButtonWithTitle: @"Song"];
    [a addButtonWithTitle: [NSString stringWithFormat: @"Pattern %d", e.currentPattern() + 1]];
    [a addButtonWithTitle: @"Cancel"];

    // names (the song's and the pattern's) and the export choices
    const bool hasSong = e.song().numEntries > 0;
    const CGFloat rowH = 30.0, wAcc = 320.0, labW = 100.0;
    const int rows = (hasSong ? 1 : 0) + 1 + 1 + (audio ? 2 : 0);
    NSView* acc = [[[NSView alloc] initWithFrame: NSMakeRect (0, 0, wAcc, rows * rowH)] autorelease];
    int row = rows - 1;
    NSTextField* songName = nil;
    NSTextField* patName = nil;
    const tbdm::Pattern& P0 = e.song().patterns[r.pattern];
    for (int which = 0; which < 2; ++which)
    {
        if (which == 0 && ! hasSong) continue;
        NSTextField* lab = [[[NSTextField alloc] initWithFrame: NSMakeRect (0, row * rowH + 3, labW, 20)] autorelease];
        [lab setStringValue: which == 0 ? @"Song name:" : [NSString stringWithFormat: @"Pattern %d name:", r.pattern + 1]];
        [lab setBezeled: NO];
        [lab setDrawsBackground: NO];
        [lab setEditable: NO];
        [lab setSelectable: NO];
        [lab setAlignment: NSRightTextAlignment];
        [acc addSubview: lab];
        NSTextField* f = [[[NSTextField alloc] initWithFrame: NSMakeRect (labW + 6, row * rowH + 2, wAcc - labW - 6, 22)] autorelease];
        [f setStringValue: which == 0 ? str (e.song().name[0] ? e.song().name : "TB Drum Machine Song")
                                      : (P0.name[0] ? str (P0.name) : [NSString stringWithFormat: @"TB Drum Machine Pattern %d", r.pattern + 1])];
        [acc addSubview: f];
        if (which == 0) songName = f; else patName = f;
        --row;
    }
    NSPopUpButton* times = [[[NSPopUpButton alloc] initWithFrame: NSMakeRect (0, row * rowH, wAcc, 26) pullsDown: NO] autorelease];
    const int counts[6] = { 1, 2, 4, 8, 16, 32 };
    for (int i = 0; i < 6; ++i) [times addItemWithTitle: [NSString stringWithFormat: @"Pattern %d time%s", counts[i], counts[i] > 1 ? "s" : ""]];
    [acc addSubview: times];
    --row;
    NSPopUpButton* what = nil;
    NSPopUpButton* rates = nil;
    if (audio)
    {
        what = [[[NSPopUpButton alloc] initWithFrame: NSMakeRect (0, row * rowH, wAcc, 26) pullsDown: NO] autorelease];
        [what addItemWithTitle: @"Stereo mix (one stereo WAV)"];
        [what addItemWithTitle: @"Separate tracks (one mono WAV per pad)"];
        [what addItemWithTitle: @"Both: stereo mix and separate tracks"];
        [acc addSubview: what];
        --row;
        rates = [[[NSPopUpButton alloc] initWithFrame: NSMakeRect (0, row * rowH, wAcc, 26) pullsDown: NO] autorelease];
        [rates addItemWithTitle: @"44.1 kHz, 24-bit"];
        [rates addItemWithTitle: @"48 kHz, 24-bit"];
        [acc addSubview: rates];
    }
    [a setAccessoryView: acc];
    [[a window] setInitialFirstResponder: songName ? songName : patName];
    const NSInteger b = [a runModal];
    if (hasSong && b == NSAlertFirstButtonReturn) r.wholeSong = true;
    else if ((hasSong && b == NSAlertSecondButtonReturn) || (! hasSong && b == NSAlertFirstButtonReturn))
        r.loops = counts[clampi ((int) [times indexOfSelectedItem], 0, 5)];
    else return NO;
    if (audio)
    {
        mode = clampi ((int) [what indexOfSelectedItem], 0, 2);
        rate = [rates indexOfSelectedItem] == 1 ? 48000 : 44100;
    }
    // keep the names: the song's for next time, the pattern's as its name on the panel
    e.lock();
    if (songName)
    {
        const std::string nm = cleanName ([[songName stringValue] UTF8String]);
        std::memset (e.song().name, 0, sizeof (e.song().name));
        std::memcpy (e.song().name, nm.c_str(), nm.size() < 40 ? nm.size() : 40);
    }
    if (patName && ! r.wholeSong)
    {
        const std::string nm = cleanName ([[patName stringValue] UTF8String]);
        tbdm::Pattern& Pn = e.song().patterns[r.pattern];
        std::memset (Pn.name, 0, sizeof (Pn.name));
        std::memcpy (Pn.name, nm.c_str(), nm.size() < 40 ? nm.size() : 40);
    }
    e.unlock();
    core->dirty = true;
    std::string chosen = cleanName ([[(r.wholeSong ? songName : patName) stringValue] UTF8String]);
    if (chosen.empty()) chosen = r.wholeSong ? "TB Drum Machine Song" : "TB Drum Machine Pattern";
    for (size_t i = 0; i < chosen.size(); ++i) if (chosen[i] == '/' || chosen[i] == ':') chosen[i] = '-';

    NSSavePanel* sp = [NSSavePanel savePanel];
    [sp setAllowedFileTypes: [NSArray arrayWithObject: ext]];
    [sp setTitle: title];
    if (audio && mode == 1) [sp setMessage: @"The mono tracks go in a folder with this name."];
    else if (audio && mode == 2) [sp setMessage: @"The stereo mix gets this name; the mono tracks go in a folder with the same name."];
    [sp setNameFieldStringValue: [str (chosen.c_str()) stringByAppendingPathExtension: ext]];
    if ([sp runModal] != NSFileHandlingPanelOKButton) return NO;
    path = [[[sp URL] path] UTF8String];
    return YES;
}

- (void) exportWav: (id) sender
{
    (void) sender;
    tbdm::ExportRange r;
    std::string path;
    int mode = 0, rate = 44100;
    if (! [self askRange: r path: path type: @"wav" title: @"Export Audio" audio: true mode: mode rate: rate]) return;
    tbdm::Song copy;
    core->engine.lock();
    copy = core->engine.song();
    core->engine.unlock();
    [self showMessage: "EXPORTING..."];
    [self display];

    const char* fn = std::strrchr (path.c_str(), '/');
    fn = fn ? fn + 1 : path.c_str();
    long frames = 0;
    bool ok = true;
    int tracks = 0;
    if (mode == 0 || mode == 2) ok = tbdm::exportWav (path.c_str(), copy, core->kits, r, rate, 4.0, &frames);
    if (ok && (mode == 1 || mode == 2))
    {
        // "My Song.wav" -> the mono tracks in a folder "My Song" beside it
        std::string dir = path;
        if (dir.size() > 4 && dir.compare (dir.size() - 4, 4, ".wav") == 0) dir.erase (dir.size() - 4);
        [[NSFileManager defaultManager] createDirectoryAtPath: str (dir.c_str()) withIntermediateDirectories: YES attributes: nil error: nil];
        int order[kNumPads];
        for (int i = 0; i < kNumPads; ++i) order[i] = padAt (i);
        tracks = tbdm::exportWavTracks (dir.c_str(), copy, core->kits, r, rate, 4.0, order, &frames);
        ok = tracks >= 0;
    }
    char t[200];
    const char* khz = rate == 48000 ? "48 kHz" : "44.1 kHz";
    if (! ok) std::snprintf (t, sizeof (t), "COULDN'T WRITE %s", fn);
    else if (mode == 0) std::snprintf (t, sizeof (t), "EXPORTED %s  (%.1f s, %s)", fn, frames / (double) rate, khz);
    else if (mode == 1) std::snprintf (t, sizeof (t), "EXPORTED %d TRACKS  (%.1f s, %s)", tracks, frames / (double) rate, khz);
    else std::snprintf (t, sizeof (t), "EXPORTED %s + %d TRACKS  (%s)", fn, tracks, khz);
    [self showMessage: t];
}

- (void) exportMidi: (id) sender
{
    (void) sender;
    ExportRange r;
    std::string path;
    int mode = 0, rate = 0;
    if (! [self askRange: r path: path type: @"mid" title: @"Export MIDI" audio: false mode: mode rate: rate]) return;
    tbdm::Song copy;
    core->engine.lock();
    copy = core->engine.song();
    core->engine.unlock();
    const bool ok = exportMidi (path.c_str(), copy, r);
    char t[160];
    const char* fn = std::strrchr (path.c_str(), '/');
    if (ok) std::snprintf (t, sizeof (t), "EXPORTED %s", fn ? fn + 1 : path.c_str());
    else std::snprintf (t, sizeof (t), "COULDN'T WRITE %s", fn ? fn + 1 : path.c_str());
    [self showMessage: t];
}

//------------------------------------------------------------------------------
// Mouse and keys

- (void) mouseDown: (NSEvent*) ev
{
    if (! core) return;
    if (nameField) [self finishNaming: YES];
    [[self window] makeFirstResponder: self];
    [self syncOrder];
    const NSPoint p = viewToFace ([self convertPoint: [ev locationInWindow] fromView: nil]);
    tbdm::Engine& e = core->engine;
    dragKind = 0;
    paintRow = -1;

    // the M-50 Master sidecar
    if (p.x + F >= kSideX)
    {
        const int sc = [self sideControlAt: viewToSide (NSMakePoint (p.x + F, p.y + F))];
        if (sc == -2)
        {
            e.lock();
            e.song().eqBypass = ! e.song().eqBypass;
            e.unlock();
            [self setReadout: e.song().eqBypass ? "EQ BYPASS   ON (EQ OUT)" : "EQ BYPASS   OFF (EQ IN)"];
            [self touched];
        }
        else if (sc >= 0)
        {
            if ([ev clickCount] >= 2) { [self setKnob: sc value: [self knobDefault: sc]]; return; }
            dragKind = 1;
            dragId = sc;
            dragStartY = p.y;
            dragStartV = [self knobValue: sc];
            [self describeKnob: sc];
            [self setNeedsDisplay: YES];
        }
        return;
    }

    // knobs and faders
    const int k = [self knobAt: p];
    if (k >= 0)
    {
        if ([ev clickCount] >= 2) { [self setKnob: k value: [self knobDefault: k]]; return; }
        dragKind = 1;
        dragId = k;
        dragStartY = p.y;
        dragStartV = [self knobValue: k];
        [self describeKnob: k];
        [self setNeedsDisplay: YES];
        return;
    }
    if (inRect (p, kPlayRect)) { [self togglePlay]; return; }
    if (inRect (p, kRecRect))
    {
        e.lock();
        e.setRecording (! e.isRecording());
        e.unlock();
        [self setReadout: e.isRecording() ? "REC ON   PADS AND MIDI NOTES RECORD INTO THE PATTERN" : "REC OFF"];
        [self setNeedsDisplay: YES];
        return;
    }
    if (inRect (p, kSyncRect))
    {
        const bool midi = p.x >= NSMidX (kSyncRect);
        e.lock();
        if (midi != e.externalSync())
        {
            e.stop();
            e.setExternalSync (midi);
        }
        e.unlock();
        [self setReadout: midi ? "SYNC   MIDI CLOCK (PLAY FROM THE DAW)" : "SYNC   INTERNAL"];
        [self touched];
        return;
    }
    for (int i = 0; i < kNumKits; ++i) if (inRect (p, kitRect (i))) { [self setKit: i]; return; }
    for (int i = 0; i < 4; ++i) if (inRect (p, tabRect (i))) { page = i; core->dirty = true; [self setNeedsDisplay: YES]; return; }
    for (int i = 0; i < kNumPatterns; ++i) if (inRect (p, slotRect (i))) { [self selectPatternSlot: i]; return; }
    for (int i = 0; i < 4; ++i) if (inRect (p, patBtnRect (i))) { [self patternButton: i]; return; }
    if (inRect (p, kReadout))
    {
        if (showPatternInReadout || ! readout[0]) [self startNamingPattern];
        return;
    }
    if (inRect (p, kExportWav)) { [self exportWav: nil]; return; }
    if (inRect (p, kExportMidi)) { [self exportMidi: nil]; return; }

    if (page == kPageSteps)
    {
        if (inRect (p, kTimeRect))
        {
            NSMenu* m = [[[NSMenu alloc] initWithTitle: @"Time signature"] autorelease];
            const int cur = e.song().patterns[e.currentPattern()].sig;
            for (int i = 0; i < kNumSigs; ++i)
            {
                NSString* title = [NSString stringWithFormat: @"%s   (%d steps)", sigDef (i).name, sigDef (i).steps];
                NSMenuItem* it = [[[NSMenuItem alloc] initWithTitle: title action: @selector (timeSigChosen:) keyEquivalent: @""] autorelease];
                [it setTarget: self];
                [it setTag: i];
                [it setState: i == cur ? NSOnState : NSOffState];
                [m addItem: it];
            }
            [m popUpMenuPositioningItem: [m itemAtIndex: cur] atLocation: NSMakePoint (kTimeRect.origin.x + F, NSMaxY (kTimeRect) + F - 4.0) inView: self];
            return;
        }
        if (stepperSide (kLengthRect, p))
        {
            e.lock();
            tbdm::Pattern& P = e.song().patterns[e.currentPattern()];
            const int old = P.length;
            P.length = clampi (P.length + stepperSide (kLengthRect, p), 1, kMaxSteps);
            // tracks that ran the full old length follow the pattern
            for (int t = 0; t < kNumTracks; ++t)
                if (P.tracks[t].length == old) P.tracks[t].length = P.length;
            e.unlock();
            char t[48];
            std::snprintf (t, sizeof (t), "PATTERN LENGTH   %d STEPS", P.length);
            [self setReadout: t];
            [self touched];
            return;
        }
        for (int i = 0; i < 4; ++i)
            if (inRect (p, modeRect (i)))
            {
                editMode = i;
                const char* help[4] = { "CLICK STEPS ON AND OFF (DRAG TO PAINT)", "CLICK A STEP TO SWAP ITS SOUND A / B",
                                        "CLICK A STEP: NORMAL, FLAM A, FLAM B", "CLICK A STEP: 1, 2, 3 OR 4 HITS" };
                [self setReadout: help[i]];
                [self setNeedsDisplay: YES];
                return;
            }
        for (int row = 0; row < kNumTracks; ++row)
        {
            const int tr = rowTrack (row);
            if (tr != kAccentTrack && inRect (p, rowChoiceRect (row)) && kitDef (e.song().patterns[e.currentPattern()].kit).pads[tr].numChoices == 2)
            {
                rowChoice[tr] = p.x >= NSMidX (rowChoiceRect (row)) ? 1 : 0;
                const tbdm::PadDef& d = kitDef (e.song().patterns[e.currentPattern()].kit).pads[tr];
                char t[96];
                std::snprintf (t, sizeof (t), "%s   NEW STEPS PLAY %s", d.label, d.choiceLabel[rowChoice[tr]]);
                [self setReadout: t];
                e.lock();
                e.hitPad (tr, rowChoice[tr], 0, false);
                e.unlock();
                [self setNeedsDisplay: YES];
                return;
            }
            if (stepperSide (rowLenRect (row), p))
            {
                e.lock();
                tbdm::Track& T = e.song().patterns[e.currentPattern()].tracks[tr];
                T.length = clampi (T.length + stepperSide (rowLenRect (row), p), 1, kMaxSteps);
                e.unlock();
                char t[64];
                std::snprintf (t, sizeof (t), "%s   TRACK LENGTH %d", tr == kAccentTrack ? "ACCENT" : [self padName: tr], T.length);
                [self setReadout: t];
                [self touched];
                return;
            }
            if (tr != kAccentTrack && (inRect (p, rowMuteRect (row)) || inRect (p, rowSoloRect (row))))
            {
                e.lock();
                tbdm::Channel& c = e.song().channels[tr];
                if (inRect (p, rowMuteRect (row))) c.mute = ! c.mute;
                else c.solo = ! c.solo;
                e.unlock();
                [self touched];
                return;
            }
            for (int s = 0; s < kMaxSteps; ++s)
                if (inRect (p, cellRect (row, s))) { [self stepClick: row step: s]; return; }
            // clicking the row name plays the pad
            if (tr != kAccentTrack && inRect (p, NSMakeRect (14.0, kRowY0 + row * kRowPitch + 2.0, 122.0, 32.0)))
            {
                e.lock();
                e.hitPad (tr, rowChoice[tr], 0, false);
                e.unlock();
                return;
            }
        }
    }
    else if (page == kPagePads)
    {
        const tbdm::KitDef& kd = kitDef (e.song().patterns[e.currentPattern()].kit);
        for (int pad = 0; pad < kNumPads; ++pad)
        {
            for (int i = 0; i < 3; ++i)
                if (inRect (p, padFlamRect (pad, i)) && (core->kits.flamAvailable (e.song().patterns[e.currentPattern()].kit, pad, 0)
                                                         || core->kits.flamAvailable (e.song().patterns[e.currentPattern()].kit, pad, 1)))
                {
                    padFlam[pad] = i;
                    [self setNeedsDisplay: YES];
                    return;
                }
            const NSRect r = padRect (pad);
            if (inRect (p, r) && kd.pads[pad].numChoices > 0)
            {
                const int half = kd.pads[pad].numChoices == 2 && p.x >= NSMidX (r) ? 1 : 0;
                const bool acc = ([ev modifierFlags] & NSAlternateKeyMask) != 0;
                const int flam = core->kits.flamAvailable (e.song().patterns[e.currentPattern()].kit, pad, half) ? padFlam[pad] : 0;
                e.lock();
                e.hitPad (pad, half, flam, acc);
                e.unlock();
                if (e.isRecording() && e.isPlaying()) core->dirty = true;
                [self setNeedsDisplay: YES];
                return;
            }
        }
    }
    else if (page == kPageMixer)
    {
        for (int ch = 0; ch < kNumPads; ++ch)
            if (inRect (p, mixMuteRect (ch)) || inRect (p, mixSoloRect (ch)))
            {
                e.lock();
                tbdm::Channel& c = e.song().channels[ch];
                if (inRect (p, mixMuteRect (ch))) c.mute = ! c.mute;
                else c.solo = ! c.solo;
                e.unlock();
                char t[64];
                std::snprintf (t, sizeof (t), "%s   %s %s", [self padName: ch], inRect (p, mixMuteRect (ch)) ? "MUTE" : "SOLO",
                               (inRect (p, mixMuteRect (ch)) ? c.mute : c.solo) ? "ON" : "OFF");
                [self setReadout: t];
                [self touched];
                return;
            }
    }
    else if (page == kPageSong)
        [self songAction: p];
}

- (void) mouseDragged: (NSEvent*) ev
{
    if (! core) return;
    [self syncOrder];
    const NSPoint p = viewToFace ([self convertPoint: [ev locationInWindow] fromView: nil]);
    if (dragKind == 1)
    {
        const bool fine = ([ev modifierFlags] & NSShiftKeyMask) != 0;
        const CGFloat range = dragId == kKFader ? (kSFaderBot - kSFaderTop) : ((dragId >= kKLevel && dragId < kKEqFreq) ? (kFaderBot - kFaderTop) : 200.0);
        const float v = (float) (dragStartV + (dragStartY - p.y) / range * (fine ? 0.1 : 1.0));
        [self setKnob: dragId value: v];
    }
    else if (dragKind == 2) [self paintAt: p];
}

- (void) mouseUp: (NSEvent*) ev
{
    (void) ev;
    dragKind = 0;
    paintRow = -1;
}

- (void) scrollWheel: (NSEvent*) ev
{
    if (! core) return;
    [self syncOrder];
    const NSPoint p = viewToFace ([self convertPoint: [ev locationInWindow] fromView: nil]);
    int k = [self knobAt: p];
    if (p.x + F >= kSideX) k = [self sideControlAt: viewToSide (NSMakePoint (p.x + F, p.y + F))];
    if (k < 0) return;
    const CGFloat dy = [ev deltaY];
    if (dy == 0.0) return;
    [self setKnob: k value: [self knobValue: k] + (dy > 0 ? 1.0f : -1.0f) * (k == kKTempo ? 1.0f / 270.0f : (k >= kKTune && k < kKDecay ? 0.5f / 24.0f : 0.01f))];
}

- (void) keyDown: (NSEvent*) ev
{
    NSString* c = [ev charactersIgnoringModifiers];
    if ([c length] == 1)
    {
        const unichar ch = [c characterAtIndex: 0];
        if (ch == ' ') { [self togglePlay]; return; }
        if (ch == 'r' || ch == 'R')
        {
            core->engine.lock();
            core->engine.setRecording (! core->engine.isRecording());
            core->engine.unlock();
            [self setNeedsDisplay: YES];
            return;
        }
        if (ch >= '1' && ch <= '4') { [self setPage: ch - '1']; return; }
    }
    [super keyDown: ev];
}

//------------------------------------------------------------------------------
// Test hooks

- (NSRect) rectForStep: (int) k row: (int) row { [self syncOrder]; return faceToView (cellRect (row, k)); }
- (NSRect) rectForPad: (int) pad half: (int) half
{
    [self syncOrder];
    const NSRect r = padRect (pad);
    if (half < 0) return faceToView (r);
    return faceToView (NSMakeRect (r.origin.x + half * r.size.width * 0.5, r.origin.y, r.size.width * 0.5, r.size.height));
}
- (NSRect) rectForTab: (int) i { return faceToView (tabRect (i)); }
- (NSRect) rectForPatternSlot: (int) i { return faceToView (slotRect (i)); }
- (NSRect) rectForKit: (int) i { return faceToView (kitRect (i)); }
- (NSRect) rectForPlay { return faceToView (kPlayRect); }
- (NSRect) rectForEditMode: (int) i { return faceToView (modeRect (i)); }
- (NSRect) readoutRect { return faceToView (kReadout); }
- (int) rowForPad: (int) pad { [self syncOrder]; return padPos (pad) + 1; }
- (NSPoint) sidePoint: (int) which
{
    if (which == 0) return sideToView (NSMakePoint (NSMidX (kBypassRect), NSMidY (kBypassRect)));
    if (which >= 1 && which <= 3) return sideToView (NSMakePoint (kSCx, bandY (which - 1)));
    if (which >= 4 && which <= 6) return sideToView (NSMakePoint (kSCx + kRingR - 5.0, bandY (which - 4)));
    return sideToView (NSMakePoint (kSCx, sFaderY (core->engine.song().fader)));
}

@end
