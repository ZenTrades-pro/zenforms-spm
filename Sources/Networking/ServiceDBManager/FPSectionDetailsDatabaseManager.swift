//
//  FPSectionDetailsDatabaseManager.swift
//  crm
//
//  Created by Apple on 07/01/21.
//  Copyright © 2021 SmartServ. All rights reserved.
//

import Foundation
struct FPSectionDetailsDatabaseManager: FPDataBaseQueries {
    
    typealias GetSections = (_ sections: [FPSectionDetails]) -> Void

    var fpLoggerModal: FPLoggerModal? {
        let ddLoggerModal = FPLoggerModal()
        return ddLoggerModal
    }
    static func getTableName() -> String {
        return FPTableName.sectionDetails
    }
    
    static func getCreateQuery() -> String {
        return """
        CREATE TABLE IF NOT EXISTS \(self.getTableName()) (
        \(FPColumn.sqliteId)                      \(FPDataTypes.integer) PRIMARY KEY AUTOINCREMENT,
        \(FPColumn.id)                            \(FPDataTypes.integer) UNIQUE,
        \(FPColumn.templateId)                    \(FPDataTypes.var100),
        \(FPColumn.name)                          \(FPDataTypes.var100),
        \(FPColumn.displayName)                   \(FPDataTypes.var100),
        \(FPColumn.moduleId)                      \(FPDataTypes.integer),
        \(FPColumn.showSummary)                   \(FPDataTypes.bool0),
        \(FPColumn.showDisplayName)                \(FPDataTypes.bool1),
        \(FPColumn.moduleEntityId)                 \(FPDataTypes.integer),
        \(FPColumn.moduleEntityLocalId)            \(FPDataTypes.integer),
        \(FPColumn.sortPosition)                   \(FPDataTypes.var100),
        \(FPColumn.isDeleted)                     \(FPDataTypes.bool0),
        \(FPColumn.isActive)                      \(FPDataTypes.bool1),
        \(FPColumn.createdAt)                     \(FPDataTypes.date),
        \(FPColumn.updatedAt)                     \(FPDataTypes.date),
        \(FPColumn.locallyUpdatedAt)              \(FPDataTypes.date),
        \(FPColumn.isSyncedToServer)              \(FPDataTypes.bool1),
        \(FPColumn.isHidden)                      \(FPDataTypes.bool0),
        \(FPColumn.sectionMappingValue)            \(FPDataTypes.var100),
        \(FPColumn.options)                         \(FPDataTypes.text)
        );
        """
    }
    
