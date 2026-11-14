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

const CGFloat W = kViewWidth;
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
const NSRect kLengthRect = { { 560.0, 114.0 }, { 180.0, 32.0 } };
inline NSRect modeRect (int i) { return NSMakeRect (770.0 + i * 98.0, kTabY, 90.0, kTabH); }

// Every page shows the pads in the user's order: Kick, Snare, Hi-Hat, Hi Tom,
// Mid Tom, Low Tom, Crash, Ride, Clap/Tamb, Rim/Cow
const int kPadOrder[kNumPads] = { 0, 1, 7, 4, 3, 2, 8, 9, 6, 5 };
inline int padPos (int pad)
{
    for (int i = 0; i < kNumPads; ++i) if (kPadOrder[i] == pad) return i;
    return pad;
}

// Steps page
const CGFloat kRowY0 = 186.0, kRowPitch = 40.0, kCellH = 30.0;
const CGFloat kGridX0 = 356.0, kStepPitch = 24.0, kCellW = 21.0;
inline CGFloat cellX (int k) { return kGridX0 + k * kStepPitch + (k / 4) * 3.0; }
inline NSRect cellRect (int row, int k) { return NSMakeRect (cellX (k), kRowY0 + row * kRowPitch + 5.0, kCellW, kCellH); }
inline NSRect rowChoiceRect (int row) { return NSMakeRect (140.0, kRowY0 + row * kRowPitch + 8.0, 94.0, 24.0); }
inline NSRect rowLenRect (int row) { return NSMakeRect (240.0, kRowY0 + row * kRowPitch + 8.0, 58.0, 24.0); }
inline NSRect rowMuteRect (int row) { return NSMakeRect (303.0, kRowY0 + row * kRowPitch + 8.0, 22.0, 24.0); }
inline NSRect rowSoloRect (int row) { return NSMakeRect (328.0, kRowY0 + row * kRowPitch + 8.0, 22.0, 24.0); }
// rows top to bottom (the user's order): Accent, Kick, Snare, Hi-Hat, Hi Tom,
// Mid Tom, Low Tom, Crash, Ride, Clap/Tamb, Rim/Cow
inline int rowTrack (int row) { return row == 0 ? kAccentTrack : kPadOrder[row - 1]; }

// Pads page
inline NSRect padRect (int pad)
{
    const int i = padPos (pad);
    return NSMakeRect (40.0 + (i % 5) * 224.0, (i < 5 ? 194.0 : 428.0), 196.0, 146.0);
}
inline NSRect padFlamRect (int pad, int i)
{
    const NSRect p = padRect (pad);
    return NSMakeRect (p.origin.x + i * 66.0, NSMaxY (p) + 10.0, 64.0, 24.0);
}

// Mixer page
inline CGFloat mixX (int ch) { return 24.0 + padPos (ch) * 114.0; }
const CGFloat kMixTuneY = 238.0, kMixDecayY = 326.0, kMixPanY = 414.0, kMixKnobR = 20.0;
const CGFloat kFaderTop = 458.0, kFaderBot = 582.0;
inline NSRect faderRect (int ch) { return NSMakeRect (mixX (ch) + 36.0, kFaderTop - 10.0, 32.0, kFaderBot - kFaderTop + 20.0); }
inline NSRect mixMuteRect (int ch) { return NSMakeRect (mixX (ch) + 6.0, 596.0, 44.0, 24.0); }
inline NSRect mixSoloRect (int ch) { return NSMakeRect (mixX (ch) + 54.0, 596.0, 44.0, 24.0); }

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

enum { kModeStep = 0, kModeChoice, kModeFlam, kModeHits };

// Knob ids
enum { kKTempo = 0, kKSwing = 1, kKAccent = 2, kKMaster = 3, kKTune = 16, kKDecay = 32, kKPan = 48, kKLevel = 64 };

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
const Lit kGreen = { 110, 226, 60 };
const Lit kAmber = { 255, 150, 20 };
const Lit kYellow = { 255, 214, 40 };
const Lit kLime = { 178, 245, 96 };
const Lit kBlue = { 70, 160, 250 };

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
        NSGradient* g = [[[NSGradient alloc] initWithStartingColor: rgb (238, 239, 241) endingColor: rgb (168, 171, 175)] autorelease];
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

