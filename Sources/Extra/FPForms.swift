//
//  Forms.swift
//  crm
//
//  Created by L Sunil Achari on 05/10/23.
//  Copyright © 2023 SmartServ. All rights reserved.
//

import Foundation
import UIKit

public enum FPFormType: String {
    case individualAsset = "INDIVIDUAL_ASSET"
    case assetType = "ASSET_TYPE"
    case general = "GENERAL"

    init(apiValue: String?) {
        self = apiValue == "COMPLIANCE" ? .assetType : (Self(rawValue: apiValue ?? "") ?? .individualAsset)
    }
}

public class FPForms : NSObject{
    public var formType: FPFormType = .individualAsset
    public var assetTypeId: NSNumber?
    public var parentFpFormId: NSNumber?
    public var assetFormIds: [NSNumber] = []
    var hasFormTypeMetadata = false

    func copyInspectionContext(from form: FPForms) {
        formType = form.formType
        hasFormTypeMetadata = form.hasFormTypeMetadata
        assetTypeId = form.assetTypeId
        parentFpFormId = form.parentFpFormId
        assetFormIds = form.assetFormIds
        assetId = form.assetId
        scheduleId = form.scheduleId
    }

    /// Type order used by the web: the form's own formType, else compliance when it has an assetTypeId,
    /// else its template's formType, else an asset form.
    public func resolveFormType(templates: [FPForms]) {
        guard ZenForms.assetInspectionEnabled, !hasFormTypeMetadata else { return }
        if assetTypeId != nil {
            formType = .assetType
        } else {
            formType = templates.first { $0.objectId == templateId && templateId != nil }?.formType ?? .individualAsset
        }
    }

    /// Applies what the template decides when a form opens: read-only sections, and the asset form table's
    /// isAssetFormTable, assetTemplateIds, assetFormMapping and columns. Matched by template id, never by name.
    func applyTemplateInspectionOptions(_ templateSections: [FPSectionDetails], refreshTableMapping: Bool) {
        guard ZenForms.assetInspectionEnabled, !templateSections.isEmpty else { return }
        var sectionsByID = [String: FPSectionDetails]()
        var fieldsByID = [String: FPFieldDetails]()
        for section in templateSections {
            if let id = section.objectStringId { sectionsByID[id] = section }
            for field in section.fields { if let id = field.objectStringId { fieldsByID[id] = field } }
        }
        for section in sections ?? [] {
            if let id = section.templateId, let template = sectionsByID[id] {
                section.isTemplateReadOnly = template.sectionOptions?["isReadOnly"] as? Bool == true
            }
            guard refreshTableMapping else { continue }
            for field in section.fields {
                guard let id = field.templateId, let template = fieldsByID[id]?.getOptionsDictionary(),
                      template["isAssetFormTable"] as? Bool == true || field.isAssetFormTable else { continue }
                field.refreshOptions(keys: ["isAssetFormTable", "assetTemplateIds", "assetFormMapping", "columns"], from: template)
            }
        }
    }

    public func replaceAssetFormRows(from latest: FPForms) {
        guard ZenForms.assetInspectionEnabled else { return }
        let tables = latest.sections?.flatMap(\.fields).filter(\.isAssetFormTable) ?? []
        for field in sections?.flatMap(\.fields) ?? [] where field.isAssetFormTable {
            if let match = tables.first(where: { $0.templateId == field.templateId }) {
                field.value = match.value
            }
        }
        parentFpFormId = latest.parentFpFormId
        assetFormIds = latest.assetFormIds
    }

