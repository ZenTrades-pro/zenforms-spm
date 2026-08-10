//
//  DynamicReasonsView.swift
//  crm
//
//  Created by Mayur on 24/02/22.
//  Copyright © 2022 SmartServ. All rights reserved.
//

import UIKit
import SwiftUI
internal import SSMediaManager
struct FPConstansts {
    struct NibName {
        static let FPListSelectionCell = "FPListSelectionCell"
        static let SegmentControlTableViewCell = "SegmentControlTableViewCell"
        static let CustomReasonTextFieldTableViewCell = "CustomReasonTextFieldTableViewCell"
        static let FileReasonCell =  "FileReasonCell"
        static let FileTagListCell =  "FileTagListCell"
        static let FPReasonAiCell = "FPReasonAiCell"
    }
}

protocol DynamicReasonsViewDelegate: AnyObject {
    func updateFieldItem(with values: String, value: String, indexPath: IndexPath, shouldReload: Bool)
}

class FPSegmentView: UIView {
    
    @IBOutlet weak var reasonsTableView: FPSelfSizedTableView!
    @IBOutlet var contentView: UIView!
    
    private static let INDEX_SEGMENT = 0
    private static let INDEX_REASON_LABEL = 1
    var delegate: FPCollectionCellDelegate!
    var zenFormDelegate: ZenFormsDelegate?
    var tableRowCount = 1
    var collectionIndex = IndexPath()
    var valueString = ""
    var title = ""
    var attachments = ""
    var fileInputDelegate:PFFileInputDelegate?
    var isAnalysed : Bool = false
    var fieldItem :FPFieldDetails?

    var cellItem: FPReasonsComponent? {
        didSet {
            refreshTableRowCountAndReload()
        }
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        notifyTableToUpdateHeight()
    }

    private func notifyTableToUpdateHeight() {
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  let tableView = sequence(first: self.superview, next: { $0?.superview })
                      .first(where: { $0 is UITableView }) as? UITableView,
                  tableView.superview != nil,
                  tableView.window != nil else { return }

            UIView.performWithoutAnimation {
                tableView.setNeedsLayout()
                tableView.layoutIfNeeded()
            }
        }
    }

    
    /// Updates tableRowCount from current cellItem and reloads the inner table. Call from didSet and from segmentValueChangedAt so the current view is in sync before the parent reloads the row (avoids UI hiding when segment value changes, especially first time in landscape).
    private func refreshTableRowCountAndReload() {
        if self.fieldItem?.openDeficencySelectedOption(value: cellItem?.value ?? "") == true {
            let count = self.cellItem?.rows?.count ?? 0
            if isEnableReasonAICell {
                tableRowCount = count + 2
            } else {
                tableRowCount = count + 3
                if let files = FPFormDataHolder.shared.getFiledFilesArray()[collectionIndex], files.count > 0 {
                    tableRowCount += 1
                }
            }
        } else {
            tableRowCount = 1
        }

        UIView.performWithoutAnimation {
            reasonsTableView.reloadData()
            reasonsTableView.layoutIfNeeded()
        }

        reasonsTableView.invalidateIntrinsicContentSize()
        invalidateIntrinsicContentSize()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        let bundle = ZenFormsBundle.bundle
        bundle.loadNibNamed("FPSegmentView", owner: self, options:nil)
        addSubview(contentView)
        setUpTableView()
        self.contentView.frame = self.bounds
        self.contentView.autoresizingMask = [.flexibleHeight,.flexibleWidth]
    }
    
    func setUpTableView() {
        self.reasonsTableView.register(UINib(nibName: FPConstansts.NibName.FPListSelectionCell, bundle: ZenFormsBundle.bundle), forCellReuseIdentifier: FPConstansts.NibName.FPListSelectionCell)
        self.reasonsTableView.register(UITableViewCell.self, forCellReuseIdentifier: FPConstansts.NibName.SegmentControlTableViewCell)
        self.reasonsTableView.register(UINib(nibName: FPConstansts.NibName.CustomReasonTextFieldTableViewCell, bundle: ZenFormsBundle.bundle), forCellReuseIdentifier: FPConstansts.NibName.CustomReasonTextFieldTableViewCell)
        self.reasonsTableView.register(UINib(nibName: FPConstansts.NibName.FileReasonCell, bundle: ZenFormsBundle.bundle), forCellReuseIdentifier: FPConstansts.NibName.FileReasonCell)
        self.reasonsTableView.register(UINib(nibName: FPConstansts.NibName.FileTagListCell, bundle: ZenFormsBundle.bundle), forCellReuseIdentifier: FPConstansts.NibName.FileTagListCell)
        self.reasonsTableView.register(UINib(nibName: FPConstansts.NibName.FPReasonAiCell, bundle: ZenFormsBundle.bundle), forCellReuseIdentifier: FPConstansts.NibName.FPReasonAiCell)

        

        self.reasonsTableView.delegate = self
        self.reasonsTableView.dataSource = self
        self.reasonsTableView.sectionHeaderHeight = UITableView.automaticDimension
        self.reasonsTableView.estimatedSectionHeaderHeight = 14
    }
    
    fileprivate func setValueFromSelectedIndex(_ withSelectedIndex: Int) {
        if let radioOptions = self.fieldItem?.getRadioOptions() as? [[String:Any]], let value = radioOptions[safe:withSelectedIndex]?["value"] as? String{
            self.valueString = value
        }else{
            self.valueString = ""
        }
    }
    
    
    fileprivate func getSelectedIndex(_ value: String) -> Int {
        var selIndex = -1
        if let radioOptions = self.fieldItem?.getRadioOptions() as? [[String:Any]],
           let selectedIndex = radioOptions.firstIndex(where: {($0["value"] as? String ?? "").lowercased() == value.lowercased()}){
            return selectedIndex
        }
        return selIndex
    }
    
    fileprivate func updateSelectedValue() {
        let reasons = cellItem?.getReasonsArray() ?? [[:]]
        FPFormDataHolder.shared.updateRowWith(reasons: reasons.getJson(), value: self.valueString, inSection: self.collectionIndex.section, atIndex: self.collectionIndex.row)
        delegate?.dataChanged()
    }
    
    func stopRecorder(){
        if isEnableReasonAICell {
            if let cell = self.reasonsTableView.cellForRow(at:IndexPath(row: 1, section: 0)) as? FPReasonAiCell{
                cell.stopRecording()
                cell.normalState()
            }
        }
    }
}

