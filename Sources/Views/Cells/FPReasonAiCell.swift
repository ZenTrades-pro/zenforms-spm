//
//  FileReasonCell.swift
//  pro.zentrades.FPInspecter
//
//  Created by Apple on 06/06/23.
//

import UIKit
internal import SSMediaManager
internal import Lottie
import Speech
internal let Reason_cell_DATE_STRING_FORMAT:String = "dd MMM yyyy"

class FPReasonAiCell : UITableViewCell {
    var delegate:PFFileInputDelegate?
    @IBOutlet weak var collectionViewImage: UICollectionView!
    @IBOutlet weak var collectionViewSuggestion: UICollectionView!
    @IBOutlet weak var collectionViewCheckList: UICollectionView!
    @IBOutlet weak var reasonTextField: PlaceholderTextView!
    @IBOutlet weak var recommendationTextField: PlaceholderTextView!
    @IBOutlet weak var recordBtn: UIButton!
    @IBOutlet weak var recordBtn1: UIButton!
    @IBOutlet weak var waveView: LottieAnimationView!
    @IBOutlet weak var waveView1: LottieAnimationView!
    @IBOutlet weak var txtFieldSerity: UITextField!
    @IBOutlet weak var txtFieldDate: UITextField!
    @IBOutlet weak var btnImageAdd: UIButton!
    @IBOutlet weak var btnSeverityAdd:UIButton!
    @IBOutlet weak var bgViewCell: UIView!
    @IBOutlet weak var lblRecommendation: UILabel!
    @IBOutlet weak var lblAiSuggestion: UILabel!
    @IBOutlet weak var aiSuggestionView: UIView!
    @IBOutlet weak var checkListView: UIStackView!
    @IBOutlet weak var circelProgress: CircularProgressView!
    @IBOutlet weak var circelProgressMainView: UIView!
    
