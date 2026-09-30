//
//  FPFormAutofill.swift
//  ZenForms
//
//  Speech-only AI autofill for a single FPForm section, built on ZTAIServices'
//  key-agnostic ZTFormAutofillCoordinator (same coordinator Customer/Asset/Equipment
//  already use). This file holds only the pure, stateless pieces — which fields are
//  eligible, the context sent to the model, and matching a spoken answer back to a
//  field's predefined options. Coordinator lifecycle and applying results live in
//  FPFormViewController itself, since that's where the field-write path
//  (FPFormDataHolder.updateRowWith) and table reload already live.
//

import Foundation
import ZTAIServices

/// Debug logging for the speech autofill pipeline (section and row), gated behind the same
/// `CloudAPIConfiguration.isLoggingEnabled` flag ZTAIServices' own `[AUTOFILL_TIMING]`/
/// `[AUTOFILL_DEBUG]` logs already respect — quiet by default, not a separate on/off switch
/// to remember. `@autoclosure` so the (often string-interpolation-heavy) message isn't
/// built at all when logging is off.
func autofillLog(_ message: @autoclosure () -> String) {
    guard CloudAPIConfiguration.isLoggingEnabled else { return }
    print(message())
}

/// Which FPForm field UI types this feature can autofill from speech.
enum FPFormAutofillFieldEligibility {
    /// Excluded, and why:
    /// - CHART, LABEL, HIDDEN: not user-entered data.
    /// - SIGNATURE_PAD, SCANNER, FILE: capture-only, not speakable.
    /// - AUTO_POPULATE: computed, not user input.
    /// - TABLE_SUMMARY: derived from a table's own rows.
    /// - TABLE, TABLE_RESTRICTED: explicitly deferred to a future autofill design
    ///   scoped to FPTableEdditViewController.
    ///
    /// DATE/TIME/DATE_TIME/YEAR dataTypes ARE included (still uiType .INPUT) — the
    /// extraction prompt asks the model for a fixed machine-readable format per type (see
    /// `FPFormAutofillFieldContext.dateFormatHint`/`FPFormAutofillContextBuilder`), and
    /// `FPFormAutofillDateParser` converts that into the exact string
    /// `field.value` actually needs: `FPUtility.getStringWithTZFormat`'s
    /// `"yyyy-MM-dd'T'HH:mm:ss.SSSZ"` UTC format — confirmed as the ONE universal storage
    /// format for all four dataTypes by reading FPInputFieldCell/FPFormDataHolder/FPUtility
    /// (FPFORM_DATE_FORMAT is display-only, never what's persisted). Writing the model's
    /// raw natural-language text directly (the first version of this) left these fields
    /// blank after Fill, since the picker cell couldn't parse it.
    ///
    /// BUTTON_RADIO IS included: it's FPForm's deficiency/reason segment control
    /// (Yes/No/N/A or custom `radioOptions`, via `FPFieldDetails.getRadioOptions()` —
    /// the no-arg overload in FPDeficiencySegmentCell.swift). The naive write path
    /// (`FPFormDataHolder.updateRowWith(value:inSection:atIndex:)`) is NOT used for it —
    /// that overload's `.BUTTON_RADIO` branch is attachment-specific (hardcodes
    /// `field.value = "NO"` and parses `value` as a file array). The real segment-pick
    /// write path, `updateRowWith(reasons:value:inSection:atIndex:)`, is what
    /// FPDeficiencySegmentCell.setValueFromSelectedIndex actually calls — see
    /// FPFormViewController.applySectionAutofillCandidates, which routes BUTTON_RADIO
    /// candidates through that overload, passing the field's existing `reasons` JSON
    /// through unchanged (only `value` — the selected segment — changes; filling in a
    /// full custom deficiency description/attachments via speech stays manual).
    static func isEligible(_ uiType: FPDynamicUITypes) -> Bool {
        switch uiType {
        case .INPUT, .TEXTAREA, .DROPDOWN, .RADIO, .CHECKBOX, .BUTTON_RADIO:
            return true
        case .CHART, .SIGNATURE_PAD, .AUTO_POPULATE, .LABEL, .HIDDEN, .SCANNER,
             .FILE, .TABLE_SUMMARY, .TABLE_RESTRICTED, .TABLE:
            return false
        }
    }

    /// Full eligibility check — currently just the uiType check; kept as its own function
    /// (rather than inlining `isEligible(field.getUIType())` at the call site) since
    /// eligibility has already needed a field-level exception once (date/time types) and
    /// is a more natural place to add another than the uiType-only function.
    static func isEligible(field: FPFieldDetails) -> Bool {
        isEligible(field.getUIType())
    }
}

/// One eligible field within a section, captured at the moment capture starts so the
/// prompt context, the AI response mapping, and the eventual row write all agree on the
/// same row index even if the user edits the form while the review sheet is open.
struct FPFormAutofillFieldContext {
    let field: FPFieldDetails
    let rowIndex: Int
    let uiType: FPDynamicUITypes
    let dataType: FPDynamicDataTypes
    /// Populated for DROPDOWN/RADIO/CHECKBOX/BUTTON_RADIO only; empty otherwise.
    let options: [FPFieldOption]

