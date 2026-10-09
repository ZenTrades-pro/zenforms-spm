#if DEBUG
//
//  FPFormAutofillSelfTest.swift
//  ZenForms
//
//  Debug-only self-test for form-section and table-row autofill. For each eligible field it
//  writes a sentence from the field's own label and a made-up value of the right type, sends
//  those sentences through the real pipeline (the same path a dictated transcript takes, minus
//  the speech recognizer), and checks that the review sheet would show the expected value.
//  One line per field goes to the autofill debug log (PASS / FAIL), plus a summary.
//
//  It never fills the form: every batch is dismissed instead of applied.
//

import Foundation
import UIKit
import Combine
import ZTAIServices

struct FPAutofillSelfTestField {
    let id: String            // candidate id: templateId (section) or column key (row)
    let label: String
    let kind: String          // for the log only
    let sentence: String
    let expected: String      // what the review row should show
    let check: (ZTAutofillCandidate) -> Bool
    /// True when the right outcome is that the field is left alone (no review row), e.g. words
    /// dictated into a number field.
    var expectsNoRow = false
}

enum FPAutofillSelfTest {
    static let batchSize = 6

    // MARK: Spoken phrases per app language

    /// Several ways to say each part, per app language. Field number N uses variant N (cycling),
    /// so one run covers "is", "equals", "set to", or no connector at all, and a few ways of
    /// saying dates, times and lists.
    private struct Phrases {
        let connectors: [String]   // "<field> <connector> <value>"; "" = just "<field> <value>"
        let choiceConnectors: [String]   // dropdown / radio: "<field> select <option>"
        let multiConnectors: [String]    // multi-select: "<field> tick <option> and <option>"
        let sample: String
        let dates: [String]
        let times: [String]
        let dateTimeJoiners: [String]
        let years: [String]
        let ands: [String]
        let notANumber: String     // dictated into a number field: must be ignored
    }

    private static var phrases: Phrases {
        let code = UserDefaults.libCurrentLanguage.lowercased()
        if code.hasPrefix("es") {
            return Phrases(connectors: ["es", "igual a", "fue", "está en", ""],
                           choiceConnectors: ["selecciona", "elige", "es", "pon", "marca"],
                           multiConnectors: ["selecciona", "marca", "elige", "activa"], sample: "Texto de prueba",
                           dates: ["once de junio de dos mil veintiséis", "el 11 de junio de 2026", "junio 11 de 2026"],
                           times: ["las tres y cuarto de la tarde", "las 3:15 de la tarde", "a las 15:15"],
                           dateTimeJoiners: [" a ", " a las ", ", "], years: ["dos mil veintiséis", "2026"],
                           ands: ["y", "más", "y también"], notANumber: "por determinar")
        }
        if code.hasPrefix("fr") {
            return Phrases(connectors: ["est", "égal à", "était", "est à", ""],
                           choiceConnectors: ["sélectionne", "choisis", "est", "mets", "coche"],
                           multiConnectors: ["sélectionne", "coche", "choisis", "active"], sample: "Texte d'essai",
                           dates: ["le onze juin deux mille vingt-six", "le 11 juin 2026", "11 juin 2026"],
                           times: ["trois heures et quart de l'après-midi", "15 h 15", "quinze heures quinze"],
                           dateTimeJoiners: [" à ", " vers ", ", "], years: ["deux mille vingt-six", "2026"],
                           ands: ["et", "plus", "ainsi que"], notANumber: "à déterminer")
        }
        return Phrases(connectors: ["is", "equals", "set to", "was", ""],
                       choiceConnectors: ["select", "choose", "is", "pick", "set to"],
                       multiConnectors: ["select", "tick", "choose", "check"], sample: "Sample Text",
                       dates: ["June eleventh twenty twenty six", "the eleventh of June twenty twenty six", "June 11th 2026"],
                       times: ["quarter past three in the afternoon", "3:15 PM", "three fifteen PM"],
                       dateTimeJoiners: [" at ", " around ", ", "], years: ["twenty twenty six", "2026"],
                       ands: ["and", "plus", "as well as"], notANumber: "to be determined")
    }

