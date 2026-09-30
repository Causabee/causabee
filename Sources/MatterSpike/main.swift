import Foundation
import MatterCore
import NaturalLanguage
import SwiftData

// The Phase 0 command line tool. It reads a folder of `.eml` files, runs as much of the
// pipeline as is built, and writes one JSON line per mail. Nothing goes over the network unless
// `--classify` is passed, and then only the disguised text of mail that got past the filter.

let usage = """
matter-spike — Matterbee Phase 0

USAGE
  matter-spike run    <folder> [--log <path>] [--mode placeholder|standin] [--mapping <path>]
                               [--language <code>] [--no-tagger] [--show <n>]
                               [--classify | --dry-run [<path>]] [--model opus|haiku|sonnet]
                               [--effort <level>] [--limit <n>] [--me <name>] [--cache <path>]
                               [--full-history] [--quiet-after <n>] [--no-bulk-filter]
  matter-spike labels <folder> [--out <path>] [--threads]
  matter-spike check  <folder> [--labels <path>]
  matter-spike review [--log <path>] [--labels <path>] [--page <path>]
  matter-spike report <folder> [--log <path>] [--labels <path>] [--report <path>]
                             [--judge] [--mapping <path>]
  matter-spike login  --account <address> [--host <server>] [--forget]
  matter-spike fetch  [--account <address>] [--label <name>] [--since <YYYY-MM-DD>]
                      and any option of run
  matter-spike import  [--log <path>] [--store <path>]
  matter-spike matters [<matter>] [--store <path>]
  matter-spike merge   <matter> <into matter> [--store <path>]
  matter-spike rename  <matter> <new name> [--store <path>]
  matter-spike parties <matter> [--store <path>]
  matter-spike same    <matter> <party> <same as party> | <matter> <suggestion number>
  matter-spike notsame <matter> <party> <other party>
  matter-spike rules   [--off <n> | --on <n>] [--store <path>]
  matter-spike ask     [<matter>] "<question>" [--dry-run] [--store <path>] [--mapping <path>]
  matter-spike owner   <matter> "<words of the to-do>" me|we|other|unknown [--store <path>]
  matter-spike party   <matter> "<name>" [--name "<new name>"] [--role "<role>"] [--store <path>]
  matter-spike screenshot <image> [--store <path>]
  matter-spike close   <matter> [--done] [--store <path>]
  matter-spike reopen  <matter> [--store <path>]

  run       parse → bulk filter → entity detection → pseudonymize, one JSON line per mail
            --log       where the decision log goes (default: decisions.jsonl)
            --mode      placeholder writes [Person A]; standin writes a realistic name
                        (default: placeholder)
            --mapping   where originals and their stand-ins are kept (default: mapping.json).
                        Read first and added to, so a name keeps its stand-in across runs.
            --language  force the tagger's language, e.g. de, en (default: per mail)
            --no-tagger rules only, to measure what the tagger adds
            --show <n>  print the first n decisions as formatted JSON

            --classify  steps 5 and 6: send each disguised mail to Claude, restore the answer.
                        Needs ANTHROPIC_API_KEY, in the environment or in .env
            --dry-run   write the exact requests to a file (default: requests.jsonl) and send
                        nothing. Later requests show no matters yet: those come from answers
            --model     opus (claude-opus-5, the default), sonnet or haiku, or a model id
            --effort    low, medium, high (default), xhigh or max; ignored by haiku
            --limit <n> only the first n mails, in date order
            --me <name> the mailbox owner, as a name or address; repeatable. Default: the
                        address that receives the most mail, and the names it goes by
            --cache     where answers are kept so a re-run costs nothing (default: .matter-cache)
            --full-history   send the whole quoted thread, not just the newest message
            --quiet-after <n> stop sending a sender after n answers in a row with nothing in
                        them (default: 3; 0 turns it off)
            --no-bulk-filter  keep every mail, as the manual edition does with mail the owner
                        labelled: a label is a decision the filter does not overrule

            Each mail is classified once. A mail already answered in --log keeps its answer,
            even after the disguise or the prompt changed, and is not sent again; only new mail
            is. The cost is shown first, and nothing is sent without a yes.
            --reclassify  send every mail again, the answers in --log thrown away. Asks first
            --yes         do not ask; for runs nobody is watching

  labels    write a labels.csv template: the headers filled in, every judgement blank
            --out       where it goes (default: labels.csv). An existing file is not touched.
            --threads   a thread set for the manual edition: whole matter threads, sorted
                        thread by thread, with `tapped` in place of `is_bulk`

  check     read labels.csv and say whether it is complete and whether it parses
            --labels    which file to read (default: labels.csv)

  review    write a local page of every classified mail: what the model said beside your
            label, and exactly what was sent. Made from real mail; it stays on this machine
            --page      where it goes (default: review.html)

  report    step 8: measure a classified run against the golden set — reaching the matter
            from one tap, to-dos (and the owner's own), deadlines, parties, matters — and
            write every to-do pairing out so the matcher can be checked
            --report    where the full report goes (default: report.md). Made from real mail
            --judge     pair to-dos with Claude Sonnet 5 instead of word stems. Both lists are
                        disguised with --mapping first; answers are cached in --cache

  login     save the mail password in the Keychain, after checking it works. Asked for on
            the terminal, never shown, never written to a file. For Gmail, an app password:
            myaccount.google.com/apppasswords
            --account   the address you log in with
            --host      the IMAP server; Gmail and iCloud addresses know theirs, any other needs it
                        (saved with the password, so it is named once)
            --forget    remove the saved password instead

  fetch     Phase 2's daily door: read the mail under one label, read-only, find the replies
            that followed it by thread, and run it through the same steps as run. Labelled
            mail is never thrown out by the bulk filter; a reply found by thread can be
            --account   which saved account (default: the only one saved)
            --label     the Gmail label or IMAP folder (default: Matterbee)
            --since     only mail from this day on
            --import    put what it found into the matter store (--store) as well
            The log defaults to decisions-fetch.jsonl here, the record of what the label has
            already answered: each mail is classified once.

  The daily door, in one line:
    matter-spike fetch --classify --import

  import    turn a classified log into matters: one entry per mail, one to-do per thing to
            do however often it is asked, appointments, deadlines, parties. Safe to repeat:
            a mail already in the store adds nothing
            --store     the matter store (default: matters.store). Made from real mail; gitignored

  matters   every matter, or one matter's status: open to-dos (mine, ours, waiting for),
            appointments, deadlines, parties

  merge     fold the first matter into the second. Its names stay as aliases, so mail the
            model files under the old name still arrives
  rename    give a matter a name of your own; the model's name stays as an alias

  parties   one matter's people and companies, each once, with every way they were written,
            and the merges worth asking about, numbered
  same      merge the first party into the second — or accept a numbered suggestion. Kept as
            a rule, so the next mail's spelling goes to the right party too
  notsame   the two are different people; do not suggest them again
  rules     everything you told Matterbee, where it came from, how often it was used, and a
            switch: --off <n> stops rule n for the mail that comes next, --delete <n> removes it

  ask       the assistant, from the terminal: a question about one matter, or about all of
            them. Disguised with --mapping before it is sent. --dry-run prints exactly what
            would be sent, checks it for any original from the mapping, and sends nothing

  party     put a party right by hand: its name, or its role in this matter. Free: nothing
            is sent

  screenshot  read a chat screenshot on this Mac, as the app does, and print the chat, what
            was left out, and exactly what would be sent. Sends nothing

  close     close a matter: it leaves the list and the assistant, and nothing is deleted.
            --done ticks its open to-dos; without it they stay open
  reopen    open it again; what closing ticked is open again too

  owner     whose a to-do is: me, we (you with others), other (someone else's, you wait for
            it), or unknown

  import takes --me <name> for who you are; without it, the sender of most mail in the log.
  You are never a party in your own matters.

  folder    a directory of .eml files (default: Samples/mail)

Without --classify, nothing is sent anywhere. With it, only disguised text is.
mapping.json holds the originals. It is gitignored and never leaves this machine.
"""