// Grey knurled knob with a red position line (the user's standard knob)
void drawKnob (NSPoint ctr, CGFloat r, CGFloat v)
{
    [NSGraphicsContext saveGraphicsState];
    NSShadow* sh = [[[NSShadow alloc] init] autorelease];
    [sh setShadowOffset: NSMakeSize (1.5, -2.5)];
    [sh setShadowBlurRadius: 4.0];
    [sh setShadowColor: [NSColor colorWithCalibratedWhite: 0.0 alpha: 0.45]];
    [sh set];
    [rgb (90, 93, 97) set];
    [[NSBezierPath bezierPathWithOvalInRect: NSMakeRect (ctr.x - r, ctr.y - r, 2 * r, 2 * r)] fill];
    [NSGraphicsContext restoreGraphicsState];

    const int ridges = 40;
    for (int k = 0; k < ridges; ++k)
    {
        const CGFloat a0 = (CGFloat) (2.0 * M_PI * k / ridges);
        const CGFloat a1 = (CGFloat) (2.0 * M_PI * (k + 0.5) / ridges);
        NSBezierPath* w = [NSBezierPath bezierPath];
        [w moveToPoint: ctr];
        [w lineToPoint: polar (ctr.x, ctr.y, r, a0)];
        [w lineToPoint: polar (ctr.x, ctr.y, r, a1)];
        [w closePath];
        const CGFloat lit = 0.5 + 0.5 * std::cos (a0 + 0.8);
        [[NSColor colorWithCalibratedWhite: 0.40 + 0.22 * lit alpha: 1.0] set];
        [w fill];
    }
    const CGFloat rc = r * 0.78;
    NSGradient* cap = [[[NSGradient alloc] initWithStartingColor: rgb (172, 175, 179) endingColor: rgb (104, 107, 111)] autorelease];
    NSBezierPath* capPath = [NSBezierPath bezierPathWithOvalInRect: NSMakeRect (ctr.x - rc, ctr.y - rc, 2 * rc, 2 * rc)];
    [cap drawInBezierPath: capPath angle: -60.0];
    [rgb (70, 72, 75) set];
    [capPath setLineWidth: 0.8];
    [capPath stroke];

    const CGFloat a = valueAngle (v);
    NSBezierPath* line = [NSBezierPath bezierPath];
    [line moveToPoint: polar (ctr.x, ctr.y, r * 0.18, a)];
    [line lineToPoint: polar (ctr.x, ctr.y, r * 0.98, a)];
    [line setLineWidth: 2.4];
    [line setLineCapStyle: NSRoundLineCapStyle];
    [rgb (200, 30, 30) set];
    [line stroke];
}

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
    NSGradient* g = [[[NSGradient alloc] initWithStartingColor: rgb (238, 239, 241) endingColor: rgb (176, 179, 183)] autorelease];
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
    if (messageUntil > 0.0 && messageUntil < [NSDate timeIntervalSinceReferenceDate]) messageUntil = 0.0;
}

//------------------------------------------------------------------------------
// Values behind the knobs and faders

