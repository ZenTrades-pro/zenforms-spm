//
//  FPFormsServiceManager.swift
//  crm
//
//  Created by SmartServ-Shristi on 6/29/20.
//  Copyright © 2020 SmartServ. All rights reserved.
//

import Foundation
internal import SSMediaManager

let FPFormMduleId = 33
let FPFormTemplateModuleId = 32

let commonFPFormTemplates = "fpFormTemplate"

extension Notification.Name {
    static let fpAttachmentUploadDidStart = Notification.Name("fpAttachmentUploadDidStart")
    static let fpAttachmentUploadDidFinish = Notification.Name("fpAttachmentUploadDidFinish")
}

private enum FPUploadStatusNotificationKey {
    static let fileName = "fileName"
}

class FPFormsServiceManager: NSObject {
    typealias completionHandler = () -> ()
    typealias successCompletionHandler = (_ success: Bool) -> ()
    typealias GetFormWithError = (_ form: FPForms?, _ _error: Error?) -> ()
    typealias GetFormsWithError = (_ forms: [FPForms], _ _error: Error?) -> ()
    typealias errorCompletionHandler = (Error?) -> ()
    typealias GetCheckListWithError = (_ checkList: [String:Any], _ _error: Error?) -> ()
    typealias GetRecomendationListWithError = (_ recomendation: [String], _ _error: Error?) -> ()
    typealias GetInspectionFormsCompletionBlock = (_ forms: [FPForms], _ total:Int, _ error: Error?) -> Void
    
    static let serialQueueUpsertFPForms = DispatchQueue(label: "com.queue.serialQueueUpsertFPForms")

    private static let fpformQueue = DispatchQueue(label: "com.fp.form.sync", qos: .userInitiated)
    
    static let router = FPRouter<FPFormsApiName>()
    
    private static let computedFieldsTTL: TimeInterval = 300 // 5 minutes

    /// Call after a successful form/section save to force a fresh fetch next time the form opens.
    static func invalidateComputedFieldsCache(ticketID: String) {
        UserDefaults.standard.removeObject(forKey: "computedFields_fetchedAt_\(ticketID)")
    }

    class func getComputedFields(ticketID: String) {
        guard FPUtility.isConnectedToNetwork() else { return }

        // Skip API call if cached data exists and is fresh (within TTL)
        let tsKey = "computedFields_fetchedAt_\(ticketID)"
        if let lastFetch = UserDefaults.standard.object(forKey: tsKey) as? Date,
           Date().timeIntervalSince(lastFetch) < computedFieldsTTL,
           let existing = UserDefaults.computedFields?[ticketID] as? [String: Any], !existing.isEmpty {
            return
        }

        var parms: [String: Any] = ["ticketId": ticketID]
        router.request(.getComputedFields(parms)) { json, data, response, error in
            if let tokens = (json?["result"] as? [String: Any])?["tokens"] as? [String: Any] {
                var fields = UserDefaults.computedFields ?? [:]
                fields[ticketID] = tokens
                UserDefaults.computedFields = fields
                UserDefaults.standard.set(Date(), forKey: tsKey)
            }
        }
    }
    
    class func getZenFormConstants(){
        guard FPUtility.isConnectedToNetwork() else {
            return
        }
        guard let userId  = UserDefaults.standard.string(forKey: "userId"), !userId.isEmpty, userId != "0" else { return  }
        let parms:[String:Any] = [:]
        router.request(.getFPFormConstants(parms)) { json, data, response, error in
            if let result = json?["result"] as? [String:Any]{
                UserDefaults.dictConstants = result
            }
        }
    }
    
    class func preComileFPForm(form:FPForms, ticketID:String, completion: completionHandler? = nil) {
        guard FPUtility.isConnectedToNetwork(), let formId = form.objectId else {
            completion?()
            return
        }
        var parms:[String:Any] = [:]
        parms["ticketId"] = ticketID
        router.request(.preCompileFPForm(formId, params: parms)) { (json, _data, response, _error) in
            if let error = _error {
                debugPrint(error.localizedDescription)
            }
            completion?()
        }
    }
    
    class func addSignaturesToFPForm(showLoader: Bool, form:FPForms, ticketID:NSNumber, params : [String: Any], completion: @escaping errorCompletionHandler) {
        
        if showLoader {
            DispatchQueue.main.async {
                FPUtility.showHUDWithLoadingMessage()
            }
        }
        
        guard FPUtility.isConnectedToNetwork(), let formId = form.objectId else {
            if showLoader {
                FPUtility.hideHUD()
            }
            completion(nil)
            return
        }
        router.request(.addSignaturesToFPForm(formId, params: params)) { (json, _data, response, error) in
            if showLoader {
                FPUtility.hideHUD()
            }
            if error == nil{
                guard let result = json?["result"] as? [String: Any] else {
                    let tempError = FPErrorHandler.getError(code: 401, message: FPLocalizationHelper.localize("lbl_Something_went_wrong"))
                    FPUtility.printErrorAndShowAlert(error: tempError)
                    completion(error)
                    return
                }
                completion(nil)
            } else {
                FPUtility.printErrorAndShowAlert(error: error)
                completion(error)
            }
        }
    }
    
    
    class func upsertLocalData(ticketId: NSNumber, moduleId: Int, form: FPForms, completion: @escaping GetFormWithError) {
        FPFormsDatabaseManager().upsert(form: form, ticketId: ticketId, moduleId: moduleId) { nform, success in
            if success {
                completion(nform, nil)
            }else {
                let tempError = FPErrorHandler.getError(code: 401, message: FPLocalizationHelper.localize("lbl_Something_went_wrong"))
                completion(nil, tempError)
            }
        }
    }
    
    
    class func upsertServerData(ticketId: NSNumber, moduleId: Int, localForm: FPForms, serverform:FPForms, completion: @escaping GetFormWithError) {
        FPFormsDatabaseManager().updateServerFormOnly(form: serverform, ticketId: ticketId) { form, success in
            let serverSections = serverform.sections ?? []
            let localSqliteId = localForm.sqliteId ?? 0
            let group = DispatchGroup()
            serverSections.forEach { section in
                section.moduleEntityLocalId = localSqliteId
                if let localSection = localForm.sections?.filter({$0.sortPosition == section.sortPosition}).first {
                    section.sqliteId = localSection.sqliteId
                    FPSectionDetailsDatabaseManager().deleteSectionDetails(forArray: [localSection])
                    group.enter()
                    FPSectionDetailsDatabaseManager().insertSectionDetails([section], localSqliteId) { _ in
                        group.leave()
                    }
                }
            }
            // Wait for all section writes to commit before fetching — prevents the list
            // pre-fetch in formUpdated(completion:) from reading stale section data.
            group.notify(queue: .global(qos: .userInitiated)) {
                FPFormsDatabaseManager().fetchFormBy(sqliteId: localSqliteId, shouldIncludeMedia: false, moduleId: FPFormMduleId) { form in
                    completion(form, nil)
                }
            }
        }
    }
    
    /**
     This function is used to update partial section of form only
     */
    
    class func upsertDataForPartialSave(ticketId: NSNumber, moduleId: Int, section: FPSectionDetails, completion: @escaping GetFormWithError) {
        FPFormsDatabaseManager().upsertForPartialSave(section: section, ticketId: ticketId, moduleId: moduleId) { success in
            if success {
                completion(FPForms(), nil)
            }else {
                let tempError = FPErrorHandler.getError(code: 401, message: FPLocalizationHelper.localize("lbl_Something_went_wrong"))
                completion(nil, tempError)
            }
        }
        
    }
    
    class func markFormUnsync(form: FPForms, ticketId: NSNumber, moduleId: Int , completion: @escaping ((Bool) -> ())) {
        
        FPFormsDatabaseManager().markPartialFormNeedtoSync(form: form, ticketId: ticketId, moduleId: moduleId, shouldUpdateBySqliteId: true) { success in
            completion(success)
        }
    }
    
    class func markFormLocallySync(form: FPForms, ticketId: NSNumber, completion: @escaping ((Bool) -> ())) {
        FPFormsDatabaseManager().markFormLocallySync(form: form, ticketId: ticketId, completion: completion)
    }
    
