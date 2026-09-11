//
//  TableContentCollectionViewCell.swift
//  crm
//
//  Created by Apple on 07/08/23.
//  Copyright © 2023 SmartServ. All rights reserved.
//

import UIKit
internal import SSMediaManager
internal import IQKeyboardManagerSwift

class TableContentCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var btnAddAttachment: UIButton!
    @IBOutlet weak var tblTextField: UITextField!
    @IBOutlet weak var tblDropdownField: ZTDropDown!
    @IBOutlet weak var tblTextView: UITextView!
    @IBOutlet weak var viewBarcode: UIView!
    @IBOutlet weak var imgBarcode: UIImageView!
    @IBOutlet weak var btnBarcode: UIButton!
    @IBOutlet weak var btnAction: UIButton!
    var data: ColumnData?{
        didSet{
            if let columnData  = data{
                setupView(column: columnData)
            }
        }
    }
    var parentTableIndex:IndexPath?
    var childTableIndex:IndexPath?{
        didSet{
            if let indexPath = childTableIndex{
                switch (column: indexPath.row, row: indexPath.section) {
                    //Action column
                case (1, _):
                    tblTextField.tag = -100 // Added tag to identify action field
                    break
                default:
                    break
                }
            }
        }
    }
    var pickerArray: [DropdownOptions]?
    var fieldDetails:FPFieldDetails?
    var pickerView: UIPickerView?
    var delegate:TableContentCellDelegate?
    /// Holds the formatted date/time string while the picker wheel is spinning.
    /// Written by datePickerValueChanged/yearPickerValueChanged instead of mutating
    /// self.data?.value directly — mutating data.value triggers didSet → setupView →
    /// resignFirstResponder, which dismisses the picker before the user taps Done.
    private var pendingPickerValue: String?
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
    var strFPDateFormat: String {
        var strFormat = ""
        var dateFormatType: FPFORM_DATE_FORMAT = .DATE
        
        if let columnData  = data{
            if columnData.dataType == "TIME"{
                dateFormatType = .TIME
            }else if columnData.dataType == "DATE_TIME"{
                dateFormatType = .DATE_TIME
            }else if columnData.dataType == "YEAR"{
                dateFormatType = .YEAR
            }else{
                dateFormatType = .DATE
            }
        }
        if dateFormatType == .DATE_TIME, let dateFormat = data?.dateFormat{
            strFormat = dateFormat
        }else{
            strFormat = dateFormatType.rawValue
        }
        strFormat = dateFormatType.rawValue
        return strFormat
    }
    
    var defaultDeficeincyOptions:[DropdownOptions]{
        let yesOption = DropdownOptions(key:FPStringBoolIntValue.string(FPLocalizationHelper.localize("Yes")) , value: FPStringBoolIntValue.string(FPLocalizationHelper.localize("Yes")), label: FPStringBoolIntValue.string(FPLocalizationHelper.localize("Yes")))
        let noOption = DropdownOptions(key:FPStringBoolIntValue.string(FPLocalizationHelper.localize("No")) , value: FPStringBoolIntValue.string(FPLocalizationHelper.localize("No")), label: FPStringBoolIntValue.string(FPLocalizationHelper.localize("No")))
        let naOption = DropdownOptions(key:FPStringBoolIntValue.string("NA") , value: FPStringBoolIntValue.string("NA"), label: FPStringBoolIntValue.string("NA"))
        return [yesOption, noOption, naOption]
    }
    var generateDynamically:Bool = false
    var isUITypeDeficiency:Bool = false

    /// When set, matching substrings are highlighted in visible text controls (read-only / display contexts).
    /// Configure this before setting `data` so `setupView` applies highlighting for the correct column.
    var searchHighlightQuery: String?

    /// When true, search highlighting uses case-sensitive matching (should match `TableRowTextSearch` / user default).
    var searchHighlightCaseSensitive: Bool = false

    /// When non-empty, only these column `key`s get highlights (same scoping as table search). Empty = all columns.
    var searchHighlightColumnKeys: Set<String> = []

    override func prepareForReuse() {
        super.prepareForReuse()
        searchHighlightQuery = nil
        searchHighlightCaseSensitive = false
        searchHighlightColumnKeys = []
        pendingPickerValue = nil
        stripSearchHighlightFormatting()
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        self.tblTextField.iq.toolbar.doneBarButton.setTarget(self, action: #selector(onDoneButtonTapped(sender:)))
        self.tblTextView.iq.toolbar.doneBarButton.setTarget(self, action: #selector(onDoneButtonTapped(sender:)))
        self.imgBarcode.setImageColor(color: UIColor(named: "BT-Primary") ?? .black)
    }
    
    @objc func onDoneButtonTapped(sender: UIBarButtonItem) {
        if self.tblTextView.isFirstResponder {
            self.tblTextView.resignFirstResponder()
        }
        if self.tblTextField.isFirstResponder {
            self.tblTextField.resignFirstResponder()
        }
    }

    @IBAction func didTapAddAttachments(_ sender: Any) {
        delegate?.showAddAttachment(at: childTableIndex!, with: data!)
    }
    
    
    private func setupView(column:ColumnData){
        self.btnAction.isHidden = true
        self.tblTextView.isUserInteractionEnabled = !(column.readonly ?? false)
        self.tblTextField.isUserInteractionEnabled = !(column.readonly ?? false)
        self.tblDropdownField.isUserInteractionEnabled = !(column.readonly ?? false)
        self.tblDropdownField.isHidden = true
        if(column.key == "action-checkbox" && column.uiType == "CHECKBOX"){
            self.btnAction.isHidden = false
            self.btnAddAttachment.isHidden = true
            self.tblTextView.isHidden = true
            self.tblTextField.isHidden = true
        }else if column.uiType == "DEFICIENCY" || column.uiType == "DROPDOWN"{
            self.generateDynamically = column.generateDynamically ?? false
            self.isUITypeDeficiency = column.uiType == "DEFICIENCY"
            self.btnAddAttachment.isHidden = true
            self.tblTextView.isHidden = true
            self.tblTextField.isHidden = true
            self.tblDropdownField.isHidden = false
            let displayValue = FPUtility().getSQLiteSpecialCharsCompatibleString(value: column.value, isForLocal: false) ?? column.value
            self.tblDropdownField.text = displayValue
            self.tblDropdownField.checkMarkEnabled = false
            self.tblDropdownField.isSearchEnable = (column.uiType == "DROPDOWN")
            self.tblDropdownField.itemsColor = .black
            self.tblDropdownField.rowHeight = 40
            self.tblDropdownField.selectedRowColor = #colorLiteral(red: 0.9411764706, green: 0.937254902, blue: 0.9647058824, alpha: 1)
            self.tblDropdownField.arrowSize = 15
            self.setTextFieldByType(column)
        }else if(column.uiType == "ATTACHMENT"){
            self.btnAddAttachment.isHidden = false
            self.tblTextView.isHidden = true
            self.tblTextField.isHidden = true
            let dataObject = column.value.getDictonary()
            if(!dataObject.isEmpty){
                if let files =  dataObject["files"] as? [[String:Any]],!files.isEmpty{
                    self.btnAddAttachment.setTitle(FPLocalizationHelper.localize("lbl_View"), for: .normal)
                }else{
                    if let files =  dataObject["filesToUpload"] as? [[String:Any]],!files.isEmpty{
                        var mediasAdded:[SSMedia] = []
                        files.forEach { file in
                            if((FPFormDataHolder.shared.tableMediaCache.first(where: {$0.mediaAdded.contains(where: {$0.name == file["altText"] as? String ?? "" })})) == nil){
                                
                                let mediaAdded = SSMedia(name:file["altText"] as? String ?? "",mimeType:file["type"] as? String ?? "",filePath: file["localPath"] as? String ?? "", moduleType: .forms)
                                mediasAdded.append(mediaAdded)
                            }
                        }
                        if mediasAdded.count>0{
                            if let mediaIndex = FPFormDataHolder.shared.tableMediaCache.firstIndex(where: {
                                $0.parentTableIndex == parentTableIndex && 
                                $0.childTableIndex == childTableIndex &&
                                $0.formSessionId == FPFormDataHolder.shared.currentFormSessionId
                            }){
                                var tableMedia = FPFormDataHolder.shared.tableMediaCache[mediaIndex]
                                tableMedia.mediaAdded = mediasAdded
                                FPFormDataHolder.shared.addUpdateTableMediaCache(media: tableMedia)
                                
                            }else{
                                let tableMedia = TableMedia(columnIndex:childTableIndex!.row-2,key:column.key,parentTableIndex: parentTableIndex,childTableIndex: childTableIndex, mediaAdded: mediasAdded, mediaDeleted: [], formSessionId: FPFormDataHolder.shared.currentFormSessionId)
                                FPFormDataHolder.shared.addUpdateTableMediaCache(media: tableMedia)
                            }
                        }
                        
                        self.btnAddAttachment.setTitle(FPLocalizationHelper.localize("lbl_View"), for: .normal)
                    }else{
                        self.btnAddAttachment.setTitle(FPLocalizationHelper.localize("lbl_Add"), for: .normal)
                    }
                }
            }else{
                self.btnAddAttachment.setTitle(FPLocalizationHelper.localize("lbl_Add"), for: .normal)
            }
            
        }else{
            self.btnAddAttachment.isHidden = true
            self.tblTextView.isHidden = true
            self.tblTextField.isHidden = true
            self.tblDropdownField.isHidden = true
            self.tblTextField.delegate = self
            self.tblTextView.delegate = self
            self.tblTextField.clearDropdownView()
            if column.dataType == "DATE" || column.dataType == "TIME" || column.dataType == "DATE_TIME" || column.dataType == "YEAR"{
                self.tblTextField.isHidden = false
                self.tblTextField.text = ""
                if !column.value.trim.isEmpty{
                    if let date = FPUtility.getOPDateFrom(column.value) {
                        self.tblTextField.text = self.formateDateAccordingToMode(date: date)
                    }else if let fixedDate = fixDateFormat(column.value) {
                        self.tblTextField.text = self.formateDateAccordingToMode(date: fixedDate)
                    }else{}
                }
            }else{
                self.tblTextView.isEditable = !(column.readonly ?? false)
                self.tblTextView.isHidden = false
                let displayValue = FPUtility().getSQLiteSpecialCharsCompatibleString(value: column.value, isForLocal: false) ?? column.value
                self.tblTextView.text = displayValue
            }
        }
        self.tblTextView.tag = childTableIndex!.row-2
        self.tblTextField.tag = childTableIndex!.row-2
        self.btnAddAttachment.tag = childTableIndex!.row-2
        applySearchHighlightIfNeeded()
    }

    private func applySearchHighlightIfNeeded() {
        guard let raw = searchHighlightQuery?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty,
              let column = data else {
            stripSearchHighlightFormatting()
            return
        }
        if !searchHighlightColumnKeys.isEmpty && !searchHighlightColumnKeys.contains(column.key) {
            stripSearchHighlightFormatting()
            return
        }
        let compareOptions: String.CompareOptions = searchHighlightCaseSensitive ? [] : [.caseInsensitive, .diacriticInsensitive]
        let haystack = TableRowTextSearch.searchableText(for: column)
        guard TableRowTextSearch.containsSearchSubstring(haystack, raw, options: compareOptions) else {
            stripSearchHighlightFormatting()
            return
        }

        let font = UIFont.preferredFont(forTextStyle: .body)
        if !tblTextView.isHidden {
            let base = tblTextView.text ?? ""
            tblTextView.attributedText = TableContentCollectionViewCell.attributedText(
                full: base,
                highlight: raw,
                baseFont: font,
                textColor: .label,
                compareOptions: compareOptions
            )
        }
        if !tblTextField.isHidden, tblTextField.inputView == nil, let base = tblTextField.text {
            tblTextField.attributedText = TableContentCollectionViewCell.attributedText(
                full: base,
                highlight: raw,
                baseFont: font,
                textColor: .label,
                compareOptions: compareOptions
            )
        }
        if !tblDropdownField.isHidden, let base = tblDropdownField.text {
            tblDropdownField.attributedText = TableContentCollectionViewCell.attributedText(
                full: base,
                highlight: raw,
                baseFont: font,
                textColor: .label,
                compareOptions: compareOptions
            )
        }
    }

    /// Removes yellow search highlight while keeping visible text (covers reuse and “search cleared” cases).
    private func stripSearchHighlightFormatting() {
        let font = UIFont.preferredFont(forTextStyle: .body)
        let color = UIColor.label
        if !tblTextView.isHidden {
            let plain = tblTextView.attributedText?.string ?? tblTextView.text ?? ""
            tblTextView.attributedText = NSAttributedString(string: plain, attributes: [.font: font, .foregroundColor: color])
        }
        if !tblTextField.isHidden, tblTextField.inputView == nil {
            let plain = tblTextField.attributedText?.string ?? tblTextField.text ?? ""
            tblTextField.attributedText = NSAttributedString(string: plain, attributes: [.font: font, .foregroundColor: color])
        }
        if !tblDropdownField.isHidden {
            let plain = tblDropdownField.attributedText?.string ?? tblDropdownField.text ?? ""
            tblDropdownField.attributedText = NSAttributedString(string: plain, attributes: [.font: font, .foregroundColor: color])
        }
    }

    private static func attributedText(full: String, highlight: String, baseFont: UIFont, textColor: UIColor, compareOptions: String.CompareOptions) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: full, attributes: [
            .font: baseFont,
            .foregroundColor: textColor
        ])
        for range in TableRowTextSearch.searchRanges(of: highlight, in: full, options: compareOptions) {
            let nsRange = NSRange(range, in: full)
            attributed.addAttribute(.backgroundColor, value: UIColor.systemYellow.withAlphaComponent(0.35), range: nsRange)
        }
        return attributed
    }
    
    private func setTextFieldByType(_ rowData: ColumnData) {
//        self.tblTextView.disablePaste()
        self.tblTextView.tintColor = UIColor.blue

        switch rowData.uiType {
        case "DROPDOWN","DEFICIENCY":
            self.tblTextField.isHidden = true
            self.tblDropdownField.isHidden = false
            self.pickerArray = []
            let selOption = DropdownOptions(key:FPStringBoolIntValue.string(FPLocalizationHelper.localize("SELECT")) , value: FPStringBoolIntValue.string(FPLocalizationHelper.localize("SELECT")), label: FPStringBoolIntValue.string(FPLocalizationHelper.localize("SELECT")))
            self.pickerArray?.append(selOption)
            if rowData.uiType == "DEFICIENCY", rowData.dropDownOptions == nil{
                self.pickerArray?.append(contentsOf: defaultDeficeincyOptions)
            }else{
                self.pickerArray?.append(contentsOf: rowData.dropDownOptions ?? [])
            }
            let arrStrOptions = self.pickerArray?.compactMap({ self.generateDynamically || self.isUITypeDeficiency ? $0.label.stringValue().handleAndDisplayApostrophe() : $0.key.stringValue().handleAndDisplayApostrophe()}) ?? []
            self.tblDropdownField.optionArray = arrStrOptions
           
            if self.isUITypeDeficiency, rowData.dropDownOptions != nil{
                let compareValue = FPUtility().getSQLiteSpecialCharsCompatibleString(value: rowData.value, isForLocal: false) ?? rowData.value
                if let index = self.pickerArray?.firstIndex(where: { $0.value.stringValue().handleAndDisplayApostrophe().lowercased() == compareValue.lowercased() }){
                    self.tblDropdownField.selectedIndex = index
                    self.tblDropdownField.text = self.pickerArray?[index].label.stringValue().handleAndDisplayApostrophe()
                }
            }else{
                if !rowData.value.isEmpty{
                    let compareValue = FPUtility().getSQLiteSpecialCharsCompatibleString(value: rowData.value, isForLocal: false) ?? rowData.value
                    if let index = arrStrOptions.firstIndex(where: { $0.lowercased() == compareValue.lowercased() }){
                        self.tblDropdownField.selectedIndex = index
                    }
                }
            }
            self.tblDropdownField.didSelect{(selectedText , index ,id) in
                self.pickedValue(index: index)
            }
            self.tblDropdownField.didEndSelect{(selectedText) in
                DispatchQueue.main.async {
                    self.tblDropdownField.hideList()
                }
                if var columnData = self.data{
                    let dbValue = selectedText.handleAndDisplayApostrophe()
                    columnData.value = dbValue
                    self.delegate?.updateData(at: self.childTableIndex!, with: columnData, filedData: nil)
                }
            }
        default:
            self.setTextFieldByInputType(rowData)
        }
        
    }
    private func setTextFieldByInputType(_ rowData: ColumnData) {
        self.tblTextView.isHidden = true
        self.tblTextView.isEditable = false
        self.tblTextField.isHidden = true
        switch rowData.dataType {
        case "NUMBER":
            self.tblTextView.isEditable = !(rowData.readonly ?? false)
            self.tblTextView.isHidden = false
            self.tblTextView.keyboardType = .numbersAndPunctuation
            self.tblTextView.inputView = nil
            self.tblTextView.disablePaste()
            self.tblTextView.disableCut()
//            self.tblTextView.inputAccessoryView = self.accessoryToolbar
        case "TEXT":
            self.tblTextView.isEditable = !(rowData.readonly ?? false)
            self.tblTextView.isHidden = false
            self.tblTextView.keyboardType = .default
            self.tblTextView.inputView = nil
//            self.tblTextView.inputAccessoryView = self.accessoryToolbar
            self.tblTextView.allowCut()
            self.tblTextView.allowPaste()
        case "DATE", "TIME", "DATE_TIME":
            self.tblTextField.isHidden = false
            self.tblTextField.disablePaste()
            self.tblTextField.disableCut()
            self.tblTextField.clearDropdownView()
            self.tblTextField.tintColor = UIColor.blue
            let datePicker = UIDatePicker()
            datePicker.datePickerMode = .date
            if rowData.dataType == "TIME"{
                datePicker.datePickerMode = .time
            }else if rowData.dataType == "DATE_TIME"{
                datePicker.datePickerMode = .dateAndTime
            }else{}
            if #available(iOS 13.4, *) {
                datePicker.preferredDatePickerStyle = .wheels
            }
            if !rowData.value.trim.isEmpty, let date = FPUtility.getOPDateFrom(rowData.value) {
                self.tblTextField.text = self.formateDateAccordingToMode(date: date)
            }else if let fixedDate = fixDateFormat(rowData.value) {
                self.tblTextField.text = self.formateDateAccordingToMode(date: fixedDate)
            }else{}
            
            if !rowData.value.trim.isEmpty, let date = FPUtility.getOPDateFrom(rowData.value) {
                datePicker.setDate(date, animated: false)
            }else if let fixedDate = fixDateFormat(rowData.value) {
                datePicker.setDate(fixedDate, animated: false)
            } else {
                datePicker.sendActions(for: .valueChanged)
            }
            datePicker.addTarget(self, action: #selector(datePickerValueChanged), for: .valueChanged)
            self.tblTextField.inputView = datePicker
//            self.tblTextField.inputAccessoryView = self.accessoryToolbar
        case "YEAR":
            self.tblTextField.isHidden = false
            self.tblTextField.disablePaste()
            self.tblTextField.disableCut()
            self.tblTextField.clearDropdownView()
            self.tblTextField.tintColor = UIColor.blue
            let datePicker = FPMonthYearDatePicker()
            datePicker.mode = .year
            if !rowData.value.trim.isEmpty, let date = FPUtility.getOPDateFrom(rowData.value) {
                self.tblTextField.text = self.formateDateAccordingToMode(date: date)
            }else if let fixedDate = fixDateFormat(rowData.value) {
                self.tblTextField.text = self.formateDateAccordingToMode(date: fixedDate)
            }else{}
            
            if !rowData.value.trim.isEmpty, let date = FPUtility.getOPDateFrom(rowData.value) {
                datePicker.setDate(date, animated: false)
            }else if let fixedDate = fixDateFormat(rowData.value) {
                datePicker.setDate(fixedDate, animated: false)
            } else {
//                datePicker.sendActions(for: .valueChanged)
            }
            datePicker.addTarget(self, action: #selector(yearPickerValueChanged), for: .valueChanged)
            self.tblTextField.inputView = datePicker
//            self.tblTextField.inputAccessoryView = self.accessoryToolbar
        default :
            self.tblTextView.isHidden = false
        }
    }
    
    @objc func datePickerValueChanged(sender: UIDatePicker) {
        self.tblTextField.text = self.formateDateAccordingToMode(date: sender.date)
        // Store in pendingPickerValue instead of self.data?.value.
        // Writing to self.data?.value triggers data.didSet → setupView → resignFirstResponder,
        // which dismisses the picker before the user taps Done.
        pendingPickerValue = FPUtility.getStringWithTZFormat(sender.date)
    }

    @objc func yearPickerValueChanged(sender: FPMonthYearDatePicker) {
        self.tblTextField.text = self.formateDateAccordingToMode(date: sender.date)
        pendingPickerValue = FPUtility.getStringWithTZFormat(sender.date)
    }
    
    func formateDateAccordingToMode(date:Date) -> String {
        return date.convertUTCToLocalInString(with: strFPDateFormat)
    }
    
    func fixDateFormat(_ dateString: String, format:String = "yyyy-MM-dd'T'HH:mm:ss.SSSZ") -> Date? {
        let fixedDateString = dateString.replacingOccurrences(of: "__X2E__", with: ".")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        
        if let fixedDate = dateFormatter.date(from: fixedDateString) {
            return fixedDate
        } else {
            return nil
        }
    }
    
    private func saveText(text:String){
        if var columnData = data{
            var tblValue = text
            if !text.trim.isEmpty, data?.dataType == "DATE" || data?.dataType == "TIME" || data?.dataType == "DATE_TIME" || data?.dataType == "YEAR"{
                // Use the staged picker value (set during wheel spin) so we don't read stale data.value.
                tblValue = pendingPickerValue ?? columnData.value
            }
            pendingPickerValue = nil
            let dbValue = FPUtility().getSQLiteSpecialCharsCompatibleString(value: tblValue, isForLocal: true) ?? text
            columnData.value = dbValue
            delegate?.updateData(at: childTableIndex!, with: columnData, filedData: nil)
        }
    }
    
    private func deleteRow(){
        delegate?.deleteRow(at:childTableIndex!)
    }
    
    private func duplicateRow(){
        delegate?.duplicateRow(at: childTableIndex!, parentTableIndex: parentTableIndex)
    }
}


