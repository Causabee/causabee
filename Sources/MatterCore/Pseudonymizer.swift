import Foundation

/// Step 4 of the spike: replace everything identifiable before any of it is sent, and keep the
/// way back on the device.
///
/// Two modes, because question three of the plan is which one costs the model less accuracy:
///
/// - `placeholder` writes `[Person A]`, `[Company B]`. Nothing about the original survives, and
///   nothing about the stand-in can be mistaken for a real person.
/// - `standin` writes a realistic replacement of the same shape: a full name for a full name,
///   `Frau` kept in front of a surname, a legal form kept on a company, a house number on a
///   street. A model reads it as ordinary mail.
///
/// Two things make this more than a find-and-replace of what step 3 found.
///
/// **Everything learned is replaced everywhere.** The tagger finds a name in one sentence and
/// misses it in the next; a disguise that only covers what was found in *this* mail leaks the
/// rest. So a folder is learned first, and every mail is then disguised with the whole mapping.
///
/// **A name is learned in parts.** `Sebastian Süß` also teaches `Süß` and `Sebastian`;
/// `Honigtauer Str. 14` teaches `Honigtauer`; `10437 Berlin` teaches `Berlin`. That is how
/// a bare surname in a greeting, or the street written without its dot, is still covered — and
/// in `standin` mode it keeps relationships readable: `Frau Berger` and `Hausverwaltung Berger
/// GmbH` become the same new surname, because they were the same surname.
public struct Pseudonymizer: Sendable {
    public enum Mode: String, Codable, Sendable, CaseIterable {
        case placeholder, standin
    }

    public struct Entry: Codable, Equatable, Sendable {
        public var kind: Entity.Kind
        public var original: String
        public var standIn: String
        /// Set when the entry was made from part of another — the surname out of a full name, the
        /// street out of an address — so the mapping says where every line came from.
        public var partOf: String?

        enum CodingKeys: String, CodingKey { case kind, original, standIn = "stand_in", partOf = "part_of" }
    }

    /// `mapping.json`: both modes, so a comparison run of one does not throw away the other.
    /// Made from real mail, gitignored, and never sent anywhere.
    public struct Mapping: Codable, Equatable, Sendable {
        public var version = Self.current
        public var placeholder: [Entry] = []
        public var standin: [Entry] = []

        /// 2: in placeholder mode, people who share only a first or a last name no longer share a tag.
        /// 3: a role in front of a name — `Hausmeister Brenner` — is a title, not a first name.
        public static let current = 3

        public init() {}

        /// Brings a mapping from an earlier version up to this one, and says how many people it
        /// had to tell apart. The people are learned again, full names first; nothing else changes.
        @discardableResult
        public mutating func upgrade() -> Int {
            guard version < Self.current else { return 0 }
            var changed = 0
            if version < 2 {
                let before = Set(placeholder.filter { $0.kind == .person }.compactMap { Pseudonymizer.personTag($0.standIn) }).count
                placeholder = Pseudonymizer.relearningPeople(placeholder)
                changed += Set(placeholder.filter { $0.kind == .person }.compactMap { Pseudonymizer.personTag($0.standIn) }).count - before
            }
            if version < 3 {
                // Only the entries with a role in them, so every other tag keeps its letter and the
                // model's answers for mail that never mentioned one stay in the cache.
                let before = placeholder
                placeholder = Pseudonymizer.rolesAsTitles(placeholder)
                let after = Set(placeholder.map { $0.original + "\u{0}" + $0.standIn })
                changed += before.filter { !after.contains($0.original + "\u{0}" + $0.standIn) }.count
            }
            version = Self.current
            return changed
        }

        public subscript(mode: Mode) -> [Entry] {
            get { mode == .placeholder ? placeholder : standin }
            set { if mode == .placeholder { placeholder = newValue } else { standin = newValue } }
        }
    }

    public let mode: Mode
    public private(set) var entries: [Entry] = []
    private var index: [String: Int] = [:]
    /// Placeholder mode: each full name's tag, by first and last name, so `Albers, Sebastian`
    /// finds `Sebastian Albers`.
    private var fullNames: [String: String] = [:]
    /// Every original, and every word of one. A stand-in is never picked from here, or restoring
    /// would have two answers for the same word.
    private var forbidden: Set<String> = []
    /// Only while learning: the folder's words, how often each one sat inside something the
    /// detector called an entity, whether the entity being learned came from a rule, and the
    /// parts that were not learned because they are ordinary words.
    private var vocabulary = Vocabulary([])
    private var insideEntities: [String: Int] = [:]
    private var trusted = true
    private var skippedParts: [Skip] = []

    public init(mode: Mode, entries: [Entry] = []) {
        self.mode = mode
        for entry in entries { add(entry) }
    }

    public func standIn(for original: String) -> String? {
        index[Self.key(original)].map { entries[$0].standIn }
    }

    // MARK: Learning

    /// What the detector found that the disguise left alone, and why. A false positive from the
    /// tagger — `Sie`, `Mit`, `IBAN` — replaced in every mail would ruin the text for nothing,
    /// but a skipped word is exactly where a missed name would hide, so every one is reported.
    public struct Skip: Codable, Equatable, Sendable {
        public var text: String
        public var reason: String
    }

    /// Learns everything in `entities`, all mails at once. Order matters and is fixed here:
    /// people before companies, so a company named after a person takes that person's new
    /// surname rather than the other way round; and longer names before shorter ones, so
    /// `Annegret Berger` is known before a bare `Berger` has to be guessed at.
    ///
    /// `vocabulary` is every word of the folder. It is how an ordinary word is told from a name
    /// without a dictionary: see `isOrdinary`.
    @discardableResult
    public mutating func learn(_ entities: [Entity], vocabulary: Vocabulary = Vocabulary([])) -> [Skip] {
        self.vocabulary = vocabulary
        insideEntities = [:]
        skippedParts = []
        for entity in entities {
            for word in Self.words(entity.text) { insideEntities[Self.key(word), default: 0] += 1 }
        }

        var skipped: [Skip] = []
        var usable: [Entity] = []
        for var entity in entities {
            if let reason = Self.reasonToSkip(entity) {
                skipped.append(.init(text: entity.text, reason: reason))
                continue
            }
            if entity.source == .onDevice {
                switch trimmed(entity.text) {
                case .success(let text): entity.text = text
                case .failure(let skip): skipped.append(.init(text: entity.text, reason: skip.reason)); continue
                }
            }
            usable.append(entity)
        }
        for entity in usable {
            forbidden.insert(Self.key(entity.text))
            for word in Self.words(entity.text) { forbidden.insert(Self.key(word)) }
        }
        let ordered = usable.enumerated().sorted { a, b in
            let (x, y) = (a.element, b.element)
            if Self.priority(x.kind) != Self.priority(y.kind) { return Self.priority(x.kind) < Self.priority(y.kind) }
            if Self.fullness(x.kind, x.text) != Self.fullness(y.kind, y.text) { return Self.fullness(x.kind, x.text) > Self.fullness(y.kind, y.text) }
            if Self.words(x.text).count != Self.words(y.text).count {
                return Self.words(x.text).count > Self.words(y.text).count
            }
            return a.offset < b.offset
        }
        for (_, entity) in ordered {
            trusted = entity.source == .rule
            // A single word from the tagger faces the frequency test only now, after every longer
            // name is known: `Mareike` alone is covered already if `Mareike Sandvoss` was learned.
            if !trusted, Self.words(entity.text).count == 1, standIn(for: entity.text) == nil, isOrdinary(entity.text) {
                skipped.append(.init(text: entity.text, reason: "an ordinary word in this folder"))
                continue
            }
            learn(entity.kind, entity.text)
        }
        trusted = true
        var seen: Set<String> = []
        return (skipped + skippedParts).filter { seen.insert($0.text).inserted }
    }

