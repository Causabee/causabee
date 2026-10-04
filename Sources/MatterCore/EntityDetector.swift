import Foundation
import NaturalLanguage

/// Step 3 of the spike: find everything identifiable, on the device, before anything is sent
/// anywhere.
///
/// Two layers, and the difference between them is the whole point. A rule finds what has a
/// shape — an address, an IBAN, five digits and a town — and finds all of it, every time. The
/// tagger finds what only a reader can tell is a name, and finds *most* of it. Question two of
/// the plan is how much "most" is in German mail, so the two are kept apart in the log and
/// never averaged together.
public struct EntityDetector: Sendable {
    /// Left nil to detect per mail. Forced when a folder is known to be one language and the
    /// recognizer keeps guessing Dutch at four-line mails, which it does.
    public var language: NLLanguage?
    public var runsTagger: Bool

    public init(language: NLLanguage? = nil, runsTagger: Bool = true) {
        self.language = language
        self.runsTagger = runsTagger
    }

    public func entities(in email: Email) -> [Entity] {
        var found: [Entity] = []
        found += entities(in: email.subject, field: .subject)
        found += entities(in: email.body, field: .body)
        found += addressField(email.from, field: .from)
        for address in email.to { found += addressField(address, field: .to) }
        for address in email.cc { found += addressField(address, field: .cc) }
        for attachment in email.attachments {
            found += entities(in: attachment.filename, field: .attachmentName)
        }
        return found
    }

    public func entities(in text: String, field: Entity.Field) -> [Entity] {
        guard !text.trimmed.isEmpty else { return [] }
        var found = ruleMatches(in: text, field: field)
        if runsTagger { found += taggedNames(in: text, field: field) }
        return resolvingOverlaps(found)
    }

    // MARK: The tagger

    func taggedNames(in text: String, field: Entity.Field) -> [Entity] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        let whole = text.startIndex..<text.endIndex
        tagger.setLanguage(language ?? Self.language(of: text), range: whole)

        // The same text read for grammar. The name tagger's worst habit in German is taking a
        // pronoun or an article for a name — `Sie`, `Das`, `wir Ihnen` — and every word class but
        // a noun or an adjective is something a name is not made of.
        let grammar = NLTagger(tagSchemes: [.lexicalClass])
        grammar.string = text
        grammar.setLanguage(language ?? Self.language(of: text), range: whole)

