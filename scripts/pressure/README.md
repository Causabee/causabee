# Writing messages — pressure test

Real answers of the bee (GPT-6.1 Sol, `OPENAI_API_KEY` in `.env`) to `cases.json`, on the demo's invented matters only.

1. Copy the simulator's demo store (Causabee-Demo) to a folder, e.g. `$SP/demo`.
2. `swift build --product matter-spike && .build/debug/matter-spike pressure scripts/pressure/cases.json $SP/results.json --store $SP/demo/matters.store --mapping $SP/mapping.json`
3. Screenshots: `TEST_RUNNER_PRESSURE_CASES=… TEST_RUNNER_PRESSURE_RESULTS=$SP/results.json TEST_RUNNER_SHOT_DIR=$SP/shots xcodebuild test … -only-testing:CausabeePhoneUITests/PressureShots`
4. Report: `python3 -I scripts/pressure/report.py $SP docs/message-pressure-test.md $SP/shots` (keep round 1 as `results-round1.json` to compare).
