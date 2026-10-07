//
//  FPTableAutofill.swift
//  ZenForms
//
//  Speech-only AI autofill for a single table ROW (FPEditRowViewController, both plain
//  edit and bulk-edit mode) — the row-level counterpart to FPFormAutofill.swift's
//  section-level autofill. Table columns (`ColumnData`) are a simpler sibling of
//  `FPFieldDetails` (same uiType/dataType concept, no templateId — joined by `key`
//  instead), so this file adapts the same eligibility/context shape to that type rather
//  than sharing FPFormAutofillFieldEligibility/FPFormAutofillContextBuilder directly.
//  FPFormAutofillMatcher and FPFormAutofillDateParser are reused as-is — both already
//  operate on the type-agnostic `FPFieldOption`/`FPDynamicDataTypes`, and table cell
//  dates are confirmed to use the exact same FPUtility.getStringWithTZFormat storage
//  format as section fields (FPDynamicTableViewModel.swift's own date-sort code calls
//  the same FPUtility.getOPDateFrom parser on column values).
//

import Foundation

enum FPTableAutofillFieldEligibility {
    /// Same excluded uiType set as FPFormAutofillFieldEligibility, plus:
    /// - readonly columns: not user-editable at all.
    /// - isPartOfFormula columns: computed from other cells, same reasoning as
    ///   AUTO_POPULATE for section fields.
    static func isEligible(_ column: ColumnData) -> Bool {
        guard column.readonly != true, column.isPartOfFormula != true else { return false }
        switch column.getUIType() {
        case .INPUT, .TEXTAREA, .DROPDOWN, .RADIO, .CHECKBOX, .BUTTON_RADIO:
            return true
        case .CHART, .SIGNATURE_PAD, .AUTO_POPULATE, .LABEL, .HIDDEN, .SCANNER,
             .FILE, .TABLE_SUMMARY, .TABLE_RESTRICTED, .TABLE:
            return false
        }
    }
}

struct FPTableAutofillFieldContext {
    let column: ColumnData
    let uiType: FPDynamicUITypes
    /// Populated for DROPDOWN/RADIO/CHECKBOX/BUTTON_RADIO only; empty otherwise.
    let options: [FPFieldOption]
    /// See `FPFormAutofillFieldContext.promptKey`.
    var promptKey: String?

    var key: String { promptKey ?? label }

    /// ColumnData carries no separate display name (see FPDynamicTableViewModel.swift —
    /// it's built from `Columns.name`, never `Columns.displayName`), so `key` doubles as
    /// both the match/write key and the label shown to the user and sent to the model.
    var label: String { column.key }

    var dateFormatHint: String? {
        switch column.dataType {
        case "DATE": return "date, answer as YYYY-MM-DD"
        case "TIME": return "time, answer as HH:MM in 24-hour time"
        case "DATE_TIME": return "date and time, answer as YYYY-MM-DD HH:MM in 24-hour time"
        case "YEAR": return "year, answer as a 4-digit YYYY"
        default: return nil
        }
    }

    // Same raw-string mapping as FPFieldDetails.getDataType() (note the backend uses
    // "NUMBER", not "NUMERICAL", for the .NUMERICAL case — easy to miss since the enum
    // case itself is spelled differently from the wire value).
    var dataType: FPDynamicDataTypes {
        switch column.dataType {
        case "NUMBER": return .NUMERICAL
        case "DATE": return .DATE
        case "TIME": return .TIME
        case "DATE_TIME": return .DATE_TIME
        case "YEAR": return .YEAR
        default: return .TEXT
        }
    }
}

enum FPTableAutofillContextBuilder {
    static func eligibleColumns(for row: Rows) -> [FPTableAutofillFieldContext] {
        var contexts: [FPTableAutofillFieldContext] = row.columns.filter { FPTableAutofillFieldEligibility.isEligible($0) }.map { column in
            let uiType = column.getUIType()
            var options: [FPFieldOption] = []
            switch uiType {
            case .DROPDOWN, .RADIO, .CHECKBOX, .BUTTON_RADIO:
                options = (column.dropDownOptions ?? []).map {
                    FPFieldOption(key: $0.key.stringValue(), label: $0.label.stringValue(), value: $0.value.stringValue())
                }.filter { !($0.label ?? "").trim.isEmpty }
            default:
                break
            }
            return FPTableAutofillFieldContext(column: column, uiType: uiType, options: options)
        }
        let keys = FPFormAutofillPromptKeys.uniqueKeys(for: contexts.map { $0.label })
        for index in contexts.indices { contexts[index].promptKey = keys[index] }
        return contexts
    }

    /// Same `<context>` shape FPFormAutofillContextBuilder builds for sections — the
    /// `.fpFormSection` extraction prompt doesn't distinguish a row's columns from a
    /// section's fields, it just reads whatever labels/options/format hints are listed.
    static func supplementalContext(for columns: [FPTableAutofillFieldContext]) -> String {
        columns.map {
            FPFormAutofillContextLine.make(key: $0.key, uiType: $0.uiType, dataType: $0.dataType,
                                           dateInstruction: $0.dateFormatHint, options: $0.options)
        }.joined(separator: "\n")
    }
}