struct Options {
    enum Command: String { case run, labels, check, review, report, login, fetch, `import`, matters, merge, rename, parties, same, notsame, rules, ask, owner, close, reopen, party, screenshot, digest }
    var command = Command.run
    var folder = URL(fileURLWithPath: "Samples/mail")
    var log = URL(fileURLWithPath: "decisions.jsonl")
    var labels = URL(fileURLWithPath: "labels.csv")
    var mapping = URL(fileURLWithPath: "mapping.json")
    var mode = Pseudonymizer.Mode.placeholder
    var runsTagger = true
    var language: NLLanguage?
    var show = 0
    var classify = false
    var dryRun: URL?
    var model = Claude.Model.opus
    var effort: String?
    var limit: Int?
    var me: [String] = []
    var cache = URL(fileURLWithPath: ".matter-cache")
    var page = URL(fileURLWithPath: "review.html")
    var newestOnly = true
    var strict = false
    var redoLanguage = false
    var quietAfter = 3
    var threads = false
    var filtersBulk = true
    var judge = false
    var report = URL(fileURLWithPath: "report.md")
    var account: String?
    var host: String?
    var label = "Matterbee"
    var since: Date?
    var forget = false
    var reclassify = false
    var closesDone = false
    var imports = false
    var logGiven = false
    var yes = false
    var store = URL(fileURLWithPath: "matters.store")
    /// Everything that was not a flag, in order: the folder, or a matter's names.
    var words: [String] = []
    var switchOff: Int?
    var deleteRule: Int?
    var newPartyName: String?
    var role: String?
    var switchOn: Int?

    static func day(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = .current
        return formatter.date(from: text)
    }

    static func parse(_ arguments: [String]) -> Options? {
        var options = Options()
        var rest = arguments.dropFirst()
        var sawFolder = false
        var given: Set<String> = []
        var data: URL?

        if let first = rest.first, let command = Command(rawValue: first) {
            options.command = command
            rest = rest.dropFirst()
        }

        while let argument = rest.first {
            rest = rest.dropFirst()
            func next() -> String? {
                defer { if !rest.isEmpty { rest = rest.dropFirst() } }
                return rest.first
            }
            switch argument {
            case "--help", "-h": return nil
            case "--log": guard let path = next() else { return nil }; options.log = URL(fileURLWithPath: path); options.logGiven = true
            case "--out", "--labels":
                guard let path = next() else { return nil }
                options.labels = URL(fileURLWithPath: path)
            case "--mapping": guard let path = next() else { return nil }; options.mapping = URL(fileURLWithPath: path); given.insert("mapping")
            case "--mode":
                guard let name = next(), let mode = Pseudonymizer.Mode(rawValue: name) else { return nil }
                options.mode = mode
            case "--language": guard let code = next() else { return nil }; options.language = NLLanguage(rawValue: code)
            case "--show":
                guard let count = next(), let number = Int(count) else { return nil }
                options.show = number
            case "--no-tagger": options.runsTagger = false
            case "--classify": options.classify = true
            case "--dry-run":
                if let path = rest.first, !path.hasPrefix("-"), !path.contains("/") || path.hasSuffix(".jsonl") {
                    options.dryRun = URL(fileURLWithPath: path); rest = rest.dropFirst()
                } else {
                    options.dryRun = URL(fileURLWithPath: "requests.jsonl")
                }
            case "--model": guard let name = next(), let model = Claude.Model.named(name) else { return nil }; options.model = model
            case "--effort": guard let level = next() else { return nil }; options.effort = level
            case "--limit": guard let count = next(), let number = Int(count) else { return nil }; options.limit = number
            case "--me": guard let name = next() else { return nil }; options.me.append(name)
            case "--cache": guard let path = next() else { return nil }; options.cache = URL(fileURLWithPath: path); given.insert("cache")
            case "--page": guard let path = next() else { return nil }; options.page = URL(fileURLWithPath: path)
            case "--full-history": options.newestOnly = false
            case "--strict": options.strict = true
            case "--redo-language": options.redoLanguage = true
            case "--title": _ = next()
            case "--threads": options.threads = true
            case "--no-bulk-filter": options.filtersBulk = false
            case "--judge": options.judge = true
            case "--report": guard let path = next() else { return nil }; options.report = URL(fileURLWithPath: path)
            case "--account": guard let address = next() else { return nil }; options.account = address
            case "--host": guard let host = next() else { return nil }; options.host = host
            case "--label": guard let label = next() else { return nil }; options.label = label
            case "--since":
                guard let day = next(), let date = Options.day(day) else { return nil }
                options.since = date
            case "--forget": options.forget = true
            case "--reclassify": options.reclassify = true
            case "--done": options.closesDone = true
            case "--import": options.imports = true
            case "--yes": options.yes = true
            case "--store": guard let path = next() else { return nil }; options.store = URL(fileURLWithPath: path); given.insert("store")
            case "--data": guard let path = next() else { return nil }; data = URL(fileURLWithPath: path, isDirectory: true)
            case "--off": guard let n = next().flatMap(Int.init) else { return nil }; options.switchOff = n
            case "--on": guard let n = next().flatMap(Int.init) else { return nil }; options.switchOn = n
            case "--delete": guard let n = next().flatMap(Int.init) else { return nil }; options.deleteRule = n
            case "--name": guard let name = next() else { return nil }; options.newPartyName = name
            case "--role": guard let role = next() else { return nil }; options.role = role
            case "--quiet-after": guard let count = next(), let number = Int(count) else { return nil }; options.quietAfter = number
            default:
                guard !argument.hasPrefix("-") else { return nil }
                options.words.append(argument)
                if !sawFolder { options.folder = URL(fileURLWithPath: argument) }
                sawFolder = true
            }
        }
        // The label's own record, so fetch never reads the spike's log and takes all of it for new.
        if options.command == .fetch, !options.logGiven { options.log = URL(fileURLWithPath: "decisions-fetch.jsonl") }
        // The app's data, where the app keeps it: `--data`, or Application Support once a store is
        // there. What is named with its own flag wins. Without either, files are where you are.
        let appData = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Matterbee", isDirectory: true)
        if let folder = data ?? (FileManager.default.fileExists(atPath: appData.appendingPathComponent("matters.store").path) ? appData : nil) {
            if !given.contains("store") { options.store = folder.appendingPathComponent("matters.store") }
            if !given.contains("mapping") { options.mapping = folder.appendingPathComponent("mapping.json") }
            if !given.contains("cache") { options.cache = folder.appendingPathComponent(".matter-cache") }
            if options.command == .fetch, !options.logGiven { options.log = folder.appendingPathComponent("decisions-fetch.jsonl") }
        }
        return options
    }
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

guard let options = Options.parse(CommandLine.arguments) else {
    print(usage)
    exit(CommandLine.arguments.contains(where: { $0 == "--help" || $0 == "-h" }) ? 0 : 2)
}

var isDirectory: ObjCBool = false
if [.run, .labels, .check, .report].contains(options.command) {
    if options.words.count > 1 { print(usage); exit(2) }
    guard FileManager.default.fileExists(atPath: options.folder.path, isDirectory: &isDirectory),
          isDirectory.boolValue else {
        fail("no such folder: \(options.folder.path)")
    }
}

func row(_ label: String, _ value: String) {
    print("  \(label.padding(toLength: 22, withPad: " ", startingAt: 0))\(value)")
}

func percent(_ part: Int, of whole: Int) -> String {
    whole == 0 ? "—" : "\(Int((Double(part) / Double(whole) * 100).rounded()))%"
}

switch options.command {
case .run: try await run()
case .labels: try makeLabels()
case .check: try check()
case .review: try review()
case .report: try await report()
case .login: try await login()
case .fetch: try await fetch()
case .import: try importLog()
case .matters: try matters()
case .merge: try merge()
case .rename: try rename()
case .parties: try parties()
case .same: try same()
case .notsame: try notSame()
case .rules: try rules()
case .ask: try await ask()
case .owner: try setOwner()
case .close: try close()
case .digest: try await digest()
case .reopen: try reopen()
case .party: try editParty()
case .screenshot: try readScreenshot()
}

// MARK: run

func run() async throws {
    try await process(source: options.folder.path) { spike, pseudonymizer in
        try spike.run(folder: options.folder, log: nil, pseudonymizer: pseudonymizer)
    }
}

/// What `fetch` read, for the summary. Nil for a folder.
nonisolated(unsafe) var intake: LabelIntake.Result?

/// Everything after the mail is in hand: disguise, ask, restore, log, and say what happened.
func process(source: String, reading: (Spike, Pseudonymizer) async throws -> Spike.Report) async throws {
    let spike = Spike(detector: EntityDetector(language: options.language, runsTagger: options.runsTagger),
                      filtersBulk: options.filtersBulk)
    var mapping = Pseudonymizer.Mapping()
    if let data = try? Data(contentsOf: options.mapping) {
        do { mapping = try JSONDecoder().decode(Pseudonymizer.Mapping.self, from: data) }
        catch { fail("\(options.mapping.path) is not a mapping this version can read: \(error)") }
        let split = mapping.upgrade()
        if split > 0 {
            FileHandle.standardError.write(Data("\(options.mapping.path): brought up to version \(Pseudonymizer.Mapping.current), \(split) entries changed\n".utf8))
        }
    }
    let known = mapping[options.mode].count
    // The key is checked before any work is done, so a missing one fails in a second rather
    // than after the whole folder has been read.
    let key = Claude.key(for: options.model)
    if options.classify, key == nil {
        fail("no key for \(options.model.label): put \(options.model.keyName)=… into .env, or paste it in the app's settings")
    }

    var report = try await reading(spike, Pseudonymizer(mode: options.mode, entries: mapping[options.mode]))

    var extraction: Extractor.Summary?
    var owner: [String] = []
    // What earlier runs answered. Kept, not sent again, unless --reclassify says otherwise.
    var answered: [String: Judgement] = [:]
    if options.classify || options.command == .fetch, !options.reclassify, let data = try? Data(contentsOf: options.log) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        for line in data.split(separator: 0x0A) {
            guard let judgement = try? decoder.decode(Judgement.self, from: Data(line)) else { continue }
            answered[judgement.emailID] = judgement
        }
    }
    if options.classify, options.dryRun == nil {
        let pending = report.outcomes.filter { $0.judgement.disguise != nil && !(answered[$0.judgement.emailID].map(Extractor.isSettled) ?? false) }
        let count = options.limit.map { min($0, pending.count) } ?? pending.count
        // The same price a mail as the app shows, for every model — a table of its own here had
        // Mistral and GPT four to twenty times too cheap before "Send them?".
        let estimate = Double(count) * options.model.perMail
        let kept = options.command == .fetch ? answered.values.filter(Extractor.isSettled).count
            : report.outcomes.filter { $0.judgement.disguise != nil }.count - pending.count
        FileHandle.standardError.write(Data(String(format: "\n%d mails to classify, about $%.2f with %@. %d answered before: kept, not sent.\n",
                                                   count, estimate, options.model.id, kept).utf8))
        if count > 0, !options.yes {
            FileHandle.standardError.write(Data("Send them? [y/N] ".utf8))
            let answer = readLine()?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
            guard answer == "y" || answer == "yes" || answer == "j" || answer == "ja" else {
                fail("Nothing sent. (--yes skips this question.)")
            }
        }
    }
    if (options.classify || options.dryRun != nil), let pseudonymizer = report.pseudonymizer {
        var named = options.me
        if named.isEmpty, options.command == .fetch, FileManager.default.fileExists(atPath: options.store.path),
           let context = try? ModelContext(MatterSchema.container(at: options.store)) {
            // Only today's mail is read now, too little to tell who the owner is by; the store knows.
            named = (try? context.fetch(FetchDescriptor<Profile>()).first?.names) ?? []
        }
        owner = Extractor.owner(named: named, in: report.outcomes)
        var extractor = Extractor(model: options.model, effort: options.effort,
                                  claude: key.map { Claude(key: $0) }, cache: options.cache,
                                  newestOnly: options.newestOnly, quietAfter: options.quietAfter)
        extractor.strict = options.strict
        extraction = try await extractor.run(&report.outcomes, pseudonymizer: pseudonymizer, owner: owner,
                                             limit: options.limit, dryRun: options.dryRun, known: answered) { step, total, outcome in
            guard options.dryRun == nil else { return }
            let subject = String(outcome.judgement.subject.prefix(60))
            FileHandle.standardError.write(Data("  [\(step)/\(total)] \(subject)\n".utf8))
        }
    }

