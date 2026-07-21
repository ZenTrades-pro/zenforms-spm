//
//  FPFieldDetailsDatabaseManager.swift
//  crm
//
//  Created by Apple on 07/01/21.
//  Copyright © 2021 SmartServ. All rights reserved.
//

import Foundation
struct FPFieldDetailsDatabaseManager: FPDataBaseQueries {
    typealias GetFields = (_ fields: [FPFieldDetails]) -> Void

    var fpLoggerModal: FPLoggerModal? {
        let ddLoggerModal = FPLoggerModal()
        return ddLoggerModal
    }
    static func getTableName() -> String {
        return FPTableName.fieldDetails
    }
    
    static func getCreateQuery() -> String {
        return """
        CREATE TABLE IF NOT EXISTS \(self.getTableName()) (
        \(FPColumn.sqliteId)                      \(FPDataTypes.integer) PRIMARY KEY AUTOINCREMENT,
        \(FPColumn.id)                            \(FPDataTypes.integer) UNIQUE,
        \(FPColumn.templateId)                    \(FPDataTypes.var100),
        \(FPColumn.name)                          \(FPDataTypes.var100),
        \(FPColumn.displayName)                   \(FPDataTypes.var100),
        \(FPColumn.value)                      \(FPDataTypes.text),
        \(FPColumn.uiType)                     \(FPDataTypes.var100),
        \(FPColumn.dataType)                     \(FPDataTypes.var100),
        \(FPColumn.mandatory)                     \(FPDataTypes.bool0),
        \(FPColumn.max)                     \(FPDataTypes.int),
        \(FPColumn.min)                     \(FPDataTypes.int),
        \(FPColumn.defaultValue)                     \(FPDataTypes.text),
        \(FPColumn.attachments)                     \(FPDataTypes.text),
        \(FPColumn.readOnly)                     \(FPDataTypes.bool0),
        \(FPColumn.options)                     \(FPDataTypes.text),
        \(FPColumn.sectionId)                      \(FPDataTypes.integer),
        \(FPColumn.sectionLocalId)                      \(FPDataTypes.integer),
        \(FPColumn.sortPosition)                   \(FPDataTypes.var100),
        \(FPColumn.isDeleted)                     \(FPDataTypes.bool0),
        \(FPColumn.isActive)                      \(FPDataTypes.bool1),
        \(FPColumn.createdAt)                     \(FPDataTypes.date),
        \(FPColumn.updatedAt)                     \(FPDataTypes.date),
        \(FPColumn.locallyUpdatedAt)              \(FPDataTypes.date),
        \(FPColumn.moduleId)                      \(FPDataTypes.integer),
        \(FPColumn.isSyncedToServer)              \(FPDataTypes.bool1),
        \(FPColumn.reasons)                        \(FPDataTypes.text),
        \(FPColumn.scannable)                      \(FPDataTypes.bool0),
        \(FPColumn.isSectionDuplicationField)       \(FPDataTypes.bool0)
        );
        """
    }
    
    // Create indexes for optimized batch query performance
    static func getCreateIndexQueries() -> [String] {
        return [
            """
            CREATE INDEX IF NOT EXISTS idx_fields_section_module 
            ON \(FPFieldDetailsDatabaseManager.getTableName())(\(FPColumn.sectionLocalId), \(FPColumn.moduleId), \(FPColumn.sortPosition))
            """
        ]
    }
    
