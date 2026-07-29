//
//  DatabaseManager.swift
//  crm
//
//  Created by Apple on 04/03/21.
//  Copyright © 2021 SmartServ. All rights reserved.
//

import Foundation
internal import GRDB
internal import DatadogCore
internal import DatadogLogs

// MARK: - Protocol
protocol FPDataBaseQueries {
    static func getTableName() -> String
    static func getCreateQuery() -> String
    func getDeleteQuery() -> String
    func getInsertQuery() -> String
    func getLastInsertQuery() -> String
    func getUpdateQuery() -> String
    var fpLoggerModal: FPLoggerModal? { get }
}

let dbName = "fpform_db.sqlite"

class FPLocalDatabaseManager: NSObject {
    fileprivate var localLogger:FPLoggerModal? = FPLoggerModal().setLoger("DBManager")
    var pool:DatabasePool!
    private var dbWriter: DatabaseWriter!
    let databaseFileName = dbName
    static let shared = FPLocalDatabaseManager()
    
    override init() {
        super.init()
        var configuration = Configuration()
//        configuration.defaultTransactionKind = .deferred
        configuration.maximumReaderCount = 20
        do {
            self.pool = try DatabasePool(path:FPUtility.getPathForSupportDirectory(databaseFileName)!)
            self.dbWriter = self.pool
            self.printAndSendLogToDatadog(self, queryString: "GRDB pool initialised")
        }catch {
            self.printAndSendLogToDatadog(self, queryString: "DB Error:\(error)", isError: true)
        }
    }
    
}

// MARK: - Typed GRDB Helpers

 extension FPLocalDatabaseManager {
     func insert<T:PersistableRecord>(_ dataModel: T) {
         do {
             try self.dbWriter?.write({ db in
                 try dataModel.insert(db)
             })
         } catch {
             debugPrint(error)
         }
     }
     
     func upsert<T:PersistableRecord>(_ dataModel: T) {
         do {
             try self.dbWriter?.write({ db in
                 try dataModel.save(db)
             })
         } catch {
             debugPrint(error)
         }
     }
     
     func fetch<T:FetchableRecord>(_ dataModel: T.Type, tableName: String) -> [T] {
         do {
             let results = try self.dbWriter?.read({ db in
                 try T.fetchAll(db, sql: "Select * FROM \(tableName)")
             })
             return results ?? [T]()
         } catch {
             debugPrint(error)
         }
         return [T]()
     }
     
     func update<T:PersistableRecord>(_ dataModel: T) {
         do {
             try self.dbWriter?.write({ db in
                 try dataModel.update(db)
             })
         } catch {
             debugPrint(error)
         }
     }
     
     func delete<T:PersistableRecord>(_ dataModel: T) {
         do {
            _ = try self.dbWriter?.write({ db in
                 try dataModel.delete(db)
             })
         } catch {
             debugPrint(error)
         }
     }
}

// MARK: -  Operation Functions

