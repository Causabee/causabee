import Foundation
import MatterCore
import SwiftData

/// `matter-bench [--engine apple] [--limit N] [--store matters.store]`
///
/// Reads the labelled mail again with a model on the Mac — on the text Opus was sent, the real
/// names put back here — and scores both against the store, which holds the owner's corrections.
/// Nothing is sent anywhere. The report names real people: it is written beside the store,
/// under a name git ignores, and never leaves the Mac.

let arguments = CommandLine.arguments
func value(_ flag: String) -> String? { arguments.firstIndex(of: flag).flatMap { $0 + 1 < arguments.count ? arguments[$0 + 1] : nil } }
let engineName = value("--engine") ?? "apple"
let limit = value("--limit").flatMap(Int.init)
let storeURL = URL(fileURLWithPath: value("--store") ?? "matters.store")
let folder = storeURL.deletingLastPathComponent()

// A copy, so the app can keep the store open while this reads it.
let copy = FileManager.default.temporaryDirectory.appendingPathComponent("bench-\(UUID().uuidString)", isDirectory: true)
try FileManager.default.createDirectory(at: copy, withIntermediateDirectories: true)
for suffix in ["", "-shm", "-wal"] {
    let from = URL(fileURLWithPath: storeURL.path + suffix)
    if FileManager.default.fileExists(atPath: from.path) {
        try FileManager.default.copyItem(at: from, to: copy.appendingPathComponent(storeURL.lastPathComponent + suffix))
    }
}
let context = ModelContext(try MatterSchema.container(at: copy.appendingPathComponent(storeURL.lastPathComponent)))
let matters = try context.fetch(FetchDescriptor<Matter>()).sorted { $0.key < $1.key }
let owner = (try context.fetch(FetchDescriptor<Profile>())).first?.names.first ?? "the owner"

let engine: LocalEngine
let maxCharacters: Int
switch engineName {
case "apple":
    guard #available(macOS 26.0, *) else { print("Apple's model needs macOS 26."); exit(1) }
    engine = AppleEngine()
    // Its window is 4,096 tokens for instructions, matters, mail and answer together.
    maxCharacters = 5_000
case "qwen":
    guard #available(macOS 27.0, *) else { print("MLX through Apple's session needs macOS 27."); exit(1) }
    engine = MLXEngine()
    maxCharacters = 12_000
default:
    print("Unknown engine \(engineName). Known: apple, qwen"); exit(1)
}

let cases = try Bench.cases(store: context, log: folder.appendingPathComponent("decisions-fetch.jsonl"),
                            mapping: folder.appendingPathComponent("mapping.json"), limit: limit)
print("\(engine.name): \(cases.count) mails, \(matters.count) matters. Nothing is sent.")

struct Row { var item: BenchCase; var answer: LocalAnswer?; var error: String?; var seconds: Double; var local: Bench.Score; var opus: Bench.Score }
var rows: [Row] = []
let instructions = Bench.instructions(owner: owner)
for (index, item) in cases.enumerated() {
    let started = Date()
    var answer: LocalAnswer?
    var failure: String?
    do { answer = try await engine.read(instructions: instructions, prompt: Bench.prompt(for: item, matters: matters, maxCharacters: maxCharacters)) }
    catch { failure = "\(error)" }
    let seconds = Date().timeIntervalSince(started)
    let local = Bench.score(todos: (answer?.todos ?? []).map { ($0.text, $0.owner, $0.due.isEmpty ? nil : $0.due) },
                            days: (answer?.dates ?? []).map(\.day),
                            matterRight: answer.map { Bench.matterRight($0.matter, title: $0.newMatterTitle, item: item, matters: matters) } ?? false,
                            item: item)
    let opus = Bench.score(todos: item.opus.todos.map { ($0.text, $0.owner.rawValue, $0.due) },
                           days: item.opus.appointments.map(\.date) + item.opus.deadlines.map(\.date),
                           matterRight: Bench.matterRight(item.opus.matter, title: item.opus.matterTitle, item: item, matters: matters),
                           item: item)
    rows.append(Row(item: item, answer: answer, error: failure, seconds: seconds, local: local, opus: opus))
    print(String(format: "%3d/%d  %5.1f s  matter %@ (Opus %@)  to-dos %d/%d%@", index + 1, cases.count, seconds,
                 local.matterRight ? "✓" : "✗", opus.matterRight ? "✓" : "✗", local.foundTodos, local.truthTodos,
                 failure.map { "  error: \($0.prefix(60))" } ?? ""))
}

// MARK: Totals

