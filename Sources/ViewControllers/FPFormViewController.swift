//
//  FPFormViewController.swift
//  crm
//
//  Created by kuldeep on 14/04/22.
//  Copyright © 2022 SmartServ. All rights reserved.
//

import UIKit
internal import SSMediaManager
internal import TagListView
import MobileCoreServices
import UniformTypeIdentifiers
import Photos
import PhotosUI
internal import IQKeyboardManagerSwift
internal import IQKeyboardToolbarManager
import SwiftUI

protocol FPCollectionCellDelegate{
    func reloadCollection()
    func reloadCollectionAt(index:IndexPath)
    func attachFileAtTable(coloumnIndex:Int,tableIndexPath:IndexPath,collectionIndexPath:IndexPath,value:String,key:String)
}


public protocol ZenFormsDelegate: NSObject {
    /// Reload list from local DB. Pass a completion to get a callback when done —
    /// used by the library to sequence dismiss after the list is fully up-to-date.
    func formUpdated(completion: (() -> Void)?)
    func refreshListNeeded()//refresh list from server
    func newFormCancelClicked()
    func addQuickNoteClicked()
    func mixpanelEvent(eventName: String, properties:[String:Any]?)
}


public protocol ZenFormsAssetLinkingDelegate: NSObject {
    func openBarcodeScanner(isOverWriteAsset:Bool, baseVc: UIViewController?, linkedAssets:[[String:NSNumber?]], fieldTemplateId:String?)
    func openScannerField(baseVc: UIViewController?, fieldTemplateId:String?)
    func openAssetList()
    func uploadAssetAndLink(assetLocalId:NSNumber, completion: @escaping ((_ assetObjectId: NSNumber?) -> Void))
    func openAssetDetailsForLinking(serialNumber: String, baseVc: UIViewController?)
}

class FPFormViewController: UIViewController, UINavigationControllerDelegate {
  
    @IBOutlet weak var btnRescan: UIButton!
    @IBOutlet weak var viewBottom: UIView!
    @IBOutlet weak var txtFieldSection: UITextField!
    @IBOutlet weak var formTableView: UITableView!
    @IBOutlet weak var btnPrevious: ZTLIBLoaderButton!
    @IBOutlet weak var btnNext: ZTLIBLoaderButton!
    @IBOutlet weak var btnQuickNote: UIButton!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var imgFormTitleEdit: UIImageView!
    @IBOutlet weak var formNameActivityLoader: UIActivityIndicatorView!

    @IBOutlet var viewTitle: UIView!
    @IBOutlet weak var lblCurrentSectionName: UILabel!
    @IBOutlet weak var imgEditSectionName: UIImageView!
    @IBOutlet weak var viewSectioNameEdit: UIView!

    var ticketId:NSNumber?
    var serviceAddressId:NSNumber?
    
    var customForm:FPForms!
    var isNew: Bool = true
    var isFromHistory = false
    var isAssetEnabled = false
    
    public var delegate: ZenFormsDelegate?
    public var linkingDelegate: ZenFormsAssetLinkingDelegate?

    private let util = FPUtility()
        
    var shownAlertForPull = 0
    var section = 0
    var previousSection = -1
    private var backgroundSaveTask: UIBackgroundTaskIdentifier = .invalid
    private var hasDataChanges: Bool = false
    var pickerView: UIPickerView?
    var isAnalysed: Bool = false
    var isPreviousForm: Bool = false
    var attachmentIndex:IndexPath?
    var isFileAttachedInIndex = [IndexPath:Bool]()
    var isInitialReload: Bool = true
    var tableAttachementParentIndexPath:IndexPath?
    var tableAttachementChildIndexPath:IndexPath?
    var tableAttachementcoloumnIndex:Int?
    var tableAttachementcoloumnKey:String?
    var isImageOnly:Bool = false
    
    let TEXT_CELL = "text_cell"
    let RADIO_CELL = "radio_cell"
    let TABLE_CELL = "table_cell"
    let SEGMENT_CELL = "segment_cell"
    let FILE_CELL = "file_cell"
    let SIGNATURE_CELL = "signature_cell"
    let SUMMARY_CELL = "summary_cell"
    let LABEL_CELL = "label_cell"
    let CHART_CELL = "chart_cell"
    var isRescan: Bool = false
    fileprivate let fileManager = FileManager.default
    
    var refreshActivityBarButton:UIBarButtonItem?
    var refreshActivityIndicator = UIActivityIndicatorView()
    var isSaveRefreshing:Bool = false{
        didSet {
            setupNavBar()
        }
    }
    @IBOutlet weak var sectionDropDownActivityLoader: UIActivityIndicatorView!
    var barSaveButton:UIBarButtonItem?

    
    func addSectionPicker() {
        let imgViewForDropDown = UIImageView()
        imgViewForDropDown.frame = CGRect(x: 0, y: 0, width: 30, height: 48)
        imgViewForDropDown.image = UIImage(named: "ic_down_arrow_black")
        // Disable formatting options (Bold, Italic, Underline) in iOS 18+
        txtFieldSection.allowsEditingTextAttributes = false
        txtFieldSection.rightView = imgViewForDropDown
        txtFieldSection.rightViewMode = .always
        txtFieldSection.delegate = self
        txtFieldSection.tag = 1991 /// this added to diferentaite AttachedKeyboardToolBar to nullify global tool bar affetct
        self.pickerView = UIPickerView()
        self.pickerView?.dataSource = self
        self.pickerView?.delegate = self
        txtFieldSection.inputView = pickerView
        txtFieldSection.isUserInteractionEnabled = true
    }
    
    
   
    
    fileprivate func setupDropDownView() {
        
        
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.isTranslucent = false

        let appearance = UIToolbarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white
        toolbar.standardAppearance = appearance
        toolbar.scrollEdgeAppearance = appearance
        toolbar.compactAppearance = appearance
        
        let doneButton = UIBarButtonItem(title: FPLocalizationHelper.localize("Done"), style:.plain, target: self, action: #selector(onDoneButtonTapped(sender:)))
        
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolbar.setItems([flexibleSpace,doneButton], animated: false)
        
        let imgViewForDropDown = UIImageView()
        imgViewForDropDown.frame = CGRect(x: 0, y: 0, width: 30, height: 48)
        imgViewForDropDown.image = UIImage(named: "ic_down_arrow_black")
        txtFieldSection.text = FPUtility.getSQLiteCompatibleStringValue(FPFormDataHolder.shared.getFormSections().first?.displayName ?? "", isForLocal: false)
        lblCurrentSectionName.text = txtFieldSection.text
        if(FPFormDataHolder.shared.getSectionCount()>1) {
            addSectionPicker()
        }else{
            txtFieldSection.isUserInteractionEnabled = false
        }
        self.txtFieldSection.inputAccessoryView = toolbar
    }
    
    func registerKeyBoardNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name:UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name:UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    //MARK: - Handle localNotification listeners
    @objc func keyboardWillShow(notification:NSNotification)
    {
        guard let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else {
            // if keyboard size is not available for some reason, dont do anything
            return
        }
        let contentInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: keyboardSize.height , right: 0.0)
        formTableView.contentInset = contentInsets
        formTableView.scrollIndicatorInsets = contentInsets
    }
    
    @objc func keyboardWillHide(notification:NSNotification) {
        let contentInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
        formTableView.contentInset = contentInsets
        formTableView.scrollIndicatorInsets = contentInsets
    }
    
    fileprivate func setUpTableView() {
        formTableView.register(UINib(nibName: "FPTableCollectionViewCell", bundle: ZenFormsBundle.bundle), forCellReuseIdentifier: TABLE_CELL)
        formTableView.register(UINib(nibName: "FPDropDownTableViewCell", bundle: ZenFormsBundle.bundle), forCellReuseIdentifier: "FPDropDownTableViewCell")
        formTableView.register(UINib(nibName: "ReasonsCollectionViewCell", bundle: ZenFormsBundle.bundle), forCellReuseIdentifier: SEGMENT_CELL)
        formTableView.register(UINib(nibName: "FPFileInputTableViewCell", bundle: ZenFormsBundle.bundle), forCellReuseIdentifier: FILE_CELL)        
        formTableView.register(UITableViewCell.self, forCellReuseIdentifier: "FPChartFieldCell")
        formTableView.register(UITableViewCell.self, forCellReuseIdentifier: "FPSignatureFieldCell")
        formTableView.register(UITableViewCell.self, forCellReuseIdentifier: "FPLabelFieldCell")
        formTableView.register(UITableViewCell.self, forCellReuseIdentifier: "FPFileAttachmentFieldCell")
        formTableView.register(UITableViewCell.self, forCellReuseIdentifier: "FPRadioCheckboxFieldCell")
        formTableView.register(UITableViewCell.self, forCellReuseIdentifier: "FPDeficiencySegmentCell")
        formTableView.register(UITableViewCell.self, forCellReuseIdentifier: "FPInputFieldCell")
        
        formTableView.delegate = self
        formTableView.dataSource = self
        formTableView.rowHeight = UITableView.automaticDimension
        formTableView.estimatedRowHeight = 200
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let form = self.customForm.getCopyOfCustomForm(isTemplate: false)
        if isNew{
            form.objectId = nil
        }
        FPFormDataHolder.shared.resetData()
        // Use localClientId as a stable session identifier that survives crashes and syncs.
        FPFormDataHolder.shared.currentFormSessionId = form.sqliteId?.stringValue ?? form.localClientId ?? UUID().uuidString
        FPFormDataHolder.shared.customForm = form
        FPFormDataHolder.shared.getFilesFromValue(form: form)
        btnPrevious.currentView = self.navigationController?.view ?? self.view
        btnNext.currentView = self.navigationController?.view ?? self.view
        
        initializeView()
        btnQuickNote.isHidden = !isEnableQuickNotes
        if self.isAnalysed || self.isFromHistory{
            btnQuickNote.isHidden = true
        }
        viewBottom.dropShadow()
        viewSectioNameEdit.dropShadow()
        if let ticketID = self.ticketId?.stringValue{
            FPFormsServiceManager.getComputedFields(ticketID: ticketID)
        }
        
        // Capture initial form state for change detection
        DispatchQueue.main.async {
            FPFormDataHolder.shared.captureInitialFormState()
        }
        
        // Register memory warning observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        FPFormsServiceManager.getZenFormConstants()
        setupNavBar()
        IQKeyboardManager.shared.isEnabled = true
        IQKeyboardToolbarManager.shared.isEnabled = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        IQKeyboardManager.shared.isEnabled = false
        IQKeyboardToolbarManager.shared.isEnabled = false
        
        // Clear file attachment tracking to prevent memory growth
        isFileAttachedInIndex.removeAll()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        
        // Cleanup all tracked failed uploads for this session
        ZenForms.shared.failedFilesTrackingDelegate?.cleanupAllTrackedFailedUploads()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if isInitialReload{
            isInitialReload.toggle()
            self.formTableView.reloadData()
        }
    }
    
    @objc func handleMemoryWarning() {
        // Clear local file attachment tracking
        isFileAttachedInIndex.removeAll()
        
        // Clear FPFormDataHolder caches
        FPFormDataHolder.shared.clearFormCaches()
        
        // Force table reload to release cell references
        formTableView.reloadData()
    }
    
    func resetLocalVariables(){
        // Reset table attachment context to prevent attachments from previous forms/tickets showing up
        tableAttachementParentIndexPath = nil
        tableAttachementChildIndexPath = nil
        tableAttachementcoloumnIndex = nil
        tableAttachementcoloumnKey = nil
    }
    