    func getLastInsertQuery() -> String {
        return "SELECT MAX(\(FPColumn.sqliteId)) as lastInsertedId FROM \(FPFieldDetailsDatabaseManager.getTableName())"
    }
    func getInsertQuery() -> String {
        return """
        INSERT INTO \(FPFieldDetailsDatabaseManager.getTableName()) (
        """
    }
    func getInsertBaseQuery(_ item: FPFieldDetails, _ moduleId: Int) -> String {
        var insertQuery = self.getInsertQuery()
        if item.objectId != nil {
            insertQuery += "\(FPColumn.id),"
        }
        if item.templateId != nil {
            insertQuery += "\(FPColumn.templateId),"
        }
        if item.name != nil {
            insertQuery += "\(FPColumn.name),"
        }
        if item.displayName != nil {
            insertQuery += "\(FPColumn.displayName),"
        }
        if item.value != nil {
            insertQuery += "\(FPColumn.value),"
        }
        if item.uiType != nil {
            insertQuery += "\(FPColumn.uiType),"
        }
        if item.dataType != nil {
            insertQuery += "\(FPColumn.dataType),"
        }
        if item.max != nil {
            insertQuery += "\(FPColumn.max),"
        }
        if item.min != nil {
            insertQuery += "\(FPColumn.min),"
        }
        if item.defaultValue != nil {
            insertQuery += "\(FPColumn.defaultValue),"
        }
        if item.attachments != nil {
            insertQuery += "\(FPColumn.attachments),"
        }
        if item.sortPosition != nil {
            insertQuery += "\(FPColumn.sortPosition),"
        }
        if item.options != nil {
            insertQuery += "\(FPColumn.options),"
        }
        if item.sectionId != nil {
            insertQuery += "\(FPColumn.sectionId),"
        }
        if item.createdAt != nil {
            insertQuery += "\(FPColumn.createdAt),"
        }
        if item.updatedAt != nil {
            insertQuery += "\(FPColumn.updatedAt),"
        }
        if item.locallyUpdatedAt != nil {
            insertQuery += "\(FPColumn.locallyUpdatedAt),"
        }
        if item.reasons != nil {
            insertQuery += "\(FPColumn.reasons),"
        }
        insertQuery += """
        \(FPColumn.sectionLocalId),
        \(FPColumn.mandatory),
        \(FPColumn.readOnly),
        \(FPColumn.isActive),
        \(FPColumn.isDeleted),
        \(FPColumn.moduleId),
        \(FPColumn.isSyncedToServer),
        \(FPColumn.scannable),
        \(FPColumn.isSectionDuplicationField)
        )
        VALUES
        (
        """
        return insertQuery
    }
    
    func getInsertQuery(for item: FPFieldDetails, _ sectionLocalId:NSNumber, _ moduleId: Int) -> String {
        var insertQuery = self.getInsertBaseQuery(item, moduleId)
        if let value = item.objectId  {
            insertQuery += "'\(value)',"
        }
        if let value = item.templateId {
            insertQuery += "'\(value)',"
        }
        if let value = item.name {
            insertQuery += "'\(value.processApostrophe())',"
        }
        if let value = item.displayName {
            insertQuery += "'\(value.processApostrophe())',"
        }
        if let value = item.value {
            insertQuery += "'\(value.processApostrophe())',"
        }
        if let value = item.uiType {
            insertQuery += "'\(value)',"
        }
        if let value = item.dataType {
            insertQuery += "'\(value)',"
        }
        if let value = item.max {
            insertQuery += "'\(value)',"
        }
        if let value = item.min {
            insertQuery += "'\(value)',"
        }
        if let value = item.defaultValue {
            insertQuery += "'\(value.processApostrophe())',"
        }
        if let value = item.attachments {
            insertQuery += "'\(value.processApostrophe())',"
        }
        if let value = item.sortPosition {
            insertQuery += "'\(value)',"
        }
        if let value = item.options {
            insertQuery += "'\(value.processApostrophe())',"
        }
        if let value = item.sectionId {
            insertQuery += "'\(value)',"
        }
        if let value = item.createdAt {
            insertQuery += "'\(value)',"
        }
        if let value = item.updatedAt {
            insertQuery += "'\(value)',"
        }
        if let value = item.locallyUpdatedAt {
            insertQuery += "'\(value)',"
        }
        if let value = item.reasons {
            insertQuery += "'\(value.processApostrophe())',"
        }
        insertQuery += """
        '\(sectionLocalId)',
        '\(item.mandatory ? 1 : 0)',
        '\(item.readOnly ? 1 : 0)',
        '\(item.isActive ? 1 : 0)',
        '\(item.isDeleted ? 1 : 0)',
        \(moduleId),
        '\(item.isSyncedToServer ? 1 : 0)',
        '\(item.scannable ? 1 : 0)',
        '\(item.isSectionDuplicationField ? 1 : 0)'
        )
        """
        return insertQuery
    }
    func lastInserted() -> [String: Any]? {
        var result:[String: Any]?
        FPLocalDatabaseManager.shared.executeQuery(self.getLastInsertQuery(), dbManager: self) { results in
            result = results.first
        }
        return result
    }
    func insertFieldDetails(_ fieldDetails: [FPFieldDetails], _ sectionLocalId:NSNumber, _ moduleId: Int) {
        let queryArray = fieldDetails.map { (value) -> String  in
            return self.getInsertQuery(for: value, sectionLocalId, moduleId)
        }
        FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery(queryArray, dbManager: self)
    }
        