    var label: String {
        let displayName = field.displayName?.trim ?? ""
        return displayName.isEmpty ? (field.name ?? "") : displayName
    }

    /// For DATE/TIME/DATE_TIME/YEAR fields: the machine-readable format instruction added
    /// to this field's line in the extraction context, and what `FPFormAutofillDateParser`
    /// expects back. nil for every other dataType.
    var dateFormatHint: (instruction: String, parseFormat: String)? {
        switch dataType {
        case .DATE: return ("date, answer as YYYY-MM-DD", "yyyy-MM-dd")
        case .TIME: return ("time, answer as HH:MM in 24-hour time", "HH:mm")
        case .DATE_TIME: return ("date and time, answer as YYYY-MM-DD HH:MM in 24-hour time", "yyyy-MM-dd HH:mm")
        case .YEAR: return ("year, answer as a 4-digit YYYY", "yyyy")
        default: return nil
        }
    }
}

enum FPFormAutofillContextBuilder {
    /// The eligible fields of a section, in the same order/index as
    /// `FPFormDataHolder.shared.getFieldsIn(section:)` — i.e. `rowIndex` is a valid
    /// table row index for `updateRowWith(value:inSection:atIndex:)`.
    static func eligibleFields(forSection sectionIndex: Int) -> [FPFormAutofillFieldContext] {
        let fields = FPFormDataHolder.shared.getFieldsIn(section: sectionIndex)
        var result: [FPFormAutofillFieldContext] = []
        result.reserveCapacity(fields.count)

        for (row, field) in fields.enumerated() {
            let uiType = field.getUIType()
            guard FPFormAutofillFieldEligibility.isEligible(field: field), field.templateId != nil else { continue }

            var options: [FPFieldOption] = []
            switch uiType {
            case .DROPDOWN:
                // getDropdownOptions() prepends a "SELECT" placeholder — not a real choice.
                options = field.getDropdownOptions().filter { ($0.label ?? "").trim.isEmpty == false }
                    .filter { $0.value?.trim.isEmpty == false }
            case .RADIO, .CHECKBOX:
                options = field.getRadioOptions(inSection: sectionIndex, row: row, uiType: uiType)
            case .BUTTON_RADIO:
                // Separate no-arg overload (FPDeficiencySegmentCell.swift) reading
                // field.options.radioOptions as raw dicts — same UI the segmented
                // control itself uses, falling back to Yes/No/N/A when empty.
                let rawOptions = field.getRadioOptions()
                if rawOptions.isEmpty {
                    options = [
                        FPFieldOption(key: "Yes", label: FPLocalizationHelper.localize("Yes"), value: "Yes"),
                        FPFieldOption(key: "NO", label: FPLocalizationHelper.localize("NO"), value: "NO"),
                        FPFieldOption(key: "N/A", label: "N/A", value: "N/A")
                    ]
                } else {
                    options = rawOptions.map { dict in
                        let label = dict["label"] as? String ?? ""
                        let value = dict["value"] as? String ?? label
                        return FPFieldOption(key: value, label: label, value: value)
                    }.filter { !($0.label ?? "").trim.isEmpty }
                }
            default:
                break
            }

            result.append(FPFormAutofillFieldContext(field: field, rowIndex: row, uiType: uiType, dataType: field.getDataType(), options: options))
        }
        return result
    }

    /// The `<context>` text handed to ZTAIServices' `.fpFormSection` extraction — one
    /// line per eligible field, its label, and (for choice fields) its allowed options.
    /// The extraction prompt (TextAIService.pageFieldFocus for `.dynamicForm`) describes
    /// this exact shape and instructs the model to key its `fields` output by these
    /// labels verbatim.
    static func supplementalContext(for fields: [FPFormAutofillFieldContext]) -> String {
        fields.map { ctx -> String in
            if let hint = ctx.dateFormatHint {
                return "- \"\(ctx.label)\" (\(hint.instruction))"
            }
            guard !ctx.options.isEmpty else { return "- \"\(ctx.label)\"" }
            let optionLabels = ctx.options.compactMap { $0.label?.trim }.filter { !$0.isEmpty }
            guard !optionLabels.isEmpty else { return "- \"\(ctx.label)\"" }
            return "- \"\(ctx.label)\" (options: \(optionLabels.joined(separator: ", ")))"
        }.joined(separator: "\n")
    }
}

