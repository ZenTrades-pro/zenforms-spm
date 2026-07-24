//
//  AssetFormMappingData.swift
//  crm
//
//  Created by apple on 08/05/24.
//  Copyright © 2024 SmartServ. All rights reserved.
//


import Foundation
import UIKit


class AssetFormMappingData: NSObject {
    var sqliteId: NSNumber?
    var assetId: NSNumber?
    var assetLocalId: NSNumber?
    var customFormId: NSNumber?
    var customFormLocalId: NSNumber?
    var isAssetSynced: Bool = true
    var fieldTemplateId: String?
    var sectionTemplateId: String?
    var formTemplateId: String?
    var tableRowId: String?
    var tableRowLocalId: String?
    var sectionId: NSNumber?
    var sectionLocalId: NSNumber?
    var companyId: NSNumber?
    var isSyncedToServer: Bool = true
    var addLinking: Bool = true
    var sectionLinking: Bool = false
    var deleteLinking: Bool = true
    var isNotConfirmed: Bool = false
    var isTableSaved: Bool = false
    // Scan tracking properties
    var zenScanLat: Double?
    var zenScanLong: Double?
    var zenScanAccuracy: Double?
    var zenScanTimestamp: NSNumber?
    var zenScanUserId: String?
    var zenScanStatus: String?

    override init() { }
    
    init(json:[String:Any], isForLocal: Bool) {
        super.init()
        self.companyId = FPUtility.getNumberValue( json["companyId"])
        self.sqliteId = FPUtility.getNumberValue( json["sqliteId"])
        self.fieldTemplateId = FPUtility.getSQLiteCompatibleStringValue( json["fieldTemplateId"], isForLocal: isForLocal)
        self.sectionTemplateId = FPUtility.getSQLiteCompatibleStringValue( json["sectionTemplateId"], isForLocal: isForLocal)
        self.formTemplateId = FPUtility.getSQLiteCompatibleStringValue( json["formTemplateId"], isForLocal: isForLocal)
        self.tableRowId = FPUtility.getSQLiteCompatibleStringValue( json["tableRowId"], isForLocal: isForLocal)
        self.tableRowLocalId = FPUtility.getSQLiteCompatibleStringValue( json["tableRowLocalId"], isForLocal: isForLocal)
        self.companyId = FPUtility.getNumberValue(json["companyId"])
        self.isAssetSynced = json["isAssetSynced"] as? Bool ?? false
        self.assetLocalId = FPUtility.getNumberValue(json["assetLocalId"])
        self.assetId = FPUtility.getNumberValue(json["assetId"])
        self.sectionId = FPUtility.getNumberValue(json["sectionId"])
        self.sectionLocalId = FPUtility.getNumberValue(json["sectionLocalId"])
        self.customFormId = FPUtility.getNumberValue(json["customFormId"])
        self.customFormLocalId = FPUtility.getNumberValue(json["customFormLocalId"])
        self.isSyncedToServer = json["isSyncedToServer"] as? Bool ?? false
        self.addLinking = json["addLinking"] as? Bool ?? false
        self.sectionLinking = json["sectionLinking"] as? Bool ?? false
        self.deleteLinking = json["deleteLinking"] as? Bool ?? false
        self.isNotConfirmed = json["isNotConfirmed"] as? Bool ?? false
        self.zenScanLat = json["zenScanLat"] as? Double
        self.zenScanLong = json["zenScanLong"] as? Double
        self.zenScanAccuracy = json["zenScanAccuracy"] as? Double
        self.zenScanTimestamp = FPUtility.getNumberValue(json["zenScanTimestamp"])
        self.zenScanUserId = json["zenScanUserId"] as? String
        self.zenScanStatus = json["zenScanStatus"] as? String
    }
}


