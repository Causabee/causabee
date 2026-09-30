import Foundation
import MatterCore

/// A page for the owner to judge two models' to-dos without knowing which is which: the mail
/// as the models read it, two lists as A and B in a random order, four buttons. It needs no script:
/// the choices are radio buttons, and the page's style counts them and shows the answer once every
/// mail is judged — so it works in a viewer that runs none.
enum BlindPage {
    struct Side { var model: String; var todos: [String]; var dates: [String] }

    /// `choosingBy`: the record the mails were chosen by the first time, so a second page with a
    /// changed model shows the very same mails in the same order.
    static func html(cases: [BenchCase], other: [String: Judgement], otherName: String, count: Int,
                     choosingBy: [String: Judgement]? = nil) -> String {
        var generator = Seeded(seed: 20260928)
        func side(_ model: String, _ judgement: Judgement) -> Side {
            Side(model: model,
                 todos: judgement.todos.map { todo in
                     let whose = ["me": "ich", "we": "wir", "other": "andere"][todo.owner.rawValue] ?? "unklar"
                     return "\(todo.text) — \(whose)" + (todo.due.map { ", bis \($0)" } ?? "")
                 },
                 dates: judgement.appointments.map { "\($0.date)\($0.time.map { " \($0)" } ?? "") \($0.what)" }
                     + judgement.deadlines.map { "bis \($0.date): \($0.what)" })
        }
        // Mails where the two differ and at least one has something to do, in a fixed random order.
        let chooser = choosingBy ?? other
        let candidates = cases.compactMap { item -> (BenchCase, Side, Side)? in
            guard let first = chooser[item.id], first.extraction != nil else { return nil }
            let a = side("Opus", item.opus), b = side(otherName, first)
            guard !(a.todos.isEmpty && b.todos.isEmpty), a.todos != b.todos else { return nil }
            return (item, a, b)
        }
        var picked = candidates
        picked.shuffle(using: &generator)
        let chosen = picked.prefix(count).compactMap { item, a, _ -> (BenchCase, Side, Side)? in
            guard let theirs = other[item.id] else { return nil }
            return (item, a, side(otherName, theirs))
        }

        func esc(_ text: String) -> String {
            text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
        }
        func list(_ side: Side) -> String {
            var out = side.todos.isEmpty ? "<p class=none>Keine Aufgaben</p>" : "<ol>" + side.todos.map { "<li>\(esc($0))</li>" }.joined() + "</ol>"
            if !side.dates.isEmpty { out += "<p class=dates>Termine und Fristen: " + side.dates.map(esc).joined(separator: " · ") + "</p>" }
            return out
        }
        // Which model a choice counts for, as a class the page's own style counts: no script needed,
        // so it works where scripts do not run.
        func key(_ model: String) -> String { model.lowercased().filter(\.isLetter) }
        let other = key(otherName)
        // A second page shows the same mails, but A and B fall anew, so memory of the first page
        // tells nothing.
        var sides = choosingBy == nil ? generator : Seeded(seed: 20260929)
        var cards = ""
        for (index, (item, opus, theirs)) in chosen.enumerated() {
            let opusFirst = Bool.random(using: &sides)
            let (a, b) = opusFirst ? (opus, theirs) : (theirs, opus)
            let date = item.date.map { MatterStatus.day($0) } ?? ""
            cards += """
            <section class=mail data-id="\(index)" data-a="\(esc(a.model))" data-b="\(esc(b.model))">
              <div class=head><span class=n>\(index + 1) / \(chosen.count)</span> <b>\(esc(item.subject))</b> <span class=d>\(date)</span></div>
              <details><summary>Die Mail, wie beide sie gelesen haben</summary><pre>\(esc(String(item.text.prefix(4000))))</pre></details>
              <div class=sides><div class=side><h3>A</h3>\(list(a))</div><div class=side><h3>B</h3>\(list(b))</div></div>
              <div class=pick>
                <input type=radio name=m\(index) id=m\(index)a class=\(key(a.model))><label for=m\(index)a>A ist besser</label>
                <input type=radio name=m\(index) id=m\(index)b class=\(key(b.model))><label for=m\(index)b>B ist besser</label>
                <input type=radio name=m\(index) id=m\(index)s class=same><label for=m\(index)s>Gleich gut</label>
                <input type=radio name=m\(index) id=m\(index)x class=bad><label for=m\(index)x>Beide schlecht</label>
              </div>
            </section>
            """
        }
        return """
        <!doctype html><html lang=de><meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1">
        <title>Blind vergleichen</title>
        <style>
        :root{--bg:#f6f5f2;--card:#fff;--ink:#1f1f1f;--muted:#6b6b6b;--line:#e2dfd8;--accent:#b8870a;--pick:#2e7d32}
        @media (prefers-color-scheme:dark){:root{--bg:#1c1c1e;--card:#2a2a2c;--ink:#eee;--muted:#a0a0a0;--line:#3a3a3c;--accent:#e0b040;--pick:#6fcf73}}
        body{background:var(--bg);color:var(--ink);font:15px/1.45 -apple-system,system-ui,sans-serif;margin:0;padding:24px 16px}
        main{max-width:1000px;margin:0 auto}h1{font-size:22px;margin:0 0 4px}.lead{color:var(--muted);margin:0 0 20px}
        .mail{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:16px;margin:0 0 16px}
        .head{margin-bottom:8px}.n{color:var(--accent);font-weight:600;margin-right:6px}.d{color:var(--muted);font-size:13px;margin-left:6px}
        details{margin:6px 0 12px}summary{cursor:pointer;color:var(--muted);font-size:13px}
        pre{white-space:pre-wrap;font:13px/1.4 ui-monospace,monospace;background:var(--bg);padding:10px;border-radius:8px;max-height:320px;overflow:auto}
        .sides{display:grid;grid-template-columns:1fr 1fr;gap:12px}@media(max-width:700px){.sides{grid-template-columns:1fr}}
        .side{border:1px solid var(--line);border-radius:10px;padding:10px 12px}.side h3{margin:0 0 6px;font-size:14px;color:var(--accent)}
        ol{margin:0;padding-left:20px}li{margin:3px 0}.none{color:var(--muted);margin:0}.dates{color:var(--muted);font-size:13px;margin:8px 0 0}
        .pick{display:flex;flex-wrap:wrap;gap:8px;margin-top:12px}
        .pick input{position:absolute;opacity:0;width:1px;height:1px}
        .pick label{padding:8px 12px;border-radius:8px;border:1px solid var(--line);background:var(--bg);cursor:pointer;-webkit-user-select:none;user-select:none}
        .pick input:checked+label{border-color:var(--pick);color:var(--pick);font-weight:600;background:var(--card)}
        .pick input:checked+label::before{content:"✓ "}
        .mail:has(input:checked){border-color:var(--pick)}
        main{counter-reset:opus \(other) same bad done}
        input.opus:checked{counter-increment:opus done}input.\(other):checked{counter-increment:\(other) done}
        input.same:checked{counter-increment:same done}input.bad:checked{counter-increment:bad done}
        #bar{position:sticky;bottom:0;background:var(--card);border:1px solid var(--line);border-radius:12px;padding:10px 14px;margin-top:8px;box-shadow:0 -2px 12px rgba(0,0,0,.08)}
        #bar .done::before{content:counter(done)}
        #result{display:none;margin-top:6px;color:var(--pick);font-weight:600}
        #show{position:absolute;opacity:0;width:1px;height:1px}
        #bar label[for=show]{display:inline-block;margin-left:10px;padding:4px 10px;border-radius:8px;border:1px solid var(--line);cursor:pointer}
        #show:checked~#result{display:block}#show:checked+label{display:none}
        #result .o::after{content:counter(opus)}#result .m::after{content:counter(\(other))}
        #result .s::after{content:counter(same)}#result .x::after{content:counter(bad)}
        </style>
        <main>
        <h1>Welche Aufgaben passen besser?</h1>
        <p class=lead>Zwei Modelle haben dieselben Mails gelesen. Welches A und welches B ist, wechselt und bleibt verborgen, bis alles bewertet ist. Achte darauf: fehlt etwas Wichtiges, ist etwas überflüssig oder falsch, stimmt „wessen“ und das Datum?</p>
        \(cards)
        <div id=bar><b class=done></b> von \(chosen.count) bewertet
          <input type=checkbox id=show><label for=show>Ergebnis zeigen</label>
          <div id=result>Ergebnis — Opus: <span class=o></span> · \(esc(otherName)): <span class=m></span> · Gleich gut: <span class=s></span> · Beide schlecht: <span class=x></span></div>
        </div>
        </main>
        </html>
        """
    }
}

/// The same order on every run, so the page can be made again and match.
struct Seeded: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
