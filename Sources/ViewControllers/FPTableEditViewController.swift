//
//  FPTableEditViewController.swift
//  crm
//
//  Created by Apple on 03/08/23.
//  Copyright © 2023 SmartServ. All rights reserved.
//

import UIKit
internal import SSMediaManager
internal import RSSelectionMenu
internal import IQKeyboardManagerSwift
internal import IQKeyboardToolbar
internal import IQKeyboardToolbarManager
internal import ZTExpressionEngine

enum SortColumnOption: Int {
    case ascending
    case descending
    case filter
}

struct SortFilter{
    let uuid = UUID().uuidString
    let indPath: IndexPath
    let option: SortColumnOption
    let filterItems:[String]?
}

let fileterBlankOptionKey = FPLocalizationHelper.localize("lbl_Empty")
let checkBoxCollectionRow = 1

class FPTableEditViewController: UIViewController {
    var rowCount = 1
    var MAX_ADD_ROW_COUNT  = 10
    
    private let headerCellReuseIdentifier = "TableHeaderCollectionViewCell"
    private let contentCellReuseIdentifier = "TableContentCollectionViewCell"
    
    private let cardTransitionDelegate = CardTransitioningDelegate()
    
    @IBOutlet weak var txtRowCount: UITextField!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var viewAddRow: UIView!
    
    @IBOutlet weak var mainBottomStk: UIStackView!
    @IBOutlet weak var stkOptions: UIStackView!
    
    @IBOutlet weak var btnEditRow: UIButton!
    @IBOutlet weak var btnBulkEdit: UIButton!
    @IBOutlet weak var btnAssetLink: UIButton!
    @IBOutlet weak var btnDuplicate: UIButton!
    @IBOutlet weak var btnMultipleDeleteRows: UIButton!
    
    @IBOutlet weak var btnAddMultipleRows: UIButton!
    @IBOutlet weak var btnOpenClose: UIButton!
    @IBOutlet weak var constLeading: NSLayoutConstraint!
    
    var tableIndexPath:IndexPath?
    var tableComponent:TableComponent?
    var sortFilteredTableComponent:TableComponent?
    var titleText: String?
    var attachmentIndex:IndexPath?
    var attachmentColumnData: ColumnData?
    var isAnalysed = false
    var isFromHistory = false
    var isNew: Bool = true
    var isAssetEnabled:Bool = false
    var didCompletedEdit:((_ tableComponent:TableComponent)->())?
    
    var sortFilterColumnIndexPath:IndexPath?
    var sortFilterColumn:Columns?
    var isSortFilterApplied:Bool = false
    var zenFormsDelegate: ZenFormsDelegate?
    private var fp_autoSaveTimer: Timer?
    private var fp_hasFirstChangeSaved = false
    private var fp_sessionInitialSnapshot: String = ""
    private var fp_tableDataGeneration = 0
    private var fp_pendingCollectionReloadWorkItem: DispatchWorkItem?

    private func fp_bumpTableGeneration() {
        fp_tableDataGeneration += 1
    }

    
    var arrAppliedFilters = [SortFilter]()
    var arrSelectedIndexes = [IndexPath]()
    var arrSelectedRows = [Rows]()
    var isSelectedAll = false
    var viewModel: FPSpreadsheetCollectionViewModel? {
        didSet {
            guard let layout = collectionView.collectionViewLayout as? FPSpreadsheetCollectionViewLayout else {
                assertionFailure("Expected a SpreadsheetLayout")
                return
            }
            viewModel?.dataSource = self
            viewModel?.parentIndexPath = tableIndexPath
            collectionView.dataSource = viewModel
            collectionView.delegate = viewModel
            layout.delegate = viewModel
            collectionView!.reloadData()
        }
    }
    