    func initializeView() {
        resetLocalVariables()
        self.imgEditSectionName.isHidden = false
        FPFormDataHolder.shared.customForm = self.customForm.getCopyOfCustomForm(isTemplate: false)
        if isNew || isFromHistory{
            FPFormDataHolder.shared.customForm?.objectId = nil
            self.title =  FPFormDataHolder.shared.customForm?.displayName
            self.imgEditSectionName.isHidden = isFromHistory
        }else{
            if self.isAnalysed || self.isFromHistory{
                self.title =  FPFormDataHolder.shared.customForm?.displayName
                self.imgEditSectionName.isHidden = true
            }else{
                self.viewTitle.backgroundColor = .clear
                self.navigationItem.titleView = self.viewTitle
                self.lblTitle.text = FPFormDataHolder.shared.customForm?.displayName
                if isFromCoPILOT{
                    self.lblTitle.textColor = .white
                }
            }
        }
        setupDropDownView()
        setUpTableView()
        handleSectionControlUI()
        util.feedAssetLinkingIfAny(form: FPFormDataHolder.shared.customForm)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        SCREEN_WIDTH_S = size.width
        DispatchQueue.main.async {
            self.formTableView.reloadData()
        }
    }
    
    
    @objc func onDoneButtonTapped(sender: UIBarButtonItem) {
        if self.txtFieldSection.isFirstResponder {
            self.txtFieldSection.resignFirstResponder()
        }
        self.view.endEditing(true)
        if(self.isAnalysed || self.isFromHistory){
            return self.handleSectionControlUI()
        }
        guard let form = FPFormDataHolder.shared.customForm else {
            return
        }
        
        guard self.validatePartialSectionToSave(sectionIndex: self.previousSection) else {
            self.section =  self.previousSection
            self.previousSection = -1
            return
        }
       
        isRescan = false
        self.btnNext.updateInteraction(isEnabled: false)
        self.btnPrevious.updateInteraction(isEnabled: false)
        self.barSaveButton?.isEnabled = false
        
        self.sectionDropDownActivityLoader.isHidden = false
        self.sectionDropDownActivityLoader.startAnimating()

        if self.isNew{
            if FPUtility.isConnectedToNetwork(){
                self.saveEmptyForm { [weak self] status in
                    self?.handleSectionControlUI()
                }
            }else{
                FPFormsServiceManager.uploadMediasAttached { [weak self] status in
                    if(status){
                        FPFormsServiceManager.uploadTableAttachments { [weak self] isTableAttachmentUploaded in
                            if(isTableAttachmentUploaded){
                                self?.offlinePartialSave(form: form, sectionIndex: self?.previousSection ?? 0) { [weak self] success in
                                    self?.handleSectionControlUI()
                                }
                            }else{
                                self?.stopLoadings()
                            }
                        }
                    }else{
                        self?.stopLoadings()
                    }
                }
            }
            return
        }
        
        if !self.isNew, form.objectId == nil{
            
            if FPUtility.isConnectedToNetwork()  {
                //sync form first if not created
                self.continuePartialSave(form: form, isDismiss: false, sectionIndex: self.previousSection) { [weak self] success in
                    self?.handleSectionControlUI()
                }
                return
            }
            
            guard let formSection = FPFormDataHolder.shared.getProcessedSection(sectionIndex: self.previousSection) else{
                self.stopLoadings()
                return
            }
            FPFormsServiceManager.uploadMediasAttachedForCurrentSection(section: self.previousSection) { [weak self] status in
                guard let self = self else { return }
                if(status){
                    FPFormsServiceManager.uploadTableAttachmentsForCurrentSection(section: self.previousSection) { [weak self] isTableAttachmentUploaded in
                        if(isTableAttachmentUploaded){
                            FPFormsServiceManager.routeToOfflinePartialSaveCustomFormSection(ticketId: self?.ticketId ?? 0, section: formSection, form: form) { [weak self] form, _error in
                                self?.fpClearTableDraftsForSection(formSection)
                                self?.handleSectionControlUI()
                            }
                        }else{
                            self?.stopLoadings()
                        }
                    }
                }else{
                    self.stopLoadings()
                }
            }
            return
        }
        
        guard FPUtility.isConnectedToNetwork() else {
            self.continuePartialSave(form: form, isDismiss: false, sectionIndex: self.previousSection) { [weak self] success in
                self?.handleSectionControlUI()
            }
            return
        }
        
        shouldPullSectionFromServer { [weak self] needToPull in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if needToPull == true, self.shownAlertForPull == 0{
                    self.shownAlertForPull = self.shownAlertForPull + 1
                    _  = FPUtility.showAlertController(title: FPLocalizationHelper.localize("alert_dialog_title"), andMessage: FPLocalizationHelper.localizeWith(args: ["\(form.displayName ?? "")"], key: "msg_form_updated_other_tech_pull_first"), completion: nil, withPositiveAction: FPLocalizationHelper.localize("OK"), style: .default, andHandler: { [weak self] (action) in
                        self?.pullSectionFromServerAndRefresh(sectionIndex: self?.previousSection ?? 0)
                    }, withNegativeAction: nil, style: .default, andHandler: nil)
                }else{
                    self.continuePartialSave(form: form, isDismiss: false, sectionIndex: self.previousSection) { [weak self] success in
                        self?.handleSectionControlUI()
                    }
                }
            }
        }
        
    }
    
    func setupNavBar() {
        
        self.refreshActivityIndicator.sizeToFit()
        self.refreshActivityIndicator.color = UIColor(named: "BT-Primary") ?? .blue
        self.refreshActivityIndicator.style = .medium
        self.refreshActivityIndicator.hidesWhenStopped = true
        
        if (self.refreshActivityBarButton == nil) {
            self.refreshActivityBarButton =  UIBarButtonItem(customView:refreshActivityIndicator)
        }

        if self.customForm?.isAnalysed == false, isFromHistory == false{
            barSaveButton = UIBarButtonItem(title:FPLocalizationHelper.localize("SAVE"), style:.plain, target: self, action: #selector(saveButtonAction))
            self.navigationItem.rightBarButtonItem = isSaveRefreshing ? self.refreshActivityBarButton! : barSaveButton!
        }else{
            self.navigationItem.rightBarButtonItem = nil
        }
        let leftBarButton = UIBarButtonItem(title: FPLocalizationHelper.localize("Cancel"), style: .plain, target: self, action: #selector(cancelButtonAction))
        self.navigationItem.leftBarButtonItem = leftBarButton
        
        if isSaveRefreshing{
            self.refreshActivityIndicator.startAnimating()
            (self.navigationController?.view ?? self.view)?.isUserInteractionEnabled = false
        }else{
            self.refreshActivityIndicator.stopAnimating()
            (self.navigationController?.view ?? self.view)?.isUserInteractionEnabled = true
        }
    }
    
    //MARK: - ViewController button actions
    
    @IBAction func btnEditCurrentSectionDisplayNameAction(_ sender: UIButton) {
        if self.isAnalysed || self.isFromHistory{
            return
        }
        showRenameCurrentSection()
    }
    
    @IBAction func didTapRescan(_ sender: Any) {
        self.delegate?.mixpanelEvent(eventName: "RESCAN_SECTION_CLICKED", properties: nil)
        _ = FPUtility.showAlertController(title: FPLocalizationHelper.localize("alert_dialog_title"), andMessage: FPLocalizationHelper.localize("msg_asset_already_linked_section"), completion: nil, withPositiveAction: FPLocalizationHelper.localize("Yes"), style: .default, andHandler: { (action) in
            self.isRescan = true
            UserDefaults.currentScannerSectionId = FPFormDataHolder.shared.getScannebleSection()?.objectId
            self.linkingDelegate?
                .openBarcodeScanner(
                    isOverWriteAsset: true,
                    baseVc: self,
                    linkedAssets: [],
                    fieldTemplateId:nil
                )
        }, withNegativeAction: FPLocalizationHelper.localize("No"), style: .default, andHandler: nil)
    }
    
    @IBAction func btnEditNameDidTap(_ sender: UIButton) {
        self.showRenamePopup()
    }
    
    @IBAction func previousButtonAction(_ sender: UIButton) {
        self.view.endEditing(true)
        if(self.isAnalysed || self.isFromHistory){
            return showPreviousSection()
        }
        guard let form = FPFormDataHolder.shared.customForm else {
            return
        }
        
        guard self.validatePartialSectionToSave(sectionIndex: self.section) else {
            return
        }
        
        self.btnPrevious.isLoading = true
        self.btnNext.updateInteraction(isEnabled: false)
        self.barSaveButton?.isEnabled = false
        
        //edge case where form is not created
        if self.isNew{
            if FPUtility.isConnectedToNetwork(){
                self.saveEmptyForm { status in
                    self.showPreviousSection()
                }
            }else{
                FPFormsServiceManager.uploadMediasAttached { status in
                    if(status){
                        FPFormsServiceManager.uploadTableAttachments { isTableAttachmentUploaded in
                            if(isTableAttachmentUploaded){
                                self.offlinePartialSave(form: form, sectionIndex: self.section) { success in
                                    self.showPreviousSection()
                                }
                            }else{
                                self.stopLoadings()
                            }
                        }
                    }else{
                        self.stopLoadings()
                    }
                }
            }
            return
        }

        if !self.isNew, form.objectId == nil{
            if FPUtility.isConnectedToNetwork()  {
                //sync form first if not created
                self.continuePartialSave(form: form, isDismiss: false, sectionIndex: self.section) { success in
                    self.showPreviousSection()
                }
                return
            }
            
            guard let formSection = FPFormDataHolder.shared.getProcessedSection(sectionIndex: self.section) else{
                self.stopLoadings()
                return
            }
            FPFormsServiceManager.uploadMediasAttachedForCurrentSection(section: self.section) { status in
                if(status){
                    FPFormsServiceManager.uploadTableAttachmentsForCurrentSection(section: self.section) { isTableAttachmentUploaded in
                        if(isTableAttachmentUploaded){
                            FPFormsServiceManager.routeToOfflinePartialSaveCustomFormSection(ticketId: self.ticketId ?? 0, section: formSection, form: form) { [weak self] form, _error in
                                self?.fpClearTableDraftsForSection(formSection)
                                self?.showPreviousSection()
                            }
                        }else{
                            self.stopLoadings()
                        }
                    }
                }else{
                    self.stopLoadings()
                }
            }
            return
        }
        
        guard FPUtility.isConnectedToNetwork() else {
            self.continuePartialSave(form: form, isDismiss: false, sectionIndex: self.section) { success in
                self.showPreviousSection()
            }
            return
        }
        shouldPullSectionFromServer { needToPull in
            DispatchQueue.main.async {
                if needToPull == true, self.shownAlertForPull == 0{
                    self.shownAlertForPull = self.shownAlertForPull + 1
                    _  = FPUtility.showAlertController(title: FPLocalizationHelper.localize("alert_dialog_title"), andMessage: FPLocalizationHelper.localizeWith(args: ["\(form.displayName ?? "")"], key: "msg_form_updated_other_tech_pull_first"), completion: nil, withPositiveAction: FPLocalizationHelper.localize("OK"), style: .default, andHandler: { (action) in
                        self.pullSectionFromServerAndRefresh(sectionIndex: self.section)
                    }, withNegativeAction: nil, style: .default, andHandler: nil)
                }else{
                    self.continuePartialSave(form: form, isDismiss: false, sectionIndex: self.section) { success in
                        self.showPreviousSection()
                    }
                }
            }
        }
        
    }
    
    @IBAction func nextButtonAction(_ sender: UIButton) {
        self.view.endEditing(true)
        if(self.isAnalysed || self.isFromHistory){
            return showNextSection()
        }
        guard let form = FPFormDataHolder.shared.customForm else {
            return
        }
      
        //stop validating whole form is it may give error to other section and user might not able to reach there
//        if FPUtility.isConnectedToNetwork(), self.isNew{
//            guard self.validateToSave() else {
//                return
//            }
//        }
//
        guard self.validatePartialSectionToSave(sectionIndex: self.section) else {
            return
        }
        self.btnNext.isLoading = true
        self.btnPrevious.updateInteraction(isEnabled: false)
        self.barSaveButton?.isEnabled = false

        if self.isNew{
            if FPUtility.isConnectedToNetwork(){
                self.saveEmptyForm { status in
                    self.showNextSection()
                }
            }else{
                FPFormsServiceManager.uploadMediasAttached { status in
                    if(status){
                        FPFormsServiceManager.uploadTableAttachments { isTableAttachmentUploaded in
                            if(isTableAttachmentUploaded){
                                self.offlinePartialSave(form: form, sectionIndex: self.section) { success in
                                    self.showNextSection()
                                }
                            }else{
                                self.stopLoadings()
                            }
                        }
                    }else{
                        self.stopLoadings()
                    }
                }
            }
            return
        }
        
        if !self.isNew, form.objectId == nil{
            
            if FPUtility.isConnectedToNetwork()  {
                //sync form first if not created
                self.continuePartialSave(form: form, isDismiss: false, sectionIndex: self.section) { success in
                    self.showNextSection()
                }
                return
            }
            
            guard let formSection = FPFormDataHolder.shared.getProcessedSection(sectionIndex: self.section) else{
                self.stopLoadings()
                return
            }
            FPFormsServiceManager.uploadMediasAttachedForCurrentSection(section: self.section) { status in
                if(status){
                    FPFormsServiceManager.uploadTableAttachmentsForCurrentSection(section: self.section) { isTableAttachmentUploaded in
                        if(isTableAttachmentUploaded){
                            FPFormsServiceManager.routeToOfflinePartialSaveCustomFormSection(ticketId: self.ticketId ?? 0, section: formSection, form: form) { [weak self] form, _error in
                                self?.fpClearTableDraftsForSection(formSection)
                                self?.showNextSection()
                            }
                        }else{
                            self.stopLoadings()
                        }
                    }
                }else{
                    self.stopLoadings()
                }
            }
            return
        }
        
        guard FPUtility.isConnectedToNetwork() else {
            self.continuePartialSave(form: form, isDismiss: false, sectionIndex: self.section) { success in
                self.showNextSection()
            }
            return
        }
        
        shouldPullSectionFromServer { needToPull in
            DispatchQueue.main.async {
                if needToPull == true, self.shownAlertForPull == 0{
                    self.shownAlertForPull = self.shownAlertForPull + 1
                    _  = FPUtility.showAlertController(title: FPLocalizationHelper.localize("alert_dialog_title"), andMessage: FPLocalizationHelper.localizeWith(args: ["\(form.displayName ?? "")"], key: "msg_form_updated_other_tech_pull_first"), completion: nil, withPositiveAction: FPLocalizationHelper.localize("OK"), style: .default, andHandler: { (action) in
                        self.pullSectionFromServerAndRefresh(sectionIndex: self.section)
                    }, withNegativeAction: nil, style: .default, andHandler: nil)
                }else{
                    self.continuePartialSave(form: form, isDismiss: false, sectionIndex: self.section) { success in
                        self.showNextSection()
                    }
                }
            }
        }
    }
    
    func showNextSection(){
        isRescan = false
        if self.section <= FPFormDataHolder.shared.getSectionCount() - 1{
            self.section += 1
            handleSectionControlUI()
        }else{
            self.stopLoadings()
        }
    }
    
    func showPreviousSection(){
        isRescan = false
        if self.section > 0{
            self.section -= 1
            self.handleSectionControlUI()
        }else{
            self.stopLoadings()
        }
    }
    
    func handleSectionControlUI(){
        self.stopLoadings()
        DispatchQueue.main.async {
            let sections = FPFormDataHolder.shared.getFormSections()
            if sections.count == 1{
                self.btnPrevious.isHidden = true
                self.btnNext.isHidden = true
                return
            }else{
                self.btnPrevious.isHidden = false
                self.btnNext.isHidden = false
                self.addSectionPicker()
            }
            let sectionFields = FPFormDataHolder.shared.getFieldsIn(section: self.section);
            if let _ = sectionFields
                .firstIndex(where: {$0.getUIType() == .HIDDEN && $0.name == "assetId"}){
                self.btnRescan.isHidden = false
                if self.isAnalysed || self.isFromHistory{
                    self.btnRescan.isHidden = true
                }
            }else{
                self.btnRescan.isHidden = true
            }
            self.handleSectionButtonsInteraction()
            self.refreshSection()
        }
    }
    
    func handleSectionButtonsInteraction(){
        let sections = FPFormDataHolder.shared.getFormSections()
        DispatchQueue.main.async {
            self.btnPrevious.updateInteraction(isEnabled: self.section > 0)
            self.btnNext.updateInteraction(isEnabled: self.section < sections.count - 1)
        }
    }

    //MARK: SCANNER Field



    func scannerFieldScanDidComplete(result: String, fieldTemplateId: String?) {
        guard let currentSection = FPFormDataHolder.shared.getSection(at: self.section) else {
            return
        }
        if let fieldIndex = currentSection.fields.firstIndex(where: { $0.getUIType() == .SCANNER && $0.templateId == fieldTemplateId }){
            self.selectedValue(for: self.section, fieldIndex: fieldIndex, pickerIndex: nil, value: result, date: nil, isSectionDuplicationField: currentSection.fields[safe:fieldIndex]?.isSectionDuplicationField ?? false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.reloadCollectionAt(index: IndexPath(row: fieldIndex, section: 0))
            }
        }
    }
    
    //MARK: Link Asset to Section
    
    func proceedWithAssetFormLinking(assetData:AssetInspectionData, isScannedResult:Bool, fieldTemplateId: String?){
        self.delegate?.mixpanelEvent(eventName: "SCANNED_ASSET_SECTION", properties: ["assetId": assetData.assetObjectId ?? ""])
        if let assetID = assetData.assetObjectId?.intValue{
            if let addedSectionIndex = FPFormDataHolder.shared.assetAddedAtSection(assetID){
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5,execute: {
                    _ = FPUtility.showAlertController(
                        title: FPLocalizationHelper.localize("msg_asset_inspected"),
                        andMessage: FPLocalizationHelper.localize("msg_asset_inspected_confirmation"),
                        completion: nil,
                        withPositiveAction: FPLocalizationHelper.localize("Yes"),
                        style: .default,
                        andHandler: { action in
                            self.section = addedSectionIndex
                            self.handleSectionControlUI()
                        },
                        withNegativeAction: FPLocalizationHelper.localize("No"),
                        style: .cancel,
                        andHandler: nil
                    )
                    return
                })
                return
            }
        }
        var  scannebleSection = FPFormDataHolder.shared.getSection(at: self.section)
        if(isRescan){
            scannebleSection = FPFormDataHolder.shared.getScannebleSection()
        }
        if let scannebleField = scannebleSection?.fields.first(where: {$0.scannable}), let sectionMappingName = scannebleField.sectionMappingName{
            let assetField = assetData.assetSection?.fields.first(
                where: {$0.name?.lowercased() == sectionMappingName.lowercased()
                })
            var value = assetField?.value
            if(assetField?.name == "assetTypeId"){
                let dropDownOption = assetField?
                    .getDropdownOptions()
                    .first(where: {$0.value == assetField?.value})
                value = dropDownOption?.label
            }
            let sections = FPFormDataHolder.shared
                .getHiddenSections(using: value ?? "")
            if(sections.count>0){
                if let asset = assetData.assetSection{
                    if(!isRescan){
                        FPFormDataHolder.shared
                            .addSection(
                                sections.first!,
                                at: section,
                                forAsset: [asset], assetData: assetData,  completion: { status in
                                    self.handleSectionControlUI()
                                    if let _ = FPFormDataHolder.shared.customForm?.objectId{
                                        self.continuePartialSave(
                                            form:  FPFormDataHolder.shared.customForm!,
                                            isDismiss: false,
                                            sectionIndex: self.section+1,
                                            justScannedSection: true) { success in
                                                
                                            }
                                    }else{
                                        //saveForm()
                                    }
                                }
                            )
                    }else{
                        let prevSection = FPFormDataHolder.shared.getSection(at: self.section)
                        FPFormDataHolder.shared
                            .updateAssetSection(
                                sections.first!,
                                at: section,
                                forAsset: [asset],
                                assetData: assetData,
                                completion: {
                                    error,
                                    response in
                                    if let section = response as? FPSectionDetails{
                                        //previous section query and update new section
                                        FPFormDataHolder.shared.customForm?.isSyncedToServer = FPUtility.isConnectedToNetwork()
                                        self.deletePreviousAndAddNewSectionAssetLinkIntoDB(assetData: assetData, section:section, prevSection: prevSection)
                                    }
                                    self.handleSectionControlUI()
                                    if let _ = FPFormDataHolder.shared.customForm?.objectId{
                                        self.continuePartialSave(
                                            form:  FPFormDataHolder.shared.customForm!,
                                            isDismiss: false,
                                            sectionIndex: self.section+1) { success in
                                                
                                            }
                                    }else{
                                        //saveForm()
                                    }
                                }
                            )
                    }
                    
                }
            }else{
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                    _  = FPUtility.showAlertController(title: FPLocalizationHelper.localize("error_dialog_title"), message: FPLocalizationHelper.localize("msg_asset_type_not_supported"), viewController: self, completion: nil)
                })
             
            }
        }
    }
    
    func deletePreviousAndAddNewSectionAssetLinkIntoDB(assetData:AssetInspectionData, section:FPSectionDetails?, prevSection:FPSectionDetails?){
        let data = AssetFormMappingData()
        data.assetId = assetData.assetObjectId
        data.assetLocalId = assetData.assetLocalId
        data.isAssetSynced = assetData.isAssetSyncedToServer
        data.customFormId = FPUtility.getNumberValue(FPFormDataHolder.shared.customForm?.objectId)
        data.customFormLocalId = FPFormDataHolder.shared.customForm?.sqliteId ?? 0
        data.formTemplateId = FPFormDataHolder.shared.customForm?.templateId ?? "0"
        data.sectionTemplateId = section?.templateId
        data.sectionLocalId  = section?.sqliteId
        data.sectionId  = section?.objectId
        data.isSyncedToServer = false
        data.addLinking = false
        data.sectionLinking = true
        data.deleteLinking = false
        data.isNotConfirmed = true
        if FPFormDataHolder.shared.customForm?.sqliteId == nil{
            if let indexDel = FPFormDataHolder.shared.arrLinkingDB.firstIndex(where: { data in
                return (data.sectionId == prevSection?.objectId || data.sectionLocalId == prevSection?.sqliteId) && (data.customFormId?.stringValue == FPFormDataHolder.shared.customForm?.objectId || data.customFormLocalId == FPFormDataHolder.shared.customForm?.sqliteId)
            }){
                FPFormDataHolder.shared.arrLinkingDB.remove(at: indexDel)
                FPFormDataHolder.shared.arrLinkingDB.append(data)
            }
        }else{
            AssetFormLinkingDatabaseManager().deletePreviousSectionAsset(formId: FPFormDataHolder.shared.customForm?.objectId, formLocalId: FPFormDataHolder.shared.customForm?.sqliteId?.stringValue, prevSectionId:prevSection?.objectId?.stringValue, prevSectionLocalId: prevSection?.sqliteId?.stringValue){
                success in
                AssetFormLinkingDatabaseManager().insertSectionAsset(item: data) { success in }
            }
        }
    }
    
    //MARK: - Dynamic Section
    
    func proceedToDynamicSection(at sectionIndex:Int, section name:String){
        if let section = FPFormDataHolder.shared.getHiddenDynamicSections(using: name){
            self.addDynamicSection(section: section, at: sectionIndex)
        }
    }
    
    func addDynamicSection(section:FPSectionDetails, at sectionIndex:Int){
        FPFormDataHolder.shared.addDynamicSection(section, at: sectionIndex) { status in
            self.handleSectionControlUI()
            if let _ = FPFormDataHolder.shared.customForm?.objectId{
                self.continuePartialSave(
                    form:  FPFormDataHolder.shared.customForm!,
                    isDismiss: false,
                    sectionIndex: self.section+1) { success in }
            }
        }
    }
    
    
    //MARK: - Partial Save
    func shouldPullSectionFromServer(completion: @escaping FPFormsServiceManager.successCompletionHandler){
        var needtToPull = false
        if !FPUtility.isConnectedToNetwork(){
            completion(needtToPull)
        }
        guard let localSection = FPFormDataHolder.shared.getSection(at: self.section) else {
            completion(needtToPull)
            return
        }
        
        if checkIfSectionHasScannerOrDuplicateFieldsfor(localSection) {
            completion(needtToPull)
            return
        }
        FPFormsServiceManager.getCustomFPForms(ticketId: self.ticketId ?? 0, serviceAddressId: self.serviceAddressId ?? 0, sectionDelta: true, shouldFetchOnline: true, showLoader: false) { forms in
            if let serverForm = forms.filter({$0.objectId ==  FPFormDataHolder.shared.customForm!.objectId}).first, let serverSection = serverForm.sections?.filter({($0 ).objectId == localSection.objectId}).first as? FPSectionDetails{
                if let localUpdateDate = localSection.updatedAt, let serverUpdateDate = serverSection.updatedAt{
                    let localUpdatedTime = FPUtility.getDateFrom(localUpdateDate, format: "yyyy-MM-dd'T'HH:mm:ss.SSSZ") ?? Date()
                    let serverUpdatedTime = FPUtility.getDateFrom(serverUpdateDate, format: "yyyy-MM-dd'T'HH:mm:ss.SSSZ") ?? Date()
                    needtToPull = serverUpdatedTime > localUpdatedTime
                }
                completion(needtToPull)
            }else{
                completion(needtToPull)
            }
        }
    }
    
    func checkIfSectionHasScannerOrDuplicateFieldsfor(_ section: FPSectionDetails) -> Bool {
        var value = false
        for field in section.fields {
            if field.isSectionDuplicationField || field.scannable {
                value = true
                break
            }
        }
        return value
    }
    
    
    func saveCurrentSection(isDismiss:Bool){
        self.view.endEditing(true)
        guard !self.isNew else {
            return
        }
        guard let form = FPFormDataHolder.shared.customForm else {
            return
        }
        guard self.validatePartialSectionToSave(sectionIndex: self.section) else {
            return
        }
        isSaveRefreshing = true
        self.btnNext.updateInteraction(isEnabled: false)
        self.btnPrevious.updateInteraction(isEnabled: false)
        shouldPullSectionFromServer { needToPull in
            DispatchQueue.main.async {
                if needToPull == true, self.shownAlertForPull == 0{
                    self.shownAlertForPull = self.shownAlertForPull + 1
                    _  = FPUtility.showAlertController(title: FPLocalizationHelper.localize("alert_dialog_title"), andMessage: FPLocalizationHelper.localizeWith(args: ["\(form.displayName ?? "")"], key: "msg_form_updated_other_tech_pull_first"), completion: nil, withPositiveAction: FPLocalizationHelper.localize("OK"), style: .default, andHandler: { (action) in
                        self.pullSectionFromServerAndRefresh(sectionIndex: self.section)
                    }, withNegativeAction: nil, style: .default, andHandler: nil)
                }else{
                    self.continuePartialSave(form: form, isDismiss: isDismiss, sectionIndex: self.section) { success in }
                }
            }
        }
        
    }
    
    func pullSectionFromServerAndRefresh(sectionIndex:Int){
        FPFormsServiceManager.getFPFormDetails(formId: FPFormDataHolder.shared.customForm?.objectId ?? "0", ticketId: self.ticketId ?? 0, showLoader: false) { form in
            if let localSection = FPFormDataHolder.shared.getSection(at: sectionIndex){
                if let serverSection = form.sections?.filter({($0 ).objectId == localSection.objectId}).first as? FPSectionDetails{
                    self.shownAlertForPull = 0
                    FPFormDataHolder.shared.sections?[sectionIndex] = serverSection
                    self.refreshFPForm(serverForm: FPFormDataHolder.shared.customForm ?? FPForms(), sectionIndex: sectionIndex)
                }
            }
            self.stopLoadings()
        }
    }
    
    
    func refreshFPForm(serverForm:FPForms, sectionIndex:Int){
        let fpform = serverForm
        fpform.isSyncedToServer = true
        fpform.sqliteId = FPFormDataHolder.shared.customForm?.sqliteId
        FPFormDataHolder.shared.resetData()
        FPFormDataHolder.shared.customForm = fpform
        FPFormDataHolder.shared.getFilesFromValue(form: fpform)
        FPFormsDatabaseManager().updateForm(form: fpform, ticketId: self.ticketId ?? 0, moduleId: FPFormMduleId, shouldUpdateBySqliteId: false) {  [weak self] _, _ in
            self?.fpClearAllTableDrafts()
            DispatchQueue.main.async {
                self?.formTableView.reloadData()
            }
        }
    }
    
    func offlinePartialSave(form:FPForms, sectionIndex:Int , completion: @escaping FPFormsServiceManager.successCompletionHandler){
        var isNewForm = false
        if form.sqliteId == nil{
            form.objectId = nil
            isNewForm = true
        }
        DispatchQueue.global(qos: .userInitiated).async {
            form.isSyncedToServer = false
            FPFormsServiceManager.upsertLocalData(ticketId: self.ticketId ?? 0, moduleId: FPFormMduleId, form: form) { fpform, error in
                if error == nil, let nfpform = fpform {
                    DispatchQueue.main.async {
                        if isNewForm{
                            isNewForm = false
                            for linking in FPFormDataHolder.shared.arrLinkingDB{
                                let updated = linking
                                updated.customFormLocalId = nfpform.sqliteId
                                updated.isNotConfirmed = false
                                AssetFormLinkingDatabaseManager().upsert(item: updated) { success in }
                            }
                            FPFormDataHolder.shared.arrLinkingDB = []
                        }
                        self.isNew = false
                        FPFormDataHolder.shared.customForm = nfpform
                        self.fpClearAllTableDrafts()
                        self.delegate?.formUpdated(completion: nil)
                        self.stopLoadings()
                    }
                    completion(true)
                }else {
                    self.stopLoadings()
                    FPUtility.printErrorAndShowAlert(error: error)
                    completion(false)
                }
            }
        }
    }
    
    func continuePartialSave(form:FPForms, isDismiss:Bool, sectionIndex:Int, justScannedSection:Bool = false , completion: @escaping FPFormsServiceManager.successCompletionHandler){
        if FPUtility.isConnectedToNetwork(),  form.isSyncedToServer == false{
            self.saveForm(isDismiss: isDismiss, isRefreshForm: true) { status in
                completion(status)
            }
            return
        }
        isSaveRefreshing = true
        FPFormsServiceManager.uploadMediasAttachedForCurrentSection(section: sectionIndex) { [weak self] status in
            guard let self = self else { return }
            if(status){
                FPFormsServiceManager.uploadTableAttachmentsForCurrentSection(section: sectionIndex) { [weak self] isTableAttachmentUploaded in
                    guard let self = self else { return }
                    if(isTableAttachmentUploaded){
                        guard let formSection = FPFormDataHolder.shared.getProcessedSection(sectionIndex: sectionIndex) else{
                            self.stopLoadings()
                            return
                        }
                        FPUtility.findAssetLinkingsFor(form: form, linkingDelegate: self.linkingDelegate) { [weak self] assetLinkJson in
                            guard let self = self else { return }
                            FPFormsServiceManager.routeToPartialSaveCustomFormSection(ticketId: self.ticketId ?? 0, section: formSection, justScannedSection: justScannedSection, form: form, sectionIndex:sectionIndex, setSynced: false, assetLinkDetail: assetLinkJson) { [weak self] form, error in
                                if error == nil {
                                    self?.fpClearTableDraftsForSection(formSection)
                                    DispatchQueue.main.async { [weak self] in
                                        if isDismiss{
                                            // Full form dismissed — full draft cleanup handled by saveForm (line ~1211)
                                            self?.delegate?.formUpdated(completion: { [weak self] in
                                                self?.dismiss()
                                            })
                                        }else{
                                            self?.stopLoadings()
                                        }
                                    }
                                    completion(true)
                                }else {
                                    DispatchQueue.main.async { [weak self] in
                                        FPUtility.printErrorAndShowAlert(error: error)
                                        self?.stopLoadings()
                                    }
                                    completion(false)
                                }
                            }
                        }
                        
                    }else{
                        self.stopLoadings()
                    }
                }
            }else{
                self.stopLoadings()
                completion(false)
            }
        }
    }
    
    func validatePartialSectionToSave(sectionIndex:Int) -> Bool {
        if let formCF = FPFormDataHolder.shared.customForm, let currentSection  = formCF.sections?[safe: sectionIndex] {
            for fieldItem in currentSection.fields {
                if fieldItem.mandatory, fieldItem.needToCheckMandatoryFlag(), (fieldItem.value == nil || fieldItem.value?.isEmpty ?? false) {
                    _  = FPUtility.showAlertController(title: FPLocalizationHelper.localize("lbl_Data_required"), message: "\(fieldItem.displayName ?? "")", completion: nil)
                    return false
                }else if fieldItem.getUIType() == .BUTTON_RADIO{
                  //  if fieldItem.mandatory,
                    if let value = fieldItem.value?.lowercased(), fieldItem.openDeficencySelectedOption(value: value) == true, let reasnDict = fieldItem.reasons?.getArray().first as? [String:Any] {
                        if reasnDict["description"] == nil || (reasnDict["description"] as? String)?.isEmpty == true{
                            _  = FPUtility.showAlertController(title: FPLocalizationHelper.localize("error_dialog_title"), message: FPLocalizationHelper.localize("msg_select_reasons_all_deficiencies"), completion: nil)
                            return false
                        }
                    }
                }
            }
        }
        return true
    }
    
    
    //MARK: - Navigation bar button actions
    
    @IBAction func btnQuickNoteDidTap(_ sender: UIButton) {
        delegate?.addQuickNoteClicked()
    }
    
    @objc func saveButtonAction() {
        self.view.endEditing(true)
        if self.view.subviews.last?.tag == 1991{
            //means TableAttachementView is showing so first dismiss it then save  so ignoring save action
            return
        }
        
        // Wait briefly for keyboard to dismiss and text fields to commit their values
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.performSaveAction()
        }
    }
    
    private func performSaveAction() {
        if self.isNew {
            if(isPreviousForm){
                guard self.validateToSave() else {
                    return
                }
                showRenamePopup()
            }else{
                saveForm()
            }
        }else{
            if FPUtility.isConnectedToNetwork(), FPFormDataHolder.shared.customForm?.objectId == nil{
                self.saveForm()
            }else{
                // For existing forms, check if there are any changes
                if !FPFormDataHolder.shared.hasFormChanged() {
                    // No changes detected - just dismiss without saving
                    self.dismiss(isRefreshNeeded: false)
                    return
                }
                saveCurrentSection(isDismiss: true)
            }
        }
    }
    
    func saveForm(isDismiss:Bool = true, isRefreshForm:Bool = false, completion: ((_ status:Bool)->Void)? = nil){
        self.view.endEditing(true)
        guard self.validateToSave() else {
            stopLoadings()
            return
        }
        let snapshotFormLocalId = FPFormDataHolder.shared.customForm?.sqliteId?.stringValue
                                  ?? FPFormDataHolder.shared.customForm?.localClientId

        isSaveRefreshing = true
        
        self.btnNext.updateInteraction(isEnabled: false)
        self.btnPrevious.updateInteraction(isEnabled: false)
        
        DispatchQueue.main.asyncAfter(deadline: .now()+0.25, execute: { [weak self] in
            FPFormsServiceManager.uploadMediasAttached { [weak self] status in
                guard let self = self else { return }
                if(status){
                    FPFormsServiceManager.uploadTableAttachments { [weak self] isTableAttachmentUploaded in
                        guard let self = self else { return }
                        if(isTableAttachmentUploaded){
                            guard let form = FPFormDataHolder.shared.getProcessedForm(isNew:  self.isNew) else {
                                self.stopLoadings()
                                return
                            }
                            FPUtility.findAssetLinkingsFor(form: form, linkingDelegate: self.linkingDelegate) { [weak self] assetLinkJson in
                                guard let self = self else { return }
                                FPFormsServiceManager.routeToSaveCustomForm(ticketId:self.ticketId ?? 0, isNew: self.isNew, form:form , setSynced: false, assetLinkDetail: assetLinkJson) { [weak self] serverForm, error in
                                    if error == nil {
                                        let clearId = serverForm?.sqliteId?.stringValue ?? snapshotFormLocalId
                                        self?.fpClearAllTableDrafts(formLocalId: clearId)
                                        // Update session ID to use sqliteId if it became available after save
                                        FPFormDataHolder.shared.updateSessionIdWithSqliteId()

                                        if isDismiss{
                                            DispatchQueue.main.async { [weak self] in
                                                guard let self = self else { return }
                                                if form.objectId == nil {
                                                    // New form: stop loader, then refresh list + dismiss.
                                                    self.stopLoadings()
                                                    self.delegate?.refreshListNeeded()
                                                    self.dismiss()
                                                } else {
                                                    // Existing form: keep loader running while the host fetches local DB.
                                                    self.delegate?.formUpdated(completion: { [weak self] in
                                                        self?.dismiss()
                                                    })
                                                }
                                            }
                                        } else {
                                            self?.stopLoadings()
                                        }
                                        if isRefreshForm, let serverForm = serverForm{
                                            let fpform = serverForm
                                            fpform.isSyncedToServer = true
                                            fpform.sqliteId = FPFormDataHolder.shared.customForm?.sqliteId
                                            let sortedSection = serverForm.sections?.sorted(by:{$0.sortPosition ?? "" < $1.sortPosition ?? ""}) ?? []
                                            fpform.sections = []
                                            fpform.sections?.append(contentsOf: sortedSection)
                                            FPFormDataHolder.shared.customForm = fpform
                                        }
                                        completion?(true)
                                    }else {
                                        self?.stopLoadings()
                                        FPUtility.printErrorAndShowAlert(error: error)
                                        completion?(false)
                                    }
                                }
                            }
                        }else{
                            self.stopLoadings()
                            completion?(false)
                        }
                    }
                }else{
                    self.stopLoadings()
                    completion?(false)
                }
            }
        })
    }
    
    
    private func renameForm(name: String) {
        guard let form = FPFormDataHolder.shared.customForm else { return }
        form.name = name
        form.displayName = name
        FPFormsServiceManager.renameCustomForm(form: form) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.stopLoadings()
                if error == nil {
                    self.delegate?.formUpdated(completion: { [weak self] in
                        self?.dismiss()
                    })
                } else {
                    FPUtility.printErrorAndShowAlert(error: error)
                }
            }
        }
    }

    func saveFormOfflineForTable( completion: ((_ status:Bool)->Void)? = nil){
        guard let form = FPFormDataHolder.shared.getProcessedForm(isNew:  self.isNew) else {
            completion?(false)
            return
        }
        FPUtility.findAssetLinkingsFor(form: form, linkingDelegate: self.linkingDelegate) { [weak self] assetLinkJson in
            guard let self = self else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                // Generate localClientId if not already set (similar to sqliteId assignment pattern)
                if form.localClientId == nil || form.localClientId?.isEmpty == true {
                    form.localClientId = FPUtility.nanoID()
                }
                form.isSyncedToServer = false
                form.isActive = true
                FPFormsServiceManager.upsertLocalData(ticketId: self.ticketId ?? 0, moduleId: FPFormMduleId, form: form) { form, error in
                    FPFormDataHolder.shared.updateSessionIdWithSqliteId()
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
                    FPFormDataHolder.shared.customForm = form
                    completion?(true)
                }
            }
            return
        }
    }
    
    func saveEmptyForm(completion:@escaping(_ status:Bool)->Void){
        self.view.endEditing(true)
        let snapshotFormLocalId = FPFormDataHolder.shared.customForm?.sqliteId?.stringValue
                                  ?? FPFormDataHolder.shared.customForm?.localClientId
        isSaveRefreshing = true
        DispatchQueue.main.asyncAfter(deadline: .now()+0.25, execute: {
            FPFormsServiceManager.uploadMediasAttached { status in
                if(status){
                    FPFormsServiceManager.uploadTableAttachments { isTableAttachmentUploaded in
                        if(isTableAttachmentUploaded){
                            guard let form = FPFormDataHolder.shared.getProcessedForm(isNew:  self.isNew) else {
                                self.stopLoadings()
                                return
                            }
                            FPUtility.findAssetLinkingsFor(form: form, linkingDelegate: self.linkingDelegate) { assetLinkJson in
                                FPFormsServiceManager.routeToSaveCustomForm(ticketId:self.ticketId ?? 0, isNew: self.isNew, form:form , setSynced: false, assetLinkDetail: assetLinkJson) { [weak self]  serverForm, error in
                                    DispatchQueue.main.async {
                                        self?.stopLoadings()
                                        if error == nil {
                                            self?.fpClearAllTableDrafts(formLocalId: snapshotFormLocalId)
                                            FPFormDataHolder.shared.customForm = serverForm
                                            // Update session ID to use sqliteId if it became available after save
                                            FPFormDataHolder.shared.updateSessionIdWithSqliteId()
                                            self?.customForm = serverForm
                                            self?.isNew = false
                                            self?.delegate?.refreshListNeeded()
                                            completion(true)
                                        }else{
                                            FPUtility.printErrorAndShowAlert(error: error)
                                            completion(false)
                                        }
                                    }
                                }
                            }
                        }else{
                            self.stopLoadings()
                            completion(false)
                        }
                    }
                }else{
                    self.stopLoadings()
                    completion(false)
                }
            }
        })
    }
    
    func stopLoadings(){
        DispatchQueue.main.async {
            self.isSaveRefreshing = false
            self.btnNext.isLoading = false
            self.btnPrevious.isLoading = false
           
            self.barSaveButton?.isEnabled = true
            self.handleSectionButtonsInteraction()
            
            self.imgFormTitleEdit.isHidden = false
            self.formNameActivityLoader.stopAnimating()

            self.sectionDropDownActivityLoader.stopAnimating()

        }
    }
    
    func showRenameCurrentSection(){
        let alertController = UIAlertController(
            title: FPLocalizationHelper.localize("lbl_Rename_Section"),
            message: nil,
            preferredStyle: .alert)
        alertController.addTextField(configurationHandler: { [self] textField in
            textField.placeholder = FPLocalizationHelper.localize("lbl_Name")
            textField.text = FPFormDataHolder.shared.getFormSections()[safe:self.section]?.displayName
            textField.textColor = .blue
            textField.clearButtonMode = .whileEditing
        })
        alertController.addAction(UIAlertAction(title: FPLocalizationHelper.localize("OK"), style: .default, handler: { action in
            let textField =  alertController.textFields?.first
            alertController.dismiss(animated: true) {
//                if let strName = textField?.text, !strName.trim.isEmpty {
//                    FPFormDataHolder.shared.getFormSections()[safe:self.section]?.displayName = strName
//                    FPFormDataHolder.shared.customForm?.isSyncedToServer = FPUtility.isConnectedToNetwork()
//                    self.refreshSection(isSectionNameRefresh: true)
//                }else{
//                    let invalidNameAlert = UIAlertController(title: FPLocalizationHelper.localize("error_dialog_title"),
//                                                             message: FPLocalizationHelper.localize("Invalid_Name"),
//                                                             preferredStyle: .alert)
//                    invalidNameAlert.addAction(UIAlertAction(title: FPLocalizationHelper.localize("OK"), style: .default) { _ in
//                        self.showRenameCurrentSection()
//                    })
//                    self.present(invalidNameAlert, animated: true, completion: nil)
//                }
                
                if let strName = textField?.text, !strName.trim.isEmpty {
                    let textCount = strName.trim.count
                    if UserDefaults.libCurrentLanguage.contains(LIB_ENGLISH_LANGUAGE_CODE),strName.rangeOfCharacter(from: CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLKMNOPQRSTUVWXYZ _0123456789-.()").inverted) != nil{
                        let invalidNameAlert = UIAlertController(title: FPLocalizationHelper.localize("Invalid_Name"),
                                                                 message: FPLocalizationHelper.localize("msg_plsNoEnterSpecialChars"),
                                                                 preferredStyle: .alert)
                        invalidNameAlert.addAction(UIAlertAction(title: FPLocalizationHelper.localize("OK"), style: .default) { _ in
                            self.showRenameCurrentSection()
                        })
                        invalidNameAlert.applyLegacyActionSheetStyle()
                        self.present(invalidNameAlert, animated: true, completion: nil)
                    }else if textCount > 256{
                        let fileNameTooLongAlert = UIAlertController(title: FPLocalizationHelper.localize("error_dialog_title"),
                                                                     message: FPLocalizationHelper.localize("msg_enterShortfileName"),
                                                                     preferredStyle: .alert)
                        fileNameTooLongAlert.addAction(UIAlertAction(title: FPLocalizationHelper.localize("OK"), style: .default) { _ in
                            self.showRenameCurrentSection()
                        })
                        fileNameTooLongAlert.applyLegacyActionSheetStyle()
                        self.present(fileNameTooLongAlert, animated: true, completion: nil)
                    }else{
                        FPFormDataHolder.shared.getFormSections()[safe:self.section]?.displayName = strName
                        FPFormDataHolder.shared.customForm?.isSyncedToServer = FPUtility.isConnectedToNetwork()
                        self.refreshSection(isSectionNameRefresh: true)
                    }
                }else{
                    let invalidNameAlert = UIAlertController(title: FPLocalizationHelper.localize("error_dialog_title"),
                                                             message: FPLocalizationHelper.localize("Invalid_Name"),
                                                             preferredStyle: .alert)
                    invalidNameAlert.addAction(UIAlertAction(title: FPLocalizationHelper.localize("OK"), style: .default) { _ in
                        self.showRenameCurrentSection()
                    })
                    invalidNameAlert.applyLegacyActionSheetStyle()
                    self.present(invalidNameAlert, animated: true, completion: nil)
                }
            }
        }))
        alertController.addAction(.init(title: FPLocalizationHelper.localize("Cancel"), style: .cancel, handler: { action in
            alertController.dismiss(animated: true)
        }))
        alertController.applyLegacyActionSheetStyle()
        self.present(alertController, animated: true)
    }
    
    func showRenamePopup(){
        let alertController = UIAlertController(
            title: FPLocalizationHelper.localize("lbl_Rename_Form"),
            message: FPLocalizationHelper.localize("msg_noEnterSpecialChars"),
            preferredStyle: .alert)
        alertController.addTextField(configurationHandler: { [self] textField in
            textField.placeholder = FPLocalizationHelper.localize("lbl_Name")
            textField.text = self.customForm.displayName
            textField.textColor = .blue
            textField.clearButtonMode = .whileEditing
        })
        
        alertController.addAction(UIAlertAction(title: FPLocalizationHelper.localize("OK"), style: .default, handler: { action in
            let textField =  alertController.textFields?.first
            alertController.dismiss(animated: true) {
                if let strName = textField?.text, !strName.trim.isEmpty {
                    let textCount = strName.trim.count
                    if UserDefaults.libCurrentLanguage.contains(LIB_ENGLISH_LANGUAGE_CODE),strName.rangeOfCharacter(from: CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLKMNOPQRSTUVWXYZ _0123456789-.").inverted) != nil{
                        let invalidNameAlert = UIAlertController(title: FPLocalizationHelper.localize("Invalid_Name"),
                                                                 message: FPLocalizationHelper.localize("msg_plsNoEnterSpecialChars"),
                                                                 preferredStyle: .alert)
                        invalidNameAlert.addAction(UIAlertAction(title: FPLocalizationHelper.localize("OK"), style: .default) { _ in
                            self.showRenamePopup()
                        })
                        invalidNameAlert.applyLegacyActionSheetStyle()
                        self.present(invalidNameAlert, animated: true, completion: nil)
                    }else if textCount > 256{
                        let fileNameTooLongAlert = UIAlertController(title: FPLocalizationHelper.localize("error_dialog_title"),
                                                                     message: FPLocalizationHelper.localize("msg_enterShortfileName"),
                                                                     preferredStyle: .alert)
                        fileNameTooLongAlert.addAction(UIAlertAction(title: FPLocalizationHelper.localize("OK"), style: .default) { _ in
                            self.showRenamePopup()
                        })
                        fileNameTooLongAlert.applyLegacyActionSheetStyle()
                        self.present(fileNameTooLongAlert, animated: true, completion: nil)
                    }else{
                        self.proceedToEditFormName(strName: strName)
                    }
                }else{
                    let invalidNameAlert = UIAlertController(title: FPLocalizationHelper.localize("Invalid_Name"),
                                                             message: FPLocalizationHelper.localize("msg_formNameNotBlank"),
                                                             preferredStyle: .alert)
                    invalidNameAlert.addAction(UIAlertAction(title: FPLocalizationHelper.localize("OK"), style: .default) { _ in
                        self.showRenamePopup()
                    })
                    invalidNameAlert.applyLegacyActionSheetStyle()
                    self.present(invalidNameAlert, animated: true, completion: nil)
                }
            }
        }))
        
        alertController.addAction(.init(title: FPLocalizationHelper.localize("Cancel"), style: .cancel, handler: { action in
            alertController.dismiss(animated: true)
        }))
        alertController.applyLegacyActionSheetStyle()
        self.present(alertController, animated: true)
    }
    
    func proceedToEditFormName(strName:String){
        self.customForm.name = strName
        self.customForm.displayName = strName
        FPFormDataHolder.shared.customForm?.name = strName
        FPFormDataHolder.shared.customForm?.displayName = strName
        self.imgFormTitleEdit.isHidden = true
        self.formNameActivityLoader.isHidden = false
        self.formNameActivityLoader.startAnimating()
        self.btnNext.updateInteraction(isEnabled: false)
        self.btnPrevious.updateInteraction(isEnabled: false)
        self.barSaveButton?.isEnabled = false
        let formExistsLocally = self.customForm.objectId != nil || self.customForm.sqliteId != nil
        if formExistsLocally {
            self.renameForm(name: strName)
        } else {
            self.saveForm()
        }
    }
    
    func cloneCurrentForm() {
        self.isNew = true
        self.isPreviousForm = false
        self.customForm.isAnalysed = false
        DispatchQueue.main.async {
            self.initializeView()
            self.formTableView.reloadData()
        }
    }
    
    @objc func cancelButtonAction() {
        // Close keyboard first
        self.view.endEditing(true)
        
        // Wait briefly for keyboard to dismiss and text fields to commit their values
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.performCancelAction()
        }
    }
    
    private func performCancelAction() {
        if(isNew && !isFromHistory){
            _ = FPUtility.showAlertController(title: FPLocalizationHelper.localize("alert_dialog_title"), andMessage: FPLocalizationHelper.localize("msg_are_sure_data_lost"), completion: nil, withPositiveAction: FPLocalizationHelper.localize("Yes"), style: .default, andHandler: { (action) in
                if let form = FPFormDataHolder.shared.customForm, let _ = form.sqliteId{
                    FPFormsServiceManager.deleteFormLocally(form: form, ticketId: self.ticketId ?? 0, moduleId: FPFormMduleId) { form, error in
                        DispatchQueue.main.async {
                            AssetFormLinkingDatabaseManager().fetchAndRemoveNotConfirmedAssetLinkingForForm(FPFormDataHolder.shared.customForm)
                            self.fpClearAllTableDrafts()
                            self.dismiss(isRefreshNeeded: true)
                        }
                    }
                }else{
                    AssetFormLinkingDatabaseManager().fetchAndRemoveNotConfirmedAssetLinkingForForm(FPFormDataHolder.shared.customForm)
                    self.dismiss(isRefreshNeeded: true)
                }
            }, withNegativeAction: FPLocalizationHelper.localize("Cancel"), style: .default, andHandler: nil)
        }else{
            // For existing forms, check if there are unsaved changes
            if FPFormDataHolder.shared.hasFormChanged() {
                // Show alert about unsaved changes
                _ = FPUtility.showAlertController(
                    title: FPLocalizationHelper.localize("alert_dialog_title"),
                    andMessage: FPLocalizationHelper.localize("msg_are_sure_data_lost"),
                    completion: nil,
                    withPositiveAction: FPLocalizationHelper.localize("Yes"),
                    style: .default,
                    andHandler: { (action) in
                        AssetFormLinkingDatabaseManager().fetchAndRemoveNotConfirmedAssetLinkingForForm(FPFormDataHolder.shared.customForm)
                        self.fpClearAllTableDrafts()
                        // Dismiss without saving - no refresh needed
                        self.dismiss(isRefreshNeeded: false)
                    },
                    withNegativeAction: FPLocalizationHelper.localize("Cancel"),
                    style: .default,
                    andHandler: nil
                )
            } else {
                // No changes detected - dismiss directly without alert or refresh
                AssetFormLinkingDatabaseManager().fetchAndRemoveNotConfirmedAssetLinkingForForm(FPFormDataHolder.shared.customForm)
                self.fpClearAllTableDrafts()
                // Dismiss without refresh since nothing changed
                self.dismiss(isRefreshNeeded: false)
            }
        }
    }
    
    
    func dismiss(isRefreshNeeded:Bool = false)  {
        stopLoadings()
        self.resignFirstResponder()
        // Clear session ID immediately when dismissing
        FPFormDataHolder.shared.currentFormSessionId = ""
        DispatchQueue.main.asyncAfter(
            deadline:.now()+0.2,
            execute: {
                FPFormDataHolder.shared.reset()
            })
        if isNew{
            self.delegate?.newFormCancelClicked()
        }
        self.navigationController?.dismiss(animated: true) {
            if isRefreshNeeded{
                self.delegate?.formUpdated(completion: nil)
            }
        }
    }
    
    func validateToSave() -> Bool {
        if let formCF = FPFormDataHolder.shared.customForm {
            for item in formCF.sections ?? [] {
                for fieldItem in item.fields {
                    if fieldItem.mandatory, fieldItem.needToCheckMandatoryFlag(), (fieldItem.value == nil || fieldItem.value?.isEmpty ?? false) {
                        _  = FPUtility.showAlertController(title: FPLocalizationHelper.localize("lbl_Data_required"), message: "\(fieldItem.displayName ?? "")", completion: nil)
                        return false
                    }else if fieldItem.getUIType() == .BUTTON_RADIO{
                       // if fieldItem.mandatory,
                         if let value = fieldItem.value?.lowercased(), fieldItem.openDeficencySelectedOption(value: value) == true, let reasnDict = fieldItem.reasons?.getArray().first as? [String:Any] {
                            if reasnDict["description"] == nil || (reasnDict["description"] as? String)?.isEmpty == true{
                                _  = FPUtility.showAlertController(title: FPLocalizationHelper.localize("error_dialog_title"), message: FPLocalizationHelper.localize("msg_select_reasons_all_deficiencies"), completion: nil)
                                return false
                            }
                        }
                    }
                }
            }
        }
        return true
    }

    private func fpClearAllTableDrafts(formLocalId override: String? = nil) {
        let tid = self.ticketId?.stringValue ?? "0"
        let fid = override
                  ?? FPFormDataHolder.shared.customForm?.sqliteId?.stringValue
                  ?? FPFormDataHolder.shared.customForm?.localClientId
                  ?? "0"
        FPTableDraftDatabaseManager().deleteAllDraftsForForm(ticketId: tid, formLocalId: fid)
    }

    private func fpClearTableDraftsForSection(_ section: FPSectionDetails) {
        let tableFields = section.fields.filter {
            let t = $0.getUIType()
            return t == .TABLE || t == .TABLE_RESTRICTED
        }
        guard !tableFields.isEmpty else { return }
        DispatchQueue.global(qos: .utility).async {
            for field in tableFields {
                let sid = field.sqliteId?.int64Value
                let oid = field.objectId?.stringValue
                FPTableDraftDatabaseManager().deleteDraftsForField(fieldLocalId: sid, fieldId: oid)
            }
        }
    }
}



