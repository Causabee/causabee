# Causabee — HIG review

Date: 2026-10-09 · Commit: `9b672d4` · Review only, no source changed.
Method: code reading checked against Apple's HIG pages, then a second pass that resolved every cited
line, read twelve more HIG pages and ran existing builds of the Mac and iPad apps for the open
questions (`raw/runtime-checks.md`). The HIG Doctor baseline was run last, after the review, as a cross-check — see section 7.

Targets: `CausabeeApp` (macOS 15.0+, `Sources/Causabee`), `CausabeePhone` (iPhone + iPad,
iOS/iPadOS 26.0+, `Sources/CausabeePhone`, plus ten shared files from `Sources/Causabee`),
`CausabeeShare` (share extension). HIG links below are relative to
`https://developer.apple.com/design/human-interface-guidelines/`.

## 1. Executive summary

| Platform | Rating | Why |
|---|---|---|
| macOS | 3 / 5 | Real Settings scene, context menus and drag-in are right; but the window chrome, sidebar and split are hand-built, the menu bar covers a fraction of the app, and there is no undo. |
| iPadOS | 2 / 5 | Adapts by size class, but is a mouse-and-keyboard blank: no menu bar commands, no shortcuts, no hover, no drag and drop, a hand-built sidebar, and in a window the system's controls cover the sidebar button. |
| iPhone | 4 / 5 | System navigation, back-swipe, sheets, Dynamic Type and contextual permissions are right; the gaps are small targets, untitled bars and unguarded sheets. |

Top 5 issues: **M1** closing the Mac's only window leaves an app whose menus do nothing
(confirmed running) · **P2** in an iPad window the system's window controls cover the sidebar button
(confirmed running) · **M2** the Mac sidebar cannot be operated from the keyboard · **P1** the iPad
has no menu bar commands or shortcuts at all · **M4/M5** most Mac actions are missing from the menu
bar. Next after these: **M8/B14**, no undo on any platform.

Top 3 strengths: every row's ⋯ menu is mirrored as a context menu from one builder, on all three
platforms · destructive actions carry the destructive role and a confirmation that says what goes
with them · layout follows the size class, not the device, so an iPad window turns into the iPhone
layout cleanly.

## 2. What's done well

**macOS**
- A real `Settings` scene on ⌘, with a grouped form — `Sources/Causabee/CausabeeApp.swift:146`, `Sources/Causabee/ModelChoice.swift:46`.
- Matter menu items disable when no matter is open, through a focused scene value — `CausabeeApp.swift:933`, `:946`; `Sources/Causabee/MatterStatusView.swift:207`.
- Each row's ⋯ menu and right-click menu come from one builder — `MatterStatusView.swift:1594`/`:1603`, `:1988`/`:1998`, `:2443`/`:2458`; sidebar `CausabeeApp.swift:574`.
- Drag in: files and URLs onto the window, a matter and the assistant; a person onto a person to merge; ⌘V of an image — `CausabeeApp.swift:660`, `MatterStatusView.swift:165`, `:1240`, `Sources/Causabee/AssistantView.swift:256`, `:261`.
- Liquid Glass behind an availability check with a material fallback, so macOS 15 still works — `Sources/Causabee/Theme.swift:219`; scroll-edge effect on 26 only — `Sources/Causabee/Components.swift:56`.
- Colours are dynamic light/dark providers, and the sidebar ground is a real `NSVisualEffectView(.sidebar)` — `Theme.swift:81`, `Components.swift:191`.
- `.navigationTitle` keeps the hidden window title meaningful for the Window menu and Mission Control — `MatterStatusView.swift:208`.
- Finder-like inline rename; Esc cancels rename and find; ⌘. stops an answer — `MatterStatusView.swift:909`, `Sources/Causabee/PageFind.swift:122`, `Sources/Causabee/Conversation.swift:485`.

**iPhone and iPad**
- Size class, not idiom, switches the layout; no `UIScreen` or idiom checks anywhere — `Sources/CausabeePhone/OverviewScreen.swift:44`.
- System bar and `NavigationStack(path:)` kept deliberately so the back-swipe survives — `OverviewScreen.swift:81`, `:231`.
- Every editor uses the standard Cancel / Save placements — e.g. `Sources/CausabeePhone/MatterScreen.swift:1258`, `Sources/CausabeePhone/PeopleAndLinks.swift:195`.
- Deletes use `confirmationDialog` with a destructive role and Cancel — `MatterScreen.swift:1098`, `:1404`; `Sources/CausabeePhone/MailFiles.swift:111`.
- Permissions are asked in context, never at launch: calendar on tap, microphone on first mic tap, camera on scan — `Sources/Causabee/CalendarChip.swift:132`, `Sources/MatterCore/Voice/Voice.swift:184`.
- Glass on controls only, and `safeAreaBar` for the sidebar's top — `Sources/CausabeePhone/Parts.swift:101`, `Sources/CausabeePhone/Pad.swift:85`.
- Text is almost entirely text styles; the serif scales with `relativeTo:` — `Parts.swift:9`.
- Haptics are tied to outcomes, not taps — `Sources/CausabeePhone/Haptics.swift`.

## 3. Findings

