// main.mm
// TB Drum Machine: the stand-alone app. Window and menus, CoreAudio output,
// CoreMIDI input (clock, start/stop, notes), session autosave, and an offscreen
// self-test used by the GitHub build (--selftest <dir>).
// Mac OS X 10.8.5 and later; manual retain/release.

#import <Cocoa/Cocoa.h>
#include <AudioUnit/AudioUnit.h>
#include <AudioToolbox/AudioToolbox.h>
#include <CoreMIDI/CoreMIDI.h>
#include <mach/mach_time.h>

#include "AppCore.h"
#import "MainView.h"

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>
#if defined (__SSE__) || defined (__x86_64__)
#include <xmmintrin.h>
#endif

using namespace tbdm;

static AppCore* gCore = 0;

//==============================================================================
// Audio

static OSStatus renderCallback (void* ref, AudioUnitRenderActionFlags* flags, const AudioTimeStamp* ts,
                                UInt32 bus, UInt32 frames, AudioBufferList* io)
{
    (void) flags; (void) ts; (void) bus;
    AppCore* c = (AppCore*) ref;
#if defined (__SSE__) || defined (__x86_64__)
    const unsigned int csr = _mm_getcsr();
    _mm_setcsr (csr | 0x8040);    // flush denormals to zero
#endif
    if (io->mNumberBuffers >= 2)
        c->engine.render ((float*) io->mBuffers[0].mData, (float*) io->mBuffers[1].mData, (int) frames);
    else if (io->mNumberBuffers == 1)
    {
        static float scratch[4096];
        float* L = (float*) io->mBuffers[0].mData;
        UInt32 done = 0;
        while (done < frames)
        {
            const int n = (int) ((frames - done) > 4096 ? 4096 : (frames - done));
            c->engine.render (L + done, scratch, n);
            done += (UInt32) n;
        }
    }
#if defined (__SSE__) || defined (__x86_64__)
    _mm_setcsr (csr);
#endif
    return noErr;
}

static AudioUnit gOutput = 0;

static bool startAudio (AppCore* c)
{
    AudioComponentDescription d;
    std::memset (&d, 0, sizeof (d));
    d.componentType = kAudioUnitType_Output;
    d.componentSubType = kAudioUnitSubType_DefaultOutput;
    d.componentManufacturer = kAudioUnitManufacturer_Apple;
    AudioComponent comp = AudioComponentFindNext (0, &d);
    if (! comp) return false;
    if (AudioComponentInstanceNew (comp, &gOutput) != noErr) { gOutput = 0; return false; }

    AudioStreamBasicDescription dev;
    UInt32 size = sizeof (dev);
    double rate = 44100.0;
    if (AudioUnitGetProperty (gOutput, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &dev, &size) == noErr
        && dev.mSampleRate > 8000.0)
        rate = dev.mSampleRate;

    AudioStreamBasicDescription f;
    std::memset (&f, 0, sizeof (f));
    f.mSampleRate = rate;
    f.mFormatID = kAudioFormatLinearPCM;
    f.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved;
    f.mChannelsPerFrame = 2;
    f.mBitsPerChannel = 32;
    f.mBytesPerFrame = 4;
    f.mFramesPerPacket = 1;
    f.mBytesPerPacket = 4;
    AudioUnitSetProperty (gOutput, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &f, sizeof (f));

    AURenderCallbackStruct cb;
    cb.inputProc = renderCallback;
    cb.inputProcRefCon = c;
    AudioUnitSetProperty (gOutput, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &cb, sizeof (cb));

    c->engine.lock();
    c->engine.setSampleRate (rate);
    c->engine.unlock();
    if (AudioUnitInitialize (gOutput) != noErr || AudioOutputUnitStart (gOutput) != noErr)
    {
        AudioComponentInstanceDispose (gOutput);
        gOutput = 0;
        return false;
    }
    return true;
}

static void stopAudio()
{
    if (! gOutput) return;
    AudioOutputUnitStop (gOutput);
    AudioUnitUninitialize (gOutput);
    AudioComponentInstanceDispose (gOutput);
    gOutput = 0;
}

//==============================================================================
// MIDI in: clock, start/continue/stop, notes (any channel) play the pads

static MIDIClientRef gMidiClient = 0;
static MIDIPortRef gMidiIn = 0;
static std::vector<MIDIEndpointRef> gConnected;
static double gTicksToSec = 1e-9;
static UInt64 gLastClock = 0;

