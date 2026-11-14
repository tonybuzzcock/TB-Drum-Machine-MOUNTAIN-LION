// MainView.h: the TB Drum Machine panel (one window, drawn in code).

#import <Cocoa/Cocoa.h>

struct AppCore;

const CGFloat kViewWidth = 1180.0;
const CGFloat kViewHeight = 780.0;

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
- (NSTextField*) nameField;
- (const char*) readoutText;
@end
