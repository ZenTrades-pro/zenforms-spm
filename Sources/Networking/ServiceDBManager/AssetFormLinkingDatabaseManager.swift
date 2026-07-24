//
//  AssetFormLinkingDatabaseManager.swift
//  crm
//
//  Created by apple on 08/05/24.
//  Copyright © 2024 SmartServ. All rights reserved.
//

import Foundation



import UIKit

struct AssetFormLinkingDatabaseManager: FPDataBaseQueries {
    typealias successCompletionHandler = (_ success: Bool)->()
    typealias completionHandler = ()->()

    var fpLoggerModal: FPLoggerModal? {
        let fpLoggerModal = FPLoggerModal()
        fpLoggerModal.loggerName = FPLoggerNames.customForms
        return fpLoggerModal
    }
    static func getTableName() -> String {
        return FPTableName.assetFormLinking
    }
    
    var companyId: String{
        if strCompanyId.isEmpty{
            let companyId = UserDefaults.standard.value(forKey: "companyId") as? String ?? "0"
            strCompanyId = companyId
        }
        return strCompanyId
    }
    
    static func getCreateQuery() -> String {
        return """
        CREATE TABLE IF NOT EXISTS \(self.getTableName()) (
        \(FPColumn.sqliteId)                  \(FPDataTypes.integer) PRIMARY KEY AUTOINCREMENT,
        \(FPColumn.assetId)                   \(FPDataTypes.integer),
        \(FPColumn.assetLocalId)             \(FPDataTypes.integer),
        \(FPColumn.sectionId)                \(FPDataTypes.integer),
        \(FPColumn.sectionLocalId)           \(FPDataTypes.integer),
        \(FPColumn.customFormId)      \(FPDataTypes.integer),
        \(FPColumn.customFormLocalId)         \(FPDataTypes.integer),
        \(FPColumn.isAssetSynced)               \(FPDataTypes.bool1),
        \(FPColumn.fieldTemplateId)               \(FPDataTypes.text),
        \(FPColumn.sectionTemplateId)               \(FPDataTypes.text),
        \(FPColumn.formTemplateId)               \(FPDataTypes.text),
        \(FPColumn.tableRowId)                     \(FPDataTypes.text),
        \(FPColumn.tableRowLocalId)               \(FPDataTypes.text),
        \(FPColumn.companyId)                   \(FPDataTypes.integer),
        \(FPColumn.isSyncedToServer)          \(FPDataTypes.bool1),
        \(FPColumn.addLinking)          \(FPDataTypes.bool1),
        \(FPColumn.sectionLinking)          \(FPDataTypes.bool0),
        \(FPColumn.deleteLinking)          \(FPDataTypes.bool0),
        \(FPColumn.isNotConfirmed)          \(FPDataTypes.bool0),
        \(FPColumn.zenScanLat)                 \(FPDataTypes.text),
        \(FPColumn.zenScanLong)                \(FPDataTypes.text),
        \(FPColumn.zenScanAccuracy)            \(FPDataTypes.text),
        \(FPColumn.zenScanTimestamp)           \(FPDataTypes.text),
        \(FPColumn.zenScanUserId)              \(FPDataTypes.text),
        \(FPColumn.zenScanStatus)              \(FPDataTypes.text)
        );
        """
    }
    
    func getDeleteQuery() -> String {
        return """
        DELETE FROM \(AssetFormLinkingDatabaseManager.getTableName())\n
        """
    }
    func getLastInsertQuery() -> String {
        return ""
    }
    func getInsertQuery() -> String {
        return """
        INSERT INTO \(AssetFormLinkingDatabaseManager.getTableName()) (
        """
    }
    