        var found: [Entity] = []
        tagger.enumerateTags(in: whole, unit: .word, scheme: .nameType,
                             options: [.omitWhitespace, .omitPunctuation, .omitOther, .joinNames]) { tag, range in
            guard let kind = Self.kind(of: tag),
                  let range = Self.nameWords(in: range, of: text, grammar: grammar) else { return true }
            let nsRange = NSRange(range, in: text)
            found.append(Entity(kind: kind, text: String(text[range]), field: field,
                                start: nsRange.location, length: nsRange.length, source: .onDevice))
            return true
        }
        return found
    }

    /// The tagger's span with the words that cannot be part of a name taken off either end, or
    /// nil when nothing is left or a word in the middle cannot be either — `Sachsen und NRW` is
    /// two names and a conjunction, not one name.
    static func nameWords(in range: Range<String.Index>, of text: String, grammar: NLTagger) -> Range<String.Index>? {
        var words: [(range: Range<String.Index>, fits: Bool)] = []
        grammar.enumerateTags(in: range, unit: .word, scheme: .lexicalClass,
                              options: [.omitWhitespace, .omitPunctuation]) { tag, wordRange in
            let word = text[wordRange].lowercased()
            let fits = tag == .noun || tag == .adjective || tag == .otherWord || tag == nil
                || particles.contains(word) || word.hasSuffix(".")
            words.append((wordRange, fits))
            return true
        }
        while let first = words.first, !first.fits { words.removeFirst() }
        while let last = words.last, !last.fits { words.removeLast() }
        guard let first = words.first, let last = words.last else { return nil }
        guard words.allSatisfy(\.fits) else { return nil }
        return first.range.lowerBound..<last.range.upperBound
    }

    static let particles: Set<String> = ["von", "van", "de", "der", "den", "zu", "da", "di", "del", "la", "le", "du", "ten", "ter"]

    static func kind(of tag: NLTag?) -> Entity.Kind? {
        switch tag {
        case .personalName?: .person
        case .placeName?: .place
        case .organizationName?: .organization
        default: nil
        }
    }

    /// The recognizer wants a paragraph and gets a subject line, so anything it is not fairly
    /// sure about is read as German — which is what this mailbox mostly is.
    static func language(of text: String) -> NLLanguage {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let best = recognizer.dominantLanguage,
              let confidence = recognizer.languageHypotheses(withMaximum: 1)[best],
              confidence > 0.5 else { return .german }
        return best
    }

    // MARK: The rules

    struct Pattern: Sendable {
        var kind: Entity.Kind
        var expression: String
        var options: NSRegularExpression.Options = []
        /// Minimum digits, for the patterns that are mostly digits and easy to fool.
        var minimumDigits: Int = 0
        /// The capture group that is the entity, when the pattern needs context around it:
        /// `Frau Behrend` is found by its `Frau`, and the entity is the whole of it.
        var group: Int = 0
        /// A name found by its context, checked against the list of ordinary words: "Liebe Grüße"
        /// is a closing, not Frau Grüße.
        var isName = false
    }

    /// House number after the name, house number before it, and the German habit of writing the
    /// same street as one word or two. `Honigwabenallee 47` and `Wabenhöfer Allee 12` are the
    /// same shape to a reader and two different problems to a regex, and the second one is what
    /// the first run of the spike missed in four mails out of five.
    static let streetPatterns = [
        #"\b[A-ZÄÖÜ][\w.\-]*(?:stra(?:ß|ss)e|str\.|weg|allee|platz|gasse|damm|ufer|ring|chaussee|steig)\s+\d{1,4}(?:\s?[a-zA-Z])?\b"#,
        #"\b[A-ZÄÖÜ][\w.\-]+\s+(?:Stra(?:ß|ss)e|Str\.|Allee|Weg|Platz|Gasse|Damm|Ufer|Ring|Chaussee|Steig)\s+\d{1,4}(?:\s?[a-zA-Z])?\b"#,
        #"\b\d{1,4}\s+[A-Z][\w.\-]+(?:\s+[A-Z][\w.\-]+)*\s+(?:Road|Rd\.|Street|St\.|Avenue|Ave\.|Lane|Drive|Close|Square|Court|Gardens)\b"#,
    ]

    static let patterns: [Pattern] = [
        .init(kind: .email, expression: #"[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(?:\.[A-Za-z0-9\-]+)+"#),
        .init(kind: .iban, expression: #"\b[A-Z]{2}\d{2}(?:[ ]?[A-Z0-9]){11,30}\b"#),
        .init(kind: .street, expression: streetPatterns[0]),
        .init(kind: .street, expression: streetPatterns[1]),
        .init(kind: .street, expression: streetPatterns[2]),
        .init(kind: .postalCity, expression: #"\b\d{5}\s+[A-ZÄÖÜ][\w.\-]+(?:[ \-][A-ZÄÖÜ][\w.\-]+)*\b"#),
        // A company writes its own name with its legal form attached, and that is the one shape
        // an organisation reliably has. The tagger read `Thermotec Nowak GmbH` as a surname and
        // nothing else, which would have sent a party's name straight to the API.
        // The trailing guard is a lookahead rather than \b, because a legal form that ends in a
        // full stop — `e. V.`, `Ltd.` — has no word boundary after it and was missed.
        .init(kind: .organization,
              expression: #"\b(?:[A-ZÄÖÜ][\w.\-&]*[ ]){1,4}(?:GmbH|mbH|AG|UG|KG|OHG|GbR|SE|e\.[ ]?V\.|Ltd\.?|Inc\.?|LLC)(?!\w)"#),
        // Two shapes, because a country code replaces the leading zero rather than sitting in
        // front of it: `+49 30 09778110` has no 0 anywhere and was missed by a pattern that
        // insisted on one. The leading + or 0 keeps dates and amounts out; the digit count
        // keeps house numbers and years out.
        .init(kind: .phone, expression: #"\+\d{1,3}[ \-/]?\(?\d{1,5}\)?[ \-/]?\d[\d \-/]{3,}\d"#,
              minimumDigits: 8),
        .init(kind: .phone, expression: #"\(?0\d{1,5}\)?[ \-/]?\d[\d \-/]{3,}\d"#,
              minimumDigits: 8),
        // A reference number, found by the word before it: Versicherungsnummer, Kunden-Nr.,
        // Vorgang-Nr., Aktenzeichen, USt-IdNr. The number is what is replaced; the label stays,
        // so the model still knows what kind of number it was.
        .init(kind: .reference,
              expression: #"(?i:\b(?:versicherten|versicherungs|kunden|vorgangs?|vertrags|mitglieds|rechnungs|policen|referenz|buchungs|auftrags|schadens?|fall|patienten|akten|steuer|ust[\-. ]?id|mandanten|bestell|antrags)[\- ]?(?:nummer|nr\.?|zeichen)|\baz\.|\bust[\-. ]?id[\-. ]?nr\.?)\s*[:#.]?\s*((?:[A-Z0-9][A-Z0-9./\-]*)(?:\s[A-Z0-9][A-Z0-9./\-]*(?![a-zäöüß]))*)(?<=[A-Z0-9])"#,
              minimumDigits: 4, group: 1),
        // A code that is plainly an identifier with no label: letters in front of eight digits or
        // more — X8200001234567 — or ten digits and more in a row. No date or amount looks so.
        .init(kind: .reference, expression: #"\b[A-Z]{1,3}\d{8,}\b|\b\d{10,}\b"#),
        // A name found by what comes before it, where the tagger found nothing: "Frau Behrend",
        // "Herrn Dr. Brenner", "Inh. Petra Blume". The title stays in the entity, and the
        // disguise keeps it readable: "Frau [Person A]".
        .init(kind: .person,
              expression: #"\b(?:Frau|Herrn?|Dr\.|Prof\.|Inh\.|Inhaber(?:in)?:?)\s+(?:(?:Dr|Prof)\.\s+)?(?:[A-ZÄÖÜ][a-zäöüß]+[ \-]){0,2}[A-ZÄÖÜ][a-zäöüß]+(?:-[A-ZÄÖÜ][a-zäöüß]+)?"#,
              isName: true),
        // A first name after a greeting: "Hallo Georg,", "Lieber Tom".
        .init(kind: .person,
              expression: #"\b(?:Hallo|Hi|Hey|Liebe|Lieber|Moin|Servus)\s+([A-ZÄÖÜ][a-zäöüß]{2,})(?=\s*[,!\n])"#,
              group: 1, isName: true),
    ]

    /// Compiled once, not again for every field of every mail — and a rule that does not compile
    /// stops the program rather than being skipped: a skipped rule would let what it finds leave.
    static let compiled: [(pattern: Pattern, regex: NSRegularExpression)] = patterns.map { pattern in
        do { return (pattern, try NSRegularExpression(pattern: pattern.expression, options: pattern.options)) }
        catch { fatalError("A detector rule does not compile: \(pattern.expression)") }
    }

    func ruleMatches(in text: String, field: Entity.Field) -> [Entity] {
        var found: [Entity] = []
        for (pattern, regex) in Self.compiled {
            for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                let span = match.range(at: pattern.group)
                guard span.location != NSNotFound, let range = Range(span, in: text) else { continue }
                var hit = String(text[range])
                // "Frau Berger Tel.: 0331 …": the name stops before the signature's label.
                while pattern.isName, Pseudonymizer.endsOnContactWord(hit), let space = hit.lastIndex(of: " ") {
                    hit = String(hit[..<space])
                }
                if pattern.minimumDigits > 0, hit.filter(\.isNumber).count < pattern.minimumDigits { continue }
                if pattern.isName, Self.isOrdinary(hit) { continue }
                // A match that ran on into the next line is still the right entity with the
                // wrong length, and the length is what a replacement will use.
                let trimmed = hit.trimmed
                let lead = hit.distance(from: hit.startIndex,
                                        to: hit.firstIndex(where: { !$0.isWhitespace }) ?? hit.startIndex)
                found.append(Entity(kind: pattern.kind, text: trimmed, field: field,
                                    start: span.location + lead,
                                    length: (trimmed as NSString).length, source: .rule))
            }
        }
        return found
    }

    /// Every word after the title an ordinary one — "Frau Doktor", "Liebe Grüße", "Herr Hausmeister".
    static func isOrdinary(_ found: String) -> Bool {
        let words = found.split(separator: " ").map(String.init)
            .filter { !Pseudonymizer.honorifics.contains(Pseudonymizer.key($0)) && !["inh.", "inhaber", "inhaberin", "inhaber:", "inhaberin:"].contains($0.lowercased()) }
        return words.isEmpty || words.allSatisfy { Pseudonymizer.isListed($0) || ["grüße", "gruß", "grüßen", "leute", "alle", "zusammen", "team", "kollegen", "kolleginnen", "damen", "herren",
                                                                              "angehörige", "angehörigen", "mitglieder", "beiratsmitglieder", "nachbarn", "eigentümer",
                                                                              "eigentümerinnen", "freunde", "freundinnen", "eltern", "kinder", "familie", "beirat", "beiräte"].contains($0.lowercased()) }
    }

    // MARK: Header addresses

    /// `Hausverwaltung Berger <post@berger-hv.example>` is two entities, and the one before the
    /// angle bracket is the one that matters. It is never left to the tagger alone: a display
    /// name is two words with no sentence around it, which is where the tagger is weakest, and
    /// a party's own name is the last thing that should reach an API by accident.
    func addressField(_ field: String, field kind: Entity.Field) -> [Entity] {
        guard !field.trimmed.isEmpty else { return [] }
        var found = ruleMatches(in: field, field: kind)

        guard let name = Email.displayName(in: field) else { return resolvingOverlaps(found) }
        let nsRange = (field as NSString).range(of: name)
        guard nsRange.location != NSNotFound else { return resolvingOverlaps(found) }

        // The legal form is asked first and the tagger second: `GmbH` at the end of a name is
        // a fact, and a two-word display name with no sentence around it is exactly where the
        // tagger guesses — it read `Hausverwaltung Berger GmbH` as a place.
        let incorporated = Self.looksIncorporated(name)
        let tagged = incorporated || !runsTagger ? nil : taggedNames(in: name, field: kind).first?.kind
        found.append(Entity(kind: tagged ?? (incorporated ? .organization : .person),
                            text: name, field: kind,
                            start: nsRange.location, length: nsRange.length,
                            source: tagged == nil ? .rule : .onDevice))
        return resolvingOverlaps(found)
    }

    static let legalForms = ["gmbh", "mbh", " ag", "e.v.", "e. v.", " ug", " kg", " ohg", " se",
                             "hausverwaltung", "verwaltung", "kanzlei", "rechtsanwalt", "notar",
                             "praxis", "versicherung", "bank", "sparkasse", "gbr", "ltd", "inc",
                             "team", "service", "support"]

    static func looksIncorporated(_ name: String) -> Bool {
        let lowered = " " + name.lowercased()
        return legalForms.contains { lowered.contains($0) }
    }

    // MARK: Overlaps

    /// Longest span wins, and a tie goes to the rule, because a rule knows what it found.
    /// Without this an IBAN reads as an IBAN *and* as a phone number, and the same characters
    /// get disguised twice with two different stand-ins.
    func resolvingOverlaps(_ entities: [Entity]) -> [Entity] {
        let sorted = entities.sorted {
            if $0.start != $1.start { return $0.start < $1.start }
            if $0.length != $1.length { return $0.length > $1.length }
            return $0.source == .rule && $1.source != .rule
        }
        var kept: [Entity] = []
        for entity in sorted where !kept.contains(where: { $0.range.overlaps(entity.range) && $0.field == entity.field }) {
            kept.append(entity)
        }
        return kept
    }
}
