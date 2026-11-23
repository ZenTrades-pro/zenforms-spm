//
//  FPFieldDetailsCF.swift
//  crm
//
//  Created by Apple on 06/01/21.
//  Copyright © 2021 SmartServ. All rights reserved.
//

import UIKit
internal import SSMediaManager

protocol FPDynamicDataTypeCellDelegate: AnyObject {
    func selectedValue(for sectionIndex:Int, fieldIndex: Int, pickerIndex: Int?, value: String?, date: Date?, isSectionDuplicationField: Bool)
}

struct FPFieldOption {
    var key:String?
    var label:String?
    var value:String?
    var isSelected:Bool = false
}

enum FPFORM_DATE_FORMAT:String {
    case TIME = "hh:mm aa"
    case DATE = "MMM dd, yyyy"
    case DATE_TIME = "MMM dd, yyyy, hh:mm aa"
    case YEAR = "yyyy"
}


enum FPDynamicDataTypes:Int {
    case NUMERICAL = 0
    case DATE
    case TEXT
    case RADIO
    case TABLE
    case MAP
    case URL
    case ARRAY
    case SUMMARY
    case TIME
    case DATE_TIME
    case YEAR

}

enum FPDynamicUITypes:Int {
    case INPUT = 0
    case DROPDOWN
    case TEXTAREA
    case RADIO
    case TABLE
    case TABLE_RESTRICTED
    case BUTTON_RADIO
    case FILE
    case CHECKBOX
    case SIGNATURE_PAD
    case TABLE_SUMMARY
    case AUTO_POPULATE
    case CHART
    case LABEL
    case HIDDEN
    case SCANNER
}

public class FPFieldDetails: NSObject {
    public var sqliteId: NSNumber?
    public var objectStringId: String?
    public var objectId: NSNumber?
    public var templateId: String?
    public var name: String?
    public var displayName: String?
    public var sortPosition: String?
    public var uiType: String?
    public var fieldDescription: String?
    public var dataType: String?
    public var attachments: String?
    public var defaultValue: String?
    public var value: String?
    public var max: NSNumber?
    public var min: NSNumber?
    public var options: String?
    public var layout: String?
    public var reasons: String?
    var tableOptions: TableOptions?
    public var sectionId: NSNumber?
    public var sectionStringId: String?            // template ids are mongo string
    public var mandatory: Bool = false
    public var readOnly: Bool = false
    public var createdAt: String?
    public var updatedAt: String?
    public var locallyUpdatedAt: String?
    public var isSyncedToServer: Bool = true
    public var isDeleted: Bool = false
    public var isActive: Bool = true
    public var scannable: Bool = false
    public var sectionMappingName:String?
    var files:[SSMedia]?
    var deletedFiles = [String]()
    
    private let util = FPUtility()
    private lazy var cachedUIType: FPDynamicUITypes = resolveUIType()
    
    private var optionsDictionary: [String:Any]?
    func getOptionsDictionary() -> [String:Any]? {

        if let cached = optionsDictionary {
            return cached
        }

        guard let options = options else { return nil }

        let dict = options.getDictonary()
        optionsDictionary = dict
        return dict
    }
    
    public var isSectionDuplicationField: Bool {
        return getOptionsDictionary()?["isSectionDuplicationField"] as? Bool ?? false
    }
    
    public override init() {
    }
    