//MARK: UITableViewDelegate and UITableViewDataSource
extension FPSegmentView: UITableViewDelegate,UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableRowCount
    }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let label = UILabel()
        label.lineBreakMode = .byWordWrapping
        label.numberOfLines = 0
        if fieldItem?.mandatory ?? false{
            let fontAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.preferredFont(forTextStyle: .headline), .foregroundColor: UIColor.black]
            let baseString =  NSAttributedString(string: " \(title)", attributes: fontAttributes)
            let attributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.red]
            let starString =  NSAttributedString(string: "*", attributes: attributes)
            let mutableString = NSMutableAttributedString(attributedString: starString)
            mutableString.append(baseString)
            label.attributedText = mutableString
        }else{
            label.text = title
            label.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
            label.textColor = .black
        }
        return label
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let count = cellItem?.rows?.count ?? 0
        switch(indexPath.row){
        case FPSegmentView.INDEX_SEGMENT:
            
            //fixed https://smartserv.atlassian.net/browse/BB-13678
            let selectedSegmentIndex = getSelectedIndex(self.cellItem?.value ?? "")
            setValueFromSelectedIndex(selectedSegmentIndex)
            let segmentTitles: [String] = {
                let radioOptions = fieldItem?.getRadioOptions() ?? []
                if !radioOptions.isEmpty {
                    return radioOptions.indices.map { radioOptions[safe: $0]?["label"] as? String ?? "" }
                }
                return [
                    FPLocalizationHelper.localize("Yes"),
                    FPLocalizationHelper.localize("NO"),
                    "N/A"
                ]
            }()
            let cell = tableView.dequeueReusableCell(withIdentifier: FPConstansts.NibName.SegmentControlTableViewCell, for: indexPath)
            cell.backgroundColor = .clear
            cell.selectionStyle = .none
            cell.contentConfiguration = UIHostingConfiguration {
                SegmentControlView(
                    titles: segmentTitles,
                    selectedIndex: selectedSegmentIndex >= 0 && selectedSegmentIndex < segmentTitles.count ? selectedSegmentIndex : -1,
                    onSelect: { [weak self] index in
                        self?.segmentValueChangedAt(indexPath: self?.collectionIndex, withSelectedIndex: index)
                    },
                    isEnabled: !self.isAnalysed
                )
            }
            .margins(.all, 0)
            cell.isUserInteractionEnabled = !self.isAnalysed
            return cell
        case FPSegmentView.INDEX_REASON_LABEL:
            if isEnableReasonAICell{
                if let cell = tableView.dequeueReusableCell(withIdentifier: FPConstansts.NibName.FPReasonAiCell) as? FPReasonAiCell{
                    cell.delegate = fileInputDelegate
                    cell.delegate1 = self
                    cell.zenFormDelegate = self.zenFormDelegate
                    cell.indexPath = self.collectionIndex
                    cell.setupView(customReason: self.cellItem?.customReason)
                    cell.recommendationTextField.isUserInteractionEnabled = !self.isAnalysed
                    cell.reasonTextField.isUserInteractionEnabled = !self.isAnalysed
                    cell.recordBtn.isHidden = self.isAnalysed
                    cell.recordBtn1.isHidden = self.isAnalysed
                    cell.txtFieldSerity.isUserInteractionEnabled = !self.isAnalysed
                    cell.btnImageAdd.isHidden = self.isAnalysed
                    cell.btnSeverityAdd.isUserInteractionEnabled = !self.isAnalysed
                    cell.onItemsRemoved = { index in
                        self.delegate.reloadCollectionAt(index: self.collectionIndex)
                    }
                    return cell
                }
            }else{
                if let cell = tableView.dequeueReusableCell(withIdentifier: FPConstansts.NibName.FileReasonCell) as? FileReasonCell{
                    cell.delegate = fileInputDelegate
                    cell.indexPath = self.collectionIndex
                    cell.btnAddImage.isHidden = self.isAnalysed
                    return cell
                }
            }
            let cell = UITableViewCell()
            cell.textLabel?.text = FPLocalizationHelper.localize("lbl_Reasons")
            return cell;
        case count + 2:
            if let cell = tableView.dequeueReusableCell(withIdentifier: FPConstansts.NibName.CustomReasonTextFieldTableViewCell) as? CustomReasonTextFieldTableViewCell{
                cell.delegate = self
                cell.reasonTextField.isUserInteractionEnabled = !self.isAnalysed
                if let customReason = self.cellItem?.customReason {
                    cell.reasonTextField.text = customReason.description
                } else {
                    cell.reasonTextField.text = ""
                }
                return cell
            }
            break
            
        case count + 3:
            if let cell = tableView.dequeueReusableCell(withIdentifier: FPConstansts.NibName.FileTagListCell) as? FileTagListCell{
                cell.indexPath = collectionIndex
                cell.configure()
                cell.tagListView.enableRemoveButton = !self.isAnalysed
                cell.onItemsRemoved = { index in
                    self.delegate.reloadCollectionAt(index: self.collectionIndex)
                }
                return cell
            }
            break
        default:
            let reasonIndex = indexPath.row - 2
            guard reasonIndex > -1 else { return UITableViewCell() }
            if let cell = tableView.dequeueReusableCell(withIdentifier: FPConstansts.NibName.FPListSelectionCell) as? FPListSelectionCell{
                if reasonIndex > -1 {
                    if let reason = self.cellItem?.rows?[reasonIndex] {
                        let selectionModel = FPSelectionModel(titleString:reason.description, isChecked: reason.isSelected, description: nil)
                        cell.checkIcon.isUserInteractionEnabled = false
                        cell.setListSelectionCell(model: selectionModel,index: indexPath.row)
                    }
                }
                return cell
            }
            break
        }
        
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) {
            cell.contentView.backgroundColor = UIColor.white
        }
        let reasonIndex = indexPath.row - 2
        guard reasonIndex > -1 else { return }
        if var rows = self.cellItem?.rows{
            if var reasonRow = rows[safe:reasonIndex]{
                reasonRow.isSelected = !reasonRow.isSelected
                rows[reasonIndex] = reasonRow
                self.cellItem?.rows = rows
                updateSelectedValue()
                if let  cell   = tableView.cellForRow(at: indexPath) as? FPListSelectionCell{
                    cell.checkIcon.isSelected = reasonRow.isSelected
                }
            }
        }
        
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch (indexPath.row){
        case FPSegmentView.INDEX_REASON_LABEL:
            if isEnableReasonAICell{
                return UITableView.automaticDimension
            }else{
                return 50
            }
        case FPSegmentView.INDEX_SEGMENT,(tableRowCount-1):
            if tableRowCount > 2 {
                return UITableView.automaticDimension
            }else{
                return 50
            }
        default:
            return UITableView.automaticDimension
        }
    }
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
}