static void midiRead (const MIDIPacketList* list, void* ref, void* src)
{
    (void) src;
    AppCore* c = (AppCore*) ref;
    const MIDIPacket* pk = &list->packet[0];
    for (UInt32 i = 0; i < list->numPackets; ++i)
    {
        const UInt64 now = pk->timeStamp ? pk->timeStamp : mach_absolute_time();
        unsigned char status = 0;
        int need = 0, have = 0;
        unsigned char dat[2] = { 0, 0 };
        for (UInt16 b = 0; b < pk->length; ++b)
        {
            const unsigned char x = pk->data[b];
            if (x >= 0xF8)
            {
                c->engine.lock();
                if (x == 0xF8)
                {
                    const double dt = gLastClock ? (double) (now - gLastClock) * gTicksToSec : 0.0;
                    gLastClock = now;
                    c->engine.midiClock (dt);
                }
                else if (x == 0xFA) c->engine.midiStart();
                else if (x == 0xFB) c->engine.midiContinue();
                else if (x == 0xFC) c->engine.midiStop();
                c->engine.unlock();
                continue;
            }
            if (x & 0x80)
            {
                status = x;
                have = 0;
                const unsigned char hi = x & 0xF0;
                need = (hi == 0xC0 || hi == 0xD0) ? 1 : (x >= 0xF0 ? 0 : 2);
                if (x == 0xF0 || x == 0xF7) need = 0;
                continue;
            }
            if (need == 0) continue;
            dat[have++] = x;
            if (have < need) continue;
            have = 0;
            if ((status & 0xF0) == 0x90 && dat[1] > 0)
            {
                c->engine.lock();
                c->engine.midiNote (dat[0], dat[1]);
                c->engine.unlock();
                if (c->engine.isRecording()) c->dirty = true;
            }
        }
        pk = MIDIPacketNext (pk);
    }
}

static void connectMidiSources()
{
    if (! gMidiIn) return;
    const ItemCount n = MIDIGetNumberOfSources();
    for (ItemCount i = 0; i < n; ++i)
    {
        MIDIEndpointRef s = MIDIGetSource (i);
        bool already = false;
        for (size_t k = 0; k < gConnected.size(); ++k) already = already || gConnected[k] == s;
        if (! already && MIDIPortConnectSource (gMidiIn, s, 0) == noErr) gConnected.push_back (s);
    }
}

static void midiNotify (const MIDINotification* n, void* ref)
{
    (void) ref;
    if (n && n->messageID == kMIDIMsgSetupChanged)
        dispatch_async (dispatch_get_main_queue(), ^{ connectMidiSources(); });
}

static void startMidi (AppCore* c)
{
    mach_timebase_info_data_t tb;
    mach_timebase_info (&tb);
    gTicksToSec = (double) tb.numer / (double) tb.denom * 1e-9;
    if (MIDIClientCreate (CFSTR ("TB Drum Machine"), midiNotify, c, &gMidiClient) != noErr) return;
    if (MIDIInputPortCreate (gMidiClient, CFSTR ("TB Drum Machine In"), midiRead, c, &gMidiIn) != noErr) return;
    connectMidiSources();
}

//==============================================================================
// Kits, demo patterns, paths

static float* testTone (int frames, double freq, double fs, double decay)
{
    float* d = new float[frames];
    for (int i = 0; i < frames; ++i)
        d[i] = (float) (0.5 * std::sin (2.0 * M_PI * freq * i / fs) * std::exp (-i / (decay * fs)));
    return d;
}

static void setStep (tbdm::Pattern& P, int t, int k, int choice = 0, int flam = 0, int sub = 1)
{
    tbdm::Step& s = P.tracks[t].steps[k];
    s.on = 1;
    s.choice = (unsigned char) choice;
    s.flam = (unsigned char) flam;
    s.sub = (unsigned char) sub;
}

// First run: a groove in each kit (patterns 1-3)
static void makeDemo (tbdm::Song& s)
{
    s.setDefaults();
    const char* names[3] = { "707 GROOVE", "CR-78 GROOVE", "LM-1 GROOVE" };
    for (int k = 0; k < 3; ++k)
    {
        tbdm::Pattern& P = s.patterns[k];
        P.kit = k;
        std::strcpy (P.name, names[k]);
        setStep (P, 0, 0); setStep (P, 0, 6); setStep (P, 0, 10);
        setStep (P, 1, 4); setStep (P, 1, 12, k == 1 ? 0 : 1);
        for (int q = 0; q < 16; q += 2) setStep (P, 7, q, q == 14 ? 1 : 0);
        setStep (P, 7, 15, 0, 0, 2);
        setStep (P, kAccentTrack, 0);
        setStep (P, kAccentTrack, 12);
        if (k == 0) { setStep (P, 6, 12, 0); setStep (P, 2, 13, 0, 1); setStep (P, 3, 14); setStep (P, 4, 15); setStep (P, 8, 0); setStep (P, 5, 11, 1); }
        if (k == 1) { setStep (P, 2, 3); setStep (P, 2, 11); setStep (P, 4, 7); setStep (P, 4, 14); P.tracks[6].length = 3; setStep (P, 6, 1); }
        if (k == 2) { setStep (P, 2, 13); setStep (P, 3, 14); setStep (P, 4, 15); setStep (P, 9, 0); setStep (P, 9, 8); }
    }
    s.tempo = 112.0f;
}

