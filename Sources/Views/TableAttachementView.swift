//
//  TableAttachementView.swift
//  crm
//
//  Created by kuldeep on 11/05/23.
//  Copyright © 2023 SmartServ. All rights reserved.
//

import UIKit
internal import TagListView
internal import SSMediaManager
import MobileCoreServices
import QuickLook
import UniformTypeIdentifiers
import Photos
import PhotosUI

protocol AttachmentPickerDelegate{
    func onMediaSave(mediaAdded:[SSMedia],mediaDeleted:[SSMedia])
}

class TableAttachementView: UIView, UINavigationControllerDelegate {
    @IBOutlet weak var tagListView: TagListView!
    @IBOutlet var contentView: UIView!
    var delegate:AttachmentPickerDelegate?
    var attachmentValue:String?
    private var mediaAdded:[SSMedia] = []
    private var mediaDeleted:[SSMedia] = []
    var parentViewController:UIViewController?
    /// When true, no overlay is shown; action sheet is presented and onMediaSave is called once user picks a file (e.g. from Edit Row).
    var directToSourceOnly: Bool = false
    static let instance = TableAttachementView()
    var previewMedia:SSMedia?
    
    fileprivate let fileManager = FileManager.default
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
        
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    
    private func commonInit(){
        let bundle = ZenFormsBundle.bundle
        bundle.loadNibNamed("TableAttachementView", owner: self, options:nil)
        addSubview(contentView)
        
        self.contentView.layer.cornerRadius = 10
        
        contentView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        contentView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        tagListView.delegate = self
    }
    
    func showAttachmentPicker() {
        tagListView.removeAllTags()
        mediaAdded = []
        mediaDeleted = []
        contentView.frame = parentViewController?.view.frame ?? contentView.frame
        parentViewController?.view.addSubview(contentView)
        if let data = self.attachmentValue?.getDictonary(),!data.isEmpty{
            if let files = data["files"] as? [[String:Any]]{
                files.forEach { file in
                    let media = SSMedia(name: file["altText"] as? String ?? "",id: file["id"] as? String ?? "",mimeType: file["type"] as? String ?? "", serverUrl: file["file"] as? String ?? "", moduleType: .forms)
                    mediaAdded.append(media)
                    tagListView.addTag(media.name)
                }
            }
            
            if let files = data["filesToUpload"] as? [[String:Any]]{
                files.forEach { file in
                    let media = SSMedia(name: file["altText"] as? String ?? "",mimeType: file["type"] as? String ?? "", filePath: file["localPath"] as? String ?? "", moduleType: .forms)
                    mediaAdded.append(media)
                    tagListView.addTag(media.name)
                }
            }
            
        }
    }

