#!/usr/bin/env python3
"""F004 AC-3: compares what `matter-spike jobs` wrote — each job on the table's model and on the
model it may move to — against the bar the owner approved:

- reading: every item in the same matter as Sol, at least 95% of Sol's tasks and dates, none invented;
- digests: the same facts as Sol's, nothing invented;
- the brief: both, as A and B in a random order, for the owner to judge blind; the key apart.

    scripts/jobs-report.py <run folder> <report folder> [--key <file for the blind key>]

Writes `read.md`, `digest.md`, `briefs-blind.md` and `summary.json` into the report folder.
Only the demo's invented matters are in a run.
"""
import difflib
import json
import random
import re
import sys
from collections import defaultdict
from pathlib import Path

BASE = "gpt-6.1-sol"
NAMES = {"gpt-6.1-sol": "Sol", "gpt-6.1-terra": "Terra", "gpt-6-luna": "Luna"}


def words(text):
    return set(re.findall(r"[a-zà-ÿ0-9]+", text.lower())) - {"the", "a", "an", "to", "of", "for", "and", "on", "in", "at", "by", "with", "your", "my", "me"}


def same_task(a, b):
    """Two tasks are the same when they ask the same thing: most words shared, or near the same words."""
    wa, wb = words(a), words(b)
    if not wa or not wb:
        return a.strip().lower() == b.strip().lower()
    overlap = len(wa & wb) / min(len(wa), len(wb))
    return overlap >= 0.6 or difflib.SequenceMatcher(None, a.lower(), b.lower()).ratio() >= 0.7


def date_of(line):
    return line.split(" · ")[0].strip()


def matched(base, other, same):
    """How many of `base` have their like in `other`, and which of `other` have none in `base`."""
    used, found = set(), 0
    for item in base:
        for i, candidate in enumerate(other):
            if i not in used and same(item, candidate):
                used.add(i)
                found += 1
                break
    return found, [c for i, c in enumerate(other) if i not in used]


def by_model(rows):
    out = defaultdict(dict)
    for row in rows:
        out[row["model"]][row["item"]] = row
    return out


def money(rows):
    return round(sum(r.get("cost", 0) for r in rows), 4)


def read_report(rows, out):
    models = by_model(rows)
    base = models[BASE]
    summary, lines = {}, ["# F004 · Reading what comes in — Sol against the models it may move to", ""]
    for model, answers in models.items():
        lines += [f"## {NAMES.get(model, model)} ({model})", ""]
        placed_right = sum(1 for a in answers.values() if not a.get("error") and a.get("matter") == a.get("placed"))
        sent = [a for a in answers.values() if not a.get("error")]
        lines.append(f"- Items read: {len(sent)} of {len(answers)}; in the matter the demo puts them in: {placed_right}")
        lines.append(f"- Cost of the run: ${money(answers.values())}")
        if model == BASE:
            summary[model] = {"items": len(answers), "read": len(sent), "placedRight": placed_right, "cost": money(answers.values())}
            lines.append("")
            continue
        other_matter, task_found, task_all, date_found, date_all, extras, errors = [], 0, 0, 0, 0, [], []
        for item, sol in base.items():
            mine = answers.get(item)
            if not mine or mine.get("error") or sol.get("error"):
                if (mine or {}).get("error") != sol.get("error"):
                    errors.append((sol["title"], sol.get("error"), (mine or {}).get("error", "missing")))
                continue
            if mine.get("matter") != sol.get("matter"):
                other_matter.append((sol["title"], sol.get("placed"), sol.get("matter"), mine.get("matter")))
            f, extra_tasks = matched(sol["todos"], mine["todos"], same_task)
            task_found, task_all = task_found + f, task_all + len(sol["todos"])
            f, extra_dates = matched(sol["dates"], mine["dates"], lambda a, b: date_of(a) == date_of(b))
            date_found, date_all = date_found + f, date_all + len(sol["dates"])
            for e in extra_tasks:
                extras.append((sol["title"], "task", e, sol["todos"]))
            for e in extra_dates:
                extras.append((sol["title"], "date", e, sol["dates"]))
        share = (task_found + date_found) / max(1, task_all + date_all)
        summary[model] = {
            "items": len(answers), "read": len(sent), "placedRight": placed_right, "cost": money(answers.values()),
            "otherMatterThanSol": len(other_matter), "tasksOfSol": [task_found, task_all], "datesOfSol": [date_found, date_all],
            "shareOfSol": round(share, 4), "notInSol": len(extras), "errorsApart": len(errors),
            "meetsMatterBar": not other_matter and not errors, "meetsShareBar": share >= 0.95,
        }
        lines += [
            f"- **In another matter than Sol's: {len(other_matter)}** (bar: none)",
            f"- **Sol's tasks found: {task_found} of {task_all}; Sol's dates found: {date_found} of {date_all} — {share:.1%}** (bar: at least 95%)",
            f"- Found that Sol did not: {len(extras)} — each to be read against the item: a fact Sol missed, or invented (bar: none invented)",
            f"- Failed where Sol did not, or the other way: {len(errors)}",
            "",
        ]
        if other_matter:
            lines += ["### In another matter", "", "| Item | The demo's matter | Sol | This model |", "|---|---|---|---|"]
            lines += [f"| {t} | {p} | {s} | {m} |" for t, p, s, m in other_matter] + [""]
        if errors:
            lines += ["### Failed", "", "| Item | Sol | This model |", "|---|---|---|"]
            lines += [f"| {t} | {s} | {m} |" for t, s, m in errors] + [""]
        if extras:
            lines += ["### Found, but not by Sol", "", "| Item | Kind | This model | Sol's |", "|---|---|---|---|"]
            lines += [f"| {t} | {k} | {e} | {'; '.join(s) or '—'} |" for t, k, e, s in extras] + [""]
        missed = []
        for item, sol in base.items():
            mine = answers.get(item) or {}
            if sol.get("error") or mine.get("error"):
                continue
            _, left = matched(mine.get("todos", []), sol["todos"], same_task)
            missed += [(sol["title"], "task", x, mine.get("todos", [])) for x in left]
            _, left = matched(mine.get("dates", []), sol["dates"], lambda a, b: date_of(a) == date_of(b))
            missed += [(sol["title"], "date", x, mine.get("dates", [])) for x in left]
        if missed:
            lines += ["### Sol found, this model did not", "", "| Item | Kind | Sol | This model's |", "|---|---|---|---|"]
            lines += [f"| {t} | {k} | {x} | {'; '.join(m) or '—'} |" for t, k, x, m in missed] + [""]
    (out / "read.md").write_text("\n".join(lines) + "\n")
    return summary


