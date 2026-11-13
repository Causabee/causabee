#!/usr/bin/env python3
"""Causabee's words, in both languages (F009).

Reads the sources, finds every word a person is shown, and keeps the two String Catalogues up to
date — MatterCore's for the words all three devices share, the apps' for their own:

    python3 -I scripts/words.py            # add what is new, keep the German there is
    python3 -I scripts/words.py --missing  # say which words have no German yet
    python3 -I scripts/words.py --build <derived data>   # and the words that carry a value
    python3 -I scripts/words.py --escaped  # any word a person reads that is in no catalogue

The English word is the key, as SwiftUI does it: `Text("Save")` looks up "Save". German is written
by hand into the catalogues and read by the owner before anything ships. A word that is only stored
— a UserDefaults key, a Keychain service, a folder's name — is never in here.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

# Where the words of each catalogue come from, and the short name its kept words carry.
PLACES = [
    ("Sources/MatterCore/Resources/Localizable.xcstrings", ["Sources/MatterCore"], "core"),
    ("App/Resources/Localizable.xcstrings", ["Sources/Causabee", "Sources/CausabeePhone", "Sources/CausabeeShare"], "app"),
]

# The words that carry a value ("Overdue since %@"). Only the compiler knows the right placeholder
# for a value's type, so `--build` reads them out of what Xcode left behind and writes them here;
# every run after that reads this file, and the words stay even when nobody has built since.
VALUES = "scripts/words-values.txt"

# Every literal in the sources that is NOT a word a person reads, named one by one: the net of
# `--escaped` catches everything that looks like words, and this is what was looked at and let go.
MACHINE = "scripts/words-machine.txt"

# Where a value stood in a literal, while `--escaped` reads it.
HOLE = "\u0001"

# Files that hold no word a person reads at all. Each one says why, because a file let go here is a
# file the net never looks at again.
NOT_READ = {
    "Sources/Causabee/DemoData.swift": "the example matter's own content, in its own language",
    "Sources/MatterCore/Pseudonymizer.swift": "the names and patterns that disguise what is sent",
    "Sources/MatterCore/Prompts/AdviserPrompt.swift": "what the model is told",
    "Sources/MatterCore/Prompts/AssistantPrompt.swift": "what the model is told",
    "Sources/MatterCore/Prompts/ExtractionPrompt.swift": "what the model is told",
    "Sources/MatterCore/Prompts/BriefPrompt.swift": "what the model is told",
    "Sources/MatterCore/DeviceReader.swift": "what Apple's model on the device is told",
    "Sources/MatterCore/Voice/PlainWords.swift": "what the model tidying speech is told",
    "Sources/MatterCore/Report.swift": "the measurement report, for whoever builds Causabee",
    "Sources/MatterCore/ReviewPage.swift": "the measurement report, for whoever builds Causabee",
    "Sources/MatterCore/GoldenSet.swift": "the golden set, for whoever builds Causabee",
    "Sources/MatterCore/Judge.swift": "the judge that pairs to-dos while measuring",
    "Sources/MatterCore/Spike.swift": "the measurement run",
    "Sources/MatterCore/IMAP/IMAPClient.swift": "the mail protocol",
    "Sources/MatterCore/IMAP/MailProviders.swift": "the providers' own host names and ports",
    "Sources/MatterCore/IMAP/MailDiscovery.swift": "finding a provider's server",
    "Sources/MatterCore/EMLParser.swift": "a mail's own headers and encodings",
    "Sources/MatterCore/MIME.swift": "a mail's own parts",
    "Sources/MatterCore/MailLinks.swift": "the marks a quoted mail is known by",
    "Sources/MatterCore/Quotes.swift": "the marks a quoted mail is known by",
    "Sources/MatterCore/Screenshot/ChatReader.swift": "the marks a chat screenshot is known by",
    "Sources/MatterCore/DocumentTitle.swift": "the prefixes a document's own title carries",
    "Sources/MatterCore/EntityDetector.swift": "what a name, a place or a number looks like",
    "Sources/MatterCore/TimeWords.swift": "what a time looks like, in both languages",
    "Sources/MatterCore/DateFinder.swift": "what a date looks like, in both languages",
    "Sources/MatterCore/BulkFilter.swift": "what a circular looks like",
    "Sources/MatterCore/Model/ChatDepth.swift": "the words a question is weighed by, in both languages",
    "Sources/MatterCore/Model/VaultOffers.swift": "what a number worth keeping looks like",
    "Sources/MatterCore/Keychain.swift": "the Keychain's own services and accounts",
    "Sources/MatterCore/Google/GoogleSignIn.swift": "Google's own sign-in",
}

# What a person is shown. SwiftUI looks these up by itself; `String(localized:)` is ours.
SHOWN = [
    r'String\(localized: "((?:[^"\\]|\\.)+)"',
    r'\bText\("((?:[^"\\]|\\.)+)"',
    r'\bButton\("((?:[^"\\]|\\.)+)"',
    r'\bLabel\("((?:[^"\\]|\\.)+)"',
    r'\bToggle\("((?:[^"\\]|\\.)+)"',
    r'\bTextField\("((?:[^"\\]|\\.)+)"',
    r'\bSection\("((?:[^"\\]|\\.)+)"',
    r'\bPicker\("((?:[^"\\]|\\.)+)"',
    r'\bStepper\("((?:[^"\\]|\\.)+)"',
    r'\bLink\("((?:[^"\\]|\\.)+)"',
    r'\bAlert\("((?:[^"\\]|\\.)+)"',
    r'\.alert\("((?:[^"\\]|\\.)+)"',
    r'\.help\("((?:[^"\\]|\\.)+)"',
    r'\.accessibilityLabel\("((?:[^"\\]|\\.)+)"',
    r'\.accessibilityHint\("((?:[^"\\]|\\.)+)"',
    r'\.navigationTitle\("((?:[^"\\]|\\.)+)"',
    r'\.confirmationDialog\("((?:[^"\\]|\\.)+)"',
    r'\bMenu\("((?:[^"\\]|\\.)+)"',
    r'\bCommandMenu\("((?:[^"\\]|\\.)+)"',
    r'\bContentUnavailableView\("((?:[^"\\]|\\.)+)"',
    r'\bDatePicker\("((?:[^"\\]|\\.)+)"',
    r'\.searchable\(prompt: "((?:[^"\\]|\\.)+)"',
    r'\.accessibilityValue\("((?:[^"\\]|\\.)+)"',
]

def literals(line: str) -> list[dict]:
    """Every string literal of one line, as Swift reads it: an escape is one character, and a hole
    for a value (`\\(…)`) is a hole — so a literal written inside one is a literal of its own."""
    out, i, n, cur, stack = [], 0, len(line), None, []
    while i < n:
        character = line[i]
        if cur is None:
            if character == '"':
                cur, i = {"text": "", "at": i}, i + 1
                continue
            if line[i:i + 2] == "//":
                break
            i += 1
            continue
        if character == "\\":
            pair = line[i:i + 2]
            if pair == "\\(":                       # the value goes in here
                stack.append(cur)
                cur, depth, i = None, 1, i + 2
                while i < n and depth:              # over the hole, keeping its own literals
                    if line[i] == '"':
                        out += literals(line[i:])
                        i, escaped = i + 1, False
                        while i < n:
                            if escaped: escaped = False
                            elif line[i] == "\\": escaped = True
                            elif line[i] == '"': break
                            i += 1
                        i += 1
                        continue
                    depth += 1 if line[i] == "(" else -1 if line[i] == ")" else 0
                    i += 1
                cur = stack.pop()
                cur["text"] += HOLE
                continue
            cur["text"] += {"n": "\n", "t": "\t", '"': '"', "\\": "\\", "0": "\0", "'": "'"}.get(pair[1:], pair)
            i += 2
            continue
        if character == '"':
            out.append(cur)
            cur, i = None, i + 1
            continue
        cur["text"] += character
        i += 1
    return out

def shown_in(text: str) -> list[str]:
    """Every word a person is shown in one file, in the order it appears."""
    found, seen = [], set()
    for line in text.split("\n"):
        if line.lstrip().startswith("//"):
            continue
        for pattern in SHOWN:
            for word in re.findall(pattern, line):
                # What Swift writes as an escape is one character when the app runs, and that is
                # what the key must be: "Every matter.\nIn its place." holds a real new line.
                word = word.replace("\\n", "\n").replace("\\t", "\t").replace('\\"', '"').replace("\\\\", "\\")
                if word in seen or not word.strip():
                    continue
                # A key, a name or a symbol is stored or drawn, never read: "app.starts", "doc.fill".
                if re.fullmatch(r"[a-z0-9]+(\.[a-zA-Z0-9]+)+", word):
                    continue
                # A word with a value in it: Xcode writes its key itself, with the right placeholder
                # for the value's type ("Next: %@"), which only the compiler knows.
                if "\\(" in word:
                    continue
                seen.add(word)
                found.append(word)
    return found

def from_build(folders: list[str]) -> list[str]:
    """What Xcode found when it last built: a word with a value in it ("Next: %@"), whose
    placeholder only the compiler knows. Pass --build <derived data> to take them in."""
    where = sys.argv[sys.argv.index("--build") + 1] if "--build" in sys.argv else None
    if not where:
        return []
    names = {"Sources/Causabee": "Causabee.build", "Sources/CausabeePhone": "Causabee.build",
             "Sources/CausabeeShare": "Causabee.build", "Sources/MatterCore": "MatterCore"}
    wanted = {names[f] for f in folders if f in names}
    found = []
    for file in sorted(pathlib.Path(where).rglob("*.stringsdata")):
        if not any(name in str(file) for name in wanted):
            continue
        try:
            book = json.loads(file.read_text(encoding="utf-8"))
        except Exception:
            continue
        for table, entries in book.get("tables", {}).items():
            if table != "Localizable":
                continue
            for entry in entries:
                key = entry.get("key", "")
                if key and "%" in key and key not in found:
                    found.append(key)
    return found

def words(folders: list[str]) -> list[str]:
    found, seen = [], set()
    for folder in folders:
        for file in sorted((ROOT / folder).rglob("*.swift")):
            for word in shown_in(file.read_text(encoding="utf-8")):
                if word not in seen:
                    seen.add(word)
                    found.append(word)
    return found

def listing() -> int:
    """Every word, in both languages, under the screen it is on — for the owner to read before the
    gate. The file a word is shown from is the nearest thing the code knows to a screen."""
    said = {}
    for catalogue, _, _ in PLACES:
        for key, entry in read(ROOT / catalogue).get("strings", {}).items():
            said[key] = german_of(entry)[0]
    where: dict[str, list[str]] = {}
    for _, folders, _ in PLACES:
        for folder in folders:
            for file in sorted((ROOT / folder).rglob("*.swift")):
                name = str(file.relative_to(ROOT))
                if name in NOT_READ:
                    continue
                shown = [w for w in shown_in(file.read_text(encoding="utf-8")) if w in said]
                if shown:
                    where[name] = shown
    print("# Causabee's words, English and German\n")
    print(f"{len(said)} words in all. The file each one is shown from stands for its screen; a word")
    print("shown on more than one screen is under the first of them.\n")
    seen = set()
    for name in sorted(where, key=lambda n: (0 if "MatterCore" in n else 1, n)):
        mine = [w for w in where[name] if w not in seen]
        if not mine:
            continue
        seen |= set(mine)
        print(f"\n## {name}\n")
        print("| English | German |")
        print("|---|---|")
        for word in mine:
            def cell(text: str) -> str:
                return text.replace("|", "\\|").replace("\n", " ⏎ ").strip()
            print(f"| {cell(word)} | {cell(said[word])} |")
    left = sorted(set(said) - seen)
    if left:
        print("\n## Words the code picks as it runs, and words with a value in them\n")
        print("| English | German |")
        print("|---|---|")
        for word in left:
            print(f"| {word.replace('|', chr(92) + '|').replace(chr(10), ' ⏎ ')} "
                  f"| {said[word].replace('|', chr(92) + '|').replace(chr(10), ' ⏎ ')} |")
    return 0

def extra() -> list[str]:
    """Words the code picks as it runs, named in scripts/words-extra.txt: no line holds them, so
    nothing but this list keeps them in the catalogue."""
    file = ROOT / "scripts" / "words-extra.txt"
    if not file.exists():
        return []
    return [line.rstrip("\n") for line in file.read_text(encoding="utf-8").split("\n")
            if line.strip() and not line.startswith("#")]

def kept(tag: str) -> list[str]:
    """The words with a value that a build found before, as scripts/words-values.txt holds them."""
    file = ROOT / VALUES
    if not file.exists():
        return []
    found = []
    for line in file.read_text(encoding="utf-8").split("\n"):
        if not line.strip() or line.startswith("#") or "\t" not in line:
            continue
        where, key = line.split("\t", 1)
        if where == tag:
            found.append(json.loads(key))
    return found

def keep(found: dict[str, list[str]]) -> None:
    """Write back what the builds know, so a run without one keeps every word that carries a value."""
    lines = ["# The words that carry a value, as Xcode's own build named them: scripts/words.py",
             "# --build <derived data> writes them here. Not by hand — the placeholder must be the",
             "# one the compiler chose (%@ for words, %lld for numbers), or the app finds no German.",
             "# Each line: where it belongs, a tab, and the word as JSON writes it."]
    for tag in sorted(found):
        for key in sorted(found[tag]):
            lines.append(f"{tag}\t" + json.dumps(key, ensure_ascii=False))
    (ROOT / VALUES).write_text("\n".join(lines) + "\n", encoding="utf-8")

def machine() -> set[tuple[str, str]]:
    """What was looked at and is not a word a person reads: (file, the literal)."""
    file = ROOT / MACHINE
    if not file.exists():
        return set()
    out = set()
    for line in file.read_text(encoding="utf-8").split("\n"):
        if not line.strip() or line.startswith("#") or "\t" not in line:
            continue
        where, literal = line.split("\t", 1)
        out.add((where, json.loads(literal)))
    return out

def skeleton(text: str) -> str:
    """The same words with every value taken out, so a literal with a hole in it can be compared
    with the key Xcode named for it: "Sort in ⟦⟧" and "Sort in %@" are one word."""
    return re.sub(r"%(?:[0-9]+\$)?(?:lld|ld|d|@|lf|f)", "\u0001", text)

def could_be_words(text: str) -> bool:
    """Reads like something a person could be shown: two words, or one capitalised word."""
    said = text.replace(HOLE, " ").strip()
    if not re.search(r"[A-Za-zÄÖÜäöüß]{3}", said):
        return False
    if " " not in said and not re.fullmatch(r"[A-ZÄÖÜ][a-zäöüß]{2,}", said):
        return False
    # A key, a name, a symbol or a path: stored or drawn, never read.
    return not re.fullmatch(r"[a-z0-9_]+([.\-/][a-zA-Z0-9_]+)+", said)

# The parts that look a word up by themselves: SwiftUI does it for its own, and `String(localized:)`
# is ours. What stands right before the literal says so — and a word with a value in it is Xcode's
# to name, which is why `--build` writes those keys down.
LOOKS_ITSELF_UP = re.compile(
    r"(String\(localized:|\b(Text|Button|Label|Toggle|TextField|Section|Picker|Stepper|Link|Alert)\(|"
    r"\.(help|accessibilityLabel|accessibilityHint|navigationTitle|alert|alertWhenAsked|confirmationDialog)\(|"
    r"\b(BeeChip|EmptyBox)\(text:|\bSectionHeader\(title:)\s*$")

# Parts of ours that take a plain String and draw it as it is: SwiftUI looks nothing up for them,
# so a bare literal here is never looked up, however much it reads like a word. The net names one
# even when the catalogue happens to hold it, because nothing would ever read it from there (F009).
TAKES_A_WORD = re.compile(
    r"(\b(BeeChip|EmptyBox|PhoneEmptyBox)\(text:|\bSectionHeader\(title:|\.(alertWhenAsked|confirmationDialogWhenAsked)\(|"
    r"\bSheetConfirm\(title:|\bJournalHeading\(title:)\s*$")

# A line that shows nothing: what it says goes to a log, a key, a symbol or the system.
SHOWS_NOTHING = re.compile(
    r"\b(print|fatalError|assertionFailure|precondition|Logger|os_log|systemName|forKey|"
    r"removeObject|withExtension|UTType|Notification\.Name|setValue|addingPercentEncoding)\b")

def escaped() -> int:
    """Every literal in the sources that reads like words a person is shown and is in neither
    catalogue nor the machine list. `--write` writes what is found into the machine list, to say
    these were looked at; without it, the count is the answer and anything found is named."""
    keys = set()
    for catalogue, _, _ in PLACES:
        keys |= set(read(ROOT / catalogue).get("strings", {}).keys())
    keys |= set(extra())
    for tag in ("core", "app"):
        keys |= set(kept(tag))
    # A word with a value in it is compared without its value: the literal has a hole where the
    # key has %@, and only the compiler knows which placeholder it chose.
    shapes = {skeleton(key) for key in keys if "%" in key}
    allowed, found, seen = machine(), [], set()
    for folder in sorted({f for _, folders, _ in PLACES for f in folders}):
        for file in sorted((ROOT / folder).rglob("*.swift")):
            where = str(file.relative_to(ROOT))
            if where in NOT_READ:
                continue
            inside = False
            for number, line in enumerate(file.read_text(encoding="utf-8").split("\n"), 1):
                if line.count('"""') == 1:
                    inside = not inside
                    continue
                if inside or line.strip().startswith("//") or SHOWS_NOTHING.search(line):
                    continue
                for literal in literals(line):
                    word = literal["text"]
                    if not could_be_words(word):
                        continue
                    # A part that takes a plain String: the literal is a mistake, key or not.
                    takes = TAKES_A_WORD.search(line[:literal["at"]]) is not None
                    if not takes and (word in keys or (HOLE in word and word in shapes)):
                        continue
                    if not takes and LOOKS_ITSELF_UP.search(line[:literal["at"]]):
                        continue
                    if (where, word) in allowed or (where, word) in seen:
                        continue
                    seen.add((where, word))
                    found.append((where, number, word))
    if "--write" in sys.argv:
        lines = ["# Every literal in the sources that reads like words a person could be shown and",
                 "# is not one: a key, a symbol, a mark in a mail, something a model is told. Each was",
                 "# looked at once. `scripts/words.py --escaped` names anything new, and the test",
                 '"F009 AC-1 · No word a person reads escapes the catalogue" fails while one is left.',
                 "# Each line: the file, a tab, and the literal as JSON writes it."]
        for where, word in sorted(allowed | seen):
            lines.append(f"{where}\t" + json.dumps(word, ensure_ascii=False))
        (ROOT / MACHINE).write_text("\n".join("# " + l[1:] if l.startswith('"') else l for l in lines) + "\n", encoding="utf-8")
        print(f"{MACHINE}: {len(allowed | seen)} literals that are not words")
        return 0
    for where, number, word in found:
        print(f"{where}:{number}  {word.replace(HOLE, '⟦value⟧')!r}")
    print(f"{len(found)} literals read like words a person is shown and are in no catalogue")
    return 1 if found else 0