    init(json:[String:Any], isForLocal: Bool) {
        super.init()
        self.objectStringId = FPUtility.getSQLiteCompatibleStringValue(json["id"], isForLocal: isForLocal)
        self.templateId = FPUtility.getSQLiteCompatibleStringValue(json["templateId"], isForLocal: isForLocal)
        self.objectId = FPUtility.getNumberValue(json["id"])
        self.sqliteId = FPUtility.getNumberValue(json["sqliteId"])
        self.name = FPUtility.getSQLiteCompatibleStringValue(json["name"], isForLocal: isForLocal)
        self.displayName = FPUtility.getSQLiteCompatibleStringValue(json["displayName"], isForLocal: isForLocal)
        self.sortPosition = FPUtility.getSQLiteCompatibleStringValue(json["sortPosition"], isForLocal: isForLocal)
        self.uiType = FPUtility.getSQLiteCompatibleStringValue(json["uiType"], isForLocal: isForLocal)
        self.dataType = FPUtility.getSQLiteCompatibleStringValue(json["dataType"], isForLocal: isForLocal)
        self.defaultValue = util.getSQLiteSpecialCharsCompatibleString(value: json["defaultValue"], isForLocal: isForLocal)
        self.fieldDescription = FPUtility.getSQLiteCompatibleStringValue(json["description"], isForLocal: isForLocal)
        if let dict = json["options"] as? [String:Any] {
            let object = dict.getJson()
            self.options = FPUtility.getSQLiteCompatibleStringValue(object, isForLocal: isForLocal)
            
        }else if let string = json["options"] as? String {
            self.options = FPUtility.getSQLiteCompatibleStringValue(string, isForLocal: isForLocal)
        }
        
        let optionsDict = getOptionsDictionary()
        if cachedUIType == .TABLE || cachedUIType == .TABLE_RESTRICTED {
            var attachmentColumns: Set<String> = []

            if let columns = optionsDict?["columns"] as? [[String:Any]]{
                for column in columns {
                    if let columnType = column["uiType"] as? String, columnType == "ATTACHMENT"{
                        if let name = column["name"] as? String {
                            attachmentColumns.insert(name)
                        }
                    }
                }
            }
            if let arrValue = json["value"] as? [[String: Any]] {
                let dbArrValue = arrValue.map { dict in
                    var newDict = dict
                    for (key, value) in newDict {
                        if !attachmentColumns.contains(key),
                           let str = value as? String {
                            newDict[key] = util.getSQLiteSpecialCharsCompatibleString(value: str, isForLocal: true) ?? ""
                        }
                    }
                    return newDict
                }
                let object = dbArrValue.getJson()
                self.value = object
            } else if let strValue = json["value"] as? String {
                if strValue.getArray().count > 0{
                    let dbArrValue = strValue.getArray().map { dict in
                        var newDict = dict
                        for (key, value) in newDict {
                            if !attachmentColumns.contains(key),
                               let str = value as? String {
                                newDict[key] = util.getSQLiteSpecialCharsCompatibleString(value: str, isForLocal: true) ?? ""
                            }
                        }
                        return newDict
                    }
                    let object = dbArrValue.getJson()
                    self.value = object
                }
            } else {
                self.value = ""
            }
        } else if cachedUIType == .BUTTON_RADIO {
            self.value = util.getSQLiteSpecialCharsCompatibleString(value: json["value"], isForLocal: isForLocal)
            if let attachmentsValue = json["attachments"] as? [[String: Any]]{
                //online
                self.attachments = FPUtility.getSQLiteCompatibleStringValue(attachmentsValue.getJson(), isForLocal: isForLocal)
            }else if let dictAttachments = json["attachments"] as? [String: Any], let attachmentsValue = dictAttachments["files"] as? [[String: Any]]{
                //online
                self.attachments = FPUtility.getSQLiteCompatibleStringValue(attachmentsValue.getJson(), isForLocal: isForLocal)
            }else if let attachmentsValue = json["attachments"] as? String{
                //offline
                self.attachments = FPUtility.getSQLiteCompatibleStringValue(attachmentsValue, isForLocal: isForLocal)
            }else{
                self.attachments = nil
            }

        } else if cachedUIType == .CHECKBOX {
            if let dict = json["value"] as? [String:Any] {
                var newDict = dict
                for (key, value) in newDict {
                    if let str = value as? String {
                        newDict[key] = util.getSQLiteSpecialCharsCompatibleString(value: str, isForLocal: false) ?? ""
                    }
                }
                let object = newDict.getJson()
                self.value = FPUtility.getSQLiteCompatibleStringValue(object, isForLocal: isForLocal)
            }else {
                self.value = util.getSQLiteSpecialCharsCompatibleString(value: json["value"], isForLocal: isForLocal)
            }
            if self.value == nil, let dict = (json["options"] as? String)?.getDictonary()["checkboxOptions"] as? [[String:Any]] {
                var values: [String: Bool] = [:]
                for item in dict  {
                    if let key = item["key"] as? String {
                        values[key] = false
                    }
                }
                self.value = values.getJson()
            }
        } else if cachedUIType == .FILE{ // "ATTACHMENT"
            if let array = json["value"] as? [[String:Any]] , !array.isEmpty {
                self.value = array.getJson()
            } else if let array = (json["value"] as? String)?.getArray() as? [[String:Any]] , !array.isEmpty {
                self.value = array.getJson()
            } else if let val = json["value"] as? String, !val.isEmpty {
                self.value = val
            }else {
                self.value = nil
            }
        }else if cachedUIType == .CHART {
            if let dict = json["value"] as? [String:Any] {
                var newDict = dict
                for (key, value) in newDict {
                    if let str = value as? String {
                        newDict[key] = util.getSQLiteSpecialCharsCompatibleString(value: str, isForLocal: false) ?? ""
                    }
                }
                let object = newDict.getJson()
                self.value = FPUtility.getSQLiteCompatibleStringValue(object, isForLocal: isForLocal)
            }else {
                self.value = util.getSQLiteSpecialCharsCompatibleString(value: json["value"], isForLocal: isForLocal)
            }
        }
        else {
            self.value = util.getSQLiteSpecialCharsCompatibleString(value: json["value"], isForLocal: isForLocal)
        }
        
        self.max = FPUtility.getNumberValue(json["max"])
        self.min = FPUtility.getNumberValue(json["min"])
        self.sectionId = FPUtility.getNumberValue(json["sectionId"])
        self.sectionStringId = FPUtility.getSQLiteCompatibleStringValue(json["sectionId"], isForLocal: isForLocal)
        if let dict = json["layout"] as? [String:Any] {
            let object = dict.getJson()
            self.layout = FPUtility.getSQLiteCompatibleStringValue(object, isForLocal: isForLocal)
            
        }else if let string = json["layout"] as? String {
            self.layout = string
        }
        if let dict = json["reasons"] as? [[String:Any]] {
            let object = dict.getJson()
            self.reasons = FPUtility.getSQLiteCompatibleStringValue(object, isForLocal: isForLocal)
        } else if let string = json["reasons"] as? String {
            self.reasons = string
        } else {
            self.reasons = ""
        }
        self.mandatory = json["mandatory"] as? Bool ?? false
        if let readOnly = json["readOnly"] as? Bool{
            self.readOnly = readOnly
        }else if let readOnly = json["readonly"] as? Bool{
            self.readOnly = readOnly
        }
        self.createdAt = FPUtility.getSQLiteCompatibleStringValue(json["createdAt"], isForLocal: isForLocal)
        self.updatedAt = FPUtility.getSQLiteCompatibleStringValue(json["updatedAt"], isForLocal: isForLocal)
        self.isSyncedToServer = json["isSyncedToServer"] as? Bool ?? true
        if !FPUtility.isObjectEmpty(json["locallyUpdatedAt"]) {
            self.locallyUpdatedAt = FPUtility.getSQLiteCompatibleStringValue(json["locallyUpdatedAt"], isForLocal: isForLocal)
        }else if !FPUtility.isObjectEmpty(self.updatedAt) {
            self.locallyUpdatedAt = self.updatedAt
        }else {
            self.locallyUpdatedAt = FPUtility.getStringWithTZFormat(Date())
        }
        self.isActive = json["isActive"] as? Bool ?? true
        self.isDeleted = json["isDeleted"] as? Bool ?? false
        self.scannable = json["scannable"] as? Bool ?? false
        if let options = json["options"] as? [String: Any] {
            if let scannable = options["scannable"] as? Bool {
                self.scannable = scannable
            }
            if let sectionMappingName = options["columnMappingName"] as? String {
                self.sectionMappingName = sectionMappingName
            }
        }else if let options = (json["options"] as? String)?.getDictonary() {
            if let scannable = options["scannable"] as? Bool {
                self.scannable = scannable
            }
            if let sectionMappingName = options["columnMappingName"] as? String {
                self.sectionMappingName = sectionMappingName
            }
        }
        
    }
    