    /// Presents only the attachment source action sheet (Library/Camera/Document/Sketch). No Save/Cancel overlay. On selection, calls onMediaSave. Use from Edit Row.
    func showAttachmentSourcePickerOnly(sourceView: UIView?) {
        directToSourceOnly = true
        tagListView.removeAllTags()
        mediaAdded = []
        mediaDeleted = []
        if let data = attachmentValue?.getDictonary(), !data.isEmpty {
            if let files = data["files"] as? [[String: Any]] {
                files.forEach { file in
                    let media = SSMedia(name: file["altText"] as? String ?? "", id: file["id"] as? String ?? "", mimeType: file["type"] as? String ?? "", serverUrl: file["file"] as? String ?? "", moduleType: .forms)
                    mediaAdded.append(media)
                }
            }
            if let files = data["filesToUpload"] as? [[String: Any]] {
                files.forEach { file in
                    let media = SSMedia(name: file["altText"] as? String ?? "", mimeType: file["type"] as? String ?? "", filePath: file["localPath"] as? String ?? "", moduleType: .forms)
                    mediaAdded.append(media)
                }
            }
        }
        let actionOptions = UIAlertController(title: FPLocalizationHelper.localize("lbl_attachment"), message: nil, preferredStyle: .actionSheet)
        let libraryAction = UIAlertAction(title: FPLocalizationHelper.localize("lbl_Library"), style: .default) { _ in self.checkPermissionAndShowPhotoLibrary() }
        libraryAction.setValue(FPUtility.make("photo.stack"), forKey: "image")

        let cameraAction = UIAlertAction(title: FPLocalizationHelper.localize("lbl_Camera"), style: .default) { _ in
            if !UIImagePickerController.isSourceTypeAvailable(.camera) {
                FPUtility.showErrorMessage(nil, withTitle: "", withWarningMessage: FPLocalizationHelper.localize("No_Camera"))
            } else { self.checkPermissionAndShowCamera() }
        }
        cameraAction.setValue(FPUtility.make("camera"), forKey: "image")

        let documentAction = UIAlertAction(title: FPLocalizationHelper.localize("lbl_Document"), style: .default) { _ in self.showDocumentPicker() }
        documentAction.setValue(FPUtility.make("document.badge.plus"), forKey: "image")

        let sketchAction = UIAlertAction(title: FPLocalizationHelper.localize("lbl_Sketch"), style: .default) { _ in
            let vc = FPDrawViewController(nibName: "FPDrawViewController", bundle: ZenFormsBundle.bundle)
            vc.delegate = self
            self.parentViewController?.navigationController?.pushViewController(vc, animated: true)
        }
        sketchAction.setValue(FPUtility.make("lasso"), forKey: "image")

        actionOptions.addAction(libraryAction)
        actionOptions.addAction(cameraAction)
        actionOptions.addAction(documentAction)
        actionOptions.addAction(sketchAction)
        actionOptions.addAction(UIAlertAction(title: FPLocalizationHelper.localize("Cancel"), style: .cancel))
        if let popover = actionOptions.popoverPresentationController,
           let anchor = sourceView ?? parentViewController?.view {
            // iPad presents the action sheet as a popover; full bounds skew the anchor (e.g. card + landscape).
            // Center on the anchor view so the popover attaches predictably without edge glitches.
            popover.sourceView = anchor
            popover.sourceRect = CGRect(x: anchor.bounds.midX, y: anchor.bounds.midY, width: 1, height: 1)
            popover.permittedArrowDirections = []
        }
        parentViewController?.present(actionOptions, animated: true)
    }

    private func flushDirectSaveIfNeeded() {
        guard directToSourceOnly else { return }
        directToSourceOnly = false
        delegate?.onMediaSave(mediaAdded: mediaAdded, mediaDeleted: mediaDeleted)
    }
    
    @IBAction func didTapCancel(_ sender: Any) {
        contentView.removeFromSuperview()
    }
    @IBAction func didTapSave(_ sender: Any) {
        contentView.removeFromSuperview()
        delegate?.onMediaSave(mediaAdded: mediaAdded, mediaDeleted: mediaDeleted)
    }
    @IBAction func attachTap(_ sender: UIButton) {
        addAttachmentTouched(sender: sender)
    }
    
    
    //MARK: Attachments Helper
    func addAttachmentTouched(sender:UIButton) {
        let actionOptions = UIAlertController(title: FPLocalizationHelper.localize("lbl_attachment"), message: nil, preferredStyle: .actionSheet)
        let libraryAction = UIAlertAction(title:FPLocalizationHelper.localize("lbl_Library"), style: .default) { action in
            self.checkPermissionAndShowPhotoLibrary()
        }
        libraryAction.setValue(FPUtility.make("photo.stack"), forKey: "image")

        let cameraAction = UIAlertAction(title: FPLocalizationHelper.localize("lbl_Camera"), style: .default) { action in
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
            self.parentViewController?.navigationController?.pushViewController(viewController, animated: true)
        }
        sketchAction.setValue(FPUtility.make("lasso"), forKey: "image")

        let cancelAction = UIAlertAction(title: FPLocalizationHelper.localize("Cancel"), style: .cancel, handler: nil)
        
        actionOptions.addAction(libraryAction)
        actionOptions.addAction(cameraAction)
        actionOptions.addAction(documentAction)
        actionOptions.addAction(sketchAction)
        actionOptions.addAction(cancelAction)
        actionOptions.applyLegacyActionSheetStyle()
        actionOptions.popoverPresentationController?.sourceView = sender ;
        self.parentViewController?.navigationController?.present(actionOptions, animated: true, completion: nil)
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
    
    //check permissions for photo access
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
        if sourceType == .camera {
            picker.showsCameraControls = true
        }
        parentViewController?.present(picker, animated:true, completion:nil)
    }
    
