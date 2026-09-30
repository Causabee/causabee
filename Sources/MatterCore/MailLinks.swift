import Foundation
import SwiftData

/// The links in a mail that matter — the shared doc, the form, the booking page — found on the
/// device, for nothing, and offered to the owner to keep. What every newsletter and signature
/// carries is left out: unsubscribing, tracking, social media, the privacy page, the sender's
/// homepage, and whatever sits in the signature or in an older mail quoted below.
public enum MailLinks {
    // MARK: Collecting

    /// Every link in a message, with its words and where it sits. The HTML part is read when
    /// there is one — it has the words each link was written under — and the plain part when not.
    static func collect(in part: EMLParser.Part) -> [Email.Link] {
        var plain: [String] = []
        var html: [String] = []
        gather(part, plain: &plain, html: &html)
        let found = html.isEmpty ? plain.flatMap(fromPlain) : html.flatMap(fromHTML)
        var best: [String: Email.Link] = [:]
        var order: [String] = []
        let rank: [Email.Link.Place: Int] = [.body: 0, .signature: 1, .quote: 2]
        for link in found {
            guard let known = best[link.address] else { best[link.address] = link; order.append(link.address); continue }
            if rank[link.place]! < rank[known.place]! || (known.text.isEmpty && !link.text.isEmpty && link.place == known.place) {
                best[link.address] = link
            }
        }
        return order.compactMap { best[$0] }
    }

    private static func gather(_ part: EMLParser.Part, plain: inout [String], html: inout [String]) {
        let (type, parameters) = part.contentType
        let lowered = type.lowercased()
        if lowered.hasPrefix("multipart/"), let boundary = parameters["boundary"] {
            for child in EMLParser.parts(of: part.body, boundary: boundary) { gather(child, plain: &plain, html: &html) }
            return
        }
        guard lowered.hasPrefix("text/") || lowered.isEmpty, !part.disposition.value.lowercased().hasPrefix("attachment") else { return }
        let decoded = MIME.decode(body: part.body, transferEncoding: part.transferEncoding, charset: parameters["charset"])
        if lowered.hasPrefix("text/html") { html.append(decoded) } else if !lowered.hasPrefix("text/calendar") { plain.append(decoded) }
    }