    /// Is this an ordinary word rather than a name? Two tests.
    ///
    /// - It is on the short list of words the tagger is known to mistake: greetings, weekdays,
    ///   months, pronouns.
    /// - For the tagger's own guesses only: it appears at least five times, and the detector
    ///   called it part of a name in fewer than one in seven of them. `Rückfragen`, `Kosten`,
    ///   `Kalender` are nouns, capitalised like names, and the tagger passes over them nearly every
    ///   time. A real name scores far higher even in a long thread, where it is quoted over and
    ///   over in lines the tagger never looks at closely — on the first real folder, names came out
    ///   between 0.19 and 0.40 and ordinary nouns between 0.01 and 0.12.
    ///
    /// Pronouns and articles are mostly gone before this is asked: the detector drops any word
    /// the grammar tagger says a name is not made of.
    ///
    /// The second test is never applied to what a rule found. A name out of a `From:` line is a
    /// name however rarely the tagger agrees, and `Honigtauer` — a street, and the matter — is
    /// written bare far more often than it is found.
    func isOrdinary(_ word: String) -> Bool {
        if Self.isListed(word) { return true }
        guard !trusted else { return false }
        let key = Self.key(word)
        let seen = vocabulary.capitalised[key, default: 0]
        return seen >= 5 && Double(insideEntities[key, default: 0]) / Double(seen) < 0.15
    }

    static func isListed(_ word: String) -> Bool {
        let key = key(word)
        return commonWords.contains(key) || greetings.contains(key) || calendarWords.contains(key) || honorifics.contains(key)
    }

    struct Skipped: Error { var reason: String }

    /// The tagger's span, with the ordinary words at either end taken off: `Liebe Frau Stein`
    /// is `Frau Stein`, `Bis Montag` is nothing, `Nach Mannheim` is `Mannheim`. A span with a
    /// lowercase word in it, or an ordinary word in the middle — `Sie behalten jederzeit den` —
    /// is a sentence the tagger misread, not a name, and is dropped whole.
    mutating func trimmed(_ text: String) -> Result<String, Skipped> {
        trusted = false
        defer { trusted = true }
        var tokens = Self.words(text)
        // A span that is mostly lowercase or common words is a piece of a sentence: `wir Ihnen`,
        // `Sie diesen Kalender`. One lowercase word beside a name is not — people write their own
        // surname in lowercase (`Elisa ueckerhof`), and `von` belongs in `Jonas von Ostwerth`.
        func filler(_ token: String) -> Bool {
            let key = Self.key(token)
            guard !Self.particles.contains(key), !Self.honorifics.contains(key) else { return false }
            return token.first?.isLowercase == true || Self.isListed(token)
        }
        if tokens.filter(filler).count * 2 > tokens.count {
            return .failure(.init(reason: "a misread sentence, not a name"))
        }
        // Only the word lists trim a span of several words. How often the tagger found a word is
        // a fair test of a word on its own, and a poor one of a word beside a name: `Christian`
        // scores low across a folder that mentions many Christians, and `Christian Weddig` is a
        // person all the same.
        func removable(_ token: String) -> Bool {
            let key = Self.key(token)
            return !Self.honorifics.contains(key) && !Self.particles.contains(key) && Self.isListed(token)
        }
        while let first = tokens.first, removable(first) { tokens.removeFirst() }
        while let last = tokens.last, removable(last) || Self.honorifics.contains(Self.key(last)) { tokens.removeLast() }
        guard tokens.contains(where: { !Self.honorifics.contains(Self.key($0)) }) else {
            return .failure(.init(reason: "only ordinary words"))
        }
        if tokens.dropFirst().dropLast().contains(where: removable) {
            return .failure(.init(reason: "a misread sentence, not a name"))
        }
        let rest = tokens.joined(separator: " ")
        if tokens.count == 1, rest.first?.isLowercase == true { return .failure(.init(reason: "lowercase, so an ordinary word")) }
        return .success(rest)
    }

    /// A part of a name is learned unless it is on the word lists — `Liebe Frau` never teaches
    /// `Frau`, `info Hummelhaus` never teaches `info`. The folder-frequency test is not asked
    /// here: a surname the tagger rarely finds on its own is still a surname when it arrives
    /// attached to a first name, and leaving it out is exactly how a bare `Brenner` leaks.
    mutating func recordPart(_ kind: Entity.Kind, _ part: String, _ standIn: String, of original: String) {
        guard part.count >= 3, part != original else { return }
        if Self.isListed(part) {
            skippedParts.append(.init(text: part, reason: "part of \(original), but a common word"))
            return
        }
        record(kind, part, standIn, partOf: original)
    }

    /// A full name before a name in one part, so that `Sebastian Albers` and `Sebastian Süß` are
    /// both known as people before a bare `Sebastian` or `Herr Albers` has to be placed.
    static func fullness(_ kind: Entity.Kind, _ text: String) -> Int {
        guard kind == .person else { return 0 }
        let name = nameParts(text)
        return name.given != nil && name.family != nil ? 2 : 1
    }

    static func priority(_ kind: Entity.Kind) -> Int {
        switch kind {
        case .person: 0
        case .organization: 1
        case .email: 2
        case .street, .postalCity: 3
        case .place: 4
        case .phone, .iban, .reference: 5
        }
    }

    /// Only the tagger's guesses are ever skipped. A rule found what it found by shape, and an
    /// IBAN is an IBAN however short the sentence around it.
    static func reasonToSkip(_ entity: Entity) -> String? {
        guard entity.source == .onDevice else { return nil }
        let text = entity.text.trimmed
        if text.contains(where: \.isNumber) { return "a name with digits in it is not a name" }
        guard words(text).count == 1 else { return nil }
        if text.count < 3 { return "too short to be a name" }
        if let first = text.first, first.isLowercase { return "lowercase, so an ordinary word" }
        if commonWords.contains(key(text)) { return "a common word the tagger read as a name" }
        return nil
    }

    @discardableResult
    mutating func learn(_ kind: Entity.Kind, _ text: String, partOf: String? = nil) -> String? {
        let original = text.trimmed
        guard original.count >= 2 else { return nil }
        if let known = self.standIn(for: original) { return known }

        // `Süß, Sebastian (Radwerk Berlin GmbH)` is a person and a company, and each half is
        // learned as what it is.
        if let open = original.firstIndex(of: "("), let close = original.lastIndex(of: ")"), open < close {
            let outer = (String(original[..<open]) + String(original[original.index(after: close)...])).trimmed
            let inner = String(original[original.index(after: open)..<close]).trimmed
            guard let outerStandIn = learn(kind, outer), let innerStandIn = learn(.organization, inner)
            else { return nil }
            return record(kind, original, "\(outerStandIn) (\(innerStandIn))", partOf: partOf)
        }
        if original.contains("@"), kind != .email { return learn(.email, original, partOf: partOf) }

        // `Jan Kramer via TestFlight` is a person and the service that sent on their behalf.
        if kind == .person, let via = original.range(of: " via ", options: .caseInsensitive) {
            let person = String(original[..<via.lowerBound]).trimmed
            let service = String(original[via.upperBound...]).trimmed
            guard let personStandIn = learn(.person, person) else { return nil }
            let serviceStandIn = learn(.organization, service) ?? service
            return record(kind, original, "\(personStandIn) via \(serviceStandIn)", partOf: partOf)
        }

        switch kind {
        case .person: return person(original, partOf: partOf)
        case .organization: return organization(original, partOf: partOf)
        case .place: return record(.place, original, pickName(.place), partOf: partOf)
        case .email: return email(original, partOf: partOf)
        case .street: return street(original, partOf: partOf)
        case .postalCity: return postalCity(original, partOf: partOf)
        case .phone:
            return record(.phone, original, mode == .placeholder ? placeholder(.phone) : Self.phone(original), partOf: partOf)
        case .iban:
            return record(.iban, original, mode == .placeholder ? placeholder(.iban) : Self.iban(original), partOf: partOf)
        case .reference:
            return record(.reference, original, placeholder(.reference), partOf: partOf)
        }
    }