extension TableContentCollectionViewCell: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.pickerArray?.count ?? 0
    }
}

extension TableContentCollectionViewCell: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        let option = self.pickerArray?[row]
        return self.generateDynamically || self.isUITypeDeficiency ? option?.label.stringValue().handleAndDisplayApostrophe() ?? "" : option?.key.stringValue().handleAndDisplayApostrophe() ?? ""
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        self.pickedValue(index: row)
    }
    
    func pickedValue(index: Int) {
        guard let array = self.pickerArray, array.count > 0 else {
            return
        }
        let value = self.generateDynamically ? pickerArray?[index].label.stringValue().handleAndDisplayApostrophe() ?? "" : pickerArray?[index].value.stringValue().handleAndDisplayApostrophe() ?? ""
        let displayvalue = pickerArray?[index].label.stringValue().handleAndDisplayApostrophe() ?? ""
        if value ==  FPLocalizationHelper.localize("SELECT") {
            self.tblTextField.text = ""
            self.tblDropdownField.text = ""
            self.saveText(text: "")
            return
        }else if value == "Duplicate Row" {
            duplicateRow()
            if self.tblTextField.isFirstResponder {
                self.tblTextField.resignFirstResponder()
            }
            return
        }
        if(self.childTableIndex!.row != 1 ){
            self.tblTextField.text = value
            self.tblDropdownField.text = value
            if isUITypeDeficiency{
                self.tblDropdownField.text = displayvalue
            }
            self.saveText(text: value)
        }else{
            deleteRow()
            if self.tblTextField.isFirstResponder {
                self.tblTextField.resignFirstResponder()
            }
        }
    }
}

