//
//  DynamicTableViewModel.swift
//  crm
//
//  Created by Mayur on 23/02/22.
//  Copyright © 2022 SmartServ. All rights reserved.
//

import Foundation
internal import SSMediaManager
internal import GRDB
import UIKit


class TableComponent {
    var headers: [Headers]?
    var rows: [Rows]?
    var values: [[String: Any]]?
    var tableOptions:TableOptions?
    var fieldDetails:FPFieldDetails?
    var customForm:FPForms?

    func makeCopy() -> TableComponent {
        let copy = TableComponent()
        copy.headers = headers
        copy.rows = rows
        copy.values = values
        copy.tableOptions = tableOptions
        copy.fieldDetails = fieldDetails
        copy.customForm = customForm
        return copy
    }
    
    func prepareData(item: TableOptions, values: String?,index:IndexPath, rowCount: Int = 1, fieldDetails:FPFieldDetails?, customForm:FPForms) -> TableComponent {
        self.tableOptions = item
        self.headers = [Headers]()
        self.rows = [Rows]()
        self.fieldDetails = fieldDetails
        self.customForm = customForm

        if values == nil || values == "" {
            self.values = [[String: Any]]()
        } else {
            self.values = [[String: Any]]()
            let tmpValues = values?.getArray()
            tmpValues?.forEach({ tmpValue in
                var objVal = tmpValue
                if objVal["__localId__"] == nil{
                    objVal["__localId__"] = UUID().uuidString
                }
                self.values?.append(objVal)
            })
//            self.values = values?.getArray()
        }
        // Prepare headers once
        item.columns?.forEach({ column in
            self.headers?.append(Headers(name: column.name, type: column.uiType))
        })
        
        // Batch fetch asset mappings to avoid O(N) database queries
        let allMappings = AssetFormLinkingDatabaseManager().fetchAssetLinkigDataFor(fieldTemplateId: fieldDetails?.templateId ?? "", form: customForm)
        var mapByLocalId: [String: AssetFormMappingData] = [:]
        var mapByRowId: [String: AssetFormMappingData] = [:]
        for m in allMappings {
            if let lId = m.tableRowLocalId, !lId.isEmpty { mapByLocalId[lId] = m }
            if let rId = m.tableRowId, !rId.isEmpty { mapByRowId[rId] = m }
        }

        if((self.values?.count ?? 1)>1){
            self.values?.forEach({ object in
                var localRowId:String?
                var rowId:String?
                if let localIdColoumn =  object["__localId__"] as? String{
                    localRowId = localIdColoumn
                }
                var columns = [ColumnData]()
                if let IdColoumn =  object["__id__"] as? String{
                    rowId = IdColoumn
                    let column = ColumnData(key: "__id__", value: IdColoumn, uiType: "HIDDEN", dataType: "", dropDownOptions: nil)
                    columns.append(column)
                }
                item.columns?.forEach({ column in
                    var valueString = ""
                    if let value = object[column.name] as? String{
                        valueString = value
                    }else if  let value = object[column.name] as? [String:Any]{
                        valueString =  value.getJson()
                    }

                    let columnData = ColumnData(key: column.name, value: valueString, defaultValue: column.defaultValue, uiType: column.uiType, dataType: column.dataType, dropDownOptions: column.columnOptions?.dropdownOptions ?? nil, generateDynamically: column.columnOptions?.generateDynamically, dateFormat: column.columnOptions?.dateFormat ?? nil, readonly: column.readonly, scannable: column.scannable, isPartOfFormula: column.isPartOfFormula)
                    columns.append(columnData)
                })
//                self.rows?.append(Rows(columns: columns))
                var tblRow = Rows(columns: columns)
                var ncolumns = [ColumnData]()
                for (_, element) in tblRow.columns.enumerated() {
                    var nelement = element
                    nelement.rowSortUuid = tblRow.sortUuid
                    ncolumns.append(nelement)
                }
                tblRow.columns = ncolumns
                
                // O(1) Dictionary lookup instead of sequential DB queries
                let rowMapping = (localRowId != nil ? mapByLocalId[localRowId!] : nil) ?? (rowId != nil ? mapByRowId[rowId!] : nil)
                if let mapping = rowMapping, let assetId = mapping.assetId, mapping.isAssetSynced == true {
                    if let assetIdColumIndex = tblRow.columns.firstIndex(where: {(($0.getUIType() == .HIDDEN) && ($0.key.lowercased() == hiddenAssetIdColumnKey.lowercased()))}) {
                        tblRow.columns[assetIdColumIndex].value = assetId.stringValue
                    }
                }
                self.rows?.append(tblRow)
            })
        }else{
            var columns = [ColumnData]()
            var rowId:String?
            var localRowId:String?
            item.columns?.forEach({ column in
                var value = ""
                self.values?.forEach({ object in
                    if let localIdColoumn =  object["__localId__"] as? String{
                        localRowId = localIdColoumn
                    }
                    if let IdColoumn =  object["__id__"] as? String{
                        rowId = IdColoumn
                    }
                    object.keys.forEach { key in
                        if key == column.name {
                            if let objectValue = object[column.name] as? String{
                                value = objectValue
                            }else if  let objectValue = object[column.name] as? [String:Any]{
                                value =  objectValue.getJson()
                            }
                        }
                    }
                })
        
                let columnData = ColumnData(key: column.name, value: value, defaultValue: column.defaultValue, uiType: column.uiType, dataType: column.dataType, dropDownOptions: column.columnOptions?.dropdownOptions ?? nil, generateDynamically: column.columnOptions?.generateDynamically, dateFormat: column.columnOptions?.dateFormat ?? nil, readonly: column.readonly, scannable: column.scannable, isPartOfFormula: column.isPartOfFormula)
                columns.append(columnData)
            })
            
            if self.values?.isEmpty ?? false{
                var emptyvalue = [String: Any]()
                columns.forEach { column in
                    emptyvalue[column.key] = column.value
                }
                if emptyvalue["__localId__"] == nil{
                    emptyvalue["__localId__"] = UUID().uuidString
                }
                self.values?.append(emptyvalue)
            }
            for _ in(0 ..< rowCount){
                var tblRow = Rows(columns: columns)
                var ncolumns = [ColumnData]()
                for element in tblRow.columns {
                    var nelement = element
                    nelement.rowSortUuid = tblRow.sortUuid
                    ncolumns.append(nelement)
                }
                tblRow.columns = ncolumns
                
                // O(1) Dictionary lookup
                let rowMapping = (localRowId != nil ? mapByLocalId[localRowId!] : nil) ?? (rowId != nil ? mapByRowId[rowId!] : nil)
                if let mapping = rowMapping, let assetId = mapping.assetId, mapping.isAssetSynced == true {
                    if let assetIdColumIndex = tblRow.columns.firstIndex(where: {(($0.getUIType() == .HIDDEN) && ($0.key.lowercased() == hiddenAssetIdColumnKey.lowercased()))}) {
                        tblRow.columns[assetIdColumIndex].value = assetId.stringValue
                    }
                }
                self.rows?.append(tblRow)
            }
            
        }
        return self
    }
    
    
    func sortData(component:TableComponent, sortOption:SortColumnOption = .ascending, sortColumn:Columns, completion: @escaping (TableComponent) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
          let sortedComponent = TableComponent()
          sortedComponent.tableOptions = component.tableOptions
          sortedComponent.headers = component.headers
          sortedComponent.values = component.values
          sortedComponent.rows = [Rows]()
          let tblrows = component.rows ?? []
          var columnsArray = [ColumnData]()
          for (_, element) in tblrows.enumerated() {
            if let sortcolumn = element.columns.filter({ $0.key == sortColumn.displayName }).first{
              columnsArray.append(sortcolumn)
            }
          }
          var sortedColumns = [ColumnData]()
          if sortColumn.dataType == "DATE" || sortColumn.dataType == "TIME" || sortColumn.dataType == "DATE_TIME" || sortColumn.dataType == "YEAR"{
            if sortColumn.dataType == "TIME"{
                if sortOption == .ascending{
                    sortedColumns = columnsArray.sorted{ (first,second) in
                        let firstValue = Int(FPUtility.getOPDateFrom(first.value)?.comparativeDate?.millisecondsSince1970 ?? 0)
                        let secondValue = Int(FPUtility.getOPDateFrom(second.value)?.comparativeDate?.millisecondsSince1970 ?? 0)
                        if(firstValue==0){
                            return true
                        }else if(secondValue==0){
                            return false
                        }else{
                            return firstValue < secondValue
                        }
                    }
                }else{
                    sortedColumns = columnsArray.sorted{ (first,second) in
                        let firstValue = Int(FPUtility.getOPDateFrom(first.value)?.comparativeDate?.millisecondsSince1970 ?? 0)
                        let secondValue = Int(FPUtility.getOPDateFrom(second.value)?.comparativeDate?.millisecondsSince1970 ?? 0)
                        if(firstValue==0){
                            return false
                        }else if(secondValue==0){
                            return true
                        }else{
                            return firstValue > secondValue
                        }
                    }
                }
            }else{
              if sortOption == .ascending{
                  sortedColumns = columnsArray.sorted{ (first,second) in
                      let firstValue = Int(FPUtility.getOPDateFrom(first.value)?.millisecondsSince1970 ?? 0)
                      let secondValue = Int(FPUtility.getOPDateFrom(second.value)?.millisecondsSince1970 ?? 0)
                      if(firstValue==0){
                          return true
                      }else if(secondValue==0){
                          return false
                      }else{
                          return firstValue < secondValue
                      }
                  }
              }else{
                  sortedColumns = columnsArray.sorted{ (first,second) in
                      let firstValue = Int(FPUtility.getOPDateFrom(first.value)?.millisecondsSince1970 ?? 0)
                      let secondValue = Int(FPUtility.getOPDateFrom(second.value)?.millisecondsSince1970 ?? 0)
                      if(firstValue==0){
                          return false
                      }else if(secondValue==0){
                          return true
                      }else{
                          return firstValue > secondValue
                      }
                  }
              }
            }
          }else{
              if sortOption == .ascending{
                  sortedColumns = columnsArray.sorted{ (first,second) in
                      let firstValue = FPUtility().getSQLiteSpecialCharsCompatibleString(value: first.value, isForLocal: false) ??  first.value
                      let secondValue = FPUtility().getSQLiteSpecialCharsCompatibleString(value: second.value, isForLocal: false) ?? second.value
                      return firstValue < secondValue
                  }
              }else{
                  sortedColumns = columnsArray.sorted{ (first,second) in
                      let firstValue = FPUtility().getSQLiteSpecialCharsCompatibleString(value: first.value, isForLocal: false) ??  first.value
                      let secondValue = FPUtility().getSQLiteSpecialCharsCompatibleString(value: second.value, isForLocal: false) ?? second.value
                      return firstValue > secondValue
                  }
              }
          }
           
          var sortedRows = [Rows]()
          for (_, element) in sortedColumns.enumerated() {
            if let row = component.rows?.filter({$0.sortUuid == element.rowSortUuid}).first{
              sortedRows.append(row)
            }
          }
          sortedComponent.rows = sortedRows
          DispatchQueue.main.async {
            completion(sortedComponent)
          }
        }
    }
    
    func filterData(component:TableComponent, arrSelected:[String], filterColumn:Columns, completion: @escaping (TableComponent) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let filteredComponent = TableComponent()
            filteredComponent.tableOptions = component.tableOptions
            filteredComponent.headers = component.headers
            filteredComponent.values = component.values
            filteredComponent.rows = [Rows]()
            let tblrows = component.rows ?? []
            var columnsArray = [ColumnData]()
            for (_, element) in tblrows.enumerated() {
                if let ncolumn = element.columns.filter({ $0.key == filterColumn.displayName }).first{
                    columnsArray.append(ncolumn)
                }
            }
            let filteredColumns = columnsArray.filter { column in
                return arrSelected.contains(column.value) || (arrSelected.contains(fileterBlankOptionKey) && column.value.isEmpty == true)
            }

            var filteredRows = [Rows]()
            for (_, element) in filteredColumns.enumerated() {
                if let row = component.rows?.filter({$0.sortUuid == element.rowSortUuid}).first{
                    filteredRows.append(row)
                }
            }
            filteredComponent.rows = filteredRows
            DispatchQueue.main.async {
                completion(filteredComponent)
            }
        }
    }
    
    func addNewRow(with columns: [ColumnData], rowSortId:String? = nil, ignoreDefaultVal:Bool = false) -> Rows {
        var columnsArray = [ColumnData]()
        columns.forEach({ column in
            let column = ColumnData(key: column.key, value: ignoreDefaultVal ?  "" : column.defaultValue ?? "", defaultValue: column.defaultValue, uiType: column.uiType, dataType: column.dataType, dropDownOptions: column.dropDownOptions ?? nil, generateDynamically: column.generateDynamically, dateFormat: column.dateFormat ?? nil, readonly: column.readonly, scannable: column.scannable, isPartOfFormula: column.isPartOfFormula)
            columnsArray.append(column)
        })
        if let tableOptions = tableOptions {
            if let column = tableOptions.columns?.first{
                tableOptions.columns?.append(column)
                self.tableOptions = tableOptions
            }
        }
        var row = Rows(columns: columnsArray)
        if let rowSortId = rowSortId{
            row.sortUuid = rowSortId
        }
        var ncolumns = [ColumnData]()
        for (_, element) in row.columns.enumerated() {
            var nelement = element
            nelement.rowSortUuid = row.sortUuid
            ncolumns.append(nelement)
        }
        row.columns = ncolumns
        self.rows?.append(row)
//        self.rows?.append(row)
        self.values?.append(self.getValueObject(from: row))
        return row
    }
    
    func addDuplicateRow(rowSortId:String? = nil, columns:[ColumnData], at row:Int, isEndOfTable:Bool = false) -> Rows {
        var columnsArray = [ColumnData]()
        columns.forEach({ column in
            let column = ColumnData(key: column.key, value: column.key == "__id__" ? "" : column.value, defaultValue: column.defaultValue, uiType: column.uiType, dataType: column.dataType, dropDownOptions: column.dropDownOptions ?? nil, generateDynamically: column.generateDynamically, dateFormat: column.dateFormat ?? nil, readonly: column.readonly, scannable: column.scannable, isPartOfFormula: column.isPartOfFormula)
            columnsArray.append(column)
        })
        if let tableOptions = tableOptions {
            if let column = tableOptions.columns?.first{
                tableOptions.columns?.append(column)
                self.tableOptions = tableOptions
            }
        }
        var nrow = Rows(columns: columnsArray)
        if let rowSortId = rowSortId{
            nrow.sortUuid = rowSortId
        }
        var ncolumns = [ColumnData]()
        for (_, element) in nrow.columns.enumerated() {
            var nelement = element
            nelement.rowSortUuid = nrow.sortUuid
            ncolumns.append(nelement)
        }
        nrow.columns = ncolumns
        if isEndOfTable{
            self.rows?.append(nrow)
            self.values?.append(self.getValueObject(from: nrow))
        }else{
            self.rows?.insert(nrow, at: row)
            self.values?.insert(self.getValueObject(from: nrow), at: row)
        }
        return nrow
    }
    
    func deleteRow(at row:Int){
        if (rows?.count ?? 0 <= 1) {
            if let topVc = FPUtility.topViewController(), !topVc.isKind(of: UIAlertController.self){
                _  = FPUtility.showAlertController(title: FPLocalizationHelper.localize("error_dialog_title"), message: FPLocalizationHelper.localize("msg_tbl_atleast_need_one_row"), completion: nil)
            }
            return
        }
//        if(tableOptions?.columns?.count ?? 0 > row){
//            tableOptions?.columns?.remove(at: row)
//        }
        
        if(rows?.count ?? 0 > row){
            rows?.remove(at: row)
        }
        
        if(self.values?.count ?? 0 > row){
            self.values?.remove(at: row)
        }
    }
    
    func deleteSortedRow(at row:Int, orginalIndex:Int){
        if (rows?.count ?? 0 <= 1) {
            _  = FPUtility.showAlertController(title: FPLocalizationHelper.localize("error_dialog_title"), message: FPLocalizationHelper.localize("msg_tbl_atleast_need_one_row"), completion: nil)
            return
        }
        
//        if(tableOptions?.columns?.count ?? 0 > row){
//            tableOptions?.columns?.remove(at: row)
//        }

        if(rows?.count ?? 0 > row){
            rows?.remove(at: row)
        }
        
        if(self.values?.count ?? 0 > orginalIndex){
            self.values?.remove(at: orginalIndex)
        }
    }

    
    func getValuesObject() -> [[String: Any]] {
        var values = [[String: Any]]()
        self.rows?.enumerated().forEach { (index, row) in
            var value = [String: Any]()
            row.columns.forEach { column in
                value[column.key] = column.value
            }
            if let rowValue = self.values?[safe:index]{
                if let localId = rowValue["__localId__"] as? String{
                    value["__localId__"] = localId
                }
                if let remotId = rowValue["__id__"] as? String{
                    value["__id__"] = remotId
                }
            }
            values.append(value)
        }
        
//        self.rows?.forEach { row in
//            var value = [String: Any]()
//            row.columns.forEach { column in
//                value[column.key] = column.value
//            }
//            values.append(value)
//        }
        return values
    }

    /// A cheap fingerprint of exactly the data `getValuesObject()` returns (column keys and values per row in order, plus the
    /// `__localId__` / `__id__` of each row). Equal fingerprints mean the saved draft would be identical, so a save can be
    /// skipped without losing anything. It hashes the strings in place, with no dictionaries or JSON built.
    ///
    /// Strings are hashed by their exact UTF-8 bytes and length, not with `String`'s own hashing: that treats canonically
    /// equivalent text (e.g. "é" typed as one character or as "e" plus an accent) as equal, which would make an edit invisible.
    func contentFingerprint() -> Int {
        var hasher = Hasher()
        func combineExact(_ text: String) {
            var text = text
            hasher.combine(text.utf8.count)
            text.withUTF8 { hasher.combine(bytes: UnsafeRawBufferPointer($0)) }
        }
        func combineExact(optional text: String?) {
            if let text {
                hasher.combine(true)
                combineExact(text)
            } else {
                hasher.combine(false)
            }
        }
        let allRows = rows ?? []
        hasher.combine(allRows.count)
        for (index, row) in allRows.enumerated() {
            hasher.combine(row.columns.count)
            for column in row.columns {
                combineExact(column.key)
                combineExact(column.value)
            }
            let rowValue = values?[safe: index]
            combineExact(optional: rowValue?["__localId__"] as? String)
            combineExact(optional: rowValue?["__id__"] as? String)
        }
        return hasher.finalize()
    }

    func getJsonValues() -> String? {
        let values = self.getValuesObject()
        return values.getJson()
    }
    
    func getValueObject(from row: Rows, isDuplicate:Bool = false) -> [String: Any] {
        var value = [String: Any]()
        row.columns.forEach { column in
            value[column.key] = column.value
        }
        let newLocalId  = UUID().uuidString
        if value["__localId__"] == nil{
            value["__localId__"] = newLocalId
        }
        if isDuplicate{
            value["__localId__"] = newLocalId
            value["__id__"] = nil
        }
        return value
    }
    
}