    // MARK: People

    mutating func person(_ original: String, partOf: String?) -> String? {
        let name = Self.nameParts(original)
        guard name.family != nil || name.given != nil else { return nil }

        let standIn: String
        if mode == .placeholder {
            // One tag for the person however they are written; a `Frau` stays readable. A full
            // name is one person, and only the same first and last name are the same person:
            // `Sebastian Süß` is not `Sebastian Albers`, and `Greta Kramer` is not `Jan Kramer`.
            // Sharing a tag through one shared word made the way back give the wrong name.
            let tag: String
            if let given = name.given, let family = name.family {
                tag = fullNames[Self.personKey(given, family)] ?? placeholder(.person)
                standIn = [name.title, tag].compactMap { $0 }.joined(separator: " ")
                record(.person, original, standIn, partOf: partOf)
                for part in [given, family] { recordSharedPart(part, tag, of: original) }
            } else {
                let part = name.given ?? name.family ?? original
                tag = self.standIn(for: part).flatMap(Self.personTag) ?? placeholder(.person)
                standIn = [name.title, tag].compactMap { $0 }.joined(separator: " ")
                record(.person, original, standIn, partOf: partOf)
                recordPart(.person, part, tag, of: original)
            }
            return standIn
        }

        let given = name.given.map { self.standIn(for: $0) ?? pickName(.givenName) }
        let family = name.family.map { self.standIn(for: $0) ?? pickName(.person) }
        switch (given, family) {
        case let (given?, family?): standIn = name.commaFirst ? "\(family), \(given)" : "\(given) \(family)"
        case let (given?, nil): standIn = given
        case let (nil, family?): standIn = family
        default: return nil
        }
        let titled = [name.title, standIn].compactMap { $0 }.joined(separator: " ")
        record(.person, original, titled, partOf: partOf)
        if let part = name.given, let new = given { recordPart(.person, part, new, of: original) }
        if let part = name.family, let new = family { recordPart(.person, part, new, of: original) }
        return titled
    }

    /// A part of a full name, in placeholder mode. The first person to have it lends it their
    /// tag, so a bare `Brenner` is known to be Herr Brenner. When a second person has the same
    /// word — two Sebastians, a mother and a son both called Kramer — the word alone can no
    /// longer say which of them is meant, and it gets a tag of its own. It is still disguised;
    /// it just no longer comes back as the wrong person.
    mutating func recordSharedPart(_ part: String, _ tag: String, of original: String) {
        guard let at = index[Self.key(part)] else { return recordPart(.person, part, tag, of: original) }
        guard entries[at].kind == .person, let old = Self.personTag(entries[at].standIn), old != tag,
              Set(fullNames.values).contains(old) else { return }
        let own = placeholder(.person)
        for i in entries.indices where entries[i].kind == .person && Self.personTag(entries[i].standIn) == old {
            let name = Self.nameParts(entries[i].original)
            let single = name.given == nil ? name.family : (name.family == nil ? name.given : nil)
            guard i == at || single.map(Self.key) == Self.key(part) else { continue }
            entries[i].standIn = entries[i].standIn.replacingOccurrences(of: old, with: own)
        }
    }

    /// `[Person F]` out of `Frau [Person F]`.
    static func personTag(_ standIn: String) -> String? {
        standIn.firstMatch(of: /\[Person [A-Z]+\]/).map { String($0.output) }
    }

    static func personKey(_ given: String, _ family: String) -> String { key(given) + "|" + key(family) }

    struct NameParts {
        var title: String?
        var given: String?
        var family: String?
        var commaFirst = false
    }

