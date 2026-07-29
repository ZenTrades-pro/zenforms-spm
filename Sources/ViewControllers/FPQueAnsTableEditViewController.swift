//
//  FPQueAnsTableEditViewController.swift
//  crm
//
//  Created by apple on 16/10/24.
//  Copyright © 2024 SmartServ. All rights reserved.
//

import UIKit
internal import SSMediaManager
internal import RSSelectionMenu
internal import IQKeyboardManagerSwift
internal import IQKeyboardToolbar
internal import IQKeyboardToolbarManager


class FPQueAnsTableEditViewController: UIViewController {
   
    private let headerCellReuseIdentifier = "TableHeaderCollectionViewCell"
    private let contentCellReuseIdentifier = "TableContentCollectionViewCell"
    
    @IBOutlet weak var collectionView: UICollectionView!
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
    var didCompletedEdit:((_ tableComponent:TableComponent)->())?
    
    var sortFilterColumnIndexPath:IndexPath?
    var sortFilterColumn:Columns?
    var isSortFilterApplied:Bool = false
    var arrAppliedFilters = [SortFilter]()
    
    var viewModel: FPQueAnsCollectionViewModel? {
        didSet {
            guard let layout = collectionView.collectionViewLayout as? FPQueAnsCollectionViewLayout else {
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
    
    var fieldDetails:FPFieldDetails?
    var sectionDetails:FPSectionDetails?
    var fpFormViewController:FPFormViewController?
    private var fp_autoSaveTimer: Timer?
    private var fp_hasFirstChangeSaved = false

    private var qaTableSearchBar: UISearchBar?
    private var qaTableSearchFilterButton: UIButton?
    private var qaTableSearchEmptyLabel: UILabel?
    private var qaTableSearchDebounceWorkItem: DispatchWorkItem?
    private var qaTableSearchColumnNameKeys: Set<String> = []
    private var qaTableSearchHighlightQuery: String = ""
    private var qaTableSearchColumnPrefsKey: String {
        "ZenForms.FPQueAnsTableEdit.textSearch.columns.\(fieldDetails?.templateId ?? "0")"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        fp_setupAutoSave()
        fp_checkAndRecoverDraft()
       
        if !self.isAnalysed && !self.isFromHistory {
            let rightBarButton = UIBarButtonItem(title:FPLocalizationHelper.localize("SAVE"), style:.plain, target: self, action: #selector(saveButtonAction))
            self.navigationItem.rightBarButtonItem = rightBarButton
        }
        
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
        viewModel = FPQueAnsCollectionViewModel()
        viewModel?.widthQuesColumn = WIDTH_QUES_COLUMN
        self.title  = titleText
        qaInstallTableSearchChrome()
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
        IQKeyboardManager.shared.isEnabled = true
        IQKeyboardToolbarManager.shared.isEnabled = true
        IQKeyboardToolbarManager.shared.toolbarConfiguration.previousBarButtonConfiguration = IQBarButtonItemConfiguration(image: UIImage(named: "ic_left_arrow", in: ZenFormsBundle.bundle, compatibleWith: nil) ?? UIImage())
        IQKeyboardToolbarManager.shared.toolbarConfiguration.nextBarButtonConfiguration = IQBarButtonItemConfiguration(image: UIImage(named: "ic_right_arrow", in: ZenFormsBundle.bundle, compatibleWith: nil) ?? UIImage())
        NotificationCenter.default.addObserver(self, selector: #selector(fpHandleMemoryWarning), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
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
    
    @objc func onDoneButtonTapped(sender: UIBarButtonItem) {
        
    }
    
    @objc private func fpHandleMemoryWarning() {
        // Save draft immediately before the OS potentially kills the process
        fp_autoSave()
        collectionView?.collectionViewLayout.invalidateLayout()
    }
    
    
    //MARK: Actions
    
    @IBAction func btnOpenClonseDidTap(_ sender: UIButton) {
        self.constLeading.constant = sender.isSelected ? -50.0 : 0.0
        UIView.animate(withDuration: 0.3, animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
        sender.isSelected = !sender.isSelected
    }
    

   
    @objc func saveButtonAction(){
        view.endEditing(true)
        fp_performAutoSave()
        fp_stopAutoSave()
        DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
            if let tableComponent = self.tableComponent,let index = self.tableIndexPath{
                FPFormDataHolder.shared.addTableComponentAt(index: index, component: tableComponent)
                self.didCompletedEdit?(tableComponent)
            }
            let snapshot = FPFormDataHolder.shared.tableMediaCache
            snapshot.forEach { tableMedia in
                DispatchQueue.main.async {
                    FPFormDataHolder.shared.updateTableFieldValue(media: tableMedia)
                }
            }
            FPFormDataHolder.shared.tableMediaCache = []
            
            self.navigationController?.popViewController(animated: false)
        })
    }
    
    @objc func cancelButtonClicked() {
        fp_stopAutoSave()
        view.endEditing(true)
        FPFormDataHolder.shared.tableMediaCache = []
        fp_deleteDraft()
        self.navigationController?.popViewController(animated: true)
    }
    
}

extension FPQueAnsTableEditViewController: FPQueAnsCollectionViewModelDataSource {
    func configure(_ cell: UICollectionViewCell, with content: String, column: ColumnData?, indexPath: IndexPath, isHideMore: Bool, isHideCHeckBoxHeader:Bool) {
        if let contentcell = cell as? TableContentCollectionViewCell {
            contentcell.parentTableIndex = tableIndexPath
            contentcell.childTableIndex = indexPath
            contentcell.searchHighlightCaseSensitive = TableRowTextSearch.userPrefersCaseSensitiveSearch
            contentcell.searchHighlightColumnKeys = qaTableSearchColumnNameKeys
            contentcell.searchHighlightQuery = qaTableSearchHighlightQuery.isEmpty ? nil : qaTableSearchHighlightQuery
            contentcell.data = column
            contentcell.delegate = self
            contentcell.btnAction.isHidden = true
            contentcell.viewBarcode.isHidden = true
        }else if let headerCell = cell as? TableHeaderCollectionViewCell {
            headerCell.imgMore.image =  UIImage(named: "icn_more", in: Bundle(for: type(of: self)), compatibleWith: nil)
            headerCell.imgMore.setImageColor(color: .black)
            headerCell.text = content
            headerCell.viewBtn.isHidden = isHideMore
            headerCell.btnActions.isHidden = true
            headerCell.title.isHidden = !isHideCHeckBoxHeader
            headerCell.btnMore.addTarget(self, action: #selector(btnMoreClicked(sender:)), for: .touchUpInside)
            if isSortFilterApplied == true, let index = arrAppliedFilters.firstIndex(where: { $0.indPath == indexPath}), let appliedFilter = arrAppliedFilters[safe: index]  {
                if appliedFilter.option == .filter {
                    headerCell.imgMore.image = UIImage(named: "icn_filter", in: Bundle(for: type(of: self)), compatibleWith: nil)
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
        if  let sortedIndexPth = sortFilterColumnIndexPath, let shownColumns = self.tableComponent?.tableOptions?.columns?.filter({$0.uiType != "HIDDEN"}), let column = shownColumns[safe:sortedIndexPth.row - 1]{
            sortFilterColumn = column
        }
        if sortFilterColumn?.uiType == "DROPDOWN" || sortFilterColumn?.uiType == "DEFICIENCY"{
            displayOptionsPopUp(sender)
        }else{
            displaySortingPopUp(sender)
        }
    }

}

//MARK: Sort Filter Operations
extension FPQueAnsTableEditViewController{
    
    
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
//        menu.navigationItem.rightBarButtonItem?.tintColor = UIColor(named: "BT-Primary")
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
            if  let sortedIndexPth = sortFilterColumnIndexPath, let column = self.tableComponent?.tableOptions?.columns?[safe:sortedIndexPth.row - 1]{
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
        self.collectionView.reloadData()
        qaReapplyTableTextSearchIfNeeded()
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
            let canonical = qaCanonicalFilterOption(option)
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
    private func qaCanonicalFilterOption(_ value: String) -> String {
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
            self.collectionView.setContentOffset(.zero, animated: false)
            if self.arrAppliedFilters.isEmpty{
                self.resetToDefault()
            }else{
                self.collectionView.reloadData()
            }
            self.qaReapplyTableTextSearchIfNeeded()
        }
    }
}

//MARK: TableContentCellDelegate

extension FPQueAnsTableEditViewController: TableContentCellDelegate{
    func deleteRow(at index: IndexPath) {}
    
    func duplicateRow(at index: IndexPath, parentTableIndex: IndexPath?) {}
    
    
    func updateData(at index: IndexPath, with data: ColumnData, filedData filed: FPFieldDetails?) {
        guard let dRow = qa_visibleSectionToDisplayRowIndex(index.section) else { return }
        if isSortFilterApplied, let sortCompnt = sortFilteredTableComponent{
            if var row = sortCompnt.rows?[safe:dRow]{
                if let columnIndex = row.columns.firstIndex(where: {$0.key == data.key}){
                    row.columns[columnIndex] = data
                    sortCompnt.rows?[dRow] = row
                    sortFilteredTableComponent = sortCompnt
                }
            }
            if let updateRow =  sortCompnt.rows?[safe:dRow], let indexOfRow = self.tableComponent?.rows?.firstIndex(where: { $0.sortUuid == updateRow.sortUuid }){
                self.tableComponent?.rows?.remove(at: indexOfRow)
                self.tableComponent?.rows?.insert(updateRow, at: indexOfRow)
            }
            self.collectionView.reloadItems(at: [index])
        }else if let tblCompnt = tableComponent, let _ = tableIndexPath{
            if var row = tblCompnt.rows?[safe:dRow]{
                if let columnIndex = row.columns.firstIndex(where: {$0.key == data.key}){
                    row.columns[columnIndex] = data
                    tblCompnt.rows?[dRow] = row
                    tableComponent = tblCompnt
                }
            }
            self.collectionView.reloadItems(at: [index])
        }
        fp_triggerFirstSaveIfNeeded()
    }
    
    func showAddAttachment(at index:IndexPath,with data:ColumnData){
        self.view.endEditing(true)
        self.attachmentIndex = index
        self.attachmentColumnData = data
        let attachmentView =  TableAttachementView.instance
        attachmentView.parentViewController = self
        attachmentView.delegate = self
        attachmentView.attachmentValue = data.value
        attachmentView.showAttachmentPicker()
    }
    
}


//MARK: Attachment picker delegate
extension FPQueAnsTableEditViewController: AttachmentPickerDelegate{
    func onMediaSave(mediaAdded: [SSMedia], mediaDeleted: [SSMedia]) {
        if let index = attachmentIndex,let data = attachmentColumnData{
            if isSortFilterApplied, let sortCompnt = sortFilteredTableComponent, let dRow = qa_visibleSectionToDisplayRowIndex(index.section), let attachrow = sortCompnt.rows?[dRow], let tblRowIndex = self.tableComponent?.rows?.firstIndex(where: { $0.sortUuid == attachrow.sortUuid }){
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
            }else if let fullR = qa_visibleSectionToFullTableRowIndex(index.section) {
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
            self.collectionView.reloadData()
            fp_performAutoSave()
            fp_hasFirstChangeSaved = false
        }
    }

}

protocol FPQueAnsTableEditViewControllerDelegate{
    
    func didEditTableData()
}

private extension FPQueAnsTableEditViewController {

    func qa_visibleSectionToDisplayRowIndex(_ section: Int) -> Int? {
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

    func qa_visibleSectionToFullTableRowIndex(_ section: Int) -> Int? {
        guard let d = qa_visibleSectionToDisplayRowIndex(section) else { return nil }
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

    func qaRestoreTableSearchColumnPrefs() {
        if let saved = UserDefaults.standard.array(forKey: qaTableSearchColumnPrefsKey) as? [String] {
            qaTableSearchColumnNameKeys = Set(saved)
        }
    }

    func qaPersistTableSearchColumnPrefs() {
        UserDefaults.standard.set(Array(qaTableSearchColumnNameKeys), forKey: qaTableSearchColumnPrefsKey)
    }

    func qaInstallTableSearchChrome() {
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
            self?.qaPresentTableSearchColumnPicker(from: filterBtn)
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

        qaTableSearchBar = searchBar
        qaTableSearchFilterButton = filterBtn
        qaTableSearchEmptyLabel = emptyLabel
        qaUpdateTableSearchFilterButtonAppearance()
    }

    private func qaTableSearchColumnScopeIsRestricted() -> Bool {
        let cols = tableComponent?.tableOptions?.columns?.filter { $0.uiType != "HIDDEN" } ?? []
        guard !cols.isEmpty else { return false }
        if qaTableSearchColumnNameKeys.isEmpty { return false }
        return qaTableSearchColumnNameKeys.count < cols.count
    }

    private func qaUpdateTableSearchFilterButtonAppearance() {
        guard let btn = qaTableSearchFilterButton else { return }
        let primary = UIColor(named: "BT-Primary") ?? .systemBlue
        let restricted = qaTableSearchColumnScopeIsRestricted()
        let symbol = restricted ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
        btn.setImage(UIImage(systemName: symbol), for: .normal)
        btn.tintColor = primary
        btn.accessibilityHint = FPLocalizationHelper.localize("lbl_table_search_filter_hint")
        btn.accessibilityTraits = restricted ? [.button, .selected] : .button
        if restricted {
            let cols = tableComponent?.tableOptions?.columns?.filter { $0.uiType != "HIDDEN" } ?? []
            let n = min(qaTableSearchColumnNameKeys.count, cols.count)
            btn.accessibilityValue = String.localizedStringWithFormat(
                FPLocalizationHelper.localize("msg_table_search_scope_active_a11y"),
                n,
                cols.count
            )
        } else {
            btn.accessibilityValue = FPLocalizationHelper.localize("msg_table_search_scope_all_a11y")
        }
    }

    func qaPresentTableSearchColumnPicker(from sender: UIView) {
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
        if qaTableSearchColumnNameKeys.isEmpty {
            preselected = labels
        } else {
            preselected = cols.filter { qaTableSearchColumnNameKeys.contains($0.name) }.map {
                ($0.displayName.isEmpty ? $0.name : $0.displayName).handleAndDisplayApostrophe()
            }
        }
        let allSelected = (qaTableSearchColumnNameKeys.isEmpty || qaTableSearchColumnNameKeys.count == cols.count)
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
            self.qaTableSearchColumnNameKeys = keys
            self.qaUpdateTableSearchFilterButtonAppearance()
            self.qaApplyTableTextSearchFromField(animated: true)
        }
        menu.cellSelectionStyle = .checkbox
        menu.show(style: .popover(sourceView: sender, size: nil, arrowDirection: .any), from: self)
    }

    func qaApplyTableTextSearchFromField(animated: Bool) {
        let raw = qaTableSearchBar?.text ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let rows = getTableComponent()?.rows ?? []
        if trimmed.isEmpty {
            viewModel?.textSearchVisibleRowIndices = nil
            qaTableSearchHighlightQuery = ""
            qaTableSearchEmptyLabel?.isHidden = true
            qaTableSearchBar?.searchTextField.backgroundColor = nil
            qaTableSearchBar?.searchTextField.textColor = .label
        } else {
            let indices = TableRowTextSearch.matchingRowIndices(
                rows: rows,
                query: trimmed,
                columnKeys: qaTableSearchColumnNameKeys,
                caseSensitive: TableRowTextSearch.userPrefersCaseSensitiveSearch
            )
            viewModel?.textSearchVisibleRowIndices = indices
            qaTableSearchHighlightQuery = trimmed
            let noResults = indices.isEmpty
            qaTableSearchEmptyLabel?.isHidden = true
            let primary = UIColor(named: "BT-Primary") ?? .systemBlue
            if noResults {
                qaTableSearchBar?.searchTextField.backgroundColor = UIColor.systemRed.withAlphaComponent(0.08)
                qaTableSearchBar?.searchTextField.textColor = .systemRed
            } else {
                qaTableSearchBar?.searchTextField.backgroundColor = primary.withAlphaComponent(0.1)
                qaTableSearchBar?.searchTextField.textColor = .label
            }
        }
        if let layout = collectionView.collectionViewLayout as? FPQueAnsCollectionViewLayout {
            layout.invalidateLayout()
        }
        if animated {
            UIView.transition(with: collectionView, duration: 0.12, options: .transitionCrossDissolve) {
                self.collectionView.reloadData()
            }
        } else {
            collectionView.reloadData()
        }
    }

    func qaReapplyTableTextSearchIfNeeded() {
        guard let raw = qaTableSearchBar?.text, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            viewModel?.textSearchVisibleRowIndices = nil
            qaTableSearchHighlightQuery = ""
            qaTableSearchEmptyLabel?.isHidden = true
            qaTableSearchBar?.searchTextField.backgroundColor = nil
            qaTableSearchBar?.searchTextField.textColor = .label
            return
        }
        qaApplyTableTextSearchFromField(animated: false)
    }

    func qaScheduleTableSearchDebounce(for searchText: String) {
        qaTableSearchDebounceWorkItem?.cancel()
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed.count <= 2 {
            qaApplyTableTextSearchFromField(animated: true)
            return
        }
        let item = DispatchWorkItem { [weak self] in
            self?.qaApplyTableTextSearchFromField(animated: true)
        }
        qaTableSearchDebounceWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: item)
    }
}

extension FPQueAnsTableEditViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        guard searchBar === qaTableSearchBar else { return }
        qaScheduleTableSearchDebounce(for: searchText)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        qaTableSearchDebounceWorkItem?.cancel()
        qaApplyTableTextSearchFromField(animated: true)
    }
}


// MARK: - Auto-Save

extension FPQueAnsTableEditViewController {

    // MARK: Draft key
    
    /// Returns the stable draft key for this session.
    /// Stored via objc associated object so it is computed exactly once
    /// and never changes even if fieldDetails / tableIndexPath are mutated.
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
        view.endEditing(true)
        fp_performAutoSave()
    }

    func fp_performAutoSave() {
        guard !isAnalysed && !isFromHistory else { return }
        guard let tableComponent = self.tableComponent else { return }

        let key            = fp_draftKey
        let valuesSnapshot = tableComponent.getValuesObject()

        DispatchQueue.global(qos: .userInitiated).async {
            let jsonValue = valuesSnapshot.getJson()
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
                if let layout = self.collectionView.collectionViewLayout as? FPQueAnsCollectionViewLayout {
                    let totalSections = (recovered.rows?.count ?? 0) + 1
                    layout.updateRowCountOnly(to: totalSections)
                }
                self.collectionView.reloadData()
                FPUtility.hideHUD()
                debugPrint("FPTableEdit: restored draft data")
                
                // Delete after successful restore so stale
                // draft cannot be offered again on next open.
                self.fp_deleteDraft()
            }
        }
    }
}

// MARK: - Auto-save hint banner

private extension FPQueAnsTableEditViewController {

    func fp_showAutoSaveHintIfNeeded() {
        guard !isAnalysed && !isFromHistory else { return }
        let key = "ZenForms.tableDraftHintSeen"
        guard !fp_hintSeenFromKeychain(key: key) else { return }
        fp_setHintSeenInKeychain(key: key)

        let banner = UIView()
        banner.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        banner.layer.cornerRadius = 10
        banner.layer.borderWidth = 1
        banner.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.25).cgColor
        banner.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: "arrow.counterclockwise.circle.fill"))
        icon.tintColor = .systemBlue
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let label = UILabel()
        label.text = FPLocalizationHelper.localize("msg_table_autosave_hint")
        label.font = .systemFont(ofSize: 13)
        label.textColor = .label
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        let closeBtn = UIButton(type: .system)
        closeBtn.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeBtn.tintColor = .secondaryLabel
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.setContentHuggingPriority(.required, for: .horizontal)

        banner.addSubview(icon)
        banner.addSubview(label)
        banner.addSubview(closeBtn)
        view.addSubview(banner)

        NSLayoutConstraint.activate([
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            banner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            icon.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 12),
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
        banner.transform = CGAffineTransform(translationX: 0, y: -10)
        UIView.animate(withDuration: 0.35, delay: 0.4, usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
            banner.alpha = 1
            banner.transform = .identity
        }

        let dismiss = { [weak banner] in
            UIView.animate(withDuration: 0.25) {
                banner?.alpha = 0
                banner?.transform = CGAffineTransform(translationX: 0, y: -10)
            } completion: { _ in banner?.removeFromSuperview() }
        }

        closeBtn.addAction(UIAction { _ in dismiss() }, for: .touchUpInside)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { dismiss() }
    }

    private func fp_hintSeenFromKeychain(key: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:        kSecClassGenericPassword,
            kSecAttrAccount:  key,
            kSecReturnData:   true,
            kSecMatchLimit:   kSecMatchLimitOne
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