struct Headers {
    var name: String
    var type: String
}

struct Rows {
    var sortUuid = UUID().uuidString
    var columns: [ColumnData]
}

struct ColumnData {
    var key: String
    var value: String
    var defaultValue:String?
    var uiType: String
    var dataType: String
    var files: [SSMedia]? = []
    var dropDownOptions: [DropdownOptions]?
    var generateDynamically:Bool? = false
    var dateFormat: String?
    var readonly:Bool?
    var scannable:Bool?
    let sortUuid = UUID().uuidString
    var rowSortUuid: String?
    var isPartOfFormula:Bool?

    func getUIType() -> FPDynamicUITypes {
        switch self.uiType {
        case "INPUT":
            return .INPUT
        case "TEXTAREA":
            return .TEXTAREA
        case "DROPDOWN":
            return .DROPDOWN
        case "DEFICIENCY":
            return .DROPDOWN
        case "RADIO":
            return .RADIO
        case "TABLE":
            return .TABLE
        case "TABLE_RESTRICTED":
            return .TABLE_RESTRICTED
        case "BUTTON_RADIO":
            return .BUTTON_RADIO
        case "ATTACHMENT":
            return .FILE
        case "CHECKBOX":
            return .CHECKBOX
        case "SIGNATURE_PAD":
            return .SIGNATURE_PAD
        case "AUTO_POPULATE":
            return .AUTO_POPULATE
        case "CHART":
            return .CHART
        case "LABEL":
            return .LABEL
        case "HIDDEN":
            return .HIDDEN
        default:
            return .INPUT
        }
    }
}

class DropdownOptions: NSObject, Codable, FetchableRecord, PersistableRecord {
    let key: FPStringBoolIntValue
    let value: FPStringBoolIntValue
    let label: FPStringBoolIntValue
    enum CodingKeys: String, CodingKey {
        case key
        case value
        case label
    }
    
    init(key: FPStringBoolIntValue, value: FPStringBoolIntValue, label: FPStringBoolIntValue) {
        self.key = key
        self.value = value
        self.label = label
    }
}



extension Date {
    
    public var comparativeDate : Date? {
        let todayDate = Date()
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: todayDate)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: self)
        
        var finalComponents = DateComponents()
        finalComponents.year = dateComponents.year ?? 0
        finalComponents.month = dateComponents.month ?? 0
        finalComponents.day = dateComponents.day ?? 0
        finalComponents.hour = timeComponents.hour ?? 0
        finalComponents.minute = timeComponents.minute ?? 0
        finalComponents.second = timeComponents.second ?? 0
        
        return calendar.date(from: finalComponents)
    }
}