    if options.command == .fetch {
        // The whole record: what earlier runs answered, and what this one read.
        try DailyDoor.write(Array(answered.values), plus: report.outcomes.map(\.judgement), to: options.log)
    } else {
        let log = try JudgementLog(url: options.log)
        for outcome in report.outcomes { try log.write(outcome.judgement) }
        try log.close()
    }

    if let learned = report.pseudonymizer {
        mapping[options.mode] = learned.entries
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(mapping).write(to: options.mapping, options: .atomic)
    }

    print("")
    print("matter-spike · \((Spike.stages + (options.classify ? ["classify", "restore"] : [])).joined(separator: " → "))")
    print("")
    print(source)
    if let intake {
        row("labelled", "\(intake.labelled.count)  in \(intake.labelFolder?.name ?? options.label)")
        row("followed by thread", "\(intake.followed.count)  found in \(intake.searched.joined(separator: ", "))")
        for way in [LabelIntake.Way.gmailThread, .references] {
            let count = intake.followed.values.filter { $0 == way }.count
            if count > 0 { row("", "\(count) by \(way.rawValue)") }
        }
    }
    row(intake == nil ? "files read" : "mails read", "\(report.outcomes.count)")
    if !report.failures.isEmpty { row("unreadable", "\(report.failures.count)") }
    if !report.empty.isEmpty { row("no readable body", "\(report.empty.count)") }

    print("")
    print("Bulk filter caught \(report.bulk.count) of \(report.outcomes.count) (\(percent(report.bulk.count, of: report.outcomes.count)))")
    for rule in BulkFilter.Rule.allCases {
        guard let count = report.byRule[rule] else { continue }
        row(rule.rawValue, "\(count)   \(rule.reason)")
    }

    let entities = report.outcomes.flatMap(\.judgement.entities)
    print("")
    print("Entities found in the \(report.kept.count) mails that got past it: \(entities.count)")
    for source in [Entity.Source.rule, .onDevice] { row(source.rawValue, "\(report.bySource[source] ?? 0)") }
    print("")
    for kind in Entity.Kind.allCases where (report.byKind[kind] ?? 0) > 0 {
        row(kind.rawValue, "\(report.byKind[kind] ?? 0)")
    }

    let skipped = Dictionary(grouping: report.outcomes.flatMap(\.judgement.notDisguised), by: \.text)
    let entries = report.pseudonymizer?.entries ?? []
    print("")
    print("Disguised \(report.disguised.count) mails, \(options.mode.rawValue) mode: " +
          "\(report.disguised.map { $0.judgement.disguise?.replacements ?? 0 }.reduce(0, +)) replacements")
    row("mapping", "\(entries.count) entries, \(entries.count - known) new, in \(options.mapping.path)")
    row("learned from parts", "\(entries.filter { $0.partOf != nil }.count)")
    if !skipped.isEmpty {
        print("")
        print("Found but left alone (\(skipped.count)) — check none of these is a real name:")
        for (text, skips) in skipped.sorted(by: { $0.key < $1.key }) { row(text, skips[0].reason) }
    }

    print("")
    print("  \("from".padding(toLength: 30, withPad: " ", startingAt: 0))\("subject".padding(toLength: 40, withPad: " ", startingAt: 0))verdict")
    print("  " + String(repeating: "─", count: 86))
    for outcome in report.outcomes {
        let decision = outcome.judgement
        let from = String(decision.from.prefix(28)).padding(toLength: 30, withPad: " ", startingAt: 0)
        let subject = String(decision.subject.prefix(38)).padding(toLength: 40, withPad: " ", startingAt: 0)
        let verdict = decision.isBulk
            ? "bulk · \(decision.bulkReason ?? "")"
            : "kept · \(decision.entities.count) entities · \(decision.disguise?.replacements ?? 0) replaced"
        print("  \(from)\(subject)\(verdict)")
    }
    for failure in report.failures { print("  \(failure.file): \(failure.error)") }