    var accessoryToolbar: UIToolbar {
        get {
            let toolbarFrame = CGRect(x: 0, y: 0, width: SCREEN_SIZE.width, height: 44)
            let accessoryToolbar = UIToolbar(frame: toolbarFrame)
            let doneButton = UIBarButtonItem(title: FPLocalizationHelper.localize("Done"), style:.plain, target: self, action: #selector(onDoneButtonTapped(sender:)))
            let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            accessoryToolbar.items = [flexibleSpace, doneButton]
            accessoryToolbar.barTintColor = UIColor.white
            return accessoryToolbar
        }
    }
    
    var assetLinkIndexPath:IndexPath?
    var fieldDetails:FPFieldDetails?
    var sectionDetails:FPSectionDetails?
    var fpFormViewController:FPFormViewController?
    var linkedAssets:[[String:NSNumber?]]{
        var arrResult = [[String:NSNumber?]]()
        if FPFormDataHolder.shared.customForm?.objectId == nil, FPFormDataHolder.shared.customForm?.sqliteId == nil{
            arrResult = [[String:NSNumber?]]()
            for linking in FPFormDataHolder.shared.arrLinkingDB{
                if linking.addLinking == true, linking.formTemplateId == FPFormDataHolder.shared.customForm?.templateId {
                    var dictAsset = [String:NSNumber?]()
                    dictAsset["assetId"] = linking.assetId
                    dictAsset["assetLocalId"] = linking.assetLocalId
                    arrResult.append(dictAsset)
                }
            }
        }else{
            arrResult = AssetFormLinkingDatabaseManager().fetchAssetLinkedToForm(FPFormDataHolder.shared.customForm)
        }
        return arrResult
    }
    
    var arrTblFormulas = [ColumnFormula]()
    var isAutoCalculateEnabled: Bool = false
    
    var isDuplicateRowAddedEndOFTable:Bool{
        if let preference = UserDefaults.standard.object(forKey: "DuplicateRowPreference") as? String {
            return preference == "lbl_End_Table"
        }else{
            return false
        }
    }

    private var fpTableSearchBar: UISearchBar?
    private var fpTableSearchFilterButton: UIButton?
    private var fpTableSearchEmptyLabel: UILabel?
    private var fpTableSearchDebounceWorkItem: DispatchWorkItem?
    /// Empty set = search all non-hidden columns.
    private var fpTableSearchColumnNameKeys: Set<String> = []
    private var fpTableSearchHighlightQuery: String = ""
    private var fpTableSearchColumnPrefsKey: String {
        "ZenForms.FPTableEdit.textSearch.columns.\(fieldDetails?.templateId ?? "0")"
    }
    private let bulkEditInfoShownPrefsKey = "ZenForms.FPTableEdit.bulkEdit.confirmation.shown"

    override func viewDidLoad() {
        super.viewDidLoad()
        zenFormsDelegate?.mixpanelEvent(eventName: "TABLE_SCREEN_VIEWED", properties: nil)
        if let vals = tableComponent?.getValuesObject() {
            fp_sessionInitialSnapshot = fp_normalizeJsonForComparison(vals.getJson())
        }
        fp_setupAutoSave()
        fp_checkAndRecoverDraft()
        rowCount = 1
        txtRowCount.text = "\(rowCount)"
        txtRowCount.inputAccessoryView = self.accessoryToolbar
        stkOptions.isHidden = true
        
        var arrBtns = [UIBarButtonItem]()
        let saveButton = UIBarButtonItem(title:FPLocalizationHelper.localize("SAVE"), style:.plain, target: self, action: #selector(saveButtonAction))
        let settingsButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), style: .plain, target: self, action: #selector(settingsButtonAction))
        if !self.isAnalysed && !self.isFromHistory {
            arrBtns.append(saveButton)
        }
        arrBtns.append(settingsButton)
        self.navigationItem.rightBarButtonItems = arrBtns
        
        let cancelButton = UIBarButtonItem(title:FPLocalizationHelper.localize("Cancel"), style: .plain, target: self, action: #selector(cancelButtonClicked))
        self.navigationItem.leftBarButtonItem = cancelButton
        let bundle = ZenFormsBundle.bundle
        
        collectionView?.register(
            UINib(nibName: headerCellReuseIdentifier, bundle: bundle),
            forCellWithReuseIdentifier: headerCellReuseIdentifier
        )
        collectionView?.register(
            UINib(nibName: contentCellReuseIdentifier, bundle: bundle),
            forCellWithReuseIdentifier: contentCellReuseIdentifier
        )
        viewModel = FPSpreadsheetCollectionViewModel()
        if let formulas = self.tableComponent?.tableOptions?.formulas as? [ColumnFormula], !formulas.isEmpty{
            arrTblFormulas = []
            arrTblFormulas.append(contentsOf: formulas)
        }
        isAutoCalculateEnabled = arrTblFormulas.count > 0
        self.title  = titleText
        fpInstallTableSearchChrome()
        fp_configureBulkEditToolbarButtonAppearance()
    }

    /// Heavier SF Symbol weight so the bulk edit control matches the visual weight of adjacent toolbar icons.
    private func fp_configureBulkEditToolbarButtonAppearance() {
        guard let btn = btnBulkEdit else { return }
        let base = UIImage(systemName: "square.and.pencil")
        let config = UIImage.SymbolConfiguration(pointSize: 19, weight: .bold, scale: .medium)
        if let img = base?.applyingSymbolConfiguration(config) {
            btn.setImage(img, for: .normal)
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.view.layoutIfNeeded()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        fp_showAutoSaveHintIfNeeded()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.registerAssetObservers()
        fpReapplyTableTextSearchIfNeeded()
        IQKeyboardManager.shared.isEnabled = true
        IQKeyboardToolbarManager.shared.isEnabled = true
        IQKeyboardToolbarManager.shared.toolbarConfiguration.previousBarButtonConfiguration = IQBarButtonItemConfiguration(image: UIImage(named: "ic_left_arrow", in: ZenFormsBundle.bundle, compatibleWith: nil) ?? UIImage())
        IQKeyboardToolbarManager.shared.toolbarConfiguration.nextBarButtonConfiguration = IQBarButtonItemConfiguration(image: UIImage(named: "ic_right_arrow", in: ZenFormsBundle.bundle, compatibleWith: nil) ?? UIImage())
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        fp_stopAutoSave()
        NotificationCenter.default.removeObserver(self)
        IQKeyboardManager.shared.isEnabled = false
        IQKeyboardToolbarManager.shared.isEnabled = false
        IQKeyboardToolbarManager.shared.toolbarConfiguration.previousBarButtonConfiguration = IQBarButtonItemConfiguration(image: UIImage())
        IQKeyboardToolbarManager.shared.toolbarConfiguration.nextBarButtonConfiguration = IQBarButtonItemConfiguration(image: UIImage())
    }
    
    func registerAssetObservers(){
        NotificationCenter.default.addObserver(self, selector:#selector(clearAssetLinkingIndex), name:NSNotification.ClearAssetLinkSelected, object:nil)
        NotificationCenter.default.addObserver(self, selector: #selector(fpHandleMemoryWarning), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
    }
    
    @objc func clearAssetLinkingIndex(){
        self.assetLinkIndexPath = nil
        self.resetMultipleSeletion()
    }

    @objc private func fpHandleMemoryWarning() {
        fpTableSearchDebounceWorkItem?.cancel()
        fpTableSearchDebounceWorkItem = nil

        // Save draft immediately before the OS potentially kills the process
        fp_autoSave()

        if !isSortFilterApplied {
            arrSelectedRows.removeAll()
            arrSelectedIndexes.removeAll()
        }

        collectionView?.collectionViewLayout.invalidateLayout()
    }

    
    @objc func onDoneButtonTapped(sender: UIBarButtonItem) {
        if self.txtRowCount.isFirstResponder {
            self.txtRowCount.resignFirstResponder()
        }
    }
    
    
    //MARK: Actions
    
    @IBAction func btnOpenClonseDidTap(_ sender: UIButton) {
        self.constLeading.constant = sender.isSelected ? -120.0 : 0.0
        UIView.animate(withDuration: 0.3, animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
        sender.isSelected = !sender.isSelected
    }
    
    @objc func settingsButtonAction(){
        let settingVC =  DuplicateRowPrefrenceViewController(nibName: "DuplicateRowPrefrenceViewController", bundle: ZenFormsBundle.bundle)
                let navController = UINavigationController(rootViewController: settingVC)
        if UIDevice.current.userInterfaceIdiom == .pad{
            navController.presentAsPopoverFP(self.view, rect: CGRectMake(CGRectGetMidX(self.view.bounds), 80,0,0), permittedArrowDirections: UIPopoverArrowDirection(), preferredContentSize: CGSize(width: 300, height: 500), base: self)
        } else {
            present(navController, animated: true)
        }
    }
    

    
    @objc func saveButtonAction(){
        view.endEditing(true)
        zenFormsDelegate?.mixpanelEvent(eventName: "TABLE_SAVE_CLICKED", properties: nil)
        fp_performAutoSave()
        fp_stopAutoSave()
        DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
            if let tableComponent = self.tableComponent,let index = self.tableIndexPath{
                FPFormDataHolder.shared.addTableComponentAt(index: index, component: tableComponent)
                self.didCompletedEdit?(tableComponent)
            }
            // Process all cached media synchronously — we're already on the main thread inside asyncAfter.
            // Nested DispatchQueue.main.async calls would let other closures interleave between mutations
            // of the shared FPFormDataHolder struct, risking inconsistent state.
            FPFormDataHolder.shared.tableMediaCache.forEach { tableMedia in
                FPFormDataHolder.shared.updateTableFieldValue(media: tableMedia)
            }
            FPFormDataHolder.shared.tableMediaCache = []
            
            if self.isAssetEnabled, let isAssetTable = self.tableComponent?.tableOptions?.isAssetTable, isAssetTable{
                var arrLocalLinkings = [AssetFormMappingData]()
                arrLocalLinkings.append(contentsOf: FPFormDataHolder.shared.arrLinkingDB)
                arrLocalLinkings.forEach { linking in
                    linking.isTableSaved = true
                }
                FPFormDataHolder.shared.arrLinkingDB = []
                FPFormDataHolder.shared.arrLinkingDB.append(contentsOf: arrLocalLinkings)
            }
            
            self.navigationController?.popViewController(animated: false)
        })
    }
    
    @objc func cancelButtonClicked() {
        fp_stopAutoSave()
        view.endEditing(true)
        zenFormsDelegate?.mixpanelEvent(eventName: "TABLE_CANCEL_CLICKED", properties: nil)
        let currentValues = tableComponent?.getValuesObject()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var hasChanges = false
            if let vals = currentValues {
                hasChanges = self.fp_normalizeJsonForComparison(vals.getJson()) != self.fp_sessionInitialSnapshot
            }
            DispatchQueue.main.async {
                if hasChanges {
                    _ = FPUtility.showAlertController(
                        title: FPLocalizationHelper.localize("alert_dialog_title"),
                        andMessage: FPLocalizationHelper.localize("msg_are_sure_data_lost"),
                        completion: nil,
                        withPositiveAction: FPLocalizationHelper.localize("Yes"),
                        style: .default,
                        andHandler: { [weak self] _ in
                            self?.performCancelDismiss()
                        },
                        withNegativeAction: FPLocalizationHelper.localize("Cancel"),
                        style: .default,
                        andHandler: nil
                    )
                } else {
                    self.performCancelDismiss()
                }
            }
        }
    }

    private func performCancelDismiss() {
        if self.isAssetEnabled, let isAssetTable = self.tableComponent?.tableOptions?.isAssetTable, isAssetTable {
            let otherFieldTableSavedLinkings = FPFormDataHolder.shared.arrLinkingDB.filter { $0.fieldTemplateId != self.fieldDetails?.templateId || $0.isTableSaved == true }
            FPFormDataHolder.shared.arrLinkingDB = []
            FPFormDataHolder.shared.arrLinkingDB.append(contentsOf: otherFieldTableSavedLinkings)
            AssetFormLinkingDatabaseManager().fetchAndRemoveNotConfirmedAssetLinkingForForm(FPFormDataHolder.shared.customForm)
        }
        FPFormDataHolder.shared.tableMediaCache = []
        fp_deleteDraft()
        self.navigationController?.popViewController(animated: true)
    }
    
    

    @IBAction func didTapAddRow(_ sender: Any){
        self.view.endEditing(true)
        guard let rowValue = txtRowCount.text, !rowValue.isEmpty, let intVal  = Int(rowValue) else {
            _  = FPUtility.showAlertController(title: FPLocalizationHelper.localize("error_dialog_title"), message: FPLocalizationHelper.localize("msg_Invalid_add_row"), completion: nil)
            return
        }
        rowCount = intVal
        if rowCount < 1{
            _  = FPUtility.showAlertController(title: FPLocalizationHelper.localize("error_dialog_title"), message: FPLocalizationHelper.localize("msg_add_row_non_Zero"), completion: nil)
            return
        }else if rowCount > 10{
            _  = FPUtility.showAlertController(title: FPLocalizationHelper.localize("error_dialog_title"), message: FPLocalizationHelper.localize("msg_add_row_max_ten"), completion: nil)
            return
        }
        guard let row = self.tableComponent?.rows?.first else { return }

        fp_triggerFirstSaveIfNeeded()
        FPUtility.showHUDWithLoadingMessage()

        for _ in 1...rowCount {
            let newRow = self.tableComponent?.addNewRow(with: row.columns)
            if isSortFilterApplied{
                _ = self.sortFilteredTableComponent?.addNewRow(with: row.columns, rowSortId: newRow?.sortUuid)
            }
        }
        DispatchQueue.main.async {
            FPUtility.hideHUD()
            if let layout = self.collectionView.collectionViewLayout as? FPSpreadsheetCollectionViewLayout {
                layout.addRow(nRow: self.rowCount)
                layout.invalidateLayout()
            }
            self.fp_bumpTableGeneration()
            self.collectionView.reloadData()
            self.fpReapplyTableTextSearchIfNeeded()
        }
    }
    
    func addEmptyRowToTable(){
        guard let row = self.tableComponent?.rows?.first else { return }
        fp_triggerFirstSaveIfNeeded()
        let newRow = self.tableComponent?.addNewRow(with: row.columns, ignoreDefaultVal: true)
        if isSortFilterApplied{
            _ = self.sortFilteredTableComponent?.addNewRow(with: row.columns, rowSortId: newRow?.sortUuid, ignoreDefaultVal: true)
        }
        if let layout = collectionView.collectionViewLayout as? FPSpreadsheetCollectionViewLayout {
            layout.addRow(nRow: 1)
            layout.invalidateLayout()
        }
        self.fp_bumpTableGeneration()
        self.collectionView.reloadData()
        self.fpReapplyTableTextSearchIfNeeded()
    }
    
    @IBAction func btnDuplicateDidTap(_ sender: UIButton) {
        FPUtility.showAlertController(title: FPLocalizationHelper.localize("alert_dialog_title"), andMessage: FPLocalizationHelper.localize("msg_duplicate_selected_rows"), completion: nil, withPositiveAction: FPLocalizationHelper.localize("Yes"), style: .default, andHandler: { (action) in
            self.duplicateMultipleRows(self.arrSelectedRows)
        }, withNegativeAction: FPLocalizationHelper.localize("Cancel"), style: .default, andHandler: nil)
    }
    
    @IBAction func btnDeleteDidTap(_ sender: UIButton) {
        
        FPUtility.showAlertController(title: FPLocalizationHelper.localize("alert_dialog_title"), andMessage:  FPLocalizationHelper.localize("msg_delete_selected_rows"), completion: nil, withPositiveAction: FPLocalizationHelper.localize("Yes"), style: .default, andHandler: { (action) in
            self.deleteMultipleRows(self.arrSelectedRows)
        }, withNegativeAction: FPLocalizationHelper.localize("Cancel"), style: .default, andHandler: nil)
    }
    
    @IBAction func btnLinkAssetDidTap(_ sender: UIButton) {
        if let childTableIndex = self.arrSelectedIndexes.first{
            self.linkAsset(at: childTableIndex, parentTableIndex: tableIndexPath)
        }
    }
    @IBAction func btnEditRowDidTap(_ sender: UIButton) {
        if let selIndex = self.arrSelectedIndexes.first {
            openEditRow(forSection: selIndex.section) {
                self.resetMultipleSeletion()
            }
        }
    }

    @IBAction func btnBulkEditDidTap(_ sender: UIButton) {
        let indices = uniqueSelectedFullRowIndices()
        guard indices.count >= 2 else { return }
        let alreadyShownInfo = UserDefaults.standard.bool(forKey: bulkEditInfoShownPrefsKey)
        if alreadyShownInfo {
            openBulkEditFromCurrentSelection {
                self.resetMultipleSeletion()
            }
            return
        }
        UserDefaults.standard.set(true, forKey: bulkEditInfoShownPrefsKey)
        FPUtility.showAlertController1(
            title: FPLocalizationHelper.localize("lbl_Bulk_Edit"),
            andMessage: FPLocalizationHelper.localize("msg_bulk_edit_confirm_detail"),
            completion: nil,
            withPositiveAction: FPLocalizationHelper.localize("lbl_Continue"),
            style: .default,
            andHandler: { _ in
                self.openBulkEditFromCurrentSelection {
                    self.resetMultipleSeletion()
                }
            },
            withNegativeAction: FPLocalizationHelper.localize("Cancel"),
            style: .default,
            andHandler: nil
        )
    }

    /// Maps a collection view data section to a 0-based index in `tableComponent.rows` (sort/filter/text search).
    func fullRowIndex(fromVisibleSection section: Int) -> Int? {
        fp_visibleSectionToFullTableRowIndex(section)
    }

    /// Unique selected data rows as full-table indices (0-based), sorted ascending.
    func uniqueSelectedFullRowIndices() -> [Int] {
        var set = Set<Int>()
        for ip in arrSelectedIndexes where ip.section >= 1 {
            if let idx = fullRowIndex(fromVisibleSection: ip.section) {
                set.insert(idx)
            }
        }
        return set.sorted()
    }

    /// Opens bulk edit when at least two distinct rows are selected; uses smallest row index as the base row.
    func openBulkEditFromCurrentSelection(completion: (() -> Void)? = nil) {
        let indices = uniqueSelectedFullRowIndices()
        guard indices.count >= 2 else { return }
        presentRowEditor(fullRowIndices: indices, isBulkMode: true, completion: completion)
    }

    /// Opens FPEditRowViewController for the given collection view section (section 1 = first data row).
    /// When sort/filter is applied, maps the visible section to the correct row index in the full table.
    func openEditRow(forSection section: Int, completion: (() -> Void)? = nil) {
        guard let rowNo = fullRowIndex(fromVisibleSection: section) else { return }
        presentRowEditor(fullRowIndices: [rowNo], isBulkMode: false, completion: completion)
    }

    private func presentRowEditor(fullRowIndices: [Int], isBulkMode: Bool, completion: (() -> Void)? = nil) {
        let sorted = fullRowIndices.sorted()
        guard let baseRow = sorted.first,
              let last = sorted.last,
              let rowCount = tableComponent?.rows?.count,
              baseRow >= 0,
              last < rowCount else { return }

        let vc = FPEditRowViewController(
            nibName: "FPEditRowViewController",
            bundle: ZenFormsBundle.bundle
        )
        vc.title = isBulkMode ? FPLocalizationHelper.localize("lbl_Bulk_Edit") : FPLocalizationHelper.localize("lbl_Edit_Row")
        vc.tableIndexPath = tableIndexPath
        vc.currentRowNo = baseRow
        vc.isBulkEditMode = isBulkMode
        vc.bulkSelectedFullRowIndices = isBulkMode ? sorted : []
        vc.columnApplyToAllByKey = [:]
        vc.tableComponent = tableComponent?.makeCopy()
        vc.arrTblFormulas = arrTblFormulas
        vc.isAutoCalculateEnabled = isAutoCalculateEnabled
        vc.didEditedRows = { [weak self] tableComponent in
            DispatchQueue.main.async {
                self?.tableComponent = tableComponent
                if self?.isSortFilterApplied == true {
                    self?.reapplySortFilterAfterEdit()
                } else {
                    self?.fp_bumpTableGeneration()
                    self?.collectionView.reloadData()
                }
                // Save immediately after the full-row edit is committed so the
                // draft reflects the latest state if the app is killed/crashed.
                self?.fp_performAutoSave()
            }
        }
        let nav = UINavigationController(rootViewController: vc)
        nav.navigationBar.prefersLargeTitles = false
        if UIDevice.current.userInterfaceIdiom == .pad {
            nav.modalPresentationStyle = .custom
            nav.transitioningDelegate = cardTransitionDelegate
        } else {
            if isBulkMode {
                nav.modalPresentationStyle = .fullScreen
            } else {
                nav.modalPresentationStyle = .pageSheet
                if let sheet = nav.sheetPresentationController {
                    sheet.detents = [.large()]
                    sheet.prefersGrabberVisible = true
                }
            }
        }
        present(nav, animated: true, completion: completion)
    }

    /// Re-applies current sort/filter to the updated tableComponent and refreshes the collection view. Call after edit when isSortFilterApplied.
    private func reapplySortFilterAfterEdit() {
        guard !arrAppliedFilters.isEmpty, tableComponent != nil else {
            DispatchQueue.main.async { [weak self] in
                self?.fp_bumpTableGeneration()
                self?.collectionView.reloadData()
                self?.fpReapplyTableTextSearchIfNeeded()
            }
            return
        }
        let sortFilter = arrAppliedFilters.first(where: { $0.option != .filter })
        let filterFilter = arrAppliedFilters.first(where: { $0.option == .filter })
        if let sortFilter = sortFilter, sortFilterColumn != nil {
            sortFilteredTableComponent = nil
            applySortingToTable(option: sortFilter.option) { [weak self] sortedtbl in
                guard let self = self else { return }
                self.sortFilteredTableComponent = sortedtbl
                if let filterFilter = filterFilter, let items = filterFilter.filterItems, !items.isEmpty, let col = self.sortFilterColumn {
                    sortedtbl.filterData(component: sortedtbl, arrSelected: items, filterColumn: col) { filteredComponent in
                        self.sortFilteredTableComponent = filteredComponent
                        DispatchQueue.main.async {
                            self.fp_bumpTableGeneration()
                            self.collectionView.reloadData()
                            self.fpReapplyTableTextSearchIfNeeded()
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.fp_bumpTableGeneration()
                        self.collectionView.reloadData()
                        self.fpReapplyTableTextSearchIfNeeded()
                    }
                }
            }
        } else if let filterFilter = filterFilter, let items = filterFilter.filterItems, !items.isEmpty, let column = sortFilterColumn, let tbl = tableComponent {
            tbl.filterData(component: tbl, arrSelected: items, filterColumn: column) { [weak self] filteredComponent in
                self?.sortFilteredTableComponent = filteredComponent
                DispatchQueue.main.async {
                    self?.fp_bumpTableGeneration()
                    self?.collectionView.reloadData()
                    self?.fpReapplyTableTextSearchIfNeeded()
                }
            }
        } else {
            sortFilteredTableComponent = nil
            DispatchQueue.main.async { [weak self] in
                self?.fp_bumpTableGeneration()
                self?.collectionView.reloadData()
                self?.fpReapplyTableTextSearchIfNeeded()
            }
        }
    }
}

extension FPTableEditViewController: FPSpreadsheetCollectionViewModelDataSource {
    func configure(_ cell: UICollectionViewCell, with content: String, column: ColumnData?, indexPath: IndexPath, isHideMore: Bool, isHideCHeckBoxHeader:Bool) {
        if let contentcell = cell as? TableContentCollectionViewCell {
            contentcell.parentTableIndex = tableIndexPath
            contentcell.childTableIndex = indexPath
            if fpTableSearchHighlightQuery.isEmpty {
                contentcell.searchHighlightCaseSensitive = false
                contentcell.searchHighlightColumnKeys = []
                contentcell.searchHighlightQuery = nil
            } else {
                contentcell.searchHighlightCaseSensitive = TableRowTextSearch.userPrefersCaseSensitiveSearch
                contentcell.searchHighlightColumnKeys = fpTableSearchColumnNameKeys
                contentcell.searchHighlightQuery = fpTableSearchHighlightQuery
            }
            contentcell.data = column
            contentcell.delegate = self
            contentcell.btnAction.isSelected = self.isSelectedAll || self.arrSelectedIndexes.contains(indexPath)
            contentcell.btnAction.addTarget(self, action: #selector(btnActionClicked(sender:)), for: .touchUpInside)
            var showBarcodeBtn = false
            if isAssetEnabled, let isAssetTable = self.tableComponent?.tableOptions?.isAssetTable, isAssetTable{
                showBarcodeBtn = column?.scannable ?? false && column?.dataType == "TEXT" && column?.uiType == "INPUT"
            }
            contentcell.viewBarcode.isHidden = !showBarcodeBtn
            contentcell.btnBarcode.addTarget(self, action: #selector(btnBarcodeClicked(sender:)), for: .touchUpInside)
        }else if let headerCell = cell as? TableHeaderCollectionViewCell {
            headerCell.imgMore.image =  UIImage(named: "icn_more", in: ZenFormsBundle.bundle, compatibleWith: nil)
            headerCell.imgMore.setImageColor(color: .black)
            headerCell.text = content
            if indexPath.row == 0 {
                headerCell.title.numberOfLines = 1
                headerCell.title.adjustsFontSizeToFitWidth = true
                headerCell.title.minimumScaleFactor = 0.5
                headerCell.title.lineBreakMode = .byTruncatingTail
            }
            headerCell.viewBtn.isHidden = isHideMore
            headerCell.btnActions.isHidden = isHideCHeckBoxHeader
            headerCell.btnActions.isSelected =  self.isSelectedAll
            headerCell.title.isHidden = !isHideCHeckBoxHeader
            headerCell.btnMore.addTarget(self, action: #selector(btnMoreClicked(sender:)), for: .touchUpInside)
            headerCell.btnActions.addTarget(self, action: #selector(btnHeaderActionClicked(sender:)), for: .touchUpInside)
            let isSerialNumberRow = indexPath.row == 0 && indexPath.section > 0
            let showExpandForRow = isSerialNumberRow
            headerCell.viewExpand.isHidden = !showExpandForRow
            if showExpandForRow {
                headerCell.btnExpand.tintColor = UIColor(named: "BT-Primary") ?? .systemBlue
                headerCell.currentIndexPath = indexPath
                headerCell.onExpandTapped = { [weak self] ip in
                    self?.openEditRow(forSection: ip.section)
                }
            } else {
                headerCell.currentIndexPath = nil
                headerCell.onExpandTapped = nil
            }
            if isSortFilterApplied == true, let index = arrAppliedFilters.firstIndex(where: { $0.indPath == indexPath}), let appliedFilter = arrAppliedFilters[safe: index]  {
                if appliedFilter.option == .filter {
                    headerCell.imgMore.image = UIImage(named: "icn_filter", in: ZenFormsBundle.bundle, compatibleWith: nil)
                }else{
                    headerCell.imgMore.image = UIImage(named: appliedFilter.option == .ascending ? "icn_sort_asc" : "icn_sort_dsc", in: ZenFormsBundle.bundle, compatibleWith: nil)
                }
                headerCell.imgMore.setImageColor(color: UIColor(named: "BT-Primary") ?? .blue)
            }
        }
    }

    
    func cellReuseIdentifier(for indexPath: IndexPath) -> String {
        switch (column: indexPath.row, row: indexPath.section) {
            // Origin
        case (0, 0):
            return headerCellReuseIdentifier
            
            // Top row
        case (_, 0):
            return headerCellReuseIdentifier
            
            // Left column
        case (0, _):
            return headerCellReuseIdentifier
            
            // Inner-content
        default:
            return contentCellReuseIdentifier
        }
    }
    func getTableComponent()->TableComponent?{
        if isSortFilterApplied{
            return self.sortFilteredTableComponent
        }else{
            return self.tableComponent
        }
    }
    
    @objc func btnMoreClicked(sender: UIButton){
        let btnPosition = sender.convert(CGPoint.zero, to: self.collectionView)
        sortFilterColumnIndexPath = self.collectionView.indexPathForItem(at: btnPosition)
        if  let sortedIndexPth = sortFilterColumnIndexPath, let shownColumns = self.tableComponent?.tableOptions?.columns?.filter({$0.uiType != "HIDDEN"}), let column = shownColumns[safe:sortedIndexPth.row - 2]{
            sortFilterColumn = column
        }
        if sortFilterColumn?.uiType == "DROPDOWN" || sortFilterColumn?.uiType == "DEFICIENCY"{
            displayOptionsPopUp(sender)
        }else{
            displaySortingPopUp(sender)
        }
    }
    
    @objc func btnHeaderActionClicked(sender: UIButton){
        sender.isSelected = !sender.isSelected
        isSelectedAll = sender.isSelected
        if isSelectedAll{
            self.selectALLRows()
        }else{
            self.unSelectALLRows()
        }
        self.refreshActionButtons()
    }
    
    @objc func btnActionClicked(sender: UIButton){
        let btnPosition = sender.convert(CGPoint.zero, to: self.collectionView)
        if let indexPath = self.collectionView.indexPathForItem(at: btnPosition){
            var selectedRow:Rows?
            guard let dRow = fp_visibleSectionToDisplayRowIndex(indexPath.section) else { return }
            if self.isSortFilterApplied{
                selectedRow =  self.sortFilteredTableComponent?.rows?[safe:dRow]
            }else{
                selectedRow =  self.tableComponent?.rows?[safe:dRow]
            }
            if let rowIndex = self.arrSelectedRows.firstIndex(where: { $0.sortUuid == selectedRow?.sortUuid }){
                self.arrSelectedRows.remove(at: rowIndex)
            }else{
                if let selectedRow = selectedRow{
                    self.arrSelectedRows.append(selectedRow)
                }
            }
            var tmpIndexs = self.arrSelectedIndexes
            if self.arrSelectedIndexes.contains(indexPath){
                self.arrSelectedIndexes.removeObject(indexPath)
            }else{
                tmpIndexs.append(indexPath)
                self.arrSelectedIndexes.append(indexPath)
            }
            if self.isSelectedAll{
                self.isSelectedAll = false
                self.fp_bumpTableGeneration()
                self.collectionView.reloadData()
            }else{
                self.collectionView.reloadItems(at: tmpIndexs)
            }
            self.refreshActionButtons()
        }
    }
    
    @objc func btnBarcodeClicked(sender: UIButton){
        let btnPosition = sender.convert(CGPoint.zero, to: self.collectionView)
        if let index = self.collectionView.indexPathForItem(at: btnPosition){
            self.linkAsset(at: index, parentTableIndex: tableIndexPath)
        }
    }

    
    func refreshActionButtons(animated: Bool = true) {

        let hasSelection = arrSelectedRows.count > 0

        var shouldShowAssetLink = false
        var shouldShowDuplicate = true
        let shouldShowEditRow = false // Edit icon removed when checkbox/toolbar appears at bottom

        if isAssetEnabled,
           let isAssetTable = tableComponent?.tableOptions?.isAssetTable,
           isAssetTable {

            shouldShowAssetLink = arrSelectedRows.count == 1
            shouldShowDuplicate = false
        }

        let shouldShowBulkEdit = uniqueSelectedFullRowIndices().count >= 2
            && !isAnalysed
            && !isFromHistory

        updateVisibility(
            view: stkOptions,
            hidden: !hasSelection,
            animated: animated
        )
        
        updateVisibility(
            view: btnEditRow,
            hidden: !shouldShowEditRow,
            animated: animated
        )

        updateVisibility(
            view: btnBulkEdit,
            hidden: !shouldShowBulkEdit,
            animated: animated
        )

        updateVisibility(
            view: btnAssetLink,
            hidden: !shouldShowAssetLink,
            animated: animated
        )

        updateVisibility(
            view: btnDuplicate,
            hidden: !shouldShowDuplicate,
            animated: animated
        )
    }
    
    private func updateVisibility(view: UIView, hidden: Bool, animated: Bool) {
        guard view.isHidden != hidden else { return }

        if animated {

            if !hidden {
                view.alpha = 0
                view.isHidden = false
            }

            UIView.animate(
                withDuration: 0.25,
                delay: 0,
                options: [.curveEaseInOut, .beginFromCurrentState],
                animations: {
                    view.alpha = hidden ? 0 : 1
                    self.view.layoutIfNeeded()
                },
                completion: { _ in
                    view.isHidden = hidden
                }
            )

        } else {
            view.isHidden = hidden
            view.alpha = hidden ? 0 : 1
        }
    }
    
    func selectALLRows(){
        self.arrSelectedIndexes = []
        self.arrSelectedRows = []
        (1..<collectionView.numberOfSections).forEach { sectionIndex in
            var selectedRow:Rows?
            guard let dRow = fp_visibleSectionToDisplayRowIndex(sectionIndex) else { return }
            if self.isSortFilterApplied{
                selectedRow =  self.sortFilteredTableComponent?.rows?[safe:dRow]
            }else{
                selectedRow =  self.tableComponent?.rows?[safe:dRow]
            }
            if let selectedRow = selectedRow{
                self.arrSelectedRows.append(selectedRow)
            }
        }

        (1..<collectionView.numberOfSections).indices.forEach { sectionIndex in
            //fixed BB-13681
            let indexPath = IndexPath(item: 1, section: sectionIndex)
            self.arrSelectedIndexes.append(indexPath)
        }
        
        if self.arrSelectedRows.count == 1{
            (0..<collectionView.numberOfItems(inSection: 1)).indices.forEach { rowIndex in
                if let cell = collectionView.cellForItem(at: IndexPath(row: rowIndex, section: 1)) as? TableContentCollectionViewCell{
                    let showBarcodeBtn = cell.data?.scannable ?? false && cell.data?.dataType == "TEXT" && cell.data?.uiType == "INPUT"
                    if showBarcodeBtn {
                        self.arrSelectedIndexes.append(IndexPath(row: rowIndex, section: 1))
                    }
                }
            }
        }
        self.isSelectedAll = true
        self.fp_bumpTableGeneration()
        self.collectionView.reloadData()
    }
    
    func unSelectALLRows(){
        self.isSelectedAll = false
        self.arrSelectedIndexes = []
        self.arrSelectedRows = []
        self.fp_bumpTableGeneration()
        self.collectionView.reloadData()
    }
  
}

//MARK: Sort Filter Operations

extension UITableView{
    func configureRSSelectionMenuTable(){
        if #available(iOS 15, *) {
            self.sectionHeaderTopPadding = 0
        }
        self.layoutMargins = UIEdgeInsets.zero
        self.separatorInset = UIEdgeInsets.zero
    }
}
extension FPTableEditViewController{
    
    
    func displaySortingPopUp(_ sender:UIButton){
        let arrOptions = [FPLocalizationHelper.localize("lbl_Ascending"), FPLocalizationHelper.localize("lbl_Descending")]
        let menu = RSSelectionMenu(selectionStyle: .single, dataSource: arrOptions) { (cell, name, indexPath) in
            cell.textLabel?.text = name
            cell.tintColor = UIColor(named: "BT-Primary") ?? .blue
        }
        menu.tableView?.configureRSSelectionMenuTable()
        menu.setNavigationBar(title: FPLocalizationHelper.localize("lbl_Sort"), attributes: [NSAttributedString.Key.foregroundColor: isFromCoPILOT ? UIColor.white : UIColor.black], barTintColor: UIColor(named: "BT-Primary"), tintColor: isFromCoPILOT ? UIColor.white : UIColor.black)
        if !self.arrAppliedFilters.isEmpty{
            let leftBarButton = UIBarButtonItem(title:FPLocalizationHelper.localize("lbl_Clear"), style: .plain, target: self, action: #selector(leftBarButtonTapped))
            menu.navigationItem.leftBarButtonItem = leftBarButton
        }
        let rightBarButton = UIBarButtonItem(title:FPLocalizationHelper.localize("Cancel"), style: .plain, target: self, action: #selector(rightBarButtonTapped))
        menu.navigationItem.rightBarButtonItem = rightBarButton
        menu.navigationItem.rightBarButtonItem?.tintColor = UIColor(named: "BT-Primary")
        if isSortFilterApplied == true, let index = arrAppliedFilters.firstIndex(where: { $0.indPath == sortFilterColumnIndexPath}), let appliedFilter  = arrAppliedFilters[safe: index]{
            let strSort = appliedFilter.option == .ascending ? FPLocalizationHelper.localize("lbl_Ascending"): FPLocalizationHelper.localize("lbl_Descending")
            menu.setSelectedItems(items: [strSort]) {  (_, _, _, _) in }
        }
        menu.onDismiss = { selectedItems in
            if let selected = selectedItems.first{
                if let index = self.arrAppliedFilters.firstIndex(where: { $0.option != .filter}){
                    self.arrAppliedFilters.remove(at: index)
                }
                var localsort:SortColumnOption = .descending
                if selected == FPLocalizationHelper.localize("lbl_Ascending"){
                    localsort = .ascending
                }
                if let sortFilterColumnIndexPath = self.sortFilterColumnIndexPath, let index = self.arrAppliedFilters.firstIndex(where: { $0.indPath == sortFilterColumnIndexPath}){
                    self.arrAppliedFilters.remove(at: index)
                }
                if let sortFilterColumnIndexPath = self.sortFilterColumnIndexPath{
                    let filter = SortFilter(indPath: sortFilterColumnIndexPath, option: localsort, filterItems: nil)
                    if let index = self.arrAppliedFilters.firstIndex(where: { $0.indPath == sortFilterColumnIndexPath}){
                        self.arrAppliedFilters[index] = filter
                    }else{
                        self.arrAppliedFilters.append(filter)
                    }
                }
                self.applySortFilterToTable(option: localsort)
            }
        }
        menu.cellSelectionStyle = .tickmark
        menu.show(style: .popover(sourceView: sender, size: nil, arrowDirection: .any), from: self)
    }
    
    func clearCurrentRowFilter(){
        if let sortFilterColumnIndexPath = self.sortFilterColumnIndexPath, let index = self.arrAppliedFilters.firstIndex(where: { $0.indPath == sortFilterColumnIndexPath}){
            self.arrAppliedFilters.remove(at: index)
        }
        if self.arrAppliedFilters.isEmpty{
            self.resetToDefault()
        }else if let object = self.arrAppliedFilters.first{
//            self.sortFilteredTableComponent = nil
            self.sortFilterColumnIndexPath = object.indPath
            if  let sortedIndexPth = sortFilterColumnIndexPath, let column = self.tableComponent?.tableOptions?.columns?[safe:sortedIndexPth.row - 2]{
                sortFilterColumn = column
            }
            self.applySortFilterToTable(option: object.option)
        }
    }
    
    func resetToDefault(){
        //clear option selected
        self.arrAppliedFilters = []
        self.sortFilterColumnIndexPath = nil
        self.isSortFilterApplied = false
        self.sortFilterColumn = nil
        self.sortFilteredTableComponent = nil
        // Reset selection state without triggering an intermediate reloadData
        self.arrSelectedIndexes = []
        self.arrSelectedRows = []
        self.isSelectedAll = false
        self.refreshActionButtons()
        // Reset scroll position BEFORE invalidating layout so the layout captures (0,0) as
        // originalContentOffset — prevents cells rendering at stale offsets (UI glitch after Clear).
        self.collectionView.setContentOffset(.zero, animated: false)
        if let layout = self.collectionView.collectionViewLayout as? FPSpreadsheetCollectionViewLayout {
            layout.invalidateDataSourceCounts()
        } else {
            self.collectionView.collectionViewLayout.invalidateLayout()
        }
        self.fp_bumpTableGeneration()
        self.collectionView.reloadData()
        self.fpReapplyTableTextSearchIfNeeded()
    }
    
    
    func resetMultipleSeletion(){
        self.arrSelectedIndexes = []
        self.arrSelectedRows = []
        self.isSelectedAll = false
        self.refreshActionButtons()
        self.fp_bumpTableGeneration()
        self.collectionView.reloadData()
    }
    
    func displayOptionsPopUp(_ sender:UIButton){
        if  isSortFilterApplied == true, let index = arrAppliedFilters.firstIndex(where: { $0.indPath == sortFilterColumnIndexPath}), let appliedFilter  = arrAppliedFilters[safe: index]  {
            if appliedFilter.option  == .filter{
                self.displayFilterPopUp(sender)
            }else{
                self.displaySortingPopUp(sender)
            }
        }
        else{
            let arrOptions = [FPLocalizationHelper.localize("lbl_Sort"), FPLocalizationHelper.localize("lbl_Filter")]
            let menu = RSSelectionMenu(selectionStyle: .single, dataSource: arrOptions) { (cell, name, indexPath) in
                cell.textLabel?.text = name
                cell.tintColor = UIColor(named: "BT-Primary") ?? .blue
            }
            let rightBarButton = UIBarButtonItem(title:FPLocalizationHelper.localize("Cancel"), style: .plain, target: self, action: #selector(rightBarButtonTapped))
            menu.navigationItem.rightBarButtonItem = rightBarButton
            menu.navigationItem.rightBarButtonItem?.tintColor = UIColor(named: "BT-Primary")
            menu.tableView?.configureRSSelectionMenuTable()
            menu.setNavigationBar(title: FPLocalizationHelper.localize("lbl_Sort_Filter"), attributes: [NSAttributedString.Key.foregroundColor: isFromCoPILOT ? UIColor.white : UIColor.black], barTintColor: UIColor(named: "BT-Primary"), tintColor: isFromCoPILOT ? UIColor.white : UIColor.black)
            menu.onDismiss = { selectedItems in
                if let selected = selectedItems.first{
                    self.fpPresentAfterDismiss {
                        if selected == FPLocalizationHelper.localize("lbl_Sort"){
                            self.displaySortingPopUp(sender)
                        }else{
                            self.displayFilterPopUp(sender)
                        }
                    }
                }
            }
            menu.cellSelectionStyle = .tickmark
            menu.show(style: .popover(sourceView: sender, size: nil, arrowDirection: .any), from: self)
        }
    }

    /// RSSelectionMenu's `onDismiss` fires as soon as `dismiss(animated:)` is called, not once the dismissal
    /// animation actually finishes, so presenting the next popover right away (or after a fixed guess-delay)
    /// can race with the in-flight dismissal and get silently dropped by UIKit. Poll until it's really gone.
    private func fpPresentAfterDismiss(attempt: Int = 0, _ block: @escaping () -> Void) {
        guard self.presentedViewController == nil else {
            guard attempt < 20 else { block(); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.fpPresentAfterDismiss(attempt: attempt + 1, block)
            }
            return
        }
        block()
    }

    func displayFilterPopUp(_ sender:UIButton){
        var arrOptions = [DropdownOptions]()
        var generateDynamically = false
        if let column = sortFilterColumn, (column.uiType == "DROPDOWN" || column.uiType == "DEFICIENCY") {
            generateDynamically = column.columnOptions?.generateDynamically ?? false
            if let options = column.columnOptions?.dropdownOptions, !options.isEmpty {
                arrOptions.append(contentsOf: options)
            } else if column.uiType == "DEFICIENCY" {
                arrOptions.append(contentsOf: [
                    DropdownOptions(key: .string(FPLocalizationHelper.localize("Yes")), value: .string(FPLocalizationHelper.localize("Yes")), label: .string(FPLocalizationHelper.localize("Yes"))),
                    DropdownOptions(key: .string(FPLocalizationHelper.localize("No")), value: .string(FPLocalizationHelper.localize("No")), label: .string(FPLocalizationHelper.localize("No"))),
                    DropdownOptions(key: .string("NA"), value: .string("NA"), label: .string("NA"))
                ])
            }
        }
        var seen = Set<String>()
        var menuFilterOptions: [String] = []
        let sourceOptions = arrOptions.compactMap { generateDynamically ? $0.label.stringValue() : $0.value.stringValue() }
        for option in sourceOptions {
            let canonical = fpCanonicalFilterOption(option)
            guard seen.insert(canonical).inserted else { continue }
            menuFilterOptions.append(option)
        }
        menuFilterOptions.append(fileterBlankOptionKey)
        let menu = RSSelectionMenu(selectionStyle: .multiple, dataSource: menuFilterOptions) { (cell, name, indexPath) in
            cell.textLabel?.text = name
            cell.tintColor = UIColor(named: "BT-Primary") ?? .blue
        }
        menu.tableView?.configureRSSelectionMenuTable()
        menu.setNavigationBar(title: FPLocalizationHelper.localize("lbl_Filter"), attributes: [NSAttributedString.Key.foregroundColor: isFromCoPILOT ? UIColor.white : UIColor.black], barTintColor: UIColor(named: "BT-Primary"), tintColor: isFromCoPILOT ? UIColor.white : UIColor.black)
        if !self.arrAppliedFilters.isEmpty{
            let leftBarButton = UIBarButtonItem(title: FPLocalizationHelper.localize("lbl_Clear"), style: .plain, target: self, action: #selector(leftBarButtonTapped))
            menu.navigationItem.leftBarButtonItem = leftBarButton
        }
        menu.setRightBarButton(title: FPLocalizationHelper.localize("Done")) { selectedItems in
            menu.dismiss(animated: true)
            if selectedItems.isEmpty{
                if self.arrAppliedFilters.filter({ $0.option == .filter}).count > 0{
                    self.clearCurrentRowFilter()
                }else if self.arrAppliedFilters.isEmpty{
                    self.resetToDefault()
                }else{}
            }
            if let sortFilterColumnIndexPath = self.sortFilterColumnIndexPath{
                let filter = SortFilter(indPath: sortFilterColumnIndexPath, option: .filter, filterItems: selectedItems)
                if let _ = self.arrAppliedFilters.firstIndex(where: { $0.indPath == sortFilterColumnIndexPath }){
                    self.applyFilterToSameColomnTable(filter: filter)
                }else{
                    self.arrAppliedFilters.append(filter)
                    self.applySortFilterToTable(option: .filter)
                }
            }
        }

        if  isSortFilterApplied == true, let index = arrAppliedFilters.firstIndex(where: { $0.indPath == sortFilterColumnIndexPath}), let appliedFilter = arrAppliedFilters[safe: index], appliedFilter.option  == .filter, let filterItems = appliedFilter.filterItems{
            menu.setSelectedItems(items: filterItems) {  (_, _, _, _) in }
        }
        menu.cellSelectionStyle = .checkbox
        menu.show(style: .popover(sourceView: sender, size: nil, arrowDirection: .any), from: self)
    }
    
    @objc func leftBarButtonTapped() {
        self.clearCurrentRowFilter()
        self.dismiss(animated: true)
    }
    
    @objc func rightBarButtonTapped() {
        self.dismiss(animated: true)
    }

    /// Produces a canonical key used only for deduplicating visually equivalent filter options.
    private func fpCanonicalFilterOption(_ value: String) -> String {
        let visible = value.handleAndDisplayApostrophe()
        let noControls = String(visible.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) })
        let collapsedWhitespace = noControls
            .replacingOccurrences(of: "\\s+", with: " ", options: String.CompareOptions.regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return collapsedWhitespace.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale.current)
    }
    
    func applySortingToTable(option:SortColumnOption, completion: @escaping (TableComponent) -> Void){
        if var tableComponent = tableComponent, let column = sortFilterColumn{
            if let sorted = sortFilteredTableComponent{
                tableComponent = sorted
            }
            tableComponent.sortData(component: tableComponent, sortOption: option, sortColumn: column) { sortedComponent in
                self.resetMultipleSeletion()
                completion(sortedComponent)
            }
        }
    }
    
    func applyFilterToTable(items:[String], completion: @escaping (TableComponent) -> Void){
        guard items.count > 0 else {
            if var tableComponent = tableComponent {
                if let sorted = sortFilteredTableComponent{
                    tableComponent = sorted
                }
                completion(tableComponent)
            }
            return
        }
        if var tableComponent = tableComponent, let column = sortFilterColumn {
            if let sorted = sortFilteredTableComponent{
                tableComponent = sorted
            }
            tableComponent.filterData(component: tableComponent, arrSelected: items, filterColumn: column) { filteredComponent in
                self.resetMultipleSeletion()
                completion(filteredComponent)
            }
        }
    }
    
    func applySortFilterToTable(option:SortColumnOption){
        if option == .filter, let index = self.arrAppliedFilters.firstIndex(where: { $0.option == .filter}), let filter  = self.arrAppliedFilters[safe: index]{
            self.applyFilterToTable(items: filter.filterItems ?? []) { filterdtbl in
                if filterdtbl.rows?.count == 0{
                    self.arrAppliedFilters.remove(at: index)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        _  = FPUtility.showAlertController(title: FPLocalizationHelper.localize("error_dialog_title"), message: FPLocalizationHelper.localize("msg_no_data"), completion: nil)
                    }
                }else{
                    self.sortFilteredTableComponent  = filterdtbl
                }
                self.refreshWithSortFilter()
            }
        }else if  option != .filter,  let index = self.arrAppliedFilters.firstIndex(where: { $0.option != .filter}) , let filter  = arrAppliedFilters[safe: index]{
            self.applySortingToTable(option: filter.option) { sortedtbl in
                self.sortFilteredTableComponent  = sortedtbl
                self.refreshWithSortFilter()
            }
        }else{
        }
        
    }
    
    func applyFilterToSameColomnTable(filter:SortFilter){
        if let index = self.arrAppliedFilters.firstIndex(where: { $0.option == .filter}){
            self.arrAppliedFilters.remove(at: index)
        }
        self.sortFilteredTableComponent = nil
        if let index = self.arrAppliedFilters.firstIndex(where: { $0.option != .filter}), let sortfilter  = arrAppliedFilters[safe: index]{
            self.applySortingToTable(option: sortfilter.option) { sortedtbl in
                self.sortFilteredTableComponent  = sortedtbl
                self.filterToSameColomnTable(filter: filter)
            }
        }else{
            self.filterToSameColomnTable(filter: filter)
        }
    }
    
    func filterToSameColomnTable(filter:SortFilter){
        self.arrAppliedFilters.append(filter)
        self.applyFilterToTable(items: filter.filterItems ?? []) { filterdtbl in
            if filterdtbl.rows?.count == 0{
                self.arrAppliedFilters.removeLast()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    _  = FPUtility.showAlertController(title: FPLocalizationHelper.localize("error_dialog_title"), message: FPLocalizationHelper.localize("msg_no_data"), completion: nil)
                }
            }else{
                self.sortFilteredTableComponent  = filterdtbl
            }
            self.refreshWithSortFilter()
        }
    }
    
    func refreshWithSortFilter(){
        DispatchQueue.main.async {
            self.isSortFilterApplied = !self.arrAppliedFilters.isEmpty
            if self.arrAppliedFilters.isEmpty {
                // resetToDefault handles setContentOffset + layout invalidation + reloadData
                self.resetToDefault()
                return
            }
            self.collectionView.setContentOffset(.zero, animated: false)
            if let layout = self.collectionView.collectionViewLayout as? FPSpreadsheetCollectionViewLayout {
                layout.invalidateDataSourceCounts()
            } else {
                self.collectionView.collectionViewLayout.invalidateLayout()
            }
            self.fp_bumpTableGeneration()
            self.collectionView.reloadData()
            self.fpReapplyTableTextSearchIfNeeded()
        }
    }
}

//MARK: TableContentCellDelegate

extension FPTableEditViewController: TableContentCellDelegate{
    func duplicateRow(at index: IndexPath, parentTableIndex: IndexPath?) {
        self.view.endEditing(true)
        DispatchQueue.main.async{
            
            _ = FPUtility.showAlertController(title: FPLocalizationHelper.localize("alert_dialog_title"), andMessage: FPLocalizationHelper.localizeWith(args: ["\(index.section)"], key: "msg_duplicate_row"), completion: nil, withPositiveAction: FPLocalizationHelper.localize("Yes"), style: .default, andHandler: { (action) in
                guard let dRow = self.fp_visibleSectionToDisplayRowIndex(index.section) else { return }
                let insertAtDisplay = dRow + 1
                if self.isSortFilterApplied, var duplicaterow = self.sortFilteredTableComponent?.rows?[safe: dRow] {
                    duplicaterow.columns.indices.forEach { colmIndex in
                        if duplicaterow.columns[colmIndex].uiType == "ATTACHMENT"{
                            duplicaterow.columns[colmIndex].value = ""
                        }
                    }
                    let newRow = self.sortFilteredTableComponent?.addDuplicateRow(columns: duplicaterow.columns, at: insertAtDisplay)
                    var insertAt = insertAtDisplay
                    if let orginalIndex = self.tableComponent?.rows?.firstIndex(where: { $0.sortUuid == duplicaterow.sortUuid }){
                        insertAt = orginalIndex + 1
                    }
                    _ = self.tableComponent?.addDuplicateRow(rowSortId: newRow?.sortUuid, columns: duplicaterow.columns, at: insertAt)
                }else{
                    if var duplicaterow = self.tableComponent?.rows?[safe: dRow]{
                        duplicaterow.columns.indices.forEach { colmIndex in
                            if duplicaterow.columns[colmIndex].uiType == "ATTACHMENT"{
                                duplicaterow.columns[colmIndex].value = ""
                            }
                        }
                        _ = self.tableComponent?.addDuplicateRow(columns: duplicaterow.columns, at: insertAtDisplay)
                    }
                }
                if let layout = self.collectionView.collectionViewLayout as? FPSpreadsheetCollectionViewLayout {
                    layout.addRow()
                    layout.invalidateLayout()
                }
                self.fpReapplyTableTextSearchIfNeeded()
                self.fp_bumpTableGeneration()
                self.collectionView.reloadData()
            }, withNegativeAction: FPLocalizationHelper.localize("Cancel"), style: .default, andHandler: nil)

        }
    }
    
    func duplicateMultipleRows(_ arrRows:[Rows]){
        self.view.endEditing(true)
        FPUtility.showHUDWithLoadingMessage()
        self.resetMultipleSeletion()
        let group = DispatchGroup()
        var arrNewRowsIndexs:[Int] = []
        for currentRow in arrRows {
            group.enter()
            var duplicaterow = currentRow
            var newRow:Rows?
            duplicaterow.columns.indices.forEach { colmIndex in
                if duplicaterow.columns[colmIndex].uiType == "ATTACHMENT"{
                    duplicaterow.columns[colmIndex].value = ""
                }
            }
            if self.isSortFilterApplied, let indexSortRow = self.sortFilteredTableComponent?.rows?.firstIndex(where: { $0.sortUuid == currentRow.sortUuid }){
                arrNewRowsIndexs.append(indexSortRow + 1)
                newRow = self.sortFilteredTableComponent?.addDuplicateRow(columns: duplicaterow.columns, at: indexSortRow + 1, isEndOfTable: self.isDuplicateRowAddedEndOFTable)
            }
            if let indexRow = self.tableComponent?.rows?.firstIndex(where: { $0.sortUuid == currentRow.sortUuid }){
                arrNewRowsIndexs.append(indexRow+1)
                _ = self.tableComponent?.addDuplicateRow(rowSortId: newRow?.sortUuid, columns: duplicaterow.columns, at: indexRow+1, isEndOfTable: self.isDuplicateRowAddedEndOFTable)
            }
            group.leave()
        }
        group.notify(queue: DispatchQueue.main) {
            if let layout = self.collectionView.collectionViewLayout as? FPSpreadsheetCollectionViewLayout{
                layout.addRow(nRow: arrRows.count)
                layout.invalidateLayout()
            }
            FPUtility.hideHUD()
            self.fp_bumpTableGeneration()
            self.collectionView.reloadData()
            if self.isDuplicateRowAddedEndOFTable{
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.collectionView.scrollToBottom(animated: true)
                }
            }
        }
        
    }
    
    
    func deleteRow(at index:IndexPath){
        self.view.endEditing(true)
        let totalRows = self.isSortFilterApplied
            ? (self.sortFilteredTableComponent?.rows?.count ?? 0)
            : (self.tableComponent?.rows?.count ?? 0)
        guard totalRows > 1 else {
            _ = FPUtility.showAlertController(title: FPLocalizationHelper.localize("error_dialog_title"), message: FPLocalizationHelper.localize("msg_tbl_atleast_need_one_row"), completion: nil)
            return
        }
        DispatchQueue.main.async{
            FPUtility.showAlertController(title: FPLocalizationHelper.localize("alert_dialog_title"), andMessage:FPLocalizationHelper.localizeWith(args: ["\(index.section)"], key: "msg_delete_row"), completion: nil, withPositiveAction: FPLocalizationHelper.localize("Yes"), style: .default, andHandler: { (action) in
                self.deleteIfAnyAssetLinking(index: index)
                let deletedFullRow = self.fp_visibleSectionToFullTableRowIndex(index.section) ?? max(0, index.section - 1)
                if self.isSortFilterApplied{
                    if let dSort = self.fp_visibleSectionToDisplayRowIndex(index.section),
                       let delrow = self.sortFilteredTableComponent?.rows?[safe: dSort],
                       let indexOfRow = self.tableComponent?.rows?.firstIndex(where: { $0.sortUuid == delrow.sortUuid }) {
                        self.tableComponent?.deleteRow(at:indexOfRow)
                        self.sortFilteredTableComponent?.deleteSortedRow(at: dSort, orginalIndex: indexOfRow)
                    }
                }else{
                    self.tableComponent?.deleteRow(at: deletedFullRow)
                }
                if let mediaIndex = FPFormDataHolder.shared.tableMediaCache.firstIndex(where: {
                    $0.childTableIndex?.section == (deletedFullRow + 1) &&
                    $0.childTableIndex?.row == index.row &&
                    $0.formSessionId == FPFormDataHolder.shared.currentFormSessionId
                }){
                    let media = FPFormDataHolder.shared.tableMediaCache[mediaIndex]
                    let medias = FPFormDataHolder.shared.tableMediaCache.filter({$0.childTableIndex!.section-1 > media.childTableIndex!.section-1})
                    medias.forEach { mmedia in
                        var mediaObj = mmedia
                        mediaObj.childTableIndex =  IndexPath(row: mmedia.childTableIndex!.row, section: mmedia.childTableIndex!.section-1)
                        FPFormDataHolder.shared.addUpdateTableMediaCache(media: mediaObj)
                    }
                    FPFormDataHolder.shared.tableMediaCache.remove(at: mediaIndex)
                }else{
                    let cache = FPFormDataHolder.shared.tableMediaCache
                    var tempIndex = 0
                    cache.forEach { media in
                        var mediaObj = media
                        if(mediaObj.childTableIndex!.section - 1) > deletedFullRow {
                            mediaObj.childTableIndex =  IndexPath(row: mediaObj.childTableIndex!.row, section: mediaObj.childTableIndex!.section-1)
                            FPFormDataHolder.shared.tableMediaCache[tempIndex] = mediaObj
                            tempIndex += 1
                        }
                    }
                }
                if let layout = self.collectionView.collectionViewLayout as? FPSpreadsheetCollectionViewLayout {
                    layout.removeRow()
                    layout.invalidateLayout()
                }
                self.fpReapplyTableTextSearchIfNeeded()
                self.fp_bumpTableGeneration()
                self.collectionView.reloadData()
            }, withNegativeAction: FPLocalizationHelper.localize("Cancel"), style: .default, andHandler: nil)

        }
    }
    
    func deleteMultipleRows(_ arrRows:[Rows]){
        self.view.endEditing(true)
        let totalRows = self.tableComponent?.rows?.count ?? 0
        guard !(totalRows == 1 && arrRows.count == 1 && !self.isSelectedAll) else {
            self.resetMultipleSeletion()
            _ = FPUtility.showAlertController(title: FPLocalizationHelper.localize("error_dialog_title"), message: FPLocalizationHelper.localize("msg_tbl_atleast_need_one_row"), completion: nil)
            return
        }
        FPUtility.showHUDWithLoadingMessage()
        let hasActiveSearch = !(self.fpTableSearchBar?.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        if self.isSelectedAll || arrRows.count >= totalRows {
            self.addEmptyRowToTable()
        }
        self.resetMultipleSeletion()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var assetRowIds = [String]()
            var assetRowLocalIds = [String]()
            
            for currentRow in arrRows {
                if let indexOfRow = self.tableComponent?.rows?.firstIndex(where: { $0.sortUuid == currentRow.sortUuid }){
                    
                    if self.isSortFilterApplied {
                        if let indexSRow = self.sortFilteredTableComponent?.rows?.firstIndex(where: { $0.sortUuid == currentRow.sortUuid }){
                            self.sortFilteredTableComponent?.deleteSortedRow(at: indexSRow, orginalIndex: indexOfRow)
                        }
                    }
                    
                    if let dictvalue = self.tableComponent?.values?[safe:indexOfRow]{
                        for (key, value) in dictvalue {
                            if key == "__id__", let id = value as? String {
                                assetRowIds.append(id)
                            } else if key == "__localId__", let lid = value as? String {
                                assetRowLocalIds.append(lid)
                            }
                        }
                    }
                    self.tableComponent?.deleteRow(at:indexOfRow)
                }
            }
            
            // Perform batch database update for asset linkings
            if self.isAssetEnabled, let isAssetTable = self.tableComponent?.tableOptions?.isAssetTable, isAssetTable {
                AssetFormLinkingDatabaseManager().batchUpsertDeleteAssetLinking(
                    assetRowIds: assetRowIds, 
                    assetRowLocalIds: assetRowLocalIds, 
                    fieldTemplateId: self.fieldDetails?.templateId ?? "0", 
                    form: FPFormDataHolder.shared.customForm
                )
            }
            
            DispatchQueue.main.async {
                if let layout = self.collectionView.collectionViewLayout as? FPSpreadsheetCollectionViewLayout {
                    if hasActiveSearch {
                        layout.isNew = true
                    } else {
                        layout.removeRow(nRow: arrRows.count)
                        layout.invalidateLayout()
                    }
                }
                
                if hasActiveSearch {
                    self.fpApplyTableTextSearchFromField(animated: false)
                } else {
                    self.fp_bumpTableGeneration()
                    self.collectionView.reloadData()
                }
                self.collectionView.layoutIfNeeded()
                FPUtility.hideHUD()
            }
        }
    }
    
    func updateData(at index:IndexPath, with data:ColumnData, filedData filed:FPFieldDetails?){
        // Invalidate cached row columns so reloadItems/reloadSections picks up the new value,
        // not stale ColumnData from the per-row filter cache.
        viewModel?.invalidateColumnCache()
        guard let dRow = fp_visibleSectionToDisplayRowIndex(index.section) else { return }
        if isSortFilterApplied, let sortCompnt = sortFilteredTableComponent{
            if var row = sortCompnt.rows?[safe:dRow]{
                if let columnIndex = row.columns.firstIndex(where: {$0.key == data.key}){
                    row.columns[columnIndex] = data
                    sortCompnt.rows?[dRow] = row
                    sortFilteredTableComponent = sortCompnt
                }
            }
            if var updateRow =  sortCompnt.rows?[safe:dRow], let indexOfRow = self.tableComponent?.rows?.firstIndex(where: { $0.sortUuid == updateRow.sortUuid }){
                if isAutoCalculateEnabled, data.isPartOfFormula == true{
                    updateRow = self.processAutoCalculationFor(row: updateRow, with: data)
                }
                self.tableComponent?.rows?.remove(at: indexOfRow)
                self.tableComponent?.rows?.insert(updateRow, at: indexOfRow)
            }
            fp_reloadCellOrSectionSafely(at: index, isFormulaUpdate: isAutoCalculateEnabled && data.isPartOfFormula == true)
        }else if let tblCompnt = tableComponent, let _ = tableIndexPath{
            if var row = tblCompnt.rows?[safe:dRow]{
                if let columnIndex = row.columns.firstIndex(where: {$0.key == data.key}){
                    row.columns[columnIndex] = data
                    tblCompnt.rows?[dRow] = row
                    tableComponent = tblCompnt
                    if isAutoCalculateEnabled, data.isPartOfFormula == true, let indexOfRow = self.tableComponent?.rows?.firstIndex(where: { $0.sortUuid == row.sortUuid }){
                        let autoCalRow = self.processAutoCalculationFor(row: row, with: data)
                        self.tableComponent?.rows?.remove(at: indexOfRow)
                        self.tableComponent?.rows?.insert(autoCalRow, at: indexOfRow)
                    }
                }
            }
            fp_reloadCellOrSectionSafely(at: index, isFormulaUpdate: isAutoCalculateEnabled && data.isPartOfFormula == true)
        }
        fp_triggerFirstSaveIfNeeded()
    }
    
    func inferValue(_ value: String) -> Any {
        let replaced = value.replacingOccurrences(of: "__X2E__", with: ".")
        let trimmed = replaced.trimmingCharacters(in: .whitespacesAndNewlines)
        if let number = Double(trimmed) {
            return number
        }
        return trimmed
    }
    
    func processAutoCalculationFor(row: Rows, with data:ColumnData) -> Rows{
        var updatedRow = row
        for formula in arrTblFormulas {
            var orginalExpression = formula.expression ?? ""
            var rawVars: [String: Any] = [:]
            for column in updatedRow.columns {
                if orginalExpression.range(of: "\\b\(column.key)\\b", options: .regularExpression) != nil {
                    rawVars[column.key] = self.inferValue(column.value)
                }
            }
            if let columnIndex = row.columns.firstIndex(where: {$0.key == formula.name}){
                debugPrint("formula: \(orginalExpression)")
                debugPrint("variables: \(rawVars)")
                do {
                    let value = try ZTExpressionEngine.evaluate(orginalExpression, variables: rawVars)
                    debugPrint("result: \(value)")
                    if let dbvalue = value as? Double{
                        updatedRow.columns[columnIndex].value = dbvalue.formattedMax2Decimal()
//                        updatedRow.columns[columnIndex].value = String(format: "%.2f", dbvalue)
                    }else if let strVal = value as? String{
                        updatedRow.columns[columnIndex].value = strVal
                    }else{
                        updatedRow.columns[columnIndex].value = "-"
                    }
                } catch {
                    debugPrint(error)
                }
            }
        }
        return updatedRow
    }

    private func fp_reloadCellOrSectionSafely(at index: IndexPath, isFormulaUpdate: Bool) {
        let generationAtSchedule = fp_tableDataGeneration

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard self.collectionView.window != nil else { return }

            let scheduleCoalescedFullReload: (TimeInterval) -> Void = { delay in
                self.fp_pendingCollectionReloadWorkItem?.cancel()
                // Bump generation immediately so any in-flight fp_reloadCellOrSectionSafely
                // closures that haven't run yet will detect the stale generation and bail.
                self.fp_bumpTableGeneration()
                let workItem = DispatchWorkItem { [weak self] in
                    guard let self = self else { return }
                    guard self.collectionView.window != nil else { return }
                    self.collectionView.reloadData()
                }
                self.fp_pendingCollectionReloadWorkItem = workItem

                if delay <= 0 {
                    DispatchQueue.main.async(execute: workItem)
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
                }
            }

            guard generationAtSchedule == self.fp_tableDataGeneration else {
                scheduleCoalescedFullReload(0)
                return
            }

            let sectionCount = self.collectionView.numberOfSections
            guard index.section >= 0, index.section < sectionCount else {
                scheduleCoalescedFullReload(0)
                return
            }

            // Guard against data source section count diverging from the collection view's
            // cached count (can happen when the model is mutated before reloadData runs).
            // reloadItems would crash with Invalid_Number_Of_Sections in that case.
            let dataSourceSections = self.collectionView.dataSource?.numberOfSections?(in: self.collectionView) ?? sectionCount
            guard dataSourceSections == sectionCount else {
                scheduleCoalescedFullReload(0)
                return
            }

            // Same guard, one level down: the section count can match while this section's
            // own item/column count has diverged (e.g. a conditional column's visibility
            // changed). reloadItems would then crash with Invalid_Number_Of_Items instead.
            let itemCount = self.collectionView.numberOfItems(inSection: index.section)
            let dataSourceItems = self.collectionView.dataSource?.collectionView(self.collectionView, numberOfItemsInSection: index.section) ?? itemCount
            guard dataSourceItems == itemCount else {
                scheduleCoalescedFullReload(0)
                return
            }

            if isFormulaUpdate {
                let visibleInSection = self.collectionView.indexPathsForVisibleItems.filter { $0.section == index.section }
                if !visibleInSection.isEmpty {
                    self.collectionView.reloadItems(at: visibleInSection)
                }
                scheduleCoalescedFullReload(0.15)
                return
            }

            guard index.item >= 0, index.item < itemCount else {
                scheduleCoalescedFullReload(0)
                return
            }

            // Keep keyboard focus stable when navigating between editable cells.
            // Reloading the currently edited item during responder handoff can dismiss the keyboard,
            // so for non-formula updates we update the backing model only and skip UI reload.
            return
        }
    }
    
    func showAddAttachment(at index:IndexPath,with data:ColumnData){
        self.view.endEditing(true)
        self.attachmentIndex = index
        self.attachmentColumnData = data
        let attachmentView =  TableAttachementView.instance
        attachmentView.parentViewController = self
        attachmentView.delegate = self
        attachmentView.attachmentValue = data.value
        attachmentView.sectionIndexForCapCheck = tableIndexPath?.section ?? 0
        attachmentView.showAttachmentPicker()
    }
    
    func showBarcodeScanner(at index:IndexPath,with data:ColumnData){
        self.linkAsset(at: index, parentTableIndex: tableIndexPath)
    }
    
}

extension UIScrollView {
    func scrollToBottom(animated: Bool) {
        let y = contentSize.height - 1
        let rect = CGRect(x: 0, y: y + safeAreaInsets.bottom, width: 1, height: 1)
        scrollRectToVisible(rect, animated: animated)
    }
}


//MARK: Attachment picker delegate
extension FPTableEditViewController: AttachmentPickerDelegate{
    func onMediaSave(mediaAdded: [SSMedia], mediaDeleted: [SSMedia]) {
        if let index = attachmentIndex,let data = attachmentColumnData{
            let dAttach = fp_visibleSectionToDisplayRowIndex(index.section)
            if isSortFilterApplied, let sortCompnt = sortFilteredTableComponent, let dRow = dAttach, let attachrow = sortCompnt.rows?[dRow], let tblRowIndex = self.tableComponent?.rows?.firstIndex(where: { $0.sortUuid == attachrow.sortUuid }){
                let currentMainTblRow = self.tableComponent?.rows?[safe:tblRowIndex]
                let attachIndexPath  = IndexPath(row: index.row, section: tblRowIndex + 1)
                let tableMedia = TableMedia(columnIndex: attachIndexPath.row, key: data.key, parentTableIndex:tableIndexPath!, childTableIndex: attachIndexPath, mediaAdded: mediaAdded.filter({$0.id?.isEmpty ?? true}), mediaDeleted: mediaDeleted, formSessionId: FPFormDataHolder.shared.currentFormSessionId)
                FPFormDataHolder.shared.addUpdateTableMediaCache(media: tableMedia)
                let result =  FPFormDataHolder.shared.getValueFromTableMedia(tableMedia: tableMedia, tableValues: tableComponent?.values)
                if let component  = tableComponent{
                    component.values = result?.valueArray ?? []
                    var row = component.rows![tableMedia.childTableIndex!.section -  1]
                    if let columnIndex = row.columns.firstIndex(where: {$0.key == tableMedia.key}){
                        var column  = row.columns[columnIndex]
                        if let currentColumn = currentMainTblRow?.columns[safe:columnIndex], currentColumn.uiType == "ATTACHMENT", currentColumn.value.trim.isEmpty {
                            var mediaDict:[String:Any] = [:]
                            mediaDict["files"] = []
                            if let dictValue = result?.columnValue.getDictonary(){
                                mediaDict["filesToUpload"] = dictValue["filesToUpload"]
                                mediaDict["filesToDelete"] = dictValue["filesToDelete"]
                            }
                            column.value = mediaDict.getJson()
                        }else{
                            column.value = result?.columnValue ?? ""
                        }
                        row.columns[columnIndex] = column
                    }
                    component.rows![tableMedia.childTableIndex!.section-1] = row
                    self.tableComponent = component
                    if let indexOfRow = self.sortFilteredTableComponent?.rows?.firstIndex(where: { $0.sortUuid == attachrow.sortUuid }){
                        self.sortFilteredTableComponent?.rows?.remove(at: indexOfRow)
                        self.sortFilteredTableComponent?.rows?.insert(row, at: indexOfRow)
                    }
                }
            }else if let fullR = fp_visibleSectionToFullTableRowIndex(index.section) {
                let childIdx = IndexPath(row: index.row, section: fullR + 1)
                let tableMedia = TableMedia(columnIndex: index.row, key: data.key, parentTableIndex:tableIndexPath!, childTableIndex: childIdx, mediaAdded: mediaAdded.filter({$0.id?.isEmpty ?? true}), mediaDeleted: mediaDeleted, formSessionId: FPFormDataHolder.shared.currentFormSessionId)
                FPFormDataHolder.shared.addUpdateTableMediaCache(media: tableMedia)
                let result =  FPFormDataHolder.shared.getValueFromTableMedia(tableMedia: tableMedia, tableValues: tableComponent?.values)
                if let component  = tableComponent{
                    component.values = result?.valueArray ?? []
                    var row = component.rows![fullR]
                    if let columnIndex = row.columns.firstIndex(where: {$0.key == tableMedia.key}){
                        var column  = row.columns[columnIndex]
                        column.value = result?.columnValue ?? ""
                        row.columns[columnIndex] = column
                    }
                    component.rows![fullR] = row
                    self.tableComponent = component
                }
            }
            self.fp_bumpTableGeneration()
            self.collectionView.reloadData()
            fp_performAutoSave()
            fp_hasFirstChangeSaved = false
        }
    }

}

protocol FPTableEditViewControllerDelegate{
    
    func didEditTableData()
}

//MARK: Asset Linking

extension FPTableEditViewController{
 
    func linkAsset(at index: IndexPath, parentTableIndex: IndexPath?) {
        self.view.endEditing(true)
        self.resetMultipleSeletion()
        var assetRow: Rows?
        var assetRowLocalId: String?
        var assetRowId: String?
        var dictValue: [String:Any]?
        if self.isSortFilterApplied, let dRow = fp_visibleSectionToDisplayRowIndex(index.section), let currentRow = self.sortFilteredTableComponent?.rows?[safe:dRow]{
            assetRow = currentRow
            if let indexCRow = self.tableComponent?.rows?.firstIndex(where: { $0.sortUuid == currentRow.sortUuid }){
                dictValue = self.tableComponent?.values?[safe:indexCRow]
            }
        }else if let dRow = fp_visibleSectionToDisplayRowIndex(index.section) {
            assetRow = self.tableComponent?.rows?[safe:dRow]
            dictValue = self.tableComponent?.values?[safe:dRow]
        }
        
        if let dictvalue = dictValue{
            for (key, value) in dictvalue {
                if key == "__id__"{
                    assetRowId = value as? String
                }else if key == "__localId__"{
                    assetRowLocalId = value as? String
                }
            }
        }
        
        var showAssetLinkedError = false
        if let assetIdColumIndex = assetRow?.columns.firstIndex(where: {(($0.getUIType() == .HIDDEN) && ($0.key.lowercased() == hiddenAssetIdColumnKey.lowercased()))}), let currentOne =  assetRow?.columns[safe:assetIdColumIndex]{
            showAssetLinkedError = !currentOne.value.isEmpty
        }

        if let _ =  AssetFormLinkingDatabaseManager().fetchAssetLinkigDataFor(fieldTemplateId: self.fieldDetails?.templateId ?? "", rowId: assetRowId, rowLocalId: assetRowLocalId, customForm: FPFormDataHolder.shared.customForm).first{
            showAssetLinkedError = true
        }
        
        if showAssetLinkedError{
            DispatchQueue.main.async{
                _ = FPUtility.showAlertController(title: FPLocalizationHelper.localize("alert_dialog_title"), andMessage: FPLocalizationHelper.localize("msg_asset_already_linked_row"), completion: nil, withPositiveAction: FPLocalizationHelper.localize("Yes"), style: .default, andHandler: { (action) in
                    self.assetLinkIndexPath = index
                    self.fpFormViewController?.linkingDelegate?.openBarcodeScanner(isOverWriteAsset: true, baseVc: self, linkedAssets: self.linkedAssets, fieldTemplateId: self.fieldDetails?.templateId)
                }, withNegativeAction: FPLocalizationHelper.localize("Cancel"), style: .default, andHandler: { cancel in
                    self.clearAssetLinkingIndex()
                })
            }
        }else{
            self.continueAssetLinkProcedure(index: index, parentTableIndex: parentTableIndex)
        }
    }
    
    func continueAssetLinkProcedure( index: IndexPath, parentTableIndex: IndexPath?){
        DispatchQueue.main.async{
            _ = FPUtility.showAlertController(title: FPLocalizationHelper.localize("alert_dialog_title"), andMessage: FPLocalizationHelper.localize("msg_link_asset_row_confm"), completion: nil, withPositiveAction: FPLocalizationHelper.localize("Yes"), style: .default, andHandler: { (action) in
                self.assetLinkIndexPath = index
                self.fpFormViewController?.linkingDelegate?.openBarcodeScanner(isOverWriteAsset: false, baseVc: self, linkedAssets: self.linkedAssets, fieldTemplateId: self.fieldDetails?.templateId)
            }, withNegativeAction: FPLocalizationHelper.localize("Cancel"), style: .default, andHandler: { cancel in
                self.clearAssetLinkingIndex()
            })
        }
    }
    
    func proceedWithAssetFormLinking(assetData:AssetInspectionData, isScannedResult:Bool, fieldTemplateId: String?){
        if let assetLinkIndexPath = assetLinkIndexPath, self.fieldDetails?.templateId == fieldTemplateId{
            self.resetMultipleSeletion()
            if isScannedResult, !self.linkedAssets.isEmpty{
                var showError = false
                if let assetId = assetData.assetObjectId{
                    //assetId
                    let arrIds = self.linkedAssets.compactMap { $0["assetId"]}
                    if arrIds.contains(assetId){
                        showError = true
                    }
                }else if let assetLocalId = assetData.assetLocalId{
                    //assetLocalId
                    let arrLocalIds = self.linkedAssets.compactMap { $0["assetLocalId"]}
                    if arrLocalIds.contains(assetLocalId){
                        showError = true
                    }
                }
                
                if showError{
                    self.fp_bumpTableGeneration()
                    self.collectionView.reloadData()
                    if let topVc = FPUtility.topViewController(), !topVc.isKind(of: UIAlertController.self){
                        _  = FPUtility.showAlertController(title: FPLocalizationHelper.localize("error_dialog_title"), message: FPLocalizationHelper.localize("msg_asset_already_linked_form"), completion: nil)
                    }
                    return
                }
            }
            
            var assetRow: Rows?
            var assetRowLocalId: String?
            var assetRowId: String?
            var dictValue: [String:Any]?

            if self.isSortFilterApplied, let dRow = fp_visibleSectionToDisplayRowIndex(assetLinkIndexPath.section), let currentRow = self.sortFilteredTableComponent?.rows?[safe:dRow]{
                assetRow = currentRow
                if let indexCRow = self.tableComponent?.rows?.firstIndex(where: { $0.sortUuid == currentRow.sortUuid }){
                    dictValue = self.tableComponent?.values?[safe:indexCRow]
                }
            }else if let dRow = fp_visibleSectionToDisplayRowIndex(assetLinkIndexPath.section) {
                assetRow = self.tableComponent?.rows?[safe:dRow]
                dictValue = self.tableComponent?.values?[safe:dRow]
            }
            if let dictvalue = dictValue{
                for (key, value) in dictvalue {
                    if key == "__id__"{
                        assetRowId = value as? String
                    }else if key == "__localId__"{
                        assetRowLocalId = value as? String
                    }
                }
            }
            
            if assetData.isOverWriteAsset{
                self.upsertDeleteAssetLinking(assetRowId: assetRowId, assetRowLocalId: assetRowLocalId)
            }
            if let dictMapping = self.tableComponent?.tableOptions?.assetMapping{
                FPUtility.showHUDWithLoadingMessage()
                dictMapping.forEach { dictkey, dictvalue in
                    if let assetfields = assetData.assetSection?.fields, let assetField = assetfields.filter({ $0.name?.lowercased() == dictvalue.lowercased()}).first{
                        if let mappingColoumnIndex = assetRow?.columns.firstIndex(where: { $0.key.lowercased() == dictkey.lowercased()}){
                            if let currentOne =  assetRow?.columns[safe:mappingColoumnIndex]{
                                if assetField.getUIType() == .DROPDOWN{
                                    let options = assetField.getDropdownOptions()
                                    if let indexItm = options.map({ $0.value}).firstIndex(of: assetField.value ?? "0"), let selected = options[safe: indexItm]{
                                        assetRow?.columns[mappingColoumnIndex].value = selected.label ?? currentOne.value
                                    }
                                }else{
                                    assetRow?.columns[mappingColoumnIndex].value = assetField.value ?? currentOne.value
                                }
                                self.updateData(at: assetLinkIndexPath, with: assetRow!.columns[mappingColoumnIndex], filedData: nil)
                            }
                        }
                    }
                }
                if let assetId = assetData.assetObjectId {
                    if let assetIdColumIndex = assetRow?.columns.firstIndex(where: {(($0.getUIType() == .HIDDEN) && ($0.key.lowercased() == hiddenAssetIdColumnKey.lowercased()))}){
                        if let currentOne =  assetRow?.columns[safe:assetIdColumIndex]{
                            assetRow?.columns[assetIdColumIndex].value = assetId.stringValue
                            self.updateData(at: assetLinkIndexPath, with: assetRow!.columns[assetIdColumIndex], filedData: nil)
                        }
                    }
                }
                upsertAddAssetLinkIntoDB(assetData:assetData, rowLocalId: assetRowLocalId, rowId: assetRowId)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    self.fp_bumpTableGeneration()
                    self.collectionView.reloadData()
                    FPUtility.hideHUD()
                }
            }
        }
    }
    
    func upsertAddAssetLinkIntoDB(assetData:AssetInspectionData, rowLocalId:String?, rowId:String?){
        let data = AssetFormMappingData()
        data.assetId = assetData.assetObjectId
        data.assetLocalId = assetData.assetLocalId
        data.isAssetSynced = assetData.isAssetSyncedToServer
        data.customFormId = FPUtility.getNumberValue(FPFormDataHolder.shared.customForm?.objectId)
        data.customFormLocalId = FPFormDataHolder.shared.customForm?.sqliteId ?? 0
        data.formTemplateId = FPFormDataHolder.shared.customForm?.templateId ?? "0"
        data.fieldTemplateId =  fieldDetails?.templateId ?? "0"
        data.sectionTemplateId =  sectionDetails?.templateId ?? "0"
        data.tableRowLocalId  = rowLocalId ?? "0"
        data.tableRowId  = rowId
        data.isSyncedToServer = false
        data.sectionLinking = false
        data.addLinking = true
        data.deleteLinking = false
        data.isNotConfirmed = true
        if FPFormDataHolder.shared.customForm?.sqliteId == nil{
            FPFormDataHolder.shared.arrLinkingDB.append(data)
        }else{
            AssetFormLinkingDatabaseManager().upsert(item: data, isAddLinking: true) { success in }
        }
    }
    

    
    func deleteIfAnyAssetLinking(index:IndexPath){
        let component = self.isSortFilterApplied ? self.sortFilteredTableComponent : self.tableComponent
        var assetRowLocalId: String?
        var assetRowId: String?
        var dictValue: [String:Any]?

        if self.isSortFilterApplied, let dRow = fp_visibleSectionToDisplayRowIndex(index.section), let currentRow = self.sortFilteredTableComponent?.rows?[safe:dRow], let indexCRow = self.tableComponent?.rows?.firstIndex(where: { $0.sortUuid == currentRow.sortUuid }) {
            dictValue = self.tableComponent?.values?[safe:indexCRow]
        }else if let dRow = fp_visibleSectionToDisplayRowIndex(index.section) {
            dictValue = self.tableComponent?.values?[safe:dRow]
        }
        if let dictvalue = dictValue{
            for (key, value) in dictvalue {
                if key == "__id__"{
                    assetRowId = value as? String
                }else if key == "__localId__"{
                    assetRowLocalId = value as? String
                }
            }
        }
        self.upsertDeleteAssetLinking(assetRowId: assetRowId, assetRowLocalId: assetRowLocalId)
    }
    
    
    func upsertDeleteAssetLinking(assetRowId:String?, assetRowLocalId:String?){
        if self.isAssetEnabled, let isAssetTable = self.tableComponent?.tableOptions?.isAssetTable, isAssetTable{
            if let alreadyLinked =  AssetFormLinkingDatabaseManager().fetchAssetLinkigDataFor(fieldTemplateId: self.fieldDetails?.templateId ?? "", rowId: assetRowId, rowLocalId: assetRowLocalId, customForm: FPFormDataHolder.shared.customForm, isAddLinking: true).first{
                if alreadyLinked.isSyncedToServer{
                    let updated = alreadyLinked
                    updated.deleteLinking = true
                    updated.addLinking = false
                    updated.isSyncedToServer = false
                    updated.isNotConfirmed = false
                    AssetFormLinkingDatabaseManager().upsert(item: updated) { success in }
                }else{
                    AssetFormLinkingDatabaseManager().deleteMapping(fieldTemplateId: fieldDetails?.templateId ?? "0", rowLocalId: assetRowLocalId, rowId: assetRowId, form: FPFormDataHolder.shared.customForm) { success in }
                }
            }
        }
    }
}

private extension FPTableEditViewController {

    func fp_visibleSectionToDisplayRowIndex(_ section: Int) -> Int? {
        guard section >= 1 else { return nil }
        if let map = viewModel?.textSearchVisibleRowIndices {
            let i = section - 1
            guard i >= 0, i < map.count else { return nil }
            return map[i]
        }
        let count = (isSortFilterApplied ? sortFilteredTableComponent?.rows?.count : tableComponent?.rows?.count) ?? 0
        let r = section - 1
        guard r >= 0, r < count else { return nil }
        return r
    }

    func fp_visibleSectionToFullTableRowIndex(_ section: Int) -> Int? {
        guard let d = fp_visibleSectionToDisplayRowIndex(section) else { return nil }
        let rowCount = tableComponent?.rows?.count ?? 0
        if isSortFilterApplied {
            guard let filteredRow = sortFilteredTableComponent?.rows?[d],
                  let indexInFull = tableComponent?.rows?.firstIndex(where: { $0.sortUuid == filteredRow.sortUuid }),
                  indexInFull >= 0, indexInFull < rowCount else {
                return nil
            }
            return indexInFull
        }
        guard d >= 0, d < rowCount else { return nil }
        return d
    }

    func fpRestoreTableSearchColumnPrefs() {
        if let saved = UserDefaults.standard.array(forKey: fpTableSearchColumnPrefsKey) as? [String] {
            fpTableSearchColumnNameKeys = Set(saved)
        }
    }

    func fpPersistTableSearchColumnPrefs() {
        UserDefaults.standard.set(Array(fpTableSearchColumnNameKeys), forKey: fpTableSearchColumnPrefsKey)
    }

    func fpInstallTableSearchChrome() {
        guard let stack = collectionView.superview?.superview as? UIStackView else { return }
        let searchBar = UISearchBar()
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.placeholder = FPLocalizationHelper.localize("lbl_table_search_placeholder")
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self
        searchBar.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        searchBar.accessibilityLabel = FPLocalizationHelper.localize("lbl_table_search_bar_a11y")
        searchBar.searchTextField.accessibilityLabel = FPLocalizationHelper.localize("lbl_table_search_bar_a11y")
        let filterBtn = UIButton(type: .system)
        filterBtn.setImage(UIImage(systemName: "line.3.horizontal.decrease.circle"), for: .normal)
        filterBtn.tintColor = UIColor(named: "BT-Primary") ?? .systemBlue
        filterBtn.translatesAutoresizingMaskIntoConstraints = false
        filterBtn.widthAnchor.constraint(equalToConstant: 44).isActive = true
        filterBtn.heightAnchor.constraint(equalToConstant: 44).isActive = true
        filterBtn.accessibilityLabel = FPLocalizationHelper.localize("lbl_table_search_columns")
        filterBtn.accessibilityHint = FPLocalizationHelper.localize("lbl_table_search_filter_hint")
        filterBtn.addAction(UIAction { [weak self] _ in
            self?.fpPresentTableSearchColumnPicker(from: filterBtn)
        }, for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [searchBar, filterBtn])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 4
        row.translatesAutoresizingMaskIntoConstraints = false

        let emptyLabel = UILabel()
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.font = .preferredFont(forTextStyle: .subheadline)
        emptyLabel.textColor = .systemRed
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.text = FPLocalizationHelper.localize("msg_table_search_no_results")
        emptyLabel.accessibilityLabel = FPLocalizationHelper.localize("msg_table_search_no_results")
        emptyLabel.isHidden = true

        let outer = UIStackView(arrangedSubviews: [row, emptyLabel])
        outer.axis = .vertical
        outer.spacing = 6
        outer.translatesAutoresizingMaskIntoConstraints = false
        stack.insertArrangedSubview(outer, at: 0)

        fpTableSearchBar = searchBar
        fpTableSearchFilterButton = filterBtn
        fpTableSearchEmptyLabel = emptyLabel
        fpUpdateTableSearchFilterButtonAppearance()
    }

    /// True when search is limited to a strict subset of visible (non-hidden) columns.
    private func fpTableSearchColumnScopeIsRestricted() -> Bool {
        let cols = tableComponent?.tableOptions?.columns?.filter { $0.uiType != "HIDDEN" } ?? []
        guard !cols.isEmpty else { return false }
        if fpTableSearchColumnNameKeys.isEmpty { return false }
        return fpTableSearchColumnNameKeys.count < cols.count
    }

    private func fpUpdateTableSearchFilterButtonAppearance() {
        guard let btn = fpTableSearchFilterButton else { return }
        let primary = UIColor(named: "BT-Primary") ?? .systemBlue
        let restricted = fpTableSearchColumnScopeIsRestricted()
        let symbol = restricted ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
        btn.setImage(UIImage(systemName: symbol), for: .normal)
        btn.tintColor = primary
        btn.accessibilityHint = FPLocalizationHelper.localize("lbl_table_search_filter_hint")
        btn.accessibilityTraits = restricted ? [.button, .selected] : .button
        if restricted {
            let cols = tableComponent?.tableOptions?.columns?.filter { $0.uiType != "HIDDEN" } ?? []
            let n = min(fpTableSearchColumnNameKeys.count, cols.count)
            btn.accessibilityValue = String.localizedStringWithFormat(
                FPLocalizationHelper.localize("msg_table_search_scope_active_a11y"),
                n,
                cols.count
            )
        } else {
            btn.accessibilityValue = FPLocalizationHelper.localize("msg_table_search_scope_all_a11y")
        }
    }

    func fpPresentTableSearchColumnPicker(from sender: UIView) {
        view.endEditing(true)
        let cols = tableComponent?.tableOptions?.columns?.filter { $0.uiType != "HIDDEN" } ?? []
        guard !cols.isEmpty else { return }
        let labels: [String] = cols.map {
            ($0.displayName.isEmpty ? $0.name : $0.displayName).handleAndDisplayApostrophe()
        }
        var nameByLabel: [String: String] = [:]
        for (i, col) in cols.enumerated() {
            let label = labels[i]
            if nameByLabel[label] == nil {
                nameByLabel[label] = col.name
            }
        }
        let menu = RSSelectionMenu(selectionStyle: .multiple, dataSource: labels) { cell, name, _ in
            cell.textLabel?.text = name
            cell.tintColor = UIColor(named: "BT-Primary") ?? .systemBlue
        }
        menu.tableView?.configureRSSelectionMenuTable()
        menu.setNavigationBar(title: FPLocalizationHelper.localize("lbl_table_search_columns"), attributes: [NSAttributedString.Key.foregroundColor: isFromCoPILOT ? UIColor.white : UIColor.black], barTintColor: UIColor(named: "BT-Primary"), tintColor: isFromCoPILOT ? UIColor.white : UIColor.black)

        let preselected: [String]
        if fpTableSearchColumnNameKeys.isEmpty {
            preselected = labels
        } else {
            preselected = cols.filter { fpTableSearchColumnNameKeys.contains($0.name) }.map {
                ($0.displayName.isEmpty ? $0.name : $0.displayName).handleAndDisplayApostrophe()
            }
        }
        let allSelected = (fpTableSearchColumnNameKeys.isEmpty || fpTableSearchColumnNameKeys.count == cols.count)
        menu.addFirstRowAs(rowType: .all, showSelected: allSelected) { [weak menu] _, selected in
            guard let menu = menu else { return }
            if selected {
                menu.setSelectedItems(items: labels) { _, _, _, _ in }
                menu.tableView?.reloadData()
            }
        }
        menu.setSelectedItems(items: preselected) { _, _, _, _ in }

        menu.setRightBarButton(title: FPLocalizationHelper.localize("Done")) { selectedItems in
            if selectedItems.isEmpty {
                _ = FPUtility.showAlertController(
                    title: FPLocalizationHelper.localize("error_dialog_title"),
                    message: FPLocalizationHelper.localize("msg_select_at_least_one_column"),
                    completion: nil
                )
                return
            }
            menu.dismiss(animated: true)
            var keys = Set<String>()
            for item in selectedItems {
                if let n = nameByLabel[item] {
                    keys.insert(n)
                }
            }
            self.fpTableSearchColumnNameKeys = keys
            self.fpUpdateTableSearchFilterButtonAppearance()
            self.fpApplyTableTextSearchFromField(animated: true)
        }
        menu.cellSelectionStyle = .checkbox
        menu.show(style: .popover(sourceView: sender, size: nil, arrowDirection: .any), from: self)
    }

    func fpApplyTableTextSearchFromField(animated: Bool) {
        let raw = fpTableSearchBar?.text ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let rows = getTableComponent()?.rows ?? []
        if trimmed.isEmpty {
            viewModel?.textSearchVisibleRowIndices = nil
            fpTableSearchHighlightQuery = ""
            fpTableSearchEmptyLabel?.isHidden = true
            fpTableSearchBar?.searchTextField.backgroundColor = nil
            fpTableSearchBar?.searchTextField.textColor = .label
        } else {
            let indices = TableRowTextSearch.matchingRowIndices(
                rows: rows,
                query: trimmed,
                columnKeys: fpTableSearchColumnNameKeys,
                caseSensitive: TableRowTextSearch.userPrefersCaseSensitiveSearch
            )
            viewModel?.textSearchVisibleRowIndices = indices
            fpTableSearchHighlightQuery = trimmed
            let noResults = indices.isEmpty
            fpTableSearchEmptyLabel?.isHidden = true
            let primary = UIColor(named: "BT-Primary") ?? .systemBlue
            if noResults {
                fpTableSearchBar?.searchTextField.backgroundColor = UIColor.systemRed.withAlphaComponent(0.08)
                fpTableSearchBar?.searchTextField.textColor = .systemRed
            } else {
                fpTableSearchBar?.searchTextField.backgroundColor = primary.withAlphaComponent(0.1)
                fpTableSearchBar?.searchTextField.textColor = .label
            }
        }
        resetMultipleSeletion()
        collectionView.setContentOffset(.zero, animated: false)
        if let layout = collectionView.collectionViewLayout as? FPSpreadsheetCollectionViewLayout {
            layout.invalidateDataSourceCounts()
        } else {
            collectionView.collectionViewLayout.invalidateLayout()
        }
        if animated {
            UIView.transition(with: collectionView, duration: 0.12, options: .transitionCrossDissolve) {
                self.fp_bumpTableGeneration()
                self.collectionView.reloadData()
            }
        } else {
            fp_bumpTableGeneration()
            collectionView.reloadData()
        }
    }

    func fpReapplyTableTextSearchIfNeeded() {
        guard let raw = fpTableSearchBar?.text, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            viewModel?.textSearchVisibleRowIndices = nil
            fpTableSearchHighlightQuery = ""
            fpTableSearchEmptyLabel?.isHidden = true
            fpTableSearchBar?.searchTextField.backgroundColor = nil
            fpTableSearchBar?.searchTextField.textColor = .label
            return
        }
        fpApplyTableTextSearchFromField(animated: false)
    }

    func fpScheduleTableSearchDebounce(for searchText: String) {
        fpTableSearchDebounceWorkItem?.cancel()
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed.count <= 2 {
            fpApplyTableTextSearchFromField(animated: true)
            return
        }
        let item = DispatchWorkItem { [weak self] in
            self?.fpApplyTableTextSearchFromField(animated: true)
        }
        fpTableSearchDebounceWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: item)
    }
}

extension FPTableEditViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        guard searchBar === fpTableSearchBar else { return }
        fpScheduleTableSearchDebounce(for: searchText)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        fpTableSearchDebounceWorkItem?.cancel()
        fpApplyTableTextSearchFromField(animated: true)
    }
}

