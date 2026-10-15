import Foundation

public enum Format {
    static let locale = Locale(identifier: "it_IT")

    /// -1234 -> "-€ 12,34", 123456 -> "€ 1.234,56"
    public static func euros(_ cents: Int) -> String {
        let sign = cents < 0 ? "-" : ""
        let value = cents.magnitude
        var grouped = ""
        for (index, digit) in String(value / 100).reversed().enumerated() {
            if index > 0 && index % 3 == 0 { grouped.append(".") }
            grouped.append(digit)
        }
        let decimals = value % 100
        return "\(sign)€ \(String(grouped.reversed())),\(decimals < 10 ? "0" : "")\(decimals)"
    }

    /// Accetta "20", "20,50", "€ 1.200,00", "-5". Restituisce i centesimi.
    public static func parseEuros(_ text: String) -> Int? {
        var cleaned = text
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: " ", with: "")
        if cleaned.contains(",") {
            cleaned = cleaned
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
        }
        guard let value = Double(cleaned), value.isFinite, abs(value) < 1_000_000 else { return nil }
        return Int((value * 100).rounded())
    }

    public static func duration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(rest) min" }
        return rest == 0 ? "\(hours) h" : "\(hours) h \(rest)"
    }

    /// minuti dalla mezzanotte -> "18:30"
    public static func clock(minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = format
        return formatter
    }

    private static let dayFormatter = formatter("EEEE d MMMM")
    private static let shortFormatter = formatter("EEE d MMM, HH:mm")
    private static let timeFormatter = formatter("HH:mm")
    private static let timestampFormatter = formatter("dd/MM/yyyy HH:mm")

    /// "Lunedì 12 ottobre"
    public static func day(_ date: Date) -> String {
        let text = dayFormatter.string(from: date)
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// "lun 12 ott, 18:30"
    public static func dateTime(_ date: Date) -> String {
        shortFormatter.string(from: date)
    }

    public static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    public static func timeRange(_ start: Date, _ end: Date) -> String {
        "\(time(start))–\(time(end))"
    }

    public static func timestamp(_ date: Date) -> String {
        timestampFormatter.string(from: date)
    }
}