//MARK: Text Field delegate
extension FPFormViewController: UITextFieldDelegate{
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if textField == txtFieldSection{
            self.previousSection = self.section
            pickerView?.selectRow(self.section, inComponent: 0, animated: true)
            self.btnNext.updateInteraction(isEnabled: false)
            self.btnPrevious.updateInteraction(isEnabled: false)
        }
        return true
    }
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        if textField == txtFieldSection{
            self.btnNext.updateInteraction(isEnabled: true)
            self.btnPrevious.updateInteraction(isEnabled: true)
        }
        return true
    }
}

extension FPFormViewController: UITableViewDataSource,UITableViewDelegate{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return FPFormDataHolder.shared.getFieldsCountFor(section: self.section)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let sectionItem = FPFormDataHolder.shared.getRowForSection(self.section, at: indexPath.row) else{return UITableViewCell()}
        switch(sectionItem.getUIType()){
        case .CHART:
            return getChartCellFor(tableView: tableView, sectionItem, indexPath)
        case .LABEL:
            return getLabelCellFor(tableView: tableView, sectionItem, indexPath)
        case .INPUT,.AUTO_POPULATE,.TEXTAREA, .SCANNER: //, .DROPDOWN
            return getTextCellFor(tableView: tableView, sectionItem, indexPath)
        case .DROPDOWN:
            return getDropDownCellFor(tableView: tableView, sectionItem, indexPath)
        case .RADIO, .CHECKBOX:
            return getRadioCellFor(tableView: tableView, sectionItem, indexPath)
        case .TABLE, .TABLE_RESTRICTED:
            return getTableCellFor(tableView: tableView, sectionItem, indexPath)
        case .BUTTON_RADIO:
            return getRadioButtonCellFor(tableView: tableView, sectionItem, indexPath)
        case .FILE:
            return getFileCell(tableView: tableView, sectionItem, indexPath)
        case .SIGNATURE_PAD:
            return getSignatureCellFor(tableView: tableView, sectionItem, indexPath)
        default:
            return UITableViewCell()
            
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? FPTableCollectionViewCell {
            // Do layout immediately without delay to prevent async block pileup
            // Remove nested reloadData() as it causes scroll hangs
            cell.collMain.layoutIfNeeded()
            cell.setNeedsLayout()
            cell.layoutIfNeeded()
            cell.recalculateLayout()
        }
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        // Provide estimated height to help table view calculate cell positions correctly
        // This prevents cells from being configured with incorrect bounds
        guard let sectionItem = FPFormDataHolder.shared.getRowForSection(self.section, at: indexPath.row) else{
            return 200 // Default estimated height
        }
        
        // Return a reasonable estimate based on field type
        if sectionItem.getUIType() == .TABLE {
            return 300 // Tables typically need more height
        }
        return 200 // Default for other field types
    }
    