// MARK: - Auto-Save

extension FPTableEditViewController {

    // MARK: Draft key
    
    /// Stable draft key, computed based on available IDs.
    /// Priority: fieldId > fieldLocalId > template fallback.
    private var fp_draftKey: String {
        return fp_buildDraftKey()
    }
        
    private func fp_buildDraftKey() -> String {
        // Build a stable structural key independent of global IDs but unique to the form instance.
        // We include the parent form's local sqliteId to distinguish between multiple 
        // instances of the same form template on the same ticket.
        let ticketId = self.fpFormViewController?.ticketId?.stringValue ?? "0"
        let parentFormLocalId = FPFormDataHolder.shared.customForm?.sqliteId?.stringValue ?? FPFormDataHolder.shared.customForm?.localClientId ?? "0"

        let fieldTemplateId = self.fieldDetails?.templateId ?? ""
        let section = self.tableIndexPath?.section ?? 0
        let row = self.tableIndexPath?.row ?? 0
        let installId = FPTableDraftDatabaseManager.installScopeId()

        return "fp_tbl_path_\(ticketId)_\(parentFormLocalId)_\(fieldTemplateId)_s\(section)_r\(row)_\(installId)"
    }

    // MARK: DB dispatch helpers

    private func fp_saveDraftToDB(key: String, value: String) {
        if let parentForm = FPFormDataHolder.shared.customForm, parentForm.sqliteId == nil {
            // Edge case: parent form not yet saved locally.
            // We must persist the form record first so this draft has a valid parent.
            self.fpFormViewController?.saveFormOfflineForTable { [weak self] success in
                if success {
                    // 1. Refresh local reference to fieldDetails to pick up the new sqliteId
                    self?.fp_refreshFieldDetailsFromHolder()

                    // 2. Retry save with REGENERATED key
                    if let newKey = self?.fp_draftKey {
                        self?.fp_saveDraftToDB(key: newKey, value: value)
                    }
                }
            }
            return
        }

        let sid = (self.fieldDetails?.sqliteId as? NSNumber)?.int64Value
        let oid = self.fieldDetails?.objectId?.stringValue
        let fid = FPFormDataHolder.shared.customForm?.sqliteId?.stringValue ?? FPFormDataHolder.shared.customForm?.localClientId ?? "0"

        FPTableDraftDatabaseManager().saveDraft(key: key, formLocalId: fid, sqliteId: sid, objectId: oid, value: value)
    }

