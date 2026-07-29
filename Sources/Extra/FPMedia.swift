//
//  Media.swift
//  crm
//
//  Created by Soumya on 06/05/20.
//  Copyright © 2020 SmartServ. All rights reserved.
//

import UIKit
import MobileCoreServices

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
           completion(fileUrl)
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
    
    // MARK: - Shared Preview File Utilities
    
    /// Returns cache directory path for a media file name
    class func getCacheFilePath(for fileName: String) -> String? {
        guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        return cachesDirectory.appendingPathComponent(fileName).path
    }
    
    /// Returns document directory path for a media file name
    class func getDocumentFilePath(for fileName: String) -> String? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsDirectory.appendingPathComponent(fileName).path
    }
    
    /// Finds existing local file path, checking both document (legacy) and cache directories
    class func findLocalFilePath(for fileName: String) -> String? {
        // Check document directory first (legacy files)
        if let documentPath = getDocumentFilePath(for: fileName),
           FileManager.default.fileExists(atPath: documentPath) {
            return documentPath
        }
        
        // Check cache directory (new preview downloads)
        if let cachePath = getCacheFilePath(for: fileName),
           FileManager.default.fileExists(atPath: cachePath) {
            return cachePath
        }
        
        return nil
    }
    
    /// Gets local URL for media, downloading from server if needed (for preview purposes)
    /// - Parameters:
    ///   - fileName: Name of the file
    ///   - serverUrl: Server URL to download from if file doesn't exist locally
    ///   - completion: Completion handler with local file path (nil if failed)
    class func getPreviewFilePath(fileName: String, serverUrl: String?, completion: @escaping (String?) -> Void) {
        // Check if file exists locally (document or cache directory)
        if let existingPath = findLocalFilePath(for: fileName) {
            completion(existingPath)
            return
        }
        
        // If offline and file not found locally, return nil
        guard FPUtility.isConnectedToNetwork() else {
            completion(nil)
            return
        }
        
        // Validate server URL
        guard let serverUrl = serverUrl,
              serverUrl.isValidHttpsUrl || serverUrl.isValidHttpUrl else {
            completion(nil)
            return
        }
        
        guard let filePath = getCacheFilePath(for: fileName) else {
            completion(nil)
            return
        }
        
        // Download file to cache directory (new files go to cache)
        DispatchQueue.main.async {
            _ = FPUtility.showHUDWithMessage(FPLocalizationHelper.localize("lbl_Getting_File"), detailText: "")
        }

        FPUtility.download(urlString: serverUrl, toFile: filePath) { error in
            FPUtility.hideHUD()
            completion(error == nil ? filePath : nil)
        }
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