    private static let anchor = try! NSRegularExpression(
        pattern: #"<a\s[^>]*?href\s*=\s*["']([^"']+)["'][^>]*>(.*?)</a\s*>"#, options: [.caseInsensitive, .dotMatchesLineSeparators])

    static func fromHTML(_ html: String) -> [Email.Link] {
        let lower = html.lowercased()
        func start(_ markers: [String]) -> Int {
            markers.compactMap { marker in lower.range(of: marker).map { lower.distance(from: lower.startIndex, to: $0.lowerBound) } }.min() ?? .max
        }
        let quote = start(["class=\"gmail_quote", "<blockquote", "id=\"divrplyfwdmsg\"", "id=\"appendonsend\"", "class=\"moz-cite-prefix",
                           "-----original message-----", "-----ursprüngliche nachricht-----"])
        let signature = start(["class=\"gmail_signature", "data-smartmail=\"gmail_signature", "class=\"moz-signature", "id=\"signature",
                               ">-- <br", ">--&nbsp;<br", "\n-- <br"])
        let whole = NSRange(html.startIndex..., in: html)
        return anchor.matches(in: html, range: whole).compactMap { match in
            guard let hrefRange = Range(match.range(at: 1), in: html), let textRange = Range(match.range(at: 2), in: html) else { return nil }
            let address = HTMLText.entities(String(html[hrefRange])).trimmingCharacters(in: .whitespacesAndNewlines)
            guard address.lowercased().hasPrefix("http") else { return nil }
            let at = html.distance(from: html.startIndex, to: hrefRange.lowerBound)
            let place: Email.Link.Place = at >= quote ? .quote : at >= signature ? .signature : .body
            let text = HTMLText.strip(String(html[textRange])).replacingOccurrences(of: "\n", with: " ")
            return Email.Link(address: address, text: text, place: place)
        }
    }

    private static let quoteHeader = try! NSRegularExpression(
        pattern: #"(?m)^(>|Am .{5,160}schrieb.{0,80}:\s*$|On .{5,160}wrote:\s*$|-+\s*(Original Message|Ursprüngliche Nachricht)\s*-+|Von: .*\n(?:.*\n){0,3}?(Gesendet|Datum|Sent|Date): )"#)
    private static let signatureMark = try! NSRegularExpression(pattern: #"(?m)^-- ?$"#)

    static func fromPlain(_ text: String) -> [Email.Link] {
        let whole = NSRange(text.startIndex..., in: text)
        let quote = quoteHeader.firstMatch(in: text, range: whole)?.range.location ?? .max
        let signature = signatureMark.firstMatch(in: text, range: whole)?.range.location ?? .max
        return LinkStandIns.pattern.matches(in: text, range: whole).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            var address = String(text[range])
            while let last = address.last, ".,;:!?)»“\"'>".contains(last) { address.removeLast() }
            guard address.lowercased().hasPrefix("http") else { return nil }
            let at = match.range.location
            let place: Email.Link.Place = at >= quote ? .quote : at >= signature ? .signature : .body
            // "Kostenaufstellung <https://…>", as Gmail writes a link in the plain part.
            let lineStart = text[..<range.lowerBound].lastIndex(of: "\n").map { text.index(after: $0) } ?? text.startIndex
            let before = String(text[lineStart..<range.lowerBound]).trimmingCharacters(in: CharacterSet(charactersIn: " <(:[\t"))
            return Email.Link(address: address, text: before.count <= 60 ? before : "", place: place)
        }
    }

    // MARK: Choosing

    static let leftOutHosts = [
        "facebook.com", "fb.me", "instagram.com", "linkedin.com", "twitter.com", "x.com", "youtube.com", "youtu.be", "xing.com",
        "tiktok.com", "pinterest.com", "threads.net", "whatsapp.com", "wa.me", "apps.apple.com", "itunes.apple.com", "play.google.com",
        "list-manage.com", "mailchimp.com", "sendgrid.net", "mandrillapp.com", "rs6.net", "hubspotlinks.com", "exacttarget.com",
        "mailjet.com", "sendinblue.com", "brevo.com", "cleverreach.com", "newsletter2go.com", "doubleclick.net",
        "google-analytics.com", "trustpilot.com", "maps.google.com", "goo.gl", "maps.apple.com", "gravatar.com",
    ]
    static let trackingPrefixes = ["click.", "clicks.", "links.", "link.", "track.", "tracking.", "email.", "mailing.", "newsletter.", "t."]
    static let leftOutWords = [
        "unsubscribe", "abmelden", "abbestellen", "austragen", "optout", "opt-out", "newsletter", "datenschutz", "privacy", "impressum",
        "imprint", "agb", "terms", "cookie", "einstellungen", "preferences", "im browser", "webversion", "view in browser",
        "online ansehen", "online-version", "rechtliche hinweise", "legal", "disclaimer", "widerruf", "kontaktformular",
    ]

    /// Whether a link is one the owner could want: written in the mail, not in its signature or
    /// in an older mail below, not an unsubscribing, tracking, social or legal link, not a picture,
    /// and not only a homepage.
    public static func isWorthKeeping(_ link: Email.Link) -> Bool {
        guard link.place == .body, let url = URL(string: link.address), let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme), var host = url.host?.lowercased(), host.contains(".") else { return false }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        if leftOutHosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) { return false }
        if trackingPrefixes.contains(where: { host.hasPrefix($0) }) { return false }
        let words = (url.path + " " + (url.query ?? "") + " " + link.text).lowercased()
        if leftOutWords.contains(where: { words.contains($0) }) { return false }
        let path = url.path.lowercased()
        if [".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp"].contains(where: { path.hasSuffix($0) }) { return false }
        if path.isEmpty || path == "/" { return false }
        return true
    }

    /// The link's own words as its name, when they say something: not "hier", not the address.
    public static func name(of link: Email.Link) -> String {
        let text = link.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let nothing = ["hier", "here", "link", "klicken sie hier", "click here", "mehr", "more", "weiter", "öffnen", "open", "hier klicken"]
        guard text.count >= 2, text.count <= 80, !nothing.contains(text.lowercased()),
              !text.lowercased().hasPrefix("http"), !text.lowercased().hasPrefix("www.") else { return "" }
        return text
    }

    // MARK: Suggesting

    /// Offers the mail's important links in the matter that holds the mail. Says how many.
    @MainActor
    @discardableResult
    public static func suggest(_ email: Email, in context: ModelContext) -> Int {
        let id = email.id
        guard !email.links.isEmpty,
              let matter = try? context.fetch(FetchDescriptor<Entry>(predicate: #Predicate { $0.messageID == id })).first?.matter
        else { return 0 }
        return suggest(email.links, messageID: id, to: matter, in: context)
    }

    @MainActor
    @discardableResult
    public static func suggest(_ links: [Email.Link], messageID: String, to matter: Matter, in context: ModelContext) -> Int {
        var known = Set((matter.links ?? []).map(\.address))
        var added = 0
        for link in links where isWorthKeeping(link) && !known.contains(link.address) {
            let web = WebLink(address: link.address, title: name(of: link))
            web.messageID = messageID
            web.isSuggestion = true
            context.insert(web)
            web.matter = matter
            known.insert(link.address)
            added += 1
        }
        return added
    }
}
