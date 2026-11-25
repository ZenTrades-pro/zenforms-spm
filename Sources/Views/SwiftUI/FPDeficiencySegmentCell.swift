import SwiftUI
internal import SSMediaManager
internal import SwiftUIFlowLayout

struct FPDeficiencySegmentCell: View {
    
    var fieldItem :FPFieldDetails
    var reasonsComponent:FPReasonsComponent?
    var fieldIndexPath: IndexPath
    @State var selectedIndex: Int
    @State var customReason: String
    let items: [String]
    var isViewOnly: Bool = false
    @State var segmentOptions:[String] = []
    var onAddImageClicked: () -> Void
    var onItemsRemoved: ((Int)-> Void)?
    var onItemsClicked: ((Int)-> Void)?
    var triggerCollectionReload: (()-> Void)?
    var onTriggerMixpanelEvent: ((String)-> Void)?

    @FocusState private var isFocused: Bool
    @State var showCustomReasonOptions:Bool = false
    
    @ViewBuilder
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 16) {
                SwiftUI.Text(fieldItem.displayName?.handleAndDisplayApostrophe() ?? "")
                    .font(.headline)
                    .foregroundStyle(Color("ZT-Black"))
                deficiencySegmentView
                deficiencyContentView
            }
            .padding(10)
            .onAppear {
                segmentOptions = getSegmentOptions()
                showCustomReasonOptions = fieldItem.openDeficencySelectedOption(value: reasonsComponent?.value ?? "")
            }
        }
    }
    
    @ViewBuilder
    private var deficiencySegmentView: some View {
        Picker("", selection: $selectedIndex) {
            ForEach(segmentOptions.indices, id: \.self) { idx in
                SwiftUI.Text(segmentOptions[idx]).tag(idx)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedIndex) { [prevIndex = selectedIndex] newValue in
            let oldValue = segmentOptions[safe:prevIndex]
            setValueFromSelectedIndex(selectedIndex, oldValue: oldValue)
        }
        .disabled(isViewOnly)
        .frame(height: 40.0)
    }
    
    @ViewBuilder
    private var deficiencyContentView: some View {
        ZStack {
            if showCustomReasonOptions {
                if isEnableReasonAICell{
                    customDeficiencyAIView
                }else{
                    VStack(alignment: .leading, spacing: 16) {
                        customReasonHeaderView
                        customReasonInputView
                        attachedFilesView
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var customReasonHeaderView: some View {
        HStack(alignment: .center, spacing: 8) {
            SwiftUI.Text(FPLocalizationHelper.localize("lbl_Reasons"))
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(Color("ZT-Black"))

            Spacer()
            
            if !isViewOnly{
                Button(action: onAddImageClicked) {
                    HStack {
                        Image(systemName: "camera")
                        SwiftUI.Text(FPLocalizationHelper.localize("lbl_Add_Image"))
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color("BT-Primary"))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                }
            }
        }
    }
    
    @ViewBuilder
    private var customReasonInputView: some View {
        TextField(FPLocalizationHelper.localize("lbl_Custom_Reason"), text: $customReason)
            .focused($isFocused)
            .padding(.horizontal, 8)
            .font(.subheadline)
            .foregroundStyle(Color("ZT-Black"))
            .frame(height: 50)
            .disabled(isViewOnly)
            .background(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .onChange(of: isFocused) { isFocused in
                if !isFocused {
                    updateCustomReasonWith(customReason, otherData: [:])
                }
            }
    }

    @ViewBuilder
    private var attachedFilesView: some View {
        FlowLayout(mode: .scrollable, items: Array(items.indices), itemSpacing: 4) { index in
            HStack(spacing: 8) {
                SwiftUI.Text(items[index])
                    .font(.footnote)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                
                if !isViewOnly{
                    Button(action: {
                        onItemsRemoved?(index)
                    }) {
                        Image(systemName: "xmark")
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.trailing, 8)
                            .padding(.vertical, 4)
                    }
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color("BT-Primary"))
            )
            .onTapGesture {
                onItemsClicked?(index)
            }
        }
    }
    
    @ViewBuilder
    private var customDeficiencyAIView: some View {
        FPDeficiencyReasonAiCell(
            fieldIndexPath: fieldIndexPath,
            items: FPFormDataHolder.shared.getFiledFilesArray()[fieldIndexPath] ?? [],
            isViewOnly: isViewOnly,
            reasonText: reasonsComponent?.customReason?.description ?? "",
            recommendationText: reasonsComponent?.customReason?.recommendations?.last?.description ?? "",
            selectedSeverityKey: reasonsComponent?.customReason?.severity,
            dueDate: getDueDate(),
            aiSuggestionData: FPFormDataHolder.shared.getFiledSuggestionArray()[fieldIndexPath] ?? []) {
                onAddImageClicked()
            } onItemRemoved: { index in
                onItemsRemoved?(index)
            } onItemClicked: { index in
                onItemsClicked?(index)
            } onUpdateReasonData: { value, otherData in
                updateCustomReasonWith(value, otherData: otherData)
            } onTriggerMixpanelEvent:{ event in
                onTriggerMixpanelEvent?(event)
            }
    }
    
    //MARK: Helper Methods
    
    fileprivate func getSegmentOptions() -> [String]{
        let radioOptions = fieldItem.getRadioOptions().map { dict in
            return dict["label"] as? String ?? ""
        }
        if radioOptions.isEmpty{
            return [FPLocalizationHelper.localize("Yes"), FPLocalizationHelper.localize("NO"), "N/A"]
        }else{
            return radioOptions
        }
    }
    
    fileprivate func getSelectedIndex(_ value: String) -> Int {
        if let selectedIndex = fieldItem.getRadioOptions().firstIndex(where: {($0["value"] as? String ?? "").lowercased() == value.lowercased()}){
            return selectedIndex
        }
        return -1
    }
    
    fileprivate func setValueFromSelectedIndex(_ withSelectedIndex: Int, oldValue:String?) {
        if let value = fieldItem.getRadioOptions()[safe:withSelectedIndex]?["value"] as? String{
           reasonsComponent?.value = value
        }else{
            reasonsComponent?.value = ""
        }
        updateSelectedValue()
        withAnimation {
            showCustomReasonOptions = fieldItem.openDeficencySelectedOption(value: reasonsComponent?.value ?? "")
        }
    }
    
    fileprivate func updateSelectedValue() {
        let reasons = reasonsComponent?.getReasonsArray() ?? [[:]]
        FPFormDataHolder.shared.updateRowWith(reasons: reasons.getJson(), value: reasonsComponent?.value ?? "", inSection: fieldIndexPath.section, atIndex: fieldIndexPath.row)
    }
    
    fileprivate func updateCustomReasonWith(_ value: String, otherData: [String : Any]) {
       let servity = otherData["severity"] as? String ?? ""
        let dueDate = otherData["dueDate"] as? Int ?? nil
        let recommendation = otherData["recommendation"] as? String ?? ""
        let recommendationID = reasonsComponent?.customReason?.recommendations?.first?.id ?? 0
        reasonsComponent?.customReason = FPReasonsComponent().getCustomReason(value, templateId: reasonsComponent?.fieldTemplateId ?? "", objectId: reasonsComponent?.customReason?.objectID ?? "",severity: servity,dueDate: dueDate,recommendation: recommendation, recommendationID: recommendationID)
        updateSelectedValue()
    }
    
    func getDueDate() -> Date? {
        if let dueDate = self.reasonsComponent?.customReason?.dueDate, dueDate != 0{
            let backendTimestamp: TimeInterval = TimeInterval(dueDate)
            // If timestamp is too large, assume it's in milliseconds and convert
            let timestampInSeconds = backendTimestamp > 9999999999 ? backendTimestamp / 1000 : backendTimestamp
            let date = Date(timeIntervalSince1970: TimeInterval(timestampInSeconds))
            return date
        }
        return nil
    }
    
    func getDueDateTimeStamp() -> Int? {
        if let dueDate = self.reasonsComponent?.customReason?.dueDate, dueDate != 0{
            let backendTimestamp: TimeInterval = TimeInterval(dueDate)
            // If timestamp is too large, assume it's in milliseconds and convert
            let timestampInSeconds = backendTimestamp > 9999999999 ? backendTimestamp / 1000 : backendTimestamp
            return Int(timestampInSeconds)
        }
        return nil
    }
}


extension FPFieldDetails{
    func getRadioOptions() -> [[String:Any]]{
        let radioOptions = [[String:Any]]()
        if let dict = options?.getDictonary(), let options = dict["radioOptions"] as? [[String:Any]] {
            return options
        }
        return radioOptions
    }
    
    func openDeficencySelectedOption(value:String) -> Bool{
        if let dict = options?.getDictonary(), let array = dict["considerDeficiencyForOptions"] as? [String] {
            let lowercasedArr = array.map{$0.lowercased()}
            return lowercasedArr.contains(value.lowercased())
        }
        return value.lowercased() == "no"
    }
    
    func getSelectedIndex(_ value: String) -> Int {
        var selIndex = -1
        if let radioOptions = getRadioOptions() as? [[String:Any]],
           let selectedIndex = radioOptions.firstIndex(where: {($0["value"] as? String ?? "").lowercased() == value.lowercased()}){
            return selectedIndex
        }
        return selIndex
    }
}

