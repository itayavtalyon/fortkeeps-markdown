/// Escapes text for Markdown only where a character would otherwise start
/// syntax (design log 001 › Paste).
struct MarkdownEscaper {
    let escapesPipes: Bool

    /// `previous` and `next` are the characters around `text` in the output,
    /// nil at a line's start or end.
    func escape(_ text: String, atLineStart: Bool, previous: Character?, next: Character?) -> String {
        let characters = Array(text)
        var output = ""
        let lineStartEscape = atLineStart ? Self.lineStartEscape(text) : nil
        for (index, character) in characters.enumerated() {
            let before = index > 0 ? characters[index - 1] : previous
            let after = index + 1 < characters.count ? characters[index + 1] : next
            if index == lineStartEscape || needsEscape(
                character,
                before: before,
                after: after,
                rest: characters[index...]
            ) {
                output.append("\\")
            }
            output.append(character)
        }
        return output
    }

    /// The index of the character to escape so a line does not start a
    /// heading, quote, list item, thematic break, or setext underline.
    static func lineStartEscape(_ line: String) -> Int? {
        if line.wholeMatch(of: /=+ */) != nil || line.wholeMatch(of: /(?:([-*_]) *){3,}/) != nil {
            return 0
        }
        let startsBlock = line.prefixMatch(of: /#{1,6}(?: |$)/) != nil || line.prefixMatch(of: /[-+*](?: |$)/) != nil
        if startsBlock || line.hasPrefix(">") {
            return 0
        }
        if let match = line.prefixMatch(of: /(\d{1,9})[.)](?: |$)/) {
            return match.1.count
        }
        return nil
    }

    private func needsEscape(
        _ character: Character,
        before: Character?,
        after: Character?,
        rest: ArraySlice<Character>
    ) -> Bool {
        let flanking = !Self.isSpace(before) || !Self.isSpace(after)
        switch character {
        case "\\": return after.map { $0.isASCII && $0.isPunctuation || $0.isASCII && $0.isSymbol } ?? false
        case "`", "[": return true
        case "*", "~": return flanking
        case "_": return flanking && !(Self.isWord(before) && Self.isWord(after))
        case "<": return after.map { $0.isLetter || "/!?".contains($0) } ?? false
        case "&": return Self.startsEntity(String(rest))
        case "|": return escapesPipes
        default: return false
        }
    }

    /// True when the text starts with an entity that CommonMark decodes;
    /// `&unknown;` is not one and stays as it is.
    private static func startsEntity(_ text: String) -> Bool {
        guard let match = text.prefixMatch(of: /&#?[A-Za-z0-9]+;/) else { return false }
        return HTMLParser.decode(ArraySlice(match.0.utf8)) != String(match.0)
    }

    private static func isSpace(_ character: Character?) -> Bool {
        character.map(\.isWhitespace) ?? true
    }

    private static func isWord(_ character: Character?) -> Bool {
        character.map { $0.isLetter || $0.isNumber } ?? false
    }
}
