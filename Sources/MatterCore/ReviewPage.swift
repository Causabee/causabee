import Foundation

/// A page for reading the decision log by eye: each mail with what the model said, what the
/// golden set says, and exactly what was sent.
///
/// It is a local file and meant to stay one. It is made from real mail — the restored names, the
/// subjects, the labels — so it is written next to the log, gitignored, and opened in a browser
/// from disk. It has no scripts that fetch anything and loads nothing from the network.
public enum ReviewPage {
    public static func render(decisions: [Judgement], labels: [Label], title: String) -> String {
        let byFile = Dictionary(labels.map { ($0.file, $0) }, uniquingKeysWith: { first, _ in first })
        let classified = decisions.filter { $0.extraction != nil }
            .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        let cost = classified.compactMap { $0.extraction?.costUSD }.reduce(0, +)
        let failed = classified.filter { $0.extraction?.error != nil }.count
        let labelled = classified.filter { byFile[fileName($0)]?.isLabelled == true }.count
        let model = Set(classified.compactMap { $0.extraction?.model }).sorted().joined(separator: ", ")
        let prompt = Set(classified.compactMap { $0.extraction?.prompt }).sorted().joined(separator: ", ")

        var cards: [String] = []
        for decision in classified {
            cards.append(card(decision, label: byFile[fileName(decision)]))
        }

        return """
        <!doctype html>
        <html lang="de">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(escape(title))</title>
        <style>\(style)</style>
        </head>
        <body>
        <header>
          <h1>\(escape(title))</h1>
          <p class="meta">\(classified.count) mails classified · \(labelled) of them labelled · \
        \(escape(model)) · prompt \(escape(prompt)) · \(String(format: "$%.2f", cost))\(failed > 0 ? " · \(failed) failed" : "")</p>
          <p class="meta">Made from real mail. Local only — do not share or upload this file.</p>
          <nav>
            <label><input type="checkbox" id="only-labelled"> only mails with a label</label>
            <label><input type="checkbox" id="only-disagree"> only where matter differs</label>
          </nav>
        </header>
        <main>
        \(cards.joined(separator: "\n"))
        </main>
        <script>\(script)</script>
        </body>
        </html>
        """
    }

    static func fileName(_ decision: Judgement) -> String {
        URL(fileURLWithPath: decision.source).lastPathComponent
    }

    static func card(_ decision: Judgement, label: Label?) -> String {
        let isLabelled = label?.isLabelled == true
        let modelMatter = decision.matter?.lowercased()
        let labelMatter = label?.matter?.lowercased()
        // Names differ by design — the model makes up its own — so "differs" here only means one
        // side found a matter and the other did not.
        let disagrees = isLabelled && ((modelMatter == nil) != (labelMatter == nil))
        let extraction = decision.extraction

        var rows: [String] = []
        rows.append(row("matter",
                        model: decision.matter.map { "<b>\(escape($0))</b> <span class=dim>\(String(format: "%.2f", decision.matterConfidence))</span><div class=reason>\(escape(decision.matterReason))</div>" } ?? "<span class=dim>none</span><div class=reason>\(escape(decision.matterReason))</div>",
                        label: isLabelled ? (label?.matter.map { "<b>\(escape($0))</b>" } ?? "<span class=dim>none</span>") : nil))
        rows.append(row("parties",
                        model: list(decision.parties.map { "\(escape($0.name)) <span class=dim>\(escape($0.role))</span>" }),
                        label: isLabelled ? list(label?.parties.map { "\(escape($0.name)) <span class=dim>\(escape($0.role))</span>" } ?? []) : nil))
        rows.append(row("to-dos",
                        model: list(decision.todos.map { todo in
                            let again = todo.sameAs.map { " <span class=tag>again · \(escape($0))</span>" } ?? (todo.id.map { " <span class=dim>\(escape($0))</span>" } ?? "")
                            return "\(escape(todo.text)) <span class=tag>\(todo.owner.rawValue)</span>\(again)\(todo.due.map { " <span class=date>\(escape($0))</span>" } ?? "")<q>\(escape(todo.sourceQuote))</q>"
                        } + decision.done.map { "<span class=tag>done · \(escape($0.todo))</span><q>\(escape($0.sourceQuote))</q>" }),
                        label: isLabelled ? list(label?.todos.map { todo in
                            "\(escape(todo.text)) <span class=tag>\(todo.owner.rawValue)</span>\(todo.due.map { " <span class=date>\(escape($0))</span>" } ?? "")"
                        } ?? []) : nil))
        rows.append(row("deadlines",
                        model: list(decision.deadlines.map { "\(escape($0.what)) <span class=date>\(escape($0.date))</span><q>\(escape($0.sourceQuote))</q>" }),
                        label: isLabelled ? list(label?.deadlines.map { "\(escape($0.what)) <span class=date>\(escape($0.date))</span>" } ?? []) : nil))
        if !decision.appointments.isEmpty {
            rows.append(row("appointments", model: list(decision.appointments.map { appointment in
                "\(escape(appointment.what)) <span class=date>\(escape(appointment.date))\(appointment.time.map { " " + escape($0) } ?? "")</span>"
                    + (appointment.place.map { " <span class=dim>\(escape($0))</span>" } ?? "") + "<q>\(escape(appointment.sourceQuote))</q>"
            }), label: nil))
        }
        if isLabelled, let notes = label?.notes, !notes.isEmpty {
            rows.append("<tr><th>notes</th><td></td><td class=notes>\(escape(notes))</td></tr>")
        }

        let date = decision.date.map { ISO8601DateFormatter.string(from: $0, timeZone: .current, formatOptions: [.withFullDate]) } ?? ""
        let meta = extraction.map { extraction in
            var parts = [extraction.servedBy, "\(extraction.inputTokens) in / \(extraction.outputTokens) out",
                         String(format: "$%.4f", extraction.costUSD), String(format: "%.1f s", extraction.seconds)]
            if extraction.cached { parts.append("from cache") }
            if let skipped = extraction.skipped { return "not sent — " + escape(skipped) }
            if let asked = Claude.Model.named(extraction.model), !asked.isServing(extraction.servedBy) { parts.append("fallback") }
            if let omitted = extraction.historyOmitted, omitted > 0 { parts.append("\(omitted) characters of quoted history left out") }
            return parts.map(escape).joined(separator: " · ")
        } ?? ""
        let error = extraction?.error.map { "<p class=error>\(escape($0))</p>" } ?? ""
        let sent = decision.disguise.map { disguise in
            "From: \(disguise.from)\nTo: \(disguise.to.joined(separator: ", "))\nSubject: \(disguise.subject)\n\n\(disguise.body)"
        } ?? ""
        let skipped = decision.notDisguised.isEmpty ? "" :
            "<p class=dim>left alone: \(decision.notDisguised.map { escape($0.text) }.joined(separator: " · "))</p>"

        return """
        <article data-labelled="\(isLabelled)" data-disagree="\(disagrees)"\(disagrees ? " class=disagree" : "")>
          <h2><span class=date>\(escape(date))</span> \(escape(decision.subject))</h2>
          <p class=from>\(escape(decision.from))</p>
          \(error)
          <table>
            <thead><tr><th></th><th>model</th><th>\(isLabelled ? "your label" : "<span class=dim>not labelled</span>")</th></tr></thead>
            <tbody>\(rows.joined())</tbody>
          </table>
          <details><summary>what was sent to Claude</summary><pre>\(escape(sent))</pre>\(skipped)</details>
          <p class=meta>\(meta)</p>
        </article>
        """
    }

