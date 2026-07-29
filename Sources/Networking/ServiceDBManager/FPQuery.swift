//
//  DataBaseConstants.swift
//  crm
//
//  Created by Soumya on 30/04/20.
//  Copyright © 2020 SmartServ. All rights reserved.
//

import Foundation

@objcMembers class FPQuery: NSObject {
   
    @objc static func getCreateTableQuery(_ tableName: String) -> String {
        switch tableName {
        case FPTableName.form:
            return FPFormsDatabaseManager.getCreateQuery()
        case FPTableName.sectionDetails:
            return FPSectionDetailsDatabaseManager.getCreateQuery()
        case FPTableName.fieldDetails:
            return FPFieldDetailsDatabaseManager.getCreateQuery()
        case FPTableName.assetFormLinking:
            return AssetFormLinkingDatabaseManager.getCreateQuery()
        case FPTableName.differentialMeta:
            return FPDifferentialMetaDatabaseManager.getCreateQuery()
        case FPTableName.sectionDetailsTemplate:
            return FPSectionDetailsTemplateDatabaseManager.getCreateQuery()
        case FPTableName.fieldDetailsTemplate:
            return FPFieldDetailsTemplateDatabaseManager.getCreateQuery()
        case FPTableName.tableDraftData:
            return FPTableDraftDatabaseManager.getCreateQuery()
        case FPTableName.sectionDraftData:
            return FPSectionDraftDatabaseManager.getCreateQuery()
        default:
            return ""
        }
    }
    
    
    @objc static func selectAllQuery(_ tableName: String) -> String {
        return "select * from \(tableName)"
    }
    
    @objc static func deleteAllQuery(_ tableName: String) -> String {
        return "DELETE FROM \(tableName);"
    }
}

@objcMembers class FPColumn: NSObject {
    static let createdAt = "createdAt"
    static let firstName = "firstName"
    static let lastName = "lastName"
    static let email = "email"
    static let isActive = "isActive"
    static let isAdmin = "isAdmin"
    static let id = "id"
    static let localClientId = "localClientId"
    static let companyId = "companyId"
    static let templateId = "templateId"
    static let isTemplate = "isTemplate"
    static let sqliteId = "sqliteId"
    static let updatedAt = "updatedAt"
    static let locallyUpdatedAt = "locallyUpdatedAt"
    static let createdBy = "createdBy"
    static let displayName = "displayName"
    static let equipmentId = "equipmentId"
    static let parentTicketId = "parentTicketId"
    static let name = "name"
    static let isSyncedToServer = "isSyncedToServer"
    static let moduleId = "moduleId"
    static let moduleEntityId = "moduleEntityId"
   
    static let parentId = "parentId"
    static let parentType = "parentType"
   
    static let isDeleted = "isDeleted"
    static let createdUser = "createdUser"
    static let updatedUser = "updatedUser"
    static let mediaId = "mediaId"
  
    //Form
    static let fileId = "fileId"
    static let localFileId = "localFileId"
    static let isAnalysed = "isAnalysed"
    
    //section details
    
    static let showTitle = "showTitle"
    static let localEntityId = "localEntityId"
    static let sortPosition = "sortPosition"
    static let uiType = "uiType"

    static let dataType = "dataType"
    static let mandatory = "mandatory"
    static let max = "max"
    static let min = "min"
    static let defaultValue = "defaultValue"
    static let readOnly = "readOnly"
    static let options = "options"
    static let layout = "layout"
    static let sectionId = "sectionId"
    static let sectionLocalId = "sectionLocalId"
    static let showDisplayName = "showDisplayName"
    static let showSummary = "showSummary"
    static let equipmentCFLocalId = "equipmentCFLocalId"
    static let equipmentCFId = "equipmentCFId"
    static let moduleEntityLocalId = "moduleEntityLocalId"
    static let equipmentLocalId = "equipmentLocalId"
    static let reasons = "reasons"
    static let isHidden = "isHidden"
    static let sectionMappingValue = "columnMappingValue"
    static let sectionOptions = "options"
    static let scannable = "scannable"
    static let isSectionDuplicationField = "isSectionDuplicationField"

    // Custom Forms
    static let customFormId = "customFormId"
    static let customFormLocalId = "customFormLocalId"
    static let isCustom = "isCustom"
    static let value = "value"
    static let attachments = "attachments"
    static let isSigned = "isSigned"
    static let signedAt = "signedAt"
    static let notes = "notes"
    static let deletedSections = "deletedSections"
    static let downloadStatus = "downloadStatus"
    static let downloadURL = "downloadURL"
    static let draftKey = "draft_key"
    static let fieldId = "fieldId"
    static let fieldLocalId = "fieldLocalId"
    
    //Linking
    static let isAssetSynced = "isAssetSynced"
    static let fieldTemplateId = "fieldTemplateId"
    static let sectionTemplateId = "sectionTemplateId"
    static let formTemplateId = "formTemplateId"
    static let tableRowId = "tableRowId"
    static let tableRowLocalId = "tableRowLocalId"
    static let addLinking = "addLinking"
    static let sectionLinking = "sectionLinking"
    static let deleteLinking = "deleteLinking"
    static let isNotConfirmed = "isNotConfirmed"

    //Assets
    static let assetId = "assetId"
    static let assetLocalId = "assetLocalId"
    
    //differential meta
    static let apiName = "apiName"
    static let payload = "payload"
    static let isFetching = "isFetching"
    static let pageCount = "pageCount"
}

@objcMembers class FPDataTypes: NSObject {
    static let var100 = "VARCHAR(100)"
    static let var50 = "VARCHAR(50)"
    static let var30 = "VARCHAR(30)"
    static let var20 = "VARCHAR(20)"
    static let int = "INT"
    static let integer = "INTEGER"
    static let text = "TEXT"
    static let date = "DATE"
    static let blob = "BLOB"
    static let bool0 = "BOOL NOT NULL DEFAULT 0"
    static let bool1 = "BOOL NOT NULL DEFAULT 1"
    static let notnull = "NOT NULL"
    static let real = "REAL"
}

@objcMembers class FPKey: NSObject {
    static let primary = "PRIMARY KEY"
    static let foreign = "FOREIGN KEY"
    static let autoincrement = "AUTOINCREMENT"
    static let unique = "UNIQUE"
}

@objcMembers class FPTableName: NSObject {
    static let form = "Form"
    static let sectionDetails = "SectionDetails"
    static let fieldDetails = "FieldDetails"
    static let assetFormLinking = "AssetFormLinking"
    static let differentialMeta = "FPDifferentialMeta"
    static let fieldDetailsTemplate = "FPFieldDetailsTemplate"
    static let sectionDetailsTemplate = "FPSectionDetailsTemplate"
    static let tableDraftData = "TableDraftData"
    static let sectionDraftData = "SectionDraftData"

    static func getArrayOfTables() -> [String] {
        let mirrored_object = Mirror(reflecting: FPTableName.self)
        var tableNameArray = [String]()
        for (_, attr) in mirrored_object.children.enumerated() {
            if let _ = attr.label {
                tableNameArray.append("\(attr.value)")
            }
        }
        var count: CUnsignedInt = 0
        let methods = class_copyPropertyList(object_getClass(FPTableName.self), &count)!
        for i in 0 ..< count {
            let selector = property_getName(methods.advanced(by: Int(i)).pointee)
            if let key = String(cString: selector, encoding: .utf8) {
                let res = FPTableName.value(forKey: key)
                tableNameArray.append("\(res ?? "")")
            }
        }
        return tableNameArray
    }

}