    // MARK: Building the cases

    static func fields(forSection contexts: [FPFormAutofillFieldContext]) -> [FPAutofillSelfTestField] {
        var result: [FPAutofillSelfTestField] = []
        let testable = speakable(contexts.map { $0.label })
        for (index, ctx) in contexts.enumerated() where testable[index] {
            guard let id = ctx.field.templateId,
                  let field = make(id: id, label: ctx.label, uiType: ctx.uiType, dataType: ctx.dataType, options: ctx.options, index: index) else { continue }
            result.append(field)
        }
        // Words dictated into a number field must be ignored, not written.
        for (index, ctx) in contexts.enumerated() where testable[index] && ctx.uiType == .INPUT && ctx.dataType == .NUMERICAL {
            if let id = ctx.field.templateId { result.append(notANumberCase(id: id, label: ctx.label, index: index)) }
        }
        return result
    }

    static func fields(forColumns contexts: [FPTableAutofillFieldContext]) -> [FPAutofillSelfTestField] {
        var result: [FPAutofillSelfTestField] = []
        let testable = speakable(contexts.map { $0.label })
        for (index, ctx) in contexts.enumerated() where testable[index] {
            guard let field = make(id: ctx.column.key, label: ctx.label, uiType: ctx.uiType, dataType: ctx.dataType, options: ctx.options, index: index) else { continue }
            result.append(field)
        }
        for (index, ctx) in contexts.enumerated() where testable[index] && ctx.uiType == .INPUT && ctx.dataType == .NUMERICAL {
            result.append(notANumberCase(id: ctx.column.key, label: ctx.label, index: index))
        }
        return result
    }

    private static func notANumberCase(id: String, label: String, index: Int) -> FPAutofillSelfTestField {
        let words = phrases
        let sentence = [spoken(label), words.connectors[index % words.connectors.count], words.notANumber].filter { !$0.isEmpty }.joined(separator: " ")
        return FPAutofillSelfTestField(id: id, label: label, kind: "number, words ignored", sentence: sentence,
                                       expected: "(left empty)", check: { _ in false }, expectsNoRow: true)
    }

    /// A person can't dictate a field that has no real name or that shares its name with an
    /// earlier field of the same section ("Amps" twice) — speech can't tell them apart — so
    /// those are left out of the test instead of being reported as failures.
    private static func speakable(_ labels: [String]) -> [Bool] {
        var seen = Set<String>()
        return labels.map { label in
            let name = spoken(label).lowercased()
            if name.isEmpty || name.hasPrefix("field_") { return false }
            // A label that is itself several sentences ("Lorem ipsum ... industry. Lorem ...") can't be
            // dictated in a way that tells where the label stops and the answer starts.
            // (Numbering such as "A. Power on" is fine: the period has to come well into the label.)
            if let stop = name.range(of: ". "), name.distance(from: name.startIndex, to: stop.lowerBound) > 20 { return false }
            // Same-named fields are judged on the whole label; a long label is spoken shortened, which
            // would make different long labels look alike.
            let whole = label.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ").lowercased()
            return seen.insert(whole).inserted
        }
    }