    private func fp_refreshFieldDetailsFromHolder() {
        guard let holderForm = FPFormDataHolder.shared.customForm,
              let sectionIndex = self.tableIndexPath?.section,
              let fieldIndex = self.tableIndexPath?.row else { return }

        if let section = holderForm.sections?[safe: sectionIndex],
           let field = section.fields[safe: fieldIndex] {
            self.fieldDetails = field
        }
    }

    private func fp_fetchDraftFromDB(key: String, completion: @escaping (String?) -> Void) {
        let sid = (self.fieldDetails?.sqliteId as? NSNumber)?.int64Value
        let oid = self.fieldDetails?.objectId?.stringValue
        FPTableDraftDatabaseManager().fetchDraftByMultiPath(draftKey: key, fieldLocalId: sid, fieldId: oid, completion: completion)
    }

    private func fp_deleteDraftFromDB(key: String) {
        let sid  = (self.fieldDetails?.sqliteId as? NSNumber)?.int64Value
        let oid  = self.fieldDetails?.objectId?.stringValue
        let flid = FPFormDataHolder.shared.customForm?.sqliteId?.stringValue
                   ?? FPFormDataHolder.shared.customForm?.localClientId
        FPTableDraftDatabaseManager().deleteDraftByMultiPath(draftKey: key, fieldLocalId: sid, fieldId: oid, formLocalId: flid)
    }

