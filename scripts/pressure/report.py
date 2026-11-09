"""Builds docs/message-pressure-test.md from the recorded rounds. Run with python3 -I."""
import json, re, sys, os

SP = sys.argv[1]
OUT = sys.argv[2]
SHOTS = sys.argv[3] if len(sys.argv) > 3 else None

cases = {c["id"]: c for c in json.load(open(os.path.join(SP, "cases.json")))}
r1 = {c["id"]: c for c in json.load(open(os.path.join(SP, "results-round1.json")))}
r3 = {c["id"]: c for c in json.load(open(os.path.join(SP, "results.json")))}

def entry_lines(facts):
    return [l for l in facts.split("\n") if re.match(r"^E\d+ ", l)]

def party_line(facts, pid):
    if not pid or not re.match(r"^P\d+$", pid):
        return None
    for l in facts.split("\n"):
        if l.startswith(pid + " "):
            return l
    return None

def in_hand_line(facts, title):
    if not title:
        return None
    for l in entry_lines(facts):
        if title.lower() in l.lower():
            return l
    return None

def register(line):
    m = re.search(r'written: opens "([^"]*)", closes "([^"]*)"', line or "")
    return (m.group(1), m.group(2)) if m else (None, None)

def lang(text):
    de = len(re.findall(r"\b(der|die|das|und|ist|bitte|Hallo|Grüße|wir|ich|nicht|Sie|du)\b", text))
    en = len(re.findall(r"\b(the|and|is|please|Hello|Hi|regards|we|I|not|you|Dear)\b", text))
    return "German" if de > en else "English" if en > de else "?"

def checks(card, facts, in_hand):
    out = []
    text = card.get("text", "")
    lines = [l for l in text.split("\n") if l.strip()]
    greet = lines[0] if lines else ""
    sign = " / ".join(lines[-2:]) if len(lines) >= 2 else ""
    opens, closes = register(in_hand_line(facts, in_hand) or "")
    if opens:
        out.append(f"Their mail opens “{opens}”, closes “{closes}” — the draft opens “{greet}”, closes “{sign}”.")
        out.append("Language: theirs " + lang(opens + " " + closes) + ", the draft " + lang(text) + ".")
    leaks = re.findall(r"\[(?:Person|Company|Place|Email|Street|Phone|Link)[^\]]*\]", json.dumps(card, ensure_ascii=False))
    out.append("Stand-ins left: " + (", ".join(leaks) if leaks else "none") + ".")
    party = card.get("party")
    pl = party_line(facts, party)
    out.append("Goes to: " + (pl.split(" — mail")[0][len(party) + 1:] if pl else (party or "— none —")) + ".")
    if re.search(r"\b\w+ \w+[!,]?$", greet) and any(w and w[0].isupper() for w in greet.split()[1:3]) and len(greet.split()) >= 3:
        out.append("Greeting by first and last name — " + ("not as people write" if len(greet.rstrip(",!").split()) >= 3 else "fine") + ".")
    if card.get("attach"):
        out.append("Takes along: " + card["attach"] + ".")
    out.append(f"Length: {len(text.split())} words.")
    return out

def card_md(card):
    rows = []
    kind = {"draft_message": "Mail draft", "short_message": "Short message"}.get(card["kind"], card["kind"])
    head = f"**{kind}**"
    if card.get("subject"):
        head += f" · Subject: {card['subject']}"
    rows.append(head)
    rows.append("")
    rows.append("```")
    rows.append(card.get("text", ""))
    rows.append("```")
    if card.get("reason"):
        rows.append(f"*Why, as the bee says:* {card['reason']}")
    return rows

md = []
md.append("# Writing messages with the bee — pressure test")
md.append("")
md.append("9 November 2026 · branch `glass-sidebar` · model **OpenAI GPT-6.1 Sol** (the product's only model), through the app's own pipeline: "
          "the facts of the matter with the words of what came in, everything disguised, the answer restored. "
          "Only the demo's invented matters were sent — no real names, no real mail.")
md.append("")
md.append("**How it was run.** `matter-spike pressure` asks each question exactly as the chat does (same facts, same rules, same disguise), "
          "and records what the bee was given, what went out, and what came back. Four rounds: round 1 on the code as it was, "
          "rounds 2–4 after each set of fixes below. The screenshots show the round-4 answers drawn by the iPhone app (demo, `-answers.recorded`).")