static std::string supportDirectory()
{
    const char* env = std::getenv ("TBDM_SUPPORT_DIR");
    if (env && *env) return env;
    return std::string ([NSHomeDirectory() UTF8String]) + "/Library/Application Support/TB/TB Drum Machine";
}

static void makeDirs (const std::string& path)
{
    [[NSFileManager defaultManager] createDirectoryAtPath: [NSString stringWithUTF8String: path.c_str()]
                              withIntermediateDirectories: YES attributes: nil error: nil];
}

static void loadKits (AppCore* c)
{
    std::vector<std::string> places;
    const char* env = std::getenv ("TBDM_KITS_DIR");
    if (env && *env) places.push_back (env);
    places.push_back (c->supportDir + "/Kits");
    NSString* res = [[NSBundle mainBundle] resourcePath];
    if (res) places.push_back (std::string ([res UTF8String]) + "/Kits");
    NSString* beside = [[[NSBundle mainBundle] bundlePath] stringByDeletingLastPathComponent];
    if (beside) places.push_back (std::string ([beside UTF8String]) + "/Kits");

    if (gOutput) AudioOutputUnitStop (gOutput);
    c->engine.lock();
    c->samplesLoaded = 0;
    c->kitsDir = c->supportDir + "/Kits";
    for (size_t i = 0; i < places.size(); ++i)
    {
        const int n = c->kits.load (places[i].c_str());
        if (n > 0) { c->samplesLoaded = n; c->kitsDir = places[i]; break; }
    }
    c->engine.unlock();
    if (gOutput) AudioOutputUnitStart (gOutput);
}

//==============================================================================
// App delegate

@interface TBDrumMachineApp : NSObject <NSApplicationDelegate, NSWindowDelegate>
{
    NSWindow* window;
    TBDrumMachineView* view;
    NSTimer* autosave;
    std::string testDir;
    int failures;
}
- (void) setTestDir: (const char*) d;
@end

@implementation TBDrumMachineApp

- (void) setTestDir: (const char*) d { testDir = d ? d : ""; }

- (void) addItem: (NSMenu*) m title: (NSString*) t action: (SEL) a key: (NSString*) k mods: (NSUInteger) mods
{
    NSMenuItem* it = [[[NSMenuItem alloc] initWithTitle: t action: a keyEquivalent: k] autorelease];
    [it setKeyEquivalentModifierMask: mods];
    [it setTarget: (a == @selector (terminate:) || a == @selector (hide:) || a == @selector (orderFrontStandardAboutPanel:)
                    || a == @selector (performMiniaturize:)) ? nil : self];
    [m addItem: it];
}