    class func deleteFormLocally(form: FPForms, ticketId:NSNumber, moduleId: Int, completion: @escaping GetFormWithError) {
        DispatchQueue.global(qos: .userInitiated).async {
            FPFormsDatabaseManager().deleteFormBySqliteId(form: form, moduleId: moduleId, ticketId: ticketId) { success in
                if success {
                    let fid = form.sqliteId?.stringValue ?? form.localClientId ?? "0"
                    FPTableDraftDatabaseManager().deleteAllDraftsForForm(ticketId: ticketId.stringValue, formLocalId: fid)
                    completion(form, nil)
                }else {
                    let tempError = FPErrorHandler.getError(code: 401, message: FPLocalizationHelper.localize("lbl_Something_went_wrong"))
                    completion(form, tempError)
                }
            }
        }
    }
    
    class func fetchFormBy(objectId:String, completion:@escaping (_ form: FPForms?) -> ()) {
        FPFormsDatabaseManager().fetchFormBy(objectId: objectId, moduleId: FPFormMduleId, shouldIncludeMedia: true) { form in
            completion(form)
        }
    }
    
    class func getCustomFPForms(ticketId:NSNumber, serviceAddressId:NSNumber, sectionDelta:Bool = false, shouldFetchOnline:Bool, showLoader: Bool, completion: @escaping (_ forms: [FPForms]) -> Void) {
        if showLoader {
            DispatchQueue.main.async {
                FPUtility.showHUDWithLoadingMessage()
            }
        }
        if shouldFetchOnline {
            self.fetchCustomFormsForTicket(ticketId: ticketId, serviceAddressId: serviceAddressId, sectionDelta: sectionDelta, showLoader: showLoader) { (result) in
                if showLoader {
                    FPUtility.hideHUD()
                }
                completion(result)
            }
        }else {
            FPFormsDatabaseManager().fetchFormsFromLocal(ticketId: ticketId, moduleId: FPFormMduleId) { fpForms in
                if showLoader {
                    FPUtility.hideHUD()
                }
                completion(fpForms ?? [])
            }
        }
    }
    
    
    class func fetchCustomFormsForTicket(ticketId:NSNumber, serviceAddressId:NSNumber, sectionDelta:Bool, showLoader: Bool, completion: @escaping (_ forms: [FPForms]) -> Void) {
        if showLoader {
            DispatchQueue.main.async {
                FPUtility.showHUDWithLoadingMessage()
            }
        }
        guard FPUtility.isConnectedToNetwork() else {
            if showLoader {
                FPUtility.hideHUD()
            }
            completion([FPForms]())
            return
        }
        
        var params = [String: Any]()
        params["ticketId"] = ticketId
        if sectionDelta{
            params["sectionDelta"] = sectionDelta
        }
        router.request(.getCustomFormsForTicket(params)) { (json, _data, response, _error) in
            DispatchQueue.global(qos: .background).async {
                var fpFormsArray = [FPForms]()
                if _error == nil {
                    guard let results = json?["result"] as? [[String: Any]] else {
                        return
                    }
                    let group = DispatchGroup()
                    var tmpArr = [String]()
                    tmpArr = UserDefaults.standard.object(forKey: "arrDownloadingInspectionForms") as? [String] ?? []
                    for dict in results {
                        group.enter()
                        if let currentStatus = dict["downloadStatus"] as? String, currentStatus == "IN_PROGRESS", let formId = dict["id"] as? String, !formId.isEmpty, !tmpArr.contains(formId){
                            tmpArr.append(formId)
                        }
                        let fpForm = FPForms(dict: dict, isForLocal: true)
                        fpFormsArray.append(fpForm)
                        if sectionDelta{
                            FPFormsDatabaseManager().updateForm(form: fpForm, ticketId: ticketId, moduleId: FPFormMduleId, shouldUpdateBySqliteId: false, sectionDelta: sectionDelta) { _ , success in
                                group.leave()
                            }
                        }else{
                            group.leave()
                        }
                    }
                    group.notify(queue: .main) {
                        if showLoader {
                            FPUtility.hideHUD()
                        }
                        UserDefaults.standard.set(tmpArr,forKey: "arrDownloadingInspectionForms")
                        completion(fpFormsArray)
                    }
                } else {
                    if showLoader {
                        FPUtility.hideHUD()
                    }
                    completion(fpFormsArray)
                }
            }
        }
    }
    
    
    class func getFilesFromForm(form: FPForms){
        // Reset data holder to clear any previous form's attachments before loading new form
        FPFormDataHolder.shared.resetData()
        // Set the session ID to this form's sqliteId to properly associate attachments with this form
        FPFormDataHolder.shared.currentFormSessionId = form.sqliteId?.stringValue ?? UUID().uuidString
        FPFormDataHolder.shared.customForm = form
        FPFormDataHolder.shared.getFilesFromValue(form: form)
        
    }
    
    class func getProceessedForm(isNew:Bool)->FPForms{
        return FPFormDataHolder.shared.getProcessedForm(isNew:isNew)!
    }
    
    
    class func uploadMediasAttached(completion: @escaping (_ status: Bool) -> Void) {
        guard FPUtility.isConnectedToNetwork() else {
            FPFormDataHolder.shared.saveFilesForOfflineSupport()
            completion(true)
            return
        }
        let allFiles = FPFormDataHolder.shared.getFiledFilesArray()
        var pendingUploads: [(indexPath: IndexPath, mediaIndex: Int, media: SSMedia)] = []
        for (indexPath, medias) in allFiles {
            for (idx, media) in medias.enumerated() {
                if media.filePath != nil && (media.serverUrl == nil || media.serverUrl == "") {
                    pendingUploads.append((indexPath: indexPath, mediaIndex: idx, media: media))
                }
            }
        }
        compressAndUploadMedia(pendingUploads: pendingUploads, completion: completion)
    }

    class func uploadMediasAttachedForCurrentSection(section: Int, completion: @escaping (_ status: Bool) -> Void) {
        let allFiles = FPFormDataHolder.shared.getFiledFilesArrayForSection(section: section)
        guard FPUtility.isConnectedToNetwork() else {
            FPFormDataHolder.shared.saveFilesForOfflineSupportPartialSection(sectionfiledFiles: allFiles)
            completion(true)
            return
        }
        var pendingUploads: [(indexPath: IndexPath, mediaIndex: Int, media: SSMedia)] = []
        for (indexPath, medias) in allFiles {
            for (idx, media) in medias.enumerated() {
                if media.filePath != nil && (media.serverUrl == nil || media.serverUrl == "") {
                    pendingUploads.append((indexPath: indexPath, mediaIndex: idx, media: media))
                }
            }
        }
        compressAndUploadMedia(pendingUploads: pendingUploads, completion: completion)
    }

    // Two-phase upload to balance memory safety and performance:
    // Phase 1 — compress sequentially: only one full-res UIImage (~47 MB) in memory at a time,
    //           preventing the OOM crashes seen with the original concurrent approach.
    // Phase 2 — upload with a sliding window: Alamofire streams from the file URL so no UIImage
    //           is held in memory. At most maxConcurrentUploads uploads run at a time — prevents
    //           URLSession thread explosion and backend saturation for large batches (50-500 images).
    //           Each completion kicks off the next pending item (all on main queue, no locks needed).
    private static let maxConcurrentUploads = 4

    private static func uploadDisplayName(for media: SSMedia) -> String {
        let normalized = media.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.isEmpty {
            return normalized
        }
        if let filePath = media.filePath, !filePath.isEmpty {
            return URL(fileURLWithPath: filePath).lastPathComponent
        }
        return FPLocalizationHelper.localize("lbl_attachment")
    }

