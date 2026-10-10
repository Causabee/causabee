# Runtime checks — 2026-10-09

Done with builds already on disk, both a little older than commit `9b672d4`:
the Mac demo build `.build-app/shots/…/Release/Causabee.app` (21:20, `de.chille.causabee.demo`)
and the simulator build `.build-app/uitests/…/Debug-iphonesimulator/Causabee.app` (21:24).
Each was started with `--demo` on a throwaway store; the owner's store was not opened.

## Mac — menu bar as built (read through System Events)

    Causabee   About Causabee · — · Set Up Causabee … · Try the Demo · Settings… ⌘, · — · Services · — ·
               Hide Causabee ⌘H · Hide Others ⌥⌘H · Show All · — · Quit Causabee ⌘Q
    File       New Matter … ⌘N · — · Close ⌘W · Close All ⌥⌘W
    Edit       Undo ⌘Z · Redo ⇧⌘Z · — · Cut · Copy · Paste · Delete · Select All · — ·
               Writing Tools · AutoFill · Start Dictation · Emoji & Symbols
    Matter     New Task … ⇧⌘T · Add Note … · Add File … · Add Contact … · Add Detail … · Add Link …
    View       Enter Full Screen
    Window     Minimize · Zoom · Fill · Center · Move & Resize · Full Screen Tile · Bring All to Front ·
               Arrange in Front · Remove Window from Set · Show Previous Tab · Show Next Tab ·
               Move Tab to New Window · Merge All Windows
    Help       Introduction to Causabee

- Order is Causabee, File, Edit, **Matter, View**, Window, Help (M14).
- View holds one item; there is no sidebar, assistant, reading or text-size command (M3, M4).
- Edit has no Find submenu (M4, M6).
- The two custom items stand **above** Settings… in the app menu (M25), although the code asks
  for `after: .appSettings`.
- View has no Show Tab Bar, so a second window by way of tabs is not offered. The first version of
  the report raised that as a possibility; it is withdrawn.

## Mac — closing the only window (M1)

| Step | Windows |
|---|---|
| Launch | 1 |
| File ▸ Close | 0 |
| File ▸ New Matter … | 0 — nothing happens |
| Help ▸ Introduction to Causabee | 0 — nothing happens |

After Close the Window menu lists no window to bring back. Whether a Dock click reopens it was not
settled: the owner's own demo instance ran under the same identifier at the time and took the
reopen event. Full screen (M11) was not tested for the same reason.

## iPad — windowed mode (P2)

iPad Pro 13-inch (M5) simulator, iOS 27.0, app window dragged smaller by its corner handle.
The system's window controls are drawn at the top-leading corner, directly on the sidebar button of
Causabee's own capsule; the button is covered. See `fixes/ipad-0-before-window-controls-cover-button.png`.

The iPad's menu bar shows Causabee, File, Edit, View, Window, Help — no menu of the app's own (P1).

## iPad — several windows (P8)

The built Info.plist carries `UIApplicationSupportsMultipleScenes = true`.