    func showDocumentPicker() {
        let documentPicker = UIDocumentPickerViewController(documentTypes:FPUtility.getSupportedDocumentTypesForFileUpload(), in:.import)
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .formSheet
        documentPicker.allowsMultipleSelection = true
        DispatchQueue.main.async {
            self.parentViewController?.present(documentPicker, animated:true, completion:nil)
        }
    }
}


extension TableAttachementView:  FPDrawHelper{
    func imageSelected(_ image: UIImage) {
        do {
            let documentDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor:nil, create:true)
            let fileURL = documentDirectory.appendingPathComponent(FPUtility.generateImageFileName())
            if let data = image.pngData() {
                try? data.write(to: fileURL)
            }
            let media  = SSMedia(name: fileURL.lastPathComponent, mimeType: fileURL.fileMimeType(), filePath: fileURL.path, templateId: nil, moduleType: .forms)
            self.mediaAdded.append(media)
            tagListView.removeAllTags()
            self.mediaAdded.forEach { media in
                tagListView.addTag(media.name)
            }
            flushDirectSaveIfNeeded()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    
}

// MARK: - UIImagePickerControllerDelegate

extension TableAttachementView: UIImagePickerControllerDelegate{
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion:nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true) {
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
                    let documentDirectory = try self.fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor:nil, create:true)
                    let fileURL = documentDirectory.appendingPathComponent(FPUtility.generateVideoFileName())
                    try? mediadata?.write(to: fileURL)
                    let media  = SSMedia(name: fileURL.lastPathComponent, mimeType: fileURL.fileMimeType(), filePath: fileURL.path, templateId: nil, moduleType: .forms)
                    self.mediaAdded.append(media)
                    
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
                        let documentDirectory = try self.fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor:nil, create:true)
                        let fileURL = documentDirectory.appendingPathComponent(FPUtility.generateJPEGImageFileName())
                        try? imageData.write(to: fileURL)
                        let media  = SSMedia(name: fileURL.lastPathComponent, mimeType: fileURL.fileMimeType(), filePath: fileURL.path, templateId: nil, moduleType: .forms)
                        self.mediaAdded.append(media)
                    } catch {
                        print(error.localizedDescription)
                    }
                }
            }
            DispatchQueue.main.async {
                self.tagListView.removeAllTags()
                self.mediaAdded.forEach { media in
                    self.tagListView.addTag(media.name)
                }
                self.flushDirectSaveIfNeeded()
            }
        }
    }
}

// MARK: - PHPickerViewController

extension TableAttachementView: PHPickerViewControllerDelegate{
    func showPHImagePickerController() {
        var configuration = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        configuration.selectionLimit = 10
        configuration.filter = .any(of: [.images, .videos])
        
        let pickerViewController = PHPickerViewController(configuration: configuration)
        pickerViewController.modalPresentationStyle = .fullScreen
        pickerViewController.delegate = self
        parentViewController?.present(pickerViewController, animated:true, completion:nil)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true) {
            guard !results.isEmpty else {
                return
            }
            let arrIdentifiers = results.compactMap(\.assetIdentifier)
            _ = FPUtility.showHUDWithMessage(FPLocalizationHelper.localize("lbl_Adding_PhotosVideos"), detailText: "")
            let group = DispatchGroup()
            for result in results {
                group.enter()
                if result.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier){
                    result.itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.movie.identifier) { fileData, error in
                        if let fileData = fileData{
                            do {
                                let documentDirectory = try self.fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor:nil, create:true)
                                let fileURL = documentDirectory.appendingPathComponent(FPUtility.generateVideoFileName())
                                try? fileData.write(to: fileURL)
                                let media  = SSMedia(name: fileURL.lastPathComponent, mimeType: fileURL.fileMimeType(), filePath: fileURL.path, templateId: nil, moduleType: .forms)
                                self.mediaAdded.append(media)
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
                                let documentDirectory = try self.fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor:nil, create:true)
                                let fileURL = documentDirectory.appendingPathComponent(FPUtility.generateJPEGImageFileName())
                                try? imageData.write(to: fileURL)
                                let media  = SSMedia(name: fileURL.lastPathComponent, mimeType: fileURL.fileMimeType(), filePath: fileURL.path, templateId: nil, moduleType: .forms)
                                self.mediaAdded.append(media)
                            } catch let error{
                                print(error)
                            }
                        }
                        group.leave()
                    }
                }
            }
            group.notify(queue: DispatchQueue.main) {
                FPUtility.hideHUD()
                DispatchQueue.main.async {
                    self.tagListView.removeAllTags()
                    self.mediaAdded.forEach { media in
                        self.tagListView.addTag(media.name)
                    }
                    self.flushDirectSaveIfNeeded()
                }
            }
        }
    }
}