    func getInsertBaseQuery(_ item: AssetFormMappingData) -> String {
        var insertQuery = self.getInsertQuery()
        insertQuery += "\(FPColumn.companyId),"
        
        if item.customFormId != nil {
            insertQuery += "\(FPColumn.customFormId),"
        }
        
        if item.customFormLocalId != nil {
            insertQuery += "\(FPColumn.customFormLocalId),"
        }
        
        if item.assetId != nil {
            insertQuery += "\(FPColumn.assetId),"
        }
        
        if item.assetLocalId != nil {
            insertQuery += "\(FPColumn.assetLocalId),"
        }
        
        if item.sectionId != nil {
            insertQuery += "\(FPColumn.sectionId),"
        }
        
        if item.sectionLocalId != nil {
            insertQuery += "\(FPColumn.sectionLocalId),"
        }
        
        if item.fieldTemplateId != nil {
            insertQuery += "\(FPColumn.fieldTemplateId),"
        }
        
        if item.sectionTemplateId != nil {
            insertQuery += "\(FPColumn.sectionTemplateId),"
        }
        
        if item.formTemplateId != nil {
            insertQuery += "\(FPColumn.formTemplateId),"
        }
        
        if item.tableRowId != nil {
            insertQuery += "\(FPColumn.tableRowId),"
        }
        
        if item.tableRowLocalId != nil {
            insertQuery += "\(FPColumn.tableRowLocalId),"
        }
        
        insertQuery += """
        \(FPColumn.isAssetSynced),
        \(FPColumn.isSyncedToServer),
        \(FPColumn.addLinking),
        \(FPColumn.sectionLinking),
        \(FPColumn.deleteLinking),
        \(FPColumn.isNotConfirmed),
        \(FPColumn.zenScanLat),
        \(FPColumn.zenScanLong),
        \(FPColumn.zenScanAccuracy),
        \(FPColumn.zenScanTimestamp),
        \(FPColumn.zenScanUserId),
        \(FPColumn.zenScanStatus)

        )
        VALUES
        (
        """
        return insertQuery
    }
    
    func getInsertQuery(for item: AssetFormMappingData) -> String {
        var insertQuery = self.getInsertBaseQuery(item)
        insertQuery += "'\(companyId)',"
       
        if let value = item.customFormId{
            insertQuery += "'\(value)',"
        }
        
        if let value = item.customFormLocalId{
            insertQuery += "'\(value)',"
        }
        
        if let value = item.assetId{
            insertQuery += "'\(value)',"
        }
        
        if let value =  item.assetLocalId{
            insertQuery += "'\(value)',"
        }
        
        if let value = item.sectionId{
            insertQuery += "'\(value)',"
        }
        
        if let value =  item.sectionLocalId{
            insertQuery += "'\(value)',"
        }
        
        if let value = item.fieldTemplateId {
            insertQuery += "'\(value)',"
        }
        
        if let value = item.sectionTemplateId {
            insertQuery += "'\(value)',"
        }
        
        if let value = item.formTemplateId {
            insertQuery += "'\(value)',"
        }
        
        if let value = item.tableRowId {
            insertQuery += "'\(value)',"
        }
        
        if let value = item.tableRowLocalId {
            insertQuery += "'\(value)',"
        }
       
        insertQuery += """
        '\(item.isAssetSynced ? 1 : 0)',
        '\(item.isSyncedToServer ? 1 : 0)',
        '\(item.addLinking ? 1 : 0)',
        '\(item.sectionLinking ? 1 : 0)',
        '\(item.deleteLinking ? 1 : 0)',
        '\(item.isNotConfirmed ? 1 : 0)',
        '\(item.zenScanLat ?? 0.0)',
        '\(item.zenScanLong ?? 0.0)',
        '\(item.zenScanAccuracy ?? 0.0)',
        '\(item.zenScanTimestamp ?? 0)',
        '\(item.zenScanUserId ?? "")',
        '\(item.zenScanStatus ?? "")'
        )
        """
        return insertQuery
    }
    
