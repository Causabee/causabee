# F003 · The website's pictures and content from today's app — Build

## Steps

On the branch `feature/003-the-website-s-pictures-and-content-from-today-s-app`.

1. **The tests, failing:** `WebsiteLookTests`, tagged `F003 AC-1` … `AC-3`.
2. **The Mac's pictures:** `scripts/intro-shots.sh --site-only` (the app's own pictures left alone), Pro on, on the Retina screen; `scripts/site-assets.py --pictures` with every crop measured again on today's shots.
3. **The iPhone's and the iPad's:** from a fresh install in the simulators, Pro on, 09:41; one state of Mum's matter on all four.
4. **The words** of stage 4, the alt texts, the `?v=` of every changed picture; the hidden animation stages out; the unused pictures out.
5. **Everything else:** `scripts/test.sh`; `git diff main -- App Sources` stays empty. A sheet of the new pictures beside the old for the owner.

## A test for every criterion

| Criterion | Test | Kind |
|---|---|---|
| AC-1 | `WebsiteLookTests` "F003 AC-1 · The website's pictures are today's app" | unit, owner |
| AC-2 | `WebsiteLookTests` "F003 AC-2 · Every sentence on the website is true for the app" | unit, owner |
| AC-3 | `WebsiteLookTests` "F003 AC-3 · Every picture of the app says in words what it shows" | unit, owner |
| AC-4 | The owner's look at each group of pictures | owner |

## What it adds to the manifesto

Nothing: principle 11 already says it (F002).

## The line for the release notes

causabee.app shows Causabee as it is today, and says what works on macOS 15 and what needs macOS 26.
