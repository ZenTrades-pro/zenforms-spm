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
import UIKit

/// Extra bottom scroll room while the recording panel is up, so the last row can be
/// scrolled clear of the screen edge. Removed again the moment recording ends.
enum FPAutofillScrollRoom {
    static let height: CGFloat = 80

    /// Adds the room (remembering the inset it started from) or restores that inset.
    static func set(_ on: Bool, for scrollView: UIScrollView, base: inout CGFloat?) {
        if on {
            if base == nil { base = scrollView.contentInset.bottom }
            let bottom = (base ?? 0) + height
            scrollView.contentInset.bottom = bottom
            scrollView.verticalScrollIndicatorInsets.bottom = bottom
        } else if let original = base {
            scrollView.contentInset.bottom = original
            scrollView.verticalScrollIndicatorInsets.bottom = original
            base = nil
            // Without the extra room the current offset can sit past the new end.
            let maxY = max(-scrollView.adjustedContentInset.top,
                           scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom)
            if scrollView.contentOffset.y > maxY {
                scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: maxY), animated: false)
            }
        }
    }
}

/// Full-screen wrapper around the autofill sheet's hosting view. A bare hosting view claims
/// every point in its bounds even where nothing is drawn, which froze the form behind the
/// sheet. While the recording controls are up, this wrapper claims only the panel, so a drag
/// anywhere above it reaches the form (which is view-only at that step).
final class FPAutofillTouchPassthroughView: UIView {
    struct State {
        /// true only while the recording controls are up: drags above the panel then scroll
        /// the screen behind, so it can be scrolled while the user describes. At every other
        /// step this is false and the sheet's own dim blocks the screen behind.
        var passesTouchesOutsidePanel: Bool
    }

    /// nil = the sheet isn't showing (claim nothing).
    var stateProvider: (() -> State?)?

    /// When set, a drag outside the panel (while recording) scrolls this view directly
    /// instead of relying on the touch reaching it through the screen's own views. Taps
    /// outside the panel then do nothing, so the form behind stays view-only.
    weak var scrollTarget: UIScrollView?

    private var startOffsetY: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:))))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func recordingState() -> State? {
        guard let state = stateProvider?(), state.passesTouchesOutsidePanel else { return nil }
        return state
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Only for drags that start outside the panel, while recording, with a scroll target.
        guard scrollTarget != nil, recordingState() != nil else { return false }
        return !panelStrip.contains(gestureRecognizer.location(in: self))
    }

    private func clampedOffsetY(_ y: CGFloat, in sv: UIScrollView) -> CGFloat {
        let minY = -sv.adjustedContentInset.top
        let maxY = max(minY, sv.contentSize.height - sv.bounds.height + sv.adjustedContentInset.bottom)
        return min(max(y, minY), maxY)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let sv = scrollTarget else { return }
        switch gesture.state {
        case .began:
            sv.layer.removeAllAnimations()
            startOffsetY = sv.contentOffset.y
        case .changed:
            let y = clampedOffsetY(startOffsetY - gesture.translation(in: self).y, in: sv)
            sv.setContentOffset(CGPoint(x: sv.contentOffset.x, y: y), animated: false)
        case .ended:
            let target = clampedOffsetY(sv.contentOffset.y - gesture.velocity(in: self).y * 0.25, in: sv)
            UIView.animate(withDuration: 0.4, delay: 0, options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState]) {
                sv.contentOffset = CGPoint(x: sv.contentOffset.x, y: target)
            }
        default:
            break
        }
    }

    /// The bottom strip treated as "the panel" while recording. The recording controls sit
    /// at the bottom edge and are about 215-285pt tall (including the home-indicator area),
    /// so 300pt (capped at 40% of the screen) covers them; everything above it is the screen
    /// behind. (A measured SwiftUI frame was tried and never produced a value, so a fixed
    /// strip it is.)
    private var panelStrip: CGRect {
        let height = min(bounds.height * 0.40, 300)
        return CGRect(x: 0, y: bounds.height - height, width: bounds.width, height: height)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let state = stateProvider?() else { return nil }
        guard state.passesTouchesOutsidePanel else { return super.hitTest(point, with: event) }
        guard panelStrip.contains(point) else {
            // With a scroll target the wrapper keeps the touch (and scrolls on a drag);
            // without one it lets the touch through to the screen behind.
            return scrollTarget != nil ? self : nil
        }
        return super.hitTest(point, with: event)
    }
}