    var indexPath:IndexPath?
    var ssMediaArray = [SSMedia]()
    var aiSuggestionData = [String]()
    var onItemsRemoved: ((Int)->())?
    var severityKey: String?
    var zenFormDelegate: ZenFormsDelegate?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: FPUtility.getCurrentLanguageidentifier())) // Set your locale
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    let audioEngine = AVAudioEngine()
    var dateTimeStamp : Int?
    var selectedDate = Date()
    var severityData = [["param":"CRITICAL","data":FPLocalizationHelper.localize("lbl_Critical")],["param":"NON_CRITICAL","data":FPLocalizationHelper.localize("lbl_Non_Critical")],["param":"IMPAIRMENTS_FOUND","data":FPLocalizationHelper.localize("lbl_Impairments_Found")],["param":"NO_DEFICIENCY","data":FPLocalizationHelper.localize("lbl_No_Deficiency")]]
    var checkListData: [String: Any] = ["Size": false,"Device Type": false,"Quantity": false,"Model": false,"Brand":false]

    var delegate1: CustomReasonTextFieldTableViewCellDelegate?
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        txtFieldSerity.addDropDownView()
        txtFieldDate.addCalendarIconRightView()
        FPImageCollectionViewCell.registerWithCollectionView(collectionViewImage)
        FPLabelCollectionViewCell.registerWithCollectionView(collectionViewSuggestion)
        FPLabelCollectionViewCell.registerWithCollectionView(collectionViewCheckList)
        requestSpeechPermission()
        txtFieldDate.addInputViewDatePicker(target: self, selector: #selector(dateButtonPressed),minimumDate: Date())
        self.reasonTextField.delegate = self
        self.recommendationTextField.delegate = self
        txtFieldSerity.placeholder = FPLocalizationHelper.localize("lbl_Severity")
        txtFieldDate.placeholder = FPLocalizationHelper.localize("lbl_Due_Date_PH")
        self.lblRecommendation.text = FPLocalizationHelper.localize("lbl_Recommendation")
        self.lblAiSuggestion.text = FPLocalizationHelper.localize("lbl_AI_Suggestion")
        self.bgViewCell.applyShadow()
        self.bgViewCell.layer.cornerRadius = 5
        setUiView()
        circelProgress.totalProgress = CGFloat(self.checkListData.count)
        circelProgress.currentProgress = 0
        autoCorrectDisable(textView: reasonTextField)
        autoCorrectDisable(textView: recommendationTextField)
    }

    func autoCorrectDisable(textView:UITextView){
        textView.autocorrectionType = .no
        textView.spellCheckingType = .no // Optional: Disable spell checking
        textView.smartQuotesType = .no   // Optional: Prevent smart quotes
        textView.smartDashesType = .no   // Optional: Prevent smart dashes
        textView.smartInsertDeleteType = .no // Optional: Disable auto-insert/delete
    }
    
    func setSeverityDataAndDueDate(customReason: FPReasonsRow?){
        self.dateTimeStamp = customReason?.dueDate
        if let dueDate = customReason?.dueDate{
            let date = Date(milliseconds: Int64(dueDate))
            self.txtFieldDate.text = FPUtility.dateString(date, withCustomFormat: Reason_cell_DATE_STRING_FORMAT)
            self.selectedDate = date
            self.txtFieldDate.updateSelectedDate(date)
        }else{
            txtFieldDate.text = ""
        }
        self.severityKey = customReason?.severity ?? ""
        let value = severityData.filter({ $0["param"] == severityKey}).first?["data"]
        self.txtFieldSerity.text = value ?? ""
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
    @objc func dateButtonPressed() {
        if let  datePicker = self.txtFieldDate.inputView as? UIDatePicker {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = Reason_cell_DATE_STRING_FORMAT
            self.selectedDate = datePicker.date
            self.txtFieldDate.updateSelectedDate(datePicker.date)
            self.dateTimeStamp = Int(datePicker.date.millisecondsSince1970)
            self.txtFieldDate.text = dateFormatter.string(from: datePicker.date)
        }
        self.txtFieldDate.resignFirstResponder()
        self.updateData()
     }
    
    @IBAction func severitySheet(sender: AnyObject) {
       
        let optionMenu = UIAlertController(title: nil, message: FPLocalizationHelper.localize("lbl_Choose_Severity"), preferredStyle: .actionSheet)
        
        for i in severityData{
            let action = UIAlertAction(title: i["data"], style: .default, handler: {
                (alert: UIAlertAction!) -> Void in
                self.txtFieldSerity.text = i["data"]
                self.severityKey = i["param"]!
                self.updateData()
            })
            optionMenu.addAction(action)
        }
        let cancelAction = UIAlertAction(title: FPLocalizationHelper.localize("Cancel"), style: .cancel, handler: nil)
        optionMenu.addAction(cancelAction)
        optionMenu.applyLegacyActionSheetStyle()
        if UIDevice.current.userInterfaceIdiom == .phone {
            FPUtility.topViewController()?.present(optionMenu, animated: true) {}
        } else {
            if let popoverController = optionMenu.popoverPresentationController {
                popoverController.sourceView = self
                popoverController.sourceRect = CGRect(x: self.bounds.midX, y: self.bounds.midY, width: 0, height: 0)
                popoverController.permittedArrowDirections = []
                FPUtility.topViewController()?.present(optionMenu, animated: true, completion: nil)
            }
        }
    }
    
    func updateData(){
        let param = ["severity":severityKey ?? "", "dueDate":dateTimeStamp ?? nil,"recommendation":recommendationTextField.text ?? ""] as [String : Any]
        self.delegate1?.updateCustomReasonWith(self.reasonTextField.text ?? "", otherData: param)
    }
    
    func setupView(customReason: FPReasonsRow?){
        reasonTextField.placeholder = FPLocalizationHelper.localize("lbl_Add_reason_here")
        recommendationTextField.placeholder = FPLocalizationHelper.localize("lbl_Add_recommendation_here")
        
        if let customReasonDesc = customReason?.description, !customReasonDesc.isEmpty{
            reasonTextField.text = customReasonDesc
            reasonTextField.placeholderLabel.isHidden = true
        }else{
            reasonTextField.placeholderLabel.isHidden = false
            reasonTextField.text = ""
        }
       
        if let recommendationDesc = customReason?.recommendations?.last(where: { $0.description?.isEmpty == false })?.description{
            recommendationTextField.text = recommendationDesc
           recommendationTextField.placeholderLabel.isHidden = true
        }else{
            recommendationTextField.placeholderLabel.isHidden = false
            recommendationTextField.text = ""
        }
        self.setSeverityDataAndDueDate(customReason: customReason)
        self.collectionViewImage.delegate = self
        self.collectionViewImage.dataSource = self
        self.collectionViewSuggestion.delegate = self
        self.collectionViewSuggestion.dataSource = self
        self.collectionViewCheckList.delegate = self
        self.collectionViewCheckList.dataSource = self
        ssMediaArray.removeAll()
        if let files = FPFormDataHolder.shared.getFiledFilesArray()[indexPath!]{
            var arrTags = [String]()
            files.forEach { media in
                if !arrTags.contains(media.name){
                    arrTags.append(media.name)
                }
            }
            arrTags.forEach { tagName in
                if let ssMedia = FPFormDataHolder.shared.getFiledFilesArray()[indexPath!]?.first(where: {$0.name == tagName}){
                    ssMediaArray.append(ssMedia)
                }
            }
        }
        self.aiSuggestionData = FPFormDataHolder.shared.getFiledSuggestionArray()[indexPath!] ?? []
        if let checkList = FPFormDataHolder.shared.getFiledCheckListArray()[indexPath!]{
            if let checkListname = checkList.map({$0.key}).first,(checkListname.contains("load")), FPUtility.isConnectedToNetwork(){
                self.circelProgressMainView.isHidden = true
                if let flowLayout = collectionViewCheckList.collectionViewLayout as? UICollectionViewFlowLayout {
                    flowLayout.estimatedItemSize = .zero
                    flowLayout.invalidateLayout() // Refresh layout
                }
                self.setRecommendationChecklist()
            }else{
                if let flowLayout = collectionViewCheckList.collectionViewLayout as? UICollectionViewFlowLayout {
                    flowLayout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
                    flowLayout.invalidateLayout() // Refresh layout
                }
                self.checkListData = checkList
                let progressData = self.checkListData.map({$0.value}).filter({($0 as? Bool ?? false) == true})
                self.circelProgress.totalProgress = CGFloat(self.checkListData.count)
                self.circelProgress.currentProgress = CGFloat(progressData.count)
                self.circelProgressMainView.isHidden = false
            }
            self.checkListView.isHidden = false
        }else{
            self.checkListView.isHidden = true
        }
        self.aiSuggestionView.isHidden = aiSuggestionData.isEmpty
        self.collectionViewImage.reloadData()
        self.collectionViewSuggestion.reloadData()
        self.collectionViewCheckList.reloadData()
        if let data = (self.aiSuggestionData.first),data.isEmpty{
            self.getAiRecommendation()
        }
        self.updateData()
    }

    func playWave() {
        let path = Bundle.main.path(forResource: "wave-audio", ofType: "json") ?? ""
        if recordBtn.isSelected {
            waveView.animation = LottieAnimation.filepath(path)
            waveView.loopMode = .loop
            waveView.play()
        }else{
            waveView1.animation = LottieAnimation.filepath(path)
            waveView1.loopMode = .loop
            waveView1.play()
        }
    }
    
    @IBAction func didTaprecordBtn(_ sender: UIButton) {
//        self.normalState()
        if sender.tag == 1{
            self.zenFormDelegate?.mixpanelEvent(eventName: "Reason_Voice", properties: nil)
            if recordBtn.isSelected {
                recordBtn.isSelected = false
                waveView.stop()
                waveView.isHidden = true
                getAiRecommendation()
                stopRecording()  // Stop recording and processing
            } else {
                recordBtn.isSelected = true
                waveView.isHidden = false
                recordBtn1.isSelected = false
                waveView1.isHidden = true
                waveView.stop()
                playWave()
                if audioEngine.isRunning {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                     self.startRecording()
                    })
                }
                startRecording()
            }
        }else{
            self.zenFormDelegate?.mixpanelEvent(eventName: "Recommendation_Voice", properties: nil)
            if recordBtn.isSelected{
                getAiRecommendation()
            }
            if recordBtn1.isSelected {
                recordBtn1.isSelected = false
                waveView1.isHidden = true
                waveView.stop()
                stopRecording()  // Stop recording and processing
                self.setRecommendationChecklist()
            } else {
                recordBtn1.isSelected = true
                waveView1.isHidden = false
                recordBtn.isSelected = false
                waveView.isHidden = true
                waveView.stop()
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
    
    func normalState(){
        recordBtn.isSelected = false
        waveView.isHidden = true
        recordBtn1.isSelected = false
        waveView1.isHidden = true
        waveView.stop()
        stopRecording()
    }
    
    @IBAction func addImage(_ sender: UIButton) {
        delegate?.didAttachTap(at: indexPath!, sender: sender, isImageOnly: true)
    }
    
    @IBAction func didTapRefresh(_ sender: Any) {
        guard FPUtility.isConnectedToNetwork() else {
            FPUtility.showNoNetworkAlert()
            return
        }
        self.aiSuggestionData.removeAll()
        getAiRecommendation()
    }
    
    func setUiView(){
        if audioEngine.isRunning {
            self.reasonTextField.resignFirstResponder()
            self.reasonTextField.isEditable = false
            self.recommendationTextField.resignFirstResponder()
            self.recommendationTextField.isEditable = false
        }else{
            self.reasonTextField.isEditable = true
            self.recommendationTextField.isEditable = true
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
        let reasonText = self.reasonTextField.text ?? ""
        let recommendationText = self.recommendationTextField.text ?? ""
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }

        let inputNode = audioEngine.inputNode
        recognitionRequest.requiresOnDeviceRecognition = true // Optional: Use offline mode if supported
        recognitionRequest.shouldReportPartialResults = true
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let recognizedText = result.bestTranscription.formattedString

                // Append new text instead of replacing old text
                if recordBtn.isSelected {
                    self.reasonTextField.placeholderLabel.isHidden = true
                    self.reasonTextField.text = (reasonText) + " " + recognizedText
                } else if recordBtn1.isSelected {
                    self.recommendationTextField.placeholderLabel.isHidden = true
                    self.recommendationTextField.text = (recommendationText) + " " + recognizedText
                }
                self.updateData()
            }

            if error != nil || result?.isFinal == true {
                self.stopRecording()
            }
        })
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
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
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        audioEngine.inputNode.removeTap(onBus: 0)
        setUiView()
    }
    
    func getAiRecommendation(){
        guard FPUtility.isConnectedToNetwork() else {
            return
        }
        if self.reasonTextField.text.replacingOccurrences(of: " ", with: "").isEmpty{
            return
        }
        if (self.aiSuggestionData.count == 0){
            FPFormDataHolder.shared.saveAiSuggestion(suggestion: ["","",""], indexPath: self.indexPath!)
            self.delegate1?.updateCustomAiSuggestionWith()
        }else{
            var reason = self.reasonTextField.text ?? ""
            if UserDefaults.libCurrentLanguage == "es"{
                reason.append("Please return the result in Spanish (Mexican)")
            }
            FPFormsServiceManager.getRecommendationSuggestions(reason: reason,completion: { result , error in
                if let error = error{
                  //  FPUtility.showErrorMessage(nil, withTitle: "", withWarningMessage: error.localizedDescription)
                }
                self.aiSuggestionData = result
                self.collectionViewSuggestion.reloadData()
                FPFormDataHolder.shared.saveAiSuggestion(suggestion: self.aiSuggestionData, indexPath: self.indexPath!)
            })
        }
    }
    
    func setRecommendationChecklist(){
        guard FPUtility.isConnectedToNetwork() else {
            return
        }
        if self.recommendationTextField.text.replacingOccurrences(of: " ", with: "").isEmpty{
            return
        }
        if let checkList = FPFormDataHolder.shared.getFiledCheckListArray()[indexPath!]{
            if !(checkList.map({$0.key}).first?.contains("load") ?? false){
                self.circelProgressMainView.isHidden = true
                // Adding this From Swimmer Loading animation
                FPFormDataHolder.shared.saveAiCheckList(checkList: ["load1":false,"load2":false,"load3":false], indexPath: self.indexPath!)
                self.collectionViewCheckList.reloadData()
            }
            
            self.delegate1?.updateCustomAiSuggestionWith()
            let checkListArray = self.checkListData.map({$0.key})
            FPFormsServiceManager.getRecommendationCheckList(recommendation: self.recommendationTextField.text ?? "",checkListData: checkListArray, completion: { result , error in
                if let error = error{
//                    FPUtility.showErrorMessage(nil, withTitle: "", withWarningMessage: error.localizedDescription)
                    self.checkListView.isHidden = true
                    return
                }
                if result.count != 0{
                    self.checkListData = result
                    self.checkListView.isHidden = false
                    FPFormDataHolder.shared.saveAiCheckList(checkList: self.checkListData, indexPath: self.indexPath!)
                }
                let progressData = self.checkListData.map({$0.value}).filter({($0 as? Bool ?? false) == true})
                self.circelProgress.totalProgress = CGFloat(self.checkListData.count)
                self.circelProgressMainView.isHidden = false
                self.circelProgress.currentProgress = CGFloat(progressData.count)
                self.collectionViewCheckList.reloadData()
                self.delegate1?.updateCustomAiSuggestionWith()
            })
        }else{
            // Adding this From Swimmer Loading animation
            FPFormDataHolder.shared.saveAiCheckList(checkList: ["load1":false,"load2":false,"load3":false], indexPath: self.indexPath!)
            self.delegate1?.updateCustomAiSuggestionWith()
        }
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}