    public func rebuildAssetFormRows(from forms: [FPForms], assetTypes: [Int64: Int], isNew: Bool = false) {
        guard ZenForms.assetInspectionEnabled, formType == .assetType, let typeID = assetTypeId?.intValue else { return }
        for table in sections?.flatMap(\.fields) ?? [] where table.isAssetFormTable {
            guard let options = table.getOptionsDictionary(),
                  let templates = options["assetTemplateIds"] as? [String],
                  let mapping = options["assetFormMapping"] as? [String: [String: Any]],
                  let columns = options["columns"] as? [[String: Any]] else { continue }
            let children = forms.filter { child in
                guard child.formType == .individualAsset, child.isDeleted != true,
                      let templateID = child.templateId, templates.contains(templateID) else { return false }
                if child.isSyncedToServer != false, !isNew {
                    return (objectId != nil && child.parentFpFormId?.stringValue == objectId) || assetFormIds.contains { $0.stringValue == child.objectId }
                }
                if isNew, child.parentFpFormId != nil { return false }
                guard !(child.sections?.flatMap(\.fields).contains { $0.getOptionsDictionary()?["isAssetTable"] as? Bool == true } ?? false),
                      let assetID = child.assetId?.int64Value else { return false }
                return assetTypes[assetID] == typeID
            }.sorted {
                let left = Int64($0.objectId ?? "") ?? Int64.max
                let right = Int64($1.objectId ?? "") ?? Int64.max
                return left == right ? ($0.localClientId ?? "") < ($1.localClientId ?? "") : left < right
            }
            var rows: [[String: Any]] = children.map { child in
                var row: [String: Any] = ["fpFormId": child.objectId ?? "", "assetId": child.assetId ?? 0]
                for column in columns {
                    guard let name = column["name"] as? String, name != "fpFormId", name != "assetId" else { continue }
                    guard let fieldID = mapping[name]?[child.templateId ?? ""] as? String,
                          let field = child.sections?.flatMap(\.fields).first(where: { $0.templateId == fieldID }) else {
                        row[name] = "—"; continue
                    }
                    row[name] = field.assetFormDisplayValue
                }
                return row
            }
            let knownIDs = Set(forms.compactMap(\.objectId))
            let groupedIDs = Set(assetFormIds.map(\.stringValue))
            if !isNew, let saved = table.value?.data(using: .utf8),
               let cachedRows = (try? JSONSerialization.jsonObject(with: saved)) as? [[String: Any]] {
                rows += cachedRows.filter { row in
                    let id = (row["fpFormId"] as? String) ?? (row["fpFormId"] as? NSNumber)?.stringValue ?? ""
                    return groupedIDs.contains(id) && !knownIDs.contains(id)
                }
                rows = rows.enumerated().sorted { left, right in
                    func number(_ row: [String: Any]) -> Int64 {
                        (row["fpFormId"] as? NSNumber)?.int64Value ?? Int64(row["fpFormId"] as? String ?? "") ?? .max
                    }
                    let a = number(left.element), b = number(right.element)
                    return a == b ? left.offset < right.offset : a < b
                }.map(\.element)
            }
            if let data = try? JSONSerialization.data(withJSONObject: rows), let json = String(data: data, encoding: .utf8) {
                table.value = json
            }
        }
    }

    public var locallyUpdatedAt:String?
    public var sqliteId:NSNumber?
    public var objectId:String?
    public var localClientId:String?
    public var assetId:NSNumber?
    public var scheduleId:NSNumber?
    public var createdAt:String?
    public var updatedAt:String?
    public var isSyncedToServer:Bool? = false
    public var companyId:NSNumber?
    public var templateId:String?
    public var isTemplate:Bool? = false
    public var isActive:Bool? = false
    public var isDeleted:Bool? = false
    public var name:String?
    public var ticketNumber:NSNumber?
    public var ticketId:NSNumber?
    public var customFormLocalId:NSNumber?
    public var customFormId:NSNumber?
    public var sections:[FPSectionDetails]?
    public var displayName:String?
    public var objectStringId:String?
    public var shortDescription:String?
    public var isAnalysed:Bool?
    public var isSelected:Bool? = false
    public var isDynamic:Bool? = false
    public var isHidden:Bool? = false
    public var sectionMappingValue:String?
    public var fpFormUpdatedUserId: NSNumber?
    public var generatedEstimate: String?
    public var sectionOption:[String:Any]?
    public var signedAt: NSNumber?
    public var isSigned: Bool? = false
    public var notes: String?
    public var deletedSections: String?
    public var downloadStatus: String?
    public var dwnldEnmStatus: INSPECTION_FORM_DOWNLOAD_STATUS = .NOT_REQUESTED
    public var isLoading: Bool? = false

    public var downloadURL: String?