    /// `Annegret Berger`, `Garcia, Mariana`, `Frau Berger`, `Martin`. A single word is read as a
    /// first name, because that is how a bare name turns up in mail — `Hallo Martin` — and a
    /// surname on its own almost always has `Frau` or `Herr` in front of it.
    static func nameParts(_ text: String) -> NameParts {
        let text = text.trimmingCharacters(in: CharacterSet(charactersIn: "'\"‘’‚“”„ "))
        var parts = NameParts()
        if let comma = text.firstIndex(of: ",") {
            parts.family = String(text[..<comma]).trimmed.nilIfEmpty
            parts.given = words(String(text[text.index(after: comma)...])).first
            parts.commaFirst = true
            return parts
        }
        // `'Jan Kramer'`, as some mail clients write the display name, is Jan Kramer.
        var tokens = words(text).map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "'\"‘’‚“”„")) }.filter { !$0.isEmpty }
        // `Jan Kramer via TestFlight` is Jan Kramer.
        if let via = tokens.firstIndex(where: { $0.lowercased() == "via" }), via > 0 { tokens = Array(tokens[..<via]) }
        var titles: [String] = []
        while let first = tokens.first, honorifics.contains(key(first)) { titles.append(first); tokens.removeFirst() }
        parts.title = titles.isEmpty ? nil : titles.joined(separator: " ")
        switch tokens.count {
        case 0: break
        case 1: if parts.title == nil { parts.given = tokens[0] } else { parts.family = tokens[0] }
        default: parts.given = tokens.first; parts.family = tokens.last
        }
        return parts
    }

    // MARK: Companies

    /// The legal form and the words that only say what kind of business it is are kept —
    /// `Hausverwaltung … GmbH` tells the model what a party *is*, and identifies nobody. The
    /// rest is the name, and the name is replaced.
    mutating func organization(_ original: String, partOf: String?) -> String? {
        let tokens = original.split(separator: " ").map(String.init)
        let isGeneric = tokens.map { Self.companyWords.contains(Self.key($0)) }
        guard isGeneric.contains(false) else { return nil }  // `Hausverwaltung` alone names nobody

        if mode == .placeholder {
            // The name without its legal form is learned too — `Thermotec Nowak` turns up in the
            // prose without the `GmbH`, and it names the company just as well.
            let tag = placeholder(.organization)
            record(.organization, original, tag, partOf: partOf)
            let name = zip(tokens, isGeneric).filter { !$0.1 }.map(\.0).joined(separator: " ")
            if name.count >= 4 { recordPart(.organization, name, tag, of: original) }
            return tag
        }

        var out: [String] = []
        var run: [String] = []
        var runs: [(String, String)] = []
        func endRun() {
            guard !run.isEmpty else { return }
            let text = run.joined(separator: " ")
            let new = self.standIn(for: text) ?? (run.count == 1 ? self.standIn(for: run[0]) : nil) ?? pickName(.organization)
            out.append(new)
            runs.append((text, new))
            run = []
        }
        for (token, generic) in zip(tokens, isGeneric) {
            if generic { endRun(); out.append(token) } else { run.append(token) }
        }
        endRun()
        let standIn = record(.organization, original, out.joined(separator: " "), partOf: partOf)
        for (text, new) in runs where text.count >= 4 { recordPart(.organization, text, new, of: original) }
        return standIn
    }

    // MARK: Addresses

    mutating func email(_ original: String, partOf: String?) -> String? {
        let parts = original.split(separator: "@", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return record(.email, original, placeholder(.email), partOf: partOf) }
        let domain = parts[1]
        let isFreeMail = Self.freeMail.contains(Self.key(domain))

        if mode == .placeholder {
            // The domain is learned too: `www.berger-hv.example` in a signature names the company
            // as surely as the address does.
            if !isFreeMail, self.standIn(for: domain) == nil { record(.email, domain, placeholder("Domain"), partOf: original) }
            return record(.email, original, placeholder(.email), partOf: partOf)
        }

        let newDomain: String
        if isFreeMail {
            newDomain = domain
        } else {
            newDomain = self.standIn(for: domain) ?? (Self.ascii(pickName(.organization)).lowercased() + ".example")
            record(.email, domain, newDomain, partOf: original)
        }
        // Two names from the pools, never one that is a real name somewhere in this folder.
        var count = entries.filter { $0.kind == .email && $0.partOf == nil }.count
        func usable(_ name: String) -> Bool { !forbidden.contains(Self.key(name)) }
        var given = Pool.givenNames[count % Pool.givenNames.count]
        var family = Pool.surnames[(count * 7 + 3) % Pool.surnames.count]
        while !usable(given) || !usable(family) {
            count += 1
            given = Pool.givenNames[count % Pool.givenNames.count]
            family = Pool.surnames[(count * 7 + 3) % Pool.surnames.count]
        }
        let local = Self.ascii(given).lowercased() + "." + Self.ascii(family).lowercased()
        return record(.email, original, "\(local)@\(newDomain)", partOf: partOf)
    }

    /// `Honigtauer Str. 14`, `Honigwabenallee 47`, `14 Hivemead Road`. The street's own name is
    /// learned separately, because it turns up without the number — `WEG Honigtauer` — and
    /// in a matter about a building, that word is the matter.
    mutating func street(_ original: String, partOf: String?) -> String? {
        guard let street = Self.streetParts(original) else {
            return record(.street, original, mode == .placeholder ? placeholder(.street) : pickName(.street) + " 1", partOf: partOf)
        }
        // Two words (`Honigtauer Str.`) teach the first one on its own, because that is how the
        // street gets written in a hurry. One word (`Honigwabenallee`) teaches only the whole
        // word: its front half on its own is `Honigwaben`, which is honeycombs.
        let named = street.stem + street.separator + street.suffix
        let learnsStem = !street.separator.isEmpty && street.stem.count >= 4
        let stemTag = (learnsStem ? self.standIn(for: street.stem) : nil)
            ?? (mode == .placeholder ? self.standIn(for: named) : nil)
            ?? (mode == .placeholder ? placeholder(.street) : pickName(.street))
        if learnsStem { recordPart(.street, street.stem, stemTag, of: original) }

        var suffix = street.suffix
        if street.separator.isEmpty, let first = suffix.first { suffix = first.uppercased() + suffix.dropFirst() }
        let name = mode == .placeholder ? stemTag : "\(stemTag) \(suffix)"
        if named != original { record(.street, named, self.standIn(for: named) ?? name, partOf: original) }
        if mode == .placeholder {
            return record(.street, original, stemTag, partOf: partOf)
        }
        let number = street.number.map { Self.houseNumber(for: original, not: $0) }
        let standIn = street.numberFirst ? "\(number ?? "1") \(name)" : [name, number].compactMap { $0 }.joined(separator: " ")
        return record(.street, original, standIn, partOf: partOf)
    }

    struct StreetParts {
        var stem: String
        var separator: String
        var suffix: String
        var number: String?
        var numberFirst = false
    }

    static func streetParts(_ text: String) -> StreetParts? {
        var name = text.trimmed
        var number: String?
        var numberFirst = false
        if let match = name.firstMatch(of: /^(\d{1,4}\s?[a-zA-Z]?)\s+(.+)$/) {
            number = String(match.1); name = String(match.2); numberFirst = true
        } else if let match = name.firstMatch(of: /^(.+?)\s+(\d{1,4}(?:\s?[a-zA-Z])?)$/) {
            name = String(match.1); number = String(match.2)
        }
        let suffixes = /(?i)^(.*?)(\s*)(straße|strasse|str\.|allee|weg|platz|gasse|damm|ufer|ring|chaussee|steig|road|rd\.|street|st\.|avenue|ave\.|lane|drive|close|square|court|gardens)$/
        guard let match = name.firstMatch(of: suffixes), !match.1.isEmpty else { return nil }
        return StreetParts(stem: String(match.1), separator: String(match.2), suffix: String(match.3),
                           number: number, numberFirst: numberFirst)
    }

    /// The town is learned as a place, so a bare `Berlin` in the prose gets the same stand-in as
    /// the one in the address block.
    mutating func postalCity(_ original: String, partOf: String?) -> String? {
        guard let match = original.firstMatch(of: /^(\d{5})\s+(.+)$/) else {
            return record(.postalCity, original, placeholder(.postalCity), partOf: partOf)
        }
        let code = String(match.1)
        guard let city = learn(.place, String(match.2), partOf: original) else { return nil }
        let newCode = self.standIn(for: code) ?? (mode == .placeholder ? placeholder(.postalCity) : Self.digits(5, from: code))
        record(.postalCity, code, newCode, partOf: original)
        return record(.postalCity, original, "\(newCode) \(city)", partOf: partOf)
    }

    // MARK: Numbers

    /// The shape kept — spaces, a `+49`, a leading `0` and the digit after it — and the rest
    /// replaced, so a mobile number still reads as one.
    static func phone(_ original: String) -> String {
        // `+49`, or `0` and the next digit. Never more: `+493001234567` has no spaces, and taking
        // every leading digit as the country code kept the whole number.
        var kept = original.hasPrefix("+") ? 3 : 2
        var out = ""
        var fresh = Array(digits(original.filter(\.isNumber).count, from: original))
        for character in original {
            if kept > 0 { out.append(character); kept -= 1; continue }
            if character.isNumber, !fresh.isEmpty { out.append(fresh.removeFirst()) } else { out.append(character) }
        }
        guard out == original, let last = out.lastIndex(where: \.isNumber), let digit = out[last].wholeNumberValue
        else { return out }
        out.replaceSubrange(last...last, with: String((digit + 1) % 10))
        return out
    }

    static func iban(_ original: String) -> String {
        var fresh = Array(digits(original.count, from: original))
        var out = String(original.prefix(2))
        for character in original.dropFirst(2) {
            out.append(character == " " ? " " : fresh.removeFirst())
        }
        return out
    }

    static func houseNumber(for seed: String, not original: String) -> String {
        var number = 1 + (Int(digits(3, from: seed)) ?? 0) % 120
        if String(number) == original { number += 1 }
        return String(number)
    }

    /// Digits that are the same every run for the same original, so two runs of one folder give
    /// two logs that can be diffed.
    static func digits(_ count: Int, from seed: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in seed.utf8 { hash ^= UInt64(byte); hash &*= 0x0100_0000_01b3 }
        var out = ""
        for _ in 0..<count {
            hash = hash &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            out.append(Character(String((hash >> 33) % 10)))
        }
        return out
    }

    // MARK: Picking stand-ins

    enum Pick { case person, givenName, organization, place, street }

    /// The first name in the pool that is neither in use nor anywhere among the originals. When a
    /// pool runs out, a number goes on the end: unrealistic, and still never a real name.
    mutating func pickName(_ kind: Pick) -> String {
        if mode == .placeholder {
            switch kind {
            case .person, .givenName: return placeholder(.person)
            case .organization: return placeholder(.organization)
            case .place: return placeholder(.place)
            case .street: return placeholder(.street)
            }
        }
        let pool: [String] = switch kind {
        case .person: Pool.surnames
        case .givenName: Pool.givenNames
        case .organization: Pool.companies
        case .place: Pool.places
        case .street: Pool.streets
        }
        // A domain made from a stem (`aurelis.example`) uses up that stem too.
        let used = Set(entries.flatMap { entry -> [String] in
            let key = Self.key(entry.standIn)
            return key.hasSuffix(".example") ? [key, String(key.dropLast(".example".count))] : [key]
        })
        var round = 0
        while true {
            for name in pool {
                let candidate = round == 0 ? name : "\(name)\(round + 1)"
                if !used.contains(Self.key(candidate)), !forbidden.contains(Self.key(candidate)) { return candidate }
            }
            round += 1
        }
    }

    func placeholder(_ kind: Entity.Kind) -> String {
        let label = switch kind {
        case .person: "Person"
        case .organization: "Company"
        case .place: "Place"
        case .email: "Email"
        case .phone: "Phone"
        case .iban: "IBAN"
        case .reference: "Nummer"
        case .street: "Street"
        case .postalCity: "Postcode"
        }
        return placeholder(label)
    }

    /// `[Person A]` … `[Person Z]`, `[Person AA]`. Counted from the tags already handed out, so a
    /// mapping loaded from an earlier run carries on where it stopped.
    func placeholder(_ label: String) -> String {
        let prefix = "[\(label) "
        // Wherever a tag stands in a stand-in — `Frau [Person A]` holds one too. Counting only those
        // that begin with it handed `[Person A]` to Frau Kurz, Herr Li and Frau Post alike.
        let used = Set(entries.flatMap { entry in
            entry.standIn.matches(of: /\[[A-Za-z]+ [A-Z]+\]/).map { String($0.output) }.filter { $0.hasPrefix(prefix) }
        })
        var number = used.count
        while true {
            var letters = ""
            var n = number
            repeat { letters = String(UnicodeScalar(UInt8(65 + n % 26))) + letters; n = n / 26 - 1 } while n >= 0
            let tag = "\(prefix)\(letters)]"
            if !used.contains(tag) { return tag }
            number += 1
        }
    }

    @discardableResult
    mutating func record(_ kind: Entity.Kind, _ original: String, _ standIn: String, partOf: String?) -> String {
        if let known = self.standIn(for: original) { return known }
        add(Entry(kind: kind, original: original, standIn: standIn, partOf: partOf))
        return standIn
    }

    private mutating func add(_ entry: Entry) {
        let key = Self.key(entry.original)
        guard index[key] == nil else { return }
        index[key] = entries.count
        entries.append(entry)
        forbidden.insert(key)
        if mode == .placeholder, entry.kind == .person, entry.partOf == nil,
           case let name = Self.nameParts(entry.original), let given = name.given, let family = name.family,
           let tag = Self.personTag(entry.standIn) {
            fullNames[Self.personKey(given, family)] = fullNames[Self.personKey(given, family)] ?? tag
        }
    }

    /// Every person in `entries` learned again, as if for the first time: full names before names
    /// in one part, then in the order they were first learned. Everything else is kept as it was.
    static func relearningPeople(_ entries: [Entry]) -> [Entry] {
        var fresh = Pseudonymizer(mode: .placeholder, entries: entries.filter { $0.kind != .person })
        let people = entries.enumerated().filter { $0.element.kind == .person && $0.element.partOf == nil }
        let ordered = people.sorted { a, b in
            let (x, y) = (fullness(.person, a.element.original), fullness(.person, b.element.original))
            if x != y { return x > y }
            return a.offset < b.offset
        }
        for (_, entry) in ordered { fresh.learn(.person, entry.original) }
        return fresh.entries
    }

    /// A role learned as a name is taken out, and a name with a role in front keeps the role in
    /// the clear: `Hausmeister` alone is no longer a person, and `Hausmeister Brenner` goes out as
    /// `Hausmeister [Person AS]`. Tags keep their letters.
    static func rolesAsTitles(_ entries: [Entry]) -> [Entry] {
        entries.compactMap { entry in
            guard entry.kind == .person else { return entry }
            let words = Self.words(entry.original)
            let leading = words.prefix { roles.contains(key($0)) }
            if leading.count == words.count { return nil }
            guard !leading.isEmpty, let tag = personTag(entry.standIn), !entry.standIn.lowercased().contains(leading[0].lowercased()) else {
                return entry
            }
            var fixed = entry
            fixed.standIn = entry.standIn.replacingOccurrences(of: tag, with: leading.joined(separator: " ") + " " + tag)
            return fixed
        }
    }

    // MARK: Disguising and restoring

    /// Everything the mapping knows, replaced in one pass, longest first, whole words only — and
    /// in every way it is spelled. German is typed without its umlauts as often as with them:
    /// the mapping knew `Süß` and `Mühlberger`, and `Herrn Süss` and `Herr Muehlberger` went out in
    /// the clear.
    public var disguiser: Replacer {
        let exact = entries.map { ($0.original, $0.standIn) }
        let variants = entries.filter { [.person, .organization, .street, .place, .postalCity].contains($0.kind) }
            .flatMap { entry in Self.spellings(of: entry.original).map { ($0, entry.standIn) } }
            // A number is written with its spaces and dots or without: DE123 456 789, DE123456789.
            + entries.filter { [.reference, .iban, .phone].contains($0.kind) }.compactMap { entry in
                let bare = entry.original.filter { $0.isLetter || $0.isNumber }
                return bare != entry.original && bare.count >= 6 ? (bare, entry.standIn) : nil
            }
        var replacer = Replacer(exact + variants)
        // A name learned in capitals — "BERLIN SONNE" from a shouted line — is a name where
        // the text has a capital, not the word "alles" in the owner's own sentence.
        let shouted = entries.filter { [.person, .organization].contains($0.kind) }.map(\.original)
            .filter { name in name.contains { $0.isLetter } && name == name.uppercased() && name.filter(\.isLetter).count >= 3 }
            .map(Self.key)
        replacer.capitalOnly = Self.lowercaseWords.union(shouted)
        return replacer
    }

    /// Surnames that are also ordinary German words other than nouns — "weil", "kurz", "neu". A
    /// noun is written with a capital anyway; these are not, so `Frau Kurz` is a name and "kurz
    /// er fragt" is not. Only the capitalised one is disguised; at the start of a sentence that
    /// hides one "Weil" too many, which is the safe side.
    static let lowercaseWords: Set<String> = [
        "weil", "kurz", "lang", "klein", "groß", "gross", "schwarz", "weiß", "weiss", "braun", "grün", "gruen",
        "roth", "neu", "alt", "jung", "fromm", "frei", "froh", "stark", "stolz", "ernst", "lieb", "gut", "bald",
        "recht", "wild", "hell", "klug", "reich", "schön", "schoen", "still", "fest", "voll", "bloß", "noch",
    ]

    /// The other ways a name is typed: `ß` as `ss`, `ü` as `ue`, and `ue` as `ü`. Never `ss` as
    /// `ß` — a Herr Gross must not disguise every "groß".
    static func spellings(of original: String) -> [String] {
        var out: Set<String> = []
        let spelledOut = original.replacingOccurrences(of: "ß", with: "ss")
            .replacingOccurrences(of: "ä", with: "ae").replacingOccurrences(of: "ö", with: "oe").replacingOccurrences(of: "ü", with: "ue")
            .replacingOccurrences(of: "Ä", with: "Ae").replacingOccurrences(of: "Ö", with: "Oe").replacingOccurrences(of: "Ü", with: "Ue")
        out.insert(spelledOut)
        out.insert(original.replacingOccurrences(of: "ß", with: "ss"))
        let withUmlauts = original.replacingOccurrences(of: "ae", with: "ä").replacingOccurrences(of: "oe", with: "ö")
            .replacingOccurrences(of: "ue", with: "ü").replacingOccurrences(of: "Ae", with: "Ä")
            .replacingOccurrences(of: "Oe", with: "Ö").replacingOccurrences(of: "Ue", with: "Ü")
        out.insert(withUmlauts)
        // `'Kurz, Anna'` was learned with its quote marks, and a bare Kurz never matched it.
        let quotes = CharacterSet(charactersIn: "'\"‘’‚“”„")
        for form in Array(out) + [original] { out.insert(form.trimmingCharacters(in: quotes)) }
        out.remove(original)
        return out.filter { $0.count >= 3 }.sorted()
    }

    /// The way back, for step 6. Where several originals share a tag — `[Person A]` for
    /// `Annegret Berger`, `Berger`, `Frau Berger` and `Annegret Berger via Doodle` — the way back
    /// cannot know which was written, and brings the plainest full name: two words or as few as
    /// possible above one, no title in front, and the one learned first when that still ties.
    /// Longest-wins brought back `Jan Kramer via TestFlight` as a neighbour.
    public var restorer: Replacer {
        // A name without a title before one with, and a name in full before a part of one — but a
        // word with a tag of its own, `Maria`, comes back as that word, not as `Dr. Maria`.
        // One that ran on into a signature's "Tel" comes back last of all.
        func plainness(_ entry: Entry) -> (Int, Int, Int, Int, Int) {
            let words = Self.words(entry.original)
            let titles = words.prefix { Self.honorifics.contains(Self.key($0)) }.count
            return (Self.endsOnContactWord(entry.original) ? 1 : 0,
                    words.count - titles < 2 ? 1 : 0, titles > 0 ? 1 : 0, entry.partOf != nil ? 1 : 0, words.count)
        }
        var best: [String: Int] = [:]
        for (index, entry) in entries.enumerated() {
            let key = Self.key(entry.standIn)
            if let current = best[key], plainness(entries[current]) <= plainness(entry) { continue }
            best[key] = index
        }
        // "Lindner, Petra", as an insurer's mail writes it, comes back as "Petra Lindner": beside
        // her surname's own tag it is then one name, written once.
        func natural(_ entry: Entry) -> String {
            guard entry.kind == .person, let match = entry.original.wholeMatch(of: /([\p{L}\-]+),\s+([\p{L}\-]+(?:\s[\p{L}\-]+)?)/) else { return entry.original }
            return "\(match.output.2) \(match.output.1)"
        }
        var replacer = Replacer(best.values.sorted().map { (entries[$0].standIn, natural(entries[$0])) })
        replacer.joinsNames = true
        return replacer
    }

    public func disguise(_ email: Email, with replacer: Replacer? = nil) -> Disguise {
        let replacer = replacer ?? disguiser
        var count = 0
        func apply(_ text: String) -> String {
            let (out, made) = replacer.apply(text)
            count += made
            return out
        }
        return Disguise(mode: mode,
                        subject: apply(email.subject),
                        from: apply(email.from),
                        to: email.to.map(apply),
                        cc: email.cc.map(apply),
                        body: apply(email.body),
                        attachmentNames: email.attachments.map { apply($0.filename) },
                        replacements: count)
    }

    public func restore(_ text: String) -> String { restorer.apply(text).text }

    // MARK: Words

    static func key(_ text: String) -> String {
        text.trimmed.precomposedStringWithCanonicalMapping.lowercased()
    }

    static func words(_ text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    static func ascii(_ text: String) -> String {
        text.replacingOccurrences(of: "ß", with: "ss")
            .applyingTransform(.stripDiacritics, reverse: false)?
            .replacingOccurrences(of: " ", with: "-") ?? text
    }

    /// What a signature writes right after a name — "Frau Berger Tel.: 0331 …" — and is no part of it.
    static let contactWords: Set<String> = ["tel", "tel.", "telefon", "fax", "mobil", "handy", "mail", "email", "e-mail", "durchwahl", "zimmer"]

    /// A name that ends on one of those: the detector once took "Frau Berger Tel" for a name.
    static func endsOnContactWord(_ text: String) -> Bool {
        words(text).last.map { contactWords.contains($0.lowercased()) } ?? false
    }

    static let honorifics = Set(["frau", "herr", "herrn", "dr.", "dr", "doktor", "prof.", "prof", "professor", "mr", "mr.", "mrs", "mrs.", "ms", "ms."])
        .union(roles)

    /// What someone is, written in front of their name like a title: `Hausmeister Brenner`.
    /// Kept in the text like `Herr`, because it says who a party is and names nobody — and never
    /// learned as a first name, or every caretaker in every mail would be disguised as a person.
    static let roles: Set<String> = [
        "hausmeister", "hausmeisterin", "hausverwalter", "hausverwalterin", "verwalter", "verwalterin",
        "rechtsanwalt", "rechtsanwältin", "anwalt", "anwältin", "notar", "notarin", "architekt", "architektin",
        "makler", "maklerin", "steuerberater", "steuerberaterin", "beirat", "beirätin", "kollege", "kollegin",
        "nachbar", "nachbarin", "sachbearbeiter", "sachbearbeiterin", "schwester", "pfleger", "pflegerin",
    ]

    static let companyWords: Set<String> = [
        "gmbh", "mbh", "ag", "ug", "kg", "ohg", "gbr", "se", "e.v.", "e.", "v.", "ltd", "ltd.", "inc", "inc.",
        "llc", "&", "co.", "co", "und", "hausverwaltung", "verwaltung", "immobilien", "kanzlei",
        "rechtsanwalt", "rechtsanwälte", "notar", "praxis", "versicherung", "bank", "sparkasse", "team",
        "service", "support", "studio", "studios", "söhne", "baumarkt", "design",
    ]

    static let greetings: Set<String> = [
        "liebe", "lieber", "liebes", "hallo", "guten", "abend", "morgen", "tag", "moin", "servus",
        "herzliche", "herzlichen", "viele", "beste", "besten", "grüße", "gruß", "danke", "dear", "hello",
    ]

    static let calendarWords: Set<String> = [
        "montag", "dienstag", "mittwoch", "donnerstag", "freitag", "samstag", "sonntag",
        "januar", "februar", "märz", "april", "mai", "juni", "juli", "august", "september", "oktober",
        "november", "dezember", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
        "january", "february", "march", "june", "july", "october", "december", "uhr",
        "mon", "tue", "wed", "thu", "fri", "sat", "sun", "jan", "feb", "mär", "mar", "apr", "jun", "jul",
        "aug", "sep", "sept", "okt", "oct", "nov", "dez", "dec",
    ]

    /// Lowercase words that do belong inside a name: `Ludwig van Beethoven`, `Ursula von der Leyen`.
    static let particles: Set<String> = ["von", "van", "de", "der", "den", "zu", "da", "di", "del", "la", "le", "du", "ten", "ter"]

    static let freeMail: Set<String> = [
        "gmail.com", "googlemail.com", "web.de", "gmx.de", "gmx.net", "t-online.de", "icloud.com",
        "me.com", "mac.com", "arcor.de", "mailbox.org", "posteo.de", "outlook.com", "outlook.de",
        "hotmail.com", "hotmail.de", "yahoo.com", "yahoo.de", "freenet.de", "aol.com",
    ]

    /// Words the tagger has been seen calling a name. Kept short and specific: every word here is
    /// one that will never be disguised, so a real surname that happens to be a German word —
    /// `Koch`, `Weber` — must not end up on it.
    static let commonWords: Set<String> = [
        "sie", "ihr", "ihre", "ich", "wir", "mit", "und", "oder", "aber", "viele", "liebe", "lieber",
        "hallo", "danke", "gruß", "grüße", "beste", "tel", "fax", "mail", "email", "iban", "bic", "weg",
        "bescheid", "betreff", "anbei", "bitte", "termin", "montag", "dienstag", "mittwoch",
        "donnerstag", "freitag", "samstag", "sonntag", "hi", "hey", "thanks", "best", "regards",
        "cheers", "dear", "the", "and", "with", "re", "aw", "fwd", "wg", "euch", "dein", "deine", "mein",
        "meine", "ihnen", "ihren", "ihrer", "uns", "das", "die", "der", "ein", "eine", "von", "bei",
        "on", "als", "am", "im", "um", "für", "bis", "nach", "zum", "zur", "vom", "ab", "seit", "info", "mobil", "handy", "telefon", "fon", "kurz", "kurze",
        "gute", "namen", "post", "sitz", "haus", "privat", "wenn", "ihre", "ihr", "antwort",
    ]
}