    func insertFieldDetails(_ fieldDetails: [FPFieldDetails], _ sectionLocalId: NSNumber, _ moduleId: Int, completion: @escaping GetFields ) {
        var dbFields =  [FPFieldDetails]()
        let group = DispatchGroup()
        for item in fieldDetails {
            group.enter()
            FPLocalDatabaseManager.shared.executeCRUDQuery(self.getInsertQuery(for: item, sectionLocalId, moduleId), dbManager: self) { success, lastInsertedId in
                item.sqliteId = lastInsertedId
                dbFields.append(item)
                group.leave()
            }
        }
        group.notify(queue: .main) {
            completion(dbFields)
        }
    }
    
    func insertEquipmentFieldDetails(_ fieldDetails: [FPFieldDetails], _ sectionLocalId:NSNumber, _ moduleId: Int) {
        for item in fieldDetails {
            FPLocalDatabaseManager.shared.executeCRUDQuery(self.getInsertQuery(for: item, sectionLocalId, moduleId), dbManager: self) { success, lastInsertedId in
                item.sqliteId = lastInsertedId
            }
        }
    }
    func fetchFieldDetails(for sectionLocalId: NSNumber, _ moduleId: Int) -> [FPFieldDetails] {
        var array = [FPFieldDetails]()
        FPLocalDatabaseManager.shared.executeQuery(self.getFetchQuery(sectionLocalId, moduleId), dbManager: self, completionHandler: { results in
            for item in results {
                let item = FPFieldDetails(json: item, isForLocal: false)
                array.append(item)
            }
        })
        return array
    }
    
    // Optimized batch fetch for multiple sections
    func fetchFieldDetailsForSections(sectionIds: [NSNumber], moduleId: Int, completion: @escaping ([NSNumber: [FPFieldDetails]]) -> Void) {
        guard !sectionIds.isEmpty else {
            completion([:])
            return
        }
        
        let idsString = sectionIds.map { "\($0)" }.joined(separator: ",")
        let batchQuery = """
        SELECT * FROM \(FPFieldDetailsDatabaseManager.getTableName())
        WHERE \(FPColumn.sectionLocalId) IN (\(idsString))
        AND \(FPColumn.moduleId) = \(moduleId)
        ORDER BY \(FPColumn.sectionLocalId), \(FPColumn.sortPosition) ASC
        """
        
        FPLocalDatabaseManager.shared.executeQuery(batchQuery, dbManager: self) { results in
            var fieldsDict = [NSNumber: [FPFieldDetails]]()
            
            for item in results {
                let field = FPFieldDetails(json: item, isForLocal: false)
                
                // Group by section ID (sectionLocalId from DB maps to sectionId property)
                if let sectionLocalId = item["sectionLocalId"] as? NSNumber {
                    if fieldsDict[sectionLocalId] == nil {
                        fieldsDict[sectionLocalId] = []
                    }
                    fieldsDict[sectionLocalId]?.append(field)
                }
            }
            
            completion(fieldsDict)
        }
    }
    func getFetchQuery(_ sectionLocalId:NSNumber, _ moduleId: Int) -> String {
        return """
        SELECT * FROM \(FPFieldDetailsDatabaseManager.getTableName())
        WHERE \(FPColumn.sectionLocalId) = \(sectionLocalId) AND
        \(FPColumn.moduleId) = \(moduleId)
        """
    }
    