/// Debug logging for the speech autofill pipeline (section and row), gated behind the same
/// `CloudAPIConfiguration.isLoggingEnabled` flag ZTAIServices' own `[AUTOFILL_TIMING]`/
/// `[AUTOFILL_DEBUG]` logs already respect — quiet by default, not a separate on/off switch
/// to remember. `@autoclosure` so the (often string-interpolation-heavy) message isn't
/// built at all when logging is off.
func autofillLog(_ message: @autoclosure () -> String) {
    guard CloudAPIConfiguration.isLoggingEnabled else { return }
    // Every line of one session carries the same "[AUTOFILL s3]" tag, so a pasted log can be
    // split into sessions even when several are in it.
    let text = message()
    let tag = "[AUTOFILL]"
    if text.hasPrefix(tag), FPAutofillSession.id > 0 {
        ZTAutofillLogBuffer.log("[AUTOFILL s\(FPAutofillSession.id)]" + text.dropFirst(tag.count))
    } else {
        ZTAutofillLogBuffer.log(text)
    }
}

/// Lets a tester share the autofill debug log as text: a long-press on the autofill button opens
/// the iOS share sheet (Messages, Mail, Notes, AirDrop, Copy…). Only available while the debug
/// logging flag is on, so normal users never see it.
enum FPAutofillLogShare {
    static func attach(to button: UIView, target: Any, action: Selector) {
        guard button.gestureRecognizers?.contains(where: { $0 is UILongPressGestureRecognizer }) != true else { return }
        let press = UILongPressGestureRecognizer(target: target, action: action)
        press.minimumPressDuration = 1.0
        button.addGestureRecognizer(press)
    }

    /// Long-press entry. Always offers the log; debug builds also offer the autofill self-test.
    static func presentMenu(from controller: UIViewController, sourceView: UIView?, runSelfTest: (() -> Void)?, runAllSelfTest: (() -> Void)? = nil) {
        guard CloudAPIConfiguration.isLoggingEnabled else { return }
        #if DEBUG
        if let runSelfTest {
            let menu = UIAlertController(title: "Autofill debug", message: nil, preferredStyle: .actionSheet)
            menu.addAction(UIAlertAction(title: "Share log", style: .default) { _ in
                present(from: controller, sourceView: sourceView)
            })
            menu.addAction(UIAlertAction(title: "Run self-test", style: .default) { _ in runSelfTest() })
            if let runAllSelfTest {
                menu.addAction(UIAlertAction(title: "Run self-test (all sections)", style: .default) { _ in runAllSelfTest() })
            }
            menu.addAction(UIAlertAction(title: "Clear log", style: .destructive) { _ in ZTAutofillLogBuffer.clear() })
            menu.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            if let popover = menu.popoverPresentationController {
                popover.sourceView = sourceView ?? controller.view
                popover.sourceRect = (sourceView ?? controller.view).bounds
            }
            controller.present(menu, animated: true)
            return
        }
        #endif
        present(from: controller, sourceView: sourceView)
    }

    static func present(from controller: UIViewController, sourceView: UIView?) {
        guard CloudAPIConfiguration.isLoggingEnabled else { return }
        let text = ZTAutofillLogBuffer.isEmpty
            ? "No autofill log yet. Run an autofill, then long-press the button again."
            : ZTAutofillLogBuffer.exportText()
        // Shared as a named .txt file ("Autofill-fpform-<datetime>.txt"); plain text if writing fails.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("Autofill-fpform-\(formatter.string(from: Date())).txt")
        let item: Any = (try? text.write(to: fileURL, atomically: true, encoding: .utf8)) != nil ? fileURL : text
        let sheet = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = sourceView ?? controller.view
            popover.sourceRect = (sourceView ?? controller.view).bounds
        }
        (controller.presentedViewController ?? controller).present(sheet, animated: true)
    }
}