- (float) knobValue: (int) k
{
    const tbdm::Song& s = core->engine.song();
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
    if (k == kKTempo) s.tempo = (float) (std::floor ((30.0f + 270.0f * v) * 10.0f + 0.5f) / 10.0f);
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
    if (k == kKTempo) std::snprintf (t, sizeof (t), "TEMPO   %.1f BPM", s.tempo);
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
            const CGFloat cx = mixX (ch) + 52.0;
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

- (NSImage*) backdropImage
{
    if (backdrop) return backdrop;
    backdrop = [[NSImage alloc] initWithSize: NSMakeSize (W, kViewHeight)];
    [backdrop lockFocusFlipped: YES];
    // silver face
    NSGradient* face = [[[NSGradient alloc] initWithStartingColor: rgb (222, 224, 227) endingColor: rgb (184, 188, 192)] autorelease];
    [face drawInRect: NSMakeRect (0, 0, W, kStripTop) angle: 90.0];
    // brushed grain
    unsigned seed = 707u;
    for (int i = 0; i < 900; ++i)
    {
        seed = seed * 1103515245u + 12345u;
        const CGFloat y = (CGFloat) ((seed >> 8) % (unsigned) kStripTop);
        seed = seed * 1103515245u + 12345u;
        const CGFloat x = (CGFloat) ((seed >> 8) % (unsigned) W);
        seed = seed * 1103515245u + 12345u;
        const CGFloat len = 40.0 + (CGFloat) ((seed >> 8) % 160u);
        [[NSColor colorWithCalibratedWhite: ((seed >> 4) & 1) ? 1.0 : 0.0 alpha: 0.035] set];
        NSRectFillUsingOperation (NSMakeRect (x, y, len, 1.0), NSCompositeSourceOver);
    }
    // top bar ledge
    [rgb (120, 123, 127) set];
    NSRectFill (NSMakeRect (0, kTopH, W, 1.0));
    [[NSColor colorWithCalibratedWhite: 1.0 alpha: 0.7] set];
    NSRectFill (NSMakeRect (0, kTopH + 1.0, W, 1.0));
    // strip
    NSGradient* strip = [[[NSGradient alloc] initWithStartingColor: rgb (198, 201, 205) endingColor: rgb (164, 168, 172)] autorelease];
    [strip drawInRect: NSMakeRect (0, kStripTop, W, kViewHeight - kStripTop) angle: 90.0];
    [rgb (60, 62, 65) set];
    NSRectFill (NSMakeRect (0, kStripTop, W, 1.5));
    // border
    [rgb (50, 52, 55) set];
    NSFrameRectWithWidth (NSMakeRect (0, 0, W, kViewHeight), 1.5);

    // the user's TB electronic logo, straight on the silver
    tblogo::drawTBLogo (kLogoBox);
    drawText ("DRUM MACHINE", boldFont (13.0), [NSColor blackColor], NSMidX (kLogoBox), 742.0);

    // captions in the top bar
    NSColor* ink = [NSColor blackColor];
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
    [backdrop unlockFocus];
    return backdrop;
}

- (void) drawLimeBox: (NSRect) box text: (const char*) t size: (CGFloat) size
{
    NSBezierPath* p = [NSBezierPath bezierPathWithRoundedRect: box xRadius: 4 yRadius: 4];
    NSGradient* glow = [[[NSGradient alloc] initWithStartingColor: rgb (206, 255, 120) endingColor: rgb (150, 232, 70)] autorelease];
    [glow drawInBezierPath: p relativeCenterPosition: NSMakePoint (0.0, 0.0)];
    [rgb (60, 62, 65) set];
    [p setLineWidth: 1.0];
    [p stroke];
    if (t && t[0]) drawText (t, boldFont (fitSize (t, size, box.size.width - 16.0)), [NSColor blackColor], NSMidX (box), NSMidY (box));
}

- (void) drawTopBar
{
    tbdm::Engine& e = core->engine;
    drawButton (kPlayRect, e.isPlaying() ? "STOP" : "PLAY", e.isPlaying(), kGreen, 15.0);
    drawButton (kRecRect, "REC", e.isRecording(), kRed, 15.0);
    for (int i = 0; i < 4; ++i) drawKnob (NSMakePoint (kTopKnobX[i], kTopKnobY), kTopKnobR, [self knobValue: i]);
    char t[32];
    if (e.externalSync())
    {
        if (e.externalTempo() > 1.0f) std::snprintf (t, sizeof (t), "%.1f", e.externalTempo());
        else std::snprintf (t, sizeof (t), "MIDI");
    }
    else std::snprintf (t, sizeof (t), "%.1f", e.song().tempo);
    [self drawLimeBox: kTempoBox text: t size: 17.0];
    drawSlide2 (kSyncRect, "INT", "MIDI", e.externalSync(), kBlue);
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
        const bool beat = (k % 4) == 0;
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
        drawText (nm, boldFont (fitSize (nm, 12.5, 116.0)), used ? ink : rgb (130, 132, 136), 20.0, y + 20.0, 0.0);
        if (tr != kAccentTrack && kd.pads[tr].numChoices == 2)
            drawSlide2 (rowChoiceRect (row), kd.pads[tr].choiceLabel[0], kd.pads[tr].choiceLabel[1], rowChoice[tr] == 1, kRed, used);
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
                NSGradient* g = [[[NSGradient alloc] initWithStartingColor: ((k / 4) & 1) ? rgb (214, 216, 219) : rgb (236, 237, 239)
                                                                endingColor: ((k / 4) & 1) ? rgb (170, 173, 177) : rgb (190, 193, 197)] autorelease];
                [g drawInBezierPath: p angle: -90.0];
            }
            else
            {
                [rgb (150, 153, 157) set];
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
        const CGFloat x = mixX (ch), cx = x + 52.0;
        const tbdm::Channel& c = e.song().channels[ch];
        // strip divider
        if (padPos (ch) > 0)
        {
            [rgb (140, 143, 147) set];
            NSRectFill (NSMakeRect (x - 6.0, 162.0, 1.0, 462.0));
            [[NSColor colorWithCalibratedWhite: 1.0 alpha: 0.6] set];
            NSRectFill (NSMakeRect (x - 5.0, 162.0, 1.0, 462.0));
        }
        const char* nm = kd.pads[ch].numChoices ? kd.pads[ch].label : "---";
        drawText (nm, boldFont (fitSize (nm, 12.0, 84.0)), ink, cx - 6.0, 172.0);
        drawLed (NSMakePoint (x + 98.0, 172.0), e.padFlash (ch), kRed);
        drawText ("TUNE", boldFont (10.0), ink, cx, kMixTuneY - 36.0);
        drawKnob (NSMakePoint (cx, kMixTuneY), kMixKnobR, [self knobValue: kKTune + ch]);
        drawEnds (NSMakePoint (cx, kMixTuneY), kMixKnobR, "-12", 0, "+12");
        drawText ("DECAY", boldFont (10.0), ink, cx, kMixDecayY - 36.0);
        drawKnob (NSMakePoint (cx, kMixDecayY), kMixKnobR, [self knobValue: kKDecay + ch]);
        drawEnds (NSMakePoint (cx, kMixDecayY), kMixKnobR, "0", 0, "10");
        drawText ("PAN", boldFont (10.0), ink, cx, kMixPanY - 36.0);
        drawKnob (NSMakePoint (cx, kMixPanY), kMixKnobR, [self knobValue: kKPan + ch]);
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
        NSGradient* cg = [[[NSGradient alloc] initWithStartingColor: rgb (120, 123, 127) endingColor: rgb (60, 62, 66)] autorelease];
        [cg drawInBezierPath: cap angle: -90.0];
        [NSGraphicsContext restoreGraphicsState];
        [rgb (200, 30, 30) set];
        NSRectFill (NSMakeRect (cx - 13.0, fy - 1.0, 26.0, 2.0));
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
                setGlow (litColor (kLime), 10.0);
                [litColor (kLime) set];
                [p fill];
                [NSGraphicsContext restoreGraphicsState];
            }
            else
            {
                NSGradient* g = [[[NSGradient alloc] initWithStartingColor: rgb (78, 80, 86) endingColor: rgb (40, 41, 45)] autorelease];
                [g drawInBezierPath: p angle: -90.0];
            }
            NSColor* tc = now ? ink : rgb (236, 238, 240);
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
            [rgb (200, 202, 206) set];
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
    drawSlide2 (kSongModeRect, "OFF", "ON", e.songMode(), kLime);
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
        NSColor* fill = lime ? litColor (kLime) : (used ? rgb (46, 47, 50) : rgb (214, 216, 219));
        if (lime)
        {
            [NSGraphicsContext saveGraphicsState];
            setGlow (litColor (kLime), 8.0);
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
        drawText (n, boldFont (12.0), lime ? [NSColor blackColor] : (used ? [NSColor whiteColor] : rgb (120, 122, 126)), NSMidX (r), NSMidY (r));
    }
    const char* labs[4] = { "NAME", "COPY", "PASTE", "CLEAR" };
    const bool armed = clearArmedUntil > [NSDate timeIntervalSinceReferenceDate];
    for (int i = 0; i < 4; ++i)
        drawButton (patBtnRect (i), (i == 3 && armed) ? "AGAIN" : labs[i], i == 3 && armed, kRed, 11.5, i != 2 || clipboardFull);

    char text[160];
    [self composeReadout: text size: sizeof (text)];
    if (! nameField) [self drawLimeBox: kReadout text: text size: 18.0];
    else [self drawLimeBox: kReadout text: 0 size: 18.0];

    drawButton (kExportWav, "EXPORT WAV", false, kRed, 14.0);
    drawButton (kExportMidi, "EXPORT MIDI", false, kRed, 14.0);
}