def read(path: pathlib.Path) -> dict:
    if not path.exists():
        return {"sourceLanguage": "en", "strings": {}, "version": "1.0"}
    return json.loads(path.read_text(encoding="utf-8"))

def german_of(entry: dict) -> tuple[str, str]:
    unit = entry.get("localizations", {}).get("de", {}).get("stringUnit", {})
    return unit.get("value", ""), unit.get("state", "")

def main() -> int:
    if "--escaped" in sys.argv:
        return escaped()
    if "--list" in sys.argv:
        return listing()
    only_missing = "--missing" in sys.argv
    built = "--build" in sys.argv
    missing_all, added_all, values = 0, 0, {}
    # One catalogue alone: `--only core` or `--only app`, for while the other's files are in hand.
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None
    for catalogue, folders, tag in PLACES:
        if only and only != tag:
            continue
        path = ROOT / catalogue
        book = read(path)
        strings = book.setdefault("strings", {})
        found = words(folders)
        # A word that carries a value: what this build found, and what earlier builds wrote down.
        values[tag] = sorted(set(from_build(folders) + kept(tag))) if built else kept(tag)
        with_value = (values[tag] + (extra() if "MatterCore" in catalogue else []))
        found = found + [w for w in with_value if w not in found]
        added = [word for word in found if word not in strings]
        for word in added:
            strings[word] = {"localizations": {}}
        missing = [word for word in found if not german_of(strings.get(word, {}))[0].strip()]
        missing_all += len(missing)
        added_all += len(added)
        if only_missing:
            print(f"{catalogue}: {len(found)} words, {len(missing)} without German")
            for word in missing[:40]:
                print("   ", word)
            if len(missing) > 40:
                print(f"    … and {len(missing) - 40} more")
        else:
            # No line shows it any more. Its German took work and a line can come back — a file in
            # hand for a minute, a word moved — so it is kept and counted, and `--prune` drops it.
            stale = [w for w in strings if w not in found]
            kept_stale = [] if "--prune" in sys.argv else [w for w in stale if german_of(strings[w])[0].strip()]
            for word in stale:
                if word not in kept_stale:
                    del strings[word]
            book["strings"] = {word: strings[word] for word in found + kept_stale}
            path.write_text(json.dumps(book, ensure_ascii=False, indent=2, sort_keys=False) + "\n", encoding="utf-8")
            print(f"{catalogue}: {len(found)} words, {len(added)} new, {len(missing)} without German"
                  + (f", {len(kept_stale)} no line shows any more (--prune drops them)" if kept_stale else ""))
    if built and not only_missing:
        keep(values)
        print(f"{VALUES}: {sum(len(v) for v in values.values())} words that carry a value")
    return 1 if only_missing and missing_all else 0

if __name__ == "__main__":
    sys.exit(main())