    func isTableAttchmentColumn(strColumnName: String?, attachmentColumns: Set<String>) -> Bool {
        guard let name = strColumnName else { return false }
        return attachmentColumns.contains(name)
    }
    
    func getJSON() -> [String:Any] {
        var json = [String: Any]()
        json["id"] = self.objectId
        json["templateId"] = self.templateId
        json["name"] = FPUtility.getSQLiteCompatibleStringValue(self.name , isForLocal: false)
        json["displayName"] = FPUtility.getSQLiteCompatibleStringValue(self.displayName, isForLocal: false)
        json["sortPosition"] = self.sortPosition
        json["uiType"] = self.uiType
        json["dataType"] = self.dataType
        json["description"] = self.fieldDescription
        json["defaultValue"] = ""
        if let value = self.defaultValue {
            json["defaultValue"] = util.getSQLiteSpecialCharsCompatibleString(value: value, isForLocal: false)
        }
        json["max"] = FPUtility.getStringValue(self.max)
        json["min"] = FPUtility.getStringValue(self.min)
        json["sectionId"] = self.sectionId
        if cachedUIType == .TABLE  || cachedUIType == .TABLE_RESTRICTED{
            // json["value"] = self.value?.getArray()
            let optionsDict = getOptionsDictionary()
            var attachmentColumn = ""
            if let columns = optionsDict?["columns"] as? [[String:Any]]{
                for column in columns {
                    if let columnType = column["uiType"] as? String, columnType == "ATTACHMENT"{
                        attachmentColumn = column["name"] as? String ?? ""
                    }
                }
            }
            var arrValues = [[String:Any]]()
            for arrValue in self.value?.getArray() ?? [] {
                var newDict = arrValue
                for (key, value) in newDict {
                    if let str = value as? String {
                        newDict[key] = util.fetchCompataibleSpecialCharsStringFromDB(strInput: str)
                    }
                }
                var updatedValue = newDict
                
                if let column3 = arrValue[attachmentColumn] as? String{
                    updatedValue[attachmentColumn] = column3.isEmpty ? "" : column3.getDictonary()
                    arrValues.append(updatedValue)
                }else{
                    arrValues.append(updatedValue)
                }
            }
            json["value"] = arrValues
        } else if cachedUIType == .BUTTON_RADIO {
            json["value"] = util.getSQLiteSpecialCharsCompatibleString(value: self.value, isForLocal: false)
            var arrayReasons = [[:]]
            var isCustomTemplateAdded = false
            self.reasons?.getArray().forEach({ newDict in
                
                var dict = newDict
                for (key, value) in dict {
                    if let str = value as? String {
                        dict[key] = util.getSQLiteSpecialCharsCompatibleString(value: str, isForLocal: false) ?? ""
                    }
                }
                
                var usableDict = [:]
                if let id = dict["id"] as? Int, id != 0 {
                    usableDict["id"] = id
                }
                usableDict["description"] = dict["description"]
                usableDict["displayName"] = dict["displayName"]
                usableDict["isSelected"] = dict["isSelected"] == nil ? false : dict["isSelected"] as? Bool
                usableDict["name"] = dict["name"]
                usableDict["reasonTemplateId"] = dict["reasonTemplateId"] == nil ? dict["id"] : dict["reasonTemplateId"]
                usableDict["recommendations"] = dict["recommendations"]
                usableDict["dueDate"] =  dict["dueDate"]
                usableDict["severity"] = dict["severity"]
                arrayReasons.append(usableDict)
                
                if let template = dict["reasonTemplateId"] as? String, template.contains("custom") && !isCustomTemplateAdded {
                    isCustomTemplateAdded = true
                }
            })
            if !isCustomTemplateAdded {
                var usableDict: [String:Any] = [:]
                let template = "custom_\(templateId ?? "")"
                usableDict["description"] = ""
                usableDict["displayName"] = template
                usableDict["isSelected"] = true
                usableDict["name"] = template
                usableDict["reasonTemplateId"] = template
                usableDict["recommendations"] = [:]
                usableDict["dueDate"] =  nil
                usableDict["severity"] = ""
                arrayReasons.append(usableDict)
            }
            if arrayReasons.first?.isEmpty ?? false {
                arrayReasons.remove(at: 0)
            }
            json["reasons"] = arrayReasons
            var attachmentJson = [String: Any]()

            var filesJson = [[String: Any]]()
            files?.forEach({ ssmedia in
                if ssmedia.serverUrl != nil && ssmedia.serverUrl != "" && (ssmedia.id == nil || ssmedia.id == "") {
                    var _json = [String: Any]()
                    _json["altText"] = ssmedia.name.replacingOccurrences(of: " ", with: "_")
                    _json["file"] = ssmedia.serverUrl
                    _json["type"] = ssmedia.mimeType
                    filesJson.append(_json)
                }
            })
            attachmentJson["filesToUpload"] = filesJson
            attachmentJson["filesToDelete"] = deletedFiles
            deletedFiles.forEach { id in
                if let array = self.attachments?.getArray()  {
                    let arr = array.filter {$0["id"] as? String != id}
                    attachmentJson["file"] = arr //need to test this one
                }
            }
            json["attachments"] = attachmentJson
        } else if cachedUIType == .FILE{ // "ATTACHMENT"
            var filesJson = [[String: Any]]()
            files?.forEach({ ssmedia in
                if ssmedia.serverUrl != nil && ssmedia.serverUrl != "" && (ssmedia.id == nil || ssmedia.id == "") {
                    var _json = [String: Any]()
                    _json["altText"] = ssmedia.name.replacingOccurrences(of: " ", with: "_")
                    _json["file"] = ssmedia.serverUrl
                    _json["type"] = ssmedia.mimeType
                    filesJson.append(_json)
                }
            })
            json["value"] = self.value
            json["filesToUpload"] = filesJson
            json["filesToDelete"] = deletedFiles
            deletedFiles.forEach { id in
                if let array = self.value?.getArray() as? [[String:Any]] {
                    let arr = array.filter {$0["id"] as? String != id}
                    self.value = arr.getJson()
                }
            }
        } else if cachedUIType == .CHECKBOX  || cachedUIType == .CHART{
            var dict = self.value?.getDictonary()
            if dict != nil{
                for i in dict!.values.indices {
                    if let value = dict!.values[i] as? String{
                        dict!.values[i] = util.getSQLiteSpecialCharsCompatibleString(value: value, isForLocal: false) ?? ""
                    }
                }
                json["value"] = dict
            }
        }else {
            json["value"] = ""
            if let value = self.value {
                json["value"] = util.getSQLiteSpecialCharsCompatibleString(value: self.value, isForLocal: false)
            }
        }
        json["options"] = self.getOptionsDictionary()
        json["mandatory"] = NSNumber.init(value:self.mandatory)
        json["readonly"] = NSNumber.init(value:self.readOnly)
        return json
    }
    