    func insertMappingData(_ item : AssetFormMappingData, completion: @escaping successCompletionHandler) {
        FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([self.getInsertQuery(for: item)], dbManager: self) { success in
            completion(success)
        }
    }
    
    
    func upsert(item: AssetFormMappingData, isAddLinking:Bool = false, completionHandler:  @escaping successCompletionHandler) {
        if item.sectionLinking == true{
            self.upsertSectionAsset(item: item) { success in
                completionHandler(success)
            }
            return
        }
        if let fieldTemplateId = item.fieldTemplateId {
            FPLocalDatabaseManager.shared.executeQuery(self.getFetchFieldTemplatedRowQuery(fieldTemplateId, rowId: item.tableRowId, rowLocalId: item.tableRowLocalId, formId: item.customFormId?.stringValue, formLocalId: item.customFormLocalId?.stringValue), dbManager: self) { results in
                if let result = results.first {
                    let dbItem = AssetFormMappingData(json: result, isForLocal: false)
                    let updatedItem = item
                    updatedItem.sqliteId = dbItem.sqliteId
                    self.updateMappingData(item) { success in
                        completionHandler(success)
                    }
                }else {
                    self.insertMappingData(item) { success in
                        completionHandler(success)
                    }
                }
            }
        }else {
            completionHandler(false)
        }
    }
    
    func deletePreviousSectionAsset(formId:String?, formLocalId:String?, prevSectionId:String?, prevSectionLocalId:String?, completionHandler:  @escaping successCompletionHandler) {
        FPLocalDatabaseManager.shared.executeQuery(self.getFetchAssetSectionQuery(prevSectionId, sectionLocalId: prevSectionLocalId, formId: formId, formLocalId: formLocalId), dbManager: self) { results in
            if let result = results.first {
                FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([self.getDeleteQuery(sqliteId: FPUtility.getNumberValue(result["sqliteId"]) ?? 0 )], dbManager: self) { success in
                    completionHandler(success)
                }
            }else{
                completionHandler(false)
            }
        }
    }
    
    func deleteAssetLinkingForForm(formId: String?, formLocalId: String?, completion: @escaping successCompletionHandler) {
        var fClause = ""
        if let fid = formId, !fid.isEmpty {
            fClause = "(\(FPColumn.customFormId) = '\(fid)' OR \(FPColumn.customFormLocalId) = '\(formLocalId ?? "")')"
        } else if let flid = formLocalId, !flid.isEmpty {
            fClause = "\(FPColumn.customFormLocalId) = '\(flid)'"
        }

        guard !fClause.isEmpty else {
            completion(false)
            return
        }

        let query = "DELETE FROM \(AssetFormLinkingDatabaseManager.getTableName()) WHERE \(FPColumn.companyId) = \(companyId) AND \(fClause)"

        FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([query], dbManager: self) { success in
            completion(success)
        }
    }

    func upsertSectionAsset(item: AssetFormMappingData, completionHandler:  @escaping successCompletionHandler) {
        FPLocalDatabaseManager.shared.executeQuery(self.getFetchAssetSectionQuery(item.sectionId?.stringValue, sectionLocalId: item.sectionLocalId?.stringValue, formId: item.customFormId?.stringValue, formLocalId: item.customFormLocalId?.stringValue), dbManager: self) { results in
            if let result = results.first {
                let dbItem = AssetFormMappingData(json: result, isForLocal: false)
                let updatedItem = item
                updatedItem.sqliteId = dbItem.sqliteId
                self.updateMappingData(item) { success in
                    completionHandler(success)
                }
            }else {
                self.insertMappingData(item) { success in
                    completionHandler(success)
                }
            }
        }
    }
    
    func insertSectionAsset(item: AssetFormMappingData, completionHandler:  @escaping successCompletionHandler) {
        self.insertMappingData(item) { success in
            completionHandler(success)
        }
    }
    
    func updateMappingData(_ item: AssetFormMappingData, completion: @escaping successCompletionHandler) {
        FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([self.getUpdateQuery(item: item)], dbManager: self) { success in
            completion(success)
        }
    }
    
