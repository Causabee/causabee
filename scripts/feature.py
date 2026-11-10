#!/usr/bin/env python3
# The feature pipeline's bookkeeping (docs/pipeline.md): a folder per feature under docs/features,
# six files, one stage at a time, each gate opened by the owner's word.
#
#   scripts/feature.py new "Name of the feature" [--polish]   # the next number, its folder, its files
#   scripts/feature.py status                                 # every feature and its stage
#   scripts/feature.py check 7                                # is the stage's file complete?
#   scripts/feature.py advance 7 --word "approved"            # the gate, opened by the owner's word
#   scripts/feature.py park "The gap under the date is too small"
#   scripts/feature.py drop 7 "Not needed after all"
#
# It checks what a machine can: nothing left empty, every criterion written as Given / When / Then,
# every criterion with a test in the plan, and — before "done" — with a tagged test in Tests/ and
# "pass" in the report. Whether a criterion is the right one is the owner's to say.
# --root names another repository folder: for trying the script without touching this one.
import argparse, datetime, pathlib, re, sys

STAGES = {1: ("Why", "1-prd.md"), 2: ("What", "2-acceptance.md"), 3: ("How", "3-spec.md"),
          4: ("Looks", "4-ui-spec.md"), 5: ("Build", "5-plan.md"), 6: ("Proof", "6-test-report.md")}
DONE, DROPPED = 7, 0
TODAY = datetime.date.today().isoformat()


def fail(words):
    print("✗ " + words, file=sys.stderr)
    sys.exit(1)


class Repo:
    def __init__(self, root):
        self.root = pathlib.Path(root).resolve()
        self.features = self.root / "docs" / "features"
        self.template = self.features / "_template"
        self.backlog = self.root / "docs" / "backlog.md"

    def folders(self):
        found = [p for p in self.features.iterdir() if p.is_dir() and re.match(r"\d{3}-", p.name)] if self.features.exists() else []
        return sorted(found, key=lambda p: p.name)

    def folder(self, number):
        for path in self.folders():
            if int(path.name[:3]) == int(number):
                return path
        fail(f"There is no feature {int(number):03d}. `scripts/feature.py status` lists them.")

    def card(self, folder):
        text = (folder / "README.md").read_text()
        stage = re.search(r"^- Stage: (\w+)", text, re.M)
        title = re.search(r"^# F\d+ · (.+)$", text, re.M)
        lane = re.search(r"^- Lane: (\w+)", text, re.M)
        value = stage.group(1) if stage else "1"
        number = {"done": DONE, "dropped": DROPPED}.get(value, int(value) if value.isdigit() else 1)
        return {"stage": number, "name": title.group(1) if title else folder.name, "lane": lane.group(1) if lane else "feature", "text": text}

    def set_stage(self, folder, stage, word):
        card = self.card(folder)
        value = {DONE: "done", DROPPED: "dropped"}.get(stage, str(stage))
        text = re.sub(r"^- Stage: \w+", f"- Stage: {value}", card["text"], count=1, flags=re.M)
        if word is not None:
            closed = card["stage"]
            label = f"{closed} · {STAGES[closed][0]}" if closed in STAGES else "—"
            row = f"| {label} | {TODAY} | {word} |"
            text = re.sub(r"(\|---\|---\|---\|\n(?:\|.*\|\n)*)", lambda m: m.group(1) + row + "\n", text, count=1)
        (folder / "README.md").write_text(text)

    def write_index(self):
        rows = []
        for folder in self.folders():
            card = self.card(folder)
            stage = card["stage"]
            where = "Done" if stage == DONE else "Dropped" if stage == DROPPED else f"{stage} · {STAGES[stage][0]}"
            rows.append(f"| [F{folder.name[:3]}]({folder.name}/README.md) | {card['name']} | {card['lane']} | {where} |")
        body = ["# Features", "",
                "Every feature built through the pipeline ([how](../pipeline.md)). Written by `scripts/feature.py`; do not edit by hand.", "",
                "| | Feature | Lane | Stage |", "|---|---|---|---|"] + rows
        (self.features / "README.md").write_text("\n".join(body) + "\n")


def plain(text):
    """The file without its guidance: comments are for the writer, not content."""
    return re.sub(r"<!--.*?-->", "", text, flags=re.S)