/// How often each word of a folder was written with a capital — the denominator for telling a
/// noun the tagger ignores from a name it finds. Addresses and links are left out, because they
/// write names too, and would count a name every time a signature repeats.
public struct Vocabulary: Sendable {
    public private(set) var capitalised: [String: Int] = [:]

    public init(_ texts: [String]) {
        for text in texts {
            let prose = text.precomposedStringWithCanonicalMapping
                .replacing(/\S+@\S+|https?:\/\/\S+|www\.\S+/, with: " ")
            for match in prose.matches(of: /\p{L}[\p{L}\p{M}'’\-]*/) {
                let word = String(match.output)
                if let first = word.first, first.isUppercase { capitalised[Pseudonymizer.key(word), default: 0] += 1 }
            }
        }
    }
}

/// One mail as it would be sent. Kept in the decision log so a leak can be seen, not inferred.
public struct Disguise: Codable, Equatable, Sendable {
    public var mode: Pseudonymizer.Mode
    public var subject: String
    public var from: String
    public var to: [String]
    public var cc: [String]
    public var body: String
    public var attachmentNames: [String]
    public var replacements: Int

    enum CodingKeys: String, CodingKey {
        case mode, subject, from, to, cc, body, replacements
        case attachmentNames = "attachment_names"
    }
}

/// Replaces a set of strings with others in one pass: longest first, so `Annegret Berger` is
/// never half-replaced as `Annegret` and `Berger`; whole words only, so `Berger` does not bite a
/// piece out of `Bergerstraße`'s neighbour; and without regard to case or to how an umlaut was
/// encoded, because mail arrives both ways.
public struct Replacer: Sendable {
    private let table: [String: String]
    private let expression: NSRegularExpression?
    /// For the way back only: two replacements side by side that are one name are written once.
    /// A first name two people share has a tag of its own, so `Dr. Petra Lindner` can go out as
    /// `Dr. [Person BT] [Person B]` — and must not come back as `Dr. Maria Petra Lindner`.
    var joinsNames = false
    /// Keys matched only where the text has a capital: `Kurz` the name, not "kurz" the word.
    var capitalOnly: Set<String> = []

