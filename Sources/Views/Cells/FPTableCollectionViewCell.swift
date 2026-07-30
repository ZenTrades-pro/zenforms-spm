//
//  AdditionalTableCollectionViewCell.swift
//  crm
//
//  Created by Mayur on 15/02/22.
//  Copyright © 2022 SmartServ. All rights reserved.
//

import UIKit
internal import RSSelectionMenu

class FPTableCollectionViewCell: UITableViewCell {
    
    @IBOutlet weak var btnAddRow: UIButton!
    @IBOutlet weak var collMain: UICollectionView!
    @IBOutlet weak var tableName: UILabel!

    var delegate: FPCollectionCellDelegate!
    var fpViewController:FPFormViewController?
    var isShowAddRow = true
    var titleText:String?
    var isNew: Bool = true
    var tableIndexPath:IndexPath?
    var fieldDetails:FPFieldDetails?
    var sectionDetails:FPSectionDetails?
    var zenFormsDelegate: ZenFormsDelegate?

    var cellItem: TableComponent? {
        didSet {
            if let cellItem = cellItem,let index = tableIndexPath {
                FPFormDataHolder.shared.addTableComponentAt(index: index, component: cellItem)
            }
            
            // Ensure data source is set before reloading
            if viewModel != nil && collMain.dataSource == nil {
                collMain.dataSource = viewModel
                collMain.delegate = viewModel
            }
            
            // Force layout recalculation when cellItem changes
            // This will reload data and recalculate layout
            recalculateLayout()
        }
    }
    
    var viewModel: FPQueAnsCollectionViewModel? {
        didSet {
            guard let layout = collMain.collectionViewLayout as? FPQueAnsCollectionViewLayout else {
                assertionFailure("Expected a SpreadsheetLayout")
                return
            }
            viewModel?.dataSource = self
            viewModel?.parentIndexPath = tableIndexPath
            viewModel?.maxPreviewRows = 5
            collMain.dataSource = viewModel
            collMain.delegate = viewModel
            layout.isNew = true
            layout.delegate = viewModel
            collMain.reloadData()
            
            // Force layout recalculation after data is loaded
            // If cellItem already exists, ensure layout recalculates with current data
            if cellItem != nil {
                DispatchQueue.main.async { [weak self] in
                    self?.recalculateLayout()
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    // Even without cellItem, ensure layout is ready when bounds become valid
                    if self.collMain.bounds.width > 0 && self.collMain.bounds.height > 0 {
                        layout.invalidateLayout()
                        self.collMain.layoutIfNeeded()
                    }
                }
            }
        }
    }
    
    private let headerCellReuseIdentifier = "TableHeaderCollectionViewCell"
    private let contentCellReuseIdentifier = "TableContentCollectionViewCell"

    private var fpPreviewSearchBar: UISearchBar?
    private var fpPreviewSearchEmptyLabel: UILabel?
    private var fpPreviewSearchFilterButton: UIButton?
    private var fpPreviewSearchDebounceWorkItem: DispatchWorkItem?
    private var fpPreviewSearchColumnNameKeys: Set<String> = []
    private var fpPreviewSearchHighlightQuery: String = ""
    private var fpPreviewSearchChromeInstalled = false

    private var fpPreviewSearchColumnPrefsKey: String {
        "ZenForms.FPTableCell.textSearch.columns.\(fieldDetails?.templateId ?? "0")"
    }

    private var rowCountLabel: UILabel?

    override func awakeFromNib() {
        super.awakeFromNib()
        self.setNeedsLayout()
        self.layoutIfNeeded()

        let bundle = ZenFormsBundle.bundle

        collMain?.register(
            UINib(nibName: headerCellReuseIdentifier, bundle: bundle),
            forCellWithReuseIdentifier: headerCellReuseIdentifier
        )
        collMain?.register(
            UINib(nibName: contentCellReuseIdentifier, bundle: bundle),
            forCellWithReuseIdentifier: contentCellReuseIdentifier
        )

        setupRowCountLabel()
    }