md.append("")
md.append("## What the test found, and what was changed")
md.append("")
md.append("| # | Found in round 1 | Cause | Fixed by | Round 4 |")
md.append("|---|---|---|---|---|")
md.append("| 1 | The recipient shown as a stand-in: “[Person B]”, “Ms. [Person C]”, “Registry Office [Place A]” | The card's `party` was never restored | `party` restored like every other field | none left |")
md.append("| 2 | Subjects garbled: “care level **For** Helga **Mara** Voss”, “Parking **For** the van?” | “For” learned as a company; “Voss” (part of the owner's name) disguised Helga's surname as the owner | Single common words are never names (old lists forget them); a surname after another first name is noted before disguising and comes back as itself | clean |")
md.append("| 3 | A change asked of a draft ignored: “unterschreib nur mit Mara” gave the same text | The earlier draft was sent to the bee cut at 80 characters; no rule said a change must change it | Earlier drafts go whole; rule: the same draft with exactly that change, same recipient and subject | applied |")
md.append("| 4 | Every reply “Hello, … Best regards, Mara Voss”, even to a close friend | The demo's mails were all written “Hello … Best regards”, so mirroring them was right — the test data was wrong | Demo senders write in their own voices: friends “Hi Mara! … See you soon”, firms “Hello Ms Voss … Kind regards”, offices “Dear Ms Voss … Yours sincerely” | mirrored |")
md.append("| 5 | The same reply in German once, in English once | No rule on which language | Rule: the language of the exchange, unless the owner names one | consistent |")
md.append("| 6 | “Mum is home from Monday” written to the care fund | The owner's shorthand copied | Rule: shorthand made clear to the reader (“my mother, Helga Voss”), with what identifies the case | applied |")
md.append("| 7 | (round 2) “Hello Autohaus Weber”, “Hello Trattoria Lume” | No rule on how to greet a firm | Rule: a firm without a person is greeted without a name | “Hello,” |")
md.append("| 8 | (round 2) A follow-up draft lost its recipient | — | Rule: same recipient and subject when changing a draft | kept |")
md.append("| 9 | (round 3) Still “Hi Tomás Ribeiro!”, “Hello Priya Raman” | The bee only ever sees a person as one tag for the whole name — it cannot write a first name alone | The bee writes `[Person A·first]` / `[Person A·last]`; the device puts in the first name or surname. No name leaves the device | “Hi Tomás!”, “Hello Mr Lindqvist” |")
md.append("")
md.append("Each rule is in `AssistantPrompt` (\"How the owner writes\") and in the manifesto, principle 13. The disguise fixes have tests: `DisguiseFindingsTests`.")
md.append("")
md.append("## The cases")
md.append("")
for cid in sorted(cases):
    c = cases[cid]
    a = r3.get(cid, {})
    b = r1.get(cid, {})
    md.append(f"### {cid} · {c['profile']}")
    md.append("")
    md.append(f"**Matter:** {c['matter']}" + (f" · **In hand:** “{c['inHand']}”" if c.get("inHand") else " · nothing in hand"))
    md.append("")
    for n, turn in enumerate(a.get("turns", [])):
        facts = turn["factsShown"]
        md.append(f"**You:** {turn['question']}")
        md.append("")
        ih = in_hand_line(facts, c.get("inHand")) if n == 0 else None
        if ih:
            md.append("<details><summary>What the bee was given about the mail in hand</summary>")
            md.append("")
            md.append("```")
            md.append(ih[:1200])
            md.append("```")
            md.append("</details>")
            md.append("")
        sent_q = re.search(r"<question>(.*?)</question>", turn["sent"], re.S)
        if sent_q:
            md.append(f"*Went out disguised as:* `{sent_q.group(1).strip()[:300]}`")
            md.append("")
        for line in turn["lines"]:
            md.append(f"> {line}")
        if turn.get("notInFacts"):
            md.append(f"> *Not in the facts:* {turn['notInFacts']}")
        if turn["lines"] or turn.get("notInFacts"):
            md.append("")
        for card in turn["cards"]:
            md += card_md(card)
            md.append("")
            md.append("Checks: " + " ".join(checks(card, facts, c.get("inHand"))))
            md.append("")
        if not turn["cards"]:
            md.append("No card: the bee asked first — a draft guesses nothing it is not given.")
            md.append("")
        if SHOTS and os.path.exists(os.path.join(SHOTS, f"{cid}-{n + 1}.png")):
            md.append(f"![{cid}-{n + 1}](message-pressure-test/{cid}-{n + 1}.png)")
            md.append("")
        md.append(f"*{turn['seconds']:.0f} s · ${turn['cost']:.3f}*")
        md.append("")
    old = [k for t in b.get("turns", []) for k in t["cards"]]
    if old:
        md.append("<details><summary>Round 1, for comparison</summary>")
        md.append("")
        for k in old:
            md.append("```")
            md.append(k.get("text", ""))
            md.append("```")
        md.append("</details>")
        md.append("")
md.append("## What is still open")
md.append("")
md.append("- The model does not always pick the greeting the rules ask for: “Hello,” to Priya (a person, who writes “Hello Ms Voss”), “Dear Sabine Ott”, “Hello Ravi” where “Hello Mr Nair” mirrors him. Rare, and the owner sees every draft before it goes; a check after the answer could correct it.")
md.append("- The model does not always pick the greeting the rules ask for: “Hello,” to Priya (a person, who writes “Hello Ms Voss”), “Dear Sabine Ott”, “Hello Ravi” where “Hello Mr Nair” mirrors him. Rare, and the owner sees the draft before it goes; a check after the answer could correct it.")
md.append("- The demo writes its mails in English while the owner asks in German; real mail is mostly German. The rules are the same; a German demo round would show German registers (du/Sie).")
md.append("- A draft goes to one person. Writing “to everyone” in a group gives a short message for the chat, or one draft each (case 19); a mail to several at once is not offered yet.")
md.append("- Attaching works by the file's name (cases 10, 20). In the demo the files do not exist, so the card says \u201cNot on this iPhone, attach by hand\u201d; with real mail the file is fetched from it first.")
md.append("- A link (the portfolio, case 12) is never sent to the bee, so it asks for it rather than guessing — by design (privacy), but the owner has it already.")
open(OUT, "w").write("\n".join(md) + "\n")
print("wrote", OUT)
