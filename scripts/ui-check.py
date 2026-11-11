#!/usr/bin/env python3
# The mechanical part of the UI check (docs/design-system.md): what a machine can see in a line of
# SwiftUI — a colour, a font or a material by hand, glass without the helpers, a hand-made card,
# a tap gesture where a button belongs. The rest is read by the /ui-check skill.
#
#   scripts/ui-check.py                 # the lines changed on this branch, since main, and not yet committed
#   scripts/ui-check.py --all           # every line of the app's views
#   scripts/ui-check.py FILE …          # every line of these files
#   scripts/ui-check.py --report        # the same, as Markdown, for a report
#   scripts/ui-check.py --hook          # for Claude Code: reads the edit from stdin, checks its file's changed lines
#
# ✗ breaks a rule. ? asks to be looked at: a reader decides.
# A line keeps a rule aside with `// ui-check: allow T1 — why`, on it or on the line above.
# Exit: 0 with no ✗, 1 with one or more (the hook: 2, so that Claude reads it).
import argparse, json, os, pathlib, re, subprocess, sys
from collections import Counter

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCOPE = ("Sources/Causabee/", "Sources/CausabeePhone/", "Sources/CausabeeShare/")
SYSTEM = {"Theme.swift", "Journal.swift", "Components.swift", "Parts.swift", "TextSize.swift"}
DRAWINGS = {"IntroOpener.swift", "IntroShot.swift", "ShotView.swift", "PhoneShots.swift"}

NAMED = r"(?:black|white|red|blue|green|orange|yellow|pink|purple|gray|grey|teal|indigo|mint|cyan|brown)"
# rule, mark, pattern, what it says, files that define it (the rule does not apply there)
RULES = [
    ("T1", "✗", re.compile(r"\b(?:Color|NSColor|UIColor|CGColor)\(\s*(?:red|white|hue|srgbRed|displayP3Red|\.sRGB)\b|#colorLiteral"),
     "a colour by hand: use a Theme colour or .primary / .secondary", {"Theme.swift"} | DRAWINGS),
    ("T1", "✗", re.compile(rf"\bColor\.{NAMED}\b|(?:foregroundStyle|foregroundColor|fill|background|tint|stroke|strokeBorder|color:)\s*\(?\s*\.{NAMED}\b"),
     "a named colour (does not adapt, is not ours): use a Theme colour", {"Theme.swift"} | DRAWINGS),
    ("T3", "✗", re.compile(r"\bFont\.custom\(|\.custom\(\s*\""),
     "a font by hand: use a Theme font", {"Theme.swift", "Parts.swift"} | DRAWINGS),
    ("T3", "✗", re.compile(r"\.system\(\s*size:"),
     "a fixed text size: use a text style (.body, .callout, .caption …) or a Theme font", {"Theme.swift", "TextSize.swift"} | DRAWINGS),
    ("C1", "✗", re.compile(r"\.borderedProminent\b"),
     "a prominent button (black words on black): use .filledButton()", set()),
    ("C1", "✗", re.compile(r"\b(?:struct|class)\s+\w+\s*:\s*(?:\w+\s*,\s*)*(?:Primitive)?ButtonStyle\b"),
     "a new button style: use .filledButton(), .quietButton(), .gold, .plain or .rowIcon", SYSTEM),
    ("C2", "✗", re.compile(r"\.background\(\s*(?:Theme\.(?:card|box|page|canvas)|Color\.\w+)\s*,\s*in:\s*(?:RoundedRectangle|\.rect)"),
     "a hand-made card: use .journalCard(), .box(), .quietBox(), .phoneBox(), .phoneCard() or Card", SYSTEM | DRAWINGS),
    ("G2", "✗", re.compile(r"\.glassEffect\("),
     "glass by hand: use .onGlass(shape) or .glassBehind(shape)", {"Theme.swift"}),
    ("G3", "✗", re.compile(r"\.(?:ultraThin|thin|regular|thick|ultraThick|bar)Material\b|\bMaterial\.(?:ultraThin|thin|regular|thick|ultraThick|bar)\b"),
     "a material by hand: glass is the house's, through .onGlass / .glassBehind", {"Theme.swift"}),
    ("H1", "?", re.compile(r"\.onTapGesture\b"),
     "a tap gesture: a Button gives a pressed state, the keyboard and VoiceOver", DRAWINGS),
    ("T5", "?", re.compile(r"cornerRadius:\s*\d"),
     "a radius by number: Theme.cardRadius, .tileRadius, or a named one", SYSTEM | DRAWINGS),
]
ALLOW = re.compile(r"//\s*ui-check:\s*allow\s+([A-Z]\d+(?:\s*,\s*[A-Z]\d+)*)\s*[—–-]+\s*\S")


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True).stdout


def in_scope(path):
    return path.endswith(".swift") and path.startswith(SCOPE)


def base():
    """Where this branch left main; on main itself, its last commit."""
    for ref in ("main", "origin/main"):
        found = git("merge-base", "HEAD", ref).strip()
        if found:
            return found
    return "HEAD"


def changed_lines(paths=None):
    """{path: set of line numbers} added or changed since the base, committed or not; new files whole."""
    out = {}
    args = ["diff", "-U0", "--no-color", base(), "--"] + (list(paths) if paths else list(SCOPE))
    path = None
    for line in git(*args).splitlines():
        if line.startswith("+++ "):
            name = line[4:]
            path = name[2:] if name.startswith("b/") else None
        elif line.startswith("@@") and path:
            m = re.search(r"\+(\d+)(?:,(\d+))?", line)
            start, count = int(m.group(1)), int(m.group(2) or 1)
            out.setdefault(path, set()).update(range(start, start + count))
    for name in git("ls-files", "--others", "--exclude-standard", "--", *(list(paths) if paths else list(SCOPE))).splitlines():
        if (ROOT / name).exists():
            out[name] = set(range(1, len((ROOT / name).read_text(errors="ignore").splitlines()) + 1))
    return {p: lines for p, lines in out.items() if in_scope(p)}