    private func setupRowCountLabel() {
        guard let buttonSuperview = btnAddRow.superview as? UIStackView else { return }

        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = UIColor(named: "BT-Primary") ?? .systemBlue
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false

        // Add label to spacer view, aligned to leading (next to button)
        if let spacerView = buttonSuperview.arrangedSubviews.last, spacerView != btnAddRow {
            spacerView.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: spacerView.leadingAnchor, constant: 12),
                label.centerYAnchor.constraint(equalTo: spacerView.centerYAnchor)
            ])
        }

        rowCountLabel = label
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        fpPreviewSearchDebounceWorkItem?.cancel()
        fpPreviewSearchBar?.text = ""
        fpPreviewSearchEmptyLabel?.isHidden = true
        fpPreviewSearchHighlightQuery = ""
        fpPreviewSearchColumnNameKeys = []
        self.viewModel = nil
        self.viewModel = FPQueAnsCollectionViewModel()
    }

    
    func configureCell(with item: FPFieldDetails, sectionDetail:FPSectionDetails?, indexPath: IndexPath, customForm:FPForms) {
        let displayName = item.displayName?.handleAndDisplayApostrophe() ?? ""
        self.fieldDetails  = item
        self.sectionDetails = sectionDetail
        self.tableName.text = displayName
        self.titleText = displayName
        self.tableIndexPath = indexPath
        self.btnAddRow.isHidden = !isShowAddRow
        fpEnsurePreviewSearchChromeInstalled()

        // Ensure viewModel exists before setting cellItem
        if viewModel == nil {
            viewModel = FPQueAnsCollectionViewModel()
        }

        self.viewModel?.maxPreviewRows = 5
        self.viewModel?.widthQuesColumn = self.fieldDetails?.getUIType() == .TABLE ? WIDTH_CONTENT : WIDTH_QUES_COLUMN
        if let component = FPFormDataHolder.shared.getTableComponentAt(index: indexPath){
            self.cellItem = component
        }else{
            let tableOptions = item.getTableOptions(strJson: item.options ?? "")
            self.cellItem = TableComponent().prepareData(item: tableOptions ?? TableOptions(), values: item.value,index: indexPath,fieldDetails: item, customForm: customForm)
            FPFormDataHolder.shared.addTableComponentAt(index: indexPath, component: self.cellItem!)
        }

        // Update row count label
        updateRowCountLabel()

        // Force layout recalculation after configuration
        DispatchQueue.main.async { [weak self] in
            self?.recalculateLayout()
        }
    }

    private func updateRowCountLabel() {
        let totalRows = cellItem?.rows?.count ?? 0
        let maxRows = 5

        if totalRows > maxRows {
            rowCountLabel?.text = FPLocalizationHelper.localize("lbl_showing_rows_format")
                .replacingOccurrences(of: "{shown}", with: "\(maxRows)")
                .replacingOccurrences(of: "{total}", with: "\(totalRows)")
            rowCountLabel?.isHidden = false
        } else {
            rowCountLabel?.isHidden = true
        }
    }
    
    func recalculateLayout() {
        guard let layout = collMain.collectionViewLayout as? FPQueAnsCollectionViewLayout else {
            return
        }
        
        // Always reload data first - this ensures cells are created and data source is queried
        // Data loading doesn't require valid bounds
        collMain.reloadData()
        
        // Only do layout calculations if collection view has valid bounds
        // This prevents incorrect calculations when cell is off-screen with zero bounds
        guard collMain.bounds.width > 0 && collMain.bounds.height > 0 else {
            // If bounds are invalid, schedule layout recalculation for later
            // But data is already loaded, so cells will be created when bounds become valid
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.collMain.bounds.width > 0 && self.collMain.bounds.height > 0 {
                    layout.isNew = true
                    layout.invalidateLayout()
                    self.collMain.layoutIfNeeded()
                }
            }
            return
        }
        
        // Clear layout cache to force recalculation
        layout.isNew = true
        layout.invalidateLayout()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.collMain.layoutIfNeeded()
            layout.invalidateLayout()
            self.collMain.setNeedsLayout()
            self.collMain.layoutIfNeeded()
        }
    }
    
    private var previousBounds: CGRect = .zero
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Recalculate layout when cell bounds change from zero to non-zero
        // This ensures layout is correct when cell becomes visible after being configured off-screen
        let currentBounds = collMain.bounds
        let boundsChanged = !currentBounds.equalTo(previousBounds)
        let boundsAreValid = currentBounds.width > 0 && currentBounds.height > 0
        let wasZeroBounds = previousBounds.width == 0 || previousBounds.height == 0
        
        if boundsChanged && boundsAreValid && wasZeroBounds {
            // Cell just got valid bounds (became visible), invalidate layout only
            // DO NOT call reloadData() here as it causes scroll freeze/hang
            if let layout = collMain.collectionViewLayout as? FPQueAnsCollectionViewLayout {
                layout.isNew = true
                layout.invalidateLayout()
                // Layout will be recalculated automatically, no need to force it
            }
        }
        
        previousBounds = currentBounds
    }
    
    @IBAction func didAddRowTapped(_ sender: Any) {
        if self.fieldDetails?.getUIType() == .TABLE{
            self.openNormalTable()
        }else{
            self.openRestrictedTable()
        }
    }
    
    func openNormalTable(){
        let viewController =  FPTableEditViewController(nibName: "FPTableEditViewController", bundle: ZenFormsBundle.bundle)
        viewController.fieldDetails =  fieldDetails
        viewController.sectionDetails = sectionDetails
        viewController.fpFormViewController =  fpViewController
        viewController.zenFormsDelegate = zenFormsDelegate
        let component = TableComponent()
        component.headers = cellItem?.headers
        component.rows = cellItem?.rows
        component.tableOptions = cellItem?.tableOptions
        component.values = cellItem?.values
        viewController.tableComponent = component
        viewController.titleText = self.titleText
        viewController.tableIndexPath = tableIndexPath
        viewController.isNew  = self.isNew
        viewController.isAnalysed = fpViewController?.isAnalysed ?? false
        viewController.isFromHistory = fpViewController?.isFromHistory ?? false
        viewController.isAssetEnabled = fpViewController?.isAssetEnabled ?? false
        viewController.didCompletedEdit = { tableComponent in
            self.cellItem = tableComponent
            if let index = self.tableIndexPath {
                FPFormDataHolder.shared.addTableComponentAt(index: index, component: tableComponent)
            }
            self.updateTableData()
            self.updateRowCountLabel()
            self.fpReapplyPreviewTextSearchIfNeeded()
            self.collMain.reloadData()
            self.collMain.layoutIfNeeded()
        }
        self.fpViewController?.navigationController?.pushViewController(viewController, animated: true)
        return
    }

    func openRestrictedTable(){
        let viewController =  FPQueAnsTableEditViewController(nibName: "FPQueAnsTableEditViewController", bundle: ZenFormsBundle.bundle)
        viewController.fieldDetails =  fieldDetails
        viewController.sectionDetails = sectionDetails
        viewController.fpFormViewController =  fpViewController
        viewController.zenFormsDelegate = fpViewController?.delegate
        let component = TableComponent()
        component.headers = cellItem?.headers
        component.rows = cellItem?.rows
        component.tableOptions = cellItem?.tableOptions
        component.values = cellItem?.values
        viewController.tableComponent = component
        viewController.titleText = self.titleText
        viewController.tableIndexPath = tableIndexPath
        viewController.isNew  = self.isNew
        viewController.isAnalysed = fpViewController?.isAnalysed ?? false
        viewController.isFromHistory = fpViewController?.isFromHistory ?? false
        viewController.didCompletedEdit = { tableComponent in
            self.cellItem = tableComponent
            if let index = self.tableIndexPath {
                FPFormDataHolder.shared.addTableComponentAt(index: index, component: tableComponent)
            }
            self.updateTableData()
            self.updateRowCountLabel()
            self.fpReapplyPreviewTextSearchIfNeeded()
            self.collMain.reloadData()
            self.collMain.layoutIfNeeded()
        }
        self.fpViewController?.navigationController?.pushViewController(viewController, animated: true)
        return
    }
    
    fileprivate func updateTableData() {
        if let values = self.cellItem?.getValuesObject(){
            var tempValues:[[String:Any]] = []
            if(!(values.isEmpty)){
                for (index, element) in values.enumerated() {
                    let value = values[index]
                    if (value.keys.contains(where: {$0 == "__id__"})){
                        var tempValue = element
                        tempValue["__id__"] = value["__id__"]
                        tempValues.append(tempValue)
                    }else{
                        tempValues.append(element)
                    }
                }
            }else{
                tempValues = values
            }
            FPFormDataHolder.shared.updateRowWith(value:tempValues.getJson(), inSection:tableIndexPath!.section, atIndex: tableIndexPath!.row) { _ in }
        }
    }
  
}