    func getDeleteQuery(fieldTemplateId: String, rowLocalId:String?, rowId:String?, localFormId:String?, formId:String?) -> String {
        
        var rowQureyString = ""
        if (rowId?.isEmpty ?? false) || rowId == nil {
            rowQureyString = " WHERE \(FPColumn.tableRowLocalId) = '\(rowLocalId ?? "")'"
        }else{
            rowQureyString = " WHERE \(FPColumn.tableRowId) = '\(rowId ?? "")'"
        }
        
        var formQureyString = ""
        if (formId?.isEmpty ?? false) || formId == nil {
            formQureyString = " \(FPColumn.customFormLocalId) = '\(localFormId ?? "")'"
        }else{
            formQureyString = " \(FPColumn.customFormId) = '\(formId ?? "")'"
        }
        
        
        var deleteQuery = self.getDeleteQuery()
        deleteQuery += """
        
        \(rowQureyString) AND
        \(formQureyString) AND
        \(FPColumn.fieldTemplateId) = '\(fieldTemplateId)' AND
        \(FPColumn.companyId) = \(companyId)
        """
        return deleteQuery
    }
    
    func deleteMapping(fieldTemplateId: String, rowLocalId:String?, rowId:String?, form:FPForms?, completionHandler: @escaping successCompletionHandler) {
        FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([self.getDeleteQuery(fieldTemplateId: fieldTemplateId, rowLocalId: rowLocalId, rowId: rowId, localFormId: form?.sqliteId?.stringValue, formId: form?.objectId)], dbManager: self) { success in
            completionHandler(success)
        }
    }
    
    func getDeleteQuery(sqliteId: NSNumber) -> String {
        var deleteQuery = self.getDeleteQuery()
        deleteQuery += """

        WHERE
        \(FPColumn.sqliteId) = \(sqliteId)
        """
        return deleteQuery
    }
    
    func deleteMappingData(_ item: AssetFormMappingData, completion: @escaping successCompletionHandler) {
        FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([self.getDeleteQuery(sqliteId: item.sqliteId ?? 0)], dbManager: self) { success in
            completion(success)
        }
    }
   
    func fetchAssetLinkigDataFor(customForm: FPForms) -> [AssetFormMappingData] {
        var resultArr = [AssetFormMappingData]()
        guard isAssetENABLED else {
            return resultArr
        }
        FPLocalDatabaseManager.shared.executeQuery(self.getFetchFormAssetLinkingQuery(customForm.objectId, localFormId: customForm.sqliteId?.stringValue) , dbManager: self, completionHandler: { results in
            for result in results {
                let item = AssetFormMappingData(json: result, isForLocal: false)
                resultArr.append(item)
            }
        })
        return resultArr
    }
    
    func fetchAssetScanLinkingDataFor(section: FPSectionDetails, customForm: FPForms) -> AssetFormMappingData? {
        var item: AssetFormMappingData?
        guard isAssetENABLED else {
            return item
        }
        let query = self.getFetchAssetSectionQuery(nil, sectionLocalId: section.sqliteId?.stringValue, formId: customForm.objectId, formLocalId: customForm.sqliteId?.stringValue)
        FPLocalDatabaseManager.shared.executeQuery(query, dbManager: self, completionHandler: { results in
            if let result = results.first {
                item = AssetFormMappingData(json: result, isForLocal: false)
            }
        })
        return item
    }
    
    func fetchAssetSectionLinkigDataFor(customForm: FPForms) -> [AssetFormMappingData] {
        var resultArr = [AssetFormMappingData]()
        guard isAssetENABLED else {
            return resultArr
        }
        FPLocalDatabaseManager.shared.executeQuery(self.getFetchAssetSectionQuery(nil, sectionLocalId:nil, formId:customForm.objectId, formLocalId: customForm.sqliteId?.stringValue), dbManager: self, completionHandler: { results in
            for result in results {
                let item = AssetFormMappingData(json: result, isForLocal: false)
                resultArr.append(item)
            }
        })
        return resultArr
    }
    
    
    func fetchAssetLinkigDataFor(fieldTemplateId: String, form:FPForms?) -> [AssetFormMappingData] {
        var resultArr = [AssetFormMappingData]()
        FPLocalDatabaseManager.shared.executeQuery(self.getFetchFieldTemplatedFormQuery(fieldTemplateId, formId: form?.objectId, localFormId: form?.sqliteId?.stringValue) , dbManager: self, completionHandler: { results in
            for result in results {
                let item = AssetFormMappingData(json: result, isForLocal: false)
                resultArr.append(item)
            }
        })
        return resultArr
    }
    