def empty_sections(text):
    """The `##` sections with nothing written under them."""
    empty = []
    parts = re.split(r"^## +(.+)$", plain(text), flags=re.M)
    for title, body in zip(parts[1::2], parts[2::2]):
        said = [l for l in body.splitlines() if l.strip() and not l.startswith("Schema change:")
                and not re.fullmatch(r"\|[\s|:-]*\|", l.strip()) and not re.fullmatch(r"\|\s*Criterion\s*\|.*", l.strip())
                and not re.fullmatch(r"- (Given|When|Then|Holds for:)", l.strip()) and not re.fullmatch(r"### AC-\d+ ·", l.strip())]
        if not said:
            empty.append(title.strip())
    return empty


def criteria(folder):
    """AC ids with what is wrong in each, from 2-acceptance.md."""
    text = plain((folder / "2-acceptance.md").read_text())
    found = {}
    parts = re.split(r"^### +(AC-\d+)(.*)$", text, flags=re.M)
    for name, title, body in zip(parts[1::3], parts[2::3], parts[3::3]):
        body = re.split(r"^## ", body, flags=re.M)[0]
        wrong = []
        if not title.strip(" ·"):
            wrong.append("no title")
        for word in ("Given", "When", "Then", "Holds for:"):
            if not re.search(rf"^- {re.escape(word)}[ \t]+\S", body, re.M):
                wrong.append(f"no “{word.rstrip(':')}”")
        found[name] = wrong
    return found


def check(repo, folder, stage):
    """What still stands in the way of this stage's gate. An empty list opens it to the owner."""
    problems = []
    number = folder.name[:3]
    name, file = STAGES[stage]
    path = folder / file
    if not path.exists():
        return [f"{file} is missing."]
    text = path.read_text()
    if "{{" in plain(text):
        problems.append(f"{file}: a placeholder is left ({{{{…}}}}).")
    for title in empty_sections(text):
        problems.append(f"{file}: “{title}” is empty. Write it, or “Not needed:” and why.")

    acs = criteria(folder) if (folder / "2-acceptance.md").exists() else {}
    if stage >= 2:
        if not acs:
            problems.append("2-acceptance.md: no criterion (### AC-1 · …).")
        for ac, wrong in acs.items():
            if wrong:
                problems.append(f"2-acceptance.md: {ac} has {', '.join(wrong)}.")
    if stage == 2:
        questions = re.split(r"^## +Open questions\s*$", plain(text), flags=re.M)
        if len(questions) > 1 and not re.match(r"\s*None\b", questions[1].split("\n## ")[0], re.I):
            problems.append("2-acceptance.md: a question is open. The gate stays closed until it says “None”.")
    if stage == 3 and not re.search(r"^Schema change: none\s*$", plain(text), re.M | re.I):
        problems.append("3-spec.md: the schema would change. That is the owner's decision — ask, and write the answer under “Changes after a gate”.")
    if stage == 5:
        for ac in acs:
            if not re.search(rf"^\|\s*{ac}\b.*\|\s*\S.*\|", plain(text), re.M):
                problems.append(f"5-plan.md: {ac} has no test in the table.")
    if stage == 6:
        tests = repo.root / "Tests"
        sources = "\n".join(p.read_text(errors="ignore") for p in tests.rglob("*.swift")) if tests.exists() else ""
        for ac in acs:
            if not re.search(rf"F{number} {ac}\b", sources):
                problems.append(f"Tests/: no test carries the tag “F{number} {ac}”.")
            row = re.search(rf"^\|\s*{ac}\b.*\|\s*(\w+)\s*\|\s*$", plain(text), re.M)
            if not row:
                problems.append(f"6-test-report.md: {ac} is not in the table.")
            elif row.group(1).lower() != "pass":
                problems.append(f"6-test-report.md: {ac} is “{row.group(1)}”, not “pass”.")
    return problems


def slug(name):
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")[:40] or "feature"