    public enum INSPECTION_FORM_DOWNLOAD_STATUS : String {
        case NOT_REQUESTED
        case IN_PROGRESS
        case COMPLETED
        case FAILED
    }
    
    
    private static let createdDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return formatter
    }()
    
    public override init() { }
    
    public init(dict:[String: Any], isForLocal:Bool) {
        super.init()
        
        if dict["uuid"] != nil {
            self.sqliteId = FPUtility.getNumberValue(dict["uuid"])
        }else {
            self.sqliteId = FPUtility.getNumberValue(dict["sqliteId"])
        }
        
        self.objectId = FPUtility.getSQLiteCompatibleStringValue(dict["id"], isForLocal:isForLocal)
        self.objectStringId = FPUtility.getSQLiteCompatibleStringValue(dict["id"], isForLocal:isForLocal)
        self.localClientId = FPUtility.getSQLiteCompatibleStringValue(dict["localClientId"], isForLocal:isForLocal)
        self.companyId = FPUtility.getNumberValue(dict["companyId"])
        assetTypeId = FPUtility.getNumberValue(dict["assetTypeId"])
        hasFormTypeMetadata = (dict["hasFormTypeMetadata"] as? NSNumber)?.boolValue ?? (dict["formType"] is String)
        // No formType on the form: an assetTypeId means compliance; otherwise it stays an asset form
        // until resolveFormType(templates:) can read it from the template.
        formType = hasFormTypeMetadata || assetTypeId == nil ? FPFormType(apiValue: dict["formType"] as? String) : .assetType
        parentFpFormId = FPUtility.getNumberValue(dict["parentFpFormId"])
        assetId = FPUtility.getNumberValue(dict["assetId"])
        scheduleId = FPUtility.getNumberValue(dict["scheduleId"])
        if let ids = dict["assetFormIds"] as? [Any] {
            assetFormIds = ids.compactMap { FPUtility.getNumberValue($0) }
        } else if let json = dict["assetFormIds"] as? String,
                  let data = json.data(using: .utf8),
                  let ids = (try? JSONSerialization.jsonObject(with: data)) as? [Any] {
            assetFormIds = ids.compactMap { FPUtility.getNumberValue($0) }
        }
        
        self.templateId = FPUtility.getSQLiteCompatibleStringValue(dict["templateId"], isForLocal:isForLocal)
        if self.templateId == nil{
            self.templateId = self.objectStringId
        }
        self.name = FPUtility.getSQLiteCompatibleStringValue(dict["name"], isForLocal:isForLocal)
        
        let createdKey = dict["fpFormCreatedAt"] != nil ? "fpFormCreatedAt" : "createdAt"
        self.createdAt = FPUtility.getStringValue(dict[createdKey])
        
        let updatedKey = dict["fpFormUpdatedAt"] != nil ? "fpFormUpdatedAt" : "updatedAt"
        self.updatedAt = FPUtility.getStringValue(dict[updatedKey])
        
        if let localLastUpdatedAt = dict["localLastUpdatedAt"] as? String {
            self.locallyUpdatedAt = localLastUpdatedAt
        } else if let updatedAt = self.updatedAt {
            self.locallyUpdatedAt = updatedAt
        }
        
        if dict["isSyncedToServer"] != nil{
            self.isSyncedToServer =  FPUtility.getNumberValue(dict["isSyncedToServer"])?.boolValue ?? true
        }else {
            self.isSyncedToServer = true
        }
                
        if let isTemplateValue = dict["isTemplate"] as? Bool {
            self.isTemplate = isTemplateValue
        }
        
        self.ticketNumber = FPUtility.getNumberValue(dict["parentTicketId"])
        self.ticketId = FPUtility.getNumberValue(dict["ticketId"])        
        self.isActive = dict["isActive"] as? Bool ?? false
        self.isDeleted = dict["isDeleted"] as? Bool ?? false
        
        if let _ = dict["fpFormId"] {
            self.customFormId = FPUtility.getNumberValue(dict["fpFormId"])
        } else {
            self.customFormId = FPUtility.getNumberValue(dict["customFormId"])
        }
        
        if let _ = dict["fpFormUpdatedUserId"] {
            self.fpFormUpdatedUserId = FPUtility.getNumberValue(dict["fpFormUpdatedUserId"])
        }
        self.customFormLocalId = FPUtility.getNumberValue(dict["customFormLocalId"])
        
        if let sectionsArray = dict["sections"] as? [[String: Any]] {
            var parsedSections: [FPSectionDetails] = []
            parsedSections.reserveCapacity(sectionsArray.count)
            for sectionDictionary in sectionsArray {
                parsedSections.append(
                    FPSectionDetails(json: sectionDictionary, isForLocal: isForLocal)
                )
            }
            self.sections = parsedSections
        }
        
        if let _ = dict["fpFormDisplayName"] {
            self.displayName = FPUtility.getSQLiteCompatibleStringValue(dict["fpFormDisplayName"], isForLocal:isForLocal)
        } else {
            self.displayName = FPUtility.getSQLiteCompatibleStringValue(dict["displayName"], isForLocal:isForLocal)
        }
        self.shortDescription = FPUtility.getSQLiteCompatibleStringValue(dict["shortDescription"], isForLocal:isForLocal)
        
        if let isDynamicValue = dict["isDynamic"] as? Bool {
            self.isDynamic = isDynamicValue
        }
        
        if let isAnalysedValue = dict["isAnalysed"] as? Bool {
            self.isAnalysed = isAnalysedValue
        } else {
            self.isAnalysed = false
        }
        
        self.isSigned = false
        if let dictSignature = dict["signature"] as? [String:Any] {
            self.isSigned = true
            self.signedAt = FPUtility.getNumberValue(dictSignature["updatedAt"])
        }else if let _ = dict["signature"] as? String {
            self.isSigned = true
        }else if let isSignedValue = dict["isSigned"] as? Bool {
            self.isSigned = isSignedValue
        }
        
        if let signedAt = dict["signedAt"] {
            self.signedAt = FPUtility.getNumberValue(signedAt)
        }

        if let isHidden = dict["isHidden"] as? Bool {
            self.isHidden = isHidden
        }
        
        if let sectionMappingValue = dict["columnMappingValue"] as? String {
            self.sectionMappingValue = sectionMappingValue
        }
        
        if let sectionOption = dict["option"] as? [String:Any] {
            if let isHidden = sectionOption["isHidden"] as? Bool {
                self.isHidden = isHidden
            }
            if let sectionMappingValue = sectionOption["columnMappingValue"] as? String {
                self.sectionMappingValue = sectionMappingValue
            }
            self.sectionOption = sectionOption
        }
        if let notes = dict["notes"] as? [NSNumber] {
            self.notes = notes.map(\.stringValue).joined(separator: ",")
        }else if let notes = dict["notes"] as? String {
            self.notes = notes
        }
        
        if let deletedSections = dict["deletedSections"] as? [NSNumber] {
            self.deletedSections = deletedSections.map { $0.stringValue}.joined(separator: ",")
        }else if let deletedSections = dict["deletedSections"] as? String {
            self.deletedSections = deletedSections
        }
        
        self.downloadURL = dict["downloadURL"] as? String
        self.downloadStatus = dict["downloadStatus"] as? String
        self.dwnldEnmStatus = INSPECTION_FORM_DOWNLOAD_STATUS(rawValue: self.downloadStatus ?? "") ?? .NOT_REQUESTED
    }
    
    func getJSONForUpdate() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let objectID = Int(self.objectId ?? "") {
            dict["id"] = objectID
        }
        dict["name"] = self.name
        dict["displayName"] = self.displayName
        
        if let templateId = self.templateId {
            dict["templateId"] = templateId
        } else {
            dict["templateId"] = ""
        }
        
        let updatedSections = getSectionsArray(isUpdate: true)
        if !updatedSections.isEmpty {
            dict["sections"] = updatedSections
        }
        return dict
    }
    
    func getSectionsArray(isUpdate: Bool = false) -> [[String:Any]] {
        guard let sections = sections else { return [] }
        var array = [[String:Any]]()
        array.reserveCapacity(sections.count)

        for section in sections {
            if isUpdate, section.isSyncedToServer == true { continue }
            array.append(section.getJSON())
        }
        return array
    }

    
    public func getJSONForSync() -> [String: Any] {
        var dict: [String: Any] = [:]
        
        dict["name"] = self.name
        
        if let objectId = Int(self.objectId ?? "") {
            dict["id"] = objectId
        } else {
            dict["createdAt"] = self.createdAt ?? ""
            dict["templateId"] = self.templateId ?? ""
        }
        
        dict["updatedAt"] = self.updatedAt ?? ""
        
        // Include localClientId if set (should be set during insertForm, similar to sqliteId)
        if let localClientId = self.localClientId, !localClientId.isEmpty {
            dict["localClientId"] = localClientId
        }
        
        if let sections = self.sections, !sections.isEmpty {
            dict["sections"] = getSectionsArray()
        }
        
        return dict
    }
    
    
    
    public func getCopyOfCustomForm(isTemplate: Bool) -> FPForms {
        let copy = FPForms()
        copy.formType = formType
        copy.hasFormTypeMetadata = hasFormTypeMetadata
        copy.objectId = self.objectId
        copy.companyId = self.companyId
        copy.name = self.name
        copy.displayName = self.displayName ?? self.name
        copy.createdAt = FPUtility.getStringWithTZFormat(Date())
        copy.updatedAt = FPUtility.getStringWithTZFormat(Date())
        copy.locallyUpdatedAt = FPUtility.getStringWithTZFormat(Date())
        copy.isSyncedToServer = self.isSyncedToServer
        copy.ticketNumber = self.ticketNumber
        copy.ticketId = self.ticketId

        if isTemplate {
            if !(self.objectId?.isEmpty ?? false) {
                copy.templateId = self.objectId
            } else {
                copy.templateId = self.templateId
            }
        } else {
            copy.templateId = self.templateId
            copy.sqliteId = self.sqliteId
            copy.localClientId = self.localClientId
            copy.copyInspectionContext(from: self)
            copy.assetId = self.assetId
            copy.scheduleId = self.scheduleId
        }

        if let sections = self.sections, !sections.isEmpty {
            var copiedSections: [FPSectionDetails] = []
            copiedSections.reserveCapacity(sections.count)
            for section in sections {
                copiedSections.append(section.copyFPSectionDetails(isTemplate))
            }
            copy.sections = copiedSections
        }

        copy.isAnalysed = self.isAnalysed
        copy.sectionOption = self.sectionOption
        copy.deletedSections = self.deletedSections
        copy.downloadURL = self.downloadURL
        copy.downloadStatus = self.downloadStatus
        copy.signedAt = self.signedAt
        copy.isSigned = self.isSigned
        copy.notes = self.notes
        copy.sectionMappingValue = self.sectionMappingValue
        
        fixAssetIdSortPosition(in: copy)

        return copy
    }
    
    
    func fixAssetIdSortPosition(in form: FPForms) {
        guard let sections = form.sections else { return }

        for section in sections {
            guard section.isHidden == false else { continue }

            var maxSortPosition: String?
            var assetField: FPFieldDetails?

            for field in section.fields {
                if let sort = field.sortPosition {
                    if let max = maxSortPosition {
                        if sort > max { maxSortPosition = sort }
                    } else {
                        maxSortPosition = sort
                    }
                }
                if field.name == "assetId",
                   field.uiType == "HIDDEN",
                   field.sortPosition == "000" {
                    assetField = field
                }
            }

            let finalSortPosition = maxSortPosition ?? "\(section.fields.count - 1)"
            if let assetField = assetField {
                assetField.sortPosition = "\(finalSortPosition)1"
            }
        }
    }
    
    public func getCopyOfCustomPreviousForm() -> FPForms {
        let copy = FPForms()
        copy.formType = formType
        copy.hasFormTypeMetadata = hasFormTypeMetadata
        copy.companyId = self.companyId
        copy.name = self.name
        copy.displayName = self.displayName ?? self.name
        copy.createdAt = FPUtility.getStringWithTZFormat(Date())
        copy.updatedAt = FPUtility.getStringWithTZFormat(Date())
        copy.locallyUpdatedAt = FPUtility.getStringWithTZFormat(Date())
        copy.ticketNumber = self.ticketNumber
        copy.ticketId = self.ticketId
        copy.templateId = self.templateId
        if let sections = self.sections, !sections.isEmpty {
            var copiedSections: [FPSectionDetails] = []
            copiedSections.reserveCapacity(sections.count)

            for section in sections {
                copiedSections.append(section.copyPreviousFPFormSectionDetails())
            }
            copy.sections = copiedSections
        }
        return copy
    }
    
    public func stringToNumber(_ stringValue: String?) -> NSNumber? {
        guard let value = Int(stringValue ?? "") else { return nil }
        return NSNumber(value: value)
    }
    
    public func getFormattedCreatedDate() -> String {
        guard let createdAt = self.createdAt else {
            return ""
        }
        
        if let date = FPForms.createdDateFormatter.date(from: createdAt){
            let formattedTime = FPUtility.dateString(date, withCustomFormat: "MMM dd, yyyy")
            return formattedTime
        } else {
            return ""
        }
    }
    
    
    // MARK: - Offline helper methods
    
    public func formNameWithState() -> String {
        var tempName: String
        if let displayName = self.displayName {
            tempName = displayName
        } else {
            tempName = self.name ?? ""
        }
        
//        let string = NSMutableAttributedString(string: tempName)
//        if shouldShowSyncOption() {
//            let attributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor(named: "ZT-Primary") ?? .white]
//            let subString = NSAttributedString(string: " (\(FPLocalizationHelper.localize("lbl_Not_Synced")))", attributes: attributes)
//            string.append(subString)
//        }
        
        return tempName
    }
    
    public func shouldShowSyncOption() -> Bool {
        return !(isSyncedToServer ?? false)
    }
    
}