def digest_report(rows, out):
    models = by_model(rows)
    base = models[BASE]
    others = [m for m in models if m != BASE]
    numbers = lambda t: set(n.replace(",", "").replace(".", "") for n in re.findall(r"\d(?:[\d.,:]*\d)?", t or ""))
    lines = ["# F004 · Digests — Sol's beside the models it may move to", "",
             "Each row: one mail, Sol's digest and each other's. A number or date in another digest that Sol's does not have is marked ⚑, to be read against the mail.", ""]
    summary = {BASE: {"items": len(base), "cost": money(base.values())}}
    flags = defaultdict(int)
    for item, sol in base.items():
        lines += [f"### {sol['title']}", "", f"- **Sol:** {sol.get('digest') or sol.get('error')}"]
        for m in others:
            mine = models[m].get(item, {})
            extra = numbers(mine.get("digest")) - numbers(sol.get("digest"))
            missing = numbers(sol.get("digest")) - numbers(mine.get("digest"))
            mark = (" ⚑ not in Sol's: " + ", ".join(sorted(extra))) if extra else ""
            mark += (" · Sol's, not here: " + ", ".join(sorted(missing))) if missing else ""
            if extra:
                flags[m] += 1
            lines.append(f"- **{NAMES.get(m, m)}:** {mine.get('digest') or mine.get('error')}{mark}")
        lines.append("")
    for m in others:
        summary[m] = {"items": len(models[m]), "cost": money(models[m].values()), "numbersNotInSol": flags[m],
                      "errors": sum(1 for r in models[m].values() if r.get("error"))}
    (out / "digest.md").write_text("\n".join(lines) + "\n")
    return summary


def brief_report(rows, out, key_file):
    models = by_model(rows)
    base = models[BASE]
    other = next(m for m in models if m != BASE)
    rng = random.Random()
    key, lines = {}, ["# F004 · Briefs, blind", "",
                      "For each matter, two briefs — A and B. One is GPT-6.1 Sol's, one is the model it may move to. Which is which is kept apart.",
                      "For each matter: is B worse than A, A worse than B, or neither?", ""]
    def block(r):
        part = [f"- {line}" for line in r.get("brief", [])]
        part += [f"- Summary: {' / '.join(r.get('summary', []))}"] if r.get("summary") else []
        part += [f"- Next step: {r.get('step')}" + (f" — {r['why']}" if r.get("why") else "")]
        return part if not r.get("error") else [f"- (failed: {r['error']})"]
    for n, (item, sol) in enumerate(sorted(base.items(), key=lambda kv: kv[1]["title"]), 1):
        mine = models[other].get(item, {})
        pair = [("sol", sol), ("other", mine)]
        rng.shuffle(pair)
        key[item] = {"A": pair[0][1]["model"], "B": pair[1][1]["model"]}
        lines += [f"## {n}. {sol['title']}", "", "**A**", ""] + block(pair[0][1]) + ["", "**B**", ""] + block(pair[1][1]) + [""]
    (out / "briefs-blind.md").write_text("\n".join(lines) + "\n")
    Path(key_file).write_text(json.dumps(key, indent=2, sort_keys=True) + "\n")
    return {m: {"matters": len(models[m]), "cost": money(models[m].values()), "errors": sum(1 for r in models[m].values() if r.get("error"))} for m in models}


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    run, out = Path(sys.argv[1]), Path(sys.argv[2])
    key_file = sys.argv[sys.argv.index("--key") + 1] if "--key" in sys.argv else str(run / "briefs-key.json")
    out.mkdir(parents=True, exist_ok=True)
    summary = {
        "read": read_report(json.loads((run / "read.json").read_text()), out),
        "digest": digest_report(json.loads((run / "digest.json").read_text()), out),
        "brief": brief_report(json.loads((run / "brief.json").read_text()), out, key_file),
    }
    (out / "summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(json.dumps(summary, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