    func fetchAssetLinkigDataFor(fieldTemplateId: String, rowId:String?, rowLocalId:String?, customForm: FPForms?, isAddLinking:Bool = false) -> [AssetFormMappingData] {
        var resultArr = [AssetFormMappingData]()
        FPLocalDatabaseManager.shared.executeQuery(self.getFetchFieldTemplatedRowQuery(fieldTemplateId, rowId: rowId, rowLocalId: rowLocalId, formId: customForm?.objectId, formLocalId: customForm?.sqliteId?.stringValue,isAddLinking: isAddLinking) , dbManager: self, completionHandler: { results in
            for result in results {
                let item = AssetFormMappingData(json: result, isForLocal: false)
                resultArr.append(item)
            }
        })
        return resultArr
    }
    
    func fetchAssetLinkedToForm(_ customForm: FPForms?) -> [[String:NSNumber?]] {
        var resultArr = [[String:NSNumber?]]()
        FPLocalDatabaseManager.shared.executeQuery(self.getFetchAssetLinkingForForm(customForm?.objectId, formLocalId: customForm?.sqliteId?.stringValue, formTemplateId: customForm?.templateId) , dbManager: self, completionHandler: { results in
            for result in results {
                var dictAsset = [String:NSNumber?]()
                dictAsset["assetId"] = FPUtility.getNumberValue(result["assetId"])
                dictAsset["assetLocalId"] = FPUtility.getNumberValue(result["assetLocalId"])
                resultArr.append(dictAsset)
            }
        })
        return resultArr
    }
    
    func fetchAndRemoveNotConfirmedAssetLinkingForForm(_ customForm: FPForms?){
        FPLocalDatabaseManager.shared.executeQuery(self.getFetchAssetLinkingForForm(customForm?.objectId, formLocalId: customForm?.sqliteId?.stringValue, formTemplateId: customForm?.templateId, isNotConfirmed: true) , dbManager: self, completionHandler: { results in
            for result in results {
                if (result["sectionId"] == nil || result["sectionId"] is NSNull),
                   result["sectionLinking"] as? Bool == true,
                   let sectionLocalId = result["sectionLocalId"] as? NSNumber {
                    //delete locally created section for not confirmed
                    FPSectionDetailsDatabaseManager().deleteScannedNotSavedSection(for: sectionLocalId)
                }
                FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([self.getDeleteQuery(sqliteId: FPUtility.getNumberValue(result["sqliteId"]) ?? 0 )], dbManager: self) { success in }
            }
        })
    }
    
    
    
    func getFetchFormAssetLinkingQuery(_ formId:String?, localFormId:String?) -> String {
        var formQureyString = ""
        if let formId = formId, !formId.isEmpty, let formLocalId = localFormId, !formLocalId.isEmpty{
            formQureyString = " WHERE (\(FPColumn.customFormId) = '\(formId)' OR \(FPColumn.customFormLocalId) = '\(formLocalId)')"
        }else if let formLocalId = localFormId, !formLocalId.isEmpty {
            formQureyString = " WHERE \(FPColumn.customFormLocalId) = '\(formLocalId)'"
        }else{
            formQureyString = " WHERE \(FPColumn.customFormId) = '\(formId ?? "0")'"
        }
        return """
        SELECT * FROM \(AssetFormLinkingDatabaseManager.getTableName())
        \(formQureyString) AND
        \(FPColumn.companyId) = \(companyId)
        """
    }
    