/// Numbers autofill sessions for the debug log (one per tap on the autofill button).
enum FPAutofillSession {
    static var id = 0

    static func begin(_ kind: String) {
        id += 1
        // Starts this session's slice of the shareable log (the last 5 are kept); from here until
        // the sheet closes, package-level lines (speech, timing, review) are kept too.
        ZTAutofillLogBuffer.beginSession()
        let form = FPFormDataHolder.shared.customForm
        let formName = [form?.displayName, form?.name].compactMap { $0 }.first { !$0.trim.isEmpty } ?? "unknown"
        autofillLog("[AUTOFILL] ===== session start: \(kind) | form=\"\(formName)\" | language=\(UserDefaults.libCurrentLanguage) =====")
    }
}

/// One line that answers "what happened to each field": which the model answered, which became
/// review rows, which were skipped, which were never mentioned, and any key the model made up.
func autofillLogSummary(prefix: String, fields: [(label: String, key: String)], answered: [String: Any], candidates: [ZTAutofillCandidate]) {
    guard CloudAPIConfiguration.isLoggingEnabled else { return }
    let filled = Set(candidates.map { $0.label })
    var answeredLabels: [String] = [], skipped: [String] = [], notMentioned: [String] = []
    for field in fields {
        if answered[field.key] != nil {
            answeredLabels.append(field.label)
            if !filled.contains(field.label) { skipped.append(field.label) }
        } else {
            notMentioned.append(field.label)
        }
    }
    let knownKeys = Set(fields.map { $0.key })
    let unknownKeys = answered.keys.filter { !knownKeys.contains($0) }.sorted()
    autofillLog("\(prefix) summary — eligible \(fields.count) | model answered \(answeredLabels.count) | review rows \(candidates.count) | skipped \(skipped) | not mentioned \(notMentioned) | keys the model returned that match no field \(unknownKeys)")
}

/// Guards a NUMERICAL-dataType INPUT field from being autofilled with a spoken answer
/// that isn't actually a number (e.g. uiType .INPUT + dataType .NUMERICAL but the user
/// said a free-form string) — shared by both section (FPFormViewController) and row/table
/// (FPEditRowViewController) autofill candidate mapping. Mirrors the character set
/// FPInputFieldCell's own numeric keyboard filter allows (digits + a single decimal
/// point), then confirms it actually parses.
enum FPFormAutofillNumericValidator {
    static func isValidNumericInput(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        let allowed = CharacterSet(charactersIn: "0123456789.")
        guard value.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }
        return Double(value) != nil
    }
}

/// One `<context>` line per field, shared by section and table-row autofill so both
/// give the model the same per-type answer-format hints.
enum FPFormAutofillContextLine {
    static func make(key: String, uiType: FPDynamicUITypes, dataType: FPDynamicDataTypes,
                     dateInstruction: String?, options: [FPFieldOption], description: String? = nil, label: String? = nil) -> String {
        let base = baseLine(key: key, uiType: uiType, dataType: dataType, dateInstruction: dateInstruction, options: options)
        guard let note = sanitizedNote(description, label: label ?? key) else { return base }
        return "\(base) — note: \(note)"
    }

    /// The template author's field description, when it adds something beyond the label
    /// (e.g. label "Dropdown 1" / description "Fire pump driver type"). One line, capped:
    /// descriptions are free text, so a long or multi-line one must not bloat the prompt
    /// of every field after it.
    private static func sanitizedNote(_ raw: String?, label: String) -> String? {
        guard let raw else { return nil }
        let oneLine = raw.components(separatedBy: .newlines).joined(separator: " ")
            .replacingOccurrences(of: "\"", with: "'")
            .trim
        guard !oneLine.isEmpty, oneLine.caseInsensitiveCompare(label) != .orderedSame else { return nil }
        return oneLine.count > 120 ? String(oneLine.prefix(120)) + "…" : oneLine
    }

