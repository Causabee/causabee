#!/bin/zsh
S="$(cd "$(dirname "$0")/../.." && pwd)/scripts/film"
D=$S/drive; [[ -x $D ]] || swiftc -O -o $D $S/drive.swift
OUT=/tmp/film-clips
rec() { ffmpeg -v error -y -f avfoundation -capture_cursor 1 -framerate 30 -i "1:none" -t $2 -vf crop=2380:1412:226:248 -c:v libx264 -preset ultrafast -crf 18 -pix_fmt yuv420p $OUT/$1.mp4 & sleep 1.5; }
done_() { wait; sleep 1; }

# Scene 2 · the overview, resting
$D click 158 202; sleep 1.5; $D move 700 400
rec s02-overview 7; sleep 1; $D move 720 420; sleep 2; $D move 760 470; sleep 3.5; done_
# Scene 3 · Get new mail
$D move 300 700; rec s03-getmail 7; sleep 1; $D click 188 807; sleep 3.6; $D move 228 806; sleep 2; done_
# Scene 5 · Sort in, then into the care matter
rec s05-sortin 9; sleep 0.6; $D click 228 806; sleep 4; $D move 213 307; sleep 1.2; $D click 213 307; sleep 3; done_
# Scene 6 · the next step, page at the top
$D scroll 1006 549 -3000; sleep 1
rec s06-nextstep 7; sleep 1; $D move 900 330; sleep 2; $D move 1000 420; sleep 3.5; done_
# Scene 11 · the source of a task (one scroll down)
$D scroll 1006 549 600; sleep 1.5
rec s11-source 7; sleep 1.5; $D move 941 712; sleep 0.8; $D click 941 712; sleep 4.5; done_
$D click 1000 170; sleep 1
# Scene 10 · who does what: tick "Read the Sunrise contract together with Nina"
rec s10-tasks 8; sleep 1; $D move 782 494; sleep 1.5; $D click 782 494; sleep 5; done_
# Scene 7 (Mac half) · the overdue task ticked, at the top
$D scroll 1006 549 -3000; sleep 1.2
rec s07-mac-tick 6; sleep 1.5; $D move 783 767; sleep 1; $D click 783 767; sleep 3; done_
# Scene 12 · the dates
$D scroll 1006 549 600; sleep 0.8; $D scroll 1006 549 500; sleep 1.5
rec s12-dates 7; sleep 1; $D move 1000 420; sleep 2; $D move 1010 520; sleep 3.5; done_
# Scene 13 · files, links, people
$D scroll 1006 549 600; sleep 1.5
rec s13-files-people 7; sleep 1; $D move 1000 380; sleep 2; $D scroll 1006 549 300; sleep 3.5; done_
# Scene 14 · the assistant's answer and its suggestion, taken in
rec s14-ask 10; sleep 1; $D move 560 450; sleep 1.5; $D move 684 674; sleep 1.5; $D click 684 674; sleep 5.5; done_
# Scene 15 · the overview again
$D click 158 202; sleep 1.5
rec s15-overview-after 7; sleep 1; $D move 700 400; sleep 2; $D move 760 470; sleep 3.5; done_
for f in $OUT/s*.mp4; do echo "$(basename $f) $(ffprobe -v error -show_entries format=duration -of csv=p=0 $f)"; done