    func getFetchFieldTemplatedFormQuery(_ fieldTemplateId:String, formId:String?, localFormId:String?) -> String {
        var formQureyString = ""
        if let formId = formId, !formId.isEmpty, let formLocalId = localFormId, !formLocalId.isEmpty{
            formQureyString = " WHERE (\(FPColumn.customFormId) = '\(formId)' OR \(FPColumn.customFormLocalId) = '\(formLocalId)')"
        }else if let formLocalId = localFormId, !formLocalId.isEmpty {
            formQureyString = " WHERE \(FPColumn.customFormLocalId) = '\(formLocalId)'"
        }else{
            formQureyString = " WHERE \(FPColumn.customFormId) = '\(formId ?? "0")'"
        }
        return """
        SELECT * FROM \(AssetFormLinkingDatabaseManager.getTableName())
        \(formQureyString) AND
        \(FPColumn.fieldTemplateId) = '\(fieldTemplateId)' AND
        \(FPColumn.companyId) = \(companyId)
        """
    }
    
    
    func getFetchFieldTemplatedRowQuery(_ fieldTemplateId:String, rowId:String?, rowLocalId:String?, formId:String?, formLocalId:String?, isAddLinking:Bool = false) -> String {
        var rowQureyString = ""
        var formQureyString = ""

        if let rowId = rowId, !rowId.isEmpty, let rowLocalId = rowLocalId, !rowLocalId.isEmpty{
            rowQureyString = " WHERE (\(FPColumn.tableRowLocalId) = '\(rowLocalId)' OR \(FPColumn.tableRowId) = '\(rowId)')"
        }else if let rowLocalId = rowLocalId, !rowLocalId.isEmpty {
            rowQureyString = " WHERE \(FPColumn.tableRowLocalId) = '\(rowLocalId)'"
        }else{
            rowQureyString = " WHERE \(FPColumn.tableRowId) = '\(rowId ?? "")'"
        }
        
        if let formId = formId, !formId.isEmpty, let formLocalId = formLocalId, !formLocalId.isEmpty{
            formQureyString = " (\(FPColumn.customFormId) = '\(formId)' OR \(FPColumn.customFormLocalId) = '\(formLocalId)')"
        }else if let formLocalId = formLocalId, !formLocalId.isEmpty {
            formQureyString = " \(FPColumn.customFormLocalId) = '\(formLocalId)'"
        }else{
            formQureyString = " \(FPColumn.customFormId) = '\(formId ?? "0")'"
        }
        
        if !fieldTemplateId.isEmpty, fieldTemplateId != "0"{
            formQureyString = " \(FPColumn.fieldTemplateId) = '\(fieldTemplateId)'"
        }
        
        if isAddLinking{
            return """
            SELECT * FROM \(AssetFormLinkingDatabaseManager.getTableName())
            \(rowQureyString) AND
            \(formQureyString) AND
            \(FPColumn.companyId) = \(companyId) AND
            \(FPColumn.addLinking) = 1
            """
        }else{
            return """
            SELECT * FROM \(AssetFormLinkingDatabaseManager.getTableName())
            \(rowQureyString) AND
            \(formQureyString) AND
            \(FPColumn.companyId) = \(companyId)
            """
        }
    }
    