//MARK: SegmentControlCellDelegate
extension FPSegmentView: SegmentControlDelegate {
    func segmentValueChangedAt(indexPath index: IndexPath?, withSelectedIndex: Int) {
        let oldValue = self.valueString
        setValueFromSelectedIndex(withSelectedIndex)
        self.cellItem?.value = self.valueString
        updateSelectedValue()

        let shouldChangeLayout =
        self.fieldItem?.openDeficencySelectedOption(value: oldValue) == true ||
        self.fieldItem?.openDeficencySelectedOption(value: self.valueString) == true

        guard shouldChangeLayout else { return }

        stopRecorder()

        UIView.performWithoutAnimation {
            refreshTableRowCountAndReload()
            notifyTableToUpdateHeight()
        }

        // reload collection AFTER layout settled
        DispatchQueue.main.async {
            self.delegate.reloadCollectionAt(index: self.collectionIndex)
        }
    }
}

//MARK: CustomReasonTextFieldCellDelegate
extension FPSegmentView: CustomReasonTextFieldTableViewCellDelegate {
    func updateCustomReasonWith(_ value: String, otherData: [String : Any]) {
       let servity = otherData["severity"] as? String ?? ""
        let dueDate = otherData["dueDate"] as? Int ?? nil
        let recommendation = otherData["recommendation"] as? String ?? ""
        let recommendationID = self.cellItem?.customReason?.recommendations?.first?.id
        self.cellItem?.customReason = FPReasonsComponent().getCustomReason(value, templateId: self.cellItem?.fieldTemplateId ?? "", objectId: self.cellItem?.customReason?.objectID ?? "",severity: servity,dueDate: dueDate,recommendation: recommendation, recommendationID: recommendationID)
        updateSelectedValue()
    }
    
    func updateCustomAiSuggestionWith() {
        //self.delegate.reloadCollectionAt(index: self.collectionIndex)
    }
}