    fileprivate func fileItemDidTapped(_ title: String, _ indexPath: IndexPath) {
        if let ssMedia = FPFormDataHolder.shared.getFiledFilesArrayForSection(section: self.section)[indexPath]?.first(where: {$0.name == title}), FPUtility.isConnectedToNetwork() ||  ssMedia.id == nil {
            self.handleFileMedia(ssMedia)
        } else {
            _  = FPUtility.showAlertController(title: FPLocalizationHelper.localize("alert_dialog_title"), message:
                                                FPLocalizationHelper.localize("msg_can_not_view_attachment_offline")){}
        }
    }
    
    /// Presents file preview, downloading from server if needed
    fileprivate func handleFileMedia(_ ssMedia: SSMedia) {
        FPMedia.getPreviewFilePath(fileName: ssMedia.name, serverUrl: ssMedia.serverUrl) { [weak self] filePath in
            guard let self = self, let filePath = filePath else { return }
            
            let fileUrl = URL(fileURLWithPath: filePath)
            self.presentFilePreview(url: fileUrl)
        }
    }
    
    /// Presents file preview using UIDocumentInteractionController
    private func presentFilePreview(url: URL) {
        let documentInteractionController = UIDocumentInteractionController(url: url)
        documentInteractionController.delegate = self
        DispatchQueue.main.async {
            documentInteractionController.presentPreview(animated: true)
        }
    }
    