    func getFetchAssetSectionQuery(_ sectionId:String?, sectionLocalId:String?, formId:String?, formLocalId:String?) -> String {
        var formQureyString = ""
        var sectionQureyString = ""

        if let formId = formId, !formId.isEmpty, let formLocalId = formLocalId, !formLocalId.isEmpty{
            formQureyString = " WHERE (\(FPColumn.customFormId) = '\(formId)' OR \(FPColumn.customFormLocalId) = '\(formLocalId)')"
        }else if let formLocalId = formLocalId, !formLocalId.isEmpty {
            formQureyString = " WHERE \(FPColumn.customFormLocalId) = '\(formLocalId)'"
        }else if let formId = formId, !formId.isEmpty {
            formQureyString = " WHERE \(FPColumn.customFormId) = '\(formId)'"
        }else{
            formQureyString = " WHERE 1=1 "
        }

        if let sectionId = sectionId, !sectionId.isEmpty, let sectionLocalId = sectionLocalId, !sectionLocalId.isEmpty{
            sectionQureyString = " (\(FPColumn.sectionLocalId) = '\(sectionLocalId)' OR \(FPColumn.sectionId) = '\(sectionId)')"
        }else if let sectionLocalId = sectionLocalId, !sectionLocalId.isEmpty {
            sectionQureyString = " \(FPColumn.sectionLocalId) = '\(sectionLocalId)'"
        }else if let sectionId = sectionId, !sectionId.isEmpty {
            sectionQureyString = " \(FPColumn.sectionId) = '\(sectionId)'"
        }else{}
       
        if sectionQureyString.isEmpty{
            return """
            SELECT * FROM \(AssetFormLinkingDatabaseManager.getTableName())
            \(formQureyString) AND
            \(FPColumn.companyId) = \(companyId) AND
            \(FPColumn.sectionLinking) = 1
            """
        }else{
            return """
            SELECT * FROM \(AssetFormLinkingDatabaseManager.getTableName())
            \(formQureyString) AND
            \(sectionQureyString) AND
            \(FPColumn.companyId) = \(companyId) AND
            \(FPColumn.sectionLinking) = 1
            """
        }
    }
    
    func getFetchAssetLinkingForForm(_  formId:String?, formLocalId:String?, formTemplateId:String?, isNotConfirmed:Bool = false) -> String {
        var formQureyString = ""
        
        if let formId = formId, !formId.isEmpty, let formLocalId = formLocalId, !formLocalId.isEmpty{
            formQureyString = " WHERE (\(FPColumn.customFormId) = '\(formId)' OR \(FPColumn.customFormLocalId) = '\(formLocalId)')"
        }else if let formLocalId = formLocalId, !formLocalId.isEmpty {
            formQureyString = " WHERE \(FPColumn.customFormLocalId) = '\(formLocalId)'"
        }else if let formId = formId, !formId.isEmpty {
            formQureyString = " WHERE \(FPColumn.customFormId) = '\(formId)'"
        }else if let formTemplateId = formTemplateId, !formTemplateId.isEmpty {
            formQureyString = " WHERE \(FPColumn.formTemplateId) = '\(formTemplateId)'"
        }else{
            formQureyString = " WHERE 1=1 "
        }
        
        if isNotConfirmed{
            return """
            SELECT * FROM \(AssetFormLinkingDatabaseManager.getTableName())
            \(formQureyString) AND
            \(FPColumn.companyId) = \(companyId) AND
            \(FPColumn.isNotConfirmed) = 1
            """
        }else{
            return """
            SELECT * FROM \(AssetFormLinkingDatabaseManager.getTableName())
            \(formQureyString) AND
            \(FPColumn.companyId) = \(companyId) AND
            \(FPColumn.addLinking) = 1
            """
        }
        
    }
  
    
    func getUpdateQuery() -> String {
        return """
        UPDATE \(AssetFormLinkingDatabaseManager.getTableName())
        SET
        
        """
    }
    