    // MARK: Setup / teardown

    func fp_setupAutoSave() {
        guard !isAnalysed && !isFromHistory else { return }
        fp_autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 180, repeats: true) { [weak self] _ in
            self?.fp_autoSave()
        }
        // willResignActive fires for BOTH app-switch AND incoming calls (carrier + VoIP).
        // before the system might kill or suspend the app.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(fp_autoSave),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(fp_autoSave),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    func fp_stopAutoSave() {
        fp_autoSaveTimer?.invalidate()
        fp_autoSaveTimer = nil
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    // MARK: Save draft

    @objc func fp_autoSave() {
        // Commit any active text field BEFORE taking the snapshot so the draft
        // captures the full current state including in-progress text input.
        view.endEditing(true)
        fp_performAutoSave()
    }

    func fp_performAutoSave() {
        guard !isAnalysed && !isFromHistory else { return }
        guard let tableComponent = self.tableComponent else { return }

        let key = fp_draftKey
        let valuesSnapshot = tableComponent.getValuesObject()

        DispatchQueue.global(qos: .userInitiated).async {
            let jsonValue = valuesSnapshot.getJson()

            guard !jsonValue.isEmpty else {
                debugPrint("FPTableEdit: auto-save skipped — empty JSON for key=\(key)")
                return
            }

            self.fp_saveDraftToDB(key: key, value: jsonValue)
            debugPrint("FPTableEdit: auto-saved draft key=\(key) rows=\(valuesSnapshot.count)")
        }
    }