    // Create indexes for optimized batch query performance
    static func getCreateIndexQueries() -> [String] {
        return [
            """
            CREATE INDEX IF NOT EXISTS idx_sections_entity_module 
            ON \(FPSectionDetailsDatabaseManager.getTableName())(\(FPColumn.moduleEntityLocalId), \(FPColumn.moduleId), \(FPColumn.sortPosition))
            """,
            """
            CREATE INDEX IF NOT EXISTS idx_sections_entity_id 
            ON \(FPSectionDetailsDatabaseManager.getTableName())(\(FPColumn.moduleEntityId), \(FPColumn.moduleId))
            """
        ]
    }
    
  
    func getLastInsertQuery() -> String {
        return "SELECT MAX(\(FPColumn.sqliteId)) as lastInsertedId FROM \(FPSectionDetailsDatabaseManager.getTableName())"
    }
    func getInsertQuery() -> String {
        return """
        INSERT INTO \(FPSectionDetailsDatabaseManager.getTableName()) (
        """
    }
    func getInsertBaseQuery(_ item: FPSectionDetails) -> String {
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
        if item.moduleId != nil {
            insertQuery += "\(FPColumn.moduleId),"
        }
        if item.moduleEntityId != nil {
            insertQuery += "\(FPColumn.moduleEntityId),"
        }
        if item.sortPosition != nil {
            insertQuery += "\(FPColumn.sortPosition),"
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
        insertQuery += """
        \(FPColumn.moduleEntityLocalId),
        \(FPColumn.showSummary),
        \(FPColumn.showDisplayName),
        \(FPColumn.isActive),
        \(FPColumn.isDeleted),
        \(FPColumn.isSyncedToServer),
        \(FPColumn.isHidden),
        \(FPColumn.sectionMappingValue),
        \(FPColumn.options)
        )
        VALUES
        (
        """
        return insertQuery
    }
    
    func getInsertQuery(for item: FPSectionDetails, _ entityLocalId:NSNumber) -> String {
        var insertQuery = self.getInsertBaseQuery(item)
        if let value = item.objectId  {
            insertQuery += "'\(value)',"
        }
        if let value = item.templateId  {
            insertQuery += "'\(value)',"
        }
        if let value = item.name {
            insertQuery += "'\(value.processApostrophe())',"
        }
        if let value = item.displayName {
            insertQuery += "'\(value.processApostrophe())',"
        }
        if let value = item.moduleId {
            insertQuery += "'\(value)',"
        }
        if let value = item.moduleEntityId {
            insertQuery += "'\(value)',"
        }
       
        if let value = item.sortPosition {
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
        insertQuery += """
        '\(entityLocalId)',
        '\(item.showSummary ? 1 : 0)',
        '\(item.showDisplayName ? 1 : 0)',
        '\(item.isActive ? 1 : 0)',
        '\(item.isDeleted ? 1 : 0)',
        '\(item.isSyncedToServer ? 1 : 0)',
        '\(item.isHidden ? 1 : 0)',
        '\(item.sectionMappingValue ?? "")',
        '\(item.sectionOptions?.getJson() ?? "")'
        )
        """
        return insertQuery
    }
    func getlastInsertedId() -> NSNumber? {
        var lastId:NSNumber?
        FPLocalDatabaseManager.shared.executeQuery(self.getLastInsertQuery(), dbManager: self,  completionHandler: { results in
            if let result = results.first {
                lastId = result["lastInsertedId"] as? NSNumber
            }
        })
        return lastId
        
    }

    
    func insertSectionDetails(_ sectionDetails: [FPSectionDetails], _ entityLocalId: NSNumber, _ moduleId: Int = FPFormMduleId, completion: @escaping GetSections ) {
        var dbSections =  [FPSectionDetails]()
        let group = DispatchGroup()
        for item in sectionDetails {
            item.moduleId = NSNumber.init(value: moduleId)
            group.enter()
            FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([self.getInsertQuery(for: item, entityLocalId)], dbManager: self) { success in
                if success, let sectionLocalId = self.getlastInsertedId() {
                    item.sqliteId = sectionLocalId
                    FPFieldDetailsDatabaseManager().insertFieldDetails(item.fields, sectionLocalId, moduleId) { fields in
                        item.fields = []
                        item.fields.append(contentsOf: fields)
                        dbSections.append(item)
                        group.leave()
                    }
                }else{
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) {
            completion(dbSections)
        }
    }
    
   
    func fetchSectionDetails(for moduleEntityLocalId: NSNumber, _ moduleId: Int = FPFormMduleId) -> [FPSectionDetails] {
        var array = [FPSectionDetails]()
        FPLocalDatabaseManager.shared.executeQuery(self.getFetchQuery(moduleEntityLocalId, moduleId), dbManager: self,  completionHandler: { results in
            for item in results {
                let item = FPSectionDetails(json: item, isForLocal: false)
                if let id = item.sqliteId {
                    item.fields = FPFieldDetailsDatabaseManager().fetchFieldDetails(for: id, moduleId)
                }
                array.append(item)
            }
        })
        return array
    }
    
    func getFetchQuery(_ moduleEntityLocalId:NSNumber, _ moduleId: Int) -> String {
        return """
        SELECT * FROM \(FPSectionDetailsDatabaseManager.getTableName())
        WHERE \(FPColumn.moduleEntityLocalId) = \(moduleEntityLocalId) AND
        \(FPColumn.moduleId) = \(moduleId)
        """
    }
    
    func getFetchByIdQuery(id: NSNumber?) -> String {
        return """
        SELECT * FROM \(FPSectionDetailsDatabaseManager.getTableName())
        WHERE
        \(FPColumn.id) = \(id ?? 0)
        """
    }
    
    func fetchSectionDetailsOR(for moduleEntityLocalId: NSNumber, moduleEntityId:String, _ moduleId: Int = FPFormMduleId) -> [FPSectionDetails] {
        var array = [FPSectionDetails]()
        FPLocalDatabaseManager.shared.executeQuery(self.getFetchQueryOR(moduleEntityLocalId, moduleEntityId: moduleEntityId, moduleId), dbManager: self,  completionHandler: { results in
            for item in results {
                let item = FPSectionDetails(json: item, isForLocal: false)
                if let id = item.sqliteId {
                    item.fields = FPFieldDetailsDatabaseManager().fetchFieldDetails(for: id, moduleId)
                }
                array.append(item)
            }
        })
        return array
    }
    
    func fetchSectionDetailsWithCompletion(for moduleEntityLocalId: NSNumber, moduleEntityId:String, _ moduleId: Int = FPFormMduleId, completion: @escaping GetSections) {
        var array = [FPSectionDetails]()
        FPLocalDatabaseManager.shared.executeQuery(self.getFetchQueryOR(moduleEntityLocalId, moduleEntityId: moduleEntityId, moduleId), dbManager: self,  completionHandler: { results in
            for item in results {
                let item = FPSectionDetails(json: item, isForLocal: false)
                if let id = item.sqliteId {
                    item.fields = FPFieldDetailsDatabaseManager().fetchFieldDetails(for: id, moduleId)
                }
                array.append(item)
            }
            completion(array)
        })
    }
    
    // Optimized batch fetch for multiple forms - handles both sqliteId and objectId
    func fetchSectionDetailsForForms(formIds: [NSNumber], formObjectIds: [String], moduleId: Int, completion: @escaping ([NSNumber: [FPSectionDetails]]) -> Void) {
        guard !formIds.isEmpty else {
            completion([:])
            return
        }
        
        let idsString = formIds.map { "\($0)" }.joined(separator: ",")
        let objectIdsString = formObjectIds.map { "'\($0)'" }.joined(separator: ",")
        
        // Query matches both sqliteId OR objectId, just like fetchSectionDetailsOR
        let batchQuery = """
        SELECT * FROM \(FPSectionDetailsDatabaseManager.getTableName())
        WHERE (
            \(FPColumn.moduleEntityLocalId) IN (\(idsString))
            OR \(FPColumn.moduleEntityId) IN (\(objectIdsString))
        )
        AND \(FPColumn.moduleId) = \(moduleId)
        ORDER BY \(FPColumn.moduleEntityLocalId), \(FPColumn.sortPosition) ASC
        """
        
        FPLocalDatabaseManager.shared.executeQuery(batchQuery, dbManager: self) { results in
            var sectionsDict = [NSNumber: [FPSectionDetails]]()
            var sectionIds = [NSNumber]()
            var sectionIdMap = [NSNumber: FPSectionDetails]()
            
            // Step 1: Parse all sections and collect IDs
            for item in results {
                let section = FPSectionDetails(json: item, isForLocal: false)
                section.fields = [] // Initialize empty fields array
                
                if let sectionId = section.sqliteId {
                    sectionIds.append(sectionId)
                    sectionIdMap[sectionId] = section
                }
                
                // Group by form ID
                if let formId = section.moduleEntityLocalId {
                    if sectionsDict[formId] == nil {
                        sectionsDict[formId] = []
                    }
                    sectionsDict[formId]?.append(section)
                }
            }
            
            guard !sectionIds.isEmpty else {
                completion(sectionsDict)
                return
            }
            
            // Step 2: Fetch ALL fields in ONE batch query
            FPFieldDetailsDatabaseManager().fetchFieldDetailsForSections(sectionIds: sectionIds, moduleId: moduleId) { fieldsDict in
                // Step 3: Assign fields to sections
                for (sectionId, fields) in fieldsDict {
                    if let section = sectionIdMap[sectionId] {
                        section.fields = fields
                    }
                }
                
                completion(sectionsDict)
            }
        }
    }
    
    
    
    func getFetchQueryOR(_ moduleEntityLocalId:NSNumber, moduleEntityId:String, _ moduleId: Int) -> String {
        return """
        SELECT * FROM \(FPSectionDetailsDatabaseManager.getTableName())
        WHERE (\(FPColumn.moduleEntityLocalId) = '\(moduleEntityLocalId)' OR \(FPColumn.moduleEntityId) = '\(moduleEntityId)') AND
        \(FPColumn.moduleId) = \(moduleId)
        """
    }
    
    func getUpdateQuery() -> String {
        return """
        UPDATE \(FPSectionDetailsDatabaseManager.getTableName())
        SET
        
        """
    }
    func getUpdateQuery(_ sqliteId: Int, _ item: FPSectionDetails) -> String {
        var updateQuery = self.getUpdateQuery()
        if let value = item.objectId {
            updateQuery += "\(FPColumn.id)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.id)= NULL,"
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
       
        if let value = item.moduleId {
            updateQuery += "\(FPColumn.moduleId)=\(value),"
        }else {
            updateQuery += "\(FPColumn.moduleId)= NULL,"
        }
        if let value = item.sortPosition {
            updateQuery += "\(FPColumn.sortPosition)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.sortPosition)= NULL,"
        }
        
        if let value = item.moduleEntityId {
            updateQuery += "\(FPColumn.moduleEntityId)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.moduleEntityId)= NULL,"
        }
        
        if let value = item.moduleEntityLocalId {
            updateQuery += "\(FPColumn.moduleEntityLocalId)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.moduleEntityLocalId)= NULL,"
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
        
        updateQuery += """
        \(FPColumn.showSummary)= '\(item.showSummary ? 1 : 0)',
        \(FPColumn.showDisplayName)= '\(item.showDisplayName ? 1 : 0)',
        \(FPColumn.isSyncedToServer)= '\(item.isSyncedToServer ? 1 : 0)',
        \(FPColumn.isActive)= '\(item.isActive ? 1 : 0)',
        \(FPColumn.isDeleted)= '\(item.isDeleted ? 1 : 0)',
        \(FPColumn.isHidden)= '\(item.isHidden ? 1 : 0)',
        \(FPColumn.sectionMappingValue)= '\(item.sectionMappingValue ?? "")',
        \(FPColumn.sectionOptions)= '\(item.sectionOptions?.getJson() ?? "")'
        WHERE
        \(FPColumn.sqliteId)=\(sqliteId)
        """
        return updateQuery
    }
    
    func getUpdateQueryByObjectId(_ remoteId: Int, _ item: FPSectionDetails, sectionDelta:Bool = false) -> String {
        var updateQuery = self.getUpdateQuery()
        
        if sectionDelta{
            var strLocalUpdatedAt:String = "NULL"
            if let value = item.locallyUpdatedAt {
                strLocalUpdatedAt = value
            }
            
            var strUpdatedAt:String = "NULL"
            if let value = item.updatedAt {
                strUpdatedAt = value
            }
            
            updateQuery += """
            \(FPColumn.locallyUpdatedAt)= '\(strLocalUpdatedAt)',
            \(FPColumn.updatedAt)= '\(strUpdatedAt)'
            WHERE
            \(FPColumn.id)=\(remoteId)
            """
            return updateQuery
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
       
        if let value = item.moduleId {
            updateQuery += "\(FPColumn.moduleId)=\(value),"
        }else {
            updateQuery += "\(FPColumn.moduleId)= NULL,"
        }
        if let value = item.sortPosition {
            updateQuery += "\(FPColumn.sortPosition)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.sortPosition)= NULL,"
        }
        
        if let value = item.moduleEntityId {
            updateQuery += "\(FPColumn.moduleEntityId)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.moduleEntityId)= NULL,"
        }
        
        if let value = item.moduleEntityLocalId {
            updateQuery += "\(FPColumn.moduleEntityLocalId)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.moduleEntityLocalId)= NULL,"
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
        
        updateQuery += """
        \(FPColumn.showSummary)= '\(item.showSummary ? 1 : 0)',
        \(FPColumn.showDisplayName)= '\(item.showDisplayName ? 1 : 0)',
        \(FPColumn.isSyncedToServer)= '\(item.isSyncedToServer ? 1 : 0)',
        \(FPColumn.isActive)= '\(item.isActive ? 1 : 0)',
        \(FPColumn.isDeleted)= '\(item.isDeleted ? 1 : 0)',
        \(FPColumn.isHidden)= '\(item.isHidden ? 1 : 0)',
        \(FPColumn.sectionMappingValue)= '\(item.sectionMappingValue ?? "")',
        \(FPColumn.sectionOptions)= '\(item.sectionOptions?.getJson() ?? "")'
        WHERE
        \(FPColumn.id)=\(remoteId)
        """
        return updateQuery
    }
    
    func xupdateSectionDetails(_ item: FPSectionDetails, isWriteByLocalId:Bool = true, sectionDelta:Bool = false) {
        if isWriteByLocalId, let localId = item.sqliteId as? Int {
            FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([self.getUpdateQuery(localId, item)], dbManager: self) { success in
                if success {
                    for fieldItem in item.fields {
                        FPFieldDetailsDatabaseManager().updateFieldDetails(fieldItem)
                    }
                }
            }
        }else{
            if let remoteId = item.objectId {
                FPLocalDatabaseManager.shared.executeQuery(self.getFetchByIdQuery(id: remoteId), dbManager: self) { results in
                    if let result = results.first, let resultSqliteId = result["sqliteId"], let sqliteIdInNum = FPUtility.getNumberValue(resultSqliteId) {
                        item.sqliteId = sqliteIdInNum
                        self.updateSectionDetailsByRemoteId(item, remoteId: remoteId, sectionDelta: sectionDelta) { _ in }
                    }else {
                        // insert
                        self.insertSectionDetails([item], item.moduleEntityLocalId ?? 0){ _ in}
                    }
                }
            }
        }
    }
      
    func updateSectionDetailsByRemoteId(_ item: FPSectionDetails, remoteId: NSNumber, sectionDelta:Bool = false, completionHandler: @escaping (_ success: Bool) -> Void) {
        FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([self.getUpdateQueryByObjectId(remoteId.intValue, item, sectionDelta: sectionDelta)], dbManager: self) { success in
            if success {
                for fieldItem in item.fields {
                    FPFieldDetailsDatabaseManager().updateFieldDetails(fieldItem)
                }
            }
        }
        
    }
    
    func updateSectionDetails(_ item: FPSectionDetails) {
        if let id = item.sqliteId as? Int {
            FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([self.getUpdateQuery(id, item)], dbManager: self) { success in
                if success {
                    for fieldItem in item.fields {
                        FPFieldDetailsDatabaseManager().updateFieldDetails(fieldItem)
                    }
                }
            }
        }
    }

    /// Completion-based variant: fires only after section record AND all field records are committed.
    func updateSectionDetails(_ item: FPSectionDetails, completion: @escaping (_ success: Bool) -> Void) {
        guard let id = item.sqliteId as? Int else { completion(false); return }
        FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([self.getUpdateQuery(id, item)], dbManager: self) { success in
            guard success else { completion(false); return }
            let group = DispatchGroup()
            for fieldItem in item.fields {
                group.enter()
                FPFieldDetailsDatabaseManager().updateFieldDetails(fieldItem) { group.leave() }
            }
            group.notify(queue: .global(qos: .userInitiated)) {
                completion(true)
            }
        }
    }
    
    func updateScannerSortPositionToDB(_ item: FPSectionDetails) {
        if let id = item.objectId?.intValue, let sort = item.sortPosition {
            let query = "UPDATE \(FPSectionDetailsDatabaseManager.getTableName()) SET \(FPColumn.sortPosition) = '\(sort)' WHERE \(FPColumn.id) = \(id)"
            FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([query], dbManager: self) { _ in }
        }
    }
    
    func getDeleteQuery() -> String {
        return """
        DELETE FROM \(FPSectionDetailsDatabaseManager.getTableName())\n
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
    
    func deleteSectionDetails(for sqlitId: NSNumber) {
        FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([self.getDeleteQuery(for: sqlitId)], dbManager: self)
    }
    
    func getFetchBySqLiteIdQuery(sqliteId: NSNumber?) -> String {
        return """
        SELECT * FROM \(FPSectionDetailsDatabaseManager.getTableName())
        WHERE
        \(FPColumn.sqliteId) = \(sqliteId ?? 0)
        """
    }
    
    func deleteScannedNotSavedSection(for sqlitId: NSNumber) {
        FPLocalDatabaseManager.shared.executeQuery(self.getFetchBySqLiteIdQuery(sqliteId: sqlitId), dbManager: self,  completionHandler: { results in
            if let item = results.first {
                let localSection = FPSectionDetails(json: item, isForLocal: false)
                if let id = localSection.sqliteId {
                    localSection.fields = FPFieldDetailsDatabaseManager().fetchFieldDetails(for: id, FPFormMduleId)
                }
                deleteSectionDetails(forArray: [localSection])
            }
        })
    }
    
    func deleteSectionDetails(forArray sections: [FPSectionDetails]) {
        var sqliteIdArray = [String]()
        for item in sections {
            FPFieldDetailsDatabaseManager().deleteFieldDetails(forArray: item.fields)
            if let id = item.sqliteId {
                sqliteIdArray.append("\(id)")
            }
        }
        if sqliteIdArray.count > 0 {
            FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([self.getDeleteQuery(for: sqliteIdArray.joined(separator: ","))], dbManager: self)
        }
    }
}
