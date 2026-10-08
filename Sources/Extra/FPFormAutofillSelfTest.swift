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
import Combine
import ZTAIServices

struct FPAutofillSelfTestField {
    let id: String            // candidate id: templateId (section) or column key (row)
    let label: String
    let kind: String          // for the log only
    let sentence: String
    let expected: String      // what the review row should show
    let check: (ZTAutofillCandidate) -> Bool
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
                           ands: ["y", "más", "y también"])
        }
        if code.hasPrefix("fr") {
            return Phrases(connectors: ["est", "égal à", "était", "est à", ""],
                           choiceConnectors: ["sélectionne", "choisis", "est", "mets", "coche"],
                           multiConnectors: ["sélectionne", "coche", "choisis", "active"], sample: "Texte d'essai",
                           dates: ["le onze juin deux mille vingt-six", "le 11 juin 2026", "11 juin 2026"],
                           times: ["trois heures et quart de l'après-midi", "15 h 15", "quinze heures quinze"],
                           dateTimeJoiners: [" à ", " vers ", ", "], years: ["deux mille vingt-six", "2026"],
                           ands: ["et", "plus", "ainsi que"])
        }
        return Phrases(connectors: ["is", "equals", "set to", "was", ""],
                       choiceConnectors: ["select", "choose", "is", "pick", "set to"],
                       multiConnectors: ["select", "tick", "choose", "check"], sample: "Sample Text",
                       dates: ["June eleventh twenty twenty six", "the eleventh of June twenty twenty six", "June 11th 2026"],
                       times: ["quarter past three in the afternoon", "3:15 PM", "three fifteen p.m."],
                       dateTimeJoiners: [" at ", " around ", ", "], years: ["twenty twenty six", "2026"],
                       ands: ["and", "plus", "as well as"])
    }

    // MARK: Building the cases

    static func fields(forSection contexts: [FPFormAutofillFieldContext]) -> [FPAutofillSelfTestField] {
        var result: [FPAutofillSelfTestField] = []
        for (index, ctx) in contexts.enumerated() {
            guard let id = ctx.field.templateId,
                  let field = make(id: id, label: ctx.label, uiType: ctx.uiType, dataType: ctx.dataType, options: ctx.options, index: index) else { continue }
            result.append(field)
        }
        return result
    }

    static func fields(forColumns contexts: [FPTableAutofillFieldContext]) -> [FPAutofillSelfTestField] {
        var result: [FPAutofillSelfTestField] = []
        for (index, ctx) in contexts.enumerated() {
            guard let field = make(id: ctx.column.key, label: ctx.label, uiType: ctx.uiType, dataType: ctx.dataType, options: ctx.options, index: index) else { continue }
            result.append(field)
        }
        return result
    }

    private static func spoken(_ label: String) -> String {
        label.trimmingCharacters(in: CharacterSet(charactersIn: ":#* ")).trim
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
            [name, pick(connectors ?? words.connectors), value].filter { !$0.isEmpty }.joined(separator: " ")
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

    // MARK: Running

    /// Runs every case in batches and returns a summary. `perform` must open the autofill sheet
    /// and hand it the sentence as if it had been dictated.
    @MainActor
    static func run(title: String, fields: [FPAutofillSelfTestField], coordinator: ZTFormAutofillCoordinator,
                    perform: @escaping (String) -> Void) async -> String {
        var passed = 0
        var failures: [String] = []
        let batches = stride(from: 0, to: fields.count, by: batchSize).map { Array(fields[$0..<min($0 + batchSize, fields.count)]) }
        autofillLog("[AUTOFILL] SELFTEST start: \(title) — \(fields.count) case(s) in \(batches.count) batch(es)")

        for (number, batch) in batches.enumerated() {
            let sentence = batch.map { $0.sentence }.joined(separator: ". ") + "."
            autofillLog("[AUTOFILL] SELFTEST batch \(number + 1)/\(batches.count) says: \"\(sentence)\"")
            perform(sentence)
            let failure = await waitForReviewOrError(coordinator, timeout: 90)

            for field in batch {
                let line: String
                if let failure {
                    line = "FAIL \(field.label) (\(field.kind)) — \(failure)"
                    failures.append(line)
                } else if let candidate = coordinator.candidates.first(where: { $0.id == field.id }) {
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
#endif
