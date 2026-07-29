//
//  FPSectionDetailsCF.swift
//  crm
//
//  Created by Apple on 06/01/21.
//  Copyright © 2021 SmartServ. All rights reserved.
//

import UIKit

public class FPSectionDetails: NSObject {
    public var sqliteId: NSNumber?
    public var objectId: NSNumber?
    public var objectStringId: String?
    public var templateId: String?
    public var name: String?
    public var displayName: String?
    public var showDisplayName: Bool = true
    public var moduleId: NSNumber?
    public var moduleEntityId: NSNumber?
    public var moduleEntityStringId: String?         // template ids are mongo string
    public var sortPosition: String?
    public var fields = [FPFieldDetails]()
    public var showSummary: Bool = false
    public var createdAt: String?
    public var updatedAt: String?
    public var locallyUpdatedAt: String?
    public var isSyncedToServer: Bool = true
    public var isDeleted: Bool = false
    public var isActive: Bool = true
    public var isHidden: Bool = false
    public var sectionMappingValue: String?
    public var sectionOptions: [String:Any]?
    public var moduleEntityLocalId: NSNumber?

    public override init() {}
    
    init(json:[String:Any], isForLocal: Bool) {
        super.init()
        self.objectId = FPUtility.getNumberValue(json["id"])
        self.objectStringId = FPUtility.getSQLiteCompatibleStringValue(json["id"], isForLocal: isForLocal)
        self.templateId = FPUtility.getSQLiteCompatibleStringValue(json["templateId"], isForLocal: isForLocal)
        self.sqliteId = FPUtility.getNumberValue(json["sqliteId"])
        self.showDisplayName = json["showDisplayName"] as? Bool ?? true
        self.showSummary = json["showSummary"] as? Bool ?? false
        self.name = FPUtility.getSQLiteCompatibleStringValue(json["name"], isForLocal: isForLocal)
        self.displayName = FPUtility.getSQLiteCompatibleStringValue(json["displayName"], isForLocal: isForLocal)
        self.moduleId = FPUtility.getNumberValue(json["moduleId"])
        self.moduleEntityId = FPUtility.getNumberValue(json["moduleEntityId"])
        self.moduleEntityLocalId = FPUtility.getNumberValue(json["moduleEntityLocalId"])
        self.moduleEntityStringId = FPUtility.getSQLiteCompatibleStringValue(json["moduleEntityId"], isForLocal: isForLocal)
        self.sortPosition = FPUtility.getSQLiteCompatibleStringValue(json["sortPosition"], isForLocal: isForLocal)
        if let array = FPUtility.getArrayValue(json["fields"]) as? [[String:Any]] {
            var parsedFields: [FPFieldDetails] = []
            parsedFields.reserveCapacity(array.count)

            for item in array {
                parsedFields.append(
                    FPFieldDetails(json: item, isForLocal: isForLocal)
                )
            }
            self.fields = parsedFields
        }
        self.createdAt = FPUtility.getSQLiteCompatibleStringValue(json["createdAt"], isForLocal: isForLocal)
        self.updatedAt = FPUtility.getSQLiteCompatibleStringValue(json["updatedAt"], isForLocal: isForLocal)
        self.isSyncedToServer = json["isSyncedToServer"] as? Bool ?? true
        if !FPUtility.isObjectEmpty(json["locallyUpdatedAt"]) {
            self.locallyUpdatedAt = FPUtility.getSQLiteCompatibleStringValue(json["locallyUpdatedAt"], isForLocal: isForLocal)
        }else if !FPUtility.isObjectEmpty(self.updatedAt) {
            self.locallyUpdatedAt = self.updatedAt
        }else {
            self.locallyUpdatedAt = FPUtility.getStringWithTZFormat(Date())
        }
        self.isActive = json["isActive"] as? Bool ?? true
        self.isDeleted = json["isDeleted"] as? Bool ?? false
       
        if let options = json["options"] as? [String:Any] {
            self.sectionOptions = options
            self.isHidden = options["isHidden"] as? Bool ?? false
            self.sectionMappingValue = options["columnMappingValue"] as? String ?? ""
        }else if let  options = (json["options"] as? String)?.getDictonary() {
            self.sectionOptions = options
            self.isHidden = options["isHidden"] as? Bool ?? false
            self.sectionMappingValue = options["columnMappingValue"] as? String ?? ""
        }
        
    }
    
