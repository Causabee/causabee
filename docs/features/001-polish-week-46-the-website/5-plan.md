# F001 · Polish, week 46: the website — Build

## Steps

Branch `feature/001-polish-week-46-the-website`.

1. **Tests first**, in `Tests/MatterCoreTests/WebsiteLookTests.swift`, each tagged `F001 AC-n`. Run them and see them fail.
2. **The film's page.** Its three serif rules become 400 in the text shape, and the letter changes to Source Serif 4. Then the AC-1 test passes.
3. **Rendering.** `scripts/film/render.swift` gets `--size`, `--ms` and `--root`. The film's 3,900 frames are rendered to a folder outside the repository.
4. **Encoding.**
   - ffmpeg makes the 1080p film with the sound of today's, the 720p film from it, and the poster from frame 0.
   - The steps go into `scripts/film/walkthrough.sh`, so the next render is one command.
5. **The screenshot.** `scripts/site-shots.sh` takes the demo's pictures. Only `matter-1440` and `matter-2880` are copied into `site/`, plus any picture the AC-3 test finds.
6. **The privacy page's date.**
7. **Version numbers.** The `?v=` of the changed files in `site/index.html` go up.
8. **Stills for the owner.** Today and after, side by side: the opening title, a caption, the letter, the screenshot.
9. **All of it:** `scripts/test.sh`. The app is not touched, so the screen tests on iPhone, iPad and Mac are not needed; the report says so.

## A test for every criterion

| Criterion | Test | Kind |
|---|---|---|
| AC-1 | `WebsiteLookTests.filmSerifIsTheWebsites`: every rule in the film's page that uses the serif is 400 in the text shape, and no serif rule names another typeface | unit |
| AC-2 | `WebsiteLookTests.filmIsRenderedFromThePage`: both films are newer than the page, both have a sound track, and both last as long as before, within 0.1 s. Plus the owner's look at the stills and on causabee.app | unit + the owner |
| AC-3 | `WebsiteLookTests.noPictureNamesAnotherAI`: Apple's Vision reads the words of every picture in `site/assets/img` and the poster; none is Claude, Opus, Haiku, Mistral or Anthropic | unit |
| AC-4 | `WebsiteLookTests.privacyDateIsItsLastChange`: the "Effective" date is the day git last saw the page's text change, or today while it is being changed | unit |

## What it adds to the manifesto

Nothing. The rule "said as it is" is principle 11 already. The new tests guard it on the website.

## The line for the release notes

Not needed: the website is not a release. Its own commit says what changed.