    private static func postUploadStatusNotification(name: Notification.Name, media: SSMedia) {
        let fileName = uploadDisplayName(for: media).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fileName.isEmpty else { return }

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: name,
                object: nil,
                userInfo: [FPUploadStatusNotificationKey.fileName: fileName]
            )
        }
    }

    private static func compressAndUploadMedia(
        pendingUploads: [(indexPath: IndexPath, mediaIndex: Int, media: SSMedia)],
        completion: @escaping (_ status: Bool) -> Void
    ) {
        guard !pendingUploads.isEmpty else {
            DispatchQueue.main.async { completion(true) }
            return
        }
        compressMediasSequentially(pendingUploads: pendingUploads) { compressedUploads in
            let group = DispatchGroup()
            var nextIndex = 0

            // startNext() and all mutations of nextIndex run exclusively on main queue — no locks needed.
            func startNext() {
                guard nextIndex < compressedUploads.count else { return }
                let item = compressedUploads[nextIndex]
                nextIndex += 1
                group.enter()
                postUploadStatusNotification(name: .fpAttachmentUploadDidStart, media: item.media)
                SSMediaManager.shared.uploadCompressedFile(
                    media: item.media,
                    baseS3URL: s3EnvironmentString,
                    indexPath: item.indexPath,
                    index: item.mediaIndex
                ) { json, data, response, error, indexPath, index in
                    // FPFormDataHolder.shared is a struct singleton — always mutate on main queue.
                    DispatchQueue.main.async {
                        if error == nil, let s3URL = json?["s3URL"] as? String {
                            FPFormDataHolder.shared.updateServerUrl(
                                url: s3URL,
                                key: indexPath ?? item.indexPath,
                                index: index ?? item.mediaIndex
                            )
                            if let filePath = item.media.filePath {
                                ZenForms.shared.failedFilesTrackingDelegate?.removeFromTracking(filePath: filePath)
                            }
                        } else {
                            if let filePath = item.media.filePath {
                                ZenForms.shared.failedFilesTrackingDelegate?.trackFailedUpload(filePath: filePath)
                                FPFormDataHolder.shared.failedUploadFilePaths.append(filePath)
                            }
                        }
                        postUploadStatusNotification(name: .fpAttachmentUploadDidFinish, media: item.media)
                        // Start next before leave so group count never hits 0 prematurely.
                        startNext()
                        group.leave()
                    }
                }
            }

            // Seed the initial window — at most maxConcurrentUploads uploads start immediately.
            for _ in 0..<min(maxConcurrentUploads, compressedUploads.count) { startNext() }
            group.notify(queue: .main) { completion(true) }
        }
    }

    private static func compressMediasSequentially(
        pendingUploads: [(indexPath: IndexPath, mediaIndex: Int, media: SSMedia)],
        completion: @escaping ([(indexPath: IndexPath, mediaIndex: Int, media: SSMedia)]) -> Void
    ) {
        guard !pendingUploads.isEmpty else { completion([]); return }

        // Single pre-allocated array — append is O(1) amortised vs O(N) per step with `result + [item]`.
        var result: [(indexPath: IndexPath, mediaIndex: Int, media: SSMedia)] = []
        result.reserveCapacity(pendingUploads.count)

        // compressNext and all result mutations run on main queue (compressMediaFile completion is main).
        func compressNext(index: Int) {
            guard index < pendingUploads.count else { completion(result); return }
            let item = pendingUploads[index]
            SSMediaManager.shared.compressMediaFile(media: item.media) { compressedMedia, success in
                if success {
                    result.append((indexPath: item.indexPath, mediaIndex: item.mediaIndex, media: compressedMedia))
                } else {
                    // Compression left no valid file on disk — never hand this to the upload phase.
                    // Same failure-tracking path a failed network upload already uses.
                    if let filePath = item.media.filePath {
                        ZenForms.shared.failedFilesTrackingDelegate?.trackFailedUpload(filePath: filePath)
                                FPFormDataHolder.shared.failedUploadFilePaths.append(filePath)
                    }
                    let error = NSError(domain: "SSMediaManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Media compression failed to produce a valid file"])
                    FPUtility.logMediaWriteFailure(error, context: "FPFormsServiceManager.compressMediasSequentially")
                }
                compressNext(index: index + 1)
            }
        }

        compressNext(index: 0)
    }
    
    class func routeToOfflinePartialSaveCustomFormSection(ticketId: NSNumber, section: FPSectionDetails, form: FPForms, completion: @escaping GetFormWithError) {
        DispatchQueue.global(qos: .utility).async {
            form.isSyncedToServer = false
            section.isSyncedToServer = false
            self.markFormUnsync(form: form, ticketId: ticketId, moduleId: FPFormMduleId) { _ in
                let results = AssetFormLinkingDatabaseManager().fetchAssetLinkigDataFor(customForm: form)
                for linkdata in results{
                    let updated = linkdata
                    updated.isNotConfirmed = false
                    AssetFormLinkingDatabaseManager().upsert(item: updated){  _ in }
                }
                section.moduleEntityLocalId = form.sqliteId
                self.upsertDataForPartialSave(ticketId: ticketId, moduleId: FPFormMduleId, section: section) { form, error in
                    completion(form, error)
                }
            }
        }
    }
    
    /**
     This function is used to save partial function api where we pass forms id, template Id and section object
     */
    
    class func routeToPartialSaveCustomFormSection(ticketId: NSNumber, section: FPSectionDetails, justScannedSection:Bool = false, form: FPForms, sectionIndex: Int, setSynced: Bool, assetLinkDetail:[String:Any]? = nil, completion: @escaping GetFormWithError) {
        
        let assetdbMnger = AssetFormLinkingDatabaseManager()
        guard FPUtility.isConnectedToNetwork() else {
            fpformQueue.async {
                form.isSyncedToServer = false
                section.isSyncedToServer = false
                self.markFormUnsync(form: form, ticketId: ticketId, moduleId: FPFormMduleId) { _ in
                    if !justScannedSection{
                        let results = assetdbMnger.fetchAssetLinkigDataFor(customForm: form)
                        for linkdata in results {
                            linkdata.isNotConfirmed = false
                            assetdbMnger.upsert(item: linkdata) { _ in }
                        }
                    }
                    section.moduleEntityLocalId = form.sqliteId
                    self.upsertDataForPartialSave(ticketId: ticketId, moduleId: FPFormMduleId, section: section) { form, error in
                        DispatchQueue.main.async {
                            completion(form, error)
                        }
                    }
                }
            }
            return
      }

       var params = [String: Any]()
       if let objectId = form.objectId, let intvalue = Int(objectId) {
           params["moduleEntityId"] = intvalue
       }else{
           params["moduleEntityId"] = form.objectId
       }
       params["ticketId"] = ticketId
       params["sectionDetails"] = section.getJSON()
       
       if let data = assetLinkDetail, !data.isEmpty{
           params["assetLinkingDetails"] = data
       }
       if let deletedSections = FPFormDataHolder.shared.customForm?.deletedSections, !deletedSections.isEmpty{
           let arrSections = deletedSections.components(separatedBy: ",")
           let delSections = arrSections.compactMap({Int($0)})
           if !delSections.isEmpty{
               params["delete"] = ["section":delSections]
           }
       }
        router.request(.updateCustomFormSection(params)) { (json, _data, response, _error ) in
            fpformQueue.async {
                guard _error == nil else {
                    FPUtility.hideHUD()
                    DispatchQueue.main.async {
                        completion(nil, _error)
                    }
                    return
                }
               
                guard let result = json?["result"] as? [String: Any] else {
                    let tempError = FPErrorHandler.getError(code: 401, message: FPLocalizationHelper.localize("lbl_Something_went_wrong"))
                    return
                }
                var updatedSection = section
                let formOnline = FPForms.init(dict: result, isForLocal: true)
                
                if let localSection = FPFormDataHolder.shared.getSection(at: sectionIndex){
                    if let serverSection = formOnline.sections?.first(where: { $0.sortPosition == localSection.sortPosition }) as? FPSectionDetails{
                        serverSection.sqliteId = localSection.sqliteId
                        
                        // MARK: Reconcile local ↔ server fields safely
                        var localByObjectId: [Int: NSNumber] = [:]
                        var localBySortPosition: [String: NSNumber] = [:]
                        
                        localByObjectId.reserveCapacity(localSection.fields.count)
                        localBySortPosition.reserveCapacity(localSection.fields.count)
                        
                        // Build lookup tables
                        for field in localSection.fields {
                            guard let sqliteId = field.sqliteId else { continue }
                            if let objectId = field.objectId?.intValue {
                                localByObjectId[objectId] = sqliteId
                            }
                            if let sort = field.sortPosition {
                                localBySortPosition[sort] = sqliteId
                            }
                        }
                        
                        // Attach sqliteId to server fields
                        for i in 0..<serverSection.fields.count {
                            
                            var field = serverSection.fields[i]
                            
                            if let objectId = field.objectId?.intValue,
                               let sqliteId = localByObjectId[objectId] {
                                field.sqliteId = sqliteId
                            }
                            else if let sort = field.sortPosition,
                                    let sqliteId = localBySortPosition[sort] {
                                field.sqliteId = sqliteId
                            }
                            serverSection.fields[i] = field
                        }
                        
                        
                        //make sure assetId field at last---
                        if let index = serverSection.fields.firstIndex(where: {
                            $0.getUIType() == .HIDDEN && $0.name == "assetId"
                        }) {
                            let field = serverSection.fields.remove(at: index)
                            serverSection.fields.append(field)
                        }
                        
                        var sections = FPFormDataHolder.shared.sections ?? []
                        var replaceIndex: Int?
                        
                        if let localObjectId = localSection.objectId {
                            replaceIndex = sections.firstIndex { $0.objectId == localObjectId }
                        }
                        
                        if replaceIndex == nil, let sort = localSection.sortPosition {
                            replaceIndex = sections.firstIndex { $0.sortPosition == sort }
                        }
                        
                        if let idx = replaceIndex {
                            sections[idx] = serverSection
                        } else {
                            sections.append(serverSection)
                        }
                        
                        // Fix: Specifically reconcile the Scanner section's sortPosition if it changed on server
                        if let localScanner = FPFormDataHolder.shared.getScannebleSection(){
                            if let serverScanner = formOnline.sections?.first(where: { $0.objectId == localScanner.objectId }) {
                                localScanner.sortPosition = serverScanner.sortPosition
                                if let scannerIdx = sections.firstIndex(where: { $0.objectId == localScanner.objectId }) {
                                    sections[scannerIdx] = localScanner
                                }
                                // Immediately update local DB for the scanner section to reflect new sortPosition
                                FPSectionDetailsDatabaseManager().updateScannerSortPositionToDB(localScanner)
                            }
                        }
                        
                        FPFormDataHolder.shared.sections = sections
                        
                        updatedSection = serverSection
                    }
                }
                
                if !justScannedSection{
                    //after scanning a section, we should not update all linking
                    let results = assetdbMnger.fetchAssetLinkigDataFor(customForm: form)
                    let formId = NSNumber(value: Int(formOnline.objectId ?? "") ?? 0)
                    
                    for linkdata in results {
                        linkdata.customFormId = formId
                        linkdata.isSyncedToServer = true
                        linkdata.isNotConfirmed = false
                        
                        if linkdata.deleteLinking {
                            assetdbMnger.deleteMappingData(linkdata) { _ in }
                        } else {
                            assetdbMnger.upsert(item: linkdata) { _ in }
                        }
                    }
                }
                
                updatedSection.moduleEntityLocalId = form.sqliteId
                updatedSection.isSyncedToServer = true
                self.upsertDataForPartialSave(ticketId: ticketId, moduleId: FPFormMduleId, section: updatedSection) { form, error in
                    DispatchQueue.main.async {
                        completion(form, error)
                    }
                }
            }
        }
    }


    static func uploadTableAttachments(
        medias: [TableMedia] = [],
        completion: @escaping (_ status: Bool) -> Void
    ) {
        guard FPUtility.isConnectedToNetwork() else {
            completion(true)
            return
        }
        let mediaArray = medias.isEmpty ? FPFormDataHolder.shared.tableMedia : medias
        compressAndUploadTableMedia(tableMediaArray: mediaArray, completion: completion)
    }

    static func uploadTableAttachmentsForCurrentSection(
        section: Int,
        medias: [TableMedia] = [],
        completion: @escaping (_ status: Bool) -> Void
    ) {
        guard FPUtility.isConnectedToNetwork() else {
            completion(true)
            return
        }
        let mediaArray = medias.isEmpty
            ? FPFormDataHolder.shared.tableMedia.filter { $0.parentTableIndex?.section == section }
            : medias
        compressAndUploadTableMedia(tableMediaArray: mediaArray, completion: completion)
    }

    // Two-phase upload for table field media — mirrors compressAndUploadMedia for regular attachments.
    // Phase 1: sequential compression (one UIImage in memory at a time).
    // Phase 2: sliding window uploads (Alamofire streams from disk, no UIImage in memory).
    private static func compressAndUploadTableMedia(
        tableMediaArray: [TableMedia],
        completion: @escaping (_ status: Bool) -> Void
    ) {
        var pendingItems: [(tableMedia: TableMedia, mediaIndex: Int, media: SSMedia)] = []
        for tableMedia in tableMediaArray {
            for (idx, media) in tableMedia.mediaAdded.enumerated() {
                guard media.filePath != nil else { continue }
                pendingItems.append((tableMedia: tableMedia, mediaIndex: idx, media: media))
            }
        }
        guard !pendingItems.isEmpty else {
            DispatchQueue.main.async { completion(true) }
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            compressTableItemsSequentially(pendingItems: pendingItems) { compressedItems in
                let group = DispatchGroup()
                var nextIndex = 0
                func startNext() {
                    guard nextIndex < compressedItems.count else { return }
                    let item = compressedItems[nextIndex]
                    nextIndex += 1
                    guard let parentIndex = item.tableMedia.parentTableIndex,
                          let childIndex = item.tableMedia.childTableIndex else {
                        startNext()
                        return
                    }
                    group.enter()
                    postUploadStatusNotification(name: .fpAttachmentUploadDidStart, media: item.media)
                    SSMediaManager.shared.uploadCompressedFile(
                        media: item.media,
                        baseS3URL: s3EnvironmentString,
                        indexPath: parentIndex,
                        index: childIndex.section - 1
                    ) { json, _, _, error, _, _ in
                        DispatchQueue.main.async {
                            if error == nil, let s3URL = json?["s3URL"] as? String {
                                FPFormDataHolder.shared.cacheLocalFile(at: item.media.filePath)
                                var tempMedia = item.media
                                tempMedia.filePath = nil
                                tempMedia.serverUrl = s3URL
                                // Always read the current TableMedia from the data holder rather than
                                // the snapshot captured at flatten time. All completions run serially
                                // on main, so this fetch reflects every prior upload's serverUrl update.
                                let currentTableMedia = FPFormDataHolder.shared.tableMedia.first(where: {
                                    $0.parentTableIndex == item.tableMedia.parentTableIndex &&
                                    $0.childTableIndex == item.tableMedia.childTableIndex &&
                                    $0.columnIndex == item.tableMedia.columnIndex
                                }) ?? item.tableMedia
                                var tempTableMedia = currentTableMedia
                                tempTableMedia.mediaAdded[item.mediaIndex] = tempMedia
                                FPFormDataHolder.shared.updateTableFieldValue(media: tempTableMedia, isPostUpload: true)
                                if let filePath = item.media.filePath {
                                    ZenForms.shared.failedFilesTrackingDelegate?.removeFromTracking(filePath: filePath)
                                }
                            } else {
                                if let filePath = item.media.filePath {
                                    ZenForms.shared.failedFilesTrackingDelegate?.trackFailedUpload(filePath: filePath)
                                FPFormDataHolder.shared.failedUploadFilePaths.append(filePath)
                                }
                            }
                            postUploadStatusNotification(name: .fpAttachmentUploadDidFinish, media: item.media)
                            startNext()
                            group.leave()
                        }
                    }
                }
                for _ in 0..<min(maxConcurrentUploads, compressedItems.count) { startNext() }
                group.notify(queue: .main) { completion(true) }
            }
        }
    }

    private static func compressTableItemsSequentially(
        pendingItems: [(tableMedia: TableMedia, mediaIndex: Int, media: SSMedia)],
        completion: @escaping ([(tableMedia: TableMedia, mediaIndex: Int, media: SSMedia)]) -> Void
    ) {
        guard !pendingItems.isEmpty else { completion([]); return }
        var result: [(tableMedia: TableMedia, mediaIndex: Int, media: SSMedia)] = []
        result.reserveCapacity(pendingItems.count)
        func compressNext(index: Int) {
            guard index < pendingItems.count else { completion(result); return }
            let item = pendingItems[index]
            SSMediaManager.shared.compressMediaFile(media: item.media) { compressedMedia, success in
                if success {
                    result.append((tableMedia: item.tableMedia, mediaIndex: item.mediaIndex, media: compressedMedia))
                } else {
                    // Compression left no valid file on disk — never hand this to the upload phase.
                    if let filePath = item.media.filePath {
                        ZenForms.shared.failedFilesTrackingDelegate?.trackFailedUpload(filePath: filePath)
                                FPFormDataHolder.shared.failedUploadFilePaths.append(filePath)
                    }
                    let error = NSError(domain: "SSMediaManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Media compression failed to produce a valid file"])
                    FPUtility.logMediaWriteFailure(error, context: "FPFormsServiceManager.compressTableItemsSequentially")
                }
                compressNext(index: index + 1)
            }
        }
        compressNext(index: 0)
    }

    class func routeToSaveCustomForm(ticketId: NSNumber, isNew: Bool, form: FPForms, setSynced: Bool, assetLinkDetail:[String:Any]? = nil, completion: @escaping GetFormWithError) {
        if isNew || form.objectId == nil{
            let tempForm = form
            tempForm.objectId = nil
            // Generate localClientId if not already set (similar to sqliteId assignment pattern)
            if tempForm.localClientId == nil || tempForm.localClientId?.isEmpty == true {
                tempForm.localClientId = FPUtility.nanoID()
            }
            self.addCustomForm(ticketId: ticketId, form: tempForm, setSynced: setSynced, assetLinkDetail: assetLinkDetail) { result, error in
                completion(result, error)
            }
        } else {
            self.updateCustomForm(ticketId: ticketId, form: form, setSynced: setSynced, assetLinkDetail: assetLinkDetail) { result, error in
                completion(result, error)
            }
        }
    }
    
    class func updateCustomForm(ticketId: NSNumber, form: FPForms, setSynced: Bool, assetLinkDetail:[String:Any]? = nil, completion: @escaping GetFormWithError){
        guard FPUtility.isConnectedToNetwork() else {
            DispatchQueue.global(qos: .utility).async {
                form.isSyncedToServer = false
                self.upsertLocalData(ticketId: ticketId, moduleId: FPFormMduleId, form: form) { form, error in
                    completion(form, error)
                }
            }
            return
        }
        var dictJson = form.getJSONForUpdate()
        if let data = assetLinkDetail, !data.isEmpty{
            dictJson["assetLinkingDetails"] = data
        }
        if let deletedSections = FPFormDataHolder.shared.customForm?.deletedSections, !deletedSections.isEmpty{
            let arrSections = deletedSections.components(separatedBy: ",")
            let delSections = arrSections.compactMap({Int($0)})
            if !delSections.isEmpty{
                dictJson["delete"] = ["section":delSections]
            }
        }
        router.request(.updateCustomForm(dictJson)) { (json, _data, response, _error ) in
            DispatchQueue.global(qos: .utility).async {
                if _error == nil {
                    guard let result = json?["result"] as? [String: Any] else {
                        completion(nil, FPErrorHandler.getError(code: 401, message: FPLocalizationHelper.localize("lbl_Something_went_wrong")))
                        return
                    }
                    let formOnline = FPForms.init(dict: result,isForLocal: true)
                    formOnline.isSyncedToServer = true
                    formOnline.sqliteId = form.sqliteId
                    let results = AssetFormLinkingDatabaseManager().fetchAssetLinkigDataFor(customForm: formOnline)
                    let group = DispatchGroup()
                    for linkdata in results{
                        let updated = linkdata
                        updated.customFormId = NSNumber(value: Int(form.objectId ?? "0") ?? 0)
                        updated.isSyncedToServer = true
                        updated.isNotConfirmed = false
                        if linkdata.deleteLinking{
                            group.enter()
                            AssetFormLinkingDatabaseManager().deleteMappingData(updated){  _ in
                                group.leave()
                            }
                        }else{
                            group.enter()
                            AssetFormLinkingDatabaseManager().upsert(item: updated){  _ in
                                group.leave()
                            }
                        }
                    }
                    if isStaffTechnician{
                        FPFormsServiceManager.preComileFPForm(form: formOnline, ticketID: ticketId.stringValue) {}
                    }
                    self.upsertServerData(ticketId: ticketId, moduleId: FPFormMduleId, localForm: form, serverform: formOnline) { dbform, error in
                        completion(dbform, error)
                    }
                } else {
                    FPUtility.hideHUD()
                    completion(nil, _error)
                }
            }
        }
    }
    
    class func renameCustomForm(form: FPForms, completion: @escaping GetFormWithError) {
        // If no server ID or offline, just update locally
        guard FPUtility.isConnectedToNetwork(), let objectId = Int(form.objectId ?? "") else {
            DispatchQueue.global(qos: .utility).async {
                form.isSyncedToServer = false
                FPFormsDatabaseManager().updateFormName(form: form) { success in
                    completion(success ? form : nil, success ? nil : FPErrorHandler.getError(code: 500, message: FPLocalizationHelper.localize("lbl_Something_went_wrong")))
                }
            }
            return
        }
        var dictJson: [String: Any] = [:]
        dictJson["id"] = objectId
        dictJson["name"] = form.name
        dictJson["displayName"] = form.displayName
        dictJson["templateId"] = form.templateId ?? ""
        router.request(.updateCustomForm(dictJson)) { (json, _, _, _error) in
            DispatchQueue.global(qos: .utility).async {
                guard _error == nil, let result = json?["result"] as? [String: Any] else {
                    completion(nil, _error ?? FPErrorHandler.getError(code: 401, message: FPLocalizationHelper.localize("lbl_Something_went_wrong")))
                    return
                }
                let serverForm = FPForms(dict: result, isForLocal: true)
                serverForm.sqliteId = form.sqliteId
                serverForm.isSyncedToServer = true
                FPFormsDatabaseManager().updateFormName(form: serverForm) { success in
                    completion(success ? serverForm : nil, success ? nil : FPErrorHandler.getError(code: 500, message: FPLocalizationHelper.localize("lbl_Something_went_wrong")))
                }
            }
        }
    }

    class func addCustomForm(ticketId: NSNumber, form: FPForms, setSynced: Bool, assetLinkDetail:[String:Any]? = nil, completion: @escaping GetFormWithError) {
        guard FPUtility.isConnectedToNetwork() else {
            DispatchQueue.global(qos: .utility).async {
                form.isSyncedToServer = false
                form.isActive = true
                self.upsertLocalData(ticketId: ticketId, moduleId: FPFormMduleId, form: form) { form, error in
                    let group = DispatchGroup()
                    for linking in FPFormDataHolder.shared.arrLinkingDB{
                        let updated = linking
                        updated.customFormLocalId = form?.sqliteId
                        updated.isNotConfirmed = false
                        group.enter()
                        AssetFormLinkingDatabaseManager().upsert(item: updated) { _ in
                            group.leave()
                        }
                    }
                    FPFormDataHolder.shared.arrLinkingDB = []
                    completion(form, error)
                }
            }
            return
        }
        let dictJson = form.getJSONForSync()
        var params = [String: Any]()
        params["ticketId"] = ticketId
        params["fpForm"] = dictJson
        if let data = assetLinkDetail, !data.isEmpty{
            params["assetLinkingDetails"] = data
        }
        router.request(.addCustomForm(params)) { (json, _data, response, _error ) in
            DispatchQueue.global(qos: .utility).async {
                if _error == nil {
                    guard let result = json?["result"] as? [String: Any] else {
                        completion(nil, FPErrorHandler.getError(code: 401, message: FPLocalizationHelper.localize("lbl_Something_went_wrong")))
                        return
                    }
                    let formOnline = FPForms.init(dict: result,isForLocal: true)
                    formOnline.isSyncedToServer = true
                    
                    // Preserve localClientId if not returned by server
                    if formOnline.localClientId == nil || formOnline.localClientId?.isEmpty == true {
                        formOnline.localClientId = form.localClientId
                    }
                    
                    if isStaffTechnician{
                        FPFormsServiceManager.preComileFPForm(form: formOnline, ticketID: ticketId.stringValue) {}
                    }
                    
                    let results = AssetFormLinkingDatabaseManager().fetchAssetLinkigDataFor(customForm: form)
                    let group = DispatchGroup()
                    for linkdata in results{
                        let updated = linkdata
                        updated.customFormId = NSNumber(value: Int(formOnline.objectId ?? "0") ?? 0)
                        updated.isSyncedToServer = true
                        updated.isNotConfirmed = false
                        group.enter()
                        AssetFormLinkingDatabaseManager().upsert(item: updated){  _ in
                            group.leave()
                        }
                    }
                    
                    
                    for linking in FPFormDataHolder.shared.arrLinkingDB{
                        let updated = linking
                        updated.customFormId = NSNumber(value: Int(formOnline.objectId ?? "0") ?? 0)
                        updated.isNotConfirmed = false
                        group.enter()
                        AssetFormLinkingDatabaseManager().upsert(item: updated) { _ in
                            group.leave()
                        }
                    }
                    FPFormDataHolder.shared.arrLinkingDB = []
                    
                    if let prevSqliteId  = form.sqliteId {
                        FPFormsDatabaseManager().deleteFormBySqliteId(form: form, moduleId: FPFormMduleId, ticketId: ticketId) { _ in
                            FPFormsDatabaseManager().insertForm(form: formOnline, ticketId: ticketId, moduleId: FPFormMduleId) { _ , success in
                                if success {
                                    if let newSqliteId = formOnline.sqliteId, newSqliteId != prevSqliteId {
                                        FPTableDraftDatabaseManager().migrateFormTableDrafts(from: prevSqliteId, to: newSqliteId) {
                                            completion(formOnline, nil)
                                        }
                                    } else {
                                        completion(formOnline, nil)
                                    }
                                }else {
                                    let tempError = FPErrorHandler.getError(code: 401, message: FPLocalizationHelper.localize("lbl_Something_went_wrong"))
                                    completion(nil, tempError)
                                }
                            }
                        }
                    }else {
                        FPFormsDatabaseManager().insertForm(form: formOnline, ticketId: ticketId, moduleId: FPFormMduleId) { _  , _ in
                            completion(formOnline, nil)
                        }
                    }
                } else {
                    FPUtility.hideHUD()
                    completion(nil, _error)
                }
            }
        }
    }
    
    
    @objc class func getFPFormTemplates(shouldFetchOnline:Bool, showLoader: Bool, isOnlyActive:Bool, completion:  GetFormsWithError? = nil) {
        if showLoader {
            DispatchQueue.main.async {
                FPUtility.showHUDWithLoadingMessage()
            }
        }
        if shouldFetchOnline {
            self.fetchFPFormTemplates(showLoader: showLoader) { result, _  in
                FPUtility.hideHUD()
                completion?(result, nil)
            }
        }else {
            FPFormsDatabaseManager().fetchFPFormTemplatesFromLocal() { forms in
                FPUtility.hideHUD()
                completion?(forms ?? [], nil)
            }
            
        }
    }
    
    @objc class func fetchFPFormTemplates(showLoader: Bool, completion:  GetFormsWithError? = nil) {
        if showLoader {
            DispatchQueue.main.async {
                FPUtility.showHUDWithLoadingMessage()
            }
        }
        guard FPUtility.isConnectedToNetwork() else {
            if showLoader {
                FPUtility.hideHUD()
            }
            completion?([FPForms](), nil)
            return
        }
        router.request(.getFPFormTemplates) { (json, _data, response, _error) in
            DispatchQueue.global(qos: .background).async {
                var formTemplatesArray = [FPForms]()
                var localFormTemplatesArray = [FPForms]()
                if _error == nil {
                    guard let results = json?["result"] as? [[String: Any]] else {
                        completion?(formTemplatesArray, nil)
                        return
                    }
                    for item in results {
                        let fpTemplate = FPForms(dict: item, isForLocal: false)
                        fpTemplate.isTemplate = true
                        formTemplatesArray.append(fpTemplate)
                        
                        let localTemplate = FPForms(dict: item, isForLocal: true)
                        localTemplate.isTemplate = true
                        localFormTemplatesArray.append(localTemplate)
                    }
                    
                    if showLoader {
                        FPUtility.hideHUD()
                    }
                    completion?(formTemplatesArray, nil)
                    
                    FPFormsDatabaseManager().deleteAllFPFormsFromLocal(ticketId: 0, moduleId: FPFormTemplateModuleId) { success in
                        FPFormsDatabaseManager().insertAllFPForms(forms: localFormTemplatesArray, ticketId: 0, moduleId: FPFormTemplateModuleId) {
                            self.updateDifferentialMetaAndFetch(isFetching: false, shouldChangeUpdatedAt: true, shouldFetch: false, completion: { _, _ in
                            })
                        }
                    }
                } else {
                    if showLoader {
                        FPUtility.hideHUD()
                    }
                    FPUtility.printErrorAndShowAlert(error: _error)
                }
            }
        }
    }
    
    class func getPreviousFPForms(customerId: NSNumber, showLoader: Bool, completion: @escaping  (_ customForms: [FPForms]) -> Void) {
        guard FPUtility.isConnectedToNetwork() else {
            completion([FPForms]())
            return
        }
        if showLoader {
            DispatchQueue.main.async {
                FPUtility.showHUDWithLoadingMessage()
            }
        }
        let params = ["serviceAddressId": customerId,"limit":1000]
        router.request(.getPreviousFPForms(params)) { (json, _data, response, error) in
            if showLoader {
                FPUtility.hideHUD()
            }
            var formsArray = [FPForms]()
            if error == nil {
                guard let result = json?["result"] as? [String: Any] else {
                    completion(formsArray)
                    return
                }
                guard let results = result["results"] as? [[String: Any]] else {
                    completion(formsArray)
                    return
                }
                for item in results {
                    formsArray.append(FPForms(dict: item, isForLocal: true))
                }
            } else {
                FPUtility.printErrorAndShowAlert(error: error)
            }
            completion(formsArray)
        }
    }
    
    class func getFPFormDetails(formId: String,ticketId:NSNumber, showLoader: Bool, isUpdateToLocal: Bool = false, completion: @escaping  (_ form: FPForms) -> Void) {
        guard FPUtility.isConnectedToNetwork() else {
            completion(FPForms())
            return
        }
        if showLoader {
            DispatchQueue.main.async {
                FPUtility.showHUDWithLoadingMessage()
            }
        }
        let params = ["id": formId,"ticketId":ticketId] as [String : Any]
        router.request(.getFPFormDetails(params)) { json, _, _, error in
            if showLoader {
                FPUtility.hideHUD()
            }
            if error == nil {
                guard let result = json?["result"] as? [String: Any] else {
                    completion(FPForms())
                    return
                }
                if isUpdateToLocal{
                    let localform = FPForms(dict: result, isForLocal: true)
                    FPFormsDatabaseManager().upsert(form: localform, ticketId: ticketId) { _ in
                        completion(localform)
                    }
                }else{
                    let onlineform = FPForms(dict: result, isForLocal: false)
                    completion(onlineform)
                }
               
            } else {
                FPUtility.printErrorAndShowAlert(error: error)
            }
        }
    }
    
    class func getFPFormUpsertDeleteArray(result:[String:Any], isForTemplate:Bool, isForLocal:Bool) -> ([FPForms],[FPForms]) {
        var fpformArray = [FPForms]()
        var deletedArray = [FPForms]()
        for (key, values) in result {
            for item in values as! [[String: Any]] {
                let item = FPForms(dict: item, isForLocal: isForLocal)
                if isForTemplate {
                    item.isTemplate = true
                }
                if key.lowercased() == "added" ||  key.lowercased() == "updated" {
                    fpformArray.append(item)
                }else {
                    deletedArray.append(item)
                }
            }
        }
        return (fpformArray, deletedArray)
    }
    
    class func deleteCustomForms(ticketId: NSNumber, forms: [FPForms], deleteDeficiencies:Bool, showLoader: Bool, completion: @escaping ((_ success: Bool, _ error: Error?) -> ())) {
        var params = [String: Any]()
        params["ticketId"] = ticketId
        let formIds = forms.compactMap({$0.objectId})
        params["fpFormIds"] = formIds
        params["deleteDeficiencies"] = deleteDeficiencies
        if showLoader{
            DispatchQueue.main.async {
                FPUtility.showHUDWithDeleteMessage()
            }
        }
        router.request(.deleteCustomForms(params)) { (json, _data, response, _error ) in
            if showLoader{
                FPUtility.hideHUD()
            }
            if _error == nil {
                guard let _ = json?["result"] as? [[String: Any]] else {
                    completion(false, FPErrorHandler.getError(code: 401, message: FPLocalizationHelper.localize("lbl_Something_went_wrong")))
                    return
                }
                FPFormsDatabaseManager().deleteFormsByObjectId(forms: forms, moduleId: FPFormMduleId, ticketId: ticketId) {
                    let tid = ticketId.stringValue
                    for form in forms {
                        let fid = form.sqliteId?.stringValue ?? form.localClientId ?? "0"
                        if fid != "0" {
                            FPTableDraftDatabaseManager().deleteAllDraftsForForm(ticketId: tid, formLocalId: fid)
                        }
                    }
                    completion(true, nil)
                }
                completion(true, nil)
            } else {
                completion(false, _error)
            }
        }
    }
    
    class func downloadCustomForm(ticketId: NSNumber, showLoader: Bool, params: [String:Any], completion: @escaping(_ strUrl: String?, Error?) -> ()) {
        if showLoader{
            DispatchQueue.main.async {
                FPUtility.showHUDWithLoadingMessage()
            }
        }
        
        router.request(.downloadCustomForm(params)) { (json, _data, response, _error ) in
            if showLoader{
                FPUtility.hideHUD()
            }
            if _error == nil {
                guard let result = json?["result"] as? [String: Any] else {
                    completion(nil, FPErrorHandler.getError(code: 401, message: FPLocalizationHelper.localize("lbl_Something_went_wrong")))
                    return
                }
                if let location = result["Location"] as? String{
                    completion(location, nil)
                }else if let location = result["location"] as? String{
                    completion(location, nil)
                }
            } else {
                completion(nil, _error)
            }
        }
    }
    
    class func requestDownloadCustomForm(formId: String, params : [String: Any], showLoader: Bool, completion: @escaping ((_ success: Bool, _ error: Error?) -> ()))  {
        if showLoader{
            DispatchQueue.main.async {
                FPUtility.showHUDWithLoadingMessage()
            }
        }
        router.request(.requestDownloadCustomForm(formId, params: params)) { (json, _data, response, _error ) in
            if showLoader{
                FPUtility.hideHUD()
            }
            if _error == nil {
                guard let _ = json?["result"] as? [String: Any] else {
                    let tempError = FPErrorHandler.getError(code: 401, message: FPLocalizationHelper.localize("lbl_Something_went_wrong"))
                    FPUtility.printErrorAndShowAlert(error: tempError)
                    completion(false, _error)
                    return
                }
                completion(true, nil)
            } else {
                completion(false, _error)
            }
        }
    }
    
    class func fetchDownloadStatus(showLoader: Bool, params: [String:Any], completion: @escaping ((_ result: [String:Any]?, _ error: Error?) -> ()))  {
        if showLoader{
            DispatchQueue.main.async {
                FPUtility.showHUDWithLoadingMessage()
            }
        }
        
        router.request(.fetchDownloadStatus(params: params)) { (json, _data, response, _error ) in
            if showLoader{
                FPUtility.hideHUD()
            }
            if _error == nil {
                guard let result = json?["result"] as? [String: Any] else {
                    let tempError = FPErrorHandler.getError(code: 401, message: FPLocalizationHelper.localize("lbl_Something_went_wrong"))
                    FPUtility.printErrorAndShowAlert(error: tempError)
                    completion(nil, _error)
                    return
                }
                completion(result, nil)
            } else {
                completion(nil, _error)
            }
        }
    }
    
    @objc class func getFPFormTemplatesOnline(showLoader: Bool, completion: @escaping GetFormsWithError) {
        if showLoader {
            DispatchQueue.main.async {
                FPUtility.showHUDWithLoadingMessage()
            }
        }
        guard FPUtility.isConnectedToNetwork() else {
            FPFormsDatabaseManager().fetchFPFormTemplatesFromLocal() { forms in
                if showLoader {
                    FPUtility.hideHUD()
                }
                completion(forms ?? [], nil)
            }
            return
        }
        let param = self.getParamFor(item: commonFPFormTemplates)
        let paramApi:[String: Any] = ["objectsToFetch": param["objectsToFetch"] ?? [String](), "options": param["options"] ?? [String:Any]()]
        router.request(.getCommonTemplates(paramApi)) { (json, data, response, error) in
            DispatchQueue.global(qos: .utility).async {
                if showLoader {
                    FPUtility.hideHUD()
                }
                if error == nil{
                    guard let result = json?["result"] as? [String: Any] else {
                        self.updateDifferentialMeta(isFetching: false, shouldChangeUpdatedAt: false) {
                            let tempError = FPErrorHandler.getError(code: 401, message: FPLocalizationHelper.localize("lbl_Something_went_wrong"))
                            FPUtility.printErrorAndShowAlert(error: tempError)
                            completion([], error)
                        }
                        return
                    }
                    
                    let group = DispatchGroup()
                    
                    if let fpForms = result[commonFPFormTemplates] {
                        group.enter()
                        var preUpdatedAt = ""
                        if let options = param["optionsRaw"] as? [String:Any], let updatedAt = options[commonFPFormTemplates] as? String {
                            preUpdatedAt = updatedAt
                        }
                        FPFormsServiceManager.upsertFPFormTemplatesLocallyAndFetchToDisplay(json: ["result": fpForms], updatedAt: preUpdatedAt) { forms, _error in
                            group.leave()
                            completion(forms, _error)
                        }
                    }
                    
                } else {
                    self.updateDifferentialMeta(isFetching: false, shouldChangeUpdatedAt: false) {
                        FPUtility.printErrorAndShowAlert(error: error)
                        completion([], error)
                    }
                }
            }
        }
    }
    
    @objc class func getParamFor(item: String) -> [String:Any] {
        var param = [String:Any]()
        var objectsToFetch = [String]()
        var options = [String:Any]()
        var optionsUpdatedAt = [String:Any]()
        let diffMeta = self.getTemplateDifferential(isFetching: true, item: item, shouldClearUpdatedAt: false)
        FPDifferentialMetaDatabaseManager().upsertDifferetialMeta(differentialMeta: diffMeta, shouldChangeUpdatedAt: false) { success, updatedAt in
            objectsToFetch.append(item)
            if updatedAt != "" {
                options[item] = ["updatedAt" : FPUtility.getDateStringWithBySubtractingTimeInterval(sec:5, from:updatedAt)]
            }
            optionsUpdatedAt[item] = updatedAt
        }
        param["objectsToFetch"] = objectsToFetch
        param["options"] = options
        param["optionsRaw"] = optionsUpdatedAt
        return param
    }
    
    @objc class func updateDifferentialMeta(isFetching:Bool, shouldChangeUpdatedAt:Bool, completion: @escaping completionHandler) {
        let diffMeta = self.getTemplateDifferential(isFetching: isFetching, item: commonFPFormTemplates, shouldClearUpdatedAt: false)
        FPDifferentialServiceManager.upsertDifferentialMeta(differentialMeta: diffMeta, shouldChangeUpdatedAt: shouldChangeUpdatedAt) { success, updatedAt in
            completion()
        }
    }
    
    class func getTemplateDifferential(isFetching: Bool, item: String,shouldClearUpdatedAt:Bool) -> FPDifferentialMeta {
        let diff = FPDifferentialMeta()
        diff.apiName = FPFormsApiName.getCommonTemplates([String : Any]()).path
        diff.isFetching = isFetching
        diff.payload = item
        
        if shouldClearUpdatedAt{
            diff.updatedAt = ""
        }else{
            diff.updatedAt = FPUtility.getUTCDateSQLiteQuery(date: Date()) ?? ""
        }
        return diff
    }
    
    @objc class func updateDifferentialMetaAndFetch(isFetching:Bool, shouldChangeUpdatedAt:Bool, shouldFetch:Bool, completion: @escaping GetFormsWithError) {
        let moduldId = FPFormTemplateModuleId
        self.updateDifferentialMeta(isFetching: false, shouldChangeUpdatedAt: true) {
            if shouldFetch {
                FPFormsDatabaseManager().fetchFormsFromLocal(ticketId: 0, moduleId: moduldId) { forms in
                    completion(forms ?? [FPForms](), nil)
                }
            }else {
                completion([FPForms](), nil)
            }
        }
    }
    
    
    @objc class func resetDifferntialMetaFor(commonTemplate:String,completion: @escaping completionHandler) {
        let diffMeta = self.getTemplateDifferential(isFetching: false, item: commonTemplate,shouldClearUpdatedAt: true)
        FPDifferentialServiceManager.upsertDifferentialMeta(differentialMeta: diffMeta, shouldChangeUpdatedAt: true) { success, updatedAt in
            completion()
        }
    }
    
    
    
    @objc class func upsertFPFormTemplatesLocallyAndFetchToDisplay(json: [String: Any]?, updatedAt: String, completion: @escaping GetFormsWithError) {
        var formTemplatesArray = [FPForms]()
        var localFormTemplatesArray = [FPForms]()
        var deletedArray = [FPForms]()
        if updatedAt != "" {
            guard let result = json?["result"] as? [String: Any] else {
                self.updateDifferentialMeta(isFetching: false, shouldChangeUpdatedAt: false) {
                    let tempError = FPErrorHandler.getError(code: 401, message: FPLocalizationHelper.localize("lbl_Something_went_wrong"))
                    FPUtility.printErrorAndShowAlert(error: tempError)
                    completion(formTemplatesArray, tempError)
                }
                return
            }
            (formTemplatesArray, deletedArray) = self.getFPFormUpsertDeleteArray(result: result, isForTemplate: true, isForLocal: false)
        } else {
            guard let results = json?["result"] as? [[String: Any]] else {
                self.updateDifferentialMeta(isFetching: false, shouldChangeUpdatedAt: false) {
                    let tempError = FPErrorHandler.getError(code: 401, message: FPLocalizationHelper.localize("lbl_Something_went_wrong"))
                    FPUtility.printErrorAndShowAlert(error: tempError)
                    completion(formTemplatesArray, tempError)
                }
                return
            }
            for dict in results {
                let item = FPForms(dict: dict, isForLocal: false)
                item.isTemplate = true
                formTemplatesArray.append(item)
                
                let localTemplate = FPForms(dict: dict, isForLocal: true)
                localTemplate.isTemplate = true
                localFormTemplatesArray.append(localTemplate)
            }
        }
        
        guard updatedAt != "" else {
            
            FPFormsDatabaseManager().deleteAllFPFormsFromLocal(ticketId: 0, moduleId: FPFormTemplateModuleId) { success in
                FPFormsDatabaseManager().insertAllFPForms(forms: localFormTemplatesArray, ticketId: 0, moduleId: FPFormTemplateModuleId) {
                    self.updateDifferentialMetaAndFetch(isFetching: false, shouldChangeUpdatedAt: true, shouldFetch: false, completion: { results, error in
                        completion(results, error)
                    })
                }
            }
            return
        }
        
        FPFormsDatabaseManager().upsertFormsByObjectId(forms: localFormTemplatesArray, moduleId: FPFormTemplateModuleId, ticketId: 0) {
            if deletedArray.count > 0 {
                FPFormsDatabaseManager().deleteFormsByObjectId(forms: deletedArray, moduleId: FPFormTemplateModuleId, ticketId: 0) {
                    self.updateDifferentialMetaAndFetch(isFetching: false, shouldChangeUpdatedAt: true, shouldFetch: false, completion: { results, error in
                        completion(results, error)
                    })
                }
            }else{
                self.updateDifferentialMetaAndFetch(isFetching: false, shouldChangeUpdatedAt: true, shouldFetch: false, completion: { results, error in
                    completion(results, error)
                })
            }
        }
    }
    
    class func getRecommendationCheckList(recommendation: String,checkListData: [String],completion: @escaping GetCheckListWithError) {
        var summaryParms = [String:Any]()
        summaryParms["deficiency"] = "inspection is been done"
        summaryParms["deficiencyReason"] = recommendation
        summaryParms["checklist"] = checkListData
        summaryParms["actions"] = ["get_covered_checklist"]
        router.request(.getChecklistAndSummary(summaryParms)) { (json, _data, response, _error ) in
            if _error == nil {
                if let result = json?["result"] as? [String:Any]{
                    if let suggestions = result["suggestions"] as? [String:Any], let actions = suggestions["actions"] as? [String:Any]{
                        if let checklist = actions["get_covered_checklist"] as? [String:Any],
                           let answer = checklist["answer"] as? [String:Any],
                           let message = answer["message"] as? [String:Any],
                           let checklist_covered = message["content"] as? String{
                            let dict = checklist_covered.getDictonary()
                            completion(dict, _error)
                        }
                    }
                }
            } else {
                completion([:], _error)
            }
        }
    }
    
    class func getRecommendationSuggestions(reason: String,completion: @escaping GetRecomendationListWithError) {
        var parms = [String:Any]()
        parms["query"] = reason
        router.request(.getRecommendationSuggestions(parms)) { (json, _data, response, _error ) in
            if _error == nil {
                if let result = json?["result"] as? [String:Any]{
                    let result = result["response"] as? [String:Any]
                    let recommendations = result?["recommendations"] as? [String] ?? []
                    completion(recommendations, _error)
                }
            } else {
                completion([], _error)
            }
        }
    }
}