    func batchUpsertDeleteAssetLinking(assetRowIds: [String], assetRowLocalIds: [String], fieldTemplateId: String, form: FPForms?) {
        var queries = [String]()
        let allIds = (assetRowIds + assetRowLocalIds).filter { !$0.isEmpty }
        guard !allIds.isEmpty else { return }
        let idsString = allIds.map { "'\($0)'" }.joined(separator: ",")
        var fClause = ""
        if let fid = form?.objectId, !fid.isEmpty { 
            fClause = "AND (\(FPColumn.customFormId) = '\(fid)' OR \(FPColumn.customFormLocalId) = '\(form?.sqliteId?.stringValue ?? "")')" 
        } else if let flid = form?.sqliteId?.stringValue, !flid.isEmpty { 
            fClause = "AND \(FPColumn.customFormLocalId) = '\(flid)'" 
        }
        
        let activeConstraint = "AND \(FPColumn.addLinking) = 1"

        let softQuery = "UPDATE \(AssetFormLinkingDatabaseManager.getTableName()) SET \(FPColumn.deleteLinking) = 1, \(FPColumn.addLinking) = 0, \(FPColumn.isSyncedToServer) = 0, \(FPColumn.isNotConfirmed) = 0 WHERE \(FPColumn.companyId) = \(companyId) AND \(FPColumn.fieldTemplateId) = '\(fieldTemplateId)' \(fClause) \(activeConstraint) AND \(FPColumn.isSyncedToServer) = 1 AND (\(FPColumn.tableRowId) IN (\(idsString)) OR \(FPColumn.tableRowLocalId) IN (\(idsString)))"
        queries.append(softQuery)
        
        let hardQuery = "DELETE FROM \(AssetFormLinkingDatabaseManager.getTableName()) WHERE \(FPColumn.companyId) = \(companyId) AND \(FPColumn.fieldTemplateId) = '\(fieldTemplateId)' \(fClause) \(activeConstraint) AND \(FPColumn.isSyncedToServer) = 0 AND (\(FPColumn.tableRowId) IN (\(idsString)) OR \(FPColumn.tableRowLocalId) IN (\(idsString)))"
        queries.append(hardQuery)
        
        if !queries.isEmpty { FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery(queries, dbManager: self) { _ in } }
    }
    
    func getUpdateQuery(item: AssetFormMappingData) -> String {
        var updateQuery = self.getUpdateQuery()
        
        if let value = item.assetId {
            updateQuery += "\(FPColumn.assetId)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.assetId)= NULL,"
        }
        
        if let value = item.assetLocalId {
            updateQuery += "\(FPColumn.assetLocalId)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.assetLocalId)= NULL,"
        }
        
        if let value = item.sectionId {
            updateQuery += "\(FPColumn.sectionId)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.sectionId)= NULL,"
        }
        
        if let value = item.sectionLocalId {
            updateQuery += "\(FPColumn.sectionLocalId)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.sectionLocalId)= NULL,"
        }
        
        if let value = item.customFormId {
            updateQuery += "\(FPColumn.customFormId)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.customFormId)= NULL,"
        }
        
        if let value = item.customFormLocalId {
            updateQuery += "\(FPColumn.customFormLocalId)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.customFormLocalId)= NULL,"
        }
        
        if let value = item.tableRowId {
            updateQuery += "\(FPColumn.tableRowId)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.tableRowId)= NULL,"
        }
        
        if let value = item.tableRowLocalId {
            updateQuery += "\(FPColumn.tableRowLocalId)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.tableRowLocalId)= NULL,"
        }
        
        updateQuery += """
        \(FPColumn.isAssetSynced)='\(item.isAssetSynced ? 1 : 0)',
        \(FPColumn.isSyncedToServer)='\(item.isSyncedToServer ? 1 : 0)',
        \(FPColumn.addLinking)='\(item.addLinking ? 1 : 0)',
        \(FPColumn.sectionLinking)='\(item.sectionLinking ? 1 : 0)',
        \(FPColumn.deleteLinking)='\(item.deleteLinking ? 1 : 0)',
        \(FPColumn.isNotConfirmed)='\(item.isNotConfirmed ? 1 : 0)',
        \(FPColumn.zenScanLat)='\(item.zenScanLat ?? 0.0)',
        \(FPColumn.zenScanLong)='\(item.zenScanLong ?? 0.0)',
        \(FPColumn.zenScanAccuracy)='\(item.zenScanAccuracy ?? 0.0)',
        \(FPColumn.zenScanTimestamp)='\(item.zenScanTimestamp ?? 0)',
        \(FPColumn.zenScanUserId)='\(item.zenScanUserId ?? "")',
        \(FPColumn.zenScanStatus)='\(item.zenScanStatus ?? "")'

        WHERE \(FPColumn.sqliteId) = \(item.sqliteId ?? 0)
        """
        return updateQuery
    }
    
}
        


