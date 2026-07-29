//
//  ZenForms.swift
//
//  Created by apple on 15/04/24.
//

import Foundation
import UIKit
internal import IQKeyboardManagerSwift
internal import IQKeyboardToolbar
internal import IQKeyboardToolbarManager

public enum ViewType {
    case new
    case history
    case previous
}

internal var baseUrlString:String  = "https://services.zentrades.pro/api/"
internal var aibaseUrlString:String  = "https://services-copilot.zentrades.pro/api/"
internal var datadogEnvironmentString:String  = "crm-prod"
internal var s3EnvironmentString:String  = "https://mxq8cn3ws2.execute-api.us-east-1.amazonaws.com/prod/signedurl"

internal var strAccessToken:String = ""
internal var strRefreshToken:String = ""
internal var strCompanyId:String = ""
internal var strUserName:String = ""
internal var strUserId:String = ""

internal var ticketId:NSNumber?
internal var serviceAddressId:NSNumber?
internal var isAssetENABLED = false
internal var isFromCoPILOT = false
internal var isEnableQuickNotes = false
internal var isStaffTechnician = false
internal var isEnableReasonAICell = false


public class ZenServerAndAuthenticationInfo : NSObject{
    public var apiBaseUrl:String = "https://services.zentrades.pro/api/"
    public var aiapibaseUrl:String = "https://services-copilot.zentrades.pro/api/"
    public var datalogUrl:String = "crm-prod"
    public var awsS3Url:String = "https://mxq8cn3ws2.execute-api.us-east-1.amazonaws.com/prod/signedurl"
    public var accessToken:String = ""
    public var refreshToken:String = ""
}

public class ZenUserInfo : NSObject{
    public var username:String = ""
    public var userId:String = ""
    public var companyId:String = ""
    public var isEnableQuickNotes:Bool = false
    public var isStaffTechnician:Bool = false
    public var isEnableReasonAICell:Bool = false
}

public class AssetInspectionData: NSObject {
    public var isOverWriteAsset: Bool = false
    public var assetObjectId:NSNumber?
    public var assetLocalId:NSNumber?
    public var isAssetSyncedToServer: Bool = false
    public var assetName:String?
    public var assetSection:FPSectionDetails?
}


extension NSNotification {
    static let ClearAssetLinkSelected = Notification.Name.init("ClearAssetLinkSelected")
}

public protocol ZenFormsSyncAssetLinkingDelegate: NSObject {
    func uploadAssetAndLink(assetLocalId:NSNumber, completion: @escaping ((_ assetObjectId: NSNumber?) -> Void))
}

public protocol ZenFormsLogDelegate: AnyObject {
    func sendDebugLog(_ dictLog: [String : Any])
    func sendErrorLog(_ dictLog: [String : Any])
}

/// Protocol for tracking file uploads
/// Implement this in your main app to integrate with FailedUploadTracker
public protocol ZenFormsFailedFilesTrackingDelegate: AnyObject {
    /// Called when a file upload fails and should be tracked for cleanup
    func trackFailedUpload(filePath: String)
    
    /// Called when a file upload succeeds and should be removed from tracking
    func removeFromTracking(filePath: String)
    
    /// Called when form view controller deinits to cleanup all tracked failed uploads
    func cleanupAllTrackedFailedUploads()
}

public enum ZenFormsBundle {
    /// Resource bundle for ZenForms Swift Package
    public static let bundle: Bundle = {
        return Bundle.module
    }()
}


public final class ZenForms {

    public weak var delegate: ZenFormsSyncAssetLinkingDelegate?
    public weak var logDelegate: ZenFormsLogDelegate?
    public weak var failedFilesTrackingDelegate: ZenFormsFailedFilesTrackingDelegate?

    public static let shared = ZenForms()
    
    private init() {
        Task { @MainActor in
            ZenForms.setupKeyboard()
        }
    }
        
    public class func initializeDB(){
        FPLocalDatabaseManager.shared.migrateGRDB()
        DispatchQueue.global(qos: .utility).async {
            FPTableDraftDatabaseManager().deleteOrphanedDrafts()
        }
    }

    /// Call on logout — removes all table draft data so stale restore prompts never appear for the next user.
    public class func clearAllTableDrafts() {
        DispatchQueue.global(qos: .utility).async {
            FPTableDraftDatabaseManager().deleteAllDrafts()
        }
    }