// MARK: - FP Form List Revamp

extension FPFormsServiceManager {
    class func getAllInspectionFormsFor(ticketId: NSNumber, params:[String:Any], showLoader: Bool, completion: @escaping GetInspectionFormsCompletionBlock) {
        router.request(.getInspectionForms(params)) { (json, _data, response, _error) in
            if _error == nil {
                guard let result = json?["result"] as? [String: Any] else {
                    if showLoader {
                        FPUtility.hideHUD()
                    }
                    completion([FPForms](), 0, FPErrorHandler.getError(code: 401, message: FPLocalizationHelper.localize("lbl_Something_went_wrong")))
                    return
                }
                guard let results = result["data"] as? [[String:Any]] else {
                    if showLoader {
                        FPUtility.hideHUD()
                    }
                    completion([FPForms](), 0, FPErrorHandler.getError(code: 401, message: FPLocalizationHelper.localize("lbl_Something_went_wrong")))
                    return
                }
                if let deletedFpFormIds = result["deleted"] as? [NSNumber], !deletedFpFormIds.isEmpty{
                    ZenForms.deleteInspectionFormsByIds(deletedFpFormIds.map{$0.stringValue}, ticketId: ticketId) { }
                }
                let total = result["total"] as? Int ?? 0
                self.processInspectionForms(arrResults: results, total: total, ticketId) { forms, total,  error  in
                    completion(forms, total, error)
                }
            } else {
                if showLoader {
                    FPUtility.hideHUD()
                }
                completion([FPForms](), 0, _error)
            }
        }
    }
    