private extension FPTableCollectionViewCell {

    func fpRestorePreviewSearchColumnPrefs() {
        if let saved = UserDefaults.standard.array(forKey: fpPreviewSearchColumnPrefsKey) as? [String] {
            fpPreviewSearchColumnNameKeys = Set(saved)
        }
    }

    func fpPersistPreviewSearchColumnPrefs() {
        UserDefaults.standard.set(Array(fpPreviewSearchColumnNameKeys), forKey: fpPreviewSearchColumnPrefsKey)
    }

    func fpEnsurePreviewSearchChromeInstalled() {
        guard let stack = collMain.superview?.superview as? UIStackView else { return }
        if fpPreviewSearchChromeInstalled {
            fpUpdatePreviewSearchFilterButtonAppearance()
            return
        }
        fpPreviewSearchChromeInstalled = true
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
            guard let self, let base = self.fpViewController else { return }
            self.fpPresentPreviewColumnPicker(from: filterBtn, presenting: base)
        }, for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [searchBar, filterBtn])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 4
        row.translatesAutoresizingMaskIntoConstraints = false

        let emptyLabel = UILabel()
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.font = .preferredFont(forTextStyle: .subheadline)
        emptyLabel.textColor = .secondaryLabel
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

        fpPreviewSearchBar = searchBar
        fpPreviewSearchFilterButton = filterBtn
        fpPreviewSearchEmptyLabel = emptyLabel
        fpUpdatePreviewSearchFilterButtonAppearance()
    }

    private func fpPreviewTableSearchColumnScopeIsRestricted() -> Bool {
        let cols = cellItem?.tableOptions?.columns?.filter { $0.uiType != "HIDDEN" } ?? []
        guard !cols.isEmpty else { return false }
        if fpPreviewSearchColumnNameKeys.isEmpty { return false }
        return fpPreviewSearchColumnNameKeys.count < cols.count
    }

    private func fpUpdatePreviewSearchFilterButtonAppearance() {
        guard let btn = fpPreviewSearchFilterButton else { return }
        let primary = UIColor(named: "BT-Primary") ?? .systemBlue
        let restricted = fpPreviewTableSearchColumnScopeIsRestricted()
        let symbol = restricted ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
        btn.setImage(UIImage(systemName: symbol), for: .normal)
        btn.tintColor = primary
        btn.accessibilityHint = FPLocalizationHelper.localize("lbl_table_search_filter_hint")
        btn.accessibilityTraits = restricted ? [.button, .selected] : .button
        if restricted {
            let cols = cellItem?.tableOptions?.columns?.filter { $0.uiType != "HIDDEN" } ?? []
            let n = min(fpPreviewSearchColumnNameKeys.count, cols.count)
            btn.accessibilityValue = String.localizedStringWithFormat(
                FPLocalizationHelper.localize("msg_table_search_scope_active_a11y"),
                n,
                cols.count
            )
        } else {
            btn.accessibilityValue = FPLocalizationHelper.localize("msg_table_search_scope_all_a11y")
        }
    }

    func fpPresentPreviewColumnPicker(from sender: UIView, presenting: UIViewController) {
        fpViewController?.view.endEditing(true)
        let cols = cellItem?.tableOptions?.columns?.filter { $0.uiType != "HIDDEN" } ?? []
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
        menu.setNavigationBar(title: FPLocalizationHelper.localize("lbl_table_search_columns"), attributes: [NSAttributedString.Key.foregroundColor: UIColor.black], barTintColor: UIColor(named: "BT-Primary"), tintColor: UIColor.black)

        let preselected: [String]
        if fpPreviewSearchColumnNameKeys.isEmpty {
            preselected = labels
        } else {
            preselected = cols.filter { fpPreviewSearchColumnNameKeys.contains($0.name) }.map {
                ($0.displayName.isEmpty ? $0.name : $0.displayName).handleAndDisplayApostrophe()
            }
        }
        menu.setSelectedItems(items: preselected) { _, _, _, _ in }

        menu.setRightBarButton(title: FPLocalizationHelper.localize("Done")) { [weak self] selectedItems in
            menu.dismiss(animated: true)
            guard let self else { return }
            var keys = Set<String>()
            for item in selectedItems {
                if let n = nameByLabel[item] {
                    keys.insert(n)
                }
            }
            self.fpPreviewSearchColumnNameKeys = keys
            self.fpUpdatePreviewSearchFilterButtonAppearance()
            self.fpApplyPreviewTextSearchFromField(animated: true)
        }
        menu.cellSelectionStyle = .checkbox
        menu.show(style: .popover(sourceView: sender, size: nil, arrowDirection: .any), from: presenting)
    }

    func fpApplyPreviewTextSearchFromField(animated: Bool) {
        let raw = fpPreviewSearchBar?.text ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let rows = cellItem?.rows ?? []
        if trimmed.isEmpty {
            viewModel?.textSearchVisibleRowIndices = nil
            fpPreviewSearchHighlightQuery = ""
            fpPreviewSearchEmptyLabel?.isHidden = true
        } else {
            let indices = TableRowTextSearch.matchingRowIndices(
                rows: rows,
                query: trimmed,
                columnKeys: fpPreviewSearchColumnNameKeys,
                caseSensitive: TableRowTextSearch.userPrefersCaseSensitiveSearch
            )
            viewModel?.textSearchVisibleRowIndices = indices
            fpPreviewSearchHighlightQuery = trimmed
            fpPreviewSearchEmptyLabel?.isHidden = !indices.isEmpty
        }
        if let layout = collMain.collectionViewLayout as? FPQueAnsCollectionViewLayout {
            layout.invalidateLayout()
        }
        if animated {
            UIView.transition(with: collMain, duration: 0.12, options: .transitionCrossDissolve) {
                self.collMain.reloadData()
            }
        } else {
            collMain.reloadData()
        }
    }

    func fpReapplyPreviewTextSearchIfNeeded() {
        guard let raw = fpPreviewSearchBar?.text, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            viewModel?.textSearchVisibleRowIndices = nil
            fpPreviewSearchHighlightQuery = ""
            fpPreviewSearchEmptyLabel?.isHidden = true
            return
        }
        fpApplyPreviewTextSearchFromField(animated: false)
    }

    func fpSchedulePreviewSearchDebounce(for searchText: String) {
        fpPreviewSearchDebounceWorkItem?.cancel()
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed.count <= 2 {
            fpApplyPreviewTextSearchFromField(animated: true)
            return
        }
        let item = DispatchWorkItem { [weak self] in
            self?.fpApplyPreviewTextSearchFromField(animated: true)
        }
        fpPreviewSearchDebounceWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: item)
    }
}