    public class func configureZenForms(serverInfo:ZenServerAndAuthenticationInfo, userInfo:ZenUserInfo){
        baseUrlString =  serverInfo.apiBaseUrl
        aibaseUrlString = serverInfo.aiapibaseUrl
        datadogEnvironmentString =  serverInfo.datalogUrl
        s3EnvironmentString =  serverInfo.awsS3Url
        strAccessToken =  serverInfo.accessToken
        strRefreshToken =  serverInfo.refreshToken
        strUserName =  userInfo.username
        strUserId =  userInfo.userId
        strCompanyId =  userInfo.companyId
        isEnableQuickNotes = userInfo.isEnableQuickNotes
        isStaffTechnician = userInfo.isStaffTechnician
        isEnableReasonAICell = userInfo.isEnableReasonAICell
    }
    
    public func openForm(_ controller:UIViewController, form:FPForms, isNew:Bool, isPreviousForm:Bool, isFromHistory:Bool, isAssetEnabled:Bool, isFromCoPilot: Bool = false) {
        let viewController:FPFormViewController = FPFormViewController(nibName:"FPFormViewController", bundle: ZenFormsBundle.bundle)
        viewController.customForm = form
        viewController.isAnalysed = form.isAnalysed ?? true || form.isSigned ?? false
        viewController.ticketId = ticketId
        viewController.serviceAddressId = serviceAddressId
        viewController.isNew = isNew
        viewController.isFromHistory = isFromHistory
        viewController.isPreviousForm = isPreviousForm
        viewController.isAssetEnabled = isAssetEnabled
        viewController.delegate = controller as? ZenFormsDelegate
        viewController.linkingDelegate = controller as? ZenFormsAssetLinkingDelegate
        isAssetENABLED = isAssetEnabled
        isFromCoPILOT = isFromCoPilot
        viewController.modalPresentationStyle = .overFullScreen
//        let navVc = ZTLIBNavigationController(rootViewController:viewController)
        let navVC = UINavigationController(rootViewController:viewController)
        navVC.modalPresentationStyle = .overFullScreen
        controller.navigationController?.present(navVC, animated: true) {}
    }

    public func getComputedFieldsForZenForm(ticketID:String){
        FPFormsServiceManager.getComputedFields(ticketID: ticketID)
    }
    
    public class func getConstantsForZenForm(){
        FPFormsServiceManager.getZenFormConstants()
    }
    
    @MainActor  private class func setupKeyboard(){
        IQKeyboardToolbarManager.shared.toolbarConfiguration.barTintColor = .systemBackground
        IQKeyboardManager.shared.keyboardDistance = 20
        IQKeyboardToolbarManager.shared.toolbarConfiguration.previousNextDisplayMode = .alwaysShow
        IQKeyboardManager.shared.isEnabled = false
        IQKeyboardToolbarManager.shared.isEnabled = false
        IQKeyboardManager.shared.resignOnTouchOutside = true
        IQKeyboardToolbarManager.shared.deepResponderAllowedContainerClasses  = [UITableView.self, UICollectionView.self, UIStackView.self, UIView.self, UIScrollView.self]
    }
   
    public func syncZenForm(form:FPForms, syncDelegate: ZenFormsSyncAssetLinkingDelegate?, isAssetEnabled:Bool , completion: @escaping (_ form: FPForms?, _ success: Bool) -> ()){
        isAssetENABLED = isAssetEnabled
        FPFormsServiceManager.getFilesFromForm(form: form)
        FPFormsServiceManager.uploadMediasAttached { status in
            FPFormsServiceManager.uploadTableAttachments { status in
                let processedForm = FPFormsServiceManager.getProceessedForm(isNew: form.objectId == nil)
                FPUtility.findAssetLinkingsFor(form: processedForm, synclinkingDelegate: syncDelegate) { assetLinkJson in
                    FPFormsServiceManager.routeToSaveCustomForm(ticketId: ticketId ?? 0, isNew: form.objectId == nil, form: processedForm, setSynced: true, assetLinkDetail:assetLinkJson) { form, error in
                        if error == nil {
                            if isEnableQuickNotes, let form = form, let strTicketId = ticketId?.stringValue{
                                FPFormsServiceManager.preComileFPForm(form: form, ticketID: strTicketId) { }
                            }
                            completion(form, true)
                        }else {
                            DispatchQueue.main.async {
                                FPUtility.printErrorAndShowAlert(error: error)
                            }
                            completion(nil, false)
                        }
                    }
                }
            }
        }
    }
    