extension FPReasonAiCell : UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == self.collectionViewSuggestion{
            return aiSuggestionData.count
        }else if collectionView == self.collectionViewImage{
            return ssMediaArray.count
        }else{
            return checkListData.map({$0.key}).count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == self.collectionViewSuggestion{
            let cell = FPLabelCollectionViewCell.getDequeuedCell(for: collectionView, indexPath: indexPath) as! FPLabelCollectionViewCell
            if (self.aiSuggestionData.first?.isEmpty ?? false){
                cell.setTemplateWithSubviews(true, animate: true, viewBackgroundColor: .systemBackground)
                return cell
            }else{
                cell.setTemplateWithSubviews(false, animate: true, viewBackgroundColor: .systemBackground)
            }
            cell.viewBack.layer.cornerRadius = 5
            cell.lblText.numberOfLines = 0
            cell.lblText.font = UIFont.systemFont(ofSize: 12)
            cell.lblText.text = aiSuggestionData[safe:indexPath.row]
            return cell
        }else if collectionView == self.collectionViewImage{
            let cell = FPImageCollectionViewCell.getDequeuedCell(for: collectionView, indexPath: indexPath) as! FPImageCollectionViewCell
            if let url = ssMediaArray[safe: indexPath.row]?.serverUrl {
                let imageURL = URL(string: url)
                cell.fpImageView.kf.indicatorType = .activity
                cell.fpImageView.kf.setImage(
                    with: imageURL,
                    placeholder: UIImage(named: "image-placeholder"),
                    options: [.transition(.fade(0.2))]
                )
            } else {
                let filePath = ssMediaArray[safe: indexPath.row]?.filePath ?? ""
                cell.fpImageView.image = UIImage(contentsOfFile: filePath)
            }
            cell.onItemsRemoved = {
                if let files = FPFormDataHolder.shared.getFiledFilesArray()[self.indexPath!], let index = files.firstIndex(where:{$0.name == self.ssMediaArray[safe:indexPath.row]?.name}), let media = FPFormDataHolder.shared.getFiledFilesArray()[self.indexPath!]?[index], FPUtility.isConnectedToNetwork() ||  media.id == nil {
                    FPFormDataHolder.shared.removeMediaAt(indexPath: self.indexPath!, index: index)
                    self.onItemsRemoved?(index)
                }else {
                    _  = FPUtility.showAlertController(title: "Alert!", message: "You cannot delete attachments while offline"){}
                }
            }
            return cell
        }else{
            let cell = FPLabelCollectionViewCell.getDequeuedCell(for: collectionView, indexPath: indexPath) as! FPLabelCollectionViewCell
            cell.viewBack.layer.cornerRadius = 5
            cell.lblText.font = UIFont.systemFont(ofSize: 12)
            if let checkList = FPFormDataHolder.shared.getFiledCheckListArray()[self.indexPath!]{
                if let checkListname = checkList.map({$0.key}).first,(checkListname.contains("load")){
                    cell.viewBack.layer.borderWidth = 0
                    cell.lblText.text = "swimmer effect"
                    cell.setTemplateWithSubviews(true, animate: true, viewBackgroundColor: .systemBackground)
                    return cell
                }
            }
            cell.setTemplateWithSubviews(false, animate: true, viewBackgroundColor: .systemBackground)
            let key = (checkListData.map({$0.key})[indexPath.row]).replacingOccurrences(of: " ", with: "_")
            cell.lblText.text = FPLocalizationHelper.localize(key)
            cell.viewBack.layer.borderWidth = 1
            let color = checkListData.map({($0.value as? Bool ?? false)})[indexPath.row] ? FPUtility.colorwithHexString("#059B33") : FPUtility.colorwithHexString("#E70201")
            cell.viewBack.layer.borderColor = color.cgColor
            cell.lblText.textColor = color
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView == self.collectionViewSuggestion{
            if UIDevice.current.userInterfaceIdiom == .pad {
                return CGSize(width: (collectionView.frame.width/3) - 7, height: collectionView.frame.height)
            }else{
                return CGSize(width: (collectionView.frame.width) - 50, height: collectionView.frame.height)
            }
        }else if collectionView == self.collectionViewImage{
            return CGSize(width: 50, height: 50)
        }else{
            if let checkList = FPFormDataHolder.shared.getFiledCheckListArray()[self.indexPath!],let checkListname = checkList.map({$0.key}).first,(checkListname.contains("load")){
                return CGSize(width: 100, height: collectionView.frame.height)
            }
            return "String".size(withAttributes:nil)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == self.collectionViewImage{
            self.fileItemDidTapped(self.ssMediaArray[safe:indexPath.row]?.name ?? "")
        } else if collectionView == self.collectionViewSuggestion{
            self.recommendationTextField.text = aiSuggestionData[safe:indexPath.row]
            self.setRecommendationChecklist()
            self.updateData()
            if let indexPth = self.indexPath {
                FPFormDataHolder.shared.removeAiSuggestion(indexPath: indexPth)
            }
            self.delegate1?.updateCustomAiSuggestionWith()
        }
    }
    fileprivate func fileItemDidTapped(_ title: String) {
        if let ssMedia = FPFormDataHolder.shared.getFiledFilesArray()[indexPath!]?.first(where: {$0.name == title}), FPUtility.isConnectedToNetwork() ||  ssMedia.id == nil {
            let fileManager = FileManager.default
            let documentsUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            var url = documentsUrl.appendingPathComponent(ssMedia.name)
                        if fileManager.fileExists(atPath: url.path){
                let documentInteractionController = UIDocumentInteractionController(url: url)
                documentInteractionController.delegate = self
                documentInteractionController.presentPreview(animated: true)
            } else if let serverUrl = ssMedia.serverUrl {
                FPUtility.showHUDWithLoadingMessage()
                FPUtility.downloadAnyData(from: serverUrl) { image  in
                    do {
                        let documentDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor:nil, create:false)
                        let ext : String = URL.init(string: serverUrl)?.pathExtension ?? ""
                        url = documentDirectory.appendingPathComponent("\(UUID().uuidString)_downloaded.\(ext)")
                        try image?.write(to: url)
                        let documentInteractionController = UIDocumentInteractionController(url: url)
                        documentInteractionController.delegate = self
                        DispatchQueue.main.async {
                            documentInteractionController.presentPreview(animated: true)
                        }
                    } catch{
                        print(error)
                    }
                    FPUtility.hideHUD()
                }
            }
        } else {
            _  = FPUtility.showAlertController(title:FPLocalizationHelper.localize("alert_dialog_title"), message:FPLocalizationHelper.localize("msg_can_not_view_attachment_offline")){}
        }
    }
    
}

extension FPReasonAiCell : UITextViewDelegate {

    func textViewDidChange(_ textView: UITextView) {
        self.updateData()
    }
    func textViewDidEndEditing(_ textView: UITextView) {
        guard FPUtility.isConnectedToNetwork() else {
            return
        }
        if textView == self.reasonTextField{
            self.aiSuggestionData.removeAll()
            self.getAiRecommendation()
        }else{
            self.setRecommendationChecklist()
        }
    }
}

extension FPReasonAiCell:  UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return FPUtility.topViewController() ?? UIViewController()
    }
}