- (void) buildMenus
{
    NSMenu* bar = [[[NSMenu alloc] init] autorelease];
    NSMenuItem* appItem = [[[NSMenuItem alloc] init] autorelease];
    NSMenu* app = [[[NSMenu alloc] initWithTitle: @"TB Drum Machine"] autorelease];
    [self addItem: app title: @"About TB Drum Machine" action: @selector (orderFrontStandardAboutPanel:) key: @"" mods: 0];
    [app addItem: [NSMenuItem separatorItem]];
    [self addItem: app title: @"Hide TB Drum Machine" action: @selector (hide:) key: @"h" mods: NSCommandKeyMask];
    [self addItem: app title: @"Quit TB Drum Machine" action: @selector (terminate:) key: @"q" mods: NSCommandKeyMask];
    [appItem setSubmenu: app];
    [bar addItem: appItem];

    NSMenuItem* fileItem = [[[NSMenuItem alloc] init] autorelease];
    NSMenu* file = [[[NSMenu alloc] initWithTitle: @"File"] autorelease];
    [self addItem: file title: @"New Session" action: @selector (newSession:) key: @"n" mods: NSCommandKeyMask];
    [self addItem: file title: @"Open Session…" action: @selector (openSession:) key: @"o" mods: NSCommandKeyMask];
    [self addItem: file title: @"Save Session As…" action: @selector (saveSessionAs:) key: @"s" mods: NSCommandKeyMask];
    [file addItem: [NSMenuItem separatorItem]];
    [self addItem: file title: @"Export WAV…" action: @selector (exportWav:) key: @"e" mods: NSCommandKeyMask];
    [self addItem: file title: @"Export MIDI…" action: @selector (exportMidi:) key: @"e" mods: NSCommandKeyMask | NSShiftKeyMask];
    [fileItem setSubmenu: file];
    [bar addItem: fileItem];

    NSMenuItem* kitItem = [[[NSMenuItem alloc] init] autorelease];
    NSMenu* kits = [[[NSMenu alloc] initWithTitle: @"Kits"] autorelease];
    [self addItem: kits title: @"Show Kits Folder" action: @selector (showKitsFolder:) key: @"" mods: 0];
    [self addItem: kits title: @"Reload Kits" action: @selector (reloadKits:) key: @"r" mods: NSCommandKeyMask | NSShiftKeyMask];
    [kitItem setSubmenu: kits];
    [bar addItem: kitItem];

    NSMenuItem* viewItem = [[[NSMenuItem alloc] init] autorelease];
    NSMenu* pages = [[[NSMenu alloc] initWithTitle: @"View"] autorelease];
    [self addItem: pages title: @"Pads" action: @selector (showPads:) key: @"1" mods: NSCommandKeyMask];
    [self addItem: pages title: @"Steps" action: @selector (showSteps:) key: @"2" mods: NSCommandKeyMask];
    [self addItem: pages title: @"Mixer" action: @selector (showMixer:) key: @"3" mods: NSCommandKeyMask];
    [self addItem: pages title: @"Song" action: @selector (showSong:) key: @"4" mods: NSCommandKeyMask];
    [viewItem setSubmenu: pages];
    [bar addItem: viewItem];

    NSMenuItem* winItem = [[[NSMenuItem alloc] init] autorelease];
    NSMenu* win = [[[NSMenu alloc] initWithTitle: @"Window"] autorelease];
    [self addItem: win title: @"Minimize" action: @selector (performMiniaturize:) key: @"m" mods: NSCommandKeyMask];
    [winItem setSubmenu: win];
    [bar addItem: winItem];
    [NSApp setMainMenu: bar];
    [NSApp setWindowsMenu: win];
}

- (void) showPads: (id) s { (void) s; [view setPage: kPagePads]; }
- (void) showSteps: (id) s { (void) s; [view setPage: kPageSteps]; }
- (void) showMixer: (id) s { (void) s; [view setPage: kPageMixer]; }
- (void) showSong: (id) s { (void) s; [view setPage: kPageSong]; }
- (void) exportWav: (id) s { [view exportWav: s]; }
- (void) exportMidi: (id) s { [view exportMidi: s]; }

- (SessionState) stateNow
{
    tbdm::SessionState st;
    st.currentPattern = gCore->engine.currentPattern();
    st.songMode = gCore->engine.songMode();
    st.externalSync = gCore->engine.externalSync();
    st.page = [view page];
    return st;
}

- (void) applyState: (const tbdm::SessionState&) st
{
    tbdm::Engine& e = gCore->engine;
    e.stop();
    e.setExternalSync (st.externalSync);
    e.setSongMode (false);
    e.selectPattern (st.currentPattern);
    e.setSongMode (st.songMode);
    if (st.songMode && e.song().numEntries == 0) e.setSongMode (false);
}

- (void) saveNow
{
    tbdm::Song copy;
    gCore->engine.lock();
    copy = gCore->engine.song();
    gCore->engine.unlock();
    makeDirs (gCore->supportDir);
    if (saveSession (gCore->sessionPath.c_str(), copy, [self stateNow])) gCore->dirty = false;
}

- (void) autosaveTick: (NSTimer*) t
{
    (void) t;
    if (gCore->dirty) [self saveNow];
}

- (void) newSession: (id) s
{
    (void) s;
    NSAlert* a = [[[NSAlert alloc] init] autorelease];
    [a setMessageText: @"Start a new session?"];
    [a setInformativeText: @"All 16 patterns, the song and the mixer go back to the start. Use Save Session As first to keep this one."];
    [a addButtonWithTitle: @"New Session"];
    [a addButtonWithTitle: @"Cancel"];
    if ([a runModal] != NSAlertFirstButtonReturn) return;
    gCore->engine.lock();
    makeDemo (gCore->engine.song());
    tbdm::SessionState st;
    [self applyState: st];
    gCore->engine.unlock();
    gCore->dirty = true;
    [view refreshAll];
    [view showMessage: "NEW SESSION"];
}