    func getUpdateQuery() -> String {
        return """
        UPDATE \(FPFieldDetailsDatabaseManager.getTableName())
        SET
        
        """
    }
    func getUpdateQuery(_ sqliteId: Int, _ item: FPFieldDetails) -> String {
        var updateQuery = self.getUpdateQuery()
       
    // ✅ SAFE id update (prevents UNIQUE constraint crash)
       if let value = item.objectId {
           updateQuery += """
           \(FPColumn.id) = CASE
               WHEN NOT EXISTS (
                   SELECT 1 FROM \(FPFieldDetailsDatabaseManager.getTableName())
                   WHERE \(FPColumn.id) = '\(value)'
                     AND \(FPColumn.sqliteId) != \(sqliteId)
               )
               THEN '\(value)'
               ELSE \(FPColumn.id)
           END,
           """
       } else {
           updateQuery += "\(FPColumn.id)= NULL,"
       }
        
        if let value = item.templateId {
            updateQuery += "\(FPColumn.templateId)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.templateId)= NULL,"
        }
        if let value = item.name {
            updateQuery += "\(FPColumn.name)='\(value.processApostrophe())',"
        }else {
            updateQuery += "\(FPColumn.name)= NULL,"
        }
        
        if let value = item.displayName {
            updateQuery += "\(FPColumn.displayName)='\(value.processApostrophe())',"
        }else {
            updateQuery += "\(FPColumn.displayName)= NULL,"
        }
        
        if let value = item.value {
            updateQuery += "\(FPColumn.value)='\(value.processApostrophe())',"
        }else {
            updateQuery += "\(FPColumn.value)= NULL,"
        }
        
        if let value = item.uiType {
            updateQuery += "\(FPColumn.uiType)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.uiType)= NULL,"
        }
        if let value = item.dataType {
            updateQuery += "\(FPColumn.dataType)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.dataType)= NULL,"
        }
        if let value = item.max {
            updateQuery += "\(FPColumn.max)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.max)= NULL,"
        }
        if let value = item.min {
            updateQuery += "\(FPColumn.min)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.min)= NULL,"
        }
        if let value = item.defaultValue {
            updateQuery += "\(FPColumn.defaultValue)='\(value.processApostrophe())',"
        }else {
            updateQuery += "\(FPColumn.defaultValue)= NULL,"
        }
        if let value = item.attachments {
            updateQuery += "\(FPColumn.attachments)='\(value.processApostrophe())',"
        }else {
            updateQuery += "\(FPColumn.attachments)= NULL,"
        }
        if let value = item.sortPosition {
            updateQuery += "\(FPColumn.sortPosition)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.sortPosition)= NULL,"
        }
        if let value = item.options {
            updateQuery += "\(FPColumn.options)='\(value.processApostrophe())',"
        }else {
            updateQuery += "\(FPColumn.options)= NULL,"
        }
        if let value = item.sectionId {
            updateQuery += "\(FPColumn.sectionId)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.sectionId)= NULL,"
        }
        
        if let value = item.locallyUpdatedAt {
            updateQuery += "\(FPColumn.locallyUpdatedAt)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.locallyUpdatedAt)= NULL,"
        }
        
        if let value = item.updatedAt {
            updateQuery += "\(FPColumn.updatedAt)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.updatedAt)= NULL,"
        }
        
        if let value = item.reasons {
            updateQuery += "\(FPColumn.reasons)='\(value)',"
        } else {
            updateQuery += "\(FPColumn.reasons)= NULL,"
        }
        
        updateQuery += """
        \(FPColumn.mandatory)= '\(item.mandatory ? 1 : 0)',
        \(FPColumn.readOnly)= '\(item.readOnly ? 1 : 0)',
        \(FPColumn.isActive)= '\(item.isActive ? 1 : 0)',
        \(FPColumn.isDeleted)= '\(item.isDeleted ? 1 : 0)',
        \(FPColumn.isSyncedToServer)='\(item.isSyncedToServer ? 1 : 0)',
        \(FPColumn.scannable)='\(item.scannable ? 1 : 0)',
        \(FPColumn.isSectionDuplicationField)='\(item.isSectionDuplicationField ? 1 : 0)'
        WHERE
        \(FPColumn.sqliteId)=\(sqliteId)
        """
        return updateQuery
    }
    