    func getUIType() -> FPDynamicUITypes {
        return cachedUIType
    }
    
    private func resolveUIType() -> FPDynamicUITypes {
        switch self.uiType {
        case "INPUT":
            return .INPUT
        case "TEXTAREA":
            return .TEXTAREA
        case "DROPDOWN":
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
        case "SCANNER":
            return .SCANNER
        default:
            return .HIDDEN
        }
    }
    
    
    func getDataType() -> FPDynamicDataTypes {
        switch self.dataType {
        case "NUMBER":
            return FPDynamicDataTypes.NUMERICAL
        case "TEXT":
            return FPDynamicDataTypes.TEXT
        case "DATE":
            return FPDynamicDataTypes.DATE
        case "TIME":
            return FPDynamicDataTypes.TIME
        case "DATE_TIME":
            return FPDynamicDataTypes.DATE_TIME
        case "YEAR":
            return FPDynamicDataTypes.YEAR
        case "RADIO":
            return FPDynamicDataTypes.RADIO
        case "MAP":
            return FPDynamicDataTypes.MAP
        case "TABLE":
            return FPDynamicDataTypes.TABLE
        case "SUMMARY":
            return FPDynamicDataTypes.SUMMARY
        case "ARRAY":
            return FPDynamicDataTypes.ARRAY
        case "URL":
            return FPDynamicDataTypes.URL
        default:
            return FPDynamicDataTypes.TEXT
        }
    }
    func getDropdownOptions() -> [FPFieldOption] {
        var array = [FPFieldOption]()
        let optionsDict = getOptionsDictionary()

        guard let dropDownOptions = optionsDict?["dropdownOptions"] as? [[String:Any]] else {
            return array
        }
        for item in dropDownOptions  {
            var strKey = ""
            if let value = item["key"] as? String{
                strKey = value
            }else if let value = item["key"] as? Int{
                strKey = "\(value)"
            }
            
            var strValue = ""
            if let value = item["value"] as? String{
                strValue = value
            }else if let value = item["value"] as? Int{
                strValue = "\(value)"
            }
            
            var strLable = ""
            if let value = item["label"] as? String{
                strLable = value
            }else if let value = item["label"] as? Int{
                strLable = "\(value)"
            }
            
            if strKey.isEmpty{
               strKey = strLable
            }
            array.append(FPFieldOption.init(key: strKey, label: strLable, value: strValue))
        }
        let selectOption = FPFieldOption.init(key:  FPLocalizationHelper.localize("SELECT"), label:  FPLocalizationHelper.localize("SELECT"), value:  FPLocalizationHelper.localize("SELECT"))
        array.insert(selectOption, at: 0)
        return array
    }
    func getSelectedOptionIndex() -> Int {
        return -1
    }
    func copyFPFieldDetails(_ isTemplate: Bool) -> FPFieldDetails {
        let item = FPFieldDetails()
        item.isActive = self.isActive
        item.isDeleted = self.isDeleted
        item.name = self.name
        item.displayName = self.displayName
        item.sortPosition = self.sortPosition
        item.uiType = self.uiType
        item.dataType = self.dataType
        item.defaultValue = self.defaultValue
        item.value = self.value
        item.max = self.max
        item.min = self.min
        item.options = self.options
        item.mandatory = self.mandatory
        item.readOnly = self.readOnly
        item.scannable = self.scannable
        item.sectionMappingName = self.sectionMappingName
        item.reasons = self.reasons
        item.attachments = self.attachments
        item.fieldDescription = self.fieldDescription
        
        //discussed with Smit and updated code.
      //  item.templateId = self.templateId
        //reverted again as no context found with discussion Smit

        if isTemplate {
            item.objectStringId = self.objectStringId
            item.templateId = self.objectStringId
        }else {
            item.sqliteId = self.sqliteId
            item.objectStringId = self.objectStringId
            item.objectId = self.objectId
            item.templateId = self.templateId
            item.sectionId = self.sectionId
            item.sectionStringId = self.sectionStringId
            item.isSyncedToServer = self.isSyncedToServer
        }
        item.createdAt = FPUtility.getStringWithTZFormat(Date())
        item.updatedAt = item.createdAt
        item.locallyUpdatedAt = item.createdAt
        return item
    }
    