    if let extraction {
        print("")
        if let dryRun = options.dryRun {
            print("Dry run: nothing was sent. The requests are in \(dryRun.path)")
            row("owner (\"me\")", owner.joined(separator: ", "))
        } else {
            print("Claude · \(options.model.id) · \(options.mode.rawValue) · prompt \(ExtractionPrompt.version)")
            row("owner (\"me\")", owner.joined(separator: ", "))
            row("sent", "\(extraction.sent)")
            if extraction.kept > 0 { row("kept from before", "\(extraction.kept)  (classified once, not sent again)") }
            if extraction.cached > 0 { row("from cache", "\(extraction.cached)") }
            if extraction.fallbacks > 0 { row("answered by fallback", "\(extraction.fallbacks)") }
            row("history left out", options.newestOnly ? "in \(extraction.historyLeftOut) mails" : "no (--full-history)")
            if options.quietAfter > 0 { row("not sent, quiet sender", "\(extraction.skipped)") }
            let answered = extraction.sent + extraction.cached
            row("tokens", "\(extraction.inputTokens) in (\(extraction.cacheReadTokens) of them from the prompt cache), \(extraction.outputTokens) out")
            row("cost", String(format: "$%.2f  ($%.4f per mail)", extraction.cost, answered == 0 ? 0 : extraction.cost / Double(answered)))
            row("time", String(format: "%.0f s  (%.1f s per mail)", extraction.seconds, answered == 0 ? 0 : extraction.seconds / Double(answered)))
            row("to-dos", "\(extraction.todosNew) new, \(extraction.todosAgain) asked again, \(extraction.todosDone) shown done")
            row("appointments", "\(extraction.appointments)")
            print("")
            print("Matters it found (\(extraction.matters.count)):")
            for matter in extraction.matters {
                let count = report.outcomes.filter { $0.judgement.matter == matter }.count
                row(matter, count == 1 ? "1 mail" : "\(count) mails")
            }
            if !extraction.quietSenders.isEmpty {
                print("")
                print("Senders that went quiet (\(extraction.quietSenders.count)) — nothing to act on \(options.quietAfter) times in a row:")
                for quiet in extraction.quietSenders { row(quiet.sender, String(quiet.from.prefix(50))) }
            }
            if !extraction.failed.isEmpty {
                print("")
                print("Failed (\(extraction.failed.count)):")
                for failure in extraction.failed { print("  \(failure.subject.prefix(50)): \(failure.error)") }
            }
        }
    }

    print("")
    print("Wrote \(report.outcomes.count) decisions to \(options.log.path)")
    print(options.classify ? "Only disguised text was sent; clustering and the report are steps 7 and 8."
                           : "Nothing was sent anywhere. Add --classify for steps 5 and 6.")

    if options.show > 0 {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]
        for outcome in report.outcomes.prefix(options.show) {
            print("")
            print(String(decoding: try encoder.encode(outcome.judgement), as: UTF8.self))
        }
    }
    print("")
}

// MARK: labels

func makeLabels() throws {
    // Never overwritten. The one file in this project that cannot be regenerated is the one a
    // person spent an evening typing.
    if FileManager.default.fileExists(atPath: options.labels.path) {
        fail("\(options.labels.path) already exists. Move it aside first, or pass --out somewhere else.")
    }

    let files = try Spike.files(in: options.folder)
    var emails: [Email] = []
    var unreadable: [String] = []
    for file in files {
        if let email = try? EMLParser.parse(contentsOf: file) { emails.append(email) }
        else { unreadable.append(file.lastPathComponent) }
    }
    guard !emails.isEmpty else { fail("no mail files in \(options.folder.path)") }

    let kind: GoldenSet.Kind = options.threads ? .threads : .inbox
    try GoldenSet.template(for: emails, kind: kind).write(to: options.labels, atomically: true, encoding: .utf8)

    print("")
    print("Wrote \(emails.count) rows to \(options.labels.path)")
    for file in unreadable { print("  could not read \(file)") }
    print("")
    print("Filled in for you:   file, email_id, date, from, subject")
    print("Yours to fill in:    " + GoldenSet.columns(kind).dropFirst(5).joined(separator: ", "))
    if kind == .threads {
        print("")
        print("Sorted thread by thread, oldest first. `tapped` is yes on the mail you would put the")
        print("Matterbee label on and no on the replies below it; to-dos are the main part.")
    }
    print("")
    print("The judgement columns are deliberately empty. A golden set filled in with the")
    print("pipeline's own answers measures nothing.")
    print("")
    print("Then: matter-spike check \(options.folder.path) --labels \(options.labels.path)")
    print("")
}

// MARK: check

func check() throws {
    guard let text = try? String(contentsOf: options.labels, encoding: .utf8) else {
        fail("cannot read \(options.labels.path). Run `matter-spike labels` first.")
    }
    let reading = GoldenSet.read(text)
    let files = Set(try Spike.files(in: options.folder).map(\.lastPathComponent))
    let labelled = reading.labels.filter(\.isLabelled)

    print("")
    print("\(options.labels.path)")
    row("rows", "\(reading.labels.count)")
    row("labelled", "\(labelled.count)  (\(percent(labelled.count, of: reading.labels.count)))")

    let missing = files.subtracting(reading.labels.map(\.file)).sorted()
    let unknown = reading.labels.map(\.file).filter { !files.contains($0) }.sorted()
    if !missing.isEmpty {
        print("")
        print("In the folder but not in the file (\(missing.count)):")
        for file in missing.prefix(10) { print("  \(file)") }
        if missing.count > 10 { print("  … and \(missing.count - 10) more") }
    }
    if !unknown.isEmpty {
        print("")
        print("In the file but not in the folder (\(unknown.count)):")
        for file in unknown.prefix(10) { print("  \(file)") }
    }

    // With a `suggest` column, only the suggested rows count as still to do. Without one, every
    // blank row does, and the target is the fifty the guide asks for.
    let suggested = reading.labels.filter(\.isSuggested)
    // A thread set is labelled whole: every row is a mail the manual edition would send.
    let target = reading.kind == .threads ? reading.labels.count : (suggested.isEmpty ? 50 : suggested.count)
    let pending = suggested.isEmpty ? reading.labels : suggested
    let blank = pending.filter { !$0.isLabelled }.map(\.file)
    if !suggested.isEmpty {
        let done = suggested.filter(\.isLabelled).count
        row("suggested", "\(done) of \(suggested.count) labelled")
        let extra = labelled.count - done
        if extra > 0 { row("", "plus \(extra) you chose yourself") }
    }
    if !blank.isEmpty {
        print("")
        print(suggested.isEmpty ? "Still blank (\(blank.count)):" : "Suggested and still blank (\(blank.count)):")
        for file in blank.prefix(10) { print("  \(file)") }
        if blank.count > 10 { print("  … and \(blank.count - 10) more") }
    }

    if !reading.complaints.isEmpty {
        print("")
        print("Rows to look at again (\(reading.complaints.count)):")
        for complaint in reading.complaints.prefix(20) {
            print("  row \(complaint.row)  \(complaint.file)\n    \(complaint.text)")
        }
    }

    print("")
    if reading.kind == .threads {
        row("tapped", "\(labelled.filter { $0.tapped == true }.count)")
        row("follow by thread", "\(labelled.filter { $0.tapped == false }.count)")
    } else {
        row("bulk", "\(labelled.filter { $0.isBulk == true }.count)")
        row("not bulk", "\(labelled.filter { $0.isBulk == false }.count)")
    }

    let matters = Dictionary(grouping: labelled.compactMap(\.matter), by: { $0 }).mapValues(\.count)
    print("")
    print("Matters named: \(matters.count)")
    for (matter, count) in matters.sorted(by: { $0.value > $1.value }) {
        row(matter, count == 1 ? "1 mail" : "\(count) mails")
    }
    if matters.count == 1 { print("  (one matter is enough to start; question 5 needs a second one to be interesting)") }

    print("")
    row("parties", "\(labelled.flatMap(\.parties).count)")
    row("to-dos", "\(labelled.flatMap(\.todos).count)")
    row("deadlines", "\(labelled.flatMap(\.deadlines).count)")

    print("")
    // Blank rows are not a fault. Fifty labelled out of a hundred and fifty exported is the target,
    // so most of the file stays blank on purpose.
    if reading.complaints.isEmpty && missing.isEmpty && unknown.isEmpty {
        if !blank.isEmpty || labelled.count < target {
            let done = suggested.isEmpty ? labelled.count : suggested.filter(\.isLabelled).count
            let what = reading.kind == .threads ? "\(target)" : (suggested.isEmpty ? "about 50" : "\(target) suggested")
            print("Nothing to fix. \(done) of \(what) labelled so far.")
        } else {
            print("The golden set reads cleanly. Nothing has been compared against it yet — that is")
            print("step 8, and steps 5 to 7 come first.")
        }
    } else {
        print("Fix the rows above and run check again.")
    }
    print("")
}

