import SwiftUI
import ImageIO
internal import SSMediaManager
import Speech
internal import Lottie


struct FPDeficiencyReasonAiCell: View {
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: FPUtility.getCurrentLanguageidentifier()))
    private let recognitionRequest: SFSpeechAudioBufferRecognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    @State private var recognitionTask: SFSpeechRecognitionTask?
    let audioEngine = AVAudioEngine()

    @State var checkListData: [String: Any] = ["Size": false,"Device Type": false,"Quantity": false,"Model": false,"Brand":false]

    var severityData = [["param":"CRITICAL","data":FPLocalizationHelper.localize("lbl_Critical")],["param":"NON_CRITICAL","data":FPLocalizationHelper.localize("lbl_Non_Critical")],["param":"IMPAIRMENTS_FOUND","data":FPLocalizationHelper.localize("lbl_Impairments_Found")],["param":"NO_DEFICIENCY","data":FPLocalizationHelper.localize("lbl_No_Deficiency")]]
    
    var fieldIndexPath: IndexPath
    let items: [SSMedia]
    var isViewOnly: Bool = false
    @State var reasonText: String
    @State var recommendationText: String
    @State var selectedSeverity: String?
    @State var selectedSeverityKey:String?
    @State var dueDate: Date?

    @State var aiSuggestionData = [String]()
    @State var disableInput: Bool = false

    @State var recordReasonSelected : Bool = false
    @State var recordRecommendationSelected : Bool = false

    var onAddImageClicked: (() -> Void)?
    var onItemRemoved: ((Int)-> Void)?
    var onItemClicked: ((String)-> Void)?
    var onUpdateReasonData: ((_ value: String, _ otherData: [String : Any])-> Void)?
    var triggerCollectionReload: (()-> Void)?
    var onTriggerMixpanelEvent: ((String)-> Void)?

    @FocusState private var isFocusedReason: Bool
    @FocusState private var isFocusedRecomdation: Bool

    @State var playbackModeReason = LottiePlaybackMode.paused(at: .currentFrame)
    @State var playbackModeRecommendation = LottiePlaybackMode.paused(at: .currentFrame)

    @State var showChecklist: Bool = false
    @State var showRedactedChecklist: Bool = false
    @State var showLoadingSuggestions: Bool = false

    @ViewBuilder
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    imageContainerView
                    reasonInputView
                    SwiftUI.Text(FPLocalizationHelper.localize("lbl_Recommendation"))
                        .font(.system(size: 14, weight: .medium))
                    recommendationInputView
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#F0EFF6"))
                )
                
                HStack {
                    severityPickerView
                        .frame(maxWidth: .infinity)
                    dueDatePickerView
                        .frame(maxWidth: .infinity)
                }
            }
            .disabled(isViewOnly)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            .padding(.vertical, 10)
            .onAppear {
                requestSpeechPermission()
                setupView()
            }
        }
    }
    
    @ViewBuilder
    private var imageContainerView: some View {
        HStack(spacing: 8) {
            ForEach(items.indices, id: \.self) { idx in
                ZStack(alignment: .topTrailing) {
                    ZTImageCell(
                        media: items[safe:idx],
                        width: 50.0,
                        resizingMode: .fill
                    )
                    .cornerRadius(6)
                    .onTapGesture {
                        onItemClicked?(items[idx].name)
                    }
                    Button(action: {
                        onItemRemoved?(idx)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.black)
                            .background(Color.white.clipShape(Circle()))
                    }
                    .offset(x: 6, y: -6)
                }
            }
            if !isViewOnly{
                Spacer()
                Button(action: {
                    onAddImageClicked?()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color("BT-Primary"))
                        Image(systemName: "camera")
                            .font(.body)
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 40, height: 40)
            }
        }
    }
    
    @ViewBuilder
    private var reasonInputView: some View {
        HStack(alignment: .top, spacing: 2) {
            TextEditor(text: $reasonText) //FPLocalizationHelper.localize("lbl_Add_reason_here")
                .frame(height: 100)
                .font(.system(size: 14, weight: .regular))
                .focused($isFocusedReason)
                .autocorrectionDisabled(true)
                .disabled(disableInput)
                .onChange(of: isFocusedReason) { isFocused in
                    if !isFocused {
                        aiSuggestionData = []
                        getAiRecommendation()
                    }
                }
            
            if !isViewOnly{
                HStack{
                    if recordReasonSelected{
                        LottieView(animation: .named("wave-audio"))
                            .playbackMode(playbackModeReason)
                            .frame(width: 50, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color("BT-Primary"), lineWidth: 1)
                            )
                    }
                    Button(action: {
                        didTapReasonRecordButton()
                    }) {
                        Image(recordReasonSelected ? "icon-stoprecording" : "icon-record")
                    }
                    .frame(width: 40, height: 40)
                }
            }
        }
        .background(.white)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color("BT-Primary"))
        )
    }
    
    @ViewBuilder
    private var recommendationInputView: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 2) {
                    TextEditor(text: $recommendationText)//FPLocalizationHelper.localize("lbl_Add_recommendation_here")
                        .frame(height: 100)
                        .font(.system(size: 14, weight: .regular))
                        .focused($isFocusedRecomdation)
                        .autocorrectionDisabled(true)
                        .disabled(disableInput)
                        .onChange(of: isFocusedRecomdation) { isFocused in
                            if !isFocused {
                                setRecommendationChecklist(strRecommendation: recommendationText)
                            }
                        }
                    if !isViewOnly{
                        HStack{
                            if recordRecommendationSelected{
                                LottieView(animation: .named("wave-audio"))
                                    .playbackMode(playbackModeRecommendation)
                                    .frame(width: 50, height: 32)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color("BT-Primary"), lineWidth: 1)
                                    )
                            }
                            
                            Button(action: {
                                didTapRecommendationRecordButton()
                            }) {
                                Image(recordRecommendationSelected ? "icon-stoprecording" : "icon-record")
                            }
                            .frame(width: 40, height: 40)
                        }
                    }
                }
                if showChecklist{
                    checklistView
                        .padding(.horizontal, 8)
                }
                if !aiSuggestionData.isEmpty{
                    AISuggestionsView
                }
            }
            .background(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color("BT-Primary"))
            )
        }
    }

    @ViewBuilder
    private var checklistView: some View {
        HStack(spacing: 8) {
            ZTProgressCircleView(progress: CGFloat(checkListData.map({$0.value}).filter({$0 as? Bool ?? false}).count) / CGFloat(max(checkListData.count, 1)))
                .frame(width: 30, height: 30)
            
            Divider()
                .frame(width: 2, height: 32)
                .background(Color.gray.opacity(0.5))
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(checkListData.keys.sorted(), id: \.self) { key in
                        let value = checkListData[key] ?? false
                        let keyReplaced = key.replacingOccurrences(of: " ", with: "_")
                        SwiftUI.Text(FPLocalizationHelper.localize(keyReplaced))
                            .font(.system(size: 14, weight: .regular))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke((value as? Bool ?? false) ? Color(hex: "#059B33") : Color(hex: "#E70201"), lineWidth: 1)
                            )
                            .foregroundColor((value as? Bool ?? false) ? Color(hex: "#059B33") : Color(hex: "#E70201"))
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(height: 50)
        }
        .redacted(reason: showRedactedChecklist ? .placeholder : [])
    }
    
    @ViewBuilder
    var severityPickerView: some View {
        Menu {
            ForEach(severityData.indices, id: \.self) { idx in
                let option = severityData[idx]["data"] ?? ""
                Button {
                    selectedSeverity = option
                    selectedSeverityKey = severityData[idx]["param"]
                    updateSeverityData()
                } label: {
                    if selectedSeverity == option {
                        Label(option, systemImage: "checkmark")
                    } else {
                        SwiftUI.Text(option)
                            .font(.system(size: 14, weight: .regular))
                    }
                }
            }
        } label: {
            HStack {
                SwiftUI.Text((selectedSeverity?.isEmpty == true || selectedSeverity == nil) ? FPLocalizationHelper.localize("lbl_Severity") : selectedSeverity ?? "" )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.system(size: 14, weight: .regular))
                Image(systemName: "chevron.down")
            }
            .foregroundStyle(Color("ZT-Black"))
            .padding(.horizontal, 10)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
    }
    
    @ViewBuilder
    var dueDatePickerView: some View{
        HStack {
            ZTDateTextFieldView(
                date: $dueDate,
                placeholder: FPLocalizationHelper.localize("lbl_Due_Date_PH"),
                displayFormat: Reason_cell_DATE_STRING_FORMAT,
                minDate: Date(),
                maxDate: nil) { date in
                    dueDate = date
                    updateSeverityData()
                }
                .padding(.leading, 10)
            
            Image(systemName: "calendar")
                .padding(.trailing, 10)
        }
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    var AISuggestionsView: some  View{
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label {
                    SwiftUI.Text(FPLocalizationHelper.localize("lbl_AI_Suggestion"))
                        .font(.system(size: 16, weight: .medium))
                } icon: {
                    Image("icon-ai-star")
                        .frame(width: 24, height: 24)
                }
                Spacer()
                Button(action: {
                    aiSuggestionData = []
                    getAiRecommendation()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 24, height: 24)
                }
                .frame(width: 40, height: 40)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(aiSuggestionData, id: \.self) { suggestion in
                        ZStack {
                            SwiftUI.Text(suggestion)
                                .font(.system(size: 14))
                                .foregroundStyle(Color("ZT-Black"))
                                .frame(width: 200, height: 80)
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                                .lineLimit(5)
                                .onTapGesture {
                                    FPFormDataHolder.shared.removeAiSuggestion(indexPath: fieldIndexPath)
                                    aiSuggestionData = []
                                    recommendationText = suggestion
                                    updateSeverityData()
                                    setRecommendationChecklist(strRecommendation: suggestion)
                                    //triggerCollectionReload?()
                                }
                            
                            if showLoadingSuggestions{
                                ProgressView()
                                    .tint(Color("BT-Primary"))
                            }
                        }
                        
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 2)
            }
        }
        .padding(10)
        .background(Color(.systemGray5))
        .cornerRadius(6)
    }
    
    
    //MARK: Helper Methods

    
    func updateSeverityData(){
        let param = ["severity":selectedSeverityKey ?? "", "dueDate":Int(dueDate?.timeIntervalSince1970 ?? 0) ,"recommendation":recommendationText] as [String : Any]
       onUpdateReasonData?(reasonText, param)
    }
    
    private func requestSpeechPermission() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            switch authStatus {
            case .authorized:
                break
            case .denied, .restricted, .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }
    
    func setUiView(){
        if audioEngine.isRunning {
            UIApplication.shared.endEditing()
            disableInput = true
        }else{
            disableInput = false
        }
    }
    
    func setupView(){
        selectedSeverity = severityData.filter({ $0["param"] == selectedSeverityKey}).first?["data"]
        setUiView()
        if let checkList = FPFormDataHolder.shared.getFiledCheckListArray()[fieldIndexPath]{
            checkListData = checkList
            showChecklist = true
        }else{
            showChecklist = false
        }
        if let data = (self.aiSuggestionData.first),data.isEmpty{
            getAiRecommendation()
        }
    }
    
    private func startRecording() {
        if !FPUtility.isConnectedToNetwork(){
            _  = FPUtility.showAlertController(title: FPLocalizationHelper.localize("alert_dialog_title"), message: FPLocalizationHelper.localize("msg_errorNoNetwork_Recorder")){}
            self.normalState()
            return
        }
        if audioEngine.isRunning {
            stopRecording()
            return
        }
        let localReasonText = self.reasonText
        let localRecommendationText = self.recommendationText

        let inputNode = audioEngine.inputNode
        recognitionRequest.requiresOnDeviceRecognition = true
        recognitionRequest.shouldReportPartialResults = true
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { result, error in
            if let result = result {
                let recognizedText = result.bestTranscription.formattedString

                // Append new text instead of replacing old text
                if recordReasonSelected {
                    self.reasonText = (localReasonText) + " " + recognizedText
                } else if recordRecommendationSelected {
                    self.recommendationText = (localRecommendationText) + " " + recognizedText
                }
                self.updateSeverityData()
            }

            if error != nil || result?.isFinal == true {
                self.stopRecording()
            }
        })
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
        }
        setUiView()
    }

    func stopRecording() {
        audioEngine.stop()
        recognitionRequest.endAudio()
        recognitionTask?.cancel()
        audioEngine.inputNode.removeTap(onBus: 0)
        setUiView()
    }
    
    func normalState(){
        recordReasonSelected = false
        recordRecommendationSelected = false
        playbackModeReason = LottiePlaybackMode.paused(at: .currentFrame)
        stopRecording()
    }
    
    func getAiRecommendation(){
        if reasonText.replacingOccurrences(of: " ", with: "").isEmpty{
            return
        }
        if self.aiSuggestionData.isEmpty{
            aiSuggestionData = ["","",""]
        }
        
        var reason = reasonText
        if UserDefaults.libCurrentLanguage == "es"{
            reason.append("Please return the result in Spanish (Mexican)")
        }
        showLoadingSuggestions = true
        FPFormsServiceManager.getRecommendationSuggestions(reason: reason,completion: { result , error in
            aiSuggestionData = result
            showLoadingSuggestions = false
            FPFormDataHolder.shared.saveAiSuggestion(suggestion: result, indexPath: fieldIndexPath)
        })
    }
    
    func setRecommendationChecklist(strRecommendation:String){
        if strRecommendation.replacingOccurrences(of: " ", with: "").isEmpty{
            return
        }
        let checkListArray = self.checkListData.map({$0.key})
        showRedactedChecklist = true
        showChecklist = true
        FPFormsServiceManager.getRecommendationCheckList(recommendation: strRecommendation ,checkListData: checkListArray, completion: { result , error in
            showRedactedChecklist = false
            if result.count != 0{
                checkListData = result
                FPFormDataHolder.shared.saveAiCheckList(checkList: result, indexPath: fieldIndexPath)
            }
        })
    }
    
    func playWave() {
        if recordReasonSelected {
            playbackModeReason = .playing(.fromProgress(0, toProgress: 1, loopMode: .loop))
        }else{
            playbackModeRecommendation = .playing(.fromProgress(0, toProgress: 1, loopMode: .loop))
        }
    }
    
    func didTapReasonRecordButton() {
        onTriggerMixpanelEvent?("Reason_Voice")
        if recordReasonSelected {
            recordReasonSelected = false
            playbackModeReason = .paused(at: .currentFrame)
            getAiRecommendation()
            stopRecording()
        } else {
            recordReasonSelected = true
            recordRecommendationSelected = false
            playbackModeReason = .paused(at: .currentFrame)
            playbackModeRecommendation = .paused(at: .currentFrame)
            playWave()
            if audioEngine.isRunning {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                 self.startRecording()
                })
            }
            startRecording()
        }
    }
    
    func didTapRecommendationRecordButton() {
        onTriggerMixpanelEvent?("Recommendation_Voice")
        if recordReasonSelected{
            getAiRecommendation()
        }
        if recordRecommendationSelected {
            recordRecommendationSelected = false
            playbackModeRecommendation = .paused(at: .currentFrame)
            stopRecording()
            setRecommendationChecklist(strRecommendation: recommendationText)
        } else {
            recordRecommendationSelected = true
            recordReasonSelected = false
            playbackModeReason = .paused(at: .currentFrame)
            playbackModeRecommendation = .paused(at: .currentFrame)
            playWave()
            if audioEngine.isRunning {
                stopRecording()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                 self.startRecording()
                })
            }else{
                startRecording()
            }
        }
    }
}