    func copyPreviousFPFormFieldDetails() -> FPFieldDetails {
        let item = FPFieldDetails()
        item.isActive = self.isActive
        item.isDeleted = self.isDeleted
        item.name = self.name
        item.displayName = self.displayName
        item.sortPosition = self.sortPosition
        item.uiType = self.uiType
        item.dataType = self.dataType
        item.defaultValue = self.defaultValue
        item.value = self.value
        item.max = self.max
        item.min = self.min
        item.options = self.options
        item.mandatory = self.mandatory
        item.readOnly = self.readOnly
        item.scannable = self.scannable
        item.sectionMappingName = self.sectionMappingName
        item.reasons = self.reasons
        item.attachments = self.attachments
        item.fieldDescription = self.fieldDescription
        item.templateId = self.templateId
        item.createdAt = FPUtility.getStringWithTZFormat(Date())
        item.updatedAt = item.createdAt
        item.locallyUpdatedAt = item.createdAt
        return item
    }
    
    func getRadioOptions(inSection:Int,row:Int,uiType: FPDynamicUITypes) -> [FPFieldOption] {
        var array = [FPFieldOption]()
        let optionsDict = getOptionsDictionary()

        guard let radioOptions =
                (uiType == .CHECKBOX
                 ? optionsDict?["checkboxOptions"]
                 : optionsDict?["radioOptions"]) as? [[String:Any]] else {
            return array
        }
        for item in radioOptions  {
            var keyValue = item["key"] as? String ?? ""
            if keyValue.isEmpty{
                keyValue = item["label"] as? String ?? ""
            }
            var option = FPFieldOption.init(key:keyValue, label: item["label"] as? String, value: item["value"] as? String)
            let value = FPFormDataHolder.shared.getValue(inSection: inSection, atIndex: row)
            option.isSelected = (value == option.value)
            array.append(option)
        }
        return array
    }
    
