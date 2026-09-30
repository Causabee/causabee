import Foundation

/// A comma-separated file, read and written the way a spreadsheet does it.
///
/// Small on purpose. The golden set is fifty rows typed by hand in Numbers, and what it needs
/// is a reader that does not fall over on a subject line with a comma in it, a quotation mark
/// inside a quoted field, or the byte-order mark Numbers puts at the front of a UTF-8 export.
///
/// Nor on a semicolon. Numbers on a German Mac exports with `;` between fields, because there the
/// comma is the decimal separator, and there is no setting in the export sheet to change it.
enum CSV {
    static func rows(_ text: String) -> [[String]] {
        // Line endings first, and for a reason worth remembering: Swift reads CR LF as a single
        // Character, so neither `case "\r"` nor `case "\n"` ever matches one and every row of a
        // Windows-or-Excel file runs into the next.
        var text = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        let separator = separator(of: text)

        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        let characters = Array(text)
        var index = 0

        func endField() { row.append(field); field = "" }
        func endRow() {
            endField()
            // A trailing newline is not an empty last row.
            if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
            row = []
        }

        while index < characters.count {
            let character = characters[index]
            if quoted {
                if character == "\"" {
                    if index + 1 < characters.count, characters[index + 1] == "\"" {
                        field.append("\"")
                        index += 1
                    } else {
                        quoted = false
                    }
                } else {
                    field.append(character)
                }
            } else {
                switch character {
                case "\"": quoted = true
                case separator: endField()
                case "\n": endRow()
                default: field.append(character)
                }
            }
            index += 1
        }
        if !field.isEmpty || !row.isEmpty { endRow() }
        return rows
    }

    /// Whichever of `,` and `;` the header line uses more of. The header is column names only, so
    /// the count is not thrown off by a subject line full of commas.
    static func separator(of text: String) -> Character {
        let header = text.prefix { $0 != "\n" }
        return header.filter { $0 == ";" }.count > header.filter { $0 == "," }.count ? ";" : ","
    }

    static func line(_ fields: [String]) -> String {
        fields.map(escaped).joined(separator: ",")
    }

    static func escaped(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r")
        else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