    //MARK: get file cell
    fileprivate func getFileCell(tableView: UITableView, _ sectionItem: FPFieldDetails, _ indexPath: IndexPath)-> UITableViewCell {
        
        if let cell = tableView.dequeueReusableCell(withIdentifier: FILE_CELL) as? FPFileInputTableViewCell {
            let fileIndexPath =  IndexPath(row: indexPath.row, section: self.section)
            if let value = sectionItem.value?.getArray(), !(isFileAttachedInIndex[fileIndexPath] ?? false) {
                isFileAttachedInIndex[fileIndexPath] = true
                value.forEach { uploadedItem in
                    if let name = uploadedItem["altText"] as? String, let id = uploadedItem["id"] as? String {
                        let media  = SSMedia(name: name, id: self.isPreviousForm ? "": id, mimeType: (uploadedItem["file"] as? String)?.fileMimeType(), serverUrl: uploadedItem["file"] as? String, moduleType: .forms)
                        FPFormDataHolder.shared.addFileAt(index:fileIndexPath, withMedia: media)
                    }
                }
            }
            
            if sectionItem.mandatory{
                let fontAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 17, weight: .semibold), .foregroundColor: UIColor.black]
                let baseString =  NSAttributedString(string: " \(sectionItem.displayName ?? "")", attributes: fontAttributes)
                let attributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.red]
                let starString =  NSAttributedString(string: "*", attributes: attributes)
                let mutableString = NSMutableAttributedString(attributedString: starString)
                mutableString.append(baseString)
                cell.lblQuestion.attributedText = mutableString
            }else{
                cell.lblQuestion.text = sectionItem.displayName
                cell.lblQuestion.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
                cell.lblQuestion.textColor = .black
            }
            cell.indexPath = fileIndexPath
            cell.delegate = self
            cell.tagListView.enableRemoveButton = !self.isAnalysed
            cell.btnAttachFile.isHidden = self.isAnalysed
            cell.configureCell(files: FPFormDataHolder.shared.getFiledFilesArrayForSection(section: self.section)[fileIndexPath])
            cell.onItemsRemoved = { index in
                if !self.isAnalysed{
                    if let media = FPFormDataHolder.shared.getFiledFilesArrayForSection(section: self.section)[fileIndexPath]?[index], FPUtility.isConnectedToNetwork() ||  media.id == nil  {
                        FPFormDataHolder.shared.removeMediaAt(indexPath: fileIndexPath, index: index)
                        self.formTableView.reloadData()
                    } else {
                        _  = FPUtility.showAlertController(title:FPLocalizationHelper.localize("alert_dialog_title"), message:
                                                            FPLocalizationHelper.localize("msg_can_not_delete_attachment_offline")){}
                    }
                }
                
            }
            cell.onItemsClicked = { title in
                self.fileItemDidTapped(title,fileIndexPath)
            }
            return cell
        }
        return UITableViewCell()
    }
    
    fileprivate func ngetFileCell(tableView: UITableView, _ sectionItem: FPFieldDetails, _ indexPath: IndexPath)-> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "FPFileAttachmentFieldCell")
        cell?.backgroundColor = .clear
        cell?.selectionStyle = .none
        
        let fileIndexPath =  IndexPath(row: indexPath.row, section: self.section)
        if let value = sectionItem.value?.getArray(), !(isFileAttachedInIndex[fileIndexPath] ?? false) {
            isFileAttachedInIndex[fileIndexPath] = true
            value.forEach { uploadedItem in
                if let name = uploadedItem["altText"] as? String, let id = uploadedItem["id"] as? String {
                    let media  = SSMedia(name: name, id: self.isPreviousForm ? "": id, mimeType: (uploadedItem["file"] as? String)?.fileMimeType(), serverUrl: uploadedItem["file"] as? String, moduleType: .forms)
                    FPFormDataHolder.shared.addFileAt(index:fileIndexPath, withMedia: media)
                }
            }
        }
        cell?.contentConfiguration = UIHostingConfiguration {
            FPFileAttachmentFieldCell(
                displayName: sectionItem.displayName ?? "",
                items: (FPFormDataHolder.shared.getFiledFilesArrayForSection(section: self.section)[fileIndexPath] ?? []).map(\.name),
                isViewOnly: self.isAnalysed) {
                    if !self.isAnalysed{
                        self.attachmentIndex = fileIndexPath
                        self.isImageOnly = self.isImageOnly
                        self.addAttachmentTouched(sender: cell ?? UIView())
                    }
                } onItemsRemoved: { index in
                    if !self.isAnalysed{
                        if let media = FPFormDataHolder.shared.getFiledFilesArrayForSection(section: self.section)[fileIndexPath]?[safe:index], FPUtility.isConnectedToNetwork() ||  media.id == nil  {
                            FPFormDataHolder.shared.removeMediaAt(indexPath: fileIndexPath, index: index)
                            self.formTableView.reloadData()
                        } else {
                            _  = FPUtility.showAlertController(title:FPLocalizationHelper.localize("alert_dialog_title"), message: FPLocalizationHelper.localize("msg_can_not_delete_attachment_offline")){}
                        }
                    }
                } onItemsClicked: { item in
                    self.fileItemDidTapped(item,fileIndexPath)
                }

        }
        .margins(.all, 0)
        
        return cell ?? UITableViewCell()
    }
    
    
    //MARK: get Radio Cell
    
    fileprivate func getRadioCellFor(tableView: UITableView, _ sectionItem: FPFieldDetails, _ indexPath: IndexPath)-> UITableViewCell {
        
        if isNew, let defaultVal = sectionItem.defaultValue, !defaultVal.trim.isEmpty, let val = sectionItem.value, val.trim.isEmpty{
            if sectionItem.getUIType() != .CHECKBOX {
                sectionItem.value = defaultVal
            }
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "FPRadioCheckboxFieldCell")
        cell?.backgroundColor = .clear
        cell?.selectionStyle = .none
        cell?.isUserInteractionEnabled = !self.isAnalysed
        cell?.contentConfiguration = UIHostingConfiguration {
            FPRadioCheckboxFieldCell(
                isNew: self.isNew,
                fieldItem: sectionItem,
                section: section,
                tag: indexPath.row,
                arrOptions: self.getRadioOptions(section: section, row: indexPath.row, item: sectionItem)) { value in
                    FPFormDataHolder.shared.updateRowWith(value: value, inSection: self.section, atIndex: indexPath.row)
                    self.safeReloadRows([indexPath])
                }
        }
        .margins(.all, 0)
        return cell ?? UITableViewCell()
    }
    
    private func safeReloadRows(_ indexPaths: [IndexPath]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let section = 0
            let tableViewRows = self.formTableView.numberOfRows(inSection: section)
            let dataSourceRows = FPFormDataHolder.shared.getFieldsCountFor(section: self.section)
            
            // If the counts don't match, reloadData is the only safe way to recover
            if tableViewRows != dataSourceRows {
                DispatchQueue.main.async{
                    self.formTableView.reloadData()
                }
                return
            }
            
            // Filter paths to ensure they are within current bounds and belong to the correct section
            let validPaths = indexPaths.filter { $0.row >= 0 && $0.row < tableViewRows && $0.section == section }
            guard !validPaths.isEmpty else { return }

            DispatchQueue.main.async{
                self.formTableView.beginUpdates()
                self.formTableView.reloadRows(at: validPaths, with: .automatic)
                self.formTableView.endUpdates()
            }
        }
    }
    
    //MARK: get Input Cell
    
    fileprivate func getLabelCellFor(tableView: UITableView, _ sectionItem: FPFieldDetails, _ indexPath: IndexPath)->UITableViewCell{
        let cell = tableView.dequeueReusableCell(withIdentifier: "FPLabelFieldCell")
        cell?.backgroundColor = .clear
        cell?.selectionStyle = .none
        cell?.contentConfiguration = UIHostingConfiguration {
            FPLabelFieldCell(fieldItem: sectionItem)
        }
        .margins(.all, 0)
        FPFormDataHolder.shared.updateRowWith(value: sectionItem.displayName ?? "", inSection: section, atIndex: indexPath.row)
        cell?.isUserInteractionEnabled = !self.isAnalysed
        return cell ?? UITableViewCell()
    }
    
    
    fileprivate func getTextCellFor(tableView: UITableView, _ sectionItem: FPFieldDetails, _ indexPath: IndexPath)->UITableViewCell{
        
        var datePmode:UIDatePicker.Mode = .date
        if sectionItem.getDataType() == .TIME {
            datePmode = .time
        }else if sectionItem.getDataType() == .DATE_TIME {
            datePmode = .dateAndTime
        }
        
        var fieldValue = util.fetchCompataibleSpecialCharsStringFromDB(strInput: sectionItem.value ?? "")
        if self.isNew, let defaultVal = sectionItem.defaultValue, !defaultVal.trim.isEmpty, let val = sectionItem.value, val.trim.isEmpty{
            fieldValue = util.fetchCompataibleSpecialCharsStringFromDB(strInput: defaultVal)
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "FPInputFieldCell")
        cell?.backgroundColor = .clear
        cell?.selectionStyle = .none
        cell?.isUserInteractionEnabled = !self.isAnalysed
        cell?.contentConfiguration = UIHostingConfiguration {
            FPInputFieldCell(fieldItem: sectionItem, ticketId: self.ticketId, datePickerMode: datePmode, sectionIndex: section, fieldIndex: indexPath.row, isNew: self.isNew, fieldValue: fieldValue) { fieldTemplateId, fieldSectionId in
                if sectionItem.getUIType() == .SCANNER {
                    self.linkingDelegate?
                        .openScannerField(
                            baseVc: self,
                            fieldTemplateId: fieldTemplateId
                        )
                }else{
                    UserDefaults.currentScannerSectionId = fieldSectionId
                    self.linkingDelegate?
                        .openBarcodeScanner(
                            isOverWriteAsset: true,
                            baseVc: self,
                            linkedAssets: [],
                            fieldTemplateId:fieldTemplateId
                        )
                }
            } onFieldInputChanged: { sectionIndex, fieldIndex, pickerIndex, value, date, isSectionDuplicationField in
                self.selectedValue(for: sectionIndex, fieldIndex: fieldIndex, pickerIndex: pickerIndex, value: value, date: date, isSectionDuplicationField: isSectionDuplicationField)
            } onBarcodeInputChanged: { strBarcode in
                self.linkingDelegate?
                    .openAssetDetailsForLinking(
                        serialNumber: strBarcode,
                        baseVc: self
                    )
            }
        }
        .margins(.all, 0)
        return cell ?? UITableViewCell()
    }
    
    fileprivate func getDropDownCellFor(tableView: UITableView, _ sectionItem: FPFieldDetails, _ indexPath: IndexPath)->UITableViewCell{
        if let cell = tableView.dequeueReusableCell(withIdentifier: "FPDropDownTableViewCell")  as? FPDropDownTableViewCell {
            cell.isNew = self.isNew
            cell.configureCell(item: sectionItem, sectionIndex:section, tag: indexPath.row)
            cell.delegate = self
            cell.isUserInteractionEnabled = !self.isAnalysed
            return cell
        }
        return UITableViewCell()
    }
    
    fileprivate func getTableCellFor(tableView: UITableView, _ sectionItem: FPFieldDetails, _ indexPath: IndexPath)->UITableViewCell{
        if let cell = tableView.dequeueReusableCell(withIdentifier: TABLE_CELL)  as? FPTableCollectionViewCell{
            cell.delegate = self
            cell.fpViewController = self
            cell.zenFormsDelegate = self.delegate
            cell.isNew = self.isNew
            cell.configureCell(with: sectionItem, sectionDetail: FPFormDataHolder.shared.getSection(at: self.section), indexPath:  IndexPath(row: indexPath.row, section: section), customForm: customForm)
            return cell
        }
        return UITableViewCell()
    }
    
    
    fileprivate func getChartCellFor(tableView: UITableView, _ sectionItem: FPFieldDetails, _ indexPath: IndexPath)->UITableViewCell{
        let cell = tableView.dequeueReusableCell(withIdentifier: "FPChartFieldCell")
        cell?.backgroundColor = .clear
        cell?.selectionStyle = .none
        var isNoChartData: Bool = false
        var linChartView: LineChartView?
        if let dictValue = sectionItem.value?.getDictonary(), !dictValue.isEmpty{
            var arrDatasets = [[String:Any]]()
            if let value = dictValue["datasets"] as? [[String:Any]]{
                arrDatasets.append(contentsOf: value)
            }
            var arrXLablels = [String]()
            if let lablels = dictValue["labels"] as? [String]{
                arrXLablels.append(contentsOf: lablels)
            }
            if arrDatasets.isEmpty{
                isNoChartData = true
            }
            linChartView =  util.renderSwiftChart(dictValue: dictValue, xLbls: arrXLablels)
        }else{
            isNoChartData = true
        }
        cell?.contentConfiguration = UIHostingConfiguration {
            FPChartFieldCell(
                displayName: sectionItem.displayName?.handleAndDisplayApostrophe() ?? "",
                isNoChartData: isNoChartData,
                linChartView: linChartView) {
                    self.btnViewChartClickedAt(indexPth: indexPath)
                }
        }
        .margins(.all, 0)
        return cell ?? UITableViewCell()
    }
    
    fileprivate func getRadioButtonCellFor(tableView: UITableView, _ sectionItem: FPFieldDetails, _ indexPath: IndexPath)->UITableViewCell{
        if let cell = tableView.dequeueReusableCell(withIdentifier: SEGMENT_CELL) as? ReasonsCollectionViewCell {
            cell.delegate = self
            cell.fileInputDelegate = self
            cell.zenFormDelegate = self.delegate
            cell.isNew = self.isNew
            cell.customView.isAnalysed = self.isAnalysed
            cell.configureCell(with: sectionItem, indexPath: IndexPath(row: indexPath.row, section: section))
            return cell
        }
        return UITableViewCell()
        
    }
    
    fileprivate func ngetRadioButtonCellFor(tableView: UITableView, _ sectionItem: FPFieldDetails, _ indexPath: IndexPath)->UITableViewCell{
        
        let fieldIndxPath = IndexPath(row: indexPath.row, section: section)

        let cell = tableView.dequeueReusableCell(withIdentifier: "FPDeficiencySegmentCell")
        cell?.backgroundColor = .clear
        cell?.selectionStyle = .none

        if let files = sectionItem.attachments?.getArray(){
            files.forEach { uploadedItem in
                if let name = uploadedItem["altText"] as? String{
                    if  uploadedItem["isDeleted"] as? Bool == false ||  uploadedItem["isDeleted"]  == nil {
                        let media  = SSMedia(name: name, id: uploadedItem["id"] as? String , mimeType: (uploadedItem["file"] as? String)?.fileMimeType(), serverUrl: uploadedItem["file"] as? String, moduleType: .forms)
                        if(!sectionItem.deletedFiles.contains(media.id ?? "")){
                            FPFormDataHolder.shared.addFileAt(index:fieldIndxPath, withMedia: media)
                        }
                    }
                }
            }
        }
        let reasons = sectionItem.getReasonsList(strJson: sectionItem.reasons ?? "")
        let reasonsComponent = FPReasonsComponent().preparedData(reasons ?? [FPReasons](), value: sectionItem.value, templateId: sectionItem.templateId ?? "")
        cell?.contentConfiguration = UIHostingConfiguration {
            FPDeficiencySegmentCell(
                fieldItem: sectionItem,
                reasonsComponent: reasonsComponent,
                fieldIndexPath: fieldIndxPath,
                selectedIndex:  sectionItem.getSelectedIndex(reasonsComponent.value ?? ""),
                customReason: reasonsComponent.customReason?.description ?? "",
                items: (FPFormDataHolder.shared.getFiledFilesArray()[fieldIndxPath] ?? []).map(\.name),
                isViewOnly: self.isAnalysed) {
                    if !self.isAnalysed{
                        self.attachmentIndex = fieldIndxPath
                        self.isImageOnly = true
                        self.addAttachmentTouched(sender: cell ?? UIView())
                    }
                } onItemsRemoved: { index in
                    if !self.isAnalysed{
                        if let media = FPFormDataHolder.shared.getFiledFilesArray()[fieldIndxPath]?[safe:index], FPUtility.isConnectedToNetwork() ||  media.id == nil  {
                            FPFormDataHolder.shared.removeMediaAt(indexPath: fieldIndxPath, index: index)
                            self.reloadCollectionAt(index: fieldIndxPath)
                        } else {
                            _  = FPUtility.showAlertController(title:FPLocalizationHelper.localize("alert_dialog_title"), message: FPLocalizationHelper.localize("msg_can_not_delete_attachment_offline")){}
                        }
                    }
                } onItemsClicked: { fileName in
                    if let ssMedia = FPFormDataHolder.shared.getFiledFilesArray()[fieldIndxPath]?.first(where: {$0.name == fileName}), FPUtility.isConnectedToNetwork() ||  ssMedia.id == nil {
                        self.handleFileMedia(ssMedia)
                    } else {
                        _  = FPUtility.showAlertController(title: FPLocalizationHelper.localize("alert_dialog_title"), message: FPLocalizationHelper.localize("msg_can_not_view_attachment_offline")){}
                    }
                } triggerCollectionReload: {
                    self.reloadCollectionAt(index: fieldIndxPath)

                } onTriggerMixpanelEvent: { event in
                    self.delegate?.mixpanelEvent(eventName: event, properties: nil)
                }
        }
        .margins(.all, 0)
        return cell ?? UITableViewCell()
    }
    
    
    fileprivate func getSignatureCellFor(tableView: UITableView, _ sectionItem: FPFieldDetails, _ indexPath: IndexPath)->UITableViewCell{
        let signatureIndexPath = IndexPath(row: indexPath.row, section: self.section)
        let cell = tableView.dequeueReusableCell(withIdentifier: "FPSignatureFieldCell")
        cell?.backgroundColor = .clear
        cell?.selectionStyle = .none
        cell?.contentConfiguration = UIHostingConfiguration {
            FPSignatureFieldCell(
                fieldItem: sectionItem,
                fieldIndexPth: signatureIndexPath,
                isViewOnly: self.isAnalysed) {
                    self.attachmentIndex = signatureIndexPath
                    let signatureViewController =  FPSignatureViewController(nibName: "FPSignatureViewController", bundle: ZenFormsBundle.bundle)
                    signatureViewController.del = self
                    self.navigationController?.pushViewController(signatureViewController, animated: true)
                } onSignatureRemove: {
                    FPFormDataHolder.shared.removeMediaAt(indexPath: signatureIndexPath, index: 0)
                    FPFormDataHolder.shared.updateRowWith(value: "", inSection: self.section, atIndex: indexPath.row)
                    self.reloadCollectionAt(index: indexPath)
                }
        }
        .margins(.all, 0)
        
        if isInitialReload {
            isInitialReload.toggle()
            self.formTableView.reloadData()
        }
        return cell ?? UITableViewCell()
    }
    
    
    @objc func btnViewChartClicked(_ sender: UIButton){
        let position = sender.convert(CGPoint.zero, to: self.formTableView)
        if let indexPth = self.formTableView.indexPathForRow(at: position), let sectionItem = FPFormDataHolder.shared.getRowForSection(self.section, at: indexPth.row) {
            let chartVc =  FPChartViewController(nibName: "FPChartViewController", bundle: ZenFormsBundle.bundle)
            chartVc.fieldItem = sectionItem
            chartVc.delegate = self
            chartVc.sectionIndex = self.section
            chartVc.fieldIndex = indexPth.row
            chartVc.isAnalysed = self.isAnalysed
            chartVc.isFromHistory = self.isFromHistory
            self.navigationController?.pushViewController(chartVc, animated: true)
        }
    }
    
    func btnViewChartClickedAt(indexPth:IndexPath){
        if let sectionItem = FPFormDataHolder.shared.getRowForSection(self.section, at: indexPth.row) {
            let chartVc =  FPChartViewController(nibName: "FPChartViewController", bundle: ZenFormsBundle.bundle)
            chartVc.fieldItem = sectionItem
            chartVc.delegate = self
            chartVc.sectionIndex = self.section
            chartVc.fieldIndex = indexPth.row
            chartVc.isAnalysed = self.isAnalysed
            chartVc.isFromHistory = self.isFromHistory
            self.navigationController?.pushViewController(chartVc, animated: true)
        }
    }
    
    func getRadioOptions(section:Int,row:Int, item: FPFieldDetails) -> [FPFieldOption] {
        var arrOptions = [FPFieldOption]()
        arrOptions = item.getRadioOptions(inSection: section, row: row, uiType: item.getUIType())
        if isNew, let defaultVal = item.defaultValue, !defaultVal.trim.isEmpty, let val = item.value, val.trim.isEmpty{
            var arrNewOptions = [FPFieldOption]()
            for option in arrOptions{
                var keyValue = option.key ?? ""
                if (keyValue.isEmpty){
                    keyValue = option.label ?? ""
                }
                var newOption = FPFieldOption(key: keyValue, label: option.label, value: option.value, isSelected: option.isSelected)
                newOption.isSelected = defaultVal == option.value
                arrNewOptions.append(newOption)
            }
            arrOptions = []
            arrOptions.append(contentsOf: arrNewOptions)
            
        }
        return arrOptions
    }
}