// MARK: review

func readLog() -> [Judgement] {
    guard let data = try? Data(contentsOf: options.log) else {
        fail("cannot read \(options.log.path). Run `matter-spike run <folder> --classify` first.")
    }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    var decisions: [Judgement] = []
    for (number, line) in data.split(separator: 0x0A).enumerated() {
        do { decisions.append(try decoder.decode(Judgement.self, from: Data(line))) }
        catch { fail("\(options.log.path) line \(number + 1) is not a decision this version can read: \(error)") }
    }
    return decisions
}

func review() throws {
    let decisions = readLog()
    let labels = (try? String(contentsOf: options.labels, encoding: .utf8)).map { GoldenSet.read($0).labels } ?? []

    let html = ReviewPage.render(decisions: decisions, labels: labels, title: "Matterbee — what the model said")
    try html.write(to: options.page, atomically: true, encoding: .utf8)

    let classified = decisions.filter { $0.extraction != nil }.count
    print("")
    print("Wrote \(options.page.path)")
    row("classified mails", "\(classified) of \(decisions.count)")
    row("labels read", labels.isEmpty ? "none (\(options.labels.path) not found)" : "\(labels.filter(\.isLabelled).count)")
    print("Open it in a browser. It is made from real mail and is gitignored; do not share it.")
    print("")
}

// MARK: report

func report() async throws {
    let decisions = readLog()
    guard let text = try? String(contentsOf: options.labels, encoding: .utf8) else {
        fail("cannot read \(options.labels.path)")
    }
    let reading = GoldenSet.read(text)
    if !reading.complaints.isEmpty { fail("\(options.labels.path) has rows to fix first: run `matter-spike check`.") }
    let emails = try Spike.files(in: options.folder).compactMap { try? EMLParser.parse(contentsOf: $0) }

    var judged: Report.Judged?
    var judgeCost = 0.0
    if options.judge {
        guard let key = Claude.key() else { fail(Claude.Failure.noKey.description) }
        guard let data = try? Data(contentsOf: options.mapping),
              var mapping = try? JSONDecoder().decode(Pseudonymizer.Mapping.self, from: data) else {
            fail("the judge needs the run's mapping, to disguise both lists: pass --mapping")
        }
        mapping.upgrade()
        // Everything the judge reads goes through the same disguise the mail did.
        let pseudonymizer = Pseudonymizer(mode: .placeholder, entries: mapping.placeholder)
        let disguiser = pseudonymizer.disguiser, restorer = pseudonymizer.restorer
        let judge = Judge(claude: Claude(key: key), cache: options.cache)
        let byFile = Dictionary(decisions.map { (URL(fileURLWithPath: $0.source).lastPathComponent, $0) }, uniquingKeysWith: { a, _ in a })
        let work = reading.labels.filter(\.isLabelled).compactMap { label -> (Label, Judgement)? in
            guard let decision = byFile[label.file], decision.extraction != nil else { return nil }
            return (label, decision)
        }
        judged = [:]
        for (step, (label, decision)) in work.enumerated() {
            FileHandle.standardError.write(Data("  judging [\(step + 1)/\(work.count)]\n".utf8))
            let hide = { (text: String) in disguiser.apply(text).text }
            do {
                let verdict = try await judge.judge(expected: label.todos.map { hide($0.text) },
                                                    found: decision.todos.map { hide($0.text) },
                                                    subject: decision.disguise?.subject ?? "")
                judgeCost += verdict.cost
                judged?[label.file] = verdict.pairs.map { ($0.expected, $0.found, restorer.apply($0.reason).text) }
            } catch {
                FileHandle.standardError.write(Data("    \(label.file): \(error) — word stems used instead\n".utf8))
            }
        }
    }

    var result = Report.measure(decisions: decisions, labels: reading.labels, emails: emails, judged: judged)
    if judged != nil { result.judge = Judge.version + " · " + Claude.Model.sonnet.id; result.judgeCost = judgeCost }
    let markdown = Report.text(result, title: "Step 8 · \(options.log.lastPathComponent)")
    try markdown.write(to: options.report, atomically: true, encoding: .utf8)

    // The terminal gets everything but the long list of pairs.
    let summary = markdown.components(separatedBy: "## Every to-do").first ?? markdown
    print("")
    print(summary)
    print("Wrote the full report, with every to-do pairing, to \(options.report.path)")
    print("It is made from real mail and is gitignored; do not share it.")
    print("")
}

// MARK: login

func mailAccount() -> MailAccount {
    let saved = Keychain.accounts()
    if let address = options.account {
        if let host = options.host { return MailAccount(user: address, host: host) }
        if let account = saved.first(where: { $0.user == address }) ?? MailAccount(user: address) { return account }
        fail("which server is \(address) on? Name it with --host, for example --host imap.example.com")
    }
    guard saved.count == 1 else {
        fail(saved.isEmpty
             ? "no mail account saved yet. First: matter-spike login --account you@gmail.com"
             : "more than one account is saved; say which with --account:\n" + saved.map { "  \($0.user)" }.joined(separator: "\n"))
    }
    return options.host.map { MailAccount(user: saved[0].user, host: $0) } ?? saved[0]
}

func login() async throws {
    guard let address = options.account else { fail("which account? matter-spike login --account you@gmail.com") }
    if options.forget {
        try Keychain.delete(account: address)
        print("Removed the saved password for \(address).")
        return
    }
    // Only Gmail and iCloud addresses tell their server; any other needs it named, so the
    // password is never tried on a server it does not belong to.
    guard let account = options.host.map({ MailAccount(user: address, host: $0) }) ?? MailAccount(user: address) else {
        fail("which server is \(address) on? matter-spike login --account \(address) --host imap.example.com\n"
             + "(A Google Workspace address on its own domain: --host imap.gmail.com)")
    }

    var buffer = [CChar](repeating: 0, count: 1024)
    guard let typed = readpassphrase("Password for \(address) on \(account.host) (not shown): ", &buffer, buffer.count, 0) else {
        fail("could not read a password from the terminal")
    }
    var password = String(cString: typed)
    buffer = buffer.map { _ in 0 }
    // Google shows an app password as four groups of four. The spaces are not part of it.
    if account.host == "imap.gmail.com" { password = password.replacingOccurrences(of: " ", with: "") }
    guard !password.isEmpty else { fail("no password typed; nothing saved") }

    print("Checking it with \(account.host)…")
    let client: IMAPClient
    do { client = try await IMAPClient.connect(to: account, password: password) }
    catch { fail("Not saved: \(error)") }
    let folders = (try? await client.folders()) ?? []
    await client.logout()

    try Keychain.save(password, for: account)
    print("")
    print("Logged in, and saved in the Keychain as \"Matterbee IMAP\" · \(address), for \(account.host).")
    print("It is only ever used to read. Matterbee opens folders read-only and never marks mail as read.")
    let names = folders.filter { !$0.attributes.contains("\\noselect") }.map(\.name)
    if !names.isEmpty {
        print("")
        print("Labels and folders on this account (\(names.count)):")
        for name in names.prefix(40) { print("  \(name)\(name.lowercased() == options.label.lowercased() ? "   ← the Matterbee label" : "")") }
        if names.count > 40 { print("  … and \(names.count - 40) more") }
    }
    // Gmail labels are found whatever their case, so `matterbee` is the label too.
    if !names.contains(where: { $0.lowercased() == options.label.lowercased() }) {
        print("")
        print("There is no \"\(options.label)\" label yet. Make one in Gmail, put it on a mail, then run fetch.")
    }
    print("")
}

// MARK: fetch