struct ZTImageCell: View {
    let media: SSMedia?
    var width: CGFloat = 50.0
    var resizingMode:ContentMode = .fit

    @State var localImge = Image("noimage")

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: CGFloat.leastNonzeroMagnitude){
                    if let imgUrl = media?.serverUrl, !imgUrl.isEmpty{
                        ZTImageLoaderView(urlString: imgUrl, resizingMode: resizingMode)
                    }else if  let localUrl = media?.filePath, !localUrl.isEmpty{
                        localImge
                            .resizable()
                            .aspectRatio(contentMode: resizingMode)
                    }else{
                        Image("noImage")
                            .resizable()
                            .aspectRatio(contentMode: resizingMode)
                    }
                }
                .padding(4)
            }
        }
        .frame(width: width, height: width)
        .onAppear {
            if let localUrl = media?.filePath, !localUrl.isEmpty{
                // Downsample instead of decoding the full-size photo (~48 MB for 12 MP).
                let maxPixel = max(width * 3, 100)
                DispatchQueue.global(qos: .userInitiated).async {
                    let options: [CFString: Any] = [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceShouldCacheImmediately: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: maxPixel
                    ]
                    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: localUrl) as CFURL, nil),
                          let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return }
                    let thumb = UIImage(cgImage: cgImage)
                    DispatchQueue.main.async {
                        self.localImge = Image(uiImage: thumb)
                    }
                }
            }
        }
    }
    
}





extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