    private func fp_triggerFirstSaveIfNeeded() {
        guard !fp_hasFirstChangeSaved else { return }
        fp_hasFirstChangeSaved = true
        fp_performAutoSave()
    }

    // MARK: Delete draft

    func fp_deleteDraft() {
        let key = fp_draftKey
        DispatchQueue.global(qos: .background).async {
            self.fp_deleteDraftFromDB(key: key)
        }
    }

    // MARK: Recovery

    private func fp_normalizeJsonForComparison(_ json: String) -> String {
        guard let data = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return json
        }
        let stripped = array.map { row -> [String: Any] in
            var r = row
            r.removeValue(forKey: "__localId__")
            return r
        }
        guard let result = try? JSONSerialization.data(withJSONObject: stripped, options: .sortedKeys),
              let str = String(data: result, encoding: .utf8) else {
            return json
        }
        return str
    }

    func fp_checkAndRecoverDraft() {
        guard !isAnalysed && !isFromHistory else { return }
        let key = fp_draftKey

        fp_fetchDraftFromDB(key: key) { [weak self] draftValue in
            guard let self = self,
                  let draftValue = draftValue,
                  !draftValue.isEmpty else { return }

            DispatchQueue.main.async {
                let currentValues = self.tableComponent?.getValuesObject()
                
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    guard let self = self else { return }
                    
                    if let currentJson = currentValues?.getJson() {
                        let normCurrent = self.fp_normalizeJsonForComparison(currentJson)
                        let normDraft   = self.fp_normalizeJsonForComparison(draftValue)
                        if normCurrent == normDraft { return }
                    }
                    
                    DispatchQueue.main.async {
                        _ = FPUtility.showAlertController(
                            title: FPLocalizationHelper.localize("alert_dialog_title"),
                            andMessage: FPLocalizationHelper.localize("msg_restore_unsaved_changes"),
                            completion: nil,
                            withPositiveAction: FPLocalizationHelper.localize("Restore"),
                            style: .default,
                            andHandler: { [weak self] _ in
                                guard let self = self else { return }
                                self.fp_applyDraft(draftValue)
                            },
                            withNegativeAction: FPLocalizationHelper.localize("Discard"),
                            style: .destructive,
                            andHandler: { [weak self] _ in
                                self?.fp_deleteDraft()
                            }
                        )
                    }
                }
            }
        }
    }
    private func fp_applyDraft(_ draftValue: String) {
        guard let tableOptions = self.tableComponent?.tableOptions,
              let form = FPFormDataHolder.shared.customForm else { return }

        FPUtility.showHUDWithLoadingMessage()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let index = self.tableIndexPath ?? IndexPath(row: 0, section: 0)
            let recovered = TableComponent().prepareData(
                item: tableOptions,
                values: draftValue,
                index: index,
                fieldDetails: self.fieldDetails,
                customForm: form
            )
            
            DispatchQueue.main.async {
                self.tableComponent = recovered
                if let layout = self.collectionView.collectionViewLayout as? FPSpreadsheetCollectionViewLayout {
                    let totalSections = (recovered.rows?.count ?? 0) + 1
                    layout.updateRowCountOnly(to: totalSections)
                }
                self.fp_bumpTableGeneration()
                self.collectionView.reloadData()
                FPUtility.hideHUD()
                
                // Delete after successful restore so stale
                // draft cannot be offered again on next open.
                self.fp_deleteDraft()
            }
        }
    }
}