extension FPTableCollectionViewCell: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        guard searchBar === fpPreviewSearchBar else { return }
        fpSchedulePreviewSearchDebounce(for: searchText)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        fpPreviewSearchDebounceWorkItem?.cancel()
        fpApplyPreviewTextSearchFromField(animated: true)
    }
}

extension FPTableCollectionViewCell: FPQueAnsCollectionViewModelDataSource {
    func configure(_ cell: UICollectionViewCell, with content: String, column: ColumnData?, indexPath: IndexPath, isHideMore: Bool, isHideCHeckBoxHeader:Bool) {
        if let contentcell = cell as? TableContentCollectionViewCell {
            contentcell.parentTableIndex = tableIndexPath
            contentcell.childTableIndex = indexPath
            contentcell.searchHighlightCaseSensitive = TableRowTextSearch.userPrefersCaseSensitiveSearch
            contentcell.searchHighlightColumnKeys = fpPreviewSearchColumnNameKeys
            contentcell.searchHighlightQuery = fpPreviewSearchHighlightQuery.isEmpty ? nil : fpPreviewSearchHighlightQuery
            contentcell.data = column
            contentcell.viewBarcode.isHidden = true
            contentcell.isUserInteractionEnabled = false
            contentcell.btnAddAttachment.isEnabled = false
        }else if let headerCell = cell as? TableHeaderCollectionViewCell {
            headerCell.text = content
            headerCell.viewBtn.isHidden = true
            headerCell.btnActions.isHidden = true
            headerCell.title.isHidden = !isHideCHeckBoxHeader
            headerCell.isUserInteractionEnabled = false
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
        return self.cellItem
    }
  
}