func fetch() async throws {
    let account = mailAccount()
    let password: String
    do {
        guard let saved = try await MailSecret.secret(for: account) else {
            fail("no password saved for \(account.user). First: matter-spike login --account \(account.user)")
        }
        password = saved
    } catch { fail("could not read the password: \(error)") }

    try await process(source: "\(account.user) · \(account.host)") { spike, pseudonymizer in
        FileHandle.standardError.write(Data("Reading \"\(options.label)\" from \(account.host), read-only…\n".utf8))
        let client = try await IMAPClient.connect(to: account, password: password)
        let result: LabelIntake.Result
        do {
            // What the label has answered is not downloaded again: only the new mail is read.
            let known = options.reclassify ? [] : DailyDoor.done(in: DailyDoor.readLog(options.log))
            result = try await LabelIntake(label: options.label, since: options.since, host: account.host, known: known).run(client) { line in
                FileHandle.standardError.write(Data("  \(line)\n".utf8))
            }
        } catch {
            await client.logout()
            throw error
        }
        await client.logout()
        intake = result
        return spike.run(emails: result.emails, labelled: result.labelled, pseudonymizer: pseudonymizer)
    }
    if options.imports, options.classify, options.dryRun == nil {
        try importLog()
        print("Open the app again to see it: it reads the store when it starts.")
    }
}

// MARK: matters

func openStore() throws -> ModelContext {
    do { return ModelContext(try MatterSchema.container(at: options.store)) }
    catch { fail("cannot open the matter store \(options.store.path): \(error)") }
}

func importLog() throws {
    let judgements = readLog()
    let context = try openStore()
    let profile = try context.fetch(FetchDescriptor<Profile>()).first
    var owner = options.me
    if owner.isEmpty { owner = profile?.names ?? [] }
    if owner.isEmpty {
        // The owner writes more of their own labelled mail than anyone else does.
        let senders = Dictionary(grouping: judgements.map(\.from), by: { $0 }).max { $0.value.count < $1.value.count }?.key ?? ""
        owner = [Email.displayName(in: senders), Email.address(in: senders)].compactMap { $0 }.filter { !$0.isEmpty }
    }
    if let profile { profile.names = owner } else { context.insert(Profile(names: owner)) }
    let summary = try MatterImport.apply(judgements, to: context, owner: owner)
    print("")
    print("\(options.log.path) → \(options.store.path)")
    row("mails added", "\(summary.mails)")
    if summary.mailsAlreadyThere > 0 { row("already there", "\(summary.mailsAlreadyThere)") }
    row("not imported", "\(summary.notImported)  (bulk, no matter, or not classified)")
    row("new matters", "\(summary.mattersNew)")
    row("to-dos", "\(summary.todosNew) new, \(summary.todosAgain) asked again, \(summary.todosDone) done")
    row("appointments", "\(summary.appointments)")
    row("deadlines", "\(summary.deadlines)")
    row("new parties", "\(summary.parties)")
    row("files", "\(summary.documents) attached files noted (the files stay in the mail)")
    row("you", owner.joined(separator: ", ") + (options.me.isEmpty ? "  (change with --me)" : ""))
    print("")
    print("Next: matter-spike matters")
    print("")
}

func findMatter(_ name: String, in context: ModelContext) throws -> Matter {
    let all = try context.fetch(FetchDescriptor<Matter>())
    if let matter = all.first(where: { $0.answers(to: name) }) { return matter }
    fail("no matter called \"\(name)\". There are:\n" + all.map { "  \($0.name)" }.sorted().joined(separator: "\n"))
}

func matters() throws {
    let context = try openStore()
    if let name = options.words.first { return try status(of: findMatter(name, in: context)) }

    let everything = try context.fetch(FetchDescriptor<Matter>()).sorted { ($0.entries?.count ?? 0) > ($1.entries?.count ?? 0) }
    guard !everything.isEmpty else { fail("the store is empty. First: matter-spike import --log <log>") }
    let all = everything.filter { !$0.isClosed }
    defer {
        let closed = everything.filter(\.isClosed)
        if !closed.isEmpty {
            print("Closed (\(closed.count)):")
            for matter in closed {
                let new = MatterStatus(matter).mailsSinceClosed.count
                print("  \(matter.name)   closed \(matter.closedAt.map(MatterStatus.day) ?? "")\(new > 0 ? " · \(new) new mails since" : "")")
            }
            print("")
        }
    }
    print("")
    print("  \("matter".padding(toLength: 30, withPad: " ", startingAt: 0))mails  open to-dos (mine · ours · waiting)  appointments")
    print("  " + String(repeating: "─", count: 90))
    for matter in all {
        let open = matter.openTodos
        let count = { (owner: Todo.Owner) in open.filter { $0.owner == owner }.count }
        let name = String(matter.name.prefix(28)).padding(toLength: 30, withPad: " ", startingAt: 0)
        let mails = "\(matter.entries?.count ?? 0)".padding(toLength: 7, withPad: " ", startingAt: 0)
        let todos = "\(open.count)  (\(count(.me)) · \(count(.we)) · \(count(.other)))".padding(toLength: 38, withPad: " ", startingAt: 0)
        print("  \(name)\(mails)\(todos)\(matter.appointments?.count ?? 0)")
    }
    print("")
    print("One matter in full: matter-spike matters <name>")
    print("")
}

func status(of matter: Matter) {
    let today = Options.day(ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate]))
    print("")
    print(matter.name + (matter.aliases.isEmpty && matter.name == matter.key ? "" : "   (also: \(([matter.key] + matter.aliases).filter { $0 != matter.name }.joined(separator: ", ")))"))
    print("\(matter.entries?.count ?? 0) mails")

    let open = matter.openTodos.sorted { ($0.due ?? "9999") < ($1.due ?? "9999") }
    for (owner, title) in [(Todo.Owner.me, "Mine"), (.we, "Ours"), (.other, "Waiting for"), (.unknown, "Not sure whose")] {
        let todos = open.filter { $0.owner == owner }
        guard !todos.isEmpty else { continue }
        print("")
        print("\(title) (\(todos.count))")
        for todo in todos {
            let again = todo.sources.count > 1 ? "  ×\(todo.sources.count)" : ""
            print("  ☐ \(todo.text)\(todo.due.map { "  · bis \($0)" } ?? "")\(again)")
        }
    }
    let done = (matter.todos ?? []).filter(\.isDone)
    if !done.isEmpty { print(""); print("Done: \(done.count)") }

    let appointments = (matter.appointments ?? []).sorted { ($0.day, $0.time ?? "") < ($1.day, $1.time ?? "") }
    if !appointments.isEmpty {
        print("")
        print("Appointments (\(appointments.count))")
        for item in appointments {
            let past = Options.day(item.day).map { day in today.map { day < $0 } ?? false } ?? false
            print("  \(past ? " " : "•") \(item.day)\(item.time.map { " \($0)" } ?? "")  \(item.what)\(item.place.map { " · \($0)" } ?? "")")
        }
    }
    let deadlines = (matter.deadlines ?? []).sorted { $0.day < $1.day }
    if !deadlines.isEmpty {
        print("")
        print("Deadlines (\(deadlines.count))")
        for item in deadlines { print("  \(item.day)  \(item.what)") }
    }
    let memberships = (matter.memberships ?? []).filter { $0.party != nil }.sorted { ($0.party?.name ?? "") < ($1.party?.name ?? "") }
    if !memberships.isEmpty {
        print("")
        print("Parties (\(memberships.count))")
        for membership in memberships {
            guard let party = membership.party else { continue }
            print("  \(party.name)\(membership.role.map { " · \($0)" } ?? "")")
        }
        let rules = (try? matter.modelContext?.fetch(FetchDescriptor<Rule>())) ?? []
        let suggestions = PartyBook.suggestions(in: matter, rules: rules)
        if !suggestions.isEmpty {
            print("  → \(suggestions.count) may be the same as another: matter-spike parties \(matter.key)")
        }
    }
    print("")
}

func merge() throws {
    guard options.words.count == 2 else { fail("merge needs two matters: matter-spike merge <matter> <into matter>") }
    let context = try openStore()
    let from = try findMatter(options.words[0], in: context)
    let into = try findMatter(options.words[1], in: context)
    guard from !== into else { fail("that is the same matter") }
    let name = from.name
    let mails = from.entries?.count ?? 0
    into.absorb(from, in: context)
    try context.save()
    print("Merged \(name) (\(mails) mails) into \(into.name). Mail filed under \"\(name)\" will arrive there too.")
}

