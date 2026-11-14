// AppCore.h: what the app window and the audio/MIDI side share.

#ifndef TBDM_APPCORE_H
#define TBDM_APPCORE_H

#include "../Engine/Engine.h"
#include "../Engine/Export.h"

#include <string>

struct AppCore
{
    tbdm::KitBank kits;
    tbdm::Engine engine;
    std::string supportDir;       // ~/Library/Application Support/TB/TB Drum Machine
    std::string kitsDir;          // where the kits were found (or where they belong)
    std::string sessionPath;      // Session.txt, saved on quit and every few seconds
    int samplesLoaded;
    bool dirty;                   // something changed since the last autosave
    bool testMode;                // offscreen self-test: no dialogs, no audio
    std::string testExportDir;    // test mode: exports go here without a save panel
    bool audioRunning;

    AppCore() : engine (&kits), samplesLoaded (0), dirty (false), testMode (false), audioRunning (false) {}
};

#endif