//MARK: Attachments Helper

extension FPFormViewController  {
    func addAttachmentTouched(sender:UIView) {
        let actionOptions = UIAlertController(title:FPLocalizationHelper.localize("lbl_attachment"), message: nil, preferredStyle: .actionSheet)
        let libraryAction = UIAlertAction(title: FPLocalizationHelper.localize("lbl_Library"), style: .default) { action in
            self.checkPermissionAndShowPhotoLibrary()
        }
        libraryAction.setValue(FPUtility.make("photo.stack"), forKey: "image")

        let cameraAction = UIAlertAction(title:  FPLocalizationHelper.localize("lbl_Camera"), style: .default) { action in
            if !UIImagePickerController.isSourceTypeAvailable(.camera) {
                FPUtility.showErrorMessage(nil, withTitle: "", withWarningMessage: FPLocalizationHelper.localize("No_Camera"))
            } else {
                self.checkPermissionAndShowCamera()
            }
        }
        cameraAction.setValue(FPUtility.make("camera"), forKey: "image")

        let documentAction = UIAlertAction(title: FPLocalizationHelper.localize("lbl_Document"), style: .default) { action in
            self.showDocumentPicker()
        }
        documentAction.setValue(FPUtility.make("document.badge.plus"), forKey: "image")

        let sketchAction = UIAlertAction(title: FPLocalizationHelper.localize("lbl_Sketch"), style: .default) { action in
            let viewController =  FPDrawViewController(nibName: "FPDrawViewController", bundle: ZenFormsBundle.bundle)
            viewController.delegate = self
            self.navigationController?.pushViewController(viewController, animated: true)
        }
        sketchAction.setValue(FPUtility.make("lasso"), forKey: "image")

        let cancelAction = UIAlertAction(title: FPLocalizationHelper.localize("Cancel"), style: .cancel, handler: nil)
        
        actionOptions.addAction(libraryAction)
        actionOptions.addAction(cameraAction)
        if !isImageOnly{
            actionOptions.addAction(documentAction)
        }
        actionOptions.addAction(sketchAction)
        actionOptions.addAction(cancelAction)
        actionOptions.applyLegacyActionSheetStyle()
        actionOptions.popoverPresentationController?.sourceView = sender
        self.navigationController?.present(actionOptions, animated: true, completion: nil)
    }
    
    func checkPermissionAndShowCamera() {
        let status:AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .authorized {
            OperationQueue.main.addOperation {
                self.showImagePickerForSourceType(sourceType: .camera)
            }
        } else if status == .denied {
            OperationQueue.main.addOperation {
                let alert = FPUtility.createAlertController(title: FPLocalizationHelper.localize("lbl_Permission_Denied"), andMessage: FPLocalizationHelper.localize("msg_cameraPermissionDenied"), withPositiveAction:FPLocalizationHelper.localize("lbl_Go_to_Settings"), andHandler:{ _ in
                    guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                        return
                    }
                    if UIApplication.shared.canOpenURL(settingsUrl) {
                        UIApplication.shared.open(settingsUrl, completionHandler: { (success) in  })
                    }
                }, withNegativeAction:FPLocalizationHelper.localize("Cancel"), andHandler:nil)
                FPUtility.topViewController()?.present(alert, animated: true)
            }
            
        } else if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    OperationQueue.main.addOperation {
                        self.showImagePickerForSourceType(sourceType: .camera)
                    }
                }
            }
        }
    }
    
    func checkPermissionAndShowPhotoLibrary() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized {
            DispatchQueue.main.async {
                self.showPHImagePickerController()
            }
        } else if status == .limited {
            DispatchQueue.main.async {
                self.enbaleFullAccessPermission()
            }
        } else if status == .denied {
            OperationQueue.main.addOperation {
                let alert = FPUtility.createAlertController(title: FPLocalizationHelper.localize("lbl_Permission_Denied"), andMessage: FPLocalizationHelper.localize("msg_galleryPermissionDenied"), withPositiveAction:FPLocalizationHelper.localize("lbl_Go_to_Settings"), andHandler:{ _ in
                    guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                        return
                    }
                    if UIApplication.shared.canOpenURL(settingsUrl) {
                        UIApplication.shared.open(settingsUrl, completionHandler: { (success) in  })
                    }
                    
                }, withNegativeAction:FPLocalizationHelper.localize("Cancel"), andHandler:nil)
                FPUtility.topViewController()?.present(alert, animated: true)
            }
            
        } else if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                if status == .authorized {
                    OperationQueue.main.addOperation {
                        self.showPHImagePickerController()
                    }
                }else if status == .limited {
                    DispatchQueue.main.async {
                        self.enbaleFullAccessPermission()
                    }
                }
            }
            
        }
    }
    
    func enbaleFullAccessPermission() {
        let alert = FPUtility.createAlertController(title: FPLocalizationHelper.localize("lbl_Permission_limited"), andMessage: FPLocalizationHelper.localize("msg_fullGalleryPermissionDenied"), withPositiveAction:FPLocalizationHelper.localize("lbl_Go_to_Settings"), andHandler:{ _ in
            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                return
            }
            if UIApplication.shared.canOpenURL(settingsUrl) {
                UIApplication.shared.open(settingsUrl, completionHandler: { (success) in  })
            }
        }, withNegativeAction:FPLocalizationHelper.localize("Cancel"), andHandler:nil)
        FPUtility.topViewController()?.present(alert, animated: true)
    }
    
    func showImagePickerForSourceType(sourceType:UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.allowsEditing = false
        picker.sourceType = sourceType
        picker.mediaTypes = ["public.image", "public.movie"]
        if isImageOnly{
            picker.mediaTypes = ["public.image"]
        }
        if sourceType == .camera {
            picker.showsCameraControls = true
        }
        self.present(picker, animated:true, completion:nil)
    }
    
    
    func showDocumentPicker() {
        DispatchQueue.main.async {
            let documentPicker = UIDocumentPickerViewController(documentTypes:FPUtility.getSupportedDocumentTypesForFileUpload(), in:.import)
            documentPicker.delegate = self
            documentPicker.modalPresentationStyle = .formSheet
            documentPicker.allowsMultipleSelection = true
            self.present(documentPicker, animated:true, completion:nil)
        }
        
    }
}

extension FPFormViewController: RadioButtonDelegate {
    func didSelectRadioButton(for sectionIndex: Int, fieldIndex: Int, value: String) {
        FPFormDataHolder.shared.updateRowWith(value: value, inSection: sectionIndex, atIndex: fieldIndex)
        hasDataChanges = true
    }
}