- (void) drawRect: (NSRect) dirty
{
    (void) dirty;
    if (! core) return;
    [[self backdropImage] drawInRect: [self bounds] fromRect: NSZeroRect operation: NSCompositeCopy fraction: 1.0 respectFlipped: YES hints: nil];
    [self drawTopBar];
    [self drawTabs];
    if (page == kPageSteps) [self drawStepsPage];
    else if (page == kPagePads) [self drawPadsPage];
    else if (page == kPageMixer) [self drawMixerPage];
    else [self drawSongPage];
    [self drawStrip];
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
    NSTextField* f = [[NSTextField alloc] initWithFrame: NSInsetRect (kReadout, 8.0, 12.0)];
    [f setBezeled: NO];
    [f setBordered: NO];
    [f setDrawsBackground: YES];
    [f setBackgroundColor: rgb (178, 245, 96)];
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

// Which range: the whole song or the current pattern (times n). Test mode skips
// the questions and the save panel.
- (BOOL) askRange: (tbdm::ExportRange&) r path: (std::string&) path type: (NSString*) ext title: (NSString*) title
{
    tbdm::Engine& e = core->engine;
    r.wholeSong = false;
    r.pattern = e.currentPattern();
    r.loops = 1;
    if (core->testMode)
    {
        r.wholeSong = e.song().numEntries > 0;
        r.loops = 2;
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
    NSPopUpButton* times = [[[NSPopUpButton alloc] initWithFrame: NSMakeRect (0, 0, 200, 26) pullsDown: NO] autorelease];
    const int counts[6] = { 1, 2, 4, 8, 16, 32 };
    for (int i = 0; i < 6; ++i) [times addItemWithTitle: [NSString stringWithFormat: @"Pattern %d time%s", counts[i], counts[i] > 1 ? "s" : ""]];
    [a setAccessoryView: times];
    const NSInteger b = [a runModal];
    const bool hasSong = e.song().numEntries > 0;
    if (hasSong && b == NSAlertFirstButtonReturn) r.wholeSong = true;
    else if ((hasSong && b == NSAlertSecondButtonReturn) || (! hasSong && b == NSAlertFirstButtonReturn))
        r.loops = counts[clampi ((int) [times indexOfSelectedItem], 0, 5)];
    else return NO;

    NSSavePanel* sp = [NSSavePanel savePanel];
    [sp setAllowedFileTypes: [NSArray arrayWithObject: ext]];
    [sp setTitle: title];
    const tbdm::Pattern& P = e.song().patterns[r.pattern];
    NSString* base = r.wholeSong ? @"TB Drum Machine Song"
                                 : (P.name[0] ? str (P.name) : [NSString stringWithFormat: @"TB Drum Machine Pattern %d", r.pattern + 1]);
    [sp setNameFieldStringValue: [base stringByAppendingPathExtension: ext]];
    if ([sp runModal] != NSFileHandlingPanelOKButton) return NO;
    path = [[[sp URL] path] UTF8String];
    return YES;
}

- (void) exportWav: (id) sender
{
    (void) sender;
    ExportRange r;
    std::string path;
    if (! [self askRange: r path: path type: @"wav" title: @"Export WAV"]) return;
    tbdm::Song copy;
    core->engine.lock();
    copy = core->engine.song();
    core->engine.unlock();
    const int rate = (int) (core->engine.sampleRate() >= 88200.0 ? core->engine.sampleRate() : (core->engine.sampleRate() >= 48000.0 ? 48000 : 44100));
    long frames = 0;
    const bool ok = exportWav (path.c_str(), copy, core->kits, r, rate, 4.0, &frames);
    char t[160];
    const char* fn = std::strrchr (path.c_str(), '/');
    if (ok) std::snprintf (t, sizeof (t), "EXPORTED %s  (%.1f s)", fn ? fn + 1 : path.c_str(), frames / (double) rate);
    else std::snprintf (t, sizeof (t), "COULDN'T WRITE %s", fn ? fn + 1 : path.c_str());
    [self showMessage: t];
}

- (void) exportMidi: (id) sender
{
    (void) sender;
    ExportRange r;
    std::string path;
    if (! [self askRange: r path: path type: @"mid" title: @"Export MIDI"]) return;
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
    const NSPoint p = [self convertPoint: [ev locationInWindow] fromView: nil];
    tbdm::Engine& e = core->engine;
    dragKind = 0;
    paintRow = -1;

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
            if (tr != kAccentTrack && inRect (p, NSMakeRect (14.0, kRowY0 + row * kRowPitch + 4.0, 122.0, 32.0)))
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
    const NSPoint p = [self convertPoint: [ev locationInWindow] fromView: nil];
    if (dragKind == 1)
    {
        const bool fine = ([ev modifierFlags] & NSShiftKeyMask) != 0;
        const CGFloat range = dragId >= kKLevel ? (kFaderBot - kFaderTop) : 200.0;
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
    const NSPoint p = [self convertPoint: [ev locationInWindow] fromView: nil];
    const int k = [self knobAt: p];
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

- (NSRect) rectForStep: (int) k row: (int) row { return cellRect (row, k); }
- (NSRect) rectForPad: (int) pad half: (int) half
{
    const NSRect r = padRect (pad);
    if (half < 0) return r;
    return NSMakeRect (r.origin.x + half * r.size.width * 0.5, r.origin.y, r.size.width * 0.5, r.size.height);
}
- (NSRect) rectForTab: (int) i { return tabRect (i); }
- (NSRect) rectForPatternSlot: (int) i { return slotRect (i); }
- (NSRect) rectForKit: (int) i { return kitRect (i); }
- (NSRect) rectForPlay { return kPlayRect; }
- (NSRect) rectForEditMode: (int) i { return modeRect (i); }
- (NSRect) readoutRect { return kReadout; }

@end
