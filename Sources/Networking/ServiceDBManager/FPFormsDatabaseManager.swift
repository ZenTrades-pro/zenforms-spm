//
//  FPFormsDatabaseManager.swift
//  crm
//
//  Created by SmartServ-Shristi on 7/14/20.
//  Copyright © 2020 SmartServ. All rights reserved.
//

import Foundation


struct FPFormsDatabaseManager : FPDataBaseQueries {
//    typealias completionHandler = () -> ()
    typealias successCompletionHandler = (_ success: Bool) -> ()
    typealias fetchFormsCompletionHandler = (_ forms: [FPForms]?) -> ()
    typealias fetchFormCompletionHandler = (_ form: FPForms?) -> ()
    typealias FormCompletionHandler = (_ form: FPForms?,_ success: Bool ) -> ()

    var fpLoggerModal: FPLoggerModal? {
        let fpLoggerModal = FPLoggerModal()
        fpLoggerModal.loggerName = FPLoggerNames.customForms
        return fpLoggerModal
    }
    static func getTableName() -> String {
        return FPTableName.form
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
        CREATE TABLE IF NOT EXISTS \(FPFormsDatabaseManager.getTableName()) (
        \(FPColumn.sqliteId)              \(FPDataTypes.integer) PRIMARY KEY AUTOINCREMENT,
        \(FPColumn.id)                    \(FPDataTypes.text) UNIQUE,
        \(FPColumn.localClientId)         \(FPDataTypes.text),
        \(FPColumn.locallyUpdatedAt)      \(FPDataTypes.date),
        \(FPColumn.createdAt)             \(FPDataTypes.date),
        \(FPColumn.updatedAt)             \(FPDataTypes.date),
        \(FPColumn.isSyncedToServer)      \(FPDataTypes.bool0),
        \(FPColumn.isTemplate)            \(FPDataTypes.bool1),
        \(FPColumn.parentTicketId)        \(FPDataTypes.text),
        \(FPColumn.name)                  \(FPDataTypes.text),
        \(FPColumn.displayName)           \(FPDataTypes.text),
        \(FPColumn.notes)                  \(FPDataTypes.text),
        \(FPColumn.downloadStatus)         \(FPDataTypes.text),
        \(FPColumn.downloadURL)            \(FPDataTypes.text),
        \(FPColumn.deletedSections)        \(FPDataTypes.text),
        \(FPColumn.companyId)             \(FPDataTypes.text),
        \(FPColumn.fileId)                \(FPDataTypes.text) DEFAULT '',
        \(FPColumn.templateId)            \(FPDataTypes.text),
        \(FPColumn.equipmentId)           \(FPDataTypes.integer),
        \(FPColumn.isActive)        \(FPDataTypes.bool1),
        \(FPColumn.isDeleted)        \(FPDataTypes.bool0),
        \(FPColumn.localFileId)           \(FPDataTypes.text),
        \(FPColumn.moduleId)              \(FPDataTypes.integer),
        \(FPColumn.isAnalysed)    \(FPDataTypes.bool0),
        \(FPColumn.signedAt)      \(FPDataTypes.integer),
        \(FPColumn.isSigned)    \(FPDataTypes.bool0)
        );
        """
    }
    
    // Create indexes for optimized query performance
    static func getCreateIndexQueries() -> [String] {
        return [
            """
            CREATE INDEX IF NOT EXISTS idx_forms_ticket_module 
            ON \(FPFormsDatabaseManager.getTableName())(\(FPColumn.parentTicketId), \(FPColumn.moduleId), \(FPColumn.isDeleted), \(FPColumn.companyId))
            """,
            """
            CREATE INDEX IF NOT EXISTS idx_forms_objectid 
            ON \(FPFormsDatabaseManager.getTableName())(\(FPColumn.id), \(FPColumn.companyId))
            """
        ]
    }
    
    func getDeleteQuery() -> String {
        return """
        DELETE FROM \(FPFormsDatabaseManager.getTableName())\n
        """
    }
    func getDeleteQuery(ticketId: NSNumber) -> String {
        var deleteQuery = self.getDeleteQuery()
        
        deleteQuery += """
        WHERE \(FPColumn.parentTicketId) = \(ticketId) AND
        \(FPColumn.isSyncedToServer) = 1
        """
        return deleteQuery
    }
    func getDeleteQuery(ticketId: NSNumber, moduleId: Int, isTemplate: Bool) -> String {
        var deleteQuery = self.getDeleteQuery()
        
        deleteQuery += """
        WHERE \(FPColumn.parentTicketId) = \(ticketId) AND
        \(FPColumn.isSyncedToServer) = 1 AND
        \(FPColumn.moduleId) = \(moduleId) AND
        \(FPColumn.isTemplate) = \(isTemplate)
        """
        return deleteQuery
    }
   
    
    func getFetchQuery(_ moduleEntityLocalId:NSNumber, _ moduleId: Int) -> String {
        return """
        SELECT * FROM \(FPSectionDetailsDatabaseManager.getTableName())
        WHERE \(FPColumn.moduleEntityLocalId) = \(moduleEntityLocalId) AND
        \(FPColumn.moduleId) = \(moduleId)
        """
    }
   
    func getDeleteFormByIdFromLocal(sqliteId: NSNumber) -> String {
        var deleteQuery = self.getDeleteQuery()
        
        deleteQuery += """
        WHERE
        \(FPColumn.sqliteId) = \(sqliteId)
        """
        
        return deleteQuery
    }
    
    func getDeleteFormBy(objectId: String) -> String {
        var deleteQuery = self.getDeleteQuery()
        
        deleteQuery += """
        WHERE
        \(FPColumn.id) = \(objectId)
        """
        
        return deleteQuery
    }
    
    func getInsertQuery() -> String {
        return """
        INSERT INTO \(FPFormsDatabaseManager.getTableName()) (
        """
    }
    func getInsertBaseQuery(form: FPForms, ticketId: NSNumber, moduleId: Int) -> String {
        var insertQuery = self.getInsertQuery()
        
        if !FPUtility.isObjectEmpty(form.objectId) {
            insertQuery += "\(FPColumn.id),"
        }
        if !FPUtility.isObjectEmpty(form.localClientId) {
            insertQuery += "\(FPColumn.localClientId),"
        }
        if !FPUtility.isObjectEmpty(form.locallyUpdatedAt) {
            insertQuery += "\(FPColumn.locallyUpdatedAt),"
        }
        if !FPUtility.isObjectEmpty(form.createdAt) {
            insertQuery += "\(FPColumn.createdAt),"
        }
        if !FPUtility.isObjectEmpty(form.updatedAt) {
            insertQuery += "\(FPColumn.updatedAt),"
        }
        
        if !FPUtility.isObjectEmpty(form.signedAt) {
            insertQuery += "\(FPColumn.signedAt),"
        }
        if !FPUtility.isObjectEmpty(form.name) {
            insertQuery += "\(FPColumn.name),"
        }
        
        if !FPUtility.isObjectEmpty(form.displayName) {
            insertQuery += "\(FPColumn.displayName),"
        }
        if !FPUtility.isObjectEmpty(form.notes) {
            insertQuery += "\(FPColumn.notes),"
        }
        insertQuery += "\(FPColumn.downloadStatus),"
        insertQuery += "\(FPColumn.downloadURL),"
        insertQuery += "\(FPColumn.deletedSections),"

        if !FPUtility.isObjectEmpty(form.companyId) {
            insertQuery += "\(FPColumn.companyId),"
        }
        
        if !FPUtility.isObjectEmpty(form.templateId) {
            insertQuery += "\(FPColumn.templateId),"
        }
       
        insertQuery += "\(FPColumn.isSigned),"
        insertQuery += "\(FPColumn.isAnalysed),"
        insertQuery += "\(FPColumn.isSyncedToServer),"
        insertQuery += "\(FPColumn.isTemplate),"
        insertQuery += "\(FPColumn.isActive),"
        insertQuery += "\(FPColumn.isDeleted),"
        insertQuery += "\(FPColumn.moduleId),"
        insertQuery += "\(FPColumn.parentTicketId)"
        
        insertQuery += """
        )
        VALUES
        (
        """
        
        return insertQuery
    }
    func getInsertQuery(form: FPForms, ticketId: NSNumber, moduleId: Int) -> String {
        var insertQuery = self.getInsertBaseQuery(form: form, ticketId: ticketId, moduleId: moduleId)
        
        if let objectId = form.objectId {
            insertQuery += "'\(objectId)',"
        }
        if let localClientId = form.localClientId {
            insertQuery += "'\(localClientId)',"
        }
        if let localLastUpdatedAt = form.locallyUpdatedAt {
            insertQuery += "'\(localLastUpdatedAt)',"
        }
        if let createdAt = form.createdAt {
            insertQuery += "'\(createdAt)',"
        }
        if let updatedAt = form.updatedAt {
            insertQuery += "'\(updatedAt)',"
        }
        if let signedAt = form.signedAt {
            insertQuery += "'\(signedAt)',"
        }
        if let name = FPUtility.getSQLiteCompatibleStringValue(form.name, isForLocal: true) {
            insertQuery += "'\(name)',"
        }
        if let displayName = FPUtility.getSQLiteCompatibleStringValue(form.displayName, isForLocal: true) {
            insertQuery += "'\(displayName)',"
        }
        if let notes = FPUtility.getSQLiteCompatibleStringValue(form.notes, isForLocal: true) {
            insertQuery += "'\(notes)',"
        }
        insertQuery += "'\(form.downloadStatus ?? "")',"
        insertQuery += "'\(form.downloadURL ?? "")',"
        insertQuery += "'\(form.deletedSections ?? "")',"

        if let companyId = form.companyId {
            insertQuery += "'\(companyId)',"
        }
        
        if let templateId = form.templateId {
            insertQuery += "'\(templateId)',"
        }
        
        insertQuery += "'\(form.isSigned ?? false ? 1:0)',"
        insertQuery += "'\(form.isAnalysed ?? false ? 1:0)',"
        insertQuery += "'\(form.isSyncedToServer ?? false ? 1:0)',"
        insertQuery += "'\(form.isTemplate ?? false ? 1:0)',"
        insertQuery += "'\(form.isActive ?? false ? 1:0)',"
        insertQuery += "'\(form.isDeleted ?? false ? 1:0)',"
        insertQuery += "\(moduleId),"
        insertQuery += "'\(ticketId)'"
        insertQuery += """
        )
        """
        
        return insertQuery
    }
    func getLastInsertQuery() -> String {
        return """
        SELECT MAX(\(FPColumn.sqliteId)) as lastInsertedId FROM \(FPFormsDatabaseManager.getTableName())
        """
    }
    
    func getUpdateQuery() -> String {
        return """
        UPDATE \(FPFormsDatabaseManager.getTableName())
        SET
        
        """
    }
    func getUpdateBaseQuery(form: FPForms, ticketId: NSNumber, moduleId: Int, sectionDelta:Bool = false) -> String {
        var updateQuery = self.getUpdateQuery()
        
        if let localLastUpdatedAt = form.locallyUpdatedAt {
            updateQuery += "\(FPColumn.locallyUpdatedAt)='\(localLastUpdatedAt)',"
        }
        if let updatedAt = form.updatedAt {
            updateQuery += "\(FPColumn.updatedAt)='\(updatedAt)',"
        }
        if let signedAt = form.signedAt {
            updateQuery += "\(FPColumn.signedAt)='\(signedAt)',"
        }
        if let name = FPUtility.getSQLiteCompatibleStringValue(form.name, isForLocal: true) {
            updateQuery += "\(FPColumn.name)='\(name)',"
        }
        if let displayName = FPUtility.getSQLiteCompatibleStringValue(form.displayName, isForLocal: true) {
            updateQuery += "\(FPColumn.displayName)='\(displayName)',"
        }
        if let notes = FPUtility.getSQLiteCompatibleStringValue(form.notes, isForLocal: true) {
            updateQuery += "\(FPColumn.notes)='\(notes)',"
        }
        updateQuery += "\(FPColumn.downloadStatus)='\(form.downloadStatus ?? "")',"
        updateQuery += "\(FPColumn.downloadURL)='\(form.downloadURL ?? "")',"
        updateQuery += "\(FPColumn.deletedSections)='\(form.deletedSections ?? "")',"

        if let objectId = form.objectId {
            updateQuery += "\(FPColumn.id)='\(objectId)',"
        }
        
        if let localClientId = form.localClientId {
            updateQuery += "\(FPColumn.localClientId)='\(localClientId)',"
        }
        
        if let templateId = form.templateId {
            updateQuery += "\(FPColumn.templateId)='\(templateId)',"
        }
       
        updateQuery += "\(FPColumn.isSigned)='\(form.isSigned ?? false ? 1:0)',"
        updateQuery += "\(FPColumn.isAnalysed)='\(form.isAnalysed ?? false ? 1:0)',"
        if !sectionDelta{
            updateQuery += "\(FPColumn.isSyncedToServer)='\(form.isSyncedToServer ?? false ? 1:0)',"
        }
        updateQuery += "\(FPColumn.parentTicketId)='\(ticketId)',"
        updateQuery += "\(FPColumn.isActive)='\(form.isActive ?? false ? 1 : 0)',"
        updateQuery += "\(FPColumn.isDeleted)='\(form.isDeleted ?? false ? 1 : 0)',"
        updateQuery += "\(FPColumn.isTemplate)='\(form.isTemplate ?? false ? 1 : 0)',"
        updateQuery += "\(FPColumn.moduleId)=\(moduleId)"
        return updateQuery
    }
    func getUpdateQuery(form: FPForms, sqliteId:NSNumber, ticketId: NSNumber, moduleId: Int, sectionDelta:Bool = false) -> String {
        var updateQuery = self.getUpdateBaseQuery(form: form, ticketId: ticketId, moduleId: moduleId, sectionDelta: sectionDelta)
        updateQuery += """
         WHERE
         \(FPColumn.sqliteId)=\(sqliteId)
        """
        return updateQuery
    }
    
    func getUpdateQuery(form: FPForms, objectId:String, ticketId: NSNumber, moduleId: Int, sectionDelta:Bool = false) -> String {
        var updateQuery = self.getUpdateBaseQuery(form: form, ticketId: ticketId, moduleId: moduleId, sectionDelta: sectionDelta)
        updateQuery += """
         WHERE
        \(FPColumn.id)='\(objectId)'
        """
        return updateQuery
    }
    
    func getFetchQuery() -> String {
        return """
        SELECT * FROM \(FPFormsDatabaseManager.getTableName())\n
        """
    }
    
    func getFetchTemplateQuery(moduleId: Int) -> String {
        var fetchQuery = self.getFetchQuery()
        fetchQuery += """
        WHERE
        \(FPColumn.isTemplate) = 1 AND
        \(FPColumn.isActive) = 1 AND
        \(FPColumn.isDeleted) = 0 AND
        \(FPColumn.moduleId) = \(moduleId) AND
        \(FPColumn.companyId) = \(companyId)
        """
        return fetchQuery
    }
    
    func getFetchQuery(ticketId: NSNumber, moduleId: Int) -> String {
        var fetchQuery = getFetchQuery()
        fetchQuery += """
        WHERE
        \(FPColumn.parentTicketId) = \(ticketId) AND
        \(FPColumn.moduleId) = \(moduleId) AND
        \(FPColumn.companyId) = \(companyId) AND
        \(FPColumn.isDeleted) = 0
        ORDER BY \(FPColumn.createdAt) DESC
        """
        return fetchQuery
    }
    
   
    func getFetchFormBy(objectId: String) -> String {
        var fetchQuery = self.getFetchQuery()
        fetchQuery += """
        WHERE
        \(FPColumn.id) = '\(objectId)' AND
        \(FPColumn.companyId) = \(companyId)
        """
        return fetchQuery
    }
    func getFetchFormBy(sqliteId: NSNumber) -> String {
        var fetchQuery = self.getFetchQuery()
        fetchQuery += """
        WHERE
        \(FPColumn.sqliteId) = \(sqliteId) AND
        \(FPColumn.companyId) = \(companyId)
        """
        return fetchQuery
    }
   
    func upsertForms(forms: [FPForms], moduleId: Int, ticketId:NSNumber, completion: @escaping (() -> ())) {
        let group = DispatchGroup()
        for form in forms {
            group.enter()
            self.upsert(form: form, ticketId: ticketId, moduleId: moduleId) { _ , success in
                group.leave()
            }
        }
        group.notify(queue: .main) {
            completion()
        }
    }
    func upsertFormsByObjectId(forms: [FPForms], moduleId: Int, ticketId:NSNumber, completion: @escaping (() -> ())) {
        let group = DispatchGroup()
        for form in forms {
            group.enter()
            self.upsertByObjectId(form: form, moduleId: moduleId, ticketId: ticketId) { success in
                group.leave()
            }
        }
        group.notify(queue: .main) {
            completion()
        }
    }
    func upsertByObjectId(form: FPForms, moduleId: Int, ticketId:NSNumber, completion: @escaping ((Bool) -> ())) {
        if let objectId = form.objectId {
            self.fetchFormBy(objectId: objectId, moduleId: moduleId, shouldIncludeMedia: true, completion: { result in
                if let result = result {
                    if result.isSyncedToServer ?? false {
                        self.updateForm(form: form, ticketId: ticketId, moduleId: moduleId, shouldUpdateBySqliteId: false, completion: { _ , success in
                            completion(success)
                        })
                    }else {
                     completion(false)
                    }
                }else {
                    self.insertForm(form: form, ticketId: ticketId, moduleId: moduleId) { _ , success in
                        completion(success)
                    }
                }
            })
        }else {
            completion(false)
        }
    }
   
    func upsert(form: FPForms, ticketId: NSNumber, moduleId:Int, completion: @escaping ((_ form: FPForms?, _ success: Bool) -> ())) {
        if let _ = form.sqliteId {
            self.updateForm(form: form, ticketId: ticketId, moduleId: moduleId, shouldUpdateBySqliteId: true, completion: { dbform, success  in
                completion(dbform, success)
            })
        }else {
            self.insertForm(form: form, ticketId: ticketId, moduleId: moduleId) { dbform, success  in
                completion(dbform, success)
            }
        }
    }
    
    /**
     This function is used to update partial section of form only
    */
    func upsertForPartialSave(section: FPSectionDetails, ticketId: NSNumber, moduleId:Int, completion: @escaping ((Bool) -> ())) {
        self.updatePartialFormSection(section: section, ticketId: ticketId, moduleId: moduleId) { success in
            completion(success)
        }
    }

    func insertForm(form: FPForms, ticketId: NSNumber, moduleId: Int, serviceAddressId:Int? = nil, completion: @escaping FormCompletionHandler) {
        let dbform = form
        FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([self.getInsertQuery(form: form, ticketId: ticketId, moduleId: moduleId)], dbManager: self) { success in
            if success {
                FPLocalDatabaseManager.shared.executeQuery(self.getLastInsertQuery(), dbManager: self) { results in
                    if let result = results.first, let lastInsertedId = result["lastInsertedId"] as? NSNumber {
                        dbform.sqliteId = lastInsertedId
                        if ticketId == 0 {
                            FPSectionDetailsTemplateDatabaseManager().insertSectionDetails(dbform.sections ?? [], FPUtility.getStringValue(form.objectId) ?? "") {
                                completion(dbform, true)
                            }
                        }else {
                            FPSectionDetailsDatabaseManager().insertSectionDetails(dbform.sections ?? [], lastInsertedId, moduleId) { nsections in
                                dbform.sections = []
                                dbform.sections?.append(contentsOf: nsections)
                                completion(dbform, true)
                            }
                        }
                    } else {
                        completion(dbform, false)
                    }
                }
            } else {
                completion(dbform, success)
            }
        }
    }
    
    func updateFormName(form: FPForms, completion: @escaping (Bool) -> Void) {
        let name        = FPUtility.getSQLiteCompatibleStringValue(form.name, isForLocal: true) ?? ""
        let displayName = FPUtility.getSQLiteCompatibleStringValue(form.displayName, isForLocal: true) ?? ""
        let setClause   = "\(FPColumn.name)='\(name)', \(FPColumn.displayName)='\(displayName)'"
        let query: String
        if let sqliteId = form.sqliteId {
            query = "UPDATE \(FPFormsDatabaseManager.getTableName()) SET \(setClause) WHERE \(FPColumn.sqliteId)=\(sqliteId)"
        } else if let objectId = form.objectId {
            query = "UPDATE \(FPFormsDatabaseManager.getTableName()) SET \(setClause) WHERE \(FPColumn.id)='\(objectId)'"
        } else {
            completion(false)
            return
        }
        FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([query], dbManager: self) { completion($0) }
    }

    func updateForm(form: FPForms, ticketId: NSNumber, moduleId: Int, shouldUpdateBySqliteId: Bool, sectionDelta:Bool = false, completion: @escaping FormCompletionHandler) {
        var updateQuery = ""
        if shouldUpdateBySqliteId {
            if let sqliteId = form.sqliteId {
                updateQuery = self.getUpdateQuery(form: form, sqliteId: sqliteId, ticketId: ticketId, moduleId: moduleId, sectionDelta: sectionDelta)
            }else {
                completion(form, false)
            }
        }else {
            if let objectId = form.objectId {
                updateQuery = self.getUpdateQuery(form: form, objectId: objectId, ticketId: ticketId, moduleId: moduleId, sectionDelta: sectionDelta)
            }else {
                completion(form, false)
            }
        }
        FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([updateQuery], dbManager: self) { success in
            if success {
                if let newSections = form.sections {
                    if ticketId == 0 {
                        // we update sectionDetails by sqlite id so we directly write for sectionTemplate
                        for item in newSections {
                            if let _ = item.objectStringId{
                                FPSectionDetailsTemplateDatabaseManager().updateSectionDetail(item) {success in }
                            }
                        }
                        completion(form, success)
                    }else{
//                        for item in sections {
//                            item.moduleEntityLocalId = form.sqliteId
//                            FPSectionDetailsDatabaseManager().updateSectionDetails(item, isWriteByLocalId: shouldUpdateBySqliteId, sectionDelta: sectionDelta)
//                        }
                        
                        if sectionDelta{
                            completion(form, success)
                            return
                        }
                        
                        if shouldUpdateBySqliteId{
                            for item in newSections {
                                item.moduleEntityLocalId = form.sqliteId
                                FPSectionDetailsDatabaseManager().updateSectionDetails(item)
                            }
                            completion(form, success)
                            
                        }else{
                            let localSections = FPSectionDetailsDatabaseManager().fetchSectionDetailsOR(for: form.sqliteId ?? 0, moduleEntityId: form.objectId ?? "0", moduleId)
                            FPSectionDetailsDatabaseManager().deleteSectionDetails(forArray: localSections)
                            
                            FPSectionDetailsDatabaseManager().insertSectionDetails(newSections, form.sqliteId ?? 0) { nsections in
                                form.sections = []
                                form.sections?.append(contentsOf: nsections)
                                completion(form, success)
                            }
                        }
                    }
                } else {
                    completion(form, success)
                }
            }else {
                completion(form, success)
            }
        }
    }
    
    func updateDownloadStatus(objectId: String, downloadStatus: String, downloadURL: String?, completion: @escaping (() -> ())) {
        let query = """
            UPDATE \(FPFormsDatabaseManager.getTableName())
            SET \(FPColumn.downloadStatus)='\(downloadStatus)',
                \(FPColumn.downloadURL)='\(downloadURL ?? "")'
            WHERE \(FPColumn.id)='\(objectId)'
            """
        FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([query], dbManager: self) { _ in
            completion()
        }
    }

    func updateServerFormOnly(form: FPForms, ticketId: NSNumber, completion: @escaping FormCompletionHandler) {
        let updateQuery = self.getUpdateQuery(form: form, sqliteId: form.sqliteId ?? 0, ticketId: ticketId, moduleId: FPFormMduleId, sectionDelta: false)
        FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([updateQuery], dbManager: self) { success in
            completion(form, success)
        }
    }
    
    func markPartialFormNeedtoSync(form: FPForms, ticketId: NSNumber, moduleId: Int, shouldUpdateBySqliteId: Bool, completion: @escaping successCompletionHandler) {
        var updateQuery = ""
        if shouldUpdateBySqliteId {
            if let sqliteId = form.sqliteId {
                updateQuery = self.getUpdateQuery(form: form, sqliteId: sqliteId, ticketId: ticketId, moduleId: moduleId)
            }else {
                completion(false)
            }
        }else {
            if let objectId = form.objectId {
                updateQuery = self.getUpdateQuery(form: form, objectId: objectId, ticketId: ticketId, moduleId: moduleId)
            }else {
                completion(false)
            }
        }
        FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([updateQuery], dbManager: self) { success in
            completion(success)
        }
    }
    
    func markFormLocallySync(form: FPForms, ticketId: NSNumber, completion: @escaping ((Bool) -> ())) {
        if let sqliteId = form.sqliteId {
            let updateQuery = self.getUpdateQuery(form: form, sqliteId: sqliteId, ticketId: ticketId, moduleId: FPFormMduleId)
            FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([updateQuery], dbManager: self) { success in
                completion(success)
            }
        }else {
            completion(false)
        }
    }
    
    /**
     This function is used to update partial section of form only
    */
    func updatePartialFormSection(section: FPSectionDetails, ticketId: NSNumber, moduleId: Int, completion: @escaping successCompletionHandler) {
        FPSectionDetailsDatabaseManager().updateSectionDetails(section) { success in
            completion(success)
        }
    }
    
    func xfetchFPFormTemplatesFromLocal( completion: @escaping fetchFormsCompletionHandler) {
            FPLocalDatabaseManager.shared.executeQuery(self.getFetchTemplateQuery(moduleId: FPFormTemplateModuleId), dbManager: self) { results in
                var formsArray = [FPForms]()
                for dict in results {
                    let form = FPForms(dict: dict, isForLocal: false)
                    form.sections = [FPSectionDetails]()
                    if let strId = form.objectId{
                        let sections = FPSectionDetailsTemplateDatabaseManager().fetchSectionDetails(for: strId)
                        form.sections?.append(contentsOf: sections)
                        if let sections = form.sections, sections.count > 0 {
                            formsArray.append(form)
                        }
                    }
                }
                completion(formsArray)
            }
            
        }
    
    func fetchFPFormTemplatesFromLocal( completion: @escaping fetchFormsCompletionHandler) {
        FPLocalDatabaseManager.shared.executeQuery(self.getFetchTemplateQuery(moduleId: FPFormTemplateModuleId), dbManager: self) { results in
            // Optimized batch fetch for templates
            var formsArray = [FPForms]()
            var templateObjectIds = [String]()
            var templateIdMap = [String: FPForms]()
            
            // Step 1: Parse all templates and collect objectIds
            for dict in results {
                let form = FPForms(dict: dict, isForLocal: false)
                form.sections = []
                if let objectId = form.objectId {
                    templateObjectIds.append(objectId)
                    templateIdMap[objectId] = form
                }
            }
            
            guard !templateObjectIds.isEmpty else {
                completion([])
                return
            }
            
            // Step 2: Fetch ALL template sections in ONE batch query
            FPSectionDetailsTemplateDatabaseManager().fetchSectionDetailsForTemplates(templateIds: templateObjectIds) { sectionsDict in
                // Step 3: Assign sections to templates
                for (templateId, sections) in sectionsDict {
                    if let form = templateIdMap[templateId] {
                        form.sections = sections
                    }
                }
                
                // Step 4: Filter templates with sections and maintain order
                formsArray = templateObjectIds.compactMap { templateId in
                    guard let form = templateIdMap[templateId], (form.sections?.count ?? 0) > 0 else {
                        return nil
                    }
                    return form
                }
                
                completion(formsArray)
            }
        }
    }
 
    func xfetchFormsFromLocal(ticketId: NSNumber, moduleId: Int, completion: @escaping fetchFormsCompletionHandler) {
        FPLocalDatabaseManager.shared.executeQuery(self.getFetchQuery(ticketId: ticketId, moduleId: moduleId), dbManager: self) { results in
            var formArray = [FPForms]()
            for item in results {
                let form = FPForms(dict: item, isForLocal: false)
                 if moduleId == FPFormMduleId {
                    // for non template
                    let sections = FPSectionDetailsDatabaseManager().fetchSectionDetailsOR(for: form.sqliteId ?? 0, moduleEntityId: form.objectId ?? "0", moduleId)
                    if sections.count > 0 {
                        form.sections = sections
                        formArray.append(form)
                    }
                    
                }else if moduleId == FPFormTemplateModuleId {
                    var sections:[FPSectionDetails]?
                    if let objectId = form.objectId {
                        sections = FPSectionDetailsTemplateDatabaseManager().fetchSectionDetails(for: objectId)
                    }
                    if let sections = sections, sections.count > 0 {
                        form.sections = sections
                        formArray.append(form)
                    }
                }
            }
            completion(formArray)
        }
    }
    
    func fetchFormsFromLocal(ticketId: NSNumber, moduleId: Int, completion: @escaping fetchFormsCompletionHandler) {
        FPLocalDatabaseManager.shared.executeQuery(self.getFetchQuery(ticketId: ticketId, moduleId: moduleId), dbManager: self) { results in
            
            if moduleId == FPFormMduleId {
                // Optimized batch fetch for non-template forms
                var formArray = [FPForms]()
                var formIds = [NSNumber]()
                var formObjectIds = [String]()
                var formIdMap = [NSNumber: FPForms]()
                
                // Step 1: Parse all forms and collect both sqliteIds and objectIds
                for item in results {
                    let form = FPForms(dict: item, isForLocal: false)
                    form.sections = []
                    if let sqliteId = form.sqliteId {
                        formIds.append(sqliteId)
                        formIdMap[sqliteId] = form
                        
                        // Also collect objectId for OR query
                        if let objectId = form.objectId {
                            formObjectIds.append(objectId)
                        } else {
                            formObjectIds.append("0") // Default value if objectId is nil
                        }
                    }
                }
                
                guard !formIds.isEmpty else {
                    completion([])
                    return
                }
                
                // Step 2: Fetch ALL sections in ONE batch query (handles both sqliteId OR objectId)
                FPSectionDetailsDatabaseManager().fetchSectionDetailsForForms(formIds: formIds, formObjectIds: formObjectIds, moduleId: moduleId) { sectionsDict in
                    // Step 3: Assign sections to forms
                    for (formId, sections) in sectionsDict {
                        if let form = formIdMap[formId] {
                            form.sections = sections
                        }
                    }
                    
                    // Step 4: Filter forms with sections and maintain order
                    formArray = formIds.compactMap { formId in
                        guard let form = formIdMap[formId], (form.sections?.count ?? 0) > 0 else {
                            return nil
                        }
                        return form
                    }
                    
                    completion(formArray)
                }
                
            } else if moduleId == FPFormTemplateModuleId {
                // Template forms - keep existing logic
                var formArray = [FPForms]()
                for item in results {
                    let form = FPForms(dict: item, isForLocal: false)
                    var sections: [FPSectionDetails]?
                    if let objectId = form.objectId {
                        sections = FPSectionDetailsTemplateDatabaseManager().fetchSectionDetails(for: objectId)
                    }
                    if let sections = sections, sections.count > 0 {
                        form.sections = sections
                        formArray.append(form)
                    }
                }
                completion(formArray)
            } else {
                completion([])
            }
        }
    }
    
   
    func fetchFormBy(sqliteId: NSNumber, shouldIncludeMedia: Bool, moduleId: Int, completion: @escaping fetchFormCompletionHandler) {
        FPLocalDatabaseManager.shared.executeQuery(self.getFetchFormBy(sqliteId: sqliteId), dbManager: self) { results in
            var formResult = FPForms()
            if let result = results.first {
                formResult = FPForms(dict: result, isForLocal: false)
                if let sqliteId = formResult.sqliteId {
                    formResult.sections = FPSectionDetailsDatabaseManager().fetchSectionDetails(for: sqliteId, moduleId)
                }
            }
            completion(formResult)
        }
    }
    
    func isFormSynced(objectId:String) -> Bool {
        var result = [String:Any]()
        FPLocalDatabaseManager.shared.executeQuery(self.getFetchFormBy(objectId: objectId), dbManager: self) { results in
            result = results.first ?? [:]
        }
        return FPForms(dict: result, isForLocal: false).isSyncedToServer ?? false
    }
    
    
    func fetchFormBy(objectId: String, moduleId: Int, shouldIncludeMedia: Bool, completion: @escaping fetchFormCompletionHandler) {
        FPLocalDatabaseManager.shared.executeQuery(self.getFetchFormBy(objectId: objectId), dbManager: self) { results in
            if let result = results.first {
                let fpForm = FPForms(dict: result, isForLocal: false)
                FPSectionDetailsDatabaseManager().fetchSectionDetailsWithCompletion(for: fpForm.sqliteId ?? 0, moduleEntityId: fpForm.objectId ?? "0") { sections in
                    if sections.count > 0 {
                        fpForm.sections = sections
                    }
                    completion(fpForm)
                }
            }else {
                completion(nil)
            }
            
        }
    }
    
    
    func insertAllFPForms(forms: [FPForms], ticketId:NSNumber, moduleId: Int, serviceAddressId:Int? = nil, completion: @escaping (() -> ())) {
        let group = DispatchGroup()
        for form in forms {
            group.enter()
            self.insertForm(form: form, ticketId: ticketId, moduleId: moduleId) { _ , success in
                group.leave()
            }
        }
        group.notify(queue: .main) {
            completion()
        }
    }
    
    //MARK: - Delete methods
    func deleteAllFPFormsFromLocal(ticketId: NSNumber, moduleId: Int, completion: @escaping successCompletionHandler) {
        if ticketId == 0 {
            self.fetchFPFormTemplatesFromLocal { forms in
                guard let results = forms, results.count > 0 else {
                    completion(true)
                    return
                }
                for form in results {
                    if let moduleEntityId = form.objectStringId {
                        FPSectionDetailsTemplateDatabaseManager().deleteSectionFor(moduleEntityId: moduleEntityId) { _ in }
                    }
                }
                FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([self.getDeleteQuery(ticketId: ticketId, moduleId: moduleId, isTemplate: true)], dbManager: self) { success in
                    completion(success)
                }
            }
            
        }else{
            self.fetchFormsFromLocal(ticketId: ticketId, moduleId: moduleId, completion: { forms in
                guard let results = forms, results.count > 0 else {
                    completion(true)
                    return
                }
                for form in results {
                    if form.isSyncedToServer == true , let sqliteId = form.sqliteId {
                        if let sections = form.sections {
                            FPSectionDetailsDatabaseManager().deleteSectionDetails(forArray: sections)
                        }
                    }
                }
                FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([self.getDeleteQuery(ticketId: ticketId, moduleId: moduleId, isTemplate: false)], dbManager: self) { success in
                    completion(success)
                }
            })
        }
        
    }
    
    func deleteFormBySqliteId(form:FPForms, moduleId: Int, ticketId: NSNumber, completion: @escaping successCompletionHandler) {
        if let sqliteId = form.sqliteId {
            if moduleId == FPFormMduleId{
                FPSectionDetailsDatabaseManager().deleteSectionDetails(forArray: form.sections ?? [])
            }
            FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([self.getDeleteFormByIdFromLocal(sqliteId: sqliteId)], dbManager: self) { success in
                completion(success)
            }
        }else {
            completion(false)
        }
    }
    
    func deleteFormsBySqliteId(forms: [FPForms], ticketId: NSNumber, completion: @escaping () -> ()) {
        for form in forms {
            self.deleteFormBySqliteId(form: form, moduleId: FPFormMduleId, ticketId: ticketId) { success in}
        }
        completion()
    }
    
    func deleteFormsByObjectId(forms: [FPForms], moduleId: Int, ticketId: NSNumber, completion: @escaping () -> ()) {
        for form in forms {
            self.deleteFormByObjectId(form: form, moduleId: moduleId, ticketId: ticketId) { success in}
        }
        completion()
    }
    
    func deleteFormByObjectId(form:FPForms, moduleId: Int, ticketId: NSNumber, completion: @escaping successCompletionHandler) {
        if let objectId = form.objectId {
            self.fetchFormBy(objectId: objectId, moduleId: moduleId, shouldIncludeMedia: true) { localForm in
                if let localForm = localForm, let sqliteId = localForm.sqliteId {
                    if moduleId == FPFormMduleId, let sections = form.sections, !sections.isEmpty {
                        FPSectionDetailsDatabaseManager().deleteSectionDetails(forArray: sections)
                    }
                    FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([self.getDeleteFormByIdFromLocal(sqliteId: sqliteId)], dbManager: self) { success in
                        completion(success)
                    }
                }else {
                    completion(false)
                }
            }
        }
    }
    
    func deleteInspectionFormByObjectId(_ objectId:String, ticketId: NSNumber, completion: @escaping successCompletionHandler) {
        self.fetchFormBy(objectId: objectId, moduleId: FPFormMduleId, shouldIncludeMedia: true) { localForm in
            if let sections = localForm?.sections {
                FPSectionDetailsDatabaseManager().deleteSectionDetails(forArray: sections)
            }
            FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([self.getDeleteFormBy(objectId: objectId)], dbManager: self) { success in
                completion(success)
            }
        }
    }
    
    func deleteInspectionFormsByObjectId(arrIds: [String], ticketId: NSNumber, completion: @escaping () -> ()) {
        for strId in arrIds {
            self.deleteInspectionFormByObjectId(strId, ticketId: ticketId) { _ in}
        }
        completion()
    }
   
}

extension FPFormsDatabaseManager{
    
    func getFetchByIdQuery(id: NSNumber?) -> String {
        return """
        SELECT * FROM \(FPFormsDatabaseManager.getTableName())
        WHERE
        \(FPColumn.id) = \(id ?? 0)
        """
    }
    
    func insertORUpdate(forms: [FPForms], ticketId: NSNumber, completion:@escaping (_ forms: [FPForms]?) -> ()) {
        for form in forms {
            self.upsert(form: form, ticketId: ticketId) { _ in  }
        }
        completion(forms)
    }
    
    func upsert(form: FPForms, ticketId: NSNumber, completionHandler:  @escaping ((Bool) -> ())) {
        if let id = form.objectId?.numberValue {
            FPLocalDatabaseManager.shared.executeQuery(self.getFetchByIdQuery(id: id), dbManager: self) { results in
                if let result = results.first, let resultSqliteId = result["sqliteId"], let sqliteIdInNum = FPUtility.getNumberValue(resultSqliteId) {
                    guard let isSynced = result["isSyncedToServer"] as? Bool, isSynced == true else {
                        completionHandler(false)
                        return
                    }
                    form.sqliteId = sqliteIdInNum
                    self.updateForm(form: form, ticketId: ticketId, moduleId: FPFormMduleId, shouldUpdateBySqliteId: false) { form, success in
                        completionHandler(success)
                    }
                   
                }else {
                   // insert
                    self.insertForm(form: form, ticketId: ticketId, moduleId: FPFormMduleId) { form, success in
                        completionHandler(success)
                    }
                   
                }
            }
        }else if let _ = form.sqliteId {
            // update offline non synced equip no id
            self.updateForm(form: form, ticketId: ticketId, moduleId: FPFormMduleId, shouldUpdateBySqliteId: true) { form, success in
                completionHandler(success)
            }
        }else {
            self.insertForm(form: form, ticketId: ticketId, moduleId: FPFormMduleId) { form, success in
                completionHandler(success)
            }
        }
    }
}

extension String {
    var numberValue: NSNumber? {
        if let value = Int(self) {
            return NSNumber(value: value)
        }
        return nil
    }
}
