//
//  FPSectionDraftDatabaseManager.swift
//  crm
//
//  Copyright © 2026 SmartServ. All rights reserved.
//

import Foundation
internal import GRDB

struct FPSectionDraftDatabaseManager: FPDataBaseQueries {
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
        return FPLoggerModal()
    }
    
    static func getTableName() -> String {
        return FPTableName.sectionDraftData
    }
    
    static func getCreateQuery() -> String {
        return """
        CREATE TABLE IF NOT EXISTS \(self.getTableName()) (
        \(FPColumn.draftKey)      \(FPDataTypes.text) PRIMARY KEY,
        \(FPColumn.customFormLocalId) \(FPDataTypes.text),
        \(FPColumn.sectionLocalId)  \(FPDataTypes.integer),
        \(FPColumn.sectionId)       \(FPDataTypes.text),
        \(FPColumn.value)         \(FPDataTypes.text),
        \(FPColumn.updatedAt)     \(FPDataTypes.date)
        );
        CREATE UNIQUE INDEX IF NOT EXISTS idx_section_draft_key ON \(self.getTableName())(\(FPColumn.draftKey));
        CREATE INDEX IF NOT EXISTS idx_section_draft_form ON \(self.getTableName())(\(FPColumn.customFormLocalId));
        """
    }

    func getDeleteQuery() -> String {
        return "DELETE FROM \(FPSectionDraftDatabaseManager.getTableName())"
    }

    // MARK: - Draft Operations (Key-centric)

    private func getInsertQuery(key: String, formLocalId: String?, sqliteId: Int64?, objectId: String?, value: String) -> String {
        let safeKey   = key
        let safeValue = value.processApostrophe()
        let now       = ISO8601DateFormatter().string(from: Date())
        
        let fidStr = formLocalId != nil ? "'\(formLocalId ?? "")'" : "NULL"
        let sidStr = sqliteId != nil ? "\(sqliteId ?? 0)" : "NULL"
        let oidStr = objectId != nil ? "'\(objectId ?? "")'" : "NULL"

        return """
        INSERT OR REPLACE INTO \(FPSectionDraftDatabaseManager.getTableName())
        (\(FPColumn.draftKey), \(FPColumn.customFormLocalId), \(FPColumn.sectionLocalId), \(FPColumn.sectionId), \(FPColumn.value), \(FPColumn.updatedAt))
        VALUES ('\(safeKey)', \(fidStr), \(sidStr), \(oidStr), '\(safeValue)', '\(now)')
        """
    }

    func saveDraft(key: String, formLocalId: String?, sqliteId: Int64?, objectId: String?, value: String) {
        FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery(
            [getInsertQuery(key: key, formLocalId: formLocalId, sqliteId: sqliteId, objectId: objectId, value: value)],
            dbManager: self
        )
    }

    func deleteDraft(draftKey: String) {
        let safeKey = draftKey
        let query = """
            DELETE FROM \(FPSectionDraftDatabaseManager.getTableName())
            WHERE \(FPColumn.draftKey) = '\(safeKey)'
            """
        FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([query], dbManager: self)
    }

    /// Robust delete that clears any draft matching the current section's identifiers.
    func deleteDraftByMultiPath(draftKey: String, sectionLocalId: Int64?, sectionId: String?, formLocalId: String? = nil) {
        var clauses = ["\(FPColumn.draftKey) = '\(draftKey)'"]

        if let sid = sectionLocalId, sid > 0 {
            clauses.append("\(FPColumn.sectionLocalId) = \(sid)")
        }

        if let fid = sectionId, !fid.isEmpty, fid != "0" {
            clauses.append("\(FPColumn.sectionId) = '\(fid)'")
        }

        if let flid = formLocalId, !flid.isEmpty, flid != "0" {
            clauses.append("\(FPColumn.customFormLocalId) = '\(flid)'")
        }

        let whereClause = clauses.joined(separator: " OR ")
        let query = "DELETE FROM \(FPSectionDraftDatabaseManager.getTableName()) WHERE \(whereClause)"

        FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([query], dbManager: self)
    }

    /// Deletes every section draft in the DB — call on logout.
    func deleteAllDrafts() {
        FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([getDeleteQuery()], dbManager: self)
    }

    /// Deletes all section drafts associated with a specific form instance.
    func deleteAllDraftsForForm(ticketId: String, formLocalId: String) {
        let prefix = "fp_sec_path_\(ticketId)_\(formLocalId)_"
        let query = """
            DELETE FROM \(FPSectionDraftDatabaseManager.getTableName())
            WHERE \(FPColumn.customFormLocalId) = '\(formLocalId)'
               OR \(FPColumn.draftKey) LIKE '\(prefix)%'
            """
        FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([query], dbManager: self)
    }

    func fetchDraft(draftKey: String, completion: @escaping (String?) -> Void) {
        let safeKey = draftKey
        let query = """
            SELECT \(FPColumn.value)
            FROM \(FPSectionDraftDatabaseManager.getTableName())
            WHERE \(FPColumn.draftKey) = '\(safeKey)'
            LIMIT 1
            """
        FPLocalDatabaseManager.shared.executeQuery(query, dbManager: self) { results in
            if let first = results.first,
               let value = first[FPColumn.value] as? String,
               !value.isEmpty {
                completion(value)
            } else {
                completion(nil)
            }
        }
    }

    /// Robust fetch that checks for a draft match across multiple ID paths.
    func fetchDraftByMultiPath(draftKey: String, sectionLocalId: Int64?, sectionId: String?, completion: @escaping (String?) -> Void) {
        var clauses = ["\(FPColumn.draftKey) = '\(draftKey)'"]
        
        if let sid = sectionLocalId, sid > 0 {
            clauses.append("\(FPColumn.sectionLocalId) = \(sid)")
        }
        
        if let fid = sectionId, !fid.isEmpty, fid != "0" {
            clauses.append("\(FPColumn.sectionId) = '\(fid)'")
        }
        
        let whereClause = clauses.joined(separator: " OR ")
        
        let query = """
            SELECT \(FPColumn.value)
            FROM \(FPSectionDraftDatabaseManager.getTableName())
            WHERE \(whereClause)
            ORDER BY \(FPColumn.updatedAt) DESC
            LIMIT 1
            """
        
        FPLocalDatabaseManager.shared.executeQuery(query, dbManager: self) { results in
            if let first = results.first,
               let value = first[FPColumn.value] as? String,
               !value.isEmpty {
                completion(value)
            } else {
                completion(nil)
            }
        }
    }

    /// Deletes section drafts for a specific section identified by its local sqliteId or server objectId.
    func deleteDraftsForSection(sectionLocalId: Int64?, sectionId: String?) {
        var clauses: [String] = []
        if let sid = sectionLocalId, sid > 0 {
            clauses.append("\(FPColumn.sectionLocalId) = \(sid)")
        }
        if let fid = sectionId, !fid.isEmpty, fid != "0" {
            clauses.append("\(FPColumn.sectionId) = '\(fid)'")
        }
        guard !clauses.isEmpty else { return }
        let query = "DELETE FROM \(FPSectionDraftDatabaseManager.getTableName()) WHERE \(clauses.joined(separator: \" OR \"))"
        FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([query], dbManager: self)
    }

    /// Updates customFormLocalId from the old form sqliteId to the new one after an offline→online sync.
    func migrateFormSectionDrafts(from oldSqliteId: NSNumber, to newSqliteId: NSNumber, completion: (() -> Void)? = nil) {
        let old = oldSqliteId.stringValue
        let new = newSqliteId.stringValue
        let queries = [
            "UPDATE \(FPSectionDraftDatabaseManager.getTableName()) SET \(FPColumn.customFormLocalId) = '\(new)' WHERE \(FPColumn.customFormLocalId) = '\(old)'",
            "UPDATE \(FPSectionDraftDatabaseManager.getTableName()) SET \(FPColumn.draftKey) = REPLACE(\(FPColumn.draftKey), '_\(old)_', '_\(new)_') WHERE \(FPColumn.draftKey) LIKE '%_\(old)_%'"
        ]
        FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery(queries, dbManager: self) { _ in
            completion?()
        }
    }

    /// Removes drafts whose parent form no longer exists in local DB.
    func deleteOrphanedDrafts() {
        let query = """
        DELETE FROM \(FPSectionDraftDatabaseManager.getTableName())
        WHERE \(FPColumn.customFormLocalId) IS NOT NULL
          AND \(FPColumn.customFormLocalId) != '0'
          AND \(FPColumn.customFormLocalId) NOT IN (
              SELECT CAST(\(FPColumn.sqliteId) AS TEXT)
              FROM \(FPTableName.form)
              WHERE \(FPColumn.sqliteId) IS NOT NULL
          )
          AND \(FPColumn.customFormLocalId) NOT IN (
              SELECT \(FPColumn.localClientId)
              FROM \(FPTableName.form)
              WHERE \(FPColumn.localClientId) IS NOT NULL
          )
        """
        FPLocalDatabaseManager.shared.executeInsertUpdateDeleteQuery([query], dbManager: self)
    }
}