    class func processInspectionForms(arrResults: [[String: Any]], total:Int, _ ticketId: NSNumber, completion: @escaping GetInspectionFormsCompletionBlock) {
        var arrForms = [FPForms]()
        for item in arrResults {
            arrForms.append(FPForms(dict: item, isForLocal: false))
        }
        if arrForms.count > 0{
            let arrIds = arrForms.map { $0.objectId ?? "0" }
            var params = [String:Any]()
            params["ids"] = arrIds
            params["ticketIds"] = [ticketId]
            self.queryInspectionFormsFor(ticketId: ticketId, params: params, mtotal: total, showLoader: false) { forms, quryTotal, error  in
                completion(forms, quryTotal, error)
            }
        }else{
            completion(arrForms, total, nil)
        }
    }

    class func upsertInspectionFormsFor(ticketId: NSNumber, forms: [FPForms], completion:@escaping (_ forms: [FPForms]?) -> ()) {
        serialQueueUpsertFPForms.async {
            FPFormsDatabaseManager().insertORUpdate(forms: forms, ticketId: ticketId) { forms in
                DispatchQueue.main.async {
                    completion(forms)
                }
            }
        }
    }
    
    
    class func queryInspectionFormsFor(ticketId: NSNumber, params:[String:Any], mtotal:Int? = 1, showLoader: Bool, completion: @escaping GetInspectionFormsCompletionBlock) {
        
        if showLoader {
            DispatchQueue.main.async {
                FPUtility.showHUDWithLoadingMessage()
            }
        }
        router.request(.queryInspectionForms(params)) { (json, _data, response, _error) in
            if _error == nil {
                guard let results = json?["result"] as? [[String: Any]] else {
                    DispatchQueue.main.async {
                        if showLoader { FPUtility.hideHUD() }
                        completion([], 0, FPErrorHandler.getError(code: 422, message: FPLocalizationHelper.localize("lbl_Something_went_wrong")))
                    }
                    return
                }
                var arrForms = [FPForms]()
                for item in results {
                    arrForms.append(FPForms(dict: item, isForLocal: false))
                }
                self.upsertInspectionFormsFor(ticketId: ticketId, forms: arrForms) { forms in
                    DispatchQueue.main.async {
                        if showLoader { FPUtility.hideHUD() }
                        completion(arrForms, mtotal ?? 1, nil)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    if showLoader { FPUtility.hideHUD() }
                    completion([], 0, _error)
                }
            }
        }
    }
}
