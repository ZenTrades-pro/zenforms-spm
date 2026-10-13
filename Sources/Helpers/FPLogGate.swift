//
//  FPLogGate.swift
//  ZenForms
//

import Foundation

/// Thread-safe "memory pressure" window. While active, large successful (non-error) network responses
/// and large database statements are not logged, so building them doesn't add to memory pressure.
/// Small logs and all error logs are unaffected.
enum FPLogGate {
    /// Successful responses bigger than this are skipped during the window.
    static let largeResponseBytes = 200_000
    /// Successful statements longer than this (characters) are skipped during the window.
    static let largeStatementChars = 20_000

    private static let lock = NSLock()
    private static var suppressedUntil: Date = .distantPast

    static func suppress(for seconds: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        suppressedUntil = Date().addingTimeInterval(seconds)
    }

    static var isSuppressing: Bool {
        lock.lock(); defer { lock.unlock() }
        return Date() < suppressedUntil
    }
}

/// Collects the SQL statements executed by the common/fp/form/bulk save (which runs on a queue tagged
/// with `key`) and sends one summary log per save instead of one log per statement.
enum FPBulkSaveLogScope {
    static let key = DispatchSpecificKey<Bool>()

    private static let lock = NSLock()
    private static var counts: [String: Int] = [:]

    static func record(_ sql: String) {
        let label = summaryLabel(for: sql)
        lock.lock(); defer { lock.unlock() }
        counts[label, default: 0] += 1
    }

    /// Sends the accumulated summary (if any) and resets the counts.
    static func flush() {
        lock.lock()
        let snapshot = counts
        counts.removeAll()
        lock.unlock()
        guard !snapshot.isEmpty else { return }
        let total = snapshot.values.reduce(0, +)
        let detail = snapshot.sorted { $0.key < $1.key }.map { "\($0.key) x\($0.value)" }.joined(separator: ", ")
        let modal = FPLoggerModal().setLoger(FPLoggerNames.customForms)
        modal.serviceName = FPLogServiceName.database.rawValue
        modal.message = "Bulk save summary (\(total) statements): \(detail)"
        FPDatadogWrapper.shared.sendDebugLog(modal)
    }

    /// e.g. "INSERT INTO FieldDetails (id,..." -> "INSERT FieldDetails"
    private static func summaryLabel(for sql: String) -> String {
        let tokens = sql.split(whereSeparator: { $0.isWhitespace }).prefix(8).map(String.init)
        let upper = tokens.map { $0.uppercased() }
        func token(after keyword: String) -> String? {
            guard let i = upper.firstIndex(of: keyword), i + 1 < tokens.count else { return nil }
            return tokens[i + 1]
        }
        func clean(_ name: String?) -> String {
            guard let name else { return "?" }
            return String(name.prefix { $0 != "(" })
        }
        switch upper.first {
        case "INSERT": return "INSERT \(clean(token(after: "INTO")))"
        case "UPDATE": return "UPDATE \(clean(tokens.count > 1 ? tokens[1] : nil))"
        case "DELETE": return "DELETE \(clean(token(after: "FROM")))"
        case "QUERY:": return "SELECT \(clean(token(after: "FROM")))"
        default: return "OTHER \(clean(tokens.first))"
        }
    }
}