- (void) openSession: (id) s
{
    (void) s;
    NSOpenPanel* op = [NSOpenPanel openPanel];
    [op setAllowedFileTypes: [NSArray arrayWithObjects: @"tbdm", @"txt", nil]];
    if ([op runModal] != NSFileHandlingPanelOKButton) return;
    tbdm::Song song;
    tbdm::SessionState st;
    if (! loadSession ([[[op URL] path] UTF8String], song, st))
    {
        [view showMessage: "THAT ISN'T A TB DRUM MACHINE SESSION"];
        return;
    }
    gCore->engine.lock();
    gCore->engine.song() = song;
    [self applyState: st];
    gCore->engine.unlock();
    [view setPage: st.page];
    gCore->dirty = true;
    [view refreshAll];
    [view showMessage: "SESSION OPENED"];
}

- (void) saveSessionAs: (id) s
{
    (void) s;
    NSSavePanel* sp = [NSSavePanel savePanel];
    [sp setAllowedFileTypes: [NSArray arrayWithObject: @"tbdm"]];
    [sp setNameFieldStringValue: @"My Drum Session.tbdm"];
    if ([sp runModal] != NSFileHandlingPanelOKButton) return;
    tbdm::Song copy;
    gCore->engine.lock();
    copy = gCore->engine.song();
    gCore->engine.unlock();
    const bool ok = saveSession ([[[sp URL] path] UTF8String], copy, [self stateNow]);
    [view showMessage: ok ? "SESSION SAVED" : "COULDN'T SAVE THE SESSION"];
}

- (void) showKitsFolder: (id) s
{
    (void) s;
    std::string dir = gCore->samplesLoaded > 0 ? gCore->kitsDir : gCore->supportDir + "/Kits";
    makeDirs (dir);
    NSURL* u = [NSURL fileURLWithPath: [NSString stringWithUTF8String: dir.c_str()]];
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs: [NSArray arrayWithObject: u]];
    if (gCore->samplesLoaded == 0)
        [view showMessage: "PUT THE TB 707, TB CR78 AND TB LM1 FOLDERS IN KITS, THEN KITS > RELOAD KITS"];
}

- (void) reportKits
{
    char t[160];
    if (gCore->samplesLoaded == 0) std::snprintf (t, sizeof (t), "NO KITS FOUND: KITS MENU > SHOW KITS FOLDER");
    else std::snprintf (t, sizeof (t), "KITS LOADED   707 %d/%d   CR-78 %d/%d   LM-1 %d/%d",
                        gCore->kits.samplesLoaded (0), gCore->kits.samplesExpected (0),
                        gCore->kits.samplesLoaded (1), gCore->kits.samplesExpected (1),
                        gCore->kits.samplesLoaded (2), gCore->kits.samplesExpected (2));
    [view showMessage: t];
}

- (void) reloadKits: (id) s
{
    (void) s;
    loadKits (gCore);
    [view refreshAll];
    [self reportKits];
}

- (void) applicationDidFinishLaunching: (NSNotification*) n
{
    (void) n;
    failures = 0;
    gCore->supportDir = supportDirectory();
    gCore->sessionPath = gCore->supportDir + "/Session.txt";
    if (! gCore->testMode) [self buildMenus];

    // the session from last time, or the demo grooves on first run
    tbdm::Song song;
    tbdm::SessionState st;
    if (! loadSession (gCore->sessionPath.c_str(), song, st))
    {
        makeDemo (song);
        st = SessionState();
    }
    gCore->engine.song() = song;
    [self applyState: st];

    if (gCore->testMode)
    {
        for (int k = 0; k < kNumKits; ++k)
            for (int p = 0; p < kNumPads; ++p)
                for (int c = 0; c < 2; ++c)
                    for (int f = 0; f < kNumFlams; ++f)
                        if (kitDef (k).pads[p].file[c][f])
                            gCore->kits.setSample (k, p, c, f, testTone (6000, 120.0 + 40.0 * p, 44100.0, 0.04), 6000, 44100.0);
        gCore->samplesLoaded = 40;
    }
    else loadKits (gCore);

    window = [[NSWindow alloc] initWithContentRect: NSMakeRect (0, 0, kViewWidth, kViewHeight)
                                         styleMask: NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask
                                           backing: NSBackingStoreBuffered defer: NO];
    [window setTitle: @"TB Drum Machine"];
    [window setReleasedWhenClosed: NO];
    [window setDelegate: self];
    view = [[TBDrumMachineView alloc] initWithFrame: NSMakeRect (0, 0, kViewWidth, kViewHeight) core: gCore];
    [window setContentView: view];
    [view setPage: st.page];

    if (gCore->testMode)
    {
        [self runSelfTest];
        return;
    }
    [window center];
    [window setFrameAutosaveName: @"TBDrumMachineWindow"];
    [window makeKeyAndOrderFront: nil];
    [window makeFirstResponder: view];
    [NSApp activateIgnoringOtherApps: YES];

    gCore->audioRunning = startAudio (gCore);
    startMidi (gCore);
    if (! gCore->audioRunning) [view showMessage: "NO AUDIO OUTPUT FOUND"];
    else [self reportKits];

    autosave = [[NSTimer scheduledTimerWithTimeInterval: 5.0 target: self selector: @selector (autosaveTick:) userInfo: nil repeats: YES] retain];
}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication*) a { (void) a; return YES; }