    public class func  updateZenFormSyncStatusLocally(form: FPForms, ticketId: NSNumber, completion: @escaping ((Bool) -> ())) {
        FPFormsServiceManager.markFormLocallySync(form: form, ticketId: ticketId) { success in
            completion(success)
        }
    }
    
    public func getZenFormDetails(formId: String,ticketId:NSNumber, showLoader: Bool, isUpdateToLocal: Bool = false, completion: @escaping  (_ form: FPForms) -> Void) {
        FPFormsServiceManager.getFPFormDetails(formId: formId, ticketId: ticketId, showLoader: showLoader) { form in
            completion(form)
        }
    }
    
    
    public class func getZenFormLocal(objectId:String, completion: @escaping  (_ form: FPForms?) -> Void) {
        FPFormsServiceManager.fetchFormBy(objectId: objectId) { lform in
            if let lform = lform{
                completion(lform)
            }else{
                completion(nil)
            }
        }
    }
    
    
    public class func resetZenFormReportDownloadStatus(form:FPForms,ticketId:NSNumber, completion: @escaping  (_ success: Bool) -> ()) {
        FPFormsServiceManager.routeToSaveCustomForm(ticketId: ticketId, isNew: false, form: form, setSynced: true) { form, error in
            if error == nil {
                completion(true)
            }else {
                completion(false)
            }
        }
    }
    
    public class func fetchZenFormTemplatesDifferentia(shouldFetchOnline:Bool, showLoader: Bool, completion: @escaping (_ forms: [FPForms]) -> ()) {
        if shouldFetchOnline {
            FPFormsServiceManager.getFPFormTemplatesOnline(showLoader: showLoader) { _, _error in
                FPFormsDatabaseManager().fetchFPFormTemplatesFromLocal() { forms in
                    completion(forms ?? [])
                }
            }
        }else {
            if showLoader {
                DispatchQueue.main.async {
                   FPUtility.showHUDWithLoadingMessage()
                }
            }
            FPFormsDatabaseManager().fetchFPFormTemplatesFromLocal() { forms in
                if showLoader {
                    DispatchQueue.main.async {
                       FPUtility.hideHUD()
                    }
                }
                completion(forms ?? [])
            }
        }
    }
    
    public class func fetchZenFormTemplatesDifferentialMeta( completion: @escaping ((String?) -> ())) {
        let resultTemp = FPFormsServiceManager.getTemplateDifferential(isFetching: false, item: commonFPFormTemplates, shouldClearUpdatedAt: false)
        FPDifferentialServiceManager.fetchDifferentialMeta(apiName: resultTemp.apiName, payload: resultTemp.payload) { results in
            if let result = results.first{
                completion(result.updatedAt)
            }else{
                completion("")
            }
        }
    }

    public class func fetchZenFormTemplates(shouldFetchOnline:Bool, showLoader: Bool, isOnlyActive:Bool, completion: @escaping (_ forms: [FPForms]) -> ()) {
        FPFormsServiceManager.getFPFormTemplates(shouldFetchOnline: shouldFetchOnline, showLoader: showLoader, isOnlyActive: isOnlyActive) { forms, _error in
            completion(forms)
        }
    }
    
    public class func insertAllFPForms(forms: [FPForms], ticketId:NSNumber, serviceAddressId:Int? = nil, completion: @escaping (() -> ())) {
        FPFormsDatabaseManager().insertAllFPForms(forms: forms, ticketId: ticketId, moduleId: FPFormMduleId, serviceAddressId: serviceAddressId) {
            completion()
        }
    }
    
    public class func deleteAllFPFormsFromLocal(ticketId: NSNumber, completion: @escaping (_ success: Bool) -> ()) {
        FPFormsDatabaseManager().deleteAllFPFormsFromLocal(ticketId: ticketId, moduleId: FPFormMduleId) { success in
            completion(success)
        }
    }
    
    public class func fetchFPFormsFromLocal(ticketId: NSNumber, completion: @escaping (_ fpForms: [FPForms]) -> ()) {
        FPFormsDatabaseManager().fetchFormsFromLocal(ticketId: ticketId, moduleId: FPFormMduleId) { fpForms in
            completion(fpForms ?? [])
        }
    }
    