func percent(_ part: Int, _ whole: Int) -> String { whole == 0 ? "–" : "\(Int((Double(part) / Double(whole) * 100).rounded())) %" }
@MainActor func totals(_ pick: (Row) -> Bench.Score) -> [String] {
    let scores = rows.map(pick)
    let found = scores.reduce(0) { $0 + $1.foundTodos }, truth = scores.reduce(0) { $0 + $1.truthTodos }
    let said = scores.reduce(0) { $0 + $1.saidTodos }, right = scores.reduce(0) { $0 + $1.rightTodos }
    return [percent(scores.filter(\.matterRight).count, scores.count),
            percent(found, truth), percent(right, said),
            percent(scores.reduce(0) { $0 + $1.ownerRight }, found), percent(scores.reduce(0) { $0 + $1.dueRight }, found),
            percent(scores.reduce(0) { $0 + $1.foundDays }, scores.reduce(0) { $0 + $1.truthDays })]
}
let labels = ["Right matter", "To-dos found (of the store's)", "To-dos said that are real", "…whose: right", "…due day: right", "Dates found"]
let local = totals(\.local), opus = totals(\.opus)
let failed = rows.filter { $0.error != nil }.count
let average = rows.map(\.seconds).reduce(0, +) / Double(max(rows.count, 1))
print("\n" + String(repeating: " ", count: 32) + "  \(engineName.padding(toLength: 8, withPad: " ", startingAt: 0))  Opus")
for (index, label) in labels.enumerated() {
    print(label.padding(toLength: 32, withPad: " ", startingAt: 0) + "  " + local[index].padding(toLength: 8, withPad: " ", startingAt: 0) + "  " + opus[index])
}
print(String(format: "\n%.1f s a mail on average · %d failed · report: review-bench-%@.html", average, failed, engineName))

// MARK: Report

func esc(_ text: String) -> String {
    text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
}
var html = """
<!doctype html><meta charset="utf-8"><title>Bench \(esc(engine.name))</title>
<style>body{font:14px -apple-system,sans-serif;margin:24px;max-width:1200px}table{border-collapse:collapse;width:100%}
td,th{border-bottom:1px solid #ddd;padding:6px;vertical-align:top;text-align:left}.ok{color:#2e7d32}.no{color:#c62828}
.small{color:#666;font-size:12px}ul{margin:0;padding-left:16px}</style>
<h1>\(esc(engine.name)) vs. Opus — \(rows.count) Mails</h1><table><tr><th></th><th>\(esc(engineName))</th><th>Opus</th></tr>
"""
for (index, label) in labels.enumerated() { html += "<tr><td>\(label)</td><td>\(local[index])</td><td>\(opus[index])</td></tr>" }
html += String(format: "</table><p>%.1f s pro Mail · %d Fehler</p><table><tr><th>Mail</th><th>Im Store</th><th>Lokal</th><th>Opus</th></tr>", average, failed)
func list(_ items: [String]) -> String { items.isEmpty ? "<span class=small>–</span>" : "<ul>" + items.map { "<li>\(esc($0))</li>" }.joined() + "</ul>" }
for row in rows {
    let item = row.item
    let mark = { (ok: Bool) in ok ? "<span class=ok>✓</span>" : "<span class=no>✗</span>" }
    html += "<tr><td><b>\(esc(item.subject))</b><div class=small>\(item.date.map { MatterStatus.day($0) } ?? "") · \(String(format: "%.1f s", row.seconds))</div></td>"
    html += "<td>\(esc(item.matter?.name ?? "keine"))\(item.startsMatter ? " <span class=small>(neu)</span>" : "")"
        + list(item.todos.map { "[\($0.owner)] \($0.text)\($0.due.map { " · \($0)" } ?? "")" }) + "</td>"
    if let answer = row.answer {
        html += "<td>\(mark(row.local.matterRight)) \(esc(answer.matter))\(answer.newMatterTitle.isEmpty ? "" : " „\(esc(answer.newMatterTitle))“")"
            + list(answer.todos.map { "[\($0.owner)] \($0.text)\($0.due.isEmpty ? "" : " · \($0.due)")" })
            + "<div class=small>" + esc(answer.dates.map { "\($0.day) \($0.what)" }.joined(separator: "; ")) + "</div></td>"
    } else {
        html += "<td class=no>\(esc(row.error ?? ""))</td>"
    }
    html += "<td>\(mark(row.opus.matterRight)) \(esc(item.opus.matter ?? "keine"))"
        + list(item.opus.todos.map { "[\($0.owner.rawValue)] \($0.text)\($0.due.map { " · \($0)" } ?? "")" }) + "</td></tr>"
}
html += "</table>"
try html.write(to: folder.appendingPathComponent("review-bench-\(engineName).html"), atomically: true, encoding: .utf8)
try? FileManager.default.removeItem(at: copy)
