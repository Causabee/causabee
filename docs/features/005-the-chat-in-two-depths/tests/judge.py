"""F005 AC-7: Claude Fable 5.2 reads today's answer and the two-depth answer blind, where they differ.

Each pair is judged twice, A and B swapped, so the order cannot decide. Invented demo matters only.
Usage: judge.py <tests folder> <out.json>
"""
import json
import re
import sys

import anthropic

tests, out = sys.argv[1], sys.argv[2]
today = {c["id"]: c for c in json.load(open(f"{tests}/answers/today.json"))}
depths = {c["id"]: c for c in json.load(open(f"{tests}/answers/two-depths.json"))}
pairs = [("q02", 0), ("q04", 0), ("q07", 0), ("q09", 0), ("q10", 0), ("q10", 1)]

SYSTEM = """You judge an assistant that helps one person keep track of their matters: what came in, tasks, dates, people.
You are shown everything the assistant could see of the matter, the person's question, and two answers, A and B.
Each answer has lines of text and may offer cards: actions the person can take with one tap (a new task, a date change, marking a task done, a note).

Decide whether one answer is worse for the person. Worse means: something in it is wrong; it leaves out something the person needs for this question; or a card is wrong, missing where it was clearly needed, or would do harm (a duplicate task, an empty card).
Not worse: other wording, another order, a little more or less detail that changes nothing for the person, or a different card that is just as good.
If neither is worse, say so. Judge only from the facts shown."""

SCHEMA = {
    "type": "object",
    "properties": {
        "worse": {"type": "string", "enum": ["A", "B", "neither"]},
        "why": {"type": "string"},
    },
    "required": ["worse", "why"],
    "additionalProperties": False,
}


def shown(turn):
    lines = [re.sub(r"\s*\[[A-Z][0-9]+(?: [A-Z][0-9]+)*\]\s*$", "", line) for line in turn["lines"]]
    text = "\n".join(f"- {line}" for line in lines) or "- (no lines)"
    for card in turn["cards"]:
        text += f"\n- Card: {card['kind'].replace('_', ' ')}{' · due ' + card['due'] if card.get('due') else ''} — \"{card.get('text', '')}\""
    if turn.get("notInFacts"):
        text += f"\n- Says is not in the matter: {turn['notInFacts']}"
    return text


client = anthropic.Anthropic()
facts = today["q02"]["turns"][0]["factsShown"]
results, cost = [], 0.0
for cid, n in pairs:
    a, b = today[cid]["turns"][n], depths[cid]["turns"][n]
    question = a["question"] + (" (a follow-up to \"What's next?\")" if n else "")
    for order in (("today", "two depths"), ("two depths", "today")):
        answer = {"today": a, "two depths": b}
        message = client.messages.create(
            model="claude-fable-5-2",
            max_tokens=4000,
            system=SYSTEM,
            output_config={"effort": "medium", "format": {"type": "json_schema", "schema": SCHEMA}},
            messages=[{"role": "user", "content": [
                {"type": "text", "text": "<matter>\n" + facts + "\n</matter>", "cache_control": {"type": "ephemeral"}},
                {"type": "text", "text": f"<question>{question}</question>\n\n<answer_a>\n{shown(answer[order[0]])}\n</answer_a>\n\n<answer_b>\n{shown(answer[order[1]])}\n</answer_b>"},
            ]}],
        )
        if message.stop_reason == "refusal":
            print(f"{cid}{'b' if n else ''}: refused")
            continue
        verdict = json.loads(next(block.text for block in message.content if block.type == "text"))
        worse = {"A": order[0], "B": order[1]}.get(verdict["worse"], "neither")
        u = message.usage
        spent = (u.input_tokens * 8 + (u.cache_creation_input_tokens or 0) * 10 + (u.cache_read_input_tokens or 0) * 0.2 + u.output_tokens * 40) / 1e6
        cost += spent
        results.append({"case": cid + ("b" if n else ""), "question": question, "a_was": order[0], "worse": worse, "why": verdict["why"], "cost": round(spent, 4)})
        print(f"{cid}{'b' if n else ''} (A = {order[0]}): worse = {worse} · ${spent:.3f}")
json.dump({"model": "claude-fable-5-2", "effort": "medium", "cost": round(cost, 3), "verdicts": results}, open(out, "w"), indent=2, ensure_ascii=False)
print(f"total ${cost:.3f}")