def main():
    parser = argparse.ArgumentParser(description="The feature pipeline (docs/pipeline.md).")
    parser.add_argument("--root", default=str(pathlib.Path(__file__).resolve().parent.parent))
    commands = parser.add_subparsers(dest="command", required=True)
    new = commands.add_parser("new"); new.add_argument("name"); new.add_argument("--polish", action="store_true")
    commands.add_parser("status")
    for name in ("check", "advance"):
        one = commands.add_parser(name); one.add_argument("number")
        if name == "advance":
            one.add_argument("--word", required=True, help="what the owner said to open the gate")
    park = commands.add_parser("park"); park.add_argument("idea")
    drop = commands.add_parser("drop"); drop.add_argument("number"); drop.add_argument("why")
    args = parser.parse_args()
    repo = Repo(args.root)

    if args.command == "new":
        flying = [f for f in repo.folders() if repo.card(f)["stage"] in STAGES]
        if flying:
            card = repo.card(flying[0])
            fail(f"F{flying[0].name[:3]} “{card['name']}” is in flight, at stage {card['stage']}. One feature at a time: "
                 f"finish it, or `scripts/feature.py drop {int(flying[0].name[:3])} \"why\"`. An idea for later: `scripts/feature.py park \"…\"`.")
        number = f"{max([int(f.name[:3]) for f in repo.folders()] + [0]) + 1:03d}"
        folder = repo.features / f"{number}-{slug(args.name)}"
        folder.mkdir(parents=True)
        fills = {"{{NUMBER}}": number, "{{NAME}}": args.name, "{{SLUG}}": slug(args.name), "{{DATE}}": TODAY,
                 "{{LANE}}": "polish" if args.polish else "feature"}
        for source in sorted(repo.template.glob("*.md")):
            text = source.read_text()
            for key, value in fills.items():
                text = text.replace(key, value)
            (folder / source.name).write_text(text)
        repo.write_index()
        print(f"✓ F{number} “{args.name}” — {folder.relative_to(repo.root)}. Stage 1, Why: write 1-prd.md.")

    elif args.command == "status":
        if not repo.folders():
            print("No feature yet. `scripts/feature.py new \"Name\"` starts one.")
        for folder in repo.folders():
            card = repo.card(folder)
            stage = card["stage"]
            where = "done" if stage == DONE else "dropped" if stage == DROPPED else f"stage {stage} · {STAGES[stage][0]} ({STAGES[stage][1]})"
            mark = "→" if stage in STAGES else " "
            print(f"{mark} F{folder.name[:3]}  {card['name']}  —  {where}")

    elif args.command in ("check", "advance"):
        folder = repo.folder(args.number)
        stage = repo.card(folder)["stage"]
        if stage not in STAGES:
            fail(f"F{folder.name[:3]} is {'done' if stage == DONE else 'dropped'}. A change to it is a new feature.")
        problems = check(repo, folder, stage)
        for problem in problems:
            print("✗ " + problem)
        if problems:
            sys.exit(1)
        if args.command == "check":
            print(f"✓ F{folder.name[:3]}, stage {stage} · {STAGES[stage][0]}: complete. The gate is the owner's to open.")
            return
        repo.set_stage(folder, stage + 1, args.word)
        repo.write_index()
        after = stage + 1
        print(f"✓ F{folder.name[:3]}: gate {stage} · {STAGES[stage][0]} opened with “{args.word}”. "
              + ("Done. A change to it from here is a new feature." if after == DONE else f"Now stage {after} · {STAGES[after][0]}: {STAGES[after][1]}."))

    elif args.command == "park":
        text = repo.backlog.read_text() if repo.backlog.exists() else "# Backlog\n"
        line = f"- {args.idea.strip()} ({TODAY})"
        if "## Parked" in text:
            # Newest first, under the section's own sentence.
            head, _, rest = text.partition("## Parked\n")
            lines = rest.split("\n")
            at = next((i for i, l in enumerate(lines) if l.startswith("- ") or l.startswith("## ")), len(lines))
            lines.insert(at, line)
            text = head + "## Parked\n" + "\n".join(lines)
        else:
            head, _, rest = text.partition("\n## ")
            parked = ("## Parked\n\nSeen while building something else. Not built now: each becomes a feature, joins a polish batch, or is dropped.\n\n"
                      + line + "\n")
            text = head.rstrip("\n") + "\n\n" + parked + ("\n## " + rest if rest else "")
        repo.backlog.write_text(text)
        print(f"✓ Parked in docs/backlog.md: {args.idea.strip()}")

    elif args.command == "drop":
        folder = repo.folder(args.number)
        if repo.card(folder)["stage"] not in STAGES:
            fail(f"F{folder.name[:3]} is not in flight.")
        repo.set_stage(folder, DROPPED, None)
        with (folder / "README.md").open("a") as card:
            card.write(f"\n## Dropped\n\n{TODAY} · {args.why.strip()}\n")
        repo.write_index()
        print(f"✓ F{folder.name[:3]} dropped: {args.why.strip()}")


if __name__ == "__main__":
    main()