extension FPFormViewController: FPDynamicDataTypeCellDelegate {
    func selectedValue(for sectionIndex: Int, fieldIndex: Int, pickerIndex: Int?, value: String?, date: Date?, isSectionDuplicationField: Bool) {
        if isSectionDuplicationField, let nameValue = value, !nameValue.isEmpty{
            _  = FPUtility.showAlertController(title: FPLocalizationHelper.localize("alert_dialog_title"), andMessage: FPLocalizationHelper.localize("msg_SectionCreateConfirmation"), completion:nil, withPositiveAction: FPLocalizationHelper.localize("lbl_Proceed"), style: .default, andHandler: { action in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.proceedToDynamicSection(at: sectionIndex, section: nameValue)
                }
            }, withNegativeAction: FPLocalizationHelper.localize("Cancel"), style: .cancel, andHandler: nil, parentVC: self)
        }else{
            if let selectedDate = date {
                FPFormDataHolder.shared.updateRowWith(date: selectedDate, inSection: sectionIndex, atIndex: fieldIndex)
                hasDataChanges = true
            }else{
                FPFormDataHolder.shared.updateRowWith(value: value ?? "", inSection: sectionIndex, atIndex: fieldIndex)
                hasDataChanges = true
                if let sectionItem = FPFormDataHolder.shared.getRowForSection(sectionIndex, at: fieldIndex){
                    if  (sectionItem.getUIType() == .CHART) || (sectionItem.getUIType() == .DROPDOWN){
                        let fieldIP = IndexPath(row: fieldIndex, section: 0)
                        self.reloadCollectionAt(index: fieldIP)
                    }
                }
            }
        }
    }
}

extension FPFormViewController: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return FPFormDataHolder.shared.getSectionCount()
    }
}

extension FPFormViewController: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        let sections = FPFormDataHolder.shared.getFormSections()
        return FPUtility.getSQLiteCompatibleStringValue(sections[safe:row]?.displayName ?? "", isForLocal: false)
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        self.section = row
    }
    
    func pickedValue(index: Int) {
        let sections = FPFormDataHolder.shared.getFormSections()
        let value = FPUtility.getSQLiteCompatibleStringValue(sections[safe:index]?.displayName ?? "", isForLocal: false)
        self.txtFieldSection.text = value
        if value == FPLocalizationHelper.localize("SELECT") {
            self.txtFieldSection.text = ""
        }
        self.formTableView.reloadData()
    }
    
    func refreshSection(isSectionNameRefresh: Bool = false) {
        let sections = FPFormDataHolder.shared.getFormSections()
        let value = FPUtility.getSQLiteCompatibleStringValue(sections[safe:self.section]?.displayName ?? "", isForLocal: false)
        self.txtFieldSection.text = value
        self.lblCurrentSectionName.text = value
        if value == FPLocalizationHelper.localize("SELECT"){
            self.txtFieldSection.text = ""
        }
        if isSectionNameRefresh == false{
            self.formTableView.reloadData()
        }
    }
}

extension FPFormViewController:FPCollectionCellDelegate{
    func attachFileAtTable(coloumnIndex: Int, tableIndexPath: IndexPath, collectionIndexPath: IndexPath, value:String,key:String) {
        if !self.isAnalysed{
            self.tableAttachementcoloumnKey = key
            self.tableAttachementcoloumnIndex = coloumnIndex;
            self.tableAttachementChildIndexPath = tableIndexPath
            self.tableAttachementParentIndexPath =  collectionIndexPath
            let attachmentView =  TableAttachementView.instance
            attachmentView.parentViewController = self
            attachmentView.delegate = self
            attachmentView.attachmentValue = value
            attachmentView.showAttachmentPicker()
        }
    }
    
    func reloadCollectionAt(index: IndexPath) {
        debugPrint("reloadCollectionAt -\(index.row)")
        self.safeReloadRows([IndexPath(row: index.row, section: 0)])
    }
    
    func reloadCollection() {
        self.formTableView.reloadData()
    }
}

extension FPFormViewController: FPSignatureDelegate {
    func getSignatureImage(_ image: UIImage?) {
        if let index = attachmentIndex{
            do {
                let documentDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor:nil, create:false)
                let fileURL = documentDirectory.appendingPathComponent(FPUtility.generateImageFileName())
                let imageData = image!.pngData()
                fileManager.createFile(atPath: fileURL.path, contents: imageData, attributes: nil)
                let templateId = FPFormDataHolder.shared.getFieldTemplateId(inSection:index.section, atIndex: index.row)
                let media  = SSMedia(name: fileURL.lastPathComponent, mimeType: fileURL.fileMimeType(), filePath: fileURL.path, templateId: templateId, moduleType: .forms)
                FPFormDataHolder.shared.clearFileAt(index: index)
                FPFormDataHolder.shared.addFileAt(index:index, withMedia: media)
                FPFormDataHolder.shared.updateRowWith(value: fileURL.path, inSection: self.section, atIndex: index.row)
                hasDataChanges = true
            } catch {
                print(error.localizedDescription)
            }
            DispatchQueue.main.async {
                self.reloadCollectionAt(index: index)
                self.attachmentIndex = nil
            }
        }
    }
}

extension FPFormViewController:PFFileInputDelegate{
    func didAttachTap(at: IndexPath, sender: UIButton, isImageOnly: Bool) {
        if !self.isAnalysed{
            attachmentIndex = at
            self.isImageOnly = isImageOnly
            addAttachmentTouched(sender: sender)
        }
    }
}

// MARK: - UIImagePickerControllerDelegate

extension FPFormViewController: UIImagePickerControllerDelegate{
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        attachmentIndex = nil
        picker.dismiss(animated: true, completion:nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        weak var weakSelf:FPFormViewController? = self
        picker.dismiss(animated: true) {
            if let index = weakSelf?.attachmentIndex{
                weakSelf?.attachmentIndex = nil
                let mediaType = info[UIImagePickerController.InfoKey.mediaType] as? String
                if (mediaType == "public.movie") {
                    guard let mediaURL = info[UIImagePickerController.InfoKey.mediaURL] as? URL else {
                        return
                    }
                    if picker.sourceType == .camera {
                        UISaveVideoAtPathToSavedPhotosAlbum(mediaURL.path, nil, nil, nil)
                    }
                    do{
                        let mediadata = try? Data(contentsOf: mediaURL)
                        let documentDirectory = try weakSelf?.fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor:nil, create:true)
                        if let fileURL = documentDirectory?.appendingPathComponent(FPUtility.generateVideoFileName()){
                            try? mediadata?.write(to: fileURL)
                            let templateId = FPFormDataHolder.shared.getFieldTemplateId(inSection: index.section , atIndex:index.row )
                            let media  = SSMedia(name: fileURL.lastPathComponent, mimeType: fileURL.fileMimeType(), filePath: fileURL.path, templateId: templateId, moduleType: .forms)
                            FPFormDataHolder.shared.addFileAt(index:index, withMedia: media)
                            weakSelf?.hasDataChanges = true
                        }
                    }catch let error{
                        print(error)
                    }
                    
                }else{
                    var chosenImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage
                    if (chosenImage == nil) {
                        chosenImage = info[UIImagePickerController.InfoKey.editedImage] as? UIImage
                    }
                    if picker.sourceType == .camera {
                        UIImageWriteToSavedPhotosAlbum(chosenImage!, nil, nil,nil)
                    }
                    if (chosenImage != nil) {
                        // Preserve EXIF metadata for camera captures
                        let metadata = picker.sourceType == .camera ? info[.mediaMetadata] as? [String: Any] : nil
                        guard let imageData = FPImageEXIFHelper.jpegData(from: chosenImage!, metadata: metadata, compressionQuality: 1.0) else { return }
                        do {
                            let documentDirectory = try weakSelf?.fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor:nil, create:true)
                            if let fileURL = documentDirectory?.appendingPathComponent(FPUtility.generateJPEGImageFileName()){
                                try? imageData.write(to: fileURL)
                                let templateId = FPFormDataHolder.shared.getFieldTemplateId(inSection: index.section , atIndex:index.row )
                                let media  = SSMedia(name: fileURL.lastPathComponent, mimeType: fileURL.fileMimeType(), filePath: fileURL.path, templateId: templateId, moduleType: .forms)
                                FPFormDataHolder.shared.addFileAt(index:index, withMedia: media)
                                weakSelf?.hasDataChanges = true
                            }
                        } catch {
                            print(error.localizedDescription)
                        }
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    weakSelf?.reloadCollectionAt(index: index)
                }
            }
        }
    }
}


// MARK: - PHPickerViewController

extension FPFormViewController: PHPickerViewControllerDelegate{
    func showPHImagePickerController() {
        var configuration = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        configuration.selectionLimit = 10
        configuration.filter = .any(of: [.images, .videos])
        if isImageOnly{
            configuration.filter = .images
        }
        let pickerViewController = PHPickerViewController(configuration: configuration)
        pickerViewController.modalPresentationStyle = .fullScreen
        pickerViewController.delegate = self
        self.present(pickerViewController, animated: true)
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        weak var weakSelf:FPFormViewController? = self
        picker.dismiss(animated: true) {
            guard !results.isEmpty else {
                self.attachmentIndex = nil
                return
            }
            guard let index = weakSelf?.attachmentIndex else {
                return
            }
            weakSelf?.attachmentIndex = nil
            _ = FPUtility.showHUDWithMessage(FPLocalizationHelper.localize("lbl_Adding_PhotosVideos"), detailText: "")
            let group = DispatchGroup()
            for result in results {
                group.enter()
                if result.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier){
                    result.itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.movie.identifier) { fileData, error in
                        if let fileData = fileData{
                            do {
                                let documentDirectory = try weakSelf?.fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor:nil, create:true)
                                if let fileURL = documentDirectory?.appendingPathComponent(FPUtility.generateVideoFileName()){
                                    try? fileData.write(to: fileURL)
                                    let templateId = FPFormDataHolder.shared.getFieldTemplateId(inSection: index.section , atIndex:index.row )
                                    let media  = SSMedia(name: fileURL.lastPathComponent, mimeType: fileURL.fileMimeType(), filePath: fileURL.path, templateId: templateId, moduleType: .forms)
                                    FPFormDataHolder.shared.addFileAt(index:index, withMedia: media)
                                    weakSelf?.hasDataChanges = true
                                }
                            } catch let error{
                                print(error)
                            }
                        }
                        group.leave()
                    }
                }else{
                    result.itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { phImgData, error in
                        if let imageData = phImgData{
                            do {
                                let documentDirectory = try weakSelf?.fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor:nil, create:true)
                                if let fileURL = documentDirectory?.appendingPathComponent(FPUtility.generateJPEGImageFileName()){
                                    try? imageData.write(to: fileURL)
                                    let templateId = FPFormDataHolder.shared.getFieldTemplateId(inSection: index.section , atIndex:index.row )
                                    let media  = SSMedia(name: fileURL.lastPathComponent, mimeType: fileURL.fileMimeType(), filePath: fileURL.path, templateId: templateId, moduleType: .forms)
                                    FPFormDataHolder.shared.addFileAt(index:index, withMedia: media)
                                    weakSelf?.hasDataChanges = true
                                }
                            } catch let error{
                                print(error)
                            }
                        }
                        group.leave()
                    }
                }
            }
            group.notify(queue: DispatchQueue.main) {
                DispatchQueue.main.async {
                    FPUtility.hideHUD()
                    weakSelf?.reloadCollectionAt(index: index)
                }
            }
        }
    }
}

extension  FPFormViewController: UIDocumentPickerDelegate{
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if let index = attachmentIndex, controller.documentPickerMode == .import {
            attachmentIndex = nil
            weak var weakSelf:FPFormViewController? = self
            _ = FPUtility.showHUDWithMessage(FPLocalizationHelper.localize("lbl_AddingDocuments"), detailText:"")
            var arrNames = [String]()
            for url in urls {
                let fileFullName = url.lastPathComponent.removingPercentEncoding?.replacingOccurrences(of: " ", with: "_") ?? ""
                let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
                let documentsPath = paths.first ?? ""
                let filePath = (documentsPath as NSString).appendingPathComponent(FPUtility.generateDocFileName(originalName: fileFullName))
                let tempUrl = URL(fileURLWithPath: filePath)
                let UTI = FPUTI(withExtension: tempUrl.pathExtension).rawValue
                let fileExtension = FPMedia.getExtensionWith(fileName: filePath.components(separatedBy: "/").last ?? "")
                if fileExtension != "csv", !FPUtility.getSupportedDocumentTypesForFileUpload().contains(UTI) {
                    arrNames.append(filePath.components(separatedBy: "/").last ?? "")
                    continue
                }
                if fileManager.fileExists(atPath: tempUrl.path){
                    do {
                        try fileManager.removeItem(atPath: tempUrl.path)
                    }catch let error{
                        print(error)
                    }
                }
                
                do {
                    try fileManager.moveItem(at: url, to: tempUrl)
                } catch let error{
                    print(error)
                }
                let templateId = FPFormDataHolder.shared.getFieldTemplateId(inSection: index.section, atIndex: index.row)
                let media  = SSMedia(name: tempUrl.lastPathComponent, mimeType: tempUrl.fileMimeType(), filePath: tempUrl.path, templateId: templateId, moduleType: .forms)
                FPFormDataHolder.shared.addFileAt(index:index, withMedia: media)
                hasDataChanges = true
            }
            
            FPUtility.hideHUD()
            if arrNames.count > 0 {
                let filesMsg = FPLocalizationHelper.localizeWith(args: [arrNames.joined(separator: ", ")], key: "msg_detectedExecutablesfiles")
                _  = FPUtility.showAlertController(title: FPLocalizationHelper.localize("msg_executablesfilesNotSupported"), message:filesMsg, completion:nil)
            }
            DispatchQueue.main.async {
                weakSelf?.formTableView.reloadData()
            }
        }
    }
    
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        attachmentIndex = nil
    }
    
}

extension FPFormViewController:  UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
    

}