    func getJSON() -> [String:Any] {
        var json = [String: Any]()
        json["id"] = self.objectId
        json["templateId"] = self.templateId
        json["moduleEntityId"] = self.moduleEntityId
        json["name"] = FPUtility.getSQLiteCompatibleStringValue(self.name, isForLocal: false)
        json["displayName"] = FPUtility.getSQLiteCompatibleStringValue(self.displayName, isForLocal: false)
        json["showDisplayName"] = self.showDisplayName
        json["showSummary"] = self.showSummary
        json["moduleId"] = self.moduleId
        json["sortPosition"] = self.sortPosition
        var array = [[String:Any]]()
        array.reserveCapacity(fields.count)

        for item in fields {
            array.append(item.getJSON())
        }
        json["fields"] = array
        json["options"] = self.sectionOptions
        return json
    }
    
    func getDraftJSON() -> [String:Any] {
        var json = [String: Any]()
        json["id"] = self.objectId
        json["templateId"] = self.templateId
        json["moduleEntityId"] = self.moduleEntityId
        json["name"] = FPUtility.getSQLiteCompatibleStringValue(self.name, isForLocal: false)
        json["displayName"] = FPUtility.getSQLiteCompatibleStringValue(self.displayName, isForLocal: false)
        json["showDisplayName"] = self.showDisplayName
        json["showSummary"] = self.showSummary
        json["moduleId"] = self.moduleId
        json["sortPosition"] = self.sortPosition
        var array = [[String:Any]]()
        array.reserveCapacity(fields.count)

        for item in fields {
            let uiType = item.getUIType()
            if uiType == .TABLE || uiType == .TABLE_RESTRICTED {
                continue
            }
            array.append(item.getJSON())
        }
        json["fields"] = array
        json["options"] = self.sectionOptions
        return json
    }
    
    func copyFPSectionDetails(_ isTemplate: Bool) -> FPSectionDetails {
        let item = FPSectionDetails()
        item.isActive = self.isActive
        item.isDeleted = self.isDeleted
        item.name = self.name
        item.displayName = self.displayName
        item.showDisplayName = self.showDisplayName
        item.moduleId = self.moduleId
        item.sortPosition = self.sortPosition
        if isTemplate {
            item.templateId = self.objectStringId
        }else {
            item.sqliteId = self.sqliteId
            item.objectId = self.objectId
            item.objectStringId = self.objectStringId
            item.templateId = self.templateId
            item.createdAt = self.createdAt
            item.updatedAt = self.updatedAt
            item.locallyUpdatedAt = self.locallyUpdatedAt
            item.isSyncedToServer = self.isSyncedToServer
            item.moduleEntityId = self.moduleEntityId
            item.moduleEntityStringId = self.moduleEntityStringId
        }
        item.createdAt = FPUtility.getStringWithTZFormat(Date())
        item.updatedAt = item.createdAt
        item.locallyUpdatedAt = item.createdAt
        var itemfields: [FPFieldDetails] = []
        itemfields.reserveCapacity(fields.count)

        for field in fields {
            itemfields.append(field.copyFPFieldDetails(isTemplate))
        }
        item.fields = itemfields.sorted {
            ($0.sortPosition ?? "") < ($1.sortPosition ?? "")
        }
        item.showSummary = self.showSummary
        item.sectionOptions = self.sectionOptions
        item.isHidden = self.isHidden
        item.sectionMappingValue = self.sectionMappingValue
        item.isSyncedToServer = self.isSyncedToServer
        item.moduleEntityLocalId = self.moduleEntityLocalId
        return item
    }
    
    func copyPreviousFPFormSectionDetails() -> FPSectionDetails {
        let item = FPSectionDetails()
        item.isActive = self.isActive
        item.isDeleted = self.isDeleted
        item.name = self.name
        item.displayName = self.displayName
        item.showDisplayName = self.showDisplayName
        item.moduleId = self.moduleId
        item.sortPosition = self.sortPosition
        item.templateId = self.templateId
        item.createdAt = FPUtility.getStringWithTZFormat(Date())
        item.updatedAt = item.createdAt
        item.locallyUpdatedAt = item.createdAt
        var itemfields = [FPFieldDetails]()
        for field in self.fields {
            itemfields.append(field.copyPreviousFPFormFieldDetails())
        }
        item.fields = itemfields.sorted(by:{$0.sortPosition ?? "" < $1.sortPosition ?? ""})
        item.showSummary = self.showSummary
        item.sectionOptions = self.sectionOptions
        item.isHidden = self.isHidden
        item.sectionMappingValue = self.sectionMappingValue
        return item
    }
    
    
}