extension  TableAttachementView: UIDocumentPickerDelegate{
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
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
            let media  = SSMedia(name: tempUrl.lastPathComponent, mimeType: tempUrl.fileMimeType(), filePath: tempUrl.path, moduleType: .forms)
            self.mediaAdded.append(media)
        }
        
        FPUtility.hideHUD()
        if arrNames.count > 0 {
            let filesMsg = FPLocalizationHelper.localizeWith(args: [arrNames.joined(separator: ", ")], key: "msg_detectedExecutablesfiles")
            _  = FPUtility.showAlertController(title: FPLocalizationHelper.localize("msg_executablesfilesNotSupported"), message:filesMsg, completion:nil)
        }
        DispatchQueue.main.async {
            self.tagListView.removeAllTags()
            self.mediaAdded.forEach { media in
                self.tagListView.addTag(media.name)
            }
            self.flushDirectSaveIfNeeded()
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    }
    
}


extension TableAttachementView:TagListViewDelegate{
    func tagPressed(_ title: String, tagView: TagView, sender: TagListView){
        guard let media  =  mediaAdded.first(where: {$0.name == title}) else{return}
        if(media.filePath == nil){
            if(FPUtility.isConnectedToNetwork()){
                getMedialLocalUrl(media: media) { localMedia in
                    DispatchQueue.main.async {
                        self.previewMedia = localMedia
                        let previewController = QLPreviewController()
                        previewController.dataSource = self
                        FPUtility.topViewController()?.present(previewController, animated: false)
                    }
                }
            }else{
                _  = FPUtility.showAlertController(title: FPLocalizationHelper.localize("error_dialog_title"), message: FPLocalizationHelper.localize("msg_can_not_view_attachment_offline"), completion: nil)
            }
        }else{
            self.previewMedia = media
            let previewController = QLPreviewController()
            previewController.dataSource = self
            FPUtility.topViewController()?.present(previewController, animated: false)
        }
    }
    
    
    /// Gets local URL for media, downloading from server if needed
    func getMedialLocalUrl(media: SSMedia, completion: @escaping (SSMedia?) -> Void) {
        FPMedia.getPreviewFilePath(fileName: media.name, serverUrl: media.serverUrl) { filePath in
            var resultMedia = media
            resultMedia.filePath = filePath
            completion(resultMedia)
        }
    }

    
    fileprivate func deleteTag(_ title: String, _ media: SSMedia) {
        tagListView.removeTag(title)
        _ = mediaAdded.removeObject(media)
        if let mediaID =  media.id, !mediaID.isEmpty{
            mediaDeleted.append(media)
        }
    }
    
    func tagRemoveButtonPressed(_ title: String, tagView: TagView, sender: TagListView){
        guard let media  =  mediaAdded.first(where: {$0.name == title}) else{return}
        if(media.filePath != nil){
            deleteTag(title, media)
        }else{
            if(FPUtility.isConnectedToNetwork()){
                return deleteTag(title, media)
            }
            _  = FPUtility.showAlertController(title: FPLocalizationHelper.localize("error_dialog_title"), message: FPLocalizationHelper.localize("msg_can_not_delete_attachment_offline"), completion: nil)
        }
    }
    
}


extension TableAttachementView: QLPreviewControllerDataSource{
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        if let path = previewMedia!.filePath{
            return  NSURL(fileURLWithPath: path)
        }else{
            return  NSURL()
        }
    }
}

class PreviewItem: NSObject, QLPreviewItem {
    var previewItemURL: URL?
}