    public init(_ pairs: [(String, String)]) {
        var table: [String: String] = [:]
        for (from, to) in pairs where !from.trimmed.isEmpty {
            let key = Pseudonymizer.key(from)
            if table[key] == nil { table[key] = to }
        }
        self.table = table
        let alternatives = table.keys.sorted { $0.count != $1.count ? $0.count > $1.count : $0 < $1 }
            .map(NSRegularExpression.escapedPattern(for:))
        // A table that cannot become an expression stops here: without it `apply` would hand the
        // text back unchanged, and the names in it would leave as they are.
        if alternatives.isEmpty {
            expression = nil
        } else {
            do {
                expression = try NSRegularExpression(
                    pattern: #"(?<![\p{L}\p{N}])(?:"# + alternatives.joined(separator: "|") + #")(?![\p{L}\p{N}])"#,
                    options: [.caseInsensitive])
            } catch {
                fatalError("The disguise could not be built from \(table.count) names; nothing may be sent.")
            }
        }
    }

    public func apply(_ text: String) -> (text: String, count: Int) {
        let text = text.precomposedStringWithCanonicalMapping
        guard let expression else { return (text, 0) }
        let whole = NSRange(text.startIndex..., in: text)
        var found: [(range: Range<String.Index>, with: String)] = []
        for match in expression.matches(in: text, range: whole) {
            guard let range = Range(match.range, in: text),
                  let replacement = table[Pseudonymizer.key(String(text[range]))] else { continue }
            if capitalOnly.contains(Pseudonymizer.key(String(text[range]))), text[range].first?.isLowercase == true { continue }
            found.append((range, replacement))
        }
        if joinsNames { found = Self.joined(found, in: text).map { Self.swallowingNumber($0, in: text) } }
        var out = text
        for item in found.reversed() { out.replaceSubrange(item.range, with: item.with) }
        return (out, found.count)
    }