/// Converts the machine-readable date/time/year text the model was asked for (via
/// `FPFormAutofillFieldContext.dateFormatHint`) into a `Date`, ready for
/// `FPUtility.getStringWithTZFormat` to turn into the exact string FPForm's date/time
/// picker cells expect. Uses the device's current calendar/timezone when building each
/// `Date` — the same "local wall-clock components → Date" step a manual date picker does
/// before that same `getStringWithTZFormat` call reformats it, so a value entered here
/// round-trips and displays identically to one entered by hand on this device.
enum FPFormAutofillDateParser {
    static func parse(_ rawValue: String, dataType: FPDynamicDataTypes) -> Date? {
        let trimmed = rawValue.trim
        guard !trimmed.isEmpty else { return nil }

        switch dataType {
        case .YEAR:
            guard let year = Int(trimmed) else { return nil }
            var comps = DateComponents()
            comps.year = year
            comps.month = 1
            comps.day = 1
            comps.hour = 0
            comps.minute = 0
            comps.second = 0
            return Calendar.current.date(from: comps)

        case .TIME:
            let formatter = makeFormatter(dateFormat: "HH:mm")
            guard let timeOnly = formatter.date(from: trimmed) else { return nil }
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            let timeComps = Calendar.current.dateComponents([.hour, .minute], from: timeOnly)
            comps.hour = timeComps.hour
            comps.minute = timeComps.minute
            comps.second = 0
            return Calendar.current.date(from: comps)

        case .DATE:
            return makeFormatter(dateFormat: "yyyy-MM-dd").date(from: trimmed)

        case .DATE_TIME:
            return makeFormatter(dateFormat: "yyyy-MM-dd HH:mm").date(from: trimmed)

        default:
            return nil
        }
    }

    /// A human-readable string for the review sheet, matching `FPFORM_DATE_FORMAT`'s
    /// per-type display pattern (display-only, same as the manual picker cell — never
    /// written to `field.value`).
    static func displayString(for date: Date, dataType: FPDynamicDataTypes) -> String? {
        let pattern: String
        switch dataType {
        case .DATE: pattern = FPFORM_DATE_FORMAT.DATE.rawValue
        case .TIME: pattern = FPFORM_DATE_FORMAT.TIME.rawValue
        case .DATE_TIME: pattern = FPFORM_DATE_FORMAT.DATE_TIME.rawValue
        case .YEAR: pattern = FPFORM_DATE_FORMAT.YEAR.rawValue
        default: return nil
        }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

    private static func makeFormatter(dateFormat: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = dateFormat
        return formatter
    }
}

/// The result of matching a spoken/extracted answer against a field's predefined options.
struct FPFormAutofillMatchResult {
    /// The single best guess — what gets pre-filled/pre-selected.
    let best: FPFieldOption
    /// True for a clean exact match (case/whitespace-normalized) — these are confident
    /// enough to accept without a second look. False for anything found via near-matching.
    let isExact: Bool
    /// Other close options, best-first, excluding `best` — surfaced as a quick "did you
    /// mean" picker in review when the match wasn't exact, so the user can correct a
    /// fuzzy guess with one tap instead of re-recording or opening the field manually.
    let alternatives: [FPFieldOption]
}

/// Matches a spoken/extracted answer against a field's predefined options. Exact match
/// first (case/whitespace-normalized), then a bounded near-match, ranking every option
/// that clears the threshold rather than only the single best one. Returns nil rather
/// than guessing when nothing clears the threshold at all — callers must leave the field
/// unfilled and let the review sheet surface it as unmatched.
enum FPFormAutofillMatcher {
    static func rankedMatch(for rawAnswer: String, options: [FPFieldOption], maxAlternatives: Int = 2) -> FPFormAutofillMatchResult? {
        let candidates = options.filter { ($0.label ?? "").trim.isEmpty == false }
        guard !candidates.isEmpty else { return nil }

        let normalizedAnswer = normalize(rawAnswer)
        guard !normalizedAnswer.isEmpty else { return nil }

        if let exact = candidates.first(where: { normalize($0.label ?? "") == normalizedAnswer }) {
            return FPFormAutofillMatchResult(best: exact, isExact: true, alternatives: [])
        }

        var scored: [(option: FPFieldOption, score: Int)] = []
        for option in candidates {
            let normalizedLabel = normalize(option.label ?? "")
            guard !normalizedLabel.isEmpty else { continue }

            if normalizedLabel.contains(normalizedAnswer) || normalizedAnswer.contains(normalizedLabel) {
                scored.append((option, abs(normalizedLabel.count - normalizedAnswer.count)))
                continue
            }

            let distance = levenshteinDistance(normalizedAnswer, normalizedLabel)
            let threshold = max(2, normalizedLabel.count / 3)
            if distance <= threshold {
                scored.append((option, distance))
            }
        }
        guard !scored.isEmpty else { return nil }
        scored.sort { $0.score < $1.score }

        let best = scored[0].option
        let alternatives = scored.dropFirst().prefix(maxAlternatives).map { $0.option }
        return FPFormAutofillMatchResult(best: best, isExact: false, alternatives: Array(alternatives))
    }

    /// Convenience for callers that only need the single best guess.
    static func matchedOption(for rawAnswer: String, options: [FPFieldOption]) -> FPFieldOption? {
        rankedMatch(for: rawAnswer, options: options)?.best
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func levenshteinDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)

        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = Swift.min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            previous = current
        }
        return previous[b.count]
    }
}