extension FPLocalDatabaseManager{
    func executeInsertUpdateDeleteQuery(_ strQueryArray : [String], dbManager: FPDataBaseQueries, completionHandler: ((Bool) -> ())? = nil) {
        do {
            if let isTrue = try self.dbWriter?.write({ [unowned self] db -> Bool in
                for sqlQuery in strQueryArray {
                    self.printAndSendLogToDatadog(dbManager, queryString: sqlQuery)
                    do {
                        try db.execute(sql: sqlQuery, arguments: [])
                    }catch {
                        self.printAndSendLogToDatadog(dbManager, queryString: "DB Error:\(error)", isError: true, error: error)
//                        return false  //  in array of insert if any insert fails then whole transaction rolls back hence safe to return false
                    }
                }
                return true
            }), isTrue == true {
                completionHandler?(true)

             }else {
                completionHandler?(false)
            }
            
        }catch  {
            self.printAndSendLogToDatadog(dbManager, queryString: "DB Error:\(error)", isError: true)
            completionHandler?(false)
        }
        
    }
    func executeCRUDQuery(_ sqlQuery : String, dbManager: FPDataBaseQueries, completionHandler: ((Bool, NSNumber) -> ())? = nil) {
        do {
            if let (isTrue, lastInsertedId) = try self.dbWriter?.write({ [unowned self] db -> (Bool, Int64) in
                
                self.printAndSendLogToDatadog(dbManager, queryString: sqlQuery)
                do {
                    try db.execute(sql: sqlQuery, arguments: [])
                }catch {
                    self.printAndSendLogToDatadog(dbManager, queryString: "DB Error:\(error)", isError: true, error: error)
                    return (false, -1)  //  in array of insert if any insert fails then whole transaction rolls back hence safe to return false
                }
                return (true, db.lastInsertedRowID)
            }), isTrue == true {
                completionHandler?(true, NSNumber.init(value: lastInsertedId))

             }else {
                completionHandler?(false, -1)
            }
            
        }catch  {
            self.printAndSendLogToDatadog(dbManager, queryString: "DB Error:\(error)", isError: true)
            completionHandler?(false, -1)
        }
        
    }
    func executeInsertUpdateDeleteQuery(_ strQueryArray : [[String:Any]], dbManager: FPDataBaseQueries, completionHandler: ((Bool) -> ())? = nil) {
        do {
            if let isTrue = try self.dbWriter?.write({ [unowned self] db -> Bool in
                for sqlQuery in strQueryArray {
                    self.printAndSendLogToDatadog(dbManager, queryString: "SQLQUERY:- \(sqlQuery["sqlQuery"] ?? "nil") ARGUMENT:- \(sqlQuery["arguments"] ?? "nil")")
                    if let queryString = sqlQuery["sqlQuery"]  as? String, let arguments =  sqlQuery["arguments"] as? [Any], let arg = StatementArguments(arguments)  {
                        do {
                            try db.execute(sql: queryString , arguments: arg)
                        }catch {
                            self.printAndSendLogToDatadog(dbManager, queryString: "DB Error:\(error)", isError: true, error: error)
                            return false
                        }
                    }else {
                        self.printAndSendLogToDatadog(dbManager, queryString: "DB Error: data format issue", isError: true)
                        return false
                    }
                }
                return true
            }), isTrue == true {
                completionHandler?(true)

             }else {
                completionHandler?(false)
            }
            
        }catch  {
            self.printAndSendLogToDatadog(dbManager, queryString: "DB Error:\(error)", isError: true)
            completionHandler?(false)
        }
        
    }
    func executeQuery(_ strQuery :String, dbManager: FPDataBaseQueries, completionHandler: @escaping (([[String:Any]]) -> ()) ) {
        do {
            if let result = try self.dbWriter?.read({ [unowned self] db -> [[String:Any]] in
                return self.fetchResults(db, dbManager, strQuery)
            }) {
                self.printAndSendLogToDatadog(dbManager, queryString: "Query: \(strQuery) Results: \(result.count) rows")
                completionHandler(result)
            }else {
                completionHandler([[String:Any]]())
            }
            
        }catch  {
            self.printAndSendLogToDatadog(dbManager, queryString: "DB Error:\(error)", isError: true)
            completionHandler([[String:Any]]())
        }
        
    }
    func fetchResults(_ db:GRDB.Database,_ dbManager: FPDataBaseQueries, _ strQuery :String) -> [[String:Any]] {
        var array:[[String:Any]] = [[String:Any]]()
        do {
            let rows = try Row.fetchCursor(db, sql: strQuery)
            while let row = try rows.next() {
                let dict = Dictionary(
                    row.map { (column, dbValue) in
                        (column, dbValue.storage.value as AnyObject)
                    },
                    uniquingKeysWith: { (_, right) in right })
                array.append(dict)
            }
        }catch {
            self.printAndSendLogToDatadog(dbManager, queryString: "DB Error:\(error)", isError: true)
        }
        return array
    }
}

// MARK: - Logs

extension FPLocalDatabaseManager{
    func printAndSendLogToDatadog(_ dbManager: FPDataBaseQueries, queryString: String, isError: Bool = false, error: Error? = nil) {
        if isError, let error = error as? DatabaseError, error.resultCode == ResultCode.SQLITE_CONSTRAINT {
            return
        }
        if let loggerModal = dbManager.fpLoggerModal {
            loggerModal.message = queryString
            loggerModal.serviceName = FPLogServiceName.database.rawValue
            if isError {
                FPDatadogWrapper.shared.sendErrorLog(loggerModal)
                return
            }
            FPDatadogWrapper.shared.sendDebugLog(loggerModal)
        }
    }
}