def all_lines(paths=None):
    names = paths or [str(p.relative_to(ROOT)) for s in SCOPE for p in sorted((ROOT / s).rglob("*.swift"))]
    return {n: None for n in names if in_scope(n) and (ROOT / n).exists()}


def code_of(line):
    """The line without its comment and its strings' words, so that prose does not count."""
    line = re.sub(r'"(?:[^"\\]|\\.)*"', '""', line)
    return line.split("//", 1)[0]


def check(targets):
    findings = []
    for path, lines in targets.items():
        name = pathlib.Path(path).name
        text = (ROOT / path).read_text(errors="ignore").splitlines()
        in_block = False
        for number, raw in enumerate(text, 1):
            stripped = raw.strip()
            if in_block:
                in_block = "*/" not in stripped
                continue
            if stripped.startswith("/*"):
                in_block = "*/" not in stripped
                continue
            if lines is not None and number not in lines:
                continue
            code = code_of(raw)
            # A shadow is black by nature, in light and in dark: not a colour of the page.
            code = re.sub(r"shadow\(\s*color:\s*(?:Color)?\.black\b", "shadow(color: SHADOW", code)
            if not code.strip():
                continue
            allowed = set()
            for source in (raw, text[number - 2] if number > 1 else ""):
                m = ALLOW.search(source)
                if m:
                    allowed |= {r.strip() for r in m.group(1).split(",")}
            for rule, mark, pattern, says, defined_in in RULES:
                if name in defined_in or rule in allowed or not pattern.search(code):
                    continue
                said = says
                near = " ".join(code_of(l) for l in text[max(0, number - 3):number])
                if rule == "T3" and "size:" in pattern.pattern and "Text(" not in code and "Image(" in near:
                    rule, mark, said = "H5", "?", "a glyph by point size: size it by the text style beside it or .imageScale"
                findings.append((path, number, rule, mark, said, stripped))
    return findings


def show(findings, report, scope_words):
    errors = [f for f in findings if f[3] == "✗"]
    looks = [f for f in findings if f[3] == "?"]
    if report:
        print(f"## Mechanical check — {scope_words}\n")
        print(f"{len(errors)} ✗ · {len(looks)} ? · rules in docs/design-system.md\n")
        for title, part in (("Breaks a rule", errors), ("To look at", looks)):
            if not part:
                continue
            counts = Counter(f[2] for f in part)
            print(f"### {title} ({', '.join(f'{r} {n}' for r, n in sorted(counts.items()))})\n")
            print("| Where | Rule | What | Line |\n|---|---|---|---|")
            for path, number, rule, mark, says, line in part:
                cell = line[:90].replace("|", "\\|")
                print(f"| `{path}:{number}` | {rule} | {says} | `{cell}` |")
            print()
        return
    for path, number, rule, mark, says, line in findings:
        print(f"{mark} {path}:{number}  {rule}  {says}\n      {line[:120]}")
    counts = Counter(f[2] for f in findings)
    tally = ", ".join(f"{r} {n}" for r, n in sorted(counts.items()))
    print(f"\nui-check ({scope_words}): {len(errors)} ✗, {len(looks)} ?" + (f" — {tally}" if tally else "") + ". Rules: docs/design-system.md")


def hook():
    """After an edit in Claude Code: the edited file's changed lines; quiet when there is nothing."""
    try:
        event = json.load(sys.stdin)
    except ValueError:
        return 0
    file = (event.get("tool_input") or {}).get("file_path") or ""
    try:
        path = str(pathlib.Path(file).resolve().relative_to(ROOT))
    except ValueError:
        return 0
    if not in_scope(path):
        return 0
    findings = check(changed_lines([path]))
    if not findings:
        return 0
    out = [f"ui-check on what you just changed in {path} (docs/design-system.md):"]
    out += [f"{m} {p}:{n}  {r}  {s}" for p, n, r, m, s, _ in findings]
    out.append("Use the design system's part, or keep it with `// ui-check: allow <rule> — why` if the owner agrees. Do not change what this edit did not touch.")
    print("\n".join(out), file=sys.stderr)
    return 2 if any(f[3] == "✗" for f in findings) else 0


def main():
    parser = argparse.ArgumentParser(description="The mechanical UI check (docs/design-system.md).")
    parser.add_argument("files", nargs="*", help="check every line of these files")
    parser.add_argument("--all", action="store_true", help="every line of the app's views")
    parser.add_argument("--report", action="store_true", help="Markdown, for a report")
    parser.add_argument("--hook", action="store_true", help="Claude Code's PostToolUse hook")
    args = parser.parse_args()
    if args.hook:
        sys.exit(hook())
    if args.files:
        files = [str(pathlib.Path(f).resolve().relative_to(ROOT)) for f in args.files]
        targets, words = all_lines(files), "the files named"
    elif args.all:
        targets, words = all_lines(), "all of the app's views"
    else:
        targets, words = changed_lines(), f"lines changed since {base()[:7]}"
    findings = check(targets)
    show(findings, args.report, words)
    sys.exit(1 if any(f[3] == "✗" for f in findings) else 0)


if __name__ == "__main__":
    main()