    public class func getFPFormUpsertDeleteArray(result:[String:Any], isForTemplate:Bool, isForLocal:Bool) -> ([FPForms],[FPForms]) {
            return FPFormsServiceManager.getFPFormUpsertDeleteArray(result: result, isForTemplate: isForTemplate, isForLocal: isForLocal)
        }
    
    public class func deleteInspectionFormsByIds(_ arrIds: [String], ticketId: NSNumber, completion: @escaping () -> ()) {
        FPFormsDatabaseManager().deleteInspectionFormsByObjectId(arrIds: arrIds, ticketId: ticketId) {
            completion()
        }
    }
    
    public class func deleteFPForms(forms: [FPForms], bySqliteId: Bool, ticketId: NSNumber, completion: @escaping () -> ()) {
        if bySqliteId{
            FPFormsDatabaseManager().deleteFormsBySqliteId(forms: forms, ticketId: ticketId) {
                completion()
            }
        }else{
            FPFormsDatabaseManager().deleteFormsByObjectId(forms: forms, moduleId: FPFormMduleId, ticketId: ticketId) {
                completion()
            }
        }
    }
    
    public class func updateFPFormDownloadStatus(objectId: String, downloadStatus: String, downloadURL: String?, completion: @escaping (() -> ())) {
        FPFormsDatabaseManager().updateDownloadStatus(objectId: objectId, downloadStatus: downloadStatus, downloadURL: downloadURL) {
            completion()
        }
    }

    public class func upsertFPForms(forms: [FPForms], bySqliteId: Bool, ticketId:NSNumber, completion: @escaping (() -> ())) {
        if bySqliteId{
            FPFormsDatabaseManager().upsertForms(forms: forms, moduleId: FPFormMduleId, ticketId: ticketId) {
                completion()
            }
        }else{
            FPFormsDatabaseManager().upsertFormsByObjectId(forms: forms, moduleId: FPFormMduleId, ticketId: ticketId) {
                completion()
            }
        }
    }
    
    public class func getPreviousFPForms(customerId: NSNumber, showLoader: Bool, completion: @escaping  (_ customForms: [FPForms]) -> Void) {
        FPFormsServiceManager.getPreviousFPForms(customerId: customerId, showLoader: showLoader) { customForms in
            completion(customForms)
        }
    }
    
    public class func getFPForms(ticketId:NSNumber, serviceAddressId:NSNumber, sectionDelta:Bool = false, shouldFetchOnline:Bool, showLoader: Bool, completion: @escaping (_ customForms: [FPForms]) -> Void) {
        FPFormsServiceManager.getCustomFPForms(ticketId: ticketId, serviceAddressId: serviceAddressId, sectionDelta: sectionDelta, shouldFetchOnline: shouldFetchOnline, showLoader: showLoader) { forms in
            completion(forms)
        }
    }
    
    public class func getInspectionFormsV2(ticketId:NSNumber, params:[String:Any], showLoader: Bool,  completion: @escaping (_ customForms: [FPForms], _ total:Int, _ error: Error?) -> Void) {
        FPFormsServiceManager.getAllInspectionFormsFor(ticketId: ticketId, params: params, showLoader: showLoader) { customForms, total, error in
            completion(customForms, total, error)
        }
    }
    
    public class func queryInspectionFormsFor(ticketId:NSNumber, params:[String:Any], showLoader: Bool,  completion: @escaping (_ customForms: [FPForms], _ total:Int, _ error: Error?) -> Void) {
        FPFormsServiceManager.queryInspectionFormsFor(ticketId: ticketId, params: params, showLoader: showLoader, completion: completion)
    }
    
    public class func upsertInspectionFormsFor(ticketId:NSNumber, inspectionForms:[FPForms], completion:@escaping (_ forms: [FPForms]?) -> ()) {
        FPFormsServiceManager.upsertInspectionFormsFor(ticketId: ticketId, forms: inspectionForms, completion: completion)
    }

    public class func deleteFPForms(ticketId: NSNumber, forms: [FPForms], deleteDeficiencies:Bool, showLoader: Bool, completion: @escaping ((_ success: Bool, _ error: Error?) -> ())) {
        FPFormsServiceManager.deleteCustomForms(ticketId: ticketId, forms: forms, deleteDeficiencies: deleteDeficiencies, showLoader: showLoader, completion: completion)
    }
    