    private static func spoken(_ label: String) -> String {
        // "System #" is said "System number"; the "#" itself can't be dictated.
        clippedLabel(label).replacingOccurrences(of: "#", with: " number")
            .trimmingCharacters(in: CharacterSet(charactersIn: ":*.?! ")).trim
            .components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// The label as one line (tabs and runs of spaces as a single space), no more than the 80 characters
    /// the prompt key keeps, cut at a word boundary so no half word is dictated. (Shortening harder than
    /// that makes different long labels start the same way, and then no one can tell them apart.)
    private static func clippedLabel(_ label: String) -> String {
        let flat = label.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        guard flat.count > 80 else { return flat }
        let cut = String(flat.prefix(80))
        let endsOnWord = flat[flat.index(flat.startIndex, offsetBy: 80)] == " "
        if !endsOnWord, let lastSpace = cut.lastIndex(of: " ") { return String(cut[..<lastSpace]) }
        return cut
    }

    /// A label written with a closing "." / "?" / "!" / ":" is spoken with a pause (a comma) before
    /// the connector, so "lock functional, pick No" reads as a label and an answer, not as one phrase.
    private static func pauseAfter(_ label: String) -> String {
        guard let last = clippedLabel(label).last else { return "" }
        return ".?!:".contains(last) ? "," : ""
    }

    private static func norm(_ text: String) -> String {
        text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date? {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d; comps.hour = h; comps.minute = min
        return Calendar.current.date(from: comps)
    }

    private static func make(id: String, label: String, uiType: FPDynamicUITypes, dataType: FPDynamicDataTypes,
                             options: [FPFieldOption], index: Int) -> FPAutofillSelfTestField? {
        let name = spoken(label)
        guard !name.isEmpty else { return nil }

        func shown(_ c: ZTAutofillCandidate) -> String { c.displayValue ?? c.value }
        let words = phrases
        func pick(_ list: [String]) -> String { list[index % list.count] }
        func say(_ value: String, connectors: [String]? = nil) -> String {
            [name + pauseAfter(label), pick(connectors ?? words.connectors), value].filter { !$0.isEmpty }.joined(separator: " ")
        }

        switch uiType {
        case .INPUT, .TEXTAREA:
            switch dataType {
            case .NUMERICAL:
                return FPAutofillSelfTestField(id: id, label: label, kind: "number", sentence: say("42"),
                                               expected: "42", check: { norm(shown($0)) == "42" })
            case .DATE, .TIME, .DATE_TIME, .YEAR:
                let when: Date?
                let spokenWhen: String
                switch dataType {
                case .DATE: when = date(2026, 6, 11, 0, 0); spokenWhen = pick(words.dates)
                case .TIME: when = date(2026, 6, 11, 15, 15); spokenWhen = pick(words.times)
                case .DATE_TIME: when = date(2026, 6, 11, 15, 15); spokenWhen = pick(words.dates) + pick(words.dateTimeJoiners) + pick(words.times)
                default: when = date(2026, 1, 1, 0, 0); spokenWhen = pick(words.years)
                }
                guard let when, let expected = FPFormAutofillDateParser.displayString(for: when, dataType: dataType) else { return nil }
                return FPAutofillSelfTestField(id: id, label: label, kind: "\(dataType)", sentence: say(spokenWhen),
                                               expected: expected, check: { norm(shown($0)) == norm(expected) })
            default:
                // Labels that ask for an edition / version / year get a believable value; the
                // model may (reasonably) refuse to put "Sample Text 15" into an edition field.
                let lowered = label.lowercased()
                let looksLikeEdition = lowered.contains("edition") || lowered.contains("version") || lowered.contains("édition") || lowered.contains("edición")
                let value = looksLikeEdition ? "2015" : "\(words.sample) \(index + 1)"
                return FPAutofillSelfTestField(id: id, label: label, kind: "text", sentence: say(value),
                                               expected: value, check: { norm(shown($0)) == norm(value) })
            }

        case .DROPDOWN, .RADIO, .BUTTON_RADIO:
            let usable = options.filter { ($0.label ?? "").trim.isEmpty == false }
            // The second option (the first when there is only one).
            guard let option = usable.count > 1 ? usable[1] : usable.first, let optionLabel = option.label?.trim else { return nil }
            return FPAutofillSelfTestField(id: id, label: label, kind: "choice", sentence: say(optionLabel, connectors: words.choiceConnectors),
                                           expected: optionLabel,
                                           check: { $0.value == option.value || norm(shown($0)) == norm(optionLabel) })

        case .CHECKBOX:
            let all = options.compactMap { $0.label?.trim }.filter { !$0.isEmpty }
            // The middle and the last option (just the one when there is only one).
            let labels: [String] = all.count > 2 ? [all[all.count / 2], all[all.count - 1]] : all
            guard !labels.isEmpty else { return nil }
            let spokenOptions = labels.joined(separator: " \(pick(words.ands)) ")
            // Labels can contain commas themselves, so look for each label inside the shown
            // value instead of splitting the value on commas.
            return FPAutofillSelfTestField(id: id, label: label, kind: "multi-select", sentence: say(spokenOptions, connectors: words.multiConnectors),
                                           expected: labels.joined(separator: ", "),
                                           check: { candidate in
                                               let text = norm(shown(candidate))
                                               return labels.allSatisfy { text.contains(norm($0)) }
                                           })

        default:
            return nil
        }
    }

    /// Appends to `Documents/autofill-selftest-all.txt` so a long multi-form run can be read afterwards.
    static func appendReport(_ text: String) {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let url = dir.appendingPathComponent("autofill-selftest-all.txt")
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(text.utf8))
            try? handle.close()
        } else {
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// The most recent autofill session from the shared debug log (the section just tested), without the
    /// timing / provider chatter, so a failing section's raw model output can be reviewed from the report.
    static func latestSessionLog(maxCharacters: Int = 150_000) -> String {
        let all = ZTAutofillLogBuffer.exportText()
        let blocks = all.components(separatedBy: "===== session start")
        guard blocks.count > 1, let last = blocks.last else { return "(no session log)" }
        let noise = ["[AUTOFILL_TIMING]", "[TEXT_AI]", "extraction request:", "[AUTOFILL_DEBUG] step ", "[AUTOFILL_DEBUG] provider="]
        // The "not mentioned [...]" summaries list every field of the section on every batch, which
        // would crowd out the batches that matter; cut any line to a readable length.
        let kept = last.components(separatedBy: "\n")
            .filter { line in !noise.contains(where: { line.contains($0) }) }
            .map { $0.count > 400 ? String($0.prefix(400)) + " …" : $0 }
        var text = "===== session start" + kept.joined(separator: "\n")
        if text.count > maxCharacters { text = String(text.prefix(maxCharacters)) + "\n...(truncated)" }
        return text
    }

    // MARK: Running

    /// Runs every case in batches and returns a summary. `perform` must open the autofill sheet
    /// and hand it the sentence as if it had been dictated.
    @MainActor
    static func run(title: String, fields: [FPAutofillSelfTestField], coordinator: ZTFormAutofillCoordinator,
                    perform: @escaping (String) -> Void) async -> String {
        var passed = 0
        var failures: [String] = []
        // Batches of up to batchSize, never with the same field twice (its two sentences would collide).
        var batches: [[FPAutofillSelfTestField]] = []
        for field in fields {
            if var last = batches.last, last.count < batchSize, !last.contains(where: { $0.id == field.id }) {
                last.append(field)
                batches[batches.count - 1] = last
            } else {
                batches.append([field])
            }
        }
        autofillLog("[AUTOFILL] SELFTEST start: \(title) — \(fields.count) case(s) in \(batches.count) batch(es)")

        for (number, batch) in batches.enumerated() {
            let sentence = batch.map { $0.sentence }.joined(separator: ". ") + "."
            autofillLog("[AUTOFILL] SELFTEST batch \(number + 1)/\(batches.count) says: \"\(sentence)\"")
            perform(sentence)
            let failure = await waitForReviewOrError(coordinator, timeout: 90)

            for field in batch {
                let line: String
                let row = coordinator.candidates.first(where: { $0.id == field.id })
                if field.expectsNoRow {
                    // Passing = the field was left alone; "No details could be extracted" is the
                    // same outcome when the whole batch was words for number fields.
                    if let row {
                        line = "FAIL \(field.label) (\(field.kind)) should have been ignored, but got \"\(row.displayValue ?? row.value)\""
                        failures.append(line)
                    } else if failure == nil || failure?.contains("No details") == true {
                        passed += 1
                        line = "PASS \(field.label) (\(field.kind)) said \"\(field.sentence)\" -> left empty"
                    } else {
                        line = "FAIL \(field.label) (\(field.kind)) — \(failure ?? "")"
                        failures.append(line)
                    }
                } else if let failure {
                    line = "FAIL \(field.label) (\(field.kind)) — \(failure)"
                    failures.append(line)
                } else if let candidate = row {
                    let got = candidate.displayValue ?? candidate.value
                    if field.check(candidate) {
                        passed += 1
                        line = "PASS \(field.label) (\(field.kind)) said \"\(field.sentence)\" -> \"\(got)\""
                    } else {
                        line = "FAIL \(field.label) (\(field.kind)) expected \"\(field.expected)\", got \"\(got)\""
                        failures.append(line)
                    }
                } else {
                    line = "FAIL \(field.label) (\(field.kind)) expected \"\(field.expected)\", but no review row was produced"
                    failures.append(line)
                }
                autofillLog("[AUTOFILL] SELFTEST \(line)")
            }
            coordinator.dismiss()          // never apply: the form must stay untouched
            try? await Task.sleep(nanoseconds: 800_000_000)
        }

        var summary = "\(passed) of \(fields.count) passed"
        if !failures.isEmpty { summary += "\n" + failures.joined(separator: "\n") }
        // The sheet closing ended the log session; reopen it just for the summary.
        ZTAutofillLogBuffer.sessionActive = true
        autofillLog("[AUTOFILL] SELFTEST done: \(summary)")
        ZTAutofillLogBuffer.sessionActive = false
        return summary
    }

    /// nil = reached review; otherwise the reason it did not.
    @MainActor
    private static func waitForReviewOrError(_ coordinator: ZTFormAutofillCoordinator, timeout: TimeInterval) async -> String? {
        await withCheckedContinuation { continuation in
            var cancellable: AnyCancellable?
            var finished = false
            func finish(_ result: String?) {
                guard !finished else { return }
                finished = true
                cancellable?.cancel()
                continuation.resume(returning: result)
            }
            cancellable = coordinator.$step.receive(on: DispatchQueue.main).sink { step in
                switch step {
                case .review: finish(nil)
                case .error(let message): finish("error: \(message)")
                default: break
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { finish("timed out waiting for review") }
        }
    }
}

// MARK: - Debug: template sweep (real open / close flow)
//
// Runs the autofill self-test on every form template through the REAL open / close flow. For each
// template it asks the host screen to open a new form (the same call the template picker makes),
// waits for the form to appear, runs the all-sections self-test, closes the form without saving (the
// same steps as "Yes" on the cancel alert), waits until it is gone, and moves on. After each template
// it compares the ticket's local forms with a baseline and notes any form left behind (it never
// deletes anything). Progress is appended to Documents/autofill-selftest-all.txt.

/// Implemented by the host screen that presents forms (it must be the form's `delegate`).
public protocol ZenFormsAutofillSweepHost: AnyObject {
    /// Open `template` as a new form, exactly as picking it in the template picker does.
    func zenFormsSweepOpen(template: FPForms)
}

enum FPAutofillSweep {
    static var isRunning = false

    @MainActor
    static func topFormViewController() -> FPFormViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var vc: UIViewController? = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
        var found: FPFormViewController?
        while let current = vc {
            if let form = current as? FPFormViewController { found = form }
            if let nav = current as? UINavigationController, let form = nav.topViewController as? FPFormViewController { found = form }
            vc = current.presentedViewController
        }
        return found
    }

    @MainActor
    private static func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) async -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        return condition()
    }

    private static func localTemplates() async -> [FPForms] {
        await withCheckedContinuation { continuation in
            FPFormsDatabaseManager().fetchFPFormTemplatesFromLocal { forms in
                let sorted = (forms ?? []).sorted { ($0.displayName ?? $0.name ?? "") < ($1.displayName ?? $1.name ?? "") }
                continuation.resume(returning: sorted)
            }
        }
    }

    private static func localFormNames(ticketId: NSNumber) async -> [String] {
        await withCheckedContinuation { continuation in
            FPFormsDatabaseManager().fetchFormsFromLocal(ticketId: ticketId, moduleId: FPFormMduleId) { forms in
                continuation.resume(returning: (forms ?? []).map { $0.displayName ?? $0.name ?? "?" })
            }
        }
    }

    /// Entry point: called from the open form's debug menu.
    @MainActor
    static func start(from first: FPFormViewController) {
        guard !isRunning else { return }
        guard let host = first.delegate as? ZenFormsAutofillSweepHost else {
            _ = FPUtility.showAlertController(title: "Autofill self-test", message: "This screen can't open forms for the sweep (host not set up).", parentVC: first, completion: nil)
            return
        }
        guard FPUtility.isConnectedToNetwork() else {
            _ = FPUtility.showAlertController(title: "Autofill self-test", message: "No internet connection.", parentVC: first, completion: nil)
            return
        }
        isRunning = true
        let ticketId = first.ticketId ?? 0
        Task { @MainActor in
            defer { isRunning = false }
            var templates = await localTemplates()
            // Optional: Documents/autofill-sweep-only.txt lists template names (one per line) to run; all others are skipped.
            if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
               let text = try? String(contentsOf: dir.appendingPathComponent("autofill-sweep-only.txt"), encoding: .utf8) {
                let only = Set(text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
                if !only.isEmpty {
                    // A name listed once runs once, even when the account holds several same-named copies.
                    var taken = Set<String>()
                    templates = templates.filter {
                        let name = ($0.displayName ?? $0.name ?? "").trimmingCharacters(in: .whitespaces)
                        return only.contains(name) && taken.insert(name).inserted
                    }
                }
            }
            guard !templates.isEmpty else {
                _ = FPUtility.showAlertController(title: "Autofill self-test", message: "No templates on this device.", parentVC: first, completion: nil)
                return
            }
            FPAutofillSelfTest.appendReport("##### TEMPLATE SWEEP (real open/close) | language=\(UserDefaults.libCurrentLanguage) | \(templates.count) template(s) #####\n\n")

            // Close the form the user opened (same steps as "Yes" on the cancel alert).
            await first.sweepDiscard()
            _ = await waitUntil(timeout: 20) { topFormViewController() == nil }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            var baseline = await localFormNames(ticketId: ticketId).count

            var grandPassed = 0, grandTotal = 0
            var notes: [String] = []
            for (number, template) in templates.enumerated() {
                let name = template.displayName ?? template.name ?? "template \(number + 1)"
                host.zenFormsSweepOpen(template: template)
                let appeared = await waitUntil(timeout: 30) { topFormViewController()?.isViewLoaded == true && topFormViewController()?.view.window != nil }
                guard appeared, let form = topFormViewController() else {
                    notes.append("\(name): form did not open")
                    FPAutofillSelfTest.appendReport("=== [\(number + 1)/\(templates.count)] \(name) ===\nFAILED TO OPEN\n\n")
                    continue
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)   // let the form finish loading
                let result = await form.sweepTestAndDiscard(heading: "[\(number + 1)/\(templates.count)] \(name)")
                grandPassed += result.passed
                grandTotal += result.total
                if result.passed != result.total { notes.append("\(name) (\(result.passed)/\(result.total))") }
                _ = await waitUntil(timeout: 20) { topFormViewController() == nil }
                try? await Task.sleep(nanoseconds: 2_500_000_000)   // give auto-sync a moment to show up
                let now = await localFormNames(ticketId: ticketId).count
                if now > baseline {
                    notes.append("\(name): LEFT A FORM BEHIND on the ticket")
                    FPAutofillSelfTest.appendReport("!! \(name) left a form behind (ticket forms \(baseline) -> \(now))\n\n")
                    baseline = now
                }
            }
            var summary = "\(grandPassed) of \(grandTotal) passed across \(templates.count) templates"
            if !notes.isEmpty { summary += "\nNotes: " + notes.joined(separator: "; ") }
            FPAutofillSelfTest.appendReport("##### DONE: \(summary) #####\n\n")
            let alert = UIAlertController(title: "Autofill self-test (all templates)", message: summary, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            var top = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
            while let presented = top?.presentedViewController { top = presented }
            top?.present(alert, animated: true)
        }
    }
}
#endif
