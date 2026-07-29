//
//  FPDifferentialMetaDatabaseManager.swift
//  crm
//
//  Created by SmartServ-Pooja on 9/3/21.
//  Copyright © 2021 SmartServ. All rights reserved.
//

import Foundation
struct FPDifferentialMetaDatabaseManager: FPDataBaseQueries {
    
   
    var fpLoggerModal: FPLoggerModal? {
        let fpLoggerModal = FPLoggerModal()
        fpLoggerModal.loggerName = FPLoggerNames.differentialMeta
        return fpLoggerModal
    }
    static func getTableName() -> String {
        return FPTableName.differentialMeta
    }
    static func getCreateQuery() -> String {
        return """
        CREATE TABLE IF NOT EXISTS \(self.getTableName()) (
        \(FPColumn.sqliteId)                      \(FPDataTypes.integer) PRIMARY KEY AUTOINCREMENT,
        \(FPColumn.apiName)                       \(FPDataTypes.text),
        \(FPColumn.updatedAt)                     \(FPDataTypes.var100),
        \(FPColumn.payload)                       \(FPDataTypes.text),
        \(FPColumn.isFetching)                    \(FPDataTypes.bool1),
        \(FPColumn.pageCount)                     \(FPDataTypes.text),
        CONSTRAINT uniqueConstraint \(FPKey.unique) (\(FPColumn.apiName), \(FPColumn.payload))
        );
        """
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
    func getInsertQuery(differentialMeta:FPDifferentialMeta) -> (String, [Any]) {
        var keyNames:String = ""
        var questionmarks:String = ""
        var arguments = [Any]()
       (keyNames, questionmarks, arguments) = self.getData(differentialMeta)
        return ("""
        INSERT INTO \(FPDifferentialMetaDatabaseManager.getTableName()) (
        \(keyNames)) VALUES
        (\(questionmarks))
        """, arguments)
    }
    func getUpdateQuery(_ differentialMeta:FPDifferentialMeta) -> (String, [Any]) {
        var keyNames:String = ""
        var arguments = [Any]()
       (keyNames, arguments) = self.getDataForUpdate(differentialMeta)
        let updateQuery =
        """
                UPDATE \(FPDifferentialMetaDatabaseManager.getTableName())
                SET
                \(keyNames)
                WHERE
                \(FPColumn.apiName) = '\(differentialMeta.apiName)' AND
                \(FPColumn.payload) = '\(differentialMeta.payload)'
        """
        return (updateQuery, arguments)
    }
    func insertIntoDB(differentialMeta: FPDifferentialMeta, completion: @escaping ((Bool)->())) {
        var dict = [String:Any]()
        (dict["sqlQuery"], dict["arguments"]) = self.getInsertQuery(differentialMeta: differentialMeta)
        FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([dict], dbManager: self) { success in
            completion(success)
        }
    }
    func updateIntoDB(differentialMeta: FPDifferentialMeta, completion: @escaping ((Bool)->())) {
        var dict = [String:Any]()
        (dict["sqlQuery"], dict["arguments"]) = self.getUpdateQuery( differentialMeta)
        FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([dict], dbManager: self) { success in
            completion(success)
        }
    }
    func fetchFromDB(apiName:String, payload: String, completion: @escaping (([FPDifferentialMeta])->())) {
        let query =
            """
            Select * from \(FPDifferentialMetaDatabaseManager.getTableName())
            WHERE
            \(FPColumn.apiName) = '\(apiName)' AND
            \(FPColumn.payload) = '\(payload)'
            """
        FPLocalDatabaseManager.shared.executeQuery(query, dbManager: self) { results in
            var array = [FPDifferentialMeta]()
            for item in results {
                array.append(FPDifferentialMeta.init(dict: item))
            }
            completion(array)
        }
    }
    func setIsFetchingFalseForAll() {
        let updateQuery =
            """
                    UPDATE \(FPDifferentialMetaDatabaseManager.getTableName())
                    SET
                    \(FPColumn.isFetching) = 0
                  
            """
        FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([updateQuery], dbManager: self) { success in }
    }
    func fetchFromDB(apiName:String, completion: @escaping (([FPDifferentialMeta])->())) {
        let query =
            """
            Select * from \(FPDifferentialMetaDatabaseManager.getTableName())
            WHERE
            \(FPColumn.apiName) = '\(apiName)'
            """
        FPLocalDatabaseManager.shared.executeQuery(query, dbManager: self) { results in
            var array = [FPDifferentialMeta]()
            for item in results {
                array.append(FPDifferentialMeta.init(dict: item))
            }
            completion(array)
        }
    }
    func upsertDifferetialMeta(differentialMeta: FPDifferentialMeta, shouldChangeUpdatedAt: Bool, completion: @escaping ((Bool, String)->())) {
        FPDifferentialMetaDatabaseManager().fetchFromDB(apiName: differentialMeta.apiName, payload: differentialMeta.payload) { results in
            if let result = results.first {
                if !shouldChangeUpdatedAt {
                    differentialMeta.updatedAt = result.updatedAt
                }
                FPDifferentialMetaDatabaseManager().updateIntoDB(differentialMeta: differentialMeta) { success in
                    completion(success, differentialMeta.updatedAt)
                }
            }else {
                if !shouldChangeUpdatedAt {
                    differentialMeta.updatedAt = ""
                }
                FPDifferentialMetaDatabaseManager().insertIntoDB(differentialMeta: differentialMeta) { success in
                    completion(success, differentialMeta.updatedAt)
                }
            }
        }
    }
    func getData(_ differentialMeta:FPDifferentialMeta) -> (String, String, [Any])  {
        var keyNames:String = ""
        var questionmarks:String = ""
        var arguments = [Any]()
        let mirrored_object = Mirror(reflecting: differentialMeta)
        for (_, attr) in mirrored_object.children.enumerated() {
            if let key = attr.label {
                if keyNames == "" {
                    keyNames += key
                }else {
                    keyNames += "," + key
                }
                if questionmarks == "" {
                    questionmarks += "?"
                }else {
                    questionmarks += "," + "?"
                }
                arguments.append(attr.value)
            }
        }
        return (keyNames, questionmarks, arguments)
    }
    
    func getDataForUpdate(_ differentialMeta:FPDifferentialMeta) -> (String, [Any])  {
        var keyNames:String = ""
        var arguments = [Any]()
        let mirrored_object = Mirror(reflecting: differentialMeta)
        for (_, attr) in mirrored_object.children.enumerated() {
            if let key = attr.label {
                if keyNames == "" {
                    keyNames += "\(key) = ?"
                }else {
                    keyNames += ", \(key) = ?"
                }
                
                arguments.append(attr.value)
            }
        }
        
        return (keyNames, arguments)
       
    }
    
}
