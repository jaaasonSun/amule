import Foundation

public enum FileNameEncodingRepair {
    public static func repairedSuggestion(for text: String) -> String? {
        let result = repair(text)
        return result.repaired ? result.text : nil
    }

    public static func repair(_ text: String, maxPasses: Int = 4) -> (text: String, repaired: Bool) {
        let original = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty else { return (text, false) }

        var current = original
        var repaired = false
        for _ in 0..<max(1, maxPasses) {
            guard let next = bestSinglePassCandidate(for: current), isBetter(next, than: current) else {
                break
            }
            current = next
            repaired = true
        }

        guard repaired, current != original else { return (text, false) }
        return (current, true)
    }

    private static func bestSinglePassCandidate(for text: String) -> String? {
        var candidates: [String] = []

        if looksPercentEncoded(text), let decoded = text.removingPercentEncoding {
            candidates.append(decoded)
        }

        if let decoded = decodeHTMLEntities(text) {
            candidates.append(decoded)
        }

        if let decoded = repairMojibakeRuns(text) {
            candidates.append(decoded)
        }

        if let decoded = reinterpretWindows1252BytesAsUTF8(text) {
            candidates.append(decoded)
        }

        return candidates
            .filter { !$0.isEmpty && $0 != text }
            .min { score($0) < score($1) }
    }

    private static func looksPercentEncoded(_ text: String) -> Bool {
        let scalars = Array(text.unicodeScalars)
        guard scalars.count >= 3 else { return false }
        var count = 0
        var index = 0
        while index + 2 < scalars.count {
            if scalars[index].value == 0x25,
               isHex(scalars[index + 1]),
               isHex(scalars[index + 2]) {
                count += 1
                index += 3
            } else {
                index += 1
            }
        }
        return count >= 2
    }

    private static func looksHTMLEntityEncoded(_ text: String) -> Bool {
        text.range(of: #"&(?:amp|lt|gt|quot|apos|#[0-9]{1,7}|#x[0-9a-fA-F]{1,6});"#, options: .regularExpression) != nil
    }

    private static func isHex(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 48...57, 65...70, 97...102:
            return true
        default:
            return false
        }
    }

    private static func decodeHTMLEntities(_ text: String) -> String? {
        guard looksHTMLEntityEncoded(text) else { return nil }

        var result = ""
        var index = text.startIndex
        var changed = false

        while index < text.endIndex {
            guard text[index] == "&",
                  let semicolon = text[index...].firstIndex(of: ";") else {
                result.append(text[index])
                index = text.index(after: index)
                continue
            }

            let entityStart = text.index(after: index)
            let entity = String(text[entityStart..<semicolon])
            if let replacement = htmlEntityReplacement(entity) {
                result.append(replacement)
                changed = true
                index = text.index(after: semicolon)
            } else {
                result.append(text[index])
                index = text.index(after: index)
            }
        }

        return changed ? result : nil
    }

    private static func htmlEntityReplacement(_ entity: String) -> String? {
        switch entity {
        case "amp": return "&"
        case "lt": return "<"
        case "gt": return ">"
        case "quot": return "\""
        case "apos": return "'"
        default:
            break
        }

        if entity.hasPrefix("#x") || entity.hasPrefix("#X") {
            let value = entity.dropFirst(2)
            guard let scalarValue = UInt32(value, radix: 16),
                  let scalar = Unicode.Scalar(scalarValue) else { return nil }
            return String(scalar)
        }

        if entity.hasPrefix("#") {
            let value = entity.dropFirst()
            guard let scalarValue = UInt32(value, radix: 10),
                  let scalar = Unicode.Scalar(scalarValue) else { return nil }
            return String(scalar)
        }

        return nil
    }

    private static func repairMojibakeRuns(_ text: String) -> String? {
        let scalars = Array(text.unicodeScalars)
        var result = ""
        var changed = false
        var index = 0

        while index < scalars.count {
            let value = scalars[index].value
            guard isCommonMojibakeLead(value),
                  index + 1 < scalars.count,
                  isMojibakeByteLike(scalars[index + 1].value) else {
                result.unicodeScalars.append(scalars[index])
                index += 1
                continue
            }

            var bytes: [UInt8] = []
            let start = index
            while index < scalars.count,
                  let byte = windows1252Byte(for: scalars[index].value) {
                bytes.append(byte)
                index += 1

                if index >= scalars.count {
                    break
                }
                let currentLooksLikeLead = isCommonMojibakeLead(scalars[index].value)
                let previousWasLead = isCommonMojibakeLead(scalars[index - 1].value)
                let currentContinuesPrevious = previousWasLead && isMojibakeByteLike(scalars[index].value)
                if !currentLooksLikeLead && !currentContinuesPrevious {
                    break
                }
            }

            if let repaired = String(data: Data(bytes), encoding: .utf8), !repaired.isEmpty {
                result.append(repaired)
                changed = true
            } else {
                for scalar in scalars[start..<index] {
                    result.unicodeScalars.append(scalar)
                }
            }
        }

        return changed && result != text ? result : nil
    }

