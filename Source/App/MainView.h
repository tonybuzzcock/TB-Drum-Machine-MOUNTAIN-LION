// MainView.h: the TB Drum Machine panel (one window, drawn in code).

#import <Cocoa/Cocoa.h>

struct AppCore;

// The face, and the mahogany frame round it (the M-50 strip's look)
const CGFloat kPanelFrame = 24.0;
const CGFloat kFaceWidth = 1180.0;
const CGFloat kFaceHeight = 780.0;
const CGFloat kViewWidth = kFaceWidth + 2 * kPanelFrame;
const CGFloat kViewHeight = kFaceHeight + 2 * kPanelFrame;

enum { kPagePads = 0, kPageSteps = 1, kPageMixer = 2, kPageSong = 3 };

@interface TBDrumMachineView : NSView <NSTextFieldDelegate>
{
@public
    AppCore* core;
}
- (id) initWithFrame: (NSRect) frame core: (AppCore*) c;
- (void) shutdown;
- (void) setPage: (int) p;
- (int) page;
- (void) showMessage: (const char*) text;
- (void) togglePlay;
- (void) exportWav: (id) sender;
- (void) exportMidi: (id) sender;
- (void) startNamingPattern;
- (void) refreshAll;
// test hooks
- (NSRect) rectForStep: (int) k row: (int) row;
- (NSRect) rectForPad: (int) pad half: (int) half;
- (NSRect) rectForTab: (int) i;
- (NSRect) rectForPatternSlot: (int) i;
- (NSRect) rectForKit: (int) i;
- (NSRect) rectForPlay;
- (NSRect) rectForEditMode: (int) i;
- (NSRect) readoutRect;
- (int) rowForPad: (int) pad;
- (NSTextField*) nameField;
- (const char*) readoutText;
@end
