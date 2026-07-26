enum ServerDateParser {
    private static let isoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Parses ISO-like timestamps with ANY number of fractional-second digits
    /// (.NET's "o" format sends 7 — Apple's formatter only accepts 3).
    static func parse(_ raw: String) -> Date {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return Date() }

        // Normalize fractional seconds to exactly 3 digits
        if let dot = s.firstIndex(of: ".") {
            let start = s.index(after: dot)
            var end = start
            while end < s.endIndex, s[end].isNumber { end = s.index(after: end) }
            let digits = String(s[start..<end])
            let ms = String((digits + "000").prefix(3))
            s.replaceSubrange(start..<end, with: ms)
        }

        let hasTZ = s.hasSuffix("Z") || s.range(of: #"[+-]\d{2}:\d{2}$"#, options: .regularExpression) != nil
        let candidate = hasTZ ? s : s + "Z"   // assume UTC if backend omitted the zone

        if let d = isoFraction.date(from: candidate) { return d }
        if let d = isoPlain.date(from: candidate) { return d }

        // Legacy fallback for old "HH:mm"-only payloads, just in case
        if s.count <= 5, s.contains(":") {
            let f = DateFormatter(); f.dateFormat = "HH:mm"; f.timeZone = .current
            if let t = f.date(from: s) {
                var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                let tc = Calendar.current.dateComponents([.hour, .minute], from: t)
                c.hour = tc.hour; c.minute = tc.minute
                if let combined = Calendar.current.date(from: c) { return combined }
            }
        }

        print("⚠️ ServerDateParser failed for '\(raw)' — using now")
        return Date()
    }
}