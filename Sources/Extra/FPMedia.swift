//
//  Media.swift
//  crm
//
//  Created by Soumya on 06/05/20.
//  Copyright © 2020 SmartServ. All rights reserved.
//

import UIKit
import MobileCoreServices
import QuickLook
import CryptoKit
import Darwin
internal import SSMediaManager
internal import MBProgressHUD

class FPMedia: NSObject {

    var sqliteId: NSNumber?
    var objectId: String?
    var fileURL: String?
    var imageStrBase64 : String?
    var fileName: String?
    var createdAt: String?
    var moduleEntityId: String?
    var moduleId: NSNumber?
    var type: String?
    var updatedAt: String?
    var localLastUpdatedAt: String?
    var data: String?
    var fileData: Data?
    var serverUrl: String?

    override init() {
    }

    init(json: [String: Any], isForLocal:Bool) {
        super.init()
        let fileNameValue = json["altText"] as? String ?? json["fileName"] as? String ?? ""
        self.fileName = FPUtility.getSQLiteCompatibleStringValue(fileNameValue, isForLocal: isForLocal)
        self.createdAt = FPUtility.getSQLiteCompatibleStringValue(json["createdAt"], isForLocal: isForLocal)
        if let imageURL = json["file"] as? String {
            self.fileURL = FPUtility.getSQLiteCompatibleStringValue(imageURL, isForLocal: isForLocal)
        } else if let imageURL = json["imageURL"] as? String {
            self.fileURL = FPUtility.getSQLiteCompatibleStringValue(imageURL,isForLocal: isForLocal) //Offline DB case
        }
        
        if let id = json["id"] as? String {
            self.objectId = id
        }
        self.sqliteId = FPUtility.getNumberValue(json["sqliteId"])
        self.moduleEntityId = FPUtility.getSQLiteCompatibleStringValue(json["moduleEntityId"], isForLocal: isForLocal)
        self.moduleId = FPUtility.getNumberValue(json["moduleId"])        
        self.type = FPUtility.getSQLiteCompatibleStringValue(json["type"],isForLocal: isForLocal)
        self.updatedAt = FPUtility.getSQLiteCompatibleStringValue(json["updatedAt"], isForLocal: isForLocal)
        if let updatedAt = json["locallyUpdatedAt"] as? String {
            self.localLastUpdatedAt = updatedAt
        } else if let updatedAt = self.updatedAt {
            self.localLastUpdatedAt = updatedAt
        } else {
            self.localLastUpdatedAt = FPUtility.getStringWithTZFormat(Date())
        }
        //added for saving form data
        if json["data"] != nil {
            self.data = json["data"] as? String
        } else if let localImage = json["localImage"] as? String {
            self.data = FPUtility.getSQLiteCompatibleStringValue(localImage,isForLocal: isForLocal)
        } else {
            self.data = ""
        }
        if let data = self.data, data.isEmpty, let fileUrl = self.fileURL, !fileUrl.isEmpty{
            self.data  = self.fileURL
        }
    }
    
        
    func getFileExtension(fileName:String?) -> String {
        if let url = fileName, let lastComponent = url.components(separatedBy: ".").last {
            return lastComponent
        }
        return ""
            
    }
    func getFileType() -> FPMEDIA_TYPE {
        if let url = self.fileURL, let lastComponent = url.components(separatedBy: ".").last {
            return self.getTheTypeAccording(to: lastComponent)
        }
        return .UNKNOWN
    }

    private func getTheTypeAccording(to string: String) -> FPMEDIA_TYPE {
        switch string.lowercased() {
        case "jpg", "jpeg":
            return .IMAGEJPEG
        case "png":
            return .IMAGEPNG
        case "movie", "mp4", "mov", "mpg", "avi", "3gpp":
            return .VIDEO
        case "pdf":
            return .PDF
        case "xls", "xlsx":
            return .XLS
        case "pptx", "ppt":
            return .PPTX
        case "doc":
            return .DOC
        case "docx":
            return .DOCX
        case "csv":
            return .CSV
        case "ico":
            return .ICO
        case "odp":
            return .ODP
        case "odt":
            return .ODT
        case "txt":
            return .TXT
        default:
            return .UNKNOWN
        }
    }
    

    func getJSONForAPI() -> [String:Any] {
        var json = [String: Any]()
        if let serverUrl = self.serverUrl{
            json["file"] = serverUrl
            json["altText"] = self.fileName
            json["type"] = self.type
        } else if let fileUrl = self.fileURL{
            json["file"] = fileUrl
            json["altText"] = self.fileName
            json["type"] = self.type
        }else{
            json["fileName"] = self.fileName
            if self.fileData != nil {
                json["data"] = self.fileData?.base64EncodedString()
            }else{
                json["data"] = self.data
            }
        }
        return json
    }
    
    func getFormJSONForAPI() -> [String:Any] {
        var json = [String: Any]()
        if let serverUrl = self.serverUrl{
            json["file"] = serverUrl
            json["altText"] = self.fileName
            json["type"] = self.type
        }
        else{
            json["fileName"] = self.fileName
            if self.fileData != nil {
                json["data"] = self.fileData?.base64EncodedString()
            }else{
                json["data"] = self.data
            }
        }
        return json
    }
    
    func getJSONForDeleteAttachment() -> [String:Any] {
        var json = [String: Any]()
        json["id"] = self.objectId
        return json
    }
    
    
    func getJSONBillingForAPI() -> [String:Any] {
        var json = [String: Any]()
        json["altText"] = self.fileName
        json["file"] = self.fileURL
        json["type"] = self.type
        return json
    }
    
    func getCopy() -> FPMedia {
        let copy = FPMedia()
        copy.sqliteId = self.sqliteId
        copy.objectId = self.objectId
        copy.fileURL = self.fileURL
        copy.fileName = self.fileName
        copy.createdAt = self.createdAt
        copy.moduleEntityId = self.moduleEntityId
        copy.moduleId = self.moduleId
        copy.type = self.type
        copy.updatedAt = self.updatedAt
        copy.localLastUpdatedAt = self.localLastUpdatedAt
        copy.data = self.data
        copy.fileData = self.fileData
        return copy
    }
    
    
    func getJSONForPDF() -> [String:Any] {
        var json = [String: Any]()
        json["id"] = self.objectId ?? ""
        json["altText"] = self.fileName ?? ""
//        if let strURL = self.imageURL {
//            if let url = URL(string: strURL) {
//                let data = try? Data(contentsOf: url)
//                if let imageData = data {
//                    json["file"] = "data:image/png;base64,\(imageData.base64EncodedString())"
//                }
//            }
//        } else if let fileData = self.fileData {
//            json["file"] = "data:image/png;base64,\(fileData)"
//        }
        let strMedia = "data:image/png;base64,\(data ?? "")"
        json["file"] = strMedia
        json["type"] = self.type
        return json
        
    }
    
    func getMedialLocalUrl(completion: @escaping (NSURL?) -> Void) {
        if FPUtility.isConnectedToNetwork(){
            let fileUrl = NSURL(string: self.fileURL ?? "")
            if fileUrl?.isFileURL ?? false && FPMedia.isMediaExistInDocumentsDirectory(fileName: self.fileName ?? ""){
                completion(fileUrl)
            }else{
                DispatchQueue.main.async {
                    _ = FPUtility.showHUDWithMessage(FPLocalizationHelper.localize("lbl_Getting_Document"), detailText: "")
                }
                let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
                let documentsPath = paths.first ?? ""
                let filePath = (documentsPath as NSString).appendingPathComponent(self.fileName ?? "")
                let tempUrl:NSURL = NSURL(fileURLWithPath: filePath)
                FPUtility.download(urlString:self.fileURL ?? "", toFile: tempUrl.absoluteString ?? "") { error in
                    FPUtility.hideHUD()
                    if error == nil{
                        self.fileURL = tempUrl.absoluteString
                    }
                    completion(tempUrl)
                }
            }
            
        }else{
            DispatchQueue.global(qos: .userInitiated).async {
                var fileUrl = NSURL(string: self.fileURL ?? "")
                if !(fileUrl?.isFileURL ?? false){
                    fileUrl = NSURL(string: self.data ?? "")
                }
                let fileUrls = FPMedia.getAllDocumentDirectoryMedia()
                for url in fileUrls ?? []{
                    if (url.path as NSString).lastPathComponent == self.fileName ?? ""{
                        fileUrl = url as? NSURL
                    }
                }
                DispatchQueue.main.async {
                    completion(fileUrl)
                }
            }
        }
    }

    class func getAllDocumentDirectoryMedia() -> [URL]? {
        let documentsURL =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            return fileURLs
        } catch {
            print("Error while enumerating files \(documentsURL.path): \(error.localizedDescription)")
        }
        return nil
    }
    
    class func getExtensionWith(fileName:String) -> String {
        if let lastComponent = fileName.components(separatedBy: ".").last {
            return lastComponent
        }
        return ""
    }
    
    class func isMediaExistInDocumentsDirectory(fileName: String) -> Bool {
        if let fileURLs = self.getAllDocumentDirectoryMedia() {
            for fileUrl in fileURLs {
                if fileUrl.absoluteString.contains(fileName) {
                    return true
                }
            }
        }
        return false
    }
    
    // MARK: - Attachment gallery

    class func presentAttachmentGallery(_ attachments: [SSMedia], selectedIndex: Int, from presenter: UIViewController) {
        guard attachments.indices.contains(selectedIndex),
              presenter.viewIfLoaded?.window != nil,
              presenter.presentedViewController == nil else { return }
        let preview = FPAttachmentGalleryController(attachments: attachments, selectedIndex: selectedIndex)
        presenter.present(preview, animated: true)
    }

    static func previewCacheURL(for media: SSMedia) -> URL? {
        guard let serverURL = media.serverUrl, !serverURL.isEmpty,
              let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let digest = SHA256.hash(data: Data(serverURL.utf8)).map { String(format: "%02x", $0) }.joined()
        let component = (media.name as NSString).lastPathComponent
        let name = ["", ".", "..", "/"].contains(component) ? "Attachment" : component
        return caches.appendingPathComponent("ZenFormsAttachmentPreviews", isDirectory: true)
            .appendingPathComponent(digest, isDirectory: true)
            .appendingPathComponent(name)
    }

    fileprivate static func localPreviewURL(for media: SSMedia) -> URL? {
        let local = FPFormsServiceManager.resolveUploadSource(media.filePath).map { URL(fileURLWithPath: $0) }
        return [local, previewCacheURL(for: media)].compactMap { $0 }.first(where: isUsablePreviewFile)
    }

    private static func isUsablePreviewFile(_ url: URL) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber else { return false }
        return size.int64Value > 0
    }

    @discardableResult
    static func publishPreviewFile(at source: URL, to destination: URL) -> Bool {
        guard isUsablePreviewFile(source) else { return false }
        if isUsablePreviewFile(destination) {
            if source != destination { try? FileManager.default.removeItem(at: source) }
            return true
        }
        // Local copies can inherit the source timestamp. Age the cache entry from publication.
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: source.path)
        // Publish atomically so readers never observe a partially written cache entry.
        return Darwin.rename(source.path, destination.path) == 0
    }

    func getThumbnailBasedOnDocType() -> String {
        
        switch self.getFileType() {
        case .PDF:
            return "pdf"
        case .DOC:
            return "doc"
        case .DOCX:
            return "docx"
        case .XLS, .XLSX:
            return "xls"
        case .PPT:
            return "ppt"
        case .PPTX:
            return "pptx"
        case .CSV:
            return "csv"
        case .ICO:
            return "ico"
        case .ODP:
            return "odp"
        case .ODT:
            return "odt"
        case .TXT:
            return "txt"
        case .IMAGEJPEG:
            return "jpg"
        case .IMAGEPNG:
            return "png"
        case .VIDEO:
            return "video"
        default:
            return "document-unknown"
        }
    }
    
    func getMimeTypeWithExtension() -> String? {
       let fileExtension = self.getFileExtension(fileName: self.fileName)

        guard !fileExtension.isEmpty else { return nil }

        if let utiRef = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension as CFString, nil) {
            let uti = utiRef.takeUnretainedValue()
            utiRef.release()

            if let mimeTypeRef = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType) {
                let mimeType = mimeTypeRef.takeUnretainedValue()
                mimeTypeRef.release()
                return mimeType as String
            }
        }

        return nil
    }

}


public enum FPMEDIA_TYPE:Int, RawRepresentable{
    public init?(rawValue: RawValue) {
        switch rawValue {
        case "IMAGEJPEG":
            self = .IMAGEJPEG
        case "IMAGEPNG":
            self = .IMAGEPNG
        case "VIDEO":
            self = .VIDEO
        case "PDF":
            self = .PDF
        case "XLS" , "XLSX":
            self = .XLS
        case "PPTX", "PPT":
            self = .PPTX
        case "DOC":
            self = .DOC
        case "DOCX":
            self = .DOCX
        case "CSV":
            self = .CSV
        case "ICO":
            self = .ICO
        case "ODP":
            self = .ODP
        case "ODT":
            self = .ODT
        case "TXT":
            self = .TXT
        case "UNKNOWN":
            self = .UNKNOWN
        default:
            return nil
        }
    }
    
    case IMAGEJPEG,IMAGEPNG,VIDEO,PDF,XLS,XLSX,PPT,PPTX,DOC,DOCX,CSV,ICO,ODP,ODT,TXT,UNKNOWN
    public typealias RawValue = String
    
    public var rawValue: RawValue {
        switch self {
        case .IMAGEJPEG:
            return "IMAGEJPEG"
        case .IMAGEPNG:
            return "IMAGEPNG"
        case .VIDEO:
            return "VIDEO"
        case .PDF:
            return "PDF"
        case .XLS:
            return "XLS"
        case .XLSX:
            return "XLS"
        case .PPTX:
            return "PPTX"
        case .PPT:
            return "PPTX"
        case .DOC:
            return "DOC"
        case .DOCX:
            return "DOCX"
        case .CSV:
            return "CSV"
        case .ICO:
            return "ICO"
        case .ODP:
            return "ODP"
        case .ODT:
             return "ODT"
        case .TXT:
            return "TXT"
        case .UNKNOWN:
            return "UNKNOWN"
        }
    }
    
}


extension String{

    var isValidHttpsUrl: Bool {
        guard let url = URL(string: self) else { return false }
        return url.scheme == "https"
    }

    var isValidHttpUrl: Bool {
        guard let url = URL(string: self) else { return false }
        return url.scheme == "http"
    }

    var isValidFileUrl: Bool {
        return URL(string: self)?.isFileURL ?? false
    }
}


private final class FPAttachmentPreviewItem: NSObject, QLPreviewItem {
    let media: SSMedia
    var previewItemURL: URL?
    var previewItemTitle: String? { media.name }

    init(media: SSMedia) {
        self.media = media
        previewItemURL = FPMedia.localPreviewURL(for: media)
    }
}

private final class FPAttachmentGalleryController: QLPreviewController, QLPreviewControllerDataSource, UIGestureRecognizerDelegate {
    private let items: [FPAttachmentPreviewItem]
    private var loadingIndices = Set<Int>()
    private let previewStatus = UILabel()
    private var loadingHUD: MBProgressHUD?
    private var previousButton: UIButton?
    private var nextButton: UIButton?
    private var pageObservation: NSKeyValueObservation?
    private var swipeStartIndex: Int?

    init(attachments: [SSMedia], selectedIndex: Int) {
        items = attachments.map { FPAttachmentPreviewItem(media: $0) }
        super.init(nibName: nil, bundle: nil)
        dataSource = self
        currentPreviewItemIndex = selectedIndex
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Use init(attachments:selectedIndex:)")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        previewStatus.font = .preferredFont(forTextStyle: .body)
        previewStatus.adjustsFontForContentSizeCategory = true
        previewStatus.textAlignment = .center
        previewStatus.numberOfLines = 0
        previewStatus.backgroundColor = .secondarySystemBackground
        previewStatus.translatesAutoresizingMaskIntoConstraints = false
        previewStatus.isHidden = true
        view.addSubview(previewStatus)
        NSLayoutConstraint.activate([
            previewStatus.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            previewStatus.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            previewStatus.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor)
        ])
        guard items.count > 1 else { return }

        let previous = navigationButton(symbol: "chevron.left", label: "Previous Attachment", offset: -1)
        let next = navigationButton(symbol: "chevron.right", label: "Next Attachment", offset: 1)
        let controls = UIStackView(arrangedSubviews: [previous, next])
        controls.spacing = 8
        controls.translatesAutoresizingMaskIntoConstraints = false

        let background = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        background.layer.cornerRadius = 16
        background.clipsToBounds = true
        background.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(background)
        background.contentView.addSubview(controls)
        NSLayoutConstraint.activate([
            background.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            background.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            background.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            background.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            controls.leadingAnchor.constraint(equalTo: background.contentView.leadingAnchor, constant: 12),
            controls.trailingAnchor.constraint(equalTo: background.contentView.trailingAnchor, constant: -12),
            controls.topAnchor.constraint(equalTo: background.contentView.topAnchor, constant: 8),
            controls.bottomAnchor.constraint(equalTo: background.contentView.bottomAnchor, constant: -8)
        ])

        previousButton = previous
        nextButton = next
        updateNavigation()
        pageObservation = observe(\.currentPreviewItemIndex, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.updateNavigation()
                self?.loadCurrentAttachment()
            }
        }

        let swipe = UIPanGestureRecognizer(target: self, action: #selector(changePage(_:)))
        swipe.maximumNumberOfTouches = 1
        swipe.cancelsTouchesInView = false
        swipe.allowedScrollTypesMask = .all
        swipe.delegate = self
        view.addGestureRecognizer(swipe)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadCurrentAttachment()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        hideLoadingHUD()
    }

    private func showLoadingHUD() {
        previewStatus.isHidden = true
        guard loadingHUD == nil else { return }
        let hud = FPUtility.showHUDWithMessage(FPLocalizationHelper.localize("lbl_Getting_File"), detailText: nil, in: view)
        hud.isUserInteractionEnabled = false
        loadingHUD = hud
    }

    private func hideLoadingHUD() {
        loadingHUD?.hide(animated: true)
        loadingHUD = nil
    }

    private func loadCurrentAttachment() {
        let index = currentPreviewItemIndex
        guard items.indices.contains(index) else { return }
        let item = items[index]
        if item.previewItemURL != nil {
            hideLoadingHUD()
            previewStatus.isHidden = true
            return
        }

        if let cachedURL = FPMedia.localPreviewURL(for: item.media) {
            item.previewItemURL = cachedURL
            hideLoadingHUD()
            previewStatus.isHidden = true
            refreshCurrentPreviewItem()
            return
        }

        guard FPUtility.isConnectedToNetwork() else {
            showPreviewStatus(FPLocalizationHelper.localize("msg_can_not_view_attachment_offline"))
            return
        }
        let unavailable = NSLocalizedString("Could not preview this attachment.", bundle: .module, comment: "Attachment preview failure")
        guard let serverURL = item.media.serverUrl,
              serverURL.isValidHttpsUrl || serverURL.isValidHttpUrl,
              let destination = FPMedia.previewCacheURL(for: item.media) else {
            showPreviewStatus(unavailable)
            return
        }

        showLoadingHUD()
        guard !loadingIndices.contains(index) else { return }
        let directory = destination.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            showPreviewStatus(unavailable)
            return
        }

        loadingIndices.insert(index)
        let staging = directory.appendingPathComponent(UUID().uuidString)
        FPUtility.download(urlString: serverURL, toFile: staging.path) { [weak self] error in
            if error == nil {
                FPMedia.publishPreviewFile(at: staging, to: destination)
            }
            try? FileManager.default.removeItem(at: staging)
            DispatchQueue.main.async {
                guard let self else { return }
                self.loadingIndices.remove(index)
                item.previewItemURL = FPMedia.localPreviewURL(for: item.media)
                guard self.currentPreviewItemIndex == index else { return }
                self.hideLoadingHUD()
                if item.previewItemURL != nil {
                    self.previewStatus.isHidden = true
                    self.refreshCurrentPreviewItem()
                } else {
                    self.showPreviewStatus(unavailable)
                }
            }
        }
    }

    private func showPreviewStatus(_ text: String) {
        hideLoadingHUD()
        previewStatus.text = text
        previewStatus.isHidden = false
        view.bringSubviewToFront(previewStatus)
    }

    private func navigationButton(symbol: String, label: String, offset: Int) -> UIButton {
        var configuration = UIButton.Configuration.gray()
        configuration.image = UIImage(systemName: symbol)
        configuration.cornerStyle = .capsule
        let button = UIButton(configuration: configuration)
        button.accessibilityLabel = NSLocalizedString(label, bundle: .module, comment: "Attachment preview navigation")
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        button.addAction(UIAction { [weak self] _ in self?.changePage(by: offset) }, for: .touchUpInside)
        return button
    }

    @objc private func changePage(_ swipe: UIPanGestureRecognizer) {
        switch swipe.state {
        case .began:
            swipeStartIndex = currentPreviewItemIndex
        case .ended:
            defer { swipeStartIndex = nil }
            guard let startIndex = swipeStartIndex, startIndex == currentPreviewItemIndex else { return }
            let distance = swipe.translation(in: view)
            guard abs(distance.x) >= 44, abs(distance.x) > abs(distance.y) else { return }
            let offset = distance.x < 0 ? 1 : -1
            // QuickLook can page natively for the same swipe and updates its index only after its
            // paging animation. Wait for it to settle so one swipe never moves two attachments.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self else { return }
                if self.currentPreviewItemIndex == startIndex {
                    self.changePage(by: offset)
                } else {
                    self.updateNavigation()
                    self.loadCurrentAttachment()
                }
            }
        case .cancelled, .failed:
            swipeStartIndex = nil
        default:
            break
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let swipe = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = swipe.velocity(in: view)
        return abs(velocity.x) > abs(velocity.y)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    private func changePage(by offset: Int) {
        let index = currentPreviewItemIndex + offset
        guard items.indices.contains(index) else { return }
        currentPreviewItemIndex = index
        updateNavigation()
        loadCurrentAttachment()
    }

    private func updateNavigation() {
        let hasPrevious = currentPreviewItemIndex > 0
        let hasNext = currentPreviewItemIndex < items.count - 1
        previousButton?.isEnabled = hasPrevious
        nextButton?.isEnabled = hasNext
    }

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        items.count
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        items[index]
    }
}