// MARK: - Migration

extension FPLocalDatabaseManager {
    func migrateGRDB() {
        if let _ = self.dbWriter {
            do {
                try migrator.migrate(self.pool)
                self.printAndSendLogToDatadog(self, queryString: "GRDB migration registered")
            }catch let error{
                debugPrint(error.localizedDescription)
                self.printAndSendLogToDatadog(self, queryString: "Error in GRDB migration registeration:\n\(error.localizedDescription)", isError: true)
            }
        }
    }
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createDatabaseSchema") {[unowned self] db in
            self.createDataBaseSchema(db)
        }
      
        migrator.registerMigration("form") { db in
            if(!self.isTableExist(db, FPTableName.form)){
                try db.create(table: FPTableName.form) { t in
                    t.column(FPColumn.sqliteId, .integer).primaryKey(autoincrement: true)
                    t.column(FPColumn.id, .text).unique()
                    t.column(FPColumn.locallyUpdatedAt, .date)
                    t.column(FPColumn.createdAt, .date)
                    t.column(FPColumn.updatedAt, .date)
                    t.column(FPColumn.isSyncedToServer, .boolean)
                    t.column(FPColumn.isTemplate, .boolean)
                    t.column(FPColumn.parentTicketId, .text)
                    t.column(FPColumn.name, .text)
                    t.column(FPColumn.displayName, .text)
                    t.column(FPColumn.companyId, .text)
                    t.column(FPColumn.fileId, .text)
                    t.column(FPColumn.templateId, .text)
                    t.column(FPColumn.equipmentId, .integer)
                    t.column(FPColumn.isActive, .boolean)
                    t.column(FPColumn.isDeleted, .boolean)
                    t.column(FPColumn.localFileId, .text)
                    t.column(FPColumn.moduleId, .integer)
                    t.column(FPColumn.isAnalysed, .boolean)
                }
            }
        }
        
        migrator.registerMigration("sectionDetails") { db in
            if(!self.isTableExist(db, FPTableName.sectionDetails)){
                try db.create(table: FPTableName.sectionDetails) { t in
                    t.column(FPColumn.sqliteId, .integer).primaryKey(autoincrement: true)
                    t.column(FPColumn.id, .text).unique()
                    t.column(FPColumn.templateId, .text)
                    t.column(FPColumn.name, .text)
                    t.column(FPColumn.displayName, .text)
                    t.column(FPColumn.moduleId, .integer)
                    t.column(FPColumn.showSummary, .boolean)
                    t.column(FPColumn.showDisplayName, .boolean)
                    t.column(FPColumn.moduleEntityId, .integer)
                    t.column(FPColumn.moduleEntityLocalId, .integer)
                    t.column(FPColumn.sortPosition, .text)
                    t.column(FPColumn.isDeleted, .boolean)
                    t.column(FPColumn.isActive, .boolean)
                    t.column(FPColumn.createdAt, .date)
                    t.column(FPColumn.updatedAt, .date)
                    t.column(FPColumn.locallyUpdatedAt, .date)
                    t.column(FPColumn.isSyncedToServer, .boolean)
                }
            }
        }
        
        migrator.registerMigration("fieldDetails") { db in
            if(!self.isTableExist(db, FPTableName.fieldDetails)){
                try db.create(table: FPTableName.fieldDetails) { t in
                    t.column(FPColumn.sqliteId, .integer).primaryKey(autoincrement: true)
                    t.column(FPColumn.id, .text).unique()
                    t.column(FPColumn.templateId, .text)
                    t.column(FPColumn.name, .text)
                    t.column(FPColumn.displayName, .text)
                    t.column(FPColumn.value, .text)
                    t.column(FPColumn.uiType, .text)
                    t.column(FPColumn.dataType, .text)
                    t.column(FPColumn.mandatory, .boolean)
                    t.column(FPColumn.max, .integer)
                    t.column(FPColumn.min, .integer)
                    t.column(FPColumn.defaultValue, .text)
                    t.column(FPColumn.attachments, .text)
                    t.column(FPColumn.readOnly, .boolean)
                    t.column(FPColumn.options, .text)
                    t.column(FPColumn.sectionId, .integer)
                    t.column(FPColumn.sectionLocalId, .integer)
                    t.column(FPColumn.sortPosition, .text)
                    t.column(FPColumn.isDeleted, .boolean)
                    t.column(FPColumn.isActive, .boolean)
                    t.column(FPColumn.createdAt, .date)
                    t.column(FPColumn.updatedAt, .date)
                    t.column(FPColumn.locallyUpdatedAt, .date)
                    t.column(FPColumn.moduleId, .integer)
                    t.column(FPColumn.isSyncedToServer, .boolean)
                    t.column(FPColumn.reasons, .text)
                }
            }
        }
                
        migrator.registerMigration("assetFormLinking") { db in
            if(!self.isTableExist(db, FPTableName.assetFormLinking)){
                try db.create(table: FPTableName.assetFormLinking) { t in
                    t.column(FPColumn.sqliteId, .integer).primaryKey(autoincrement: true)
                    t.column(FPColumn.assetId, .integer)
                    t.column(FPColumn.assetLocalId, .integer)
                    t.column(FPColumn.customFormId, .integer)
                    t.column(FPColumn.customFormLocalId, .integer)
                    t.column(FPColumn.isAssetSynced, .boolean)
                    t.column(FPColumn.fieldTemplateId, .text)
                    t.column(FPColumn.sectionTemplateId, .text)
                    t.column(FPColumn.formTemplateId, .text)
                    t.column(FPColumn.tableRowId, .text)
                    t.column(FPColumn.tableRowLocalId, .text)
                    t.column(FPColumn.companyId, .integer)
                    t.column(FPColumn.isSyncedToServer, .boolean)
                    t.column(FPColumn.addLinking, .boolean)
                    t.column(FPColumn.deleteLinking, .boolean)
                    t.column(FPColumn.isNotConfirmed, .boolean)
                }
            }
        }
        
        migrator.registerMigration("addFormTemplateIdColumnToAssetLinking") {[unowned self] db in
            self.addColumn(to: db, tableName: FPTableName.assetFormLinking, columnName: FPColumn.formTemplateId, constraintName: FPDataTypes.text)
        }
        
        migrator.registerMigration("addIsNotConfirmedColumnToAssetLinking") {[unowned self] db in
            self.addColumn(to: db, tableName: FPTableName.assetFormLinking, columnName: FPColumn.isNotConfirmed, constraintName: FPDataTypes.bool0)
        }
        
       
        migrator.registerMigration("differentialMetaDatabaseManager") { db in
            if(!self.isTableExist(db, FPTableName.differentialMeta)){
                try db.create(table: FPTableName.differentialMeta) { t in
                    t.column(FPColumn.sqliteId, .integer).primaryKey(autoincrement: true)
                    t.column(FPColumn.apiName, .text)
                    t.column(FPColumn.updatedAt, .text)
                    t.column(FPColumn.payload, .text)
                    t.column(FPColumn.isFetching, .boolean)
                    t.column(FPColumn.pageCount, .text)
                    t.uniqueKey([FPColumn.apiName, FPColumn.payload])
                }
            }
        }
        
        
        migrator.registerMigration("fieldDetailsTemplate") { db in
            if(!self.isTableExist(db, FPTableName.fieldDetailsTemplate)){
                try db.create(table: FPTableName.fieldDetailsTemplate) { t in
                    t.column(FPColumn.sqliteId, .integer).primaryKey(autoincrement: true)
                    t.column(FPColumn.id, .text).unique()
                    t.column(FPColumn.name, .text)
                    t.column(FPColumn.displayName, .text)
                    t.column(FPColumn.value, .text)
                    t.column(FPColumn.uiType, .text)
                    t.column(FPColumn.dataType, .text)
                    t.column(FPColumn.mandatory, .boolean)
                    t.column(FPColumn.max, .integer)
                    t.column(FPColumn.min, .integer)
                    t.column(FPColumn.defaultValue, .text)
                    t.column(FPColumn.readOnly, .boolean)
                    t.column(FPColumn.options, .text)
                    t.column(FPColumn.layout, .text)
                    t.column(FPColumn.sectionId, .integer)
                    t.column(FPColumn.sortPosition, .text)
                    t.column(FPColumn.isDeleted, .boolean)
                    t.column(FPColumn.isActive, .boolean)
                    t.column(FPColumn.createdAt, .date)
                    t.column(FPColumn.updatedAt, .date)
                    t.column(FPColumn.locallyUpdatedAt, .date)
                    t.column(FPColumn.isSyncedToServer, .boolean)
                    t.column(FPColumn.reasons, .text)
                }
            }
        }
        
        migrator.registerMigration("sectionDetailsTemplate") { db in
            if(!self.isTableExist(db, FPTableName.sectionDetailsTemplate)){
                try db.create(table: FPTableName.sectionDetailsTemplate) { t in
                    t.column(FPColumn.sqliteId, .integer).primaryKey(autoincrement: true)
                    t.column(FPColumn.id, .text).unique()
                    t.column(FPColumn.name, .text)
                    t.column(FPColumn.displayName, .text)
                    t.column(FPColumn.moduleId, .integer)
                    t.column(FPColumn.showSummary, .boolean)
                    t.column(FPColumn.showDisplayName, .boolean)
                    t.column(FPColumn.moduleEntityId, .integer)
                    t.column(FPColumn.sortPosition, .text)
                    t.column(FPColumn.isDeleted, .boolean)
                    t.column(FPColumn.isActive, .boolean)
                    t.column(FPColumn.createdAt, .date)
                    t.column(FPColumn.updatedAt, .date)
                    t.column(FPColumn.locallyUpdatedAt, .date)
                    t.column(FPColumn.isSyncedToServer, .boolean)
                }
            }
        }
        
        migrator.registerMigration("addisSignedColumnToFormsTable") {[unowned self] db in
            if !self.exists(db, column: FPColumn.isSigned, in: FPTableName.form) {
                self.addColumn(to: db, tableName: FPTableName.form, columnName: FPColumn.isSigned, constraintName: FPDataTypes.bool0)
            }
        }
        
        
        migrator.registerMigration("addsignedAtColumnToFormsTable") {[unowned self] db in
            if !self.exists(db, column: FPColumn.signedAt, in: FPTableName.form) {
                self.addColumn(to: db, tableName: FPTableName.form, columnName: FPColumn.signedAt, constraintName: FPDataTypes.integer)
            }
        }
        migrator.registerMigration("addSectionAssetColumn") { db in
            self.addColumn(
                to: db,
                tableName: FPTableName.sectionDetails,
                columnName:FPColumn.isHidden,
                constraintName: FPDataTypes.bool0
            )
            self.addColumn(
                to: db,
                tableName: FPTableName.sectionDetails,
                columnName:FPColumn.sectionMappingValue,
                constraintName: FPDataTypes.var100
            )
            self.addColumn(
                to: db,
                tableName: FPTableName.sectionDetails,
                columnName:FPColumn.options,
                constraintName: FPDataTypes.text
            )
        }
        
        migrator.registerMigration("addFieldAssetColumn") { db in
            self.addColumn(
                to: db,
                tableName: FPTableName.fieldDetails,
                columnName:FPColumn.isHidden,
                constraintName: FPDataTypes.bool0
            )
            
            self.addColumn(
                to: db,
                tableName: FPTableName.fieldDetails,
                columnName:FPColumn.scannable,
                constraintName: FPDataTypes.bool0
            )
        }
        
        
        migrator.registerMigration("addSectionTemplateAssetColumn") { db in
            self.addColumn(
                to: db,
                tableName: FPTableName.sectionDetailsTemplate,
                columnName:FPColumn.isHidden,
                constraintName: FPDataTypes.bool0
            )
            self.addColumn(
                to: db,
                tableName: FPTableName.sectionDetailsTemplate,
                columnName:FPColumn.sectionMappingValue,
                constraintName: FPDataTypes.var100
            )
            self.addColumn(
                to: db,
                tableName: FPTableName.sectionDetailsTemplate,
                columnName:FPColumn.options,
                constraintName: FPDataTypes.text
            )
        }
        
        migrator.registerMigration("addFieldTemplateAssetColumn") { db in
            self.addColumn(
                to: db,
                tableName: FPTableName.fieldDetailsTemplate,
                columnName:FPColumn.isHidden,
                constraintName: FPDataTypes.bool0
            )
            
            self.addColumn(
                to: db,
                tableName: FPTableName.fieldDetailsTemplate,
                columnName:FPColumn.scannable,
                constraintName: FPDataTypes.bool0
            )
        }
        
        migrator.registerMigration("addnotesColumnToFormsTable") {[unowned self] db in
            if !self.exists(db, column: FPColumn.notes, in: FPTableName.form) {
                self.addColumn(to: db, tableName: FPTableName.form, columnName: FPColumn.notes, constraintName: FPDataTypes.text)
            }
        }
        
        migrator.registerMigration("addSectionAssetColumnToAssetFormLinking") { db in
            self.addColumn(
                to: db,
                tableName: FPTableName.assetFormLinking,
                columnName:FPColumn.sectionId,
                constraintName: FPDataTypes.integer
            )
            self.addColumn(
                to: db,
                tableName: FPTableName.assetFormLinking,
                columnName:FPColumn.sectionLocalId,
                constraintName: FPDataTypes.integer
            )
            self.addColumn(
                to: db,
                tableName: FPTableName.assetFormLinking,
                columnName:FPColumn.sectionLinking,
                constraintName: FPDataTypes.bool0
            )
        }
        
        migrator.registerMigration("addDeletedSectionsColumnToFormsTable") {[unowned self] db in
            if !self.exists(db, column: FPColumn.deletedSections, in: FPTableName.form) {
                self.addColumn(to: db, tableName: FPTableName.form, columnName: FPColumn.deletedSections, constraintName: FPDataTypes.text)
            }
        }
        
        migrator.registerMigration("addDownloadStatusAndUrlToFormsTable") {[unowned self] db in
            if !self.exists(db, column: FPColumn.downloadStatus, in: FPTableName.form) {
                self.addColumn(to: db, tableName: FPTableName.form, columnName: FPColumn.downloadStatus, constraintName: FPDataTypes.text)
            }
            
            if !self.exists(db, column: FPColumn.downloadURL, in: FPTableName.form) {
                self.addColumn(to: db, tableName: FPTableName.form, columnName: FPColumn.downloadURL, constraintName: FPDataTypes.text)
            }
        }
        
        migrator.registerMigration("addIsSectionDuplication") { db in
            if !self.exists(db, column: FPColumn.isSectionDuplicationField, in: FPTableName.fieldDetails) {
                self.addColumn(
                    to: db,
                    tableName: FPTableName.fieldDetails,
                    columnName:FPColumn.isSectionDuplicationField,
                    constraintName: FPDataTypes.bool0
                )
            }
        }
        
        // Migration for form sync idempotency
        migrator.registerMigration("addLocalClientIdColumnToFormsTable") {[unowned self] db in
            if !self.exists(db, column: FPColumn.localClientId, in: FPTableName.form) {
                self.addColumn(to: db, tableName: FPTableName.form, columnName: FPColumn.localClientId, constraintName: FPDataTypes.text)
            }
        }

                
        migrator.registerMigration("tableDraftData") { db in
            if(!self.isTableExist(db, FPTableName.tableDraftData)){
                try db.create(table: FPTableName.tableDraftData) { t in
                    t.column(FPColumn.draftKey, .text).primaryKey()
                    t.column(FPColumn.customFormLocalId, .text)
                    t.column(FPColumn.fieldLocalId, .integer)
                    t.column(FPColumn.fieldId, .text)
                    t.column(FPColumn.value, .text)
                    t.column(FPColumn.updatedAt, .date)
                }
                try db.create(index: "idx_table_draft_key", on: FPTableName.tableDraftData, columns: [FPColumn.draftKey], unique: true)
                try db.create(index: "idx_table_draft_form", on: FPTableName.tableDraftData, columns: [FPColumn.customFormLocalId])
            }
        }
        
        migrator.registerMigration("addCustomFormLocalIdToTableDraft") { [unowned self] db in
            if !self.exists(db, column: FPColumn.customFormLocalId, in: FPTableName.tableDraftData) {
                self.addColumn(to: db, tableName: FPTableName.tableDraftData, columnName: FPColumn.customFormLocalId, constraintName: FPDataTypes.text)
                try db.create(index: "idx_table_draft_form", on: FPTableName.tableDraftData, columns: [FPColumn.customFormLocalId])
            }
        }

        return migrator
    }
    
    
    func addColumn(to db: GRDB.Database, tableName:String, columnName:String, constraintName:String) {
        if !self.exists(db, column: columnName, in: tableName) {
            self.executeQueryOn(db, [self.getAddColumnQuery(columnName, tableName, constraintName)])
        }
    }
    func addTable(_ db: GRDB.Database, _ tableName:String) {
        if !self.isTableExist(db, tableName) {
            let schemaQuery = "\(FPQuery.getCreateTableQuery(tableName))\n"
            self.executeQueryOn(db, [schemaQuery])
        }
    }
    func executeQueryOn(_ db:GRDB.Database, _ strQueryArray : [String]) {
        for sqlQuery in strQueryArray {
            self.fpLoggerModal?.loggerName = FPLoggerNames.dbManager
            self.printAndSendLogToDatadog(self, queryString: sqlQuery)
            do {
                try db.execute(sql: sqlQuery, arguments: [])
            }catch {
                self.printAndSendLogToDatadog(self, queryString: "DB Error:\(error)", isError: true, error: error)
            }
        }
    }
    func createDataBaseSchema(_ db:GRDB.Database) {
        var schemaQuery = ""
        for item in FPTableName.getArrayOfTables() {
            schemaQuery += "\(FPQuery.getCreateTableQuery(item))\n"
        }
        self.executeQueryOn(db, [schemaQuery])
    }
    func getAddColumnQuery(_ columnName: String, _ tableName: String, _ constraint: String) -> String {
        return """
            ALTER TABLE \(tableName) ADD COLUMN \(columnName) \(constraint);\n
            """
    }

    func exists(_ db: GRDB.Database, column: String, in table: String) -> Bool {
        let query = "PRAGMA table_info(\(table))"
        let results = self.fetchResults(db, self, query)
        var isExist = false
        for item in results {
            if let name = item["name"] as? String, name.lowercased() == column.lowercased() {
                isExist = true
                break
            }
        }
        return isExist
    }
    
    func existsUniqueContraints(_ db: GRDB.Database, column: String, in table: String) -> Bool {
        // Note: No way find to get column constraint directly so getting schema from master table & check for Unique key as we only have single column as Unique in table.
        let query = "select sql from sqlite_master where type='table' and name='\(table)'"
        let results = self.fetchResults(db, self, query)
        if results.count > 0 {
            if let resultString = results.first?["sql"] as? String, resultString.contains(FPKey.unique) {
                return true
            }
        }
        return false
    }
    
    func isTableExist(_ db: GRDB.Database, _ tableName: String) -> Bool {
        let query =
            """
                SELECT name, sql FROM sqlite_master
                WHERE type='table'
                ORDER BY name;
            """
        let results = self.fetchResults(db, self, query)
        var isExist = false
        for item in results {
            if let name = item["name"] as? String, name.lowercased() == tableName.lowercased() {
                isExist = true
                break
            }
        }
        return isExist
    }
   
    func deleteTable(_ db: GRDB.Database, table: String) -> Bool {
        do {
            try db.drop(table: table)
            return true
        } catch {
            return false
        }
    }
   
}

extension FPLocalDatabaseManager: FPDataBaseQueries {
    
    static func getTableName() -> String {
        return ""
    }
    
    static func getCreateQuery() -> String {
        return ""
    }
    
    func getDeleteQuery() -> String {
        return ""
    }
    
    func getInsertQuery() -> String {
        return ""
    }
    
    func getLastInsertQuery() -> String {
        return ""
    }
    
    func getUpdateQuery() -> String {
        return ""
    }
    var fpLoggerModal: FPLoggerModal? {
        get {
            return localLogger
        }
        set {
            localLogger = newValue
        }
    }
}
