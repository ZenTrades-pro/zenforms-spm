import Foundation

public struct FPAssetTokenContext {
    public let asset: [String: Any]
    public let assetType: [String: Any]?
    public let ticketAsset: [String: Any]

    public init(asset: [String: Any], assetType: [String: Any]? = nil, ticketAsset: [String: Any] = [:]) {
        self.asset = asset
        self.assetType = assetType
        self.ticketAsset = ticketAsset
    }
}

public enum FPAssetTokens {
    static let didFillField = Notification.Name("ZenForms.assetTokenFieldFilled")
    public static let sources: Set<String> = ["ASSET", "ASSET_CUSTOM_FIELD", "INSPECTION_SCHEDULE"]

    public static func build(_ context: FPAssetTokenContext, today: Date = Date(), timeZone: TimeZone = .current) -> [String: [String: String]] {
        var asset = context.asset
        var fields = asset["customFieldValues"] as? [[String: Any]] ?? []
        if let type = context.assetType {
            if text(asset["assetTypeName"]).isEmpty { asset["assetTypeName"] = type["name"] }
            let definitions = type["customFields"] as? [[String: Any]] ?? []
            fields = fields.compactMap { field in
                guard let definition = definitions.first(where: { text($0["id"]) == text(field["assetCustomFieldId"]) && !text($0["id"]).isEmpty }) else { return nil }
                var enriched = field
                for key in ["name", "displayName", "dataType", "uiType"] where text(enriched[key]).isEmpty {
                    enriched[key] = definition[key]
                }
                return enriched
            }
        }
        var values: [String: String] = [:]
        for key in ["name", "serialNumber", "model", "brand", "position", "assetTypeName"] {
            let value = text(asset[key])
            if !value.isEmpty { values[key] = value }
        }
        for key in ["installedAt", "warrantyExpiresAt"] {
            if let date = instant(asset[key]) { values[key] = format(date, zone: timeZone) }
        }
        var custom: [String: String] = [:]
        for field in fields {
            let key = text(field["name"]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty, !["DERIVED", "ATTACHMENT"].contains(text(field["uiType"])) else { continue }
            let value: String
            if text(field["dataType"]) == "DATE" {
                value = instant(field["value"]).map { format($0, zone: TimeZone(secondsFromGMT: 0)!) } ?? ""
            } else if let array = field["value"] as? [Any] {
                value = array.map(text).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: ", ")
            } else {
                value = text(field["value"])
            }
            if !value.isEmpty { custom[key] = value }
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: today)
        let localDay = String(format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)
        return ["ASSET": values, "ASSET_CUSTOM_FIELD": custom,
                "INSPECTION_SCHEDULE": schedules(asset: asset, ticketAsset: context.ticketAsset, today: localDay)]
    }

    public static func lookup(_ tokens: [String: [String: String]], source: String, entity: String) -> String {
        let key = source == "ASSET_CUSTOM_FIELD" ? entity.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() : entity
        return tokens[source]?[key] ?? ""
    }

    public static func schedules(asset: [String: Any], ticketAsset: [String: Any], today: String) -> [String: String] {
        guard let current = day(today) else { return [:] }
        let visits = (ticketAsset["inspectionSchedules"] as? [[String: Any]] ?? []).filter { text($0["status"]) == "ACTIVE" }
        let records = (asset["inspectionDates"] as? [String: Any])?["bySchedule"] as? [[String: Any]] ?? []
        let units = ["MONTHLY": 1, "QUARTERLY": 3, "SEMI_ANNUAL": 6, "ANNUAL": 12, "THREE_YEARLY": 36, "FIVE_YEARLY": 60, "SIX_YEARLY": 72, "TEN_YEARLY": 120]
        var result: [String: String] = [:]
        for record in records where text(record["status"]) == "ACTIVE" {
            let id = text(record["scheduleId"])
            guard !id.isEmpty else { continue }
            let prefix = "inspectionSchedule.\(id)."
            guard let visit = visits.first(where: { text($0["inspectionScheduleId"]) == id }) else {
                if let last = day(record["lastInspectionDate"]) { result[prefix + "last"] = format(last, zone: utc.timeZone) }
                if let next = day(record["nextInspectionDate"]) { result[prefix + "next"] = format(next, zone: utc.timeZone) }
                continue
            }
            result[prefix + "last"] = format(current, zone: utc.timeZone)
            guard let months = units[text(visit["frequencyUnit"])] else { continue }
            let raw = Double(text(visit["frequencyValue"])) ?? 1
            let multiplier = raw.isFinite && raw > 0 && raw.rounded(.down) == raw ? raw : 1
            guard multiplier <= Double(120000 / months) else { continue }
            let interval = months * Int(multiplier)
            var next: Date?
            if text(visit["recurrenceType"]) == "ANCHORED" {
                guard let anchor = day(visit["anchorDate"]) else { continue }
                let threshold = max(current, day(record["nextInspectionDate"]) ?? current)
                let difference = utc.dateComponents([.month], from: anchor, to: threshold).month ?? 0
                var slot = max(0, difference / interval)
                while slot < 120001 {
                    guard let candidate = addMonths(anchor, slot * interval) else { break }
                    if candidate > threshold { next = candidate; break }
                    slot += 1
                }
            } else {
                next = addMonths(current, interval)
            }
            if let next { result[prefix + "next"] = format(next, zone: utc.timeZone) }
        }
        return result
    }

    private static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func addMonths(_ date: Date, _ count: Int) -> Date? {
        let parts = utc.dateComponents([.year, .month, .day], from: date)
        guard let first = utc.date(from: DateComponents(year: parts.year, month: parts.month, day: 1)),
              let target = utc.date(byAdding: .month, value: count, to: first),
              let range = utc.range(of: .day, in: .month, for: target) else { return nil }
        return utc.date(byAdding: .day, value: min(parts.day ?? 1, range.count) - 1, to: target)
    }

    private static func day(_ raw: Any?) -> Date? {
        let value = String(text(raw).prefix(10))
        let formatter = DateFormatter()
        formatter.calendar = utc
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = utc.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: value), formatter.string(from: date) == value else { return nil }
        return date
    }

    private static func instant(_ raw: Any?) -> Date? {
        let value = text(raw)
        guard !value.isEmpty else { return nil }
        if let milliseconds = Double(value), milliseconds.isFinite { return Date(timeIntervalSince1970: milliseconds / 1000) }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = parser.date(from: value) { return date }
        parser.formatOptions = [.withInternetDateTime]
        return parser.date(from: value) ?? day(value)
    }

    private static func text(_ raw: Any?) -> String {
        if let string = raw as? String { return string }
        if let number = raw as? NSNumber { return number.stringValue }
        return ""
    }

    private static func format(_ date: Date, zone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.calendar = utc
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = zone
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.string(from: date)
    }
}