// MARK: - Auto-save hint banner

private extension FPTableEditViewController {

    func fp_showAutoSaveHintIfNeeded() {
        guard !isAnalysed && !isFromHistory else { return }
        // Use Keychain so the flag survives logout/login switches and persists per install.
        // UserDefaults is cleared on logout which would incorrectly re-show the hint for each user.
        let key = "ZenForms.tableDraftHintSeen"
        guard !fp_hintSeenFromKeychain(key: key) else { return }
        fp_setHintSeenInKeychain(key: key)

        let banner = UIView()
        banner.backgroundColor = .secondarySystemBackground
        banner.layer.cornerRadius = 10
        banner.layer.borderWidth = 1
        banner.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.35).cgColor
        banner.translatesAutoresizingMaskIntoConstraints = false

        banner.layer.shadowColor = UIColor.black.cgColor
        banner.layer.shadowOpacity = traitCollection.userInterfaceStyle == .dark ? 0.45 : 0.18
        banner.layer.shadowRadius = 10
        banner.layer.shadowOffset = CGSize(width: 0, height: 4)
        banner.layer.masksToBounds = false

        let icon = UIImageView(image: UIImage(systemName: "arrow.counterclockwise.circle.fill"))
        icon.tintColor = .systemBlue
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let label = UILabel()
        label.text = FPLocalizationHelper.localize("msg_table_autosave_hint")
        label.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: .systemFont(ofSize: 14))
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .label
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        let closeBtn = UIButton(type: .system)
        closeBtn.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeBtn.tintColor = .secondaryLabel
        closeBtn.accessibilityLabel = FPLocalizationHelper.localize("DISMISS")
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.setContentHuggingPriority(.required, for: .horizontal)

        banner.addSubview(icon)
        banner.addSubview(label)
        banner.addSubview(closeBtn)
        view.addSubview(banner)

        NSLayoutConstraint.activate([
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            banner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),

            icon.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 10),
            icon.centerYAnchor.constraint(equalTo: banner.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22),

            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: closeBtn.leadingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: banner.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -10),

            closeBtn.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -10),
            closeBtn.centerYAnchor.constraint(equalTo: banner.centerYAnchor),
            closeBtn.widthAnchor.constraint(equalToConstant: 26),
            closeBtn.heightAnchor.constraint(equalToConstant: 26),
        ])

        banner.alpha = 0
        banner.transform = CGAffineTransform(translationX: 0, y: -32)

        UIView.animate(withDuration: 0.35, delay: 0.4, usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
            banner.alpha = 1
            banner.transform = .identity
        } completion: { _ in
            banner.layer.shadowPath = UIBezierPath(
                roundedRect: banner.bounds,
                cornerRadius: banner.layer.cornerRadius
            ).cgPath
        }

        let dismiss = { [weak banner] in
            UIView.animate(withDuration: 0.25) {
                banner?.alpha = 0
                banner?.transform = CGAffineTransform(translationX: 0, y: -32)
            } completion: { _ in banner?.removeFromSuperview() }
        }

        closeBtn.addAction(UIAction { _ in dismiss() }, for: .touchUpInside)

        if !UIAccessibility.isVoiceOverRunning {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { dismiss() }
        }
    }

    private func fp_hintSeenFromKeychain(key: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrAccount:      key,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    private func fp_setHintSeenInKeychain(key: String) {
        let attributes: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData:   Data([1])
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }
}

extension UIImageView {
    func setImageColor(color: UIColor) {
        let templateImage = self.image?.withRenderingMode(.alwaysTemplate)
        self.image = templateImage
        self.tintColor = color
    }
}

extension Double {

    func formattedMax2Decimal() -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.numberStyle = .decimal
        
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
