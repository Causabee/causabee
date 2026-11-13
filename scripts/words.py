#!/usr/bin/env python3
"""Causabee's words, in both languages (F009).

Reads the sources, finds every word a person is shown, and keeps the two String Catalogues up to
date — MatterCore's for the words all three devices share, the apps' for their own:

    python3 -I scripts/words.py            # add what is new, keep the German there is
    python3 -I scripts/words.py --missing  # say which words have no German yet

The English word is the key, as SwiftUI does it: `Text("Save")` looks up "Save". German is written
by hand into the catalogues and read by the owner before anything ships. A word that is only stored
— a UserDefaults key, a Keychain service, a folder's name — is never in here.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

# Where the words of each catalogue come from.
PLACES = [
    ("Sources/MatterCore/Resources/Localizable.xcstrings", ["Sources/MatterCore"]),
    ("App/Resources/Localizable.xcstrings", ["Sources/Causabee", "Sources/CausabeePhone", "Sources/CausabeeShare"]),
]

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
    r'\.help\("((?:[^"\\]|\\.)+)"',
    r'\.accessibilityLabel\("((?:[^"\\]|\\.)+)"',
    r'\.accessibilityHint\("((?:[^"\\]|\\.)+)"',
    r'\.navigationTitle\("((?:[^"\\]|\\.)+)"',
    r'\.alertWhenAsked\("((?:[^"\\]|\\.)+)"',
    r'\.confirmationDialog\("((?:[^"\\]|\\.)+)"',
]

def shown_in(text: str) -> list[str]:
    """Every word a person is shown in one file, in the order it appears."""
    found, seen = [], set()
    for line in text.split("\n"):
        if line.lstrip().startswith("//"):
            continue
        for pattern in SHOWN:
            for word in re.findall(pattern, line):
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

def words(folders: list[str]) -> list[str]:
    found, seen = [], set()
    for folder in folders:
        for file in sorted((ROOT / folder).rglob("*.swift")):
            for word in shown_in(file.read_text(encoding="utf-8")):
                if word not in seen:
                    seen.add(word)
                    found.append(word)
    return found

def read(path: pathlib.Path) -> dict:
    if not path.exists():
        return {"sourceLanguage": "en", "strings": {}, "version": "1.0"}
    return json.loads(path.read_text(encoding="utf-8"))

def german_of(entry: dict) -> tuple[str, str]:
    unit = entry.get("localizations", {}).get("de", {}).get("stringUnit", {})
    return unit.get("value", ""), unit.get("state", "")

def main() -> int:
    only_missing = "--missing" in sys.argv
    missing_all, added_all = 0, 0
    for catalogue, folders in PLACES:
        path = ROOT / catalogue
        book = read(path)
        strings = book.setdefault("strings", {})
        found = words(folders)
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
            # Gone from the code: dropped, so a word never outlives what shows it.
            for word in [w for w in strings if w not in found]:
                del strings[word]
            book["strings"] = {word: strings[word] for word in found}
            path.write_text(json.dumps(book, ensure_ascii=False, indent=2, sort_keys=False) + "\n", encoding="utf-8")
            print(f"{catalogue}: {len(found)} words, {len(added)} new, {len(missing)} without German")
    return 1 if only_missing and missing_all else 0

if __name__ == "__main__":
    sys.exit(main())