extension FPFormViewController:  FPDrawHelper{
    func imageSelected(_ image: UIImage) {
        if let index = attachmentIndex{
            do {
                let documentDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor:nil, create:true)
                let fileURL = documentDirectory.appendingPathComponent(FPUtility.generateImageFileName())
                if let data = image.pngData() {
                    try? data.write(to: fileURL)
                }
                let templateId = FPFormDataHolder.shared.getFieldTemplateId(inSection: index.section , atIndex:index.row)
                let media  = SSMedia(name: fileURL.lastPathComponent, mimeType: fileURL.fileMimeType(), filePath: fileURL.path, templateId: templateId, moduleType: .forms)
                FPFormDataHolder.shared.addFileAt(index:index, withMedia: media)
                DispatchQueue.main.async {
                    self.reloadCollectionAt(index: index)
                    self.attachmentIndex = nil
                }
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}

extension FPFormViewController: AttachmentPickerDelegate{
    
    func onMediaSave(mediaAdded: [SSMedia], mediaDeleted: [SSMedia]) {
        let tableMedia = TableMedia(columnIndex: tableAttachementcoloumnIndex, key: tableAttachementcoloumnKey!, parentTableIndex: tableAttachementParentIndexPath, childTableIndex: tableAttachementChildIndexPath, mediaAdded: mediaAdded.filter({$0.id?.isEmpty ?? true}), mediaDeleted: mediaDeleted, formSessionId: FPFormDataHolder.shared.currentFormSessionId)
        FPFormDataHolder.shared.updateTableFieldValue(media: tableMedia)
        hasDataChanges = true
        self.formTableView.reloadData()
        
    }
}

//MARK: Asset  Linking

extension FPUtility{
    
    func feedAssetLinkingIfAny(form:FPForms?){
        let sections = form?.sections as? [FPSectionDetails] ?? []
        for section in sections {
            for field in section.fields {
                if field.getUIType() == .TABLE, let arrValue = field.value?.getArray(), !arrValue.isEmpty{
                    for dictValue in arrValue {
                        dictValue.forEach { dkey, dvalue in
                            if dkey == hiddenAssetIdColumnKey, let strValue = dvalue as? String, !strValue.isEmpty, let assetId = Int(strValue) {
                                let data = AssetFormMappingData()
                                data.assetId = NSNumber(value:assetId)
                                data.isAssetSynced = true
                                data.customFormId = FPUtility.getNumberValue(form?.objectId)
                                data.customFormLocalId = form?.sqliteId
                                data.fieldTemplateId =  field.templateId ?? "0"
                                data.tableRowLocalId  = dictValue["__localId__"] as? String
                                data.tableRowId  = dictValue["__id__"] as? String
                                data.isSyncedToServer = true
                                data.addLinking = true
                                data.deleteLinking = false
                                data.sectionTemplateId = section.templateId ?? "0"
                                data.formTemplateId = form?.templateId
                                data.isNotConfirmed = false
                                AssetFormLinkingDatabaseManager().upsert(item: data) { success in }
                            }
                        }
                    }
                }
            }
        }
    }
    
    static func findAssetSectionLinkingsFor(form:FPForms, linkingDelegate:ZenFormsAssetLinkingDelegate? = nil, synclinkingDelegate:ZenFormsSyncAssetLinkingDelegate? = nil,  completion: @escaping(()->Void)){
        var arrLinkings = [AssetFormMappingData]()
        if FPUtility.isConnectedToNetwork(), form.objectId == nil, form.sqliteId == nil{
            for linking in FPFormDataHolder.shared.arrLinkingDB{
                if linking.sectionLinking == true, linking.formTemplateId == form.templateId, linking.isAssetSynced == false {
                    arrLinkings.append(linking)
                }
            }
        }else{
            arrLinkings =  AssetFormLinkingDatabaseManager().fetchAssetSectionLinkigDataFor(customForm: form)
        }
        let group = DispatchGroup()
        group.enter()
        if arrLinkings.count > 0 {
            FPUtility().uploadAssetSectionRecurively(linkingDelegate:linkingDelegate, synclinkingDelegate: synclinkingDelegate, customform: form, arrLinkings: arrLinkings, currentindex: 0) {
                group.leave()
            }
        }else{
            group.leave()
        }
        group.notify(queue: DispatchQueue.main) {
            completion()
        }
    }

    
    
    static func findAssetLinkingsFor(form:FPForms, linkingDelegate:ZenFormsAssetLinkingDelegate? = nil, synclinkingDelegate:ZenFormsSyncAssetLinkingDelegate? = nil,  completion: @escaping (_ response: [String: Any]?) -> Void){
        guard isAssetENABLED else {
            completion([:])
            return
        }
        let arrAddDict = [[String:Any]]()
        var arrDeletedDict = [[String:Any]]()
        var assetLinkJson = [String:Any]()
        var arrLinkings = [AssetFormMappingData]()
        if FPUtility.isConnectedToNetwork(), form.objectId == nil, form.sqliteId == nil{
            for linking in FPFormDataHolder.shared.arrLinkingDB{
                if linking.addLinking == true, linking.formTemplateId == form.templateId, linking.isAssetSynced == false {
                    arrLinkings.append(linking)
                }
            }
        }else{
            arrLinkings =  AssetFormLinkingDatabaseManager().fetchAssetLinkigDataFor(customForm: form)
        }
        let deleteLinkings = arrLinkings.filter({ $0.deleteLinking == true})
        if deleteLinkings.count > 0 {
            arrDeletedDict = []
            for deletd in deleteLinkings {
                if deletd.isSyncedToServer == false{
                    var dict = [String:Any]()
                    dict["assetId"] = deletd.assetId
                    dict["fieldTemplateId"] = deletd.fieldTemplateId
                    arrDeletedDict.append(dict)
                }
            }
        }
        if !arrDeletedDict.isEmpty{
            assetLinkJson["remove"] = arrDeletedDict
        }
        let addLinkings = arrLinkings.filter({ $0.addLinking == true})
        let group = DispatchGroup()
        group.enter()
        if addLinkings.count > 0 {
            FPUtility().uploadAssetRecurively(linkingDelegate:linkingDelegate, synclinkingDelegate: synclinkingDelegate, customform: form, arrLinkings: addLinkings, arrAddDict: arrAddDict, currentindex: 0) { result in
                if !result.isEmpty{
                    assetLinkJson["add"] = result
                }
                group.leave()
            }
        }else{
            if FPUtility.isConnectedToNetwork(), form.objectId == nil, form.sqliteId == nil{
                var arrAddLocalDict = [[String:Any]]()
                for linking in FPFormDataHolder.shared.arrLinkingDB{
                    if linking.addLinking == true, linking.formTemplateId == form.templateId {
                        var dict = [String:Any]()
                        dict["assetId"] = linking.assetId
                        dict["fieldTemplateId"] = linking.fieldTemplateId
                        arrAddLocalDict.append(dict)
                    }
                }
                if !arrAddLocalDict.isEmpty{
                    assetLinkJson["add"] = arrAddLocalDict
                }
            }
            group.leave()
        }
        group.notify(queue: DispatchQueue.main) {
            self.findAssetSectionLinkingsFor(form: form, linkingDelegate: linkingDelegate, synclinkingDelegate: synclinkingDelegate) {
                completion(assetLinkJson)
            }
        }
    }
    
    
    func updateAssetIdForRow(customform: FPForms, linkingData:AssetFormMappingData){
        if let sectionFieldIndex = customform.sections?.firstIndex(where: { $0.templateId == linkingData.sectionTemplateId}), let assetSection = customform.sections?[safe:sectionFieldIndex]{
            if let assetFieldIndex = assetSection.fields.firstIndex(where: { $0.templateId == linkingData.fieldTemplateId}), let assetField = assetSection.fields[safe:assetFieldIndex], assetField.getUIType() == .TABLE{
                let arrValue =  assetField.value?.getArray().map { dict in
                    var newDict = dict
                    if dict["__localId__"] as? String == linkingData.tableRowLocalId{
                        for i in newDict.values.indices {
                            if let dkey = newDict.keys[i] as? String, dkey == hiddenAssetIdColumnKey{
                                newDict.values[i] = linkingData.assetId?.stringValue ?? ""
                            }
                        }
                    }
                    return newDict
                }
                let strValue = arrValue?.getJson()
                if  let _ = customform.sections?[safe:sectionFieldIndex]{
                    customform.sections?[sectionFieldIndex].fields[assetFieldIndex].value = strValue
                }
            }
        }
    }
    
    func uploadAssetRecurively(linkingDelegate:ZenFormsAssetLinkingDelegate?, synclinkingDelegate:ZenFormsSyncAssetLinkingDelegate?, customform: FPForms, arrLinkings:[AssetFormMappingData], arrAddDict:[[String:Any]], currentindex:Int, completion:@escaping(_ added:[[String:Any]])->Void){
        var arrAddDict = arrAddDict
        var currentindex = currentindex
        let group = DispatchGroup()
        if(arrLinkings.count > currentindex){
            let linking = arrLinkings[currentindex]
            if linking.isSyncedToServer == false{
                if linking.isAssetSynced == false{
                    group.enter()
                    if let _ = linkingDelegate{
                        linkingDelegate?.uploadAssetAndLink(assetLocalId: linking.assetLocalId ?? 0, completion: { assetObjectId in
                            if let assetObjectId = assetObjectId{
                                let updatedLinkData = linking
                                updatedLinkData.assetId = assetObjectId
                                updatedLinkData.isAssetSynced = true
                                updatedLinkData.isNotConfirmed = false
                                AssetFormLinkingDatabaseManager().upsert(item: updatedLinkData){ success in
                                    var dict = [String:Any]()
                                    dict["assetId"] = assetObjectId
                                    dict["fieldTemplateId"] = linking.fieldTemplateId
                                    arrAddDict.append(dict)
                                    currentindex = currentindex + 1
                                    self.updateAssetIdForRow(customform: customform, linkingData: updatedLinkData)
                                    group.leave()
                                    self.uploadAssetRecurively(linkingDelegate: linkingDelegate, synclinkingDelegate: synclinkingDelegate, customform: customform, arrLinkings: arrLinkings, arrAddDict: arrAddDict, currentindex: currentindex, completion: completion)
                                }
                            }else{
                                group.leave()
                                currentindex = currentindex + 1
                                self.uploadAssetRecurively(linkingDelegate: linkingDelegate, synclinkingDelegate: synclinkingDelegate, customform: customform, arrLinkings: arrLinkings, arrAddDict: arrAddDict, currentindex: currentindex, completion: completion)
                            }
                        })
                    }else  if let _ = synclinkingDelegate{
                        synclinkingDelegate?.uploadAssetAndLink(assetLocalId: linking.assetLocalId ?? 0, completion: { assetObjectId in
                            if let assetObjectId = assetObjectId{
                                let updatedLinkData = linking
                                updatedLinkData.assetId = assetObjectId
                                updatedLinkData.isAssetSynced = true
                                updatedLinkData.isNotConfirmed = false
                                AssetFormLinkingDatabaseManager().upsert(item: updatedLinkData){ success in
                                    var dict = [String:Any]()
                                    dict["assetId"] = assetObjectId
                                    dict["fieldTemplateId"] = linking.fieldTemplateId
                                    arrAddDict.append(dict)
                                    currentindex = currentindex + 1
                                    self.updateAssetIdForRow(customform: customform, linkingData: updatedLinkData)
                                    group.leave()
                                    self.uploadAssetRecurively(linkingDelegate: linkingDelegate, synclinkingDelegate: synclinkingDelegate, customform: customform, arrLinkings: arrLinkings, arrAddDict: arrAddDict, currentindex: currentindex, completion: completion)
                                }
                            }else{
                                group.leave()
                                currentindex = currentindex + 1
                                self.uploadAssetRecurively(linkingDelegate: linkingDelegate, synclinkingDelegate: synclinkingDelegate, customform: customform, arrLinkings: arrLinkings, arrAddDict: arrAddDict, currentindex: currentindex, completion: completion)
                            }
                        })
                    }else{
                        currentindex = currentindex + 1
                        self.uploadAssetRecurively(linkingDelegate: linkingDelegate, synclinkingDelegate: synclinkingDelegate, customform: customform, arrLinkings: arrLinkings, arrAddDict: arrAddDict, currentindex: currentindex, completion: completion)

                    }
                    
                }else{
                    var dict = [String:Any]()
                    dict["assetId"] = linking.assetId
                    dict["fieldTemplateId"] = linking.fieldTemplateId
                    arrAddDict.append(dict)
                    currentindex = currentindex + 1
                    self.uploadAssetRecurively(linkingDelegate: linkingDelegate, synclinkingDelegate: synclinkingDelegate, customform: customform, arrLinkings: arrLinkings, arrAddDict: arrAddDict, currentindex: currentindex, completion: completion)
                }
            }else{
                currentindex = currentindex + 1
                self.uploadAssetRecurively(linkingDelegate: linkingDelegate, synclinkingDelegate: synclinkingDelegate, customform: customform, arrLinkings: arrLinkings, arrAddDict: arrAddDict, currentindex: currentindex, completion: completion)
            }
        }else{
            completion(arrAddDict)
        }
    }
    
    func appendAssetIdFieldToSection(linkingData:AssetFormMappingData){
        var sectionTemplateId = ""
        if let secTemplateId = linkingData.sectionTemplateId{
            sectionTemplateId = secTemplateId
        }
        
        //edge case where we adding same type of asset via scanner in same fpform which causes incorrect payload
        if !sectionTemplateId.isEmpty,  let localSectionId = linkingData.sectionLocalId {
            if let secIndex = FPFormDataHolder.shared.customForm?.sections?.firstIndex(where: {$0.templateId == sectionTemplateId && $0.sqliteId == localSectionId}){
                if let sectionToUpdate = FPFormDataHolder.shared.customForm?.sections?[safe:secIndex], let assetId = linkingData.assetId, let sortPosition = sectionToUpdate.fields.last?.sortPosition{
                    let hiddenAssetField = FPFormDataHolder.shared.getHiddenAssetField(assetId: assetId, sortPostion: "\(sortPosition)1")
                    FPFormDataHolder.shared.customForm?.sections?[secIndex].fields.append(hiddenAssetField)
                    return
                }
            }
        }
        if let secIndex = FPFormDataHolder.shared.customForm?.sections?.firstIndex(where: { section in
            return sectionTemplateId.isEmpty ? section.sqliteId == linkingData.sectionLocalId :  (section.sqliteId == linkingData.sectionLocalId || section.templateId == linkingData.sectionTemplateId)
        }){
            if let sectionToUpdate = FPFormDataHolder.shared.customForm?.sections?[safe:secIndex], let assetId = linkingData.assetId, let sortPosition = sectionToUpdate.fields.last?.sortPosition{
                let hiddenAssetField = FPFormDataHolder.shared.getHiddenAssetField(assetId: assetId, sortPostion: "\(sortPosition)1")
                FPFormDataHolder.shared.customForm?.sections?[secIndex].fields.append(hiddenAssetField)
            }
        }
    }
    
    func uploadAssetSectionRecurively(linkingDelegate:ZenFormsAssetLinkingDelegate?, synclinkingDelegate:ZenFormsSyncAssetLinkingDelegate?, customform: FPForms, arrLinkings:[AssetFormMappingData], currentindex:Int, completion:@escaping(()->Void)){
        var currentindex = currentindex
        let group = DispatchGroup()
        if(arrLinkings.count > currentindex){
            let linking = arrLinkings[currentindex]
            if linking.isSyncedToServer == false{
                if linking.isAssetSynced == false{
                    group.enter()
                    if let _ = linkingDelegate{
                        linkingDelegate?.uploadAssetAndLink(assetLocalId: linking.assetLocalId ?? 0, completion: { assetObjectId in
                            if let assetObjectId = assetObjectId{
                                let updatedLinkData = linking
                                updatedLinkData.assetId = assetObjectId
                                updatedLinkData.isAssetSynced = true
                                updatedLinkData.isNotConfirmed = false
                                AssetFormLinkingDatabaseManager().upsertSectionAsset(item: updatedLinkData){ success in
                                    currentindex = currentindex + 1
                                    self.appendAssetIdFieldToSection(linkingData: updatedLinkData)
                                    group.leave()
                                    self.uploadAssetSectionRecurively(linkingDelegate: linkingDelegate, synclinkingDelegate: synclinkingDelegate, customform: customform, arrLinkings: arrLinkings, currentindex: currentindex, completion: completion)
                                }
                            }else{
                                group.leave()
                                currentindex = currentindex + 1
                                self.uploadAssetSectionRecurively(linkingDelegate: linkingDelegate, synclinkingDelegate: synclinkingDelegate, customform: customform, arrLinkings: arrLinkings, currentindex: currentindex, completion: completion)
                            }
                        })
                    }else  if let _ = synclinkingDelegate{
                        synclinkingDelegate?.uploadAssetAndLink(assetLocalId: linking.assetLocalId ?? 0, completion: { assetObjectId in
                            if let assetObjectId = assetObjectId{
                                let updatedLinkData = linking
                                updatedLinkData.assetId = assetObjectId
                                updatedLinkData.isAssetSynced = true
                                updatedLinkData.isNotConfirmed = false
                                AssetFormLinkingDatabaseManager().upsertSectionAsset(item: updatedLinkData){ success in
                                    currentindex = currentindex + 1
                                    self.appendAssetIdFieldToSection(linkingData: updatedLinkData)
                                    group.leave()
                                    self.uploadAssetSectionRecurively(linkingDelegate: linkingDelegate, synclinkingDelegate: synclinkingDelegate, customform: customform, arrLinkings: arrLinkings, currentindex: currentindex, completion: completion)
                                }
                            }else{
                                group.leave()
                                currentindex = currentindex + 1
                                self.uploadAssetSectionRecurively(linkingDelegate: linkingDelegate, synclinkingDelegate: synclinkingDelegate, customform: customform, arrLinkings: arrLinkings, currentindex: currentindex, completion: completion)
                            }
                        })
                    }else{
                        currentindex = currentindex + 1
                        self.uploadAssetSectionRecurively(linkingDelegate: linkingDelegate, synclinkingDelegate: synclinkingDelegate, customform: customform, arrLinkings: arrLinkings, currentindex: currentindex, completion: completion)
                    }
                    
                }else{
                    currentindex = currentindex + 1
                    self.uploadAssetSectionRecurively(linkingDelegate: linkingDelegate, synclinkingDelegate: synclinkingDelegate, customform: customform, arrLinkings: arrLinkings, currentindex: currentindex, completion: completion)
                }
            }else{
                currentindex = currentindex + 1
                self.uploadAssetSectionRecurively(linkingDelegate: linkingDelegate, synclinkingDelegate: synclinkingDelegate, customform: customform, arrLinkings: arrLinkings, currentindex: currentindex, completion: completion)
            }
        }else{
            completion()
        }
    }
}


extension UIButton {
    
    func updateInteraction(isEnabled:Bool) {
        self.isEnabled = isEnabled
        self.alpha = isEnabled ? 1.0 : 0.5
    }
    
}