    private static func baseLine(key: String, uiType: FPDynamicUITypes, dataType: FPDynamicDataTypes,
                                 dateInstruction: String?, options: [FPFieldOption]) -> String {
        if let dateInstruction { return "- \"\(key)\" (\(dateInstruction))" }
        // Mirrors FPFormAutofillNumericValidator: digits and one decimal point, no units —
        // otherwise "12 psi" is rejected after the fact instead of being asked for correctly.
        if uiType == .INPUT, dataType == .NUMERICAL {
            return "- \"\(key)\" (number, answer with digits and an optional decimal point only, no units or words)"
        }
        let optionLabels = options.compactMap { $0.label?.trim }.filter { !$0.isEmpty }
        guard !optionLabels.isEmpty else { return "- \"\(key)\"" }
        let list = optionLabels.joined(separator: ", ")
        if uiType == .CHECKBOX {
            return "- \"\(key)\" (options: \(list); one or more may be chosen — answer with everything the user said for this field, separated by commas)"
        }
        return "- \"\(key)\" (options: \(list))"
    }
}

/// Section fields (and table columns) can share a label, but the model answers in a flat
/// `fields` object keyed by label — a duplicate would silently overwrite the earlier
/// answer. First occurrence keeps its label; later ones become "Label (2)", "Label (3)".
enum FPFormAutofillPromptKeys {
    static func uniqueKeys(for rawLabels: [String]) -> [String] {
        // Labels are template text that goes into the prompt, so each is made safe first:
        // one line, no quotes (they delimit the label in the context), no tag brackets,
        // capped. The returned key is exactly what the prompt lists and what the answer is
        // looked up by, so the two always agree; the on-screen label is untouched.
        let labels = rawLabels.enumerated().map { index, raw -> String in
            let flat = raw.components(separatedBy: .newlines).joined(separator: " ")
                .replacingOccurrences(of: "\"", with: "'")
                .replacingOccurrences(of: "<", with: "(")
                .replacingOccurrences(of: ">", with: ")")
                .trim
            if flat.isEmpty { return "Field \(index + 1)" }
            return flat.count > 80 ? String(flat.prefix(80)) : flat
        }
        var used = Set(labels)
        var seen: [String: Int] = [:]
        var result: [String] = []
        result.reserveCapacity(labels.count)
        var firstSeen = Set<String>()
        for label in labels {
            if firstSeen.insert(label).inserted {
                result.append(label)
                continue
            }
            var n = (seen[label] ?? 1) + 1
            var candidate = "\(label) (\(n))"
            while used.contains(candidate) {
                n += 1
                candidate = "\(label) (\(n))"
            }
            seen[label] = n
            used.insert(candidate)
            result.append(candidate)
        }
        return result
    }
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
    /// Unique per-section key the model is asked to answer under; differs from `label`
    /// only when two fields share a label. Assigned by `eligibleFields(forSection:)`.
    var promptKey: String?

    var label: String {
        let displayName = field.displayName?.trim ?? ""
        return displayName.isEmpty ? (field.name ?? "") : displayName
    }

    var key: String { promptKey ?? label }

    /// For DATE/TIME/DATE_TIME/YEAR fields: the machine-readable format instruction added
    /// to this field's line in the extraction context (`FPFormAutofillDateParser` parses
    /// what comes back). nil for every other dataType.
    var dateFormatHint: String? {
        switch dataType {
        case .DATE: return "date, answer as YYYY-MM-DD"
        case .TIME: return "time, answer as HH:MM in 24-hour time"
        case .DATE_TIME: return "date and time, answer as YYYY-MM-DD HH:MM in 24-hour time"
        case .YEAR: return "year, answer as a 4-digit YYYY"
        default: return nil
        }
    }
}

