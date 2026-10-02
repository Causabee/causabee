# The film's draft, recorded from the demo

Records the Mac scenes of concept/film-storyboard.md from the demo and cuts them to a portrait draft.

1. Build the Release app: `scripts/intro-shots.sh` builds it into `.build-app/shots`, or run the
   `xcodebuild` line from that script.
2. Start the demo on a store of its own and leave the window where it opens (113, 124; 1190 × 706):
   `open -n -a .build-app/shots/Build/Products/Release/Matterbee.app --args --store /tmp/film-demo/matters.store --demo`
3. `scripts/film/record-mac.sh` — clicks through the scenes (`drive.swift` posts the mouse events;
   the Terminal needs Accessibility and Screen Recording) and records each as /tmp/film-clips/sNN.mp4
   with ffmpeg. Keep the demo window in front: clicks go to whatever is on top.
4. `python3 scripts/film/assemble.py` — crops each clip to 9:16, adds the caption, puts placeholder
   cards where the iPhone and the disguise scenes are, and writes concept/film/draft-mac.mp4.

The click positions are for that window size and the demo's state on a fresh store; the sidebar
re-sorts once a matter has nothing overdue, so scene 15 scrolls to find the care card.