"Judgment" in the last column means it is my reading rather than a clear guideline; "deliberate"
means a code comment documents the choice. "Verify" means it depends on runtime behaviour that was
not observed; "confirmed running" means it was seen in a running build. Paths are under `Sources/` — `Causabee/` is the Mac app, `CausabeePhone/` the
iPhone/iPad app.

### macOS

| ID | Area | Sev. | File:line | What's wrong | HIG reference | Suggested fix | Basis |
|---|---|---|---|---|---|---|---|
| M1 | Windows | High | `Causabee/CausabeeApp.swift:108`, `:125`, `:767` | The one window is a `WindowGroup`, and New Matter, Set Up and Help ▸ Introduction are notifications only `RootView` hears. After ⌘W the app runs with no window, those commands do nothing, and nothing in the Window menu brings the window back. Confirmed running: after Close, New Matter … and Introduction leave the app with no window. | [Windows](https://developer.apple.com/design/human-interface-guidelines/windows), [The menu bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar) | `Window("Causabee", id: "main")` and `openWindow(id:)` from the commands, or quit when the last window closes. | Clear; confirmed running |
| M2 | Sidebar, keyboard | High | `Causabee/Components.swift:26`, `Causabee/CausabeeApp.swift:590` | Sidebar rows are `onTapGesture` on a `List` without `selection:`. ↑/↓ do not move between matters, there is no type-select, the sidebar cannot take focus, and the hand-drawn selection ignores active/inactive window state. | [Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars), [Keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards) | `List(selection: $navigation.place)` with `.tag`; keep the grey with `listRowBackground`. | Clear for keyboard; the grey look is deliberate (`:589`) |
| M3 | Sidebar, split view | Medium | `Causabee/CausabeeApp.swift:626`, `:616`, `:651` | The split is an `HStack`: neither the 270 pt sidebar nor the 38.2 % assistant column can be dragged wider or narrower, and there is no View ▸ Show/Hide Sidebar (⌃⌘S). On macOS 26 the sidebar is a flat slab with a `Divider`, not the floating glass sidebar. | [Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars), [Split views](https://developer.apple.com/design/human-interface-guidelines/split-views) | Short term: draggable dividers and a View menu item. Long term: see section 5. | Resizing and menu item clear; system containers judgment, deliberate (`:624`) |
| M4 | Menu bar | Medium | `Causabee/CausabeeApp.swift:679`, `Causabee/PageFind.swift:146`, `Causabee/AssistantView.swift:473` | ⌘K and ⌘F hang on hidden buttons, not menu items. Sidebar toggle, Reading mode, Auto and "Get new mail" have neither menu item nor shortcut. Edit has no Find submenu, and View holds only Enter Full Screen (confirmed running). | [The menu bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar) ("Put custom commands in the menu bar, even if they're available elsewhere"), [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars) (every toolbar item also a menu command) | A View group (Show/Hide Sidebar, Show/Hide Assistant ⌘K, Reading Mode), Edit ▸ Find ▸ Find… ⌘F, Matter ▸ Get New Mail. | Clear |
| M5 | Menu bar | Medium | `Causabee/CausabeeApp.swift:936` vs `Causabee/MatterStatusView.swift:944`–`:960` | The Matter menu holds only the six add-actions. Pin, Rename, Merge, Export as RTF, Close and Open Again exist only in the ⋯ menu; the sidebar context menu (`CausabeeApp.swift:574`) lacks Export and Close. | [The menu bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar), [Context menus](https://developer.apple.com/design/human-interface-guidelines/context-menus) | Build the menu bar, ⋯ and sidebar lists from one source. | Clear |
| M6 | Find | Medium | `Causabee/PageFind.swift:118`, `:126` | Next and previous are ↩ / ⇧↩ only: no ⌘G / ⇧⌘G, no Edit ▸ Find Next / Previous. | [Keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards) (standard shortcuts), [Searching](https://developer.apple.com/design/human-interface-guidelines/searching) | Add the two commands, bound to `find.next()` / `find.previous()`. | Clear for the shortcuts |
| M7 | Dialog buttons | Medium | `Causabee/MatterStatusView.swift:873`, `:2056`, `:2173`, `:2504`, `:2610`; `Causabee/CausabeeApp.swift:730` | A global `QuietButtonStyle` makes the default button look like Cancel in five popovers (the task and contact editors fill theirs), Cancel has no `.cancelAction` there, and the style draws `role: .destructive` (`:2169`) like any grey button. | [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons), [Popovers](https://developer.apple.com/design/human-interface-guidelines/popovers) | `.inkButton()` on every default button, `.keyboardShortcut(.cancelAction)` on every Cancel, a destructive variant of the style. | Clear |
| M8 | Undo | Medium | `Causabee/MatterStatusView.swift:1619`, `:2559`; `Causabee/PageFind.swift:250`, `:565` | No undo manager anywhere, so Edit ▸ Undo is dead outside text fields. Notes, details and links delete at once with neither confirmation nor undo, while tasks and dates ask. | [Undo and redo](https://developer.apple.com/design/human-interface-guidelines/undo-and-redo), [Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts) (no alert for common, undoable actions) | Enable undo on the model container; confirmations can then shrink to the truly irreversible (merge). | Clear |
| M9 | Sheets | Medium | `Causabee/IntroView.swift:70`, `Causabee/SetupAssistant.swift:193`, `:200` | Esc does nothing in the Introduction or Setup sheets: Skip, Later and Close have no cancel action. | [Keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards) (Esc cancels the current action) | `.keyboardShortcut(.cancelAction)` on the three buttons. | Clear |
| M10 | Keyboard | Medium | `Causabee/Theme.swift:541`–`:550` | ⌥Space is swallowed app-wide for dictation, including inside text fields, where it is the non-breaking space. It appears in no menu. | [Keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards) | Capture it only when no text field is being edited, or pick a free combination; add a menu item. | Clear; deliberate (`:529`) |
| M11 | Toolbar, full screen | Medium | `Causabee/Components.swift:174`, `:157`; `Causabee/CausabeeApp.swift:712` | The toolbar is an empty spacer; the real controls are overlays at a fixed x = 87 beside the traffic lights. No customisation, no overflow, and in full screen the traffic lights go while the gap stays (verify). | [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars), [Going full screen](https://developer.apple.com/design/human-interface-guidelines/going-full-screen) | Test full screen now; long term a real `.toolbar` (section 5). | Judgment, deliberate (`CausabeeApp.swift:119`) |
| M12 | Typography, density | Medium | `Causabee/TextSize.swift:10`, `:20`–`:31`; `Causabee/CausabeeApp.swift:727` | Every text style is shadowed at 1.2× (body 16 pt against the Mac's 13) with large controls; footnote, caption and caption 2 collapse to one size. The scale is only reachable through a launch argument. The Settings window does not get the scale, so the two windows disagree. | [Typography](https://developer.apple.com/design/human-interface-guidelines/typography) (macOS body 13 pt) | Offer View ▸ Make Text Bigger / Smaller (⌘+ / ⌘−) as Mail does, and apply the scale in Settings too. | Judgment, deliberate (`TextSize.swift:4`) |
| M13 | iOS idioms | Medium | `Causabee/CausabeeApp.swift:683`–`:691`; `Causabee/AssistantView.swift:113`, `:492`; `Causabee/MatterStatusView.swift:1776`, `:1517` | A 48 pt floating action button in the window corner, a round × to close the assistant pane, a yellow "Ask Causabee" pill, capsule "Whose" pills where a segmented control belongs, SF Symbols drawn as checkboxes. | [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons), [Toggles](https://developer.apple.com/design/human-interface-guidelines/toggles) | Assistant toggle as a toolbar button plus menu item; segmented `Picker` for Whose. | Judgment; brand-driven, partly deliberate (`CausabeeApp.swift:670`) |
| M14 | Menu bar | Low | `Causabee/CausabeeApp.swift:981`–`:1004` | An `NSMenu` hack moves Matter to directly after Edit. HIG order is … Edit, View, app menus, Window. It finds Edit by title, which breaks when localised. | [The menu bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar) | Delete `MenuOrder`. | Clear; deliberate (`:981`); order confirmed running |
| M15 | Menu labels | Low | `Causabee/CausabeeApp.swift:125`, `:576`; `Causabee/MatterStatusView.swift:959`, `:1645`, `:2155` | "Rename …" beside "Close Matter…", and sentence case ("Remove from this matter") beside title case. | [Menus](https://developer.apple.com/design/human-interface-guidelines/menus) | One pass: title-style capitals, ellipsis directly after the word. | Clear |
| M16 | Menus | Low | `Causabee/Theme.swift:316`, `Causabee/MatterStatusView.swift:2690` | Checkmarks are faked with "  ✓" in the label or a checkmark icon instead of the menu's state column. | [Menus](https://developer.apple.com/design/human-interface-guidelines/menus) | `Picker(.inline)` or `Toggle` in the menu, as `MatterStatusView.swift:1309` already does. | Clear |
| M17 | Tooltips | Low | `Causabee/Components.swift:67`–`:98`, `:120` | A custom dark tooltip replaces the system's on the window controls; the Auto button carries both, with different texts. | [Offering help](https://developer.apple.com/design/human-interface-guidelines/offering-help) | `.help` only. | Clear; deliberate (`:62`) |
| M18 | Drag and drop | Low | `Causabee/CausabeeApp.swift:660`, `Causabee/MatterStatusView.swift:165`, `:1240` | No drop target highlights while dragged over (notably person-onto-person), and files cannot be dragged out. | [Drag and drop](https://developer.apple.com/design/human-interface-guidelines/drag-and-drop) | `isTargeted` highlight; `.draggable(fileURL)` on file rows. | Clear (highlight a destination only while content is over it) |
| M19 | Restoration | Low | `Causabee/CausabeeApp.swift:208`, `:111` | The open matter and page part are not restored on relaunch, and with no `.defaultSize` the first launch opens at the minimum 960 × 640. | [Launching](https://developer.apple.com/design/human-interface-guidelines/launching) | `@SceneStorage` with the matter's key; `.defaultSize(width: 1280, height: 800)`. | Clear |
| M20 | Colour | Low | `Causabee/CausabeeApp.swift:733`, `Causabee/PageFind.swift:142`, `Causabee/MatterStatusView.swift:1773` | `.tint(.primary)` overrides the user's accent colour; focus rings are hand-drawn in two colours and absent on plain fields. | [Color](https://developer.apple.com/design/human-interface-guidelines/color) | One focus treatment; a gold accent asset would apply while the user's setting is Multicolor and give way to a colour they chose. | Judgment, deliberate (`CausabeeApp.swift:732`) |
| M21 | Liquid Glass | Low | `Causabee/MatterStatusView.swift:1003` | On 26 the matter's title bar turns into a material slab with a divider under glass controls, while the assistant column already uses the scroll-edge effect. | [Layout](https://developer.apple.com/design/human-interface-guidelines/layout) ("Don't place solid or semi-opaque backgrounds behind controls"; use a scroll edge effect) | On 26 use the existing `softTopEdge()` here too. | Clear |
| M22 | Panels | Low | `Causabee/AssistantView.swift:282`, `Causabee/FolderSaver.swift:48` | App-modal `runModal()` open panels rather than a sheet on the window. | [File management](https://developer.apple.com/design/human-interface-guidelines/file-management) | `.fileImporter`, already used at `MatterStatusView.swift:485`. | Clear, minor |
| M23 | Copy | Low | `Causabee/CausabeeApp.swift:822`; `Causabee/MatterStatusView.swift:628`, `:752` | Command-line instructions in user-facing text ("First: matter-spike login"). | [Writing](https://developer.apple.com/design/human-interface-guidelines/writing) | Point to "Set Up Causabee…" with a button. | Clear |
| M24 | Locale | Low | `Causabee/Theme.swift:115`; `Causabee/MatterStatusView.swift:1761`, `:2063` | Dates and date pickers are forced to `en_US`, ignoring the user's 24-hour and first-weekday settings. | [Pickers](https://developer.apple.com/design/human-interface-guidelines/pickers), [Entering data](https://developer.apple.com/design/human-interface-guidelines/entering-data) | Keep English words if wanted, but drop the override on pickers. | Judgment |
| M25 | Menu bar | Low | `Causabee/CausabeeApp.swift:137` | In the running build "Set Up Causabee …" and "Try the Demo" stand above Settings… in the app menu, although the code asks for `after: .appSettings`. | [The menu bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar) (custom items after Settings, in the same group) | Move the two into their own `CommandGroup` placed after Settings and check the built menu. | Clear; confirmed running in the 21:20 build |

### iPadOS

| ID | Area | Sev. | File:line | What's wrong | HIG reference | Suggested fix | Basis |
|---|---|---|---|---|---|---|---|
| P1 | Menu bar, keyboard | High | `CausabeePhone/PhoneApp.swift:22` | The `WindowGroup` has no `.commands`, and no app shortcut exists in the iOS target. The iPadOS 26 menu bar shows only system items: no ⌘N, ⌘F, ⌘, or sidebar/assistant toggle. The Mac app already defines them. Confirmed running: the menu bar is Causabee, File, Edit, View, Window, Help. | [The menu bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar), [Keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards) | Add `.commands`: New Matter ⌘N, Find ⌘F, Settings ⌘, , Get New Mail, Show/Hide Sidebar, Ask Causabee, a Matter menu. | Clear |
| P2 | Windows | High | `CausabeePhone/Pad.swift:85`, `CausabeePhone/OverviewScreen.swift:28`–`:32` | A hand-placed capsule sits 16 pt from the top-leading corner, where iPadOS 26 draws the window controls in windowed mode. System toolbars move aside; this does not. Confirmed running: the controls cover the capsule's sidebar button (`raw/fixes/ipad-0-before-window-controls-cover-button.png`). | [Windows](https://developer.apple.com/design/human-interface-guidelines/windows) ("don't place toolbar buttons at the leading edge") | Move the three into real toolbar items, or inset the capsule by the window-control margin when the scene is windowed. | Clear; confirmed running |
| P3 | Navigation | Medium | `CausabeePhone/OverviewScreen.swift:54`–`:57`, `:42`; `CausabeePhone/Pad.swift:90` | The sidebar and assistant are an `HStack`: fixed 300 pt, opaque with a divider, no edge-swipe, no system toggle. Crossing 1000 pt resets `showsSidebar`, so a window resize overrides the user's choice. | [Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars) ("people expect the built-in edge-swipe gesture"), [Split views](https://developer.apple.com/design/human-interface-guidelines/split-views) | Keep the user's choice across resizes; add edge-swipe and shortcut. Long term: section 5. | Judgment, deliberate (`OverviewScreen.swift:25`) |
| P4 | Pointer | Medium | `CausabeePhone/AllMatters.swift:86`, `CausabeePhone/Pad.swift:131` | No `hoverEffect` or `onHover` in any iOS-compiled file; nearly every tappable is a plain-style custom row, so nothing responds under the pointer. | [Pointing devices](https://developer.apple.com/design/human-interface-guidelines/pointing-devices) | `.hoverEffect(.highlight)` with a matching `contentShape` on rows, cards, ⋯ buttons and the capsule's rounds. | Clear |
| P5 | Drag and drop | Medium | `CausabeePhone/PhoneShots.swift:421`, `:436` | No drop or drag anywhere; files come in only through pickers and the share extension, although the Mac accepts drops in the same places. | [Drag and drop](https://developer.apple.com/design/human-interface-guidelines/drag-and-drop) | `.dropDestination` on the matter, the assistant and sidebar rows, feeding `PhoneShots.shared.bring`. | Clear in spirit ("as much as possible"); how far is judgment |
| P6 | Copy | Medium | `CausabeePhone/Welcome.swift:80`, `CausabeePhone/SettingsSheet.swift:89`, `CausabeePhone/OverviewScreen.swift:344`, `CausabeePhone/PhoneApp.swift:138`–`:144`, `CausabeePhone/PhoneShots.swift:60`, `CausabeeShare/ShareViewController.swift:193` (some 20 strings) | The interface says "this iPhone" and "On My iPhone" on an iPad. | [Writing](https://developer.apple.com/design/human-interface-guidelines/writing) | One device-name helper used in all of them. | Clear |
| P7 | Popovers | Low | `CausabeePhone/MatterScreen.swift:363` | The icon picker is a fixed 470 pt sheet launched from a small bar tile; the Mac uses a popover. With no scroll view the fixed height can clip at large text sizes. | [Popovers](https://developer.apple.com/design/human-interface-guidelines/popovers) | `.popover` in regular width; wrap the grid in a `ScrollView`. | Judgment |
| P8 | Multiple windows | Low | `App/Causabee.xcodeproj/project.pbxproj:569` | The built app declares `UIApplicationSupportsMultipleScenes = true`, so several windows can be opened, but there is no "Open in New Window" and no scene storage for the open matter. | [Multitasking](https://developer.apple.com/design/human-interface-guidelines/multitasking), [Windows](https://developer.apple.com/design/human-interface-guidelines/windows) | Decide: support it properly or declare a single window. | Judgment |

### iPhone

| ID | Area | Sev. | File:line | What's wrong | HIG reference | Suggested fix | Basis |
|---|---|---|---|---|---|---|---|
| I1 | Navigation bar | Medium | `CausabeePhone/MatterScreen.swift:203`, `CausabeePhone/OverviewScreen.swift:233` | Inline bar with no `.navigationTitle`: once scrolled, nothing says which matter is open, and the back button's history menu has no names. | [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars) ("give each window a useful title") | Set `.navigationTitle(matter.name)` and show it once the header has scrolled under. | Clear; the in-content large name is deliberate |
| I2 | Pull to refresh | Medium | `CausabeePhone/OverviewScreen.swift:224`, `CausabeePhone/PhoneMailCheck.swift:227` | `refreshable` calls a synchronous `look` that starts its own task, so the system spinner snaps back while the fetch is still running. | [Loading](https://developer.apple.com/design/human-interface-guidelines/loading) | Await the running task inside `refreshable`. | Clear |
| I3 | Swipe actions | Medium | `CausabeePhone/MatterScreen.swift:746` | Task, date, file and link rows sit in a hand-built stack, so there are no swipe actions; Done, Edit and Delete are checkbox, ⋯ and long-press only. | [Lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables) | Move the To-do section to a `List` with `.swipeActions`, or accept the card look. | Judgment |

### iPhone and iPad

| ID | Area | Sev. | File:line | What's wrong | HIG reference | Suggested fix | Basis |
|---|---|---|---|---|---|---|---|
| B1 | Touch targets | Medium | `CausabeePhone/MatterScreen.swift:1087`, `:1042`; `CausabeePhone/AssistantSheet.swift:590`; `Causabee/Theme.swift:284`, `:607` | ⋯ menus are 30 × 26, task checkboxes 26 × 26, copy/note 32 × 32, composer buttons 34 × 34 — below 44 × 44. | [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons) ("a hit region of at least 44x44 pt") | Keep the glyph, widen the `contentShape` to 44 × 44, as `CausabeePhone/Parts.swift:141` already does. | Clear |
| B2 | Sheets | Medium | `CausabeePhone/MatterScreen.swift:281` | No `interactiveDismissDisabled` anywhere: an editor with typed text can be swiped away, and the new task is then deleted. | [Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets) (unsaved changes on swipe: "use an action sheet to let them confirm") | `.interactiveDismissDisabled(isDirty)` and a discard confirmation. | Clear |
| B3 | Destructive actions | Medium | `CausabeePhone/MailFiles.swift:315`; `CausabeePhone/PeopleAndLinks.swift:156`, `:421`; `CausabeePhone/AllMatters.swift:190` | "Remove from all devices" deletes the synced password at once; person and link removal do not confirm though tasks do. | [Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts) (confirm uncommon destructive actions that can't be undone) | Confirm the password removal; give the other two undo (B14) rather than more dialogs. | Clear |
| B4 | Bars, Liquid Glass | Medium | `CausabeePhone/MatterScreen.swift:144`–`:145`, `:394`; `CausabeePhone/Welcome.swift:125` | Opaque or material slabs with a hairline under the system's floating glass bar items, and behind the find bar and the Welcome buttons. | [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars) ("reduce custom toolbar backgrounds"), [Layout](https://developer.apple.com/design/human-interface-guidelines/layout) (no solid backgrounds behind controls) | `.safeAreaBar(edge:)` as in `Pad.swift:85`, without background and divider. | Clear |
| B5 | Settings form | Medium (verify) | `Causabee/ModelChoice.swift:117`–`:122` | Save and Remove share one form row with the default button style; in a form a row tap can fire every button in it. `MailFiles.swift:319` already guards against this. | [Lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables) | `.buttonStyle(.borderless)` on both; test on a device. | SwiftUI behaviour rather than a guideline |
| B6 | Assistant sheet | Low | `CausabeePhone/AssistantSheet.swift:222`, `:96` | A hand-built header with its own ×, title and divider instead of the sheet's navigation bar. | [Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets) | On iPhone, a `NavigationStack` with a `.cancellationAction` close button. | Judgment; the iPad alignment is deliberate (`:232`) |
| B7 | Liquid Glass | Low | `CausabeePhone/Parts.swift:77`, `CausabeePhone/AssistantSheet.swift:162` | Two glass shapes 10 pt apart without a `GlassEffectContainer`; the "New answer" pill is a material capsule beside glass siblings. | [Materials](https://developer.apple.com/design/human-interface-guidelines/materials) (the page does not cover grouping; this follows Apple's "Applying Liquid Glass to custom views") | Wrap the pair in a container; `.onGlass(Capsule())` for the pill. | Judgment; API guidance rather than HIG |
| B8 | Toggles | Low | `CausabeePhone/MatterScreen.swift:252`, `CausabeePhone/Pad.swift:125` | The "on" state of Reading and Auto is a hand-drawn yellow disc inside the system's glass group. | [Toggles](https://developer.apple.com/design/human-interface-guidelines/toggles) | `Toggle` with `.toggleStyle(.button)` and `.tint(Theme.bee)`. | Judgment, deliberate (`MatterScreen.swift:248`) |
| B9 | Search | Low | `CausabeePhone/OverviewScreen.swift:258` | The overview's search is a custom capsule field that scrolls with the content: no system placement, no Cancel, no ⌘F. It doubles as "start a matter", which looks intended. | [Search fields](https://developer.apple.com/design/human-interface-guidelines/search-fields) | `.searchable` with suggestions, or keep it and add the shortcut (P1). | Judgment |
| B10 | Dynamic Type | Low | `CausabeePhone/Pad.swift:125`, `CausabeePhone/Parts.swift:135`, `Causabee/Theme.swift:281`, `CausabeePhone/MatterScreen.swift:1376` | A handful of fixed-size glyphs and a fixed 64 pt date column do not scale with the text. | [Typography](https://developer.apple.com/design/human-interface-guidelines/typography), [SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols) | Text-style fonts or `@ScaledMetric`. | Clear, small impact |
| B11 | Buttons | Low | `CausabeePhone/Parts.swift:217`, `CausabeePhone/AssistantSheet.swift:815` | Whole-card taps are `onTapGesture`: no pressed state, and none of the hover or keyboard behaviour a `Button` brings. | [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons) | Wrap in `Button` with a pressed style. | Clear |
| B12 | Sheets | Medium | `CausabeePhone/OverviewScreen.swift:247`, `CausabeePhone/Welcome.swift:43`, `CausabeePhone/SettingsSheet.swift:115` | Welcome → Settings → Mail account stacks three sheets; the assistant sheet opens the matter chooser over itself (`OverviewScreen.swift:117`, deliberate). | [Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets) ("Display only one sheet at a time"; close the first before showing the next) | Push Settings and Mail account inside one navigation stack. | Clear |
| B13 | Locale | Low | `CausabeePhone/MatterScreen.swift:1254`, `:1453` | Forms with a `DatePicker` are forced to `en_US`, overriding 24-hour time and first weekday. | [Pickers](https://developer.apple.com/design/human-interface-guidelines/pickers) | Drop the override on pickers. | Judgment |
| B14 | Undo | Medium | `CausabeePhone/MatterScreen.swift:1098`, `CausabeePhone/PeopleAndLinks.swift:421` | No undo manager in the iOS target either: shake and the three-finger swipe undo nothing but typing, so every delete is final. | [Undo and redo](https://developer.apple.com/design/human-interface-guidelines/undo-and-redo) | The same undo on the model container as M8. | Clear |

## 4. Quick wins (under 30 minutes each)

- **M9** — `.cancelAction` on Skip, Later and Close.
- **M7** (first half) — `.cancelAction` on the five popovers' Cancel buttons and the filled style on their default buttons.
- **M6** — Find Next / Previous commands on ⌘G / ⇧⌘G.
- **M14** — delete `MenuOrder`.
- **M15**, **M16** — menu label pass; real menu checkmarks.
- **M19** (second half) — `.defaultSize`.
- **M23** — replace the command-line hints.
- **M25** — the two custom items after Settings.
- **P6** — one device-name helper.
- **B1** — widen the content shapes to 44 × 44.
- **B5** — `.buttonStyle(.borderless)` on Save and Remove.
- **B7** — the glass container and the pill.
- **I2** — await the mail check in `refreshable`.

## 5. Larger structural changes

1. **One command catalogue for the menu bar (M4, M5, M6, P1).** Define the app's commands once —
   matter actions, find, sidebar and assistant toggles, mail — and build the Mac menu bar, the
   iPad menu bar, the ⋯ menus and the context menus from it. This fixes the Mac's coverage and
   gives the iPad its menu bar and shortcuts in one piece of work. It needs the commands to act
   through focused values rather than notifications, which also removes the M1 dead-menu problem.
2. **A unique Mac window (M1, M19).** `Window` instead of `WindowGroup`, with the place restored
   by scene storage.
3. **System split containers (M2, M3, M11, P2, P3).** `NavigationSplitView` with the assistant as
   an `.inspector`, and the window controls in a real toolbar. This brings keyboard navigation,
   resizing, the View menu items, the glass sidebar on 26, the edge-swipe on iPad and correct
   placement beside iPadOS window controls. The code comments show the hand-built layout was
   chosen to avoid system transitions, so this is a design decision as much as an engineering one;
   M2's `List(selection:)` is worth doing on its own either way.
4. **Undo (M8, B3, B14).** Undo on the model container, on all platforms, with confirmations kept only
   for what cannot be undone.
5. **iPad pointer and drag pass (P4, P5).** Hover effects and drop targets across the iPad layout.

P2 is not on this list: it is a visible defect in an iPad window today and worth fixing on its own,
ahead of the rest.

## 6. Parked for accessibility pass

- Many targets are tap gestures rather than buttons, so they are not reachable by keyboard or VoiceOver: Mac sidebar rows (`Causabee/Components.swift:26`), file and people rows, overview cards; phone cards (`CausabeePhone/Parts.swift:217`).
- The Mac's text scale ignores any system setting (`Causabee/TextSize.swift`).
- Gold and warning text on white, black on the fixed yellow, and `.tertiary` captions have not had a contrast check.
- The small targets in B1 and the fixed glyphs in B10 also matter here.

## 7. Assumptions, tool errors, discarded HIG Doctor findings

**Tool errors**
- HIG Doctor ran only at the end, as a cross-check rather than as the starting signal: `bun` and the auditor were not on the machine when the review was done. Its output is in `raw/hig-doctor.md` (version 2.0.3, guideline snapshot 2025-02-02).
- `bun run audit <repo> --export` from the repository's root does not exist; the script lives in `packages/cli`. It was run there with `--stdout`, because `--export` writes `hig-audit.md` into the audited repository's root.
- Homebrew would not install `bun` (Command Line Tools older than Xcode 27); the official 1.3.11 binary was used from `~/Developer/hig-tools/bin`, checksum compared.
- The `apple-hig` skill is installed in `~/.claude/skills` but was not loaded in this session; Apple's HIG pages were the reference.

**HIG Doctor: 199 concerns, what became of them**
- 111 "Image without a11y", 10 "onTapGesture without traits": accessibility, out of scope. The tap-gesture ones overlap section 6 and B11.
- 49 "svg without a11y" (marked critical): all in `scripts/film/web/*.html`, the film's pages, not the app. Discarded.
- 15 "hardcoded font size": all are SF Symbol glyph sizes, none is running text. On the Mac they do not matter (no Dynamic Type); the iPhone and iPad ones are B10, which now also covers `CausabeePhone/PhoneShots.swift:464` and `Causabee/Theme.swift:594`–`:652`. `Theme.swift:298` and `:355` scale with their tile and were discarded.
- 6 "ignoresSafeArea": discarded. Two are dividers, one is the document camera, three are the Mac's window chrome (already M11).
- 3 hard-coded colours: discarded. `Causabee/Theme.swift:88` is the helper behind the light/dark colour providers; `MatterCore/Screenshot/ScreenshotDoor.swift:180` fills a bitmap.
- 5 in `CausabeePhone/PhoneShots.swift:575`–`:578`: discarded, it draws a demo picture, not interface.
- Net: no new finding. The tool does not look at menus, windows, navigation, keyboard or pointer behaviour, which is where this review's findings are.

**Assumptions**
- Nothing was built for this review. The runtime checks used builds already on disk from 21:20 and 21:24 on 2026-10-09, a little older than commit `9b672d4`, started with `--demo` on a throwaway store; `raw/runtime-checks.md` has the details.
- Confirmed running: M1, M4, M14, M25, P1, P2, P8. Still unverified: M11 (full screen), B5 (the form row), and whether a Dock click brings the Mac window back after it is closed.
- Every file:line in section 3 was resolved against the source by script and read; the lines in section 2 are as the two platform reviews reported them, spot-checked.
- iPhone is in scope: `CausabeePhone` is universal (`TARGETED_DEVICE_FAMILY = "1,2"`).
- The Mac target deploys to macOS 15.0, so it was judged against the current design language while requiring that macOS 15 keeps working; the iOS target deploys to 26.0.
- Screenshot staging (`DemoData`, `ShotView`, `IntroShot`, `PhoneShots`) was reviewed only where it affects the real interface.
- Not every file was read line by line: `CardActions`, `CalendarChip`, `BeeLoader`, `CloudSync`, `AskSteps` and `ThreadPlacement` were only searched; `Conversation`, `MailCheck` and `SetupAssistant` were read in part.
- HIG pages read for this review: The menu bar, Settings, Windows, Sidebars, Toolbars, Typography, Keyboards, Buttons, Sheets, Undo and redo, Pointing devices, Drag and drop, Materials, Menus, Alerts, Going full screen, Multitasking, Layout, Color. The remaining pages cited (Split views, Context menus, Popovers, Searching, Search fields, Toggles, Pickers, Entering data, Offering help, File management, Launching, Loading, Writing, Lists and tables, SF Symbols) were confirmed to exist but cited from knowledge of their content.

**Changed in the second pass**
- Withdrawn: the suggestion to mark Merge as destructive (was part of B3). Apple's Alerts page says a confirmation of an action the person chose deliberately should not carry the destructive style.
- Withdrawn: the possibility of a second Mac window through the tab bar (was part of M1). The built View menu has no Show Tab Bar.
- Raised: P2 to High (confirmed running); B12 to Medium and a clear guideline ("Display only one sheet at a time").
- Added: M25 (custom items above Settings…), B14 (no undo on iPhone and iPad).
- Re-referenced: M9 to Keyboards, M21 and B4 to Layout, B1 to Buttons alone; B7 is API guidance, not a HIG rule.
- The iPhone is portrait-only (`project.pbxproj:571`); this was taken as intended and not reported.
- Uppercase section headers (`Causabee/Theme.swift:181`) are documented as a wireframe decision and were not reported.

## 8. Fixed on the branch `hig-fixes`

Only what changes behaviour, menus or words — the window looks as it did. Pictures in `raw/fixes/`.

| ID | What was done | Checked |
|---|---|---|
| M1 | Closing the window quits Causabee (`LastWindow` delegate). The scene stays a `WindowGroup`. | Running: File ▸ Close ends the app |
| M4 | View ▸ Hide/Show Sidebar ⌃⌘S, Show/Hide Assistant ⌘K, Activate/Deactivate Reading Mode; File ▸ Get New Mail. The words follow the window; ⌘K and ⌘F moved from hidden buttons to the menu. | Running: each clicked, words flip, pictures 2–4 |
| M6 | Edit ▸ Find ▸ Find … ⌘F, Find Next ⌘G, Find Previous ⇧⌘G. | Running: Find … (picture 5); ⌘G not exercised |
| M7 | Esc on the Cancel of the five popovers. The default button's look is untouched. | Built |
| M9 | Esc on Skip, Later and Close in the Introduction and Setup. | Built |
| M16 | The icon menu ticks with the menu's own checkmark instead of "  ✓" in the name (Mac and iPhone). | Built |
| M23 | The two command-line hints point to Causabee ▸ Set Up Causabee … and File ▸ New Matter …. | Built |
| P1 | An iPad menu bar: New Matter … ⌘N, Get New Mail, Settings … ⌘, , Find … ⌘F, Show/Hide Sidebar ⌃⌘S, Show/Hide Assistant ⌘K, Reading Mode. | Built; the menus were not seen open in the simulator |
| P2 | The capsule stands right of the iPad's window controls when there are any (`containerCornerOffset`), and where it was when there are none. | Running: pictures `ipad-0` (before), `ipad-1`, `ipad-2` |
| P6 | "this iPad" on an iPad: 21 strings through `ThisDevice.name`. | Built; in the simulator's full-screen overview no such string is on screen |
| B5 | Save and Remove in the iPhone's API-key rows are each pressed only where they stand. | Built |
| B2 | The task, date, person, link, scan and mail-account sheets stay under a swipe or a tap beside them once something in them was changed; unchanged they go as before, and Cancel still drops what was typed. | Running on the iPad, both ways: picture `ipad-3` |
| B3 | "Remove from all devices" asks before the synced password goes. Person and link removal wait for undo (B14). | Built |

**Tried and taken out again**
- B1, the 44-point targets: a larger content shape, and then padding taken back in the layout, both left the ⋯ menus answering only inside their 30 × 26 — tried in the simulator. A menu takes the finger where its label is laid out, so 44 points need a label that is that large, which moves the row's text a few points. That is a look to decide, not a silent change.
- P4, hover: nothing here can show a pointer over the simulator, so the effect would have gone in unseen.
- M8/B14, undo: switching undo on for the whole store would also take back what a mail check or the assistant wrote, while their records beside the store stayed. It needs a decision on which actions are undoable — the deletes by hand first — before any code.

**Left alone, with a suggestion instead — each would change something that is meant to look as it does**
- M14 (Matter after Edit) and M15 (" …" with a space): documented choices. Compliant alternative: delete `MenuOrder`; write "Rename…".
- M7's filled default button, M13, M20, M21, B4, B8: the look. Compliant alternative per row in section 3.
- M2, M3, M11, P3: need the system's list selection and split containers — section 5.
- B12, I1, I2, I3, P5 and the shared contact and detail sheets (B2 is not yet on those two): next.
- M25: the code already asks for the right place; needs a look at why the built menu differs.

**Not run:** the Mac's and the iPhone's UI tests. The Mac's need Causabee itself quit, and it was open.