    static func row(_ name: String, model: String, label: String?) -> String {
        "<tr><th>\(name)</th><td>\(model)</td><td>\(label ?? "")</td></tr>"
    }

    static func list(_ items: [String]) -> String {
        items.isEmpty ? "<span class=dim>—</span>" : "<ul>" + items.map { "<li>\($0)</li>" }.joined() + "</ul>"
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    static let style = """
    :root { --bg:#fbfaf7; --card:#fff; --ink:#1d1d1b; --dim:#7a766e; --line:#e6e2da; --accent:#8a5a00;
            --warn:#fff4e0; --bad:#b3261e; --quote:#f3f0ea; }
    @media (prefers-color-scheme: dark) {
      :root { --bg:#161513; --card:#1f1e1b; --ink:#ece9e2; --dim:#9b968c; --line:#34322d; --accent:#e0b060;
              --warn:#3a2f18; --bad:#ff8a80; --quote:#2a2825; }
    }
    * { box-sizing:border-box; }
    body { margin:0; background:var(--bg); color:var(--ink); font:15px/1.45 -apple-system, system-ui, sans-serif; }
    header { padding:24px 16px 8px; max-width:1100px; margin:0 auto; }
    h1 { font-size:22px; margin:0 0 4px; }
    nav { display:flex; gap:20px; flex-wrap:wrap; margin:12px 0 4px; }
    main { max-width:1100px; margin:0 auto; padding:0 16px 48px; }
    article { background:var(--card); border:1px solid var(--line); border-radius:10px; padding:14px 16px; margin:14px 0; }
    article.disagree { border-color:var(--accent); box-shadow:inset 4px 0 0 var(--accent); }
    h2 { font-size:16px; margin:0; }
    .from, .meta, .dim { color:var(--dim); }
    .from { margin:2px 0 8px; font-size:13px; }
    .meta { font-size:12px; margin:8px 0 0; }
    table { width:100%; border-collapse:collapse; table-layout:fixed; }
    th, td { text-align:left; vertical-align:top; padding:6px 8px; border-top:1px solid var(--line); overflow-wrap:anywhere; }
    thead th { border-top:none; font-size:12px; color:var(--dim); font-weight:600; }
    tbody th { width:90px; font-size:12px; color:var(--dim); font-weight:600; }
    ul { margin:0; padding-left:18px; }
    q { display:block; quotes:none; font-size:12px; color:var(--dim); background:var(--quote); padding:2px 6px; border-radius:4px; margin:2px 0 4px; }
    .tag { font-size:11px; border:1px solid var(--line); border-radius:4px; padding:0 4px; color:var(--dim); }
    .date { font-variant-numeric:tabular-nums; color:var(--accent); }
    .reason { font-size:12px; color:var(--dim); }
    .notes { font-style:italic; }
    .error { color:var(--bad); }
    details { margin-top:8px; }
    summary { cursor:pointer; color:var(--dim); font-size:13px; }
    pre { white-space:pre-wrap; font-size:12px; background:var(--quote); padding:10px; border-radius:6px; max-height:420px; overflow:auto; }
    @media (max-width:640px) { tbody th { width:64px; } th, td { padding:5px 4px; } }
    """

    static let script = """
    const labelled = document.getElementById('only-labelled');
    const disagree = document.getElementById('only-disagree');
    function apply() {
      for (const card of document.querySelectorAll('article')) {
        const hide = (labelled.checked && card.dataset.labelled !== 'true')
                  || (disagree.checked && card.dataset.disagree !== 'true');
        card.style.display = hide ? 'none' : '';
      }
    }
    labelled.addEventListener('change', apply);
    disagree.addEventListener('change', apply);
    """
}
