# F003 · The website's pictures and content from today's app — Why

## The problem

causabee.app shows and says an app that is no longer quite the one people get.

- **Old pictures.** Nine of the website's pictures are from 1 November or before: the overview, the tasks, the calendar, the files, the sources, the iPhone's matter, overview and phone picture, and the iPad's. The app has changed since: the matter opens on its Digest with what is new on top, a suggestion is taken with the thumb, the one bee in the corner says Pro, the Plan is a page of days.
- **Drawn parts that are not true any more.** The page's own animations show "2 mails sorted … · $0.012" — a cost the app no longer shows; a task "by Oct 12" in October; "2 new mails" as the first thing a visitor sees, mail before every other source.
- **Words that promise more than the app does.** "Requires macOS Sequoia 15 or later" beside "Without Pro, Apple's model on your Mac sorts what comes in" — but Apple's model needs macOS 26 (`Sources/MatterCore/DeviceReader.swift:34`). On macOS 15 without Pro, nothing reads what comes in but threads and senders. Other lines describe a matter page that is now told differently ("the story so far as a journal of cards").

## Who has it

Everyone who opens causabee.app to see whether Causabee is for them, and decides on what the page shows and says. The owner, who sends people there.

## What we know

- **The page:** `site/index.html`, 464 lines; its pictures in `site/assets/img/`, 17 files. F001 renewed five of them on 10 November (matter, care, assistant, iPhone assistant); the other nine are from 1 November, one (`iphone-care.webp`) from 2 October and unused.
- **The pictures are made by** `scripts/site-shots.sh` (Mac, cut by `scripts/site-assets.py`), and by hand in the iPhone and iPad simulators. F002 found how to take each of today's screens from the demo: `--shot`, `--part`, `--no-assistant`, `--open`, Pro on with `-mail.auto YES -auto.agreed YES`; the Mac's at 2880 × 1800 on a Retina screen.
- **The macOS line:** the app runs on macOS 15 (`MACOSX_DEPLOYMENT_TARGET = 15.0`); the model on the device only on macOS 26 and iOS 26. Assessment 2 (`product-assessment` branch) found it first.
- **The page's animations** are drawn in HTML over the pictures (`live--still` turns them off); each holds its own words and numbers.
- **F002's lessons:** the app as it behaves, not as it was; nothing before it happens; no marks on text; motion in the app's own pieces; check every full frame (`docs/features/002-the-film-anew-from-today-s-app/6-test-report.md`).

## The goal

The website shows Causabee as it is today, and every sentence on it is true for the app a visitor downloads.

## Not in this feature

- The film: F002, done.
- The privacy page's words, beyond what must change for the page to stay true (F001 renewed it on 10 November).
- The teaser films (`site/film/teaser`) and `numbers.html`.
- A new design or new sections for the website. A section may be told in other words, not added.
- Changes to the app, to make it look better on the page. What looks wrong in the app goes to the backlog.
- The model per job: F004.

## How we know it worked

The owner reads causabee.app from top to bottom, on the Mac and on the iPhone, beside today's app, and finds no picture, number or sentence that the app does not show or do.

## Principles it touches

- **1, everything counts:** the first thing on the page is not mail alone.
- **11, said as it is:** what the page promises — the AI, the macOS it runs on, what is free and what needs Pro — is exactly what the app does. A picture of the app shows it as it is today and as it behaves (the rule F002 added).
- **12, everywhere the same:** the Mac, the iPad and the iPhone on the page show one matter, one state.
