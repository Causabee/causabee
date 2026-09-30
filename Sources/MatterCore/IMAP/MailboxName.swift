import Foundation

/// IMAP's own spelling of a folder name, "modified UTF-7" (RFC 3501, 5.1.3). A Gmail label
/// called `Verträge` is `Vertr&AOQ-ge` on the wire, and asking for it any other way finds
/// nothing — so the name is translated both ways, and a user never has to know.
public enum MailboxName {
    public static func encode(_ name: String) -> String {
        var out = ""
        var pending: [UInt16] = []

        func flush() {
            guard !pending.isEmpty else { return }
            let bytes = pending.flatMap { [UInt8($0 >> 8), UInt8($0 & 0xFF)] }
            let base64 = Data(bytes).base64EncodedString()
                .replacingOccurrences(of: "/", with: ",")
                .replacingOccurrences(of: "=", with: "")
            out += "&" + base64 + "-"
            pending = []
        }

        for scalar in name.unicodeScalars {
            if scalar.value >= 0x20, scalar.value <= 0x7E {
                flush()
                out += scalar == "&" ? "&-" : String(scalar)
            } else {
                pending.append(contentsOf: String(scalar).utf16)
            }
        }
        flush()
        return out
    }

    /// Anything that does not decode is left as the server sent it: a folder with an odd name
    /// is still better shown oddly than not shown.
    public static func decode(_ wire: String) -> String {
        var out = ""
        var rest = Substring(wire)
        while let amp = rest.firstIndex(of: "&") {
            out += rest[rest.startIndex..<amp]
            let after = rest.index(after: amp)
            guard let dash = rest[after...].firstIndex(of: "-") else { return out + rest[amp...] }
            let chunk = rest[after..<dash]
            if chunk.isEmpty {
                out += "&"
            } else {
                var base64 = chunk.replacingOccurrences(of: ",", with: "/")
                base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
                guard let data = Data(base64Encoded: base64), data.count % 2 == 0 else { return out + rest[amp...] }
                let units = stride(from: 0, to: data.count, by: 2).map { UInt16(data[$0]) << 8 | UInt16(data[$0 + 1]) }
                out += String(decoding: units, as: UTF16.self)
            }
            rest = rest[rest.index(after: dash)...]
        }
        return out + rest
    }
}