    /// A street comes back with its house number, and the model sometimes wrote the number after
    /// the tag as well: `[Street A] 51` is `Honigtauer Str. 14`, not `… 51 51`.
    static func swallowingNumber(_ item: (range: Range<String.Index>, with: String), in text: String) -> (range: Range<String.Index>, with: String) {
        guard let number = item.with.split(separator: " ").last, number.first?.isNumber == true else { return item }
        let rest = text[item.range.upperBound...]
        guard rest.hasPrefix(" " + number) else { return item }
        let end = text.index(item.range.upperBound, offsetBy: number.count + 1)
        if end < text.endIndex, text[end].isLetter || text[end].isNumber { return item }
        return (item.range.lowerBound..<end, item.with)
    }

    /// `Dr. Maria` is `Dr. ` and `Maria`.
    static func untitled(_ name: String) -> (title: String, core: String) {
        let words = Pseudonymizer.words(name)
        let titles = words.prefix { Pseudonymizer.honorifics.contains(Pseudonymizer.key($0)) }
        guard !titles.isEmpty, titles.count < words.count else { return ("", name) }
        return (titles.joined(separator: " ") + " ", words.dropFirst(titles.count).joined(separator: " "))
    }

    /// `Maria` then `Petra Lindner`, or `Petra Lindner` then `Lindner`, with one space between:
    /// one name, written once.
    static func joined(_ found: [(range: Range<String.Index>, with: String)], in text: String) -> [(range: Range<String.Index>, with: String)] {
        var out: [(range: Range<String.Index>, with: String)] = []
        for item in found {
            if let last = out.last, text[last.range.upperBound..<item.range.lowerBound] == " " {
                let (title, core) = untitled(last.with)
                var name: String?
                if item.with == last.with || last.with.hasSuffix(" " + item.with) { name = last.with }
                else if item.with.hasPrefix(core + " ") { name = title + item.with }
                if let name {
                    out[out.count - 1] = (last.range.lowerBound..<item.range.upperBound, name)
                    continue
                }
            }
            out.append(item)
        }
        return out
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

/// Stand-ins. Ordinary, plausible, and chosen to be unremarkable: a stand-in that reads as a
/// joke — or as `Tanja5` — changes what the model thinks the mail is.
///
/// A real folder has hundreds of people in it, far more than any hand-written list, so most of
/// each pool is made from German name parts: `Lind` and `ner`, `Berg` and `heim`. Every result
/// reads like a name and is checked against the folder's own originals before it is used.
enum Pool {
    static let givenNames = [
        "Birgit", "Jonas", "Heike", "Lukas", "Sabine", "Felix", "Anja", "Moritz", "Claudia", "Tobias",
        "Katrin", "Florian", "Nadine", "Jan", "Stefanie", "Matthias", "Julia", "Daniel", "Petra",
        "Christian", "Miriam", "Sven", "Ines", "Philipp", "Doris", "Kai", "Lena", "Marco", "Silke",
        "Oliver", "Tanja", "Henrik", "Ute", "Niklas", "Carola", "Benedikt", "Ronja", "Dirk", "Jana", "Emil",
        "Andrea", "Bernd", "Christina", "Dieter", "Elke", "Frank", "Gabriele", "Günter", "Hannah", "Holger",
        "Iris", "Jens", "Karin", "Klaus", "Laura", "Lars", "Monika", "Martin", "Nina", "Norbert", "Olga",
        "Peter", "Renate", "Ralph", "Sandra", "Stefan", "Theresa", "Thomas", "Ulla", "Uwe", "Vera",
        "Volker", "Wiebke", "Werner", "Yvonne", "Axel", "Anke", "Björn", "Beate", "Carsten", "Dagmar",
        "Detlef", "Edith", "Erik", "Franziska", "Fabian", "Gesa", "Gerd", "Helga", "Hendrik", "Ilse",
        "Ingo", "Judith", "Jörg", "Kerstin", "Konrad", "Lisa", "Lothar", "Maren", "Markus", "Nele",
        "Nils", "Paula", "Paul", "Regina", "Rainer", "Svenja", "Simon", "Tina", "Timo", "Ulrike",
        "Ulf", "Verena", "Wolfgang", "Antje", "Achim", "Bettina", "Boris", "Corinna", "Clemens", "Dörte",
        "David", "Eva", "Egon", "Friederike", "Friedrich", "Gudrun", "Georg", "Hanna", "Hans", "Imke",
        "Ivo", "Johanna", "Johannes", "Katja", "Karl", "Luise", "Leon", "Merle", "Max", "Nora", "Noah",
        "Ottilie", "Otto", "Pia", "Pascal", "Rieke", "Robert", "Susanne", "Sebastian", "Tabea", "Till",
        "Ursula", "Ulrich", "Viola", "Viktor", "Wilma", "Wilhelm", "Xenia", "Yannick", "Zoe", "Anton",
        "Agnes", "Bruno", "Britta", "Christoph", "Cornelia", "Dominik", "Diana", "Elias", "Emma", "Finn",
        "Frieda", "Gregor", "Greta", "Harald", "Heidi", "Ingrid", "Isabel", "Jakob", "Jutta", "Kurt",
        "Klara", "Ludwig", "Lotte", "Manfred", "Marie", "Nikolaus", "Nathalie", "Oskar", "Olivia",
        "Rudolf", "Rosa", "Siegfried", "Sophie", "Torsten", "Tamara", "Valentin", "Waltraud", "Walter",
        "Albert", "Alma", "Benno", "Berit", "Carl", "Cilly", "Dennis", "Dana", "Eberhard", "Esther",
        "Ferdinand", "Fenja", "Gustav", "Gisela", "Heinz", "Hedwig", "Ida", "Igor", "Jasper", "Jette",
        "Knut", "Kirsten", "Leo", "Liesel", "Malte", "Mia", "Nico", "Nadja", "Ole", "Oda", "Piet", "Rita",
        "Rolf", "Saskia", "Silas", "Thea", "Theo", "Ulli", "Vincent", "Wanda", "Wim",
        "Adele", "Arne", "Bianca", "Bastian", "Chiara", "Cem", "Denise", "Deniz", "Elif", "Emre", "Fatma",
        "Farid", "Gülay", "Goran", "Hatice", "Hakan", "Irina", "Ilias", "Jelena", "Jonte", "Kübra", "Kemal",
        "Leyla", "Luca", "Mira", "Milan", "Nesrin", "Nikola", "Oksana", "Omar", "Patrizia", "Pavel",
        "Raphaela", "Raul", "Selin", "Sami", "Tijana", "Tarek", "Vesna", "Vasco", "Yasmin", "Yusuf",
        "Zeynep", "Zoran", "Alina", "Aaron", "Bente", "Bjarne", "Cosima", "Cornelius", "Delia", "Darius",
        "Elena", "Emilian", "Fiona", "Fritz", "Gloria", "Gideon", "Helene", "Hugo", "Isolde", "Ilja",
        "Josefine", "Joscha", "Kira", "Korbinian", "Lina", "Linus", "Magdalena", "Mats", "Nadine",
        "Nepomuk", "Orla", "Otmar", "Philippa", "Quirin", "Rebekka", "Rasmus", "Selma", "Severin",
        "Theda", "Tjark", "Uta", "Urs", "Vivien", "Veit", "Wencke", "Wendelin", "Adrian", "Annika",
        "Benjamin", "Bärbel", "Cedric", "Constanze", "Dietmar", "Dorothea", "Enno", "Erika", "Frederik",
        "Frauke", "Gernot", "Gerda", "Henning", "Hildegard", "Ingmar", "Ivana", "Janosch", "Jolanda",
        "Kilian", "Kornelia", "Lennart", "Leonie", "Mathis", "Melanie", "Nikolai", "Nicole", "Olaf",
        "Pauline", "Reinhard", "Ricarda", "Sönke", "Sigrid", "Thorben", "Tilda", "Udo", "Ulrika",
        "Wieland", "Wilhelmine", "Arvid", "Amelie", "Birger", "Bella", "Colin", "Carla", "Dario", "Dina",
    ]

    static let surnames = [
        "Albers", "Brandt", "Dietz", "Ebert", "Falk", "Gerlach", "Hesse", "Jansen", "Kessler", "Lorenz",
        "Marx", "Nolte", "Ott", "Pohl", "Quast", "Ritter", "Seidel", "Thiel", "Voigt", "Winkler",
        "Beck", "Claasen", "Dreyer", "Engel", "Frey", "Gottschalk", "Haas", "Imhoff", "Jäger", "Kuhn",
        "Lang", "Mertens", "Nagel", "Oswald", "Pauli", "Reuter", "Stark", "Tews", "Ulrich", "Vogel",
        "Wendt", "Zander", "Busch", "Conrad", "Dorn", "Eckert", "Fiedler", "Grimm", "Horn", "Janke",
    ] + combined(stems, ["ner", "mann", "meier", "huber", "bach", "berg", "feld", "hoff", "rath",
                         "wald", "inger", "ke", "sen", "er", "hauser", "städter"])

    static let companies = [
        "Lindner", "Hoffmeister", "Aurelis", "Sonntag", "Brenner", "Nordwind", "Kaiser", "Stellwerk",
        "Ahrens", "Weidemann", "Merkur", "Falkenberg", "Rosenthal", "Linde", "Greif", "Heimdall",
        "Kranich", "Lotsen", "Achter", "Dreieck", "Seeberg", "Uhland", "Wachholz", "Zeisig",
    ] + combined(stems, ["tec", "plan", "werk", "bau", "haus", "data", "form", "line", "kontor", "concept"])

    static let places = [
        "Friedrichshain", "Kassel", "Lüneburg", "Göttingen", "Weißensee", "Erfurt", "Bamberg", "Rostock",
        "Oldenburg", "Pankow", "Jena", "Siegen", "Konstanz", "Wismar", "Coburg", "Tempelhof", "Gießen",
        "Hameln", "Passau", "Celle", "Stralsund", "Moabit", "Fulda", "Landshut",
    ] + generatedPlaces

    static let streets = [
        "Lindauer", "Gothaer", "Weimarer", "Kolberger", "Ansbacher", "Detmolder", "Hildesheimer",
        "Eisenacher", "Rudolstädter", "Wittenberger", "Marburger", "Bayreuther", "Zwickauer",
        "Plauener", "Coswiger", "Eschweger", "Tübinger", "Mindener", "Schweriner", "Harzer",
    ] + generatedPlaces.map { $0 + "er" }

    static let generatedPlaces = combined(stems, ["au", "heim", "hausen", "dorf", "rode", "stedt", "felde", "hagen", "burg", "beck"])

    static let stems = [
        "Lind", "Berg", "Hof", "Wald", "Stein", "Brun", "Eich", "Hart", "Kron", "Ross", "Wies", "Mohr",
        "Feld", "Hag", "Neu", "Alt", "Stroh", "Gold", "Sand", "Holz", "Ried", "Moos", "Esch", "Tann",
        "Hahn", "Roth", "Wend", "Kirch", "Mühl", "Brück",
    ]

    /// Every stem with every ending, ending by ending — so the first thirty are one family of
    /// names and not thirty variations of `Lind`.
    static func combined(_ stems: [String], _ endings: [String]) -> [String] {
        endings.flatMap { ending in
            stems.map { stem in
                // `Hahn` and `ner` would be `Hahnner`; one consonant where two would double.
                if let last = stem.last, ending.first == last { return stem + ending.dropFirst() }
                return stem + ending
            }
        }
    }
}