    public class func downloadFPForm(ticketId: NSNumber, showLoader: Bool, params: [String:Any], completion: @escaping(_ strUrl: String?, Error?) -> ()) {
        FPFormsServiceManager.downloadCustomForm(ticketId: ticketId, showLoader: showLoader, params:params, completion: completion)
    }
    
    public class func requestDownloadFPForm(formId: String, params : [String: Any], showLoader: Bool, completion: @escaping ((_ success: Bool, _ error: Error?) -> ())) {
        FPFormsServiceManager.requestDownloadCustomForm(formId: formId, params: params, showLoader: showLoader, completion: completion)
    }
    
    public class func trackDownloadStausFPForm(showLoader: Bool, params: [String:Any], completion: @escaping ((_ result: [String:Any]?, _ error: Error?) -> ())) {
        FPFormsServiceManager.fetchDownloadStatus(showLoader: showLoader, params: params, completion: completion)
    }
    
    public class func addSignaturesToFPForm(showLoader: Bool, form:FPForms, ticketID:NSNumber, params : [String: Any], completion: @escaping (Error?) -> ()) {
        FPFormsServiceManager.addSignaturesToFPForm(showLoader: showLoader, form: form, ticketID: ticketID, params: params, completion: completion)
    }
    
    public class func clearAssetLinkingIndex(){
        NotificationCenter.default.post(name: NSNotification.ClearAssetLinkSelected, object: nil)
    }
    
    public class func logoutUser(){
        FPFormsServiceManager.resetDifferntialMetaFor(commonTemplate:commonFPFormTemplates) {}
        FPTempStore.shared.clear()
        ZenForms.clearAllTableDrafts()
    }
    
    public class func proceedWithAssetFormLinking(assetData:AssetInspectionData, isScannedResult:Bool, fieldTemplateId:String?){
        if let tableEditVc = FPUtility.topViewController() as? FPTableEditViewController{
            tableEditVc.proceedWithAssetFormLinking(assetData: assetData, isScannedResult: isScannedResult, fieldTemplateId: fieldTemplateId)
        }else if let arrVcs = FPUtility.topViewController()?.navigationController?.viewControllers, let tableEditVc = arrVcs.first(where: { $0.isKind(of: FPTableEditViewController.self)}) as? FPTableEditViewController{
            tableEditVc.proceedWithAssetFormLinking(assetData: assetData, isScannedResult: isScannedResult, fieldTemplateId: fieldTemplateId)
        }else if let formVc = FPUtility.topViewController() as? FPFormViewController{
            formVc
                .proceedWithAssetFormLinking(
                    assetData: assetData,
                    isScannedResult:isScannedResult,
                    fieldTemplateId: fieldTemplateId
                )
            
        }else if let arrVcs = FPUtility.topViewController()?.navigationController?.viewControllers, let formVc = arrVcs.first(where: { $0.isKind(of: FPFormViewController.self)}) as? FPFormViewController{
            formVc.proceedWithAssetFormLinking(assetData: assetData, isScannedResult: isScannedResult, fieldTemplateId: fieldTemplateId)
        }else{
            _  = FPUtility.showAlertController(title: FPLocalizationHelper.localize("error_dialog_title"), message: FPLocalizationHelper.localize("msg_asset_link_failed"), completion: nil)
        }
    }
    
    public class func scannerFieldScanDidComplete(result: String, fieldTemplateId: String?) {
        if let formVc = FPUtility.topViewController() as? FPFormViewController{
            formVc.scannerFieldScanDidComplete(result: result, fieldTemplateId: fieldTemplateId)
        }else if let arrVcs = FPUtility.topViewController()?.navigationController?.viewControllers, let formVc = arrVcs.first(where: { $0.isKind(of: FPFormViewController.self)}) as? FPFormViewController{
            formVc.scannerFieldScanDidComplete(result: result, fieldTemplateId: fieldTemplateId)
        }else{
            _  = FPUtility.showAlertController(title: FPLocalizationHelper.localize("error_dialog_title"), message: FPLocalizationHelper.localize("msg_scan_failed"), completion: nil)
        }
    }
}
 
public class ZenFormsBuilder: NSObject{
    
    public func feedTicketandServiceAddressInfo(ticketID:NSNumber?, serviceAddressID:NSNumber?) {
        ticketId =  ticketID
        serviceAddressId =  serviceAddressID
    }
        
    public func build() -> ZenForms {
        return ZenForms.shared
    }
    
    
}