    func getTableOptions(strJson: String) -> TableOptions? {
        var tableOptions = TableOptions()
        if let data = strJson.data(using: String.Encoding.utf8) {
            let jsonDecoder = JSONDecoder()
            do {
                tableOptions = try jsonDecoder.decode(TableOptions.self, from: data)
                return tableOptions
            } catch {
                debugPrint(error)
            }
        }
        return tableOptions
    }
    
    func getReasonsList(strJson: String) -> [FPReasons]? {
        var reasons = [FPReasons]()
        self.reasons = strJson
        if let data = strJson.data(using: String.Encoding.utf8) {
            let jsonDecoder = JSONDecoder()
            do {
                reasons = try jsonDecoder.decode([FPReasons].self, from: data)
                return reasons
            } catch {
                debugPrint(error)
            }
        }
        return reasons
    }
    
    func needToCheckMandatoryFlag() -> Bool{
        var needCheck: Bool = false
        if self.getUIType() == .INPUT{
            needCheck = self.getDataType() == .NUMERICAL ||
            self.getDataType() == .TEXT ||
            self.getDataType() == .DATE ||
            self.getDataType() == .DATE_TIME ||
            self.getDataType() == .TIME ||
            self.getDataType() == .YEAR
        }else{
            // RADIO / BUTTON_RADIO must be checked too: the server rejects a section with an unanswered
            // mandatory radio ("Please provide input for all the fields"), which the user then cannot locate.
            needCheck = self.getUIType() == .TEXTAREA || self.getUIType() == .SIGNATURE_PAD ||  self.getUIType() == .AUTO_POPULATE ||
            self.getUIType() == .RADIO || self.getUIType() == .BUTTON_RADIO
        }
        return needCheck
    }
}

