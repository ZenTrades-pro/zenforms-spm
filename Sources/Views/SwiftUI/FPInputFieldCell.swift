//
//  FPInputFieldCell.swift
//  crm
//
//  Created by apple on 19/11/25.
//  Copyright © 2025 SmartServ. All rights reserved.


import SwiftUI


struct FPInputFieldCell: View {
    
    let fieldItem: FPFieldDetails
    var ticketId:NSNumber?
    var datePickerMode: UIDatePicker.Mode?
    var sectionIndex:Int
    var fieldIndex:Int
    var isNew: Bool
    
    @State var fieldValue: String
    @State var fieldSelectedDate: Date?
        
    var onBarcodeClicked: ((_ fieldTemplateId:String?, _ fieldSectionId:NSNumber?)-> Void)?
    var onFieldInputChanged: ((_ sectionIndex: Int, _ fieldIndex: Int, _ pickerIndex: Int?, _ value: String?, _ date: Date?,_ isSectionDuplicationField: Bool)-> Void)?
    var onBarcodeInputChanged: ((String)-> Void)?

    @FocusState private var isInputFocused: Bool

    private var fieldDisplayName: String {
        return fieldItem.displayName?.handleAndDisplayApostrophe() ?? ""
    }
    
    private var strFPDateFormat: String {
        var strFormat = ""
        var dateFormatType: FPFORM_DATE_FORMAT = .DATE
        if fieldItem.getDataType() == .YEAR {
            dateFormatType = .YEAR
            strFormat = dateFormatType.rawValue
            return strFormat
        }
        if let mode = self.datePickerMode{
            if mode == .date {
                dateFormatType = .DATE
            }else if mode == .time{
                dateFormatType = .TIME
            }else{
                dateFormatType = .DATE_TIME
            }
        }
        if dateFormatType == .DATE_TIME, let dict = fieldItem.options?.getDictonary(), let dateFormate = dict["dateFormat"] as? String{
            strFormat = dateFormate
        }else{
            strFormat = dateFormatType.rawValue
        }
        return strFormat
    }
    