- (void) applicationWillTerminate: (NSNotification*) n
{
    (void) n;
    if (gCore->testMode) return;
    if (autosave) { [autosave invalidate]; [autosave release]; autosave = nil; }
    stopAudio();
    [self saveNow];
    [view shutdown];
}

//------------------------------------------------------------------------------
// Self-test (GitHub build): drives the panel offscreen and writes screenshots

- (void) check: (bool) ok what: (const char*) what
{
    std::printf ("  %s  %s\n", ok ? "ok  " : "FAIL", what);
    if (! ok) ++failures;
}

- (void) shot: (const char*) name
{
    [view display];
    const NSRect b = [view bounds];
    NSBitmapImageRep* rep = [view bitmapImageRepForCachingDisplayInRect: b];
    [view cacheDisplayInRect: b toBitmapImageRep: rep];
    NSData* png = [rep representationUsingType: NSPNGFileType properties: [NSDictionary dictionary]];
    const std::string path = testDir + "/" + name + ".png";
    [png writeToFile: [NSString stringWithUTF8String: path.c_str()] atomically: YES];
    std::printf ("  wrote %s (%lu bytes)\n", path.c_str(), (unsigned long) [png length]);
}

- (void) click: (NSRect) r { [self clickAt: NSMakePoint (NSMidX (r), NSMidY (r)) flags: 0]; }

- (void) clickAt: (NSPoint) p flags: (NSUInteger) flags
{
    const NSPoint wp = [view convertPoint: p toView: nil];
    NSEvent* d = [NSEvent mouseEventWithType: NSLeftMouseDown location: wp modifierFlags: flags timestamp: 0
                                windowNumber: [window windowNumber] context: nil eventNumber: 0 clickCount: 1 pressure: 1.0f];
    NSEvent* u = [NSEvent mouseEventWithType: NSLeftMouseUp location: wp modifierFlags: flags timestamp: 0
                                windowNumber: [window windowNumber] context: nil eventNumber: 0 clickCount: 1 pressure: 1.0f];
    [view mouseDown: d];
    [view mouseUp: u];
}

- (void) drag: (NSPoint) from to: (NSPoint) to
{
    NSEvent* d = [NSEvent mouseEventWithType: NSLeftMouseDown location: [view convertPoint: from toView: nil] modifierFlags: 0 timestamp: 0
                                windowNumber: [window windowNumber] context: nil eventNumber: 0 clickCount: 1 pressure: 1.0f];
    [view mouseDown: d];
    for (int i = 1; i <= 8; ++i)
    {
        const NSPoint p = NSMakePoint (from.x + (to.x - from.x) * i / 8.0, from.y + (to.y - from.y) * i / 8.0);
        NSEvent* m = [NSEvent mouseEventWithType: NSLeftMouseDragged location: [view convertPoint: p toView: nil] modifierFlags: 0 timestamp: 0
                                    windowNumber: [window windowNumber] context: nil eventNumber: 0 clickCount: 1 pressure: 1.0f];
        [view mouseDragged: m];
    }
    NSEvent* u = [NSEvent mouseEventWithType: NSLeftMouseUp location: [view convertPoint: to toView: nil] modifierFlags: 0 timestamp: 0
                                windowNumber: [window windowNumber] context: nil eventNumber: 0 clickCount: 1 pressure: 1.0f];
    [view mouseUp: u];
}

- (void) pump: (double) secs
{
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: secs]];
}