/// Words handed to the speech recognizer so it prefers a form's own field and option names over
/// similar-sounding words. Pure and bounded; the recognizer side re-caps it as well.
enum FPFormAutofillSpeechVocabulary {
    static let maxTerms = 50

    static func terms(labels: [String], optionLabels: [[String]]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        // Field names first (they matter most), then option names, until the cap.
        for raw in labels + optionLabels.flatMap({ $0 }) {
            let term = raw.trim.trimmingCharacters(in: CharacterSet(charactersIn: ":#*"))
                .trimmingCharacters(in: .whitespaces)
            guard !term.isEmpty, term.count <= 40, seen.insert(term.lowercased()).inserted else { continue }
            result.append(term)
            if result.count == maxTerms { break }
        }
        return result
    }
}

enum FPFormAutofillContextBuilder {
    /// Field and option names for the speech recognizer (see `FPFormAutofillSpeechVocabulary`).
    static func speechVocabulary(for fields: [FPFormAutofillFieldContext]) -> [String] {
        FPFormAutofillSpeechVocabulary.terms(
            labels: fields.map { $0.label },
            optionLabels: fields.map { $0.options.compactMap { $0.label } }
        )
    }

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
        let keys = FPFormAutofillPromptKeys.uniqueKeys(for: result.map { $0.label })
        for index in result.indices { result[index].promptKey = keys[index] }
        return result
    }

    /// The `<context>` text handed to ZTAIServices' `.fpFormSection` extraction — one
    /// line per eligible field, its label, and (for choice fields) its allowed options.
    /// The extraction prompt (TextAIService.pageFieldFocus for `.dynamicForm`) describes
    /// this exact shape and instructs the model to key its `fields` output by these
    /// labels verbatim.
    static func supplementalContext(for fields: [FPFormAutofillFieldContext]) -> String {
        fields.map {
            FPFormAutofillContextLine.make(key: $0.key, uiType: $0.uiType, dataType: $0.dataType,
                                           dateInstruction: $0.dateFormatHint, options: $0.options,
                                           description: $0.field.fieldDescription, label: $0.label)
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
        formatter.locale = Locale(identifier: "en_US_POSIX")   // same as the form's own date cells
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
    static func rankedMatch(for rawAnswer: String, options: [FPFieldOption], hint: String? = nil, maxAlternatives: Int = 2) -> FPFormAutofillMatchResult? {
        let candidates = options.filter { ($0.label ?? "").trim.isEmpty == false }
        guard !candidates.isEmpty else { return nil }

        let normalizedAnswer = normalize(rawAnswer)
        guard !normalizedAnswer.isEmpty else { return nil }

        // Option labels are template data (often English) while the user dictates in the app
        // language, so each option is also compared by its localized label and its value —
        // "oui" can then match a "Yes" option. The ORIGINAL option is always what's returned.
        // `value` is exact-match only: it can be an internal id, too short/opaque to near-match.
        let forms: [(option: FPFieldOption, names: [String], value: String)] = candidates.map { option in
            var names = [normalize(option.label ?? "")]
            if let label = option.label {
                names.append(normalize(FPLocalizationHelper.localize(label)))
            }
            var seen = Set<String>()
            return (option, names.filter { !$0.isEmpty && seen.insert($0).inserted }, normalize(option.value ?? ""))
        }

        if let exact = forms.first(where: { $0.names.contains(normalizedAnswer) || $0.value == normalizedAnswer }) {
            return FPFormAutofillMatchResult(best: exact.option, isExact: true, alternatives: [])
        }

        // The model's optional `optionHints` answer: when the user spoke in a language the option
        // list isn't in (or a clear translation of one option), it names that option exactly.
        // Only an exact listed option is accepted, and it is never "exact" — review always
        // flags it, so it stays a reviewable suggestion, not a silent pick.
        let hinted: (option: FPFieldOption, names: [String], value: String)? = {
            guard let hint, case let normalizedHint = normalize(hint), !normalizedHint.isEmpty else { return nil }
            return forms.first(where: { $0.names.contains(normalizedHint) })
        }()

        var scored: [(option: FPFieldOption, score: Int)] = []
        for entry in forms {
            var bestScore: Int?
            for name in entry.names {
                var score: Int?
                if name.contains(normalizedAnswer) || normalizedAnswer.contains(name) {
                    score = abs(name.count - normalizedAnswer.count)
                } else {
                    let distance = levenshteinDistance(normalizedAnswer, name)
                    if distance <= max(2, name.count / 3) { score = distance }
                }
                if let score, score < (bestScore ?? Int.max) { bestScore = score }
            }
            if let bestScore { scored.append((entry.option, bestScore)) }
        }
        // Loosely heard option (e.g. "pre-semi-isolating assembly" for "Premises-Isolating
        // Assembly"): nothing above matched, but its distinctive words are in the answer.
        if scored.isEmpty {
            let answerTokens = Set(tokens(of: rawAnswer))
            let optionTokens = forms.map { tokens(of: $0.option.label ?? "") }
            for (index, entry) in forms.enumerated() {
                let score = tokenScore(optionTokens[index], answerTokens: answerTokens, allOptionTokens: optionTokens)
                if score >= 0.5 { scored.append((entry.option, Int((1 - score) * 50) + 3)) }
            }
        }
        scored.sort { $0.score < $1.score }

        if let hinted {
            let others = scored.map { $0.option }.filter { $0.key != hinted.option.key || $0.value != hinted.option.value }
            return FPFormAutofillMatchResult(best: hinted.option, isExact: false, alternatives: Array(others.prefix(maxAlternatives)))
        }
        guard !scored.isEmpty else { return nil }

        let best = scored[0].option
        let alternatives = scored.dropFirst().prefix(maxAlternatives).map { $0.option }
        return FPFormAutofillMatchResult(best: best, isExact: false, alternatives: Array(alternatives))
    }

    /// Options named by a comma-separated `optionHints` entry for a multi-select field —
    /// each fragment must be exactly a listed option (label or localized label).
    static func hintedOptions(for hint: String, options: [FPFieldOption]) -> [FPFieldOption] {
        hint.components(separatedBy: CharacterSet(charactersIn: ",;"))
            .compactMap { fragment -> FPFieldOption? in
                let normalizedFragment = normalize(fragment)
                guard !normalizedFragment.isEmpty else { return nil }
                return options.first { option in
                    guard let label = option.label else { return false }
                    return normalize(label) == normalizedFragment
                        || normalize(FPLocalizationHelper.localize(label)) == normalizedFragment
                }
            }
    }

    // MARK: - Multi-select

    /// Every option of a multi-select field that the spoken answer names. Speech has no
    /// commas ("domestic fire irrigation"), so splitting on punctuation alone finds one
    /// option; this also looks for each option's own words inside the whole answer, and
    /// scores partly-heard options by their distinctive words ("isolating assembly" for
    /// "Premises-Isolating Assembly"). `isExact` is true only when every option was named in
    /// full — anything looser is flagged for review.
    static func multiMatch(for rawAnswer: String, options: [FPFieldOption]) -> (options: [FPFieldOption], isExact: Bool) {
        let candidates = options.filter { ($0.label ?? "").trim.isEmpty == false }
        guard !candidates.isEmpty else { return ([], true) }
        let answerTokens = Set(tokens(of: rawAnswer))

        var picked: [Int: Bool] = [:]   // option index -> named in full?
        func mark(_ index: Int, exact: Bool) { picked[index] = (picked[index] ?? true) && exact }

        // 0. A label that itself contains a separator (",", ";" or "/") would be cut apart by the
        //    split below, so look for it whole in the answer.
        let quoteEdges = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'“”‘’"))
        for (index, option) in candidates.enumerated() {
            guard let label = option.label?.trimmingCharacters(in: quoteEdges),
                  label.count >= 3, label.rangeOfCharacter(from: CharacterSet(charactersIn: ",;/")) != nil,
                  rawAnswer.range(of: label, options: .caseInsensitive) != nil else { continue }
            mark(index, exact: true)
        }
        guard !answerTokens.isEmpty || !picked.isEmpty else { return ([], true) }

        // 1. Each comma/and-separated fragment through the single-answer matcher.
        let fragments = rawAnswer
            .replacingOccurrences(of: " and ", with: ",", options: .caseInsensitive)
            .replacingOccurrences(of: " & ", with: ",")
            .components(separatedBy: CharacterSet(charactersIn: ",;/\n"))
            .map { $0.trim }
            .filter { !$0.isEmpty }
        for fragment in fragments {
            if let result = rankedMatch(for: fragment, options: candidates),
               let index = candidates.firstIndex(where: { $0.key == result.best.key && $0.value == result.best.value }) {
                mark(index, exact: result.isExact)
            }
        }

        // 2. Each option's own words, searched for in the whole answer.
        let optionTokens = candidates.map { tokens(of: $0.label ?? "") }
        let fullyNamed = optionTokens.enumerated().filter { _, labelTokens in
            !labelTokens.isEmpty && labelTokens.allSatisfy { answerTokens.contains($0) }
        }.map { $0.offset }
        for (index, labelTokens) in optionTokens.enumerated() where !labelTokens.isEmpty {
            if fullyNamed.contains(index) {
                // "Fire" is inside "Fire Pump": when the longer option is also fully named,
                // the shorter one was only a piece of it, not a separate answer.
                let isPartOfLonger = fullyNamed.contains { other in
                    other != index && Set(labelTokens).isStrictSubset(of: Set(optionTokens[other]))
                }
                if !isPartOfLonger { mark(index, exact: true) }
            } else if tokenScore(labelTokens, answerTokens: answerTokens, allOptionTokens: optionTokens) >= 0.5 {
                mark(index, exact: false)
            }
        }

        let ordered = picked.keys.sorted()
        return (ordered.map { candidates[$0] }, ordered.allSatisfy { picked[$0] == true })
    }

    /// 0...1: how much of an option's distinctive wording the answer contains. Words shared
    /// by many options ("assembly" in "Zone Assembly", "Fixture Assembly", …) count for
    /// little, so a generic word alone can't pick an option.
    private static func tokenScore(_ labelTokens: [String], answerTokens: Set<String>, allOptionTokens: [[String]]) -> Double {
        var total = 0.0, matched = 0.0
        for token in labelTokens {
            let sharedBy = Double(allOptionTokens.filter { $0.contains(token) }.count)
            let weight = 1.0 / max(sharedBy, 1.0)
            total += weight
            if answerTokens.contains(token) { matched += weight }
        }
        return total > 0 ? matched / total : 0
    }

    /// Lowercased, accent-folded words, with hyphens and punctuation treated as spaces and
    /// filler words dropped.
    private static func tokens(of text: String) -> [String] {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
        let cleaned = String(folded.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " })
        let filler: Set<String> = ["and", "the", "of", "a", "an", "to", "or", "for"]
        return cleaned.split(separator: " ").map(String.init).filter { $0.count >= 2 && !filler.contains($0) }
    }

    /// Case-, accent- and punctuation-insensitive ("Oui." / "oui", "Électrique" / "electrique"),
    /// since speech recognition output rarely matches a label's exact diacritics or punctuation.
    private static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
        // Punctuation becomes a space ("Premises-Isolating" == "premises isolating"); "/" stays
        // so "N/A" is still one token.
        let spaced = String(folded.unicodeScalars.map { scalar -> Character in
            CharacterSet.punctuationCharacters.contains(scalar) && scalar != "/" ? " " : Character(scalar)
        })
        return spaced.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
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
