//
//  FPSectionDetailsTemplateDatabaseManager.swift
//  crm
//
//  Created by Apple on 07/01/21.
//  Copyright © 2021 SmartServ. All rights reserved.
//

import Foundation
struct FPSectionDetailsTemplateDatabaseManager: FPDataBaseQueries {
    typealias successCompletionHandler = (_ success: Bool)->()
    typealias completionHandler = ()->()

    func getDeleteQuery() -> String {
        return "DELETE FROM \(FPSectionDetailsTemplateDatabaseManager.getTableName())\n"
    }
    
    var fpLoggerModal: FPLoggerModal? {
        let ddLoggerModal = FPLoggerModal()
        return ddLoggerModal
    }
    
    static func getTableName() -> String {
        return FPTableName.sectionDetailsTemplate
    }
    
    static func getCreateQuery() -> String {
        return """
        CREATE TABLE IF NOT EXISTS \(self.getTableName()) (
        \(FPColumn.sqliteId)                      \(FPDataTypes.integer) PRIMARY KEY AUTOINCREMENT,
        \(FPColumn.id)                            \(FPDataTypes.var100) UNIQUE,
        \(FPColumn.name)                          \(FPDataTypes.var100),
        \(FPColumn.displayName)                   \(FPDataTypes.var100),
        \(FPColumn.showSummary)                   \(FPDataTypes.bool0),
        \(FPColumn.showDisplayName)               \(FPDataTypes.bool1),
        \(FPColumn.moduleId)                      \(FPDataTypes.var100),
        \(FPColumn.moduleEntityId)                \(FPDataTypes.var100),
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
            CREATE INDEX IF NOT EXISTS idx_template_sections_entity 
            ON \(FPSectionDetailsTemplateDatabaseManager.getTableName())(\(FPColumn.moduleEntityId), \(FPColumn.isActive), \(FPColumn.isDeleted), \(FPColumn.sortPosition))
            """
        ]
    }
    
    func getDeleteQuery(_ moduleEntityId:String) -> String {
        return """
        \(self.getDeleteQuery())
        WHERE \(FPColumn.moduleEntityId) = '\(moduleEntityId)'
        """
    }
    func getLastInsertQuery() -> String {
        return ""
    }
    func getInsertQuery() -> String {
        return """
        INSERT INTO \(FPSectionDetailsTemplateDatabaseManager.getTableName()) (
        """
    }
    func getInsertBaseQuery(_ item: FPSectionDetails) -> String {
        var insertQuery = self.getInsertQuery()
        if item.objectStringId != nil {
            insertQuery += "\(FPColumn.id),"
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
        if item.moduleEntityStringId != nil {
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
    
    func getInsertQuery(for item: FPSectionDetails) -> String {
        var insertQuery = self.getInsertBaseQuery(item)
        if let value = item.objectStringId  {
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
        if let value = item.moduleEntityStringId {
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
        '\(item.showSummary ? 1 : 0)',
        '\(item.showDisplayName ? 1 : 0)',
        '\(item.isActive ? 1 : 0)',
        '\(item.isDeleted ? 1 : 0)',
        '\(item.isSyncedToServer ? 1 : 0)',
        '\(item.isHidden ? 1 : 0)',
        '\(item.sectionMappingValue ?? "")',
        '\(item.sectionOptions?.getJson() ?? "")'        
        )
        ON CONFLICT(\(FPColumn.id)) DO UPDATE SET
        \(FPColumn.name) = excluded.\(FPColumn.name),
        \(FPColumn.displayName) = excluded.\(FPColumn.displayName),
        \(FPColumn.showSummary) = excluded.\(FPColumn.showSummary),
        \(FPColumn.showDisplayName) = excluded.\(FPColumn.showDisplayName),
        \(FPColumn.moduleId) = excluded.\(FPColumn.moduleId),
        \(FPColumn.moduleEntityId) = excluded.\(FPColumn.moduleEntityId),
        \(FPColumn.sortPosition) = excluded.\(FPColumn.sortPosition),
        \(FPColumn.isDeleted) = excluded.\(FPColumn.isDeleted),
        \(FPColumn.isActive) = excluded.\(FPColumn.isActive),
        \(FPColumn.createdAt) = excluded.\(FPColumn.createdAt),
        \(FPColumn.updatedAt) = excluded.\(FPColumn.updatedAt),
        \(FPColumn.locallyUpdatedAt) = excluded.\(FPColumn.locallyUpdatedAt),
        \(FPColumn.isSyncedToServer) = excluded.\(FPColumn.isSyncedToServer),
        \(FPColumn.isHidden) = excluded.\(FPColumn.isHidden),
        \(FPColumn.sectionMappingValue) = excluded.\(FPColumn.sectionMappingValue),
        \(FPColumn.options) = excluded.\(FPColumn.options)
        """
        return insertQuery
    }
    func insertSectionDetails(_ sectionDetails: [FPSectionDetails], _ moduleEntityId: String, completion: @escaping completionHandler) {
        for item in sectionDetails {
            FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([self.getInsertQuery(for: item)], dbManager: self) { success in
                if success, let sectionId = item.objectStringId {
                    FPFieldDetailsTemplateDatabaseManager().insertFieldDetails(item.fields, sectionId) {}
                }
            }
        }
        completion()
    }
    func updateSectionDetail(_ sectionDetail: FPSectionDetails, completion: @escaping successCompletionHandler) {
        FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([self.getUpdateQuery(item: sectionDetail)], dbManager: self) { success in
            for item in sectionDetail.fields {
                FPFieldDetailsTemplateDatabaseManager().updateFieldDetail(item) { success in
                }
            }
            completion(success)
        }
    }
    func getDeleteQuery(for moduleEntityId: String) -> String {
        var deleteQuery = self.getDeleteQuery()
        deleteQuery += """
        
        WHERE
        \(FPColumn.moduleEntityId) = '\(moduleEntityId)'
        """
        return deleteQuery
    }
    func deleteSectionFor(sections: [FPSectionDetails], moduleEntityId: String, completionHandler: @escaping successCompletionHandler) {
        for item in sections {
            FPFieldDetailsTemplateDatabaseManager().deleteFieldDetailFor(sectionId: item.objectStringId!) { success in }
        }
        FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([self.getDeleteQuery(for:moduleEntityId)], dbManager: self) { success in
            completionHandler(success)
        }
    }
    func deleteSectionFor(moduleEntityId: String, completionHandler: @escaping successCompletionHandler) {
        let localSectionObjectIds = FPSectionDetailsTemplateDatabaseManager().fetchSectionDetailsObjectIds(for: moduleEntityId)
        FPFieldDetailsTemplateDatabaseManager().deleteFieldDetailFor(sectionIds: localSectionObjectIds) { success in
            FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([self.getDeleteQuery(for:moduleEntityId)], dbManager: self) { success in
                completionHandler(success)
            }
        }
    }
    func fetchSectionDetails(for moduleEntityId: String) -> [FPSectionDetails] {
        var array = [FPSectionDetails]()
        FPLocalDatabaseManager.shared.executeQuery(self.getFetchQuery(moduleEntityId), dbManager: self, completionHandler: { results in
            for dict in results {
                let item = FPSectionDetails(json: dict, isForLocal: false)
                if let id = item.objectStringId {
                    item.fields = FPFieldDetailsTemplateDatabaseManager().fetchFieldDetails(for: id)
                }
                array.append(item)
            }
        })
        return array
    }
    
    // Optimized batch fetch for multiple templates
    func fetchSectionDetailsForTemplates(templateIds: [String], completion: @escaping ([String: [FPSectionDetails]]) -> Void) {
        guard !templateIds.isEmpty else {
            completion([:])
            return
        }
        
        let idsString = templateIds.map { "'\($0)'" }.joined(separator: ",")
        let batchQuery = """
        SELECT * FROM \(FPSectionDetailsTemplateDatabaseManager.getTableName())
        WHERE \(FPColumn.moduleEntityId) IN (\(idsString))
        AND \(FPColumn.isActive) = 1
        AND \(FPColumn.isDeleted) = 0
        ORDER BY \(FPColumn.moduleEntityId), \(FPColumn.sortPosition) ASC
        """
        
        FPLocalDatabaseManager.shared.executeQuery(batchQuery, dbManager: self) { results in
            var sectionsDict = [String: [FPSectionDetails]]()
            var sectionObjectIds = [String]()
            var sectionIdMap = [String: FPSectionDetails]()
            
            // Step 1: Parse all sections and collect IDs
            for dict in results {
                let section = FPSectionDetails(json: dict, isForLocal: false)
                section.fields = [] // Initialize empty fields array
                
                if let sectionId = section.objectStringId {
                    sectionObjectIds.append(sectionId)
                    sectionIdMap[sectionId] = section
                }
                
                // Group by template ID
                if let templateId = section.moduleEntityStringId {
                    if sectionsDict[templateId] == nil {
                        sectionsDict[templateId] = []
                    }
                    sectionsDict[templateId]?.append(section)
                }
            }
            
            guard !sectionObjectIds.isEmpty else {
                completion(sectionsDict)
                return
            }
            
            // Step 2: Fetch ALL template fields in ONE batch query
            FPFieldDetailsTemplateDatabaseManager().fetchFieldDetailsForSections(sectionIds: sectionObjectIds) { fieldsDict in
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
    func fetchSectionDetailsObjectIds(for moduleEntityId: String) -> [String] {
        var array = [String]()
        FPLocalDatabaseManager.shared.executeQuery(self.getFetchAllQuery(moduleEntityId), dbManager: self, completionHandler: { results in
            for item in results {
                if let id = item["\(FPColumn.id)"] as? String {
                    array.append("'\(id)'")
                }
            }
        })
        return array
    }
    func getFetchQuery(_ moduleEntityId:String) -> String {
        return """
        SELECT * FROM \(FPSectionDetailsTemplateDatabaseManager.getTableName())
        WHERE \(FPColumn.moduleEntityId) = '\(moduleEntityId)' AND
        \(FPColumn.isActive) = 1 AND
        \(FPColumn.isDeleted) = 0
        """
    }
    func getFetchAllQuery(_ moduleEntityId:String) -> String {
        return """
        SELECT * FROM \(FPSectionDetailsTemplateDatabaseManager.getTableName())
        WHERE \(FPColumn.moduleEntityId) = '\(moduleEntityId)'
        """
    }
    func getUpdateQuery() -> String {
        return """
        UPDATE \(FPSectionDetailsTemplateDatabaseManager.getTableName())
        SET
        
        """
    }
    func getUpdateQuery(item: FPSectionDetails) -> String {
        var updateQuery = self.getUpdateQuery()
        
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
            updateQuery += "\(FPColumn.moduleId)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.moduleId)= NULL,"
        }
        
        if let value = item.moduleEntityStringId {
            updateQuery += "\(FPColumn.moduleEntityId)='\(value)',"
        }else {
            updateQuery += "\(FPColumn.moduleEntityId)= NULL,"
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
        \(FPColumn.isActive)='\(item.isActive ? 1 : 0)',
        \(FPColumn.isDeleted)='\(item.isDeleted ? 1 : 0)',
        \(FPColumn.showSummary)= '\(item.showSummary ? 1 : 0)',
        \(FPColumn.showDisplayName)= '\(item.showDisplayName ? 1 : 0)',
        \(FPColumn.isSyncedToServer)='\(item.isSyncedToServer ? 1 : 0)',
        \(FPColumn.isHidden)= '\(item.isHidden ? 1 : 0)',
        \(FPColumn.sectionMappingValue)= '\(item.sectionMappingValue ?? "")',
        \(FPColumn.sectionOptions)= '\(item.sectionOptions?.getJson() ?? "")'
        WHERE
        \(FPColumn.id)= '\(item.objectStringId ?? "0")'
        """
        return updateQuery
    }
    func getFetchSqliteIdsQuery(for moduleEntityIdCSV: String) -> String {
        
        return """
        SELECT  \(FPColumn.id)  FROM \(FPSectionDetailsTemplateDatabaseManager.getTableName())
        
        WHERE
            \(FPColumn.moduleEntityId) IN (\(moduleEntityIdCSV))
        """
    }
    func fetchEquipmentSectionIds(for moduleEntityIdCSV: String) -> String {
        var csv = ""
        FPLocalDatabaseManager.shared.executeQuery(self.getFetchSqliteIdsQuery(for: moduleEntityIdCSV), dbManager: self, completionHandler: { results in
            if results.count > 0 {
                let idArray = results.map { item in
                    return "'\(item[FPColumn.id] ?? "")'"
                }
                csv = idArray.joined(separator: ",")
            }
        })
        return csv
    }
    func deleteSectionDetails(for moduleEntityIdCSV: String) {
        let equipmentSectionIds = self.fetchEquipmentSectionIds(for: moduleEntityIdCSV)
        FPFieldDetailsTemplateDatabaseManager().deleteFeildDetails(for: equipmentSectionIds)
        FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([self.getDeleteModuleEntityIdCSVQuery(for: moduleEntityIdCSV)], dbManager: self)
    }
    func getDeleteModuleEntityIdCSVQuery(for moduleEntityIdCSV: String) -> String {
        var deleteQuery = self.getDeleteQuery()
        deleteQuery += """
        
        WHERE
        \(FPColumn.moduleEntityId) IN (\(moduleEntityIdCSV))
        """
        return deleteQuery
    }
}