    private var isSectionDuplicationField: Bool {
        return fieldItem.isSectionDuplicationField
    }

    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if fieldItem.mandatory{
                SwiftUI.Text(fetchAttributedString())
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }else{
                SwiftUI.Text(fieldDisplayName)
                    .font(.headline)
                    .foregroundColor(Color("ZT-Black"))
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if showTextNumberAutoPopulateView(){
                textNumberAutoPopulateView
            }
            else if fieldItem.getUIType() == .TEXTAREA{
                textAreaInputView
            }
            else if showDateInputView(){
                if fieldItem.getDataType() == .YEAR{
                    yearPickerInputView
                }else{
                    datePickerInputView
                }
            }
            else if fieldItem.getUIType() == .DROPDOWN{
                ZTDropdownView(
                    selectedItem: fieldValue,
                    placeholder: fieldDisplayName,
                    items: fieldItem.getDropdownOptions().map(
                        {
                            $0.label ?? ""
                        }),
                    isSearchable: !self.isSectionDuplicationField) { selectedText in
                        onFieldInputChanged?(sectionIndex, fieldIndex, nil, selectedText.handleAndDisplayApostrophe(), nil, isSectionDuplicationField )
                    }
            }else{}
        }
        .padding(10)
        .id("\(sectionIndex)_\(fieldIndex)_\(fieldItem.name ?? "")")
        .onAppear {
            setItemValue()
        }
    }
    
    func fetchAttributedString() -> AttributedString {
        let fontAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.preferredFont(forTextStyle: .headline), .foregroundColor: UIColor.black]
        let baseString =  NSAttributedString(string: " \(fieldDisplayName)", attributes: fontAttributes)
        let colrattributes: [NSAttributedString.Key: Any] = [.font: UIFont.preferredFont(forTextStyle: .headline), .foregroundColor: UIColor.red]
        let starString =  NSAttributedString(string: "*", attributes: colrattributes)
        let mutableString = NSMutableAttributedString(attributedString: starString)
        mutableString.append(baseString)
        return AttributedString(mutableString)
    }

    private var textNumberAutoPopulateView: some View {
        HStack(spacing: 4) {
            TextField(fieldItem.getUIType() == .AUTO_POPULATE ? fieldItem.value ?? "" : fieldDisplayName, text: $fieldValue)
                .focused($isInputFocused)
                .withClearButton(text: $fieldValue, isFocused: Binding(get: { self.isInputFocused }, set: { self.isInputFocused = $0 }))
                .padding(.horizontal, 8)
                .font(.subheadline)
                .foregroundStyle(Color("ZT-Black"))
                .frame(height: 50)
                .autocorrectionDisabled(true)
                .keyboardType(fieldItem.getDataType() == .NUMERICAL ? .decimalPad : .default)
                .textInputAutocapitalization(fieldItem.scannable || fieldItem.getUIType() == .SCANNER ? .none : .sentences)
                .onChange(of: fieldValue) { newValue in
                    if fieldItem.getDataType() == .NUMERICAL{
                        fieldValue =  newValue.filter { "0123456789.".contains($0) }
                    }else{
                        fieldValue = newValue
                    }
                    if !fieldItem.scannable {
                        onFieldInputChanged?(sectionIndex, fieldIndex, nil, fieldValue, nil, isSectionDuplicationField)
                    }
                }
                .onChange(of: isInputFocused) { isFocused in
                    if !isFocused {
                        if(fieldItem.scannable && !fieldValue.isEmpty){
                            onBarcodeInputChanged?(fieldValue)
                        }else{
                            onFieldInputChanged?(sectionIndex, fieldIndex, nil, fieldValue, nil, isSectionDuplicationField )
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .disabled(fieldItem.readOnly)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            if isFieldScannble(){
                Button(action: {
                    onBarcodeClicked?(fieldItem.templateId, fieldItem.sectionId)
                }) {
                    Image(systemName: "barcode.viewfinder")
                        .foregroundStyle(Color("BT-Primary"))
                        .font(.title)
                }
                .frame(width: 40, height: 40)
            }
        }
    }
    
    private var textAreaInputView: some View {
        TextEditor(text: $fieldValue)
            .frame(height: 100)
            .font(.subheadline)
            .focused($isInputFocused)
            .autocorrectionDisabled(true)
            .padding(8)
            .disabled(fieldItem.readOnly)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .onChange(of: fieldValue) { newValue in
                onFieldInputChanged?(sectionIndex, fieldIndex, nil, newValue, nil, isSectionDuplicationField)
            }
            .onChange(of: isInputFocused) { isFocused in
                if !isFocused {
                    onFieldInputChanged?(sectionIndex, fieldIndex, nil, fieldValue, nil, isSectionDuplicationField )
                }
            }
    }
    
    private var datePickerInputView: some View{
        ZTDateTextFieldView(
            date: $fieldSelectedDate,
            datePickerMode: datePickerMode,
            placeholder: fieldDisplayName,
            displayFormat: strFPDateFormat,
            minDate: nil,
            maxDate: nil,
            showClearButton: true) { date in
                if let date {
                    fieldSelectedDate = date
                    fieldValue = self.formateDateAccordingToMode(date: date)
                }else{
                    fieldValue = ""
                }
                onFieldInputChanged?(sectionIndex, fieldIndex, nil, date != nil ? FPUtility.getStringWithTZFormat(date!) : "", date, isSectionDuplicationField )
            }
            .padding(.horizontal, 8)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var yearPickerInputView: some View{
        ZTYearPickerView(
            yearValue: fieldItem.value ?? "",
            selectedDate: fieldSelectedDate,
            minimumDate: Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date(),
            maximumDate: Calendar.current.date(byAdding: .year, value: 10, to: Date()) ?? Date(),
            placeholder: fieldDisplayName) { date in
                if let date {
                    fieldSelectedDate = date
                    fieldValue = self.formateDateAccordingToMode(date: date)
                }else{
                    fieldValue = ""
                }
                onFieldInputChanged?(sectionIndex, fieldIndex, nil, date != nil ? FPUtility.getStringWithTZFormat(date!) : "", date, isSectionDuplicationField )
            }
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    //MARK: Helper Methods
    
    func showTextNumberAutoPopulateView() -> Bool{
        let autoPopulateNScanner = fieldItem.getUIType() == .AUTO_POPULATE || fieldItem.getUIType() == .SCANNER
        var isTextNNumberInput: Bool = false
        
        if fieldItem.getUIType() == .INPUT {
            isTextNNumberInput =  fieldItem.getDataType() == .NUMERICAL || fieldItem.getDataType() == .TEXT
        }
        
        return autoPopulateNScanner || isTextNNumberInput
    }
    
    func isFieldScannble() -> Bool{
        return fieldItem.scannable || fieldItem.getUIType() == .SCANNER
    }
    
    func showDateInputView() -> Bool{
        if fieldItem.getUIType() == .INPUT {
            return fieldItem.getDataType() == .DATE || fieldItem.getDataType() == .DATE_TIME || fieldItem.getDataType() == .TIME || fieldItem.getDataType() == .YEAR
        }
        return false
    }
    
    func setItemValue(){
        if(fieldItem.getUIType() == .AUTO_POPULATE){
            if let options = fieldItem.options?.getDictonary(){
                if let computedFields = UserDefaults.computedFields,
                   let ticketFields = computedFields[self.ticketId?.stringValue ?? ""] as? [String:Any]{
                    if let entityType = options["entityType"] as? String, let entity = options["entity"] as? String{
                        if let entityObj =  ticketFields[entityType] as? [String:Any]{
                            if let value = entityObj[entity] as? String{
                                fieldValue = value
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onFieldInputChanged?(sectionIndex, fieldIndex, nil, value, nil, isSectionDuplicationField)
                                }
                            }
                        }
                    }
                }
            }
        }else{
            if let value = fieldItem.value, !value.trim.isEmpty{
                if fieldItem.getDataType() == .DATE || fieldItem.getDataType() == .DATE_TIME || fieldItem.getDataType() == .TIME || fieldItem.getDataType() == .YEAR{
                    if let date = FPUtility.getOPDateFrom(value) {
                        fieldSelectedDate = date
                        fieldValue = self.formateDateAccordingToMode(date: date)
                    }else if let fixedDate = fixDateFormat(value) {
                        fieldSelectedDate = fixedDate
                        fieldValue = self.formateDateAccordingToMode(date: fixedDate)
                    }else{}
                }else{
                    fieldValue = FPUtility().fetchCompataibleSpecialCharsStringFromDB(strInput: value)
                }
            } else {
                fieldValue = ""
            }
        }
        
//        if self.isNew, let defaultVal = fieldItem.defaultValue, !defaultVal.trim.isEmpty, let val = fieldItem.value, val.trim.isEmpty{
//            fieldValue = FPUtility().fetchCompataibleSpecialCharsStringFromDB(strInput: defaultVal)
//        }
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
}


struct ClearButton: ViewModifier {
    @Binding var text: String
    @Binding var isInputFocused: Bool
    func body(content: Content) -> some View {
        HStack {
            content
            if isInputFocused, !text.isEmpty {
                Button(action: {
                    self.text = ""
                }) {
                    Image(systemName: "multiply.circle.fill")
                        .foregroundColor(Color(UIColor.opaqueSeparator))
                        .padding(.trailing, 8)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
            }
        }
    }
}
extension View {
    func withClearButton(text: Binding<String>, isFocused: Binding<Bool>) -> some View {
        self.modifier(ClearButton(text: text, isInputFocused: isFocused))
    }
    
    func onViewDidLoad(_ callback: @escaping (()->Void) ) -> some View {
        self.modifier(ViewDidLoadModifier(onCallback: callback))
    }
}


struct ViewDidLoadModifier: ViewModifier {
    
    @State private var viewDidLoad: Bool = false
    private let callback: (()->Void)
    
    init(onCallback callback: @escaping (()->Void) ) {
        self.callback = callback
    }
    
    public func body(content: Content) -> some View {
        if !viewDidLoad {
            viewDidLoad = true
            callback()
        }
        return content
    }
}