func rename() throws {
    guard options.words.count == 2 else { fail("rename needs a matter and a name: matter-spike rename <matter> <new name>") }
    let context = try openStore()
    let matter = try findMatter(options.words[0], in: context)
    let old = matter.name
    matter.rename(to: options.words[1])
    try context.save()
    print("Renamed \(old) to \(matter.name).")
}

// MARK: parties

func parties() throws {
    guard let name = options.words.first else { fail("which matter? matter-spike parties <matter>") }
    let context = try openStore()
    let matter = try findMatter(name, in: context)
    let memberships = (matter.memberships ?? []).filter { $0.party != nil }.sorted { ($0.party?.name ?? "") < ($1.party?.name ?? "") }
    print("")
    print("\(matter.name) · \(memberships.count) parties")
    print("")
    for membership in memberships {
        guard let party = membership.party else { continue }
        let other = party.matters.filter { $0 !== matter }.map(\.name)
        print("  \(party.name)\(membership.role.map { " · \($0)" } ?? "")   \(membership.mentions)×")
        let also = party.otherSpellings.filter { $0 != party.name }
        if !also.isEmpty { print("      also written as: \(also.joined(separator: "; "))") }
        if !other.isEmpty { print("      also in: \(other.joined(separator: ", "))") }
    }
    let suggestions = PartyBook.suggestions(in: matter, rules: try context.fetch(FetchDescriptor<Rule>()))
    if !suggestions.isEmpty {
        print("")
        print("Same person? (\(suggestions.count))")
        for (number, suggestion) in suggestions.enumerated() {
            print("  \(number + 1). \(suggestion.party.name)  →  \(suggestion.into.name)")
            print("     why: \(suggestion.reason)")
        }
        print("")
        print("  Yes:  matter-spike same \(matter.key) <number>")
        print("  No:   matter-spike notsame \(matter.key) \"<name>\" \"<other name>\"")
    }
    print("")
}

func party(_ name: String, in matter: Matter) -> Party {
    let wanted = name.lowercased()
    let parties = matter.parties
    if let party = parties.first(where: { $0.name.lowercased() == wanted || $0.spellings.contains { $0.lowercased() == wanted } })
        ?? parties.first(where: { PartyNames.key($0.name) == PartyNames.key(name) }) {
        return party
    }
    fail("no party called \"\(name)\" in \(matter.name). There are:\n" + parties.map { "  \($0.name)" }.sorted().joined(separator: "\n"))
}

func origin(_ matter: Matter) -> String {
    let day = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none)
    return "you, in \(matter.key), \(day)"
}

func same() throws {
    guard let name = options.words.first else { fail("which matter? matter-spike same <matter> <party> <same as party>") }
    let context = try openStore()
    let matter = try findMatter(name, in: context)
    var pairs: [(Party, Party)] = []
    let numbers = options.words.dropFirst().compactMap { Int($0) }
    if !numbers.isEmpty, numbers.count == options.words.count - 1 {
        // All the numbers are read against the same list, so accepting 2 does not renumber 3.
        let suggestions = PartyBook.suggestions(in: matter, rules: try context.fetch(FetchDescriptor<Rule>()))
        for number in numbers {
            guard number >= 1, number <= suggestions.count else { fail("there is no suggestion \(number); see matter-spike parties \(matter.key)") }
            pairs.append((suggestions[number - 1].party, suggestions[number - 1].into))
        }
    } else if options.words.count == 3 {
        pairs = [(party(options.words[1], in: matter), party(options.words[2], in: matter))]
    } else {
        fail("matter-spike same <matter> <party> <same as party>, or <matter> <suggestion numbers>")
    }
    var merged: Set<ObjectIdentifier> = []
    for (from, into) in pairs {
        guard from !== into, !merged.contains(ObjectIdentifier(from)) else { continue }
        let fromName = from.name
        context.insert(Rule(.sameParty, subject: fromName, object: into.name, matterKey: matter.key, origin: origin(matter)))
        PartyBook.merge(from, into: into, context: context)
        merged.insert(ObjectIdentifier(from))
        print("  \(fromName) is \(into.name) now")
    }
    try context.save()
    print("Kept as rules, so the next mail's spelling goes there too. See them, or undo one, with matter-spike rules.")
}

func notSame() throws {
    guard options.words.count == 3 else { fail("matter-spike notsame <matter> <party> <other party>") }
    let context = try openStore()
    let matter = try findMatter(options.words[0], in: context)
    let a = party(options.words[1], in: matter), b = party(options.words[2], in: matter)
    context.insert(Rule(.notSameParty, subject: a.name, object: b.name, matterKey: matter.key, origin: origin(matter)))
    try context.save()
    print("\(a.name) and \(b.name) are two parties. Matterbee will not ask again.")
}

func rules() throws {
    let context = try openStore()
    var all = try context.fetch(FetchDescriptor<Rule>()).sorted { $0.createdAt < $1.createdAt }
    if let number = options.deleteRule {
        guard number >= 1, number <= all.count else { fail("there is no rule \(number)") }
        context.delete(all.remove(at: number - 1))
        try context.save()
        print("Rule \(number) is gone.")
    }
    for (number, isOn) in [(options.switchOff, false), (options.switchOn, true)] {
        guard let number else { continue }
        guard (1...max(1, all.count)).contains(number), number <= all.count else { fail("there is no rule \(number)") }
        all[number - 1].isOn = isOn
        try context.save()
        print(isOn ? "Rule \(number) is on again." : "Rule \(number) is off. Mail that comes next is no longer merged by it; what is merged already stays merged.")
    }
    print("")
    guard !all.isEmpty else { print("No rules yet. They come from what you tell Matterbee: same, notsame."); print(""); return }
    print("What you told Matterbee (\(all.count))")
    for (number, rule) in all.enumerated() {
        let what = switch rule.kind {
        case .sameParty: "\(rule.subject) is \(rule.object)"
        case .notSameParty: "\(rule.subject) is not \(rule.object)"
        case .partyName: "\(rule.subject) is called \(rule.object)"
        case .notInMatter: "\(rule.subject) is not part of \(rule.matterKey ?? "the matter")"
        case nil: "a rule of a newer Matterbee (\(rule.kindRaw)), left alone"
        }
        print("  \(number + 1). \(rule.isOn ? "on " : "off") \(what)")
        print("        from \(rule.origin) · used \(rule.fired)×")
    }
    print("")
}

// MARK: ask

@MainActor
func ask() async throws {
    guard let question = options.words.last else { fail("matter-spike ask [<matter>] \"<question>\"") }
    let context = try openStore()
    let all = try context.fetch(FetchDescriptor<Matter>())
    let scope = options.words.count >= 2 ? [try findMatter(options.words[0], in: context)] : all.filter { !$0.isClosed && !$0.openTodos.isEmpty }
    let today = MatterStatus.day(Date())
    let facts = FactSheet.facts(for: scope, today: today)
    let owner = try context.fetch(FetchDescriptor<Profile>()).first?.names.first
    print("")
    print("Sieht: \(facts.seen)")
    if options.dryRun != nil {
        let prepared = try AssistantAsk.prepare(question: question, inHand: nil, earlier: [], facts: facts, owner: owner,
                                                today: today, mapping: options.mapping, saves: false)
        print(prepared.sent)
        print("")
        row("characters", "\(prepared.sent.count)")
        row("new names", "\(prepared.newNames)  (not saved: dry run)")
        let leaks = prepared.leaks(prepared.pseudonymizer.entries)
        row("originals left in", leaks.isEmpty ? "none" : "\(leaks.count): " + leaks.prefix(20).joined(separator: ", "))
        print("")
        print("Dry run: nothing was sent.")
        return
    }
    guard let key = Claude.key() else { fail(Claude.Failure.noKey.description) }
    let answer = try await AssistantAsk.ask(question: question, inHand: nil, earlier: [], facts: facts, owner: owner,
                                            today: today, mapping: options.mapping, claude: Claude(key: key))
    print("")
    for line in answer.reply.lines { print("  \(line.text)   [\(line.cites.joined(separator: " "))]") }
    if let missing = answer.reply.notInFacts { print("  ? \(missing)") }
    for card in answer.reply.cards {
        print("  ☐ \(card.kind.rawValue): \([card.todo, card.party, card.into, card.from].compactMap { $0 }.joined(separator: " → ")) \(card.text) (\(card.owner))")
        print("      \(card.reason)")
    }
    print("")
    print(String(format: "  %.0f s · $%.3f · %d new names disguised", answer.seconds, answer.cost, answer.newNames))
    print("")
}