    func getUpdateQueryByObjectId(_ remoteId: Int, _ item: FPFieldDetails) -> String {
        var updateQuery = self.getUpdateQuery()
       
        if let value = item.templateId {
            updateQuery += "\(FPColumn.templateId)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.templateId)= NULL,"
        }
        if let value = item.name {
            updateQuery += "\(FPColumn.name)='\(value.processApostrophe())',"
        }else {
            updateQuery += "\(FPColumn.name)= NULL,"
        }
        
        if let value = item.displayName {
            updateQuery += "\(FPColumn.displayName)='\(value.processApostrophe())',"
        }else {
            updateQuery += "\(FPColumn.displayName)= NULL,"
        }
        
        if let value = item.value {
            updateQuery += "\(FPColumn.value)='\(value.processApostrophe())',"
        }else {
            updateQuery += "\(FPColumn.value)= NULL,"
        }
        
        if let value = item.uiType {
            updateQuery += "\(FPColumn.uiType)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.uiType)= NULL,"
        }
        if let value = item.dataType {
            updateQuery += "\(FPColumn.dataType)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.dataType)= NULL,"
        }
        if let value = item.max {
            updateQuery += "\(FPColumn.max)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.max)= NULL,"
        }
        if let value = item.min {
            updateQuery += "\(FPColumn.min)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.min)= NULL,"
        }
        if let value = item.defaultValue {
            updateQuery += "\(FPColumn.defaultValue)='\(value.processApostrophe())',"
        }else {
            updateQuery += "\(FPColumn.defaultValue)= NULL,"
        }
        if let value = item.attachments {
            updateQuery += "\(FPColumn.attachments)='\(value.processApostrophe())',"
        }else {
            updateQuery += "\(FPColumn.attachments)= NULL,"
        }
        if let value = item.sortPosition {
            updateQuery += "\(FPColumn.sortPosition)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.sortPosition)= NULL,"
        }
        if let value = item.options {
            updateQuery += "\(FPColumn.options)='\(value.processApostrophe())',"
        }else {
            updateQuery += "\(FPColumn.options)= NULL,"
        }
        if let value = item.sectionId {
            updateQuery += "\(FPColumn.sectionId)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.sectionId)= NULL,"
        }
        
        if let value = item.locallyUpdatedAt {
            updateQuery += "\(FPColumn.locallyUpdatedAt)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.locallyUpdatedAt)= NULL,"
        }
        
        if let value = item.updatedAt {
            updateQuery += "\(FPColumn.updatedAt)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.updatedAt)= NULL,"
        }
        
        if let value = item.reasons {
            updateQuery += "\(FPColumn.reasons)='\(value)',"
        } else {
            updateQuery += "\(FPColumn.reasons)= NULL,"
        }
        
        updateQuery += """
        \(FPColumn.mandatory)= '\(item.mandatory ? 1 : 0)',
        \(FPColumn.readOnly)= '\(item.readOnly ? 1 : 0)',
        \(FPColumn.isActive)= '\(item.isActive ? 1 : 0)',
        \(FPColumn.isDeleted)= '\(item.isDeleted ? 1 : 0)',
        \(FPColumn.isSyncedToServer)='\(item.isSyncedToServer ? 1 : 0)',
        \(FPColumn.scannable)='\(item.scannable ? 1 : 0)',
        \(FPColumn.isSectionDuplicationField)='\(item.isSectionDuplicationField ? 1 : 0)'
        WHERE
        \(FPColumn.id)=\(remoteId)
        """
        return updateQuery
    }
    
    func xupdateFieldDetails(_ item: FPFieldDetails) {
        if let localId = item.sqliteId as? Int {
            FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([self.getUpdateQuery(localId, item)], dbManager: self)
        }else{
            if let remoteId = item.objectId?.intValue as? Int {
                FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([self.getUpdateQueryByObjectId(remoteId, item)], dbManager: self)
            }
        }
    }
    
    func updateFieldDetails(_ item: FPFieldDetails) {
        if let id = item.sqliteId as? Int {
            FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([self.getUpdateQuery(id, item)], dbManager: self)
        }
    }

    func updateFieldDetails(_ item: FPFieldDetails, completion: @escaping () -> Void) {
        guard let id = item.sqliteId as? Int else { completion(); return }
        FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([self.getUpdateQuery(id, item)], dbManager: self) { _ in
            completion()
        }
    }
    
    func getDeleteQuery() -> String {
        return """
        DELETE FROM \(FPFieldDetailsDatabaseManager.getTableName())\n
        """
    }
    func getDeleteQuery(for sqlitId: NSNumber) -> String {
        var deleteQuery = self.getDeleteQuery()
        deleteQuery += """
        
        WHERE
        \(FPColumn.isSyncedToServer) = 1 AND
        \(FPColumn.sqliteId) = \(sqlitId)
        """
        return deleteQuery
    }
    
    func getDeleteQuery(for sqlitIdCSV: String) -> String {
        var deleteQuery = self.getDeleteQuery()
        deleteQuery += """
        
        WHERE
        \(FPColumn.sqliteId) IN (\(sqlitIdCSV))
        """
        return deleteQuery
    }
   
    func deleteFieldDetails(for sqlitId: NSNumber) {
        FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([self.getDeleteQuery(for: sqlitId)], dbManager: self)
    }
    func deleteFieldDetails(forArray sections: [FPFieldDetails]) {
        var sqliteIdArray = [String]()
        for item in sections {
            if let id = item.sqliteId {
                sqliteIdArray.append("\(id)")
            }
        }
        if sqliteIdArray.count > 0 {
            FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([self.getDeleteQuery(for: sqliteIdArray.joined(separator: ","))], dbManager: self)
        }
    }
}