- (void) renderFor: (double) secs
{
    std::vector<float> L (512), R (512);
    long n = (long) (secs * gCore->engine.sampleRate());
    while (n > 0) { gCore->engine.render (&L[0], &R[0], 512); n -= 512; }
}

- (void) runSelfTest
{
    tbdm::Engine& e = gCore->engine;
    e.setSampleRate (44100.0);
    std::printf ("Panel self-test\n");
    [view setPage: kPageSteps];
    [self shot: "steps_707"];

    // steps: kick (row 1) step 3 on, then off by painting
    [self click: [view rectForStep: 2 row: 1]];
    [self check: e.song().patterns[0].tracks[0].steps[2].on == 1 what: "click a step: on"];
    [self drag: NSMakePoint (NSMidX ([view rectForStep: 1 row: 9]), NSMidY ([view rectForStep: 1 row: 9]))
            to: NSMakePoint (NSMidX ([view rectForStep: 5 row: 9]), NSMidY ([view rectForStep: 5 row: 9]))];
    bool painted = true;
    for (int k = 1; k <= 5; ++k) painted = painted && e.song().patterns[0].tracks[8].steps[k].on;
    [self check: painted what: "drag paints steps 2-6 on the crash row"];
    [self click: [view rectForEditMode: 3]];
    [self click: [view rectForStep: 2 row: 1]];
    [self check: e.song().patterns[0].tracks[0].steps[2].sub == 2 what: "HITS mode: step split in 2"];
    [self click: [view rectForEditMode: 2]];
    [self click: [view rectForStep: 4 row: 2]];       // snare step 5 is SD A in the demo: no flams
    [self click: [view rectForStep: 12 row: 2]];      // step 13 is SD B
    [self check: e.song().patterns[0].tracks[1].steps[12].flam == 1 what: "FLAM mode: SD B step gets Flam A"];
    [self check: e.song().patterns[0].tracks[1].steps[4].flam == 0 what: "FLAM mode: SD A has no flams"];
    [self click: [view rectForEditMode: 1]];
    [self click: [view rectForStep: 0 row: 1]];
    [self check: e.song().patterns[0].tracks[0].steps[0].choice == 1 what: "A/B mode: kick step 1 becomes BD B"];
    [self click: [view rectForEditMode: 0]];
    [self shot: "steps_edited"];

    // play a little to show the playhead
    e.lock(); e.play(); e.unlock();
    [self renderFor: 0.9];
    [self shot: "steps_playing"];
    e.lock(); e.stop(); e.unlock();

    // kits
    [self click: [view rectForKit: 1]];
    [self check: e.song().patterns[0].kit == kKitCR78 what: "kit button: CR-78"];
    [self shot: "steps_cr78"];
    [self click: [view rectForPatternSlot: 2]];
    [self check: e.currentPattern() == 2 what: "pattern slot 3 selected"];
    [self shot: "steps_lm1"];
    [self click: [view rectForPatternSlot: 0]];
    [self click: [view rectForKit: 0]];

    // pads
    [self click: [view rectForTab: kPagePads]];
    [self check: [view page] == kPagePads what: "PADS tab"];
    [self shot: "pads_707"];
    Engine::HitLog lg[8];
    e.setHitLog (lg, 8);
    [self click: [view rectForPad: 0 half: 1]];
    [self check: e.hitLogCount() == 1 && lg[0].pad == 0 && lg[0].choice == 1 what: "right half of KICK plays BD B"];
    [self renderFor: 0.01];
    [self shot: "pads_hit"];
    [self click: [view rectForPad: 7 half: 0]];
    [self check: e.hitLogCount() == 2 && lg[1].pad == 7 && lg[1].choice == 0 what: "left half of HI-HAT plays closed"];
    e.setHitLog (0, 0);
    [self click: [view rectForKit: 1]];
    [self shot: "pads_cr78"];
    [self click: [view rectForKit: 0]];

    // mixer
    [self click: [view rectForTab: kPageMixer]];
    const float before = e.song().channels[0].level;
    [self drag: NSMakePoint (24.0 + 52.0, 582.0 - 124.0 * before) to: NSMakePoint (24.0 + 52.0, 582.0 - 124.0 * before + 40.0)];
    [self check: e.song().channels[0].level < before - 0.2f what: "fader drag lowers the kick level"];
    [self drag: NSMakePoint (24.0 + 114.0 * 2 + 52.0, 238.0) to: NSMakePoint (24.0 + 114.0 * 2 + 52.0, 238.0 - 50.0)];
    [self check: e.song().channels[2].tune > 2.0f what: "tune knob drag"];
    [self shot: "mixer"];

    // song
    [self click: [view rectForTab: kPageSong]];
    [self clickAt: NSMakePoint (24.0 + 56.0, 170.0 + 26.0) flags: 0];       // + ADD at slot 1
    [self click: [view rectForPatternSlot: 1]];
    [self clickAt: NSMakePoint (24.0 + 118.0 + 56.0, 170.0 + 26.0) flags: 0];
    [self clickAt: NSMakePoint (990.0 + 160.0, 444.0 + 16.0) flags: 0];       // repeats +
    [self check: e.song().numEntries == 2 && e.song().entries[1].pattern == 1 && e.song().entries[1].repeats == 2 what: "song: two steps, second plays twice"];
    [self clickAt: NSMakePoint (990.0 + 130.0, 186.0 + 15.0) flags: 0];       // song mode ON
    [self check: e.songMode() what: "song mode on"];
    e.lock(); e.play(); e.unlock();
    [self renderFor: 0.5];
    [self shot: "song"];
    e.lock(); e.stop(); e.setSongMode (false); e.unlock();
    [self click: [view rectForPatternSlot: 0]];

    // naming a pattern
    [self click: [view rectForTab: kPageSteps]];
    [view startNamingPattern];
    [self check: [view nameField] != nil what: "NAME opens a text box over the readout"];
    [self shot: "naming"];
    [[view nameField] setStringValue: @"   Friday night 707 groove\t  "];
    [[view nameField] sendAction: [[view nameField] action] to: [[view nameField] target]];
    [self pump: 0.05];
    [self check: std::strcmp (e.song().patterns[0].name, "Friday night 707 groove") == 0 what: "Return keeps the cleaned name"];
    [self check: [view nameField] == nil what: "box closed"];
    [self click: [view rectForPatternSlot: 0]];
    [self check: std::strncmp ([view readoutText], "1   Friday night 707 groove", 27) == 0 what: "readout shows 1   name"];
    [self shot: "named"];
    [self click: [view readoutRect]];
    [self check: [view nameField] != nil && [[[view nameField] stringValue] isEqualToString: @"Friday night 707 groove"] what: "clicking the readout edits the name"];
    [[view nameField] setStringValue: @"Something else"];
    [view control: [view nameField] textView: nil doCommandBySelector: @selector (cancelOperation:)];
    [self pump: 0.05];
    [self check: std::strcmp (e.song().patterns[0].name, "Friday night 707 groove") == 0 what: "Esc keeps the old name"];

    // exports
    [view exportWav: nil];
    [view exportMidi: nil];
    NSFileManager* fm = [NSFileManager defaultManager];
    NSDictionary* wa = [fm attributesOfItemAtPath: [NSString stringWithUTF8String: (testDir + "/song.wav").c_str()] error: nil];
    NSDictionary* ma = [fm attributesOfItemAtPath: [NSString stringWithUTF8String: (testDir + "/song.mid").c_str()] error: nil];
    [self check: wa && [wa fileSize] > 100000 what: "EXPORT WAV wrote the song"];
    [self check: ma && [ma fileSize] > 40 what: "EXPORT MIDI wrote the song"];
    [self shot: "exported"];

    // session save and reopen
    [self saveNow];
    tbdm::Song back;
    tbdm::SessionState st;
    [self check: loadSession (gCore->sessionPath.c_str(), back, st) && std::strcmp (back.patterns[0].name, "Friday night 707 groove") == 0
                 && back.numEntries == 2 && st.page == kPageSteps
           what: "session saved and reopened"];

    std::printf (failures ? "\n%d FAILED\n" : "\nAll panel tests passed\n", failures);
    [view shutdown];
    std::fflush (stdout);
    std::exit (failures ? 1 : 0);
}

@end

//==============================================================================

int main (int argc, char** argv)
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    AppCore* core = new AppCore();
    gCore = core;
    TBDrumMachineApp* del = [[TBDrumMachineApp alloc] init];
    for (int i = 1; i + 1 < argc; ++i)
        if (std::strcmp (argv[i], "--selftest") == 0)
        {
            core->testMode = true;
            core->testExportDir = argv[i + 1];
            [del setTestDir: argv[i + 1]];
            std::string sup = std::string (argv[i + 1]) + "/support";
            setenv ("TBDM_SUPPORT_DIR", sup.c_str(), 1);
        }
    NSApplication* app = [NSApplication sharedApplication];
    [app setActivationPolicy: core->testMode ? NSApplicationActivationPolicyAccessory : NSApplicationActivationPolicyRegular];
    [app setDelegate: del];
    [app run];
    [pool release];
    return 0;
}