// MARK: owner

func setOwner() throws {
    guard options.words.count == 3, let owner = Todo.Owner(rawValue: options.words[2]) else {
        fail("matter-spike owner <matter> \"<words of the to-do>\" me|we|other|unknown")
    }
    let context = try openStore()
    let matter = try findMatter(options.words[0], in: context)
    let words = options.words[1].lowercased()
    let found = (matter.todos ?? []).filter { $0.text.lowercased().contains(words) }
    guard found.count == 1, let todo = found.first else {
        fail(found.isEmpty ? "no to-do in \(matter.name) has \"\(options.words[1])\" in it"
             : "\(found.count) to-dos have that in them; say more of the words:\n" + found.map { "  \($0.text)" }.joined(separator: "\n"))
    }
    let before = todo.owner
    todo.owner = owner
    try context.save()
    print("\(todo.text)\n  \(before.rawValue) → \(owner.rawValue)")
}

// MARK: close

/// `matter-spike digest [--model opus|mistral] [--limit n] [--yes]`: digests for mail sorted in
/// before the extraction wrote them. Each mail is read again from the label, read-only; its
/// text stays on this Mac; only the disguised mail goes out, and only after a yes.
@MainActor func digest() async throws {
    let context = try openStore()
    // `--redo-language`: the digests that are not in their mail's language.
    var entries = options.redoLanguage ? DigestBackfill.inAnotherLanguage(in: context, store: options.store)
                                                        : DigestBackfill.missing(in: context)
    // `--title <words>`: only mail whose subject has them.
    if let title = CommandLine.arguments.firstIndex(of: "--title").map({ CommandLine.arguments[$0 + 1].lowercased() }) {
        entries = entries.filter { $0.title.lowercased().contains(title) }
    }
    if let limit = options.limit { entries = Array(entries.prefix(limit)) }
    guard !entries.isEmpty else { print("Every mail has its digest."); return }
    // `--show <n>`: what the first n would send, disguised. Nothing is sent.
    if let show = CommandLine.arguments.firstIndex(of: "--show").flatMap({ Int(CommandLine.arguments[$0 + 1]) }) {
        for entry in entries.prefix(show) {
            print("── \(entry.title) — digest now: \(entry.digest ?? "none")")
            print(DigestBackfill.preview(entry, store: options.store, mapping: options.mapping) ?? "(no text kept)")
        }
        return
    }
    let model = options.model
    guard let key = Claude.key(for: model) else {
        fail("no key for \(model.label): put \(model.keyName)=… into .env, or paste it in the app's settings")
    }
    let account = mailAccount()
    guard let password = try await MailSecret.secret(for: account) else {
        fail("no password saved for \(account.user). First: matter-spike login --account \(account.user)")
    }
    let estimate = DigestBackfill.estimate(entries.count, model: model)
    FileHandle.standardError.write(Data(String(format: "\n%d mails without a digest, about $%.2f with %@. Read again from the label, read-only; the text stays on this Mac.\n",
                                               entries.count, estimate, model.label).utf8))
    if !options.yes {
        FileHandle.standardError.write(Data("Send them? [y/N] ".utf8))
        let answer = readLine()?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
        guard ["y", "yes", "j", "ja"].contains(answer) else { fail("Nothing sent. (--yes skips this question.)") }
    }
    let result = try await DigestBackfill.run(entries, account: account, password: password, store: options.store,
                                              mapping: options.mapping, claude: Claude(key: key), model: model, context: context) { done, total in
        FileHandle.standardError.write(Data("\r  \(done)/\(total)".utf8))
    }
    print(String(format: "\n%d digests written, %d mails with nothing to keep, %d no longer in the mailbox · $%.3f",
                 result.written, result.empty, result.gone, result.cost))
}

func close() throws {
    guard let name = options.words.first else { fail("which matter? matter-spike close <matter> [--done]") }
    let context = try openStore()
    let matter = try findMatter(name, in: context)
    guard !matter.isClosed else { fail("\(matter.name) is closed already, since \(matter.closedAt.map(MatterStatus.day) ?? "")") }
    let open = matter.openTodos.count
    matter.close(markingOpenDone: options.closesDone)
    try context.save()
    print("Closed \(matter.name). Nothing is deleted; matter-spike reopen \(matter.key) opens it again.")
    if open > 0 {
        print(options.closesDone ? "  \(open) open to-dos ticked; reopening opens them again."
                                 : "  \(open) to-dos are still open in it. --done would have ticked them.")
    }
}

func reopen() throws {
    guard let name = options.words.first else { fail("which matter? matter-spike reopen <matter>") }
    let context = try openStore()
    let matter = try findMatter(name, in: context)
    guard matter.isClosed else { fail("\(matter.name) is not closed") }
    matter.reopen()
    try context.save()
    print("\(matter.name) is open again, with \(matter.openTodos.count) open to-dos.")
}

// MARK: party

func editParty() throws {
    guard options.words.count == 2, options.newPartyName != nil || options.role != nil else {
        fail("matter-spike party <matter> \"<name>\" [--name \"<new name>\"] [--role \"<role>\"]")
    }
    let context = try openStore()
    let matter = try findMatter(options.words[0], in: context)
    let found = party(options.words[1], in: matter)
    if let name = options.newPartyName, name != found.name {
        let old = found.name
        found.rename(to: name)
        context.insert(Rule(.partyName, subject: old, object: name, matterKey: matter.key, origin: origin(matter)))
        print("  \(old) → \(name)")
    }
    if let role = options.role, let membership = matter.membership(of: found) {
        membership.setRole(role)
        print("  role in \(matter.name): \(role)")
    }
    try context.save()
}

// MARK: screenshot

func readScreenshot() throws {
    guard let path = options.words.first else { fail("matter-spike screenshot <image>") }
    let owner = (try? openStore().fetch(FetchDescriptor<Profile>()).first?.names.first) ?? "Ich"
    let look = try ScreenshotDoor(besides: options.store).look(at: URL(fileURLWithPath: path), owner: owner ?? "Ich")
    if options.show > 0 {
        // Where each line sits, pseudonymised: enough to see how the chat was taken apart
        // without reading it in the clear.
        var mapping = Pseudonymizer.Mapping()
        if let data = try? Data(contentsOf: ScreenshotDoor(besides: options.store).mapping) { mapping = (try? JSONDecoder().decode(Pseudonymizer.Mapping.self, from: data)) ?? mapping }
        let disguiser = (look.report.pseudonymizer ?? Pseudonymizer(mode: .placeholder, entries: mapping.placeholder)).disguiser
        for line in try ScreenText.lines(in: URL(fileURLWithPath: path)).lines {
            print(String(format: "x %.2f–%.2f  y %.3f–%.3f  h %.3f  ", line.box.minX, line.box.maxX, line.top, line.bottom, line.box.height)
                  + disguiser.apply(line.text).text.prefix(40))
        }
    }
    let chat = look.transcript
    print("")
    print("\(chat.title ?? "(no name)")\(chat.subtitle.map { " — \($0)" } ?? "")")
    for note in chat.notes { print("  ! \(note)") }
    for message in chat.messages {
        let who = message.side == .mine ? "  → me" : "  ← \(message.speaker ?? "them")"
        print("\(who.padding(toLength: 16, withPad: " ", startingAt: 0)) \(message.day.map { "[\($0)] " } ?? "")\(message.time.map { "\($0) " } ?? "")\(message.text)")
    }
    if !chat.leftOut.isEmpty {
        print("")
        print("Left out:")
        for item in chat.leftOut { print("  \(item.text)   (\(item.why))") }
    }
    print("")
    print("Would be sent, pseudonymised:")
    print(look.sent)
    print("")
    print(look.earlier == nil ? String(format: "Classifying it would cost about $%.2f. Nothing was sent.", look.estimate)
                              : "Answered before: classifying it again costs nothing. Nothing was sent.")
    print("")
}