    private static func reinterpretWindows1252BytesAsUTF8(_ text: String) -> String? {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(text.unicodeScalars.count)

        for scalar in text.unicodeScalars {
            guard let byte = windows1252Byte(for: scalar.value) else { return nil }
            bytes.append(byte)
        }

        guard !bytes.isEmpty else { return nil }
        return String(data: Data(bytes), encoding: .utf8)
    }

    private static func windows1252Byte(for value: UInt32) -> UInt8? {
        if value <= 0x00ff {
            return UInt8(value)
        }

        switch value {
        case 0x20ac: return 0x80
        case 0x201a: return 0x82
        case 0x0192: return 0x83
        case 0x201e: return 0x84
        case 0x2026: return 0x85
        case 0x2020: return 0x86
        case 0x2021: return 0x87
        case 0x02c6: return 0x88
        case 0x2030: return 0x89
        case 0x0160: return 0x8a
        case 0x2039: return 0x8b
        case 0x0152: return 0x8c
        case 0x017d: return 0x8e
        case 0x2018: return 0x91
        case 0x2019: return 0x92
        case 0x201c: return 0x93
        case 0x201d: return 0x94
        case 0x2022: return 0x95
        case 0x2013: return 0x96
        case 0x2014: return 0x97
        case 0x02dc: return 0x98
        case 0x2122: return 0x99
        case 0x0161: return 0x9a
        case 0x203a: return 0x9b
        case 0x0153: return 0x9c
        case 0x017e: return 0x9e
        case 0x0178: return 0x9f
        default: return nil
        }
    }

    private static func isBetter(_ candidate: String, than original: String) -> Bool {
        let originalScore = score(original)
        let candidateScore = score(candidate)

        if looksPercentEncoded(original),
           !looksPercentEncoded(candidate),
           candidate.count <= original.count {
            return true
        }

        if looksHTMLEntityEncoded(original),
           !looksHTMLEntityEncoded(candidate),
           candidate.count <= original.count {
            return true
        }

        if looksHTMLEntityEncoded(original),
           candidate.count < original.count,
           candidateScore <= originalScore {
            return true
        }

        guard originalScore >= candidateScore + 2 else { return false }
        if isHighConfidenceCJKRepair(candidate: candidate, candidateScore: candidateScore, originalScore: originalScore) {
            return candidate.count * 3 + 4 >= original.count
        }
        return candidate.count * 2 + 4 >= original.count
    }

    private static func isHighConfidenceCJKRepair(candidate: String, candidateScore: Int, originalScore: Int) -> Bool {
        originalScore >= 24 &&
            candidateScore <= 2 &&
            containsCJKScalar(candidate)
    }

    private static func score(_ text: String) -> Int {
        var result = 0
        let scalars = Array(text.unicodeScalars)

        for index in scalars.indices {
            let value = scalars[index].value

            if value == 0xfffd {
                result += 8
            } else if value < 0x20, value != 0x09, value != 0x0a, value != 0x0d {
                result += 5
            } else if (0x80...0x9f).contains(value) {
                result += 4
            }

            if isCommonMojibakeLead(value) {
                result += 1
                if index + 1 < scalars.count, isMojibakeContinuation(scalars[index + 1].value) {
                    result += 3
                }
            }

            if value == 0x25, index + 2 < scalars.count, isHex(scalars[index + 1]), isHex(scalars[index + 2]) {
                result += 1
            }
        }

        if looksHTMLEntityEncoded(text) {
            result += 2
            result += text.components(separatedBy: "&").count - 1
        }

        return result
    }

    private static func containsCJKScalar(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3040...0x30ff, 0x3400...0x4dbf, 0x4e00...0x9fff, 0xf900...0xfaff:
                return true
            default:
                return false
            }
        }
    }

    private static func isCommonMojibakeLead(_ value: UInt32) -> Bool {
        switch value {
        case 0x00c2, 0x00c3, 0x00c4, 0x00c5, 0x00c6, 0x00c7, 0x00c8, 0x00c9,
             0x00d0, 0x00d1, 0x00e2, 0x00e3, 0x00e4, 0x00e5, 0x00e6, 0x00e7,
             0x00e8, 0x00e9:
            return true
        default:
            return false
        }
    }

    private static func isMojibakeContinuation(_ value: UInt32) -> Bool {
        (0x0080...0x00bf).contains(value) ||
            (0x00a0...0x00ff).contains(value) ||
            (0x0100...0x01ff).contains(value)
    }

    private static func isMojibakeByteLike(_ value: UInt32) -> Bool {
        value >= 0x80 && windows1252Byte(for: value) != nil
    }
}