extension TableContentCollectionViewCell: UITextFieldDelegate {
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        self.setTextFieldByType(self.data!)
        if self.data?.dataType == "DATE" || self.data?.dataType == "TIME" || self.data?.dataType == "DATE_TIME" || self.data?.dataType == "YEAR"{
            if let value = textField.text, value.trim.isEmpty{
                // Use pendingPickerValue instead of self.data?.value to avoid triggering
                // data.didSet → setupView → resignFirstResponder on first open with empty value.
                pendingPickerValue = FPUtility.getStringWithTZFormat(Date())
            }
        }
        return true
    }
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField.text?.trim.isEmpty ?? false, self.data?.dataType == "DATE" || self.data?.dataType == "TIME" || self.data?.dataType == "DATE_TIME" || self.data?.dataType == "YEAR"{
            self.data?.value = ""
        }
        self.saveText(text: textField.text  ?? "")
    }
}
extension TableContentCollectionViewCell: UITextViewDelegate {
    func textViewDidEndEditing(_ textView: UITextView) {
        self.saveText(text: textView.text ?? "")
    }
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        self.setTextFieldByType(self.data!)
        return true
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\t" {
            if let indexPath = childTableIndex,
               let collectionView = self.superview as? UICollectionView {
                let nextIndexPath = IndexPath(item: indexPath.item + 1, section: indexPath.section)
                if let nextCell = collectionView.cellForItem(at: nextIndexPath) as? TableContentCollectionViewCell {
                    nextCell.tblTextView.becomeFirstResponder()
                    return false
                }
            }
        }
        return true
    }

}

protocol TableContentCellDelegate{
    func deleteRow(at index:IndexPath)
    func duplicateRow(at index:IndexPath, parentTableIndex: IndexPath?)
    func updateData(at index:IndexPath, with data:ColumnData, filedData filed:FPFieldDetails?)
    func showAddAttachment(at index:IndexPath,with data:ColumnData)
}
