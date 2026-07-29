//
//  FPUtility.swift
//  crm
//
//  Created by Mayur on 30/10/19.
//  Copyright © 2019 SmartServ. All rights reserved.
//

import Foundation
import UIKit
internal import Reachability
internal import MBProgressHUD

let SCREEN_SIZE = UIScreen.main.bounds
var SCREEN_WIDTH_S = UIScreen.main.bounds.size.width
let invalidJson = "Not a valid JSON"

class FPUtility : NSObject{
    
    class func getSupportedDocumentTypesForFileUpload() -> [String]{
        // return SSMediaManager.shared.getSupportedDocumentTypesForFileUpload()
        return ["org.openxmlformats.wordprocessingml.document",
                "com.microsoft.powerpoint.​ppt",
                "com.microsoft.powerpoint.​pptx",
                "org.openxmlformats.presentationml.presentation",
                "com.microsoft.excel.xls",
                "org.openxmlformats.spreadsheetml.sheet",
                "com.microsoft.ico",
                "com.microsoft.word.doc",
                "com.microsoft.word.docx",
                "com.adobe.pdf",
                "public.jpeg",
                "public.jpeg-2000",
                "public.png",
                "public.plain-text",
                "public.text",
                "public.rtf",
                "org.oasis-open.opendocument.text",
                "org.oasis-open.opendocument.presentation",
                "org.oasis-open.opendocument.spreadsheet",
                "public.movie",
                "public.video",
                "com.apple.quicktime-movie",
                "public.avi",
                "public.mpeg",
                "public.mpeg-4",
                "public.3gpp",
                "public.3gpp2"]
        
    }
    
    class func nanoID(size: Int = 12) -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        var bytes = [UInt8](repeating: 0, count: size)
        _ = SecRandomCopyBytes(kSecRandomDefault, size, &bytes)
        return String(bytes.map { chars[chars.index(chars.startIndex, offsetBy: Int($0) % chars.count)] })
    }
    
    class func make(_ systemName: String, color: UIColor = .systemBlue) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)

        return UIImage(systemName: systemName, withConfiguration: config)?
            .withTintColor(color, renderingMode: .alwaysOriginal)
    }
    
    static func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
    
    static func getDateStringWithBySubtractingTimeInterval(sec:Int, from stringUTCDate: String) -> String {
        let date = FPUtility.getDateFrom(stringUTCDate)
        let calendar = Calendar.current
        let newdate = calendar.date(byAdding: .second, value: -5, to: date) ?? Date()
        return FPUtility.getUTCDateSQLiteQuery(date: newdate) ?? ""
    }
    
    class func getUTCDateSQLiteQuery(date:Date) -> String? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        return dateFormatter.string(from: date)
    }
    
    class func getStringWithTZFormat(_ date:Date, format:String = "yyyy-MM-dd'T'HH:mm:ss.SSSZ") -> String {
        let dateFormat = DateFormatter()
        dateFormat.dateFormat = format
        dateFormat.locale = Locale(identifier: "en_US_POSIX")
        dateFormat.timeZone = TimeZone(abbreviation: "UTC")
        return dateFormat.string(from: date)
    }
    
    class func getDateFrom(_ dateInString:String, format:String) -> Date? {
        let dateFormat = DateFormatter()
        dateFormat.locale = Locale(identifier: "en_US_POSIX")
        dateFormat.dateFormat = format
        return dateFormat.date(from: dateInString)
    }
    
    class func getDateFrom(_ dateInString:String) -> Date {
        let dateFormat = DateFormatter()
        dateFormat.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        dateFormat.locale = Locale(identifier: "en_US_POSIX")
        return dateFormat.date(from: dateInString) ?? Date()
    }
    
    class func getOPDateFrom(_ dateInString:String) -> Date? {
        let dateFormat = DateFormatter()
        dateFormat.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        dateFormat.locale = Locale(identifier: "en_US_POSIX")
        dateFormat.timeZone = TimeZone(abbreviation: "UTC")
        let fixedDateString = dateInString.replacingOccurrences(of: "__X2E__", with: ".")
        if let date = dateFormat.date(from: fixedDateString){
            return date
        }else{
            dateFormat.dateFormat = "yyyy-MM-dd"
            return dateFormat.date(from: dateInString)
        }
    }
    
    class func dateString(_ date:Date, withCustomFormat format:String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        let stringFromDate:String = formatter.string(from: date)
        return stringFromDate
    }
    
    class func colorwithHexString(_ hex:String) -> UIColor {
        var cString:String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if (cString.hasPrefix("#")) {
            cString.remove(at: cString.startIndex)
        }
        
        if ((cString.count) != 6) {
            return UIColor.gray
        }
        
        var rgbValue:UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)
        
        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
    
    class func getArrayValue(_ value:Any?) -> [Any]? {
        if self.isObjectEmpty(value)
        {return nil}
        if (value is Array<Any>) {
            return value as? [Any]
        }
        return nil
    }
    
    class func getNumberValue(_ value:Any?) -> NSNumber? {
        if self.isObjectEmpty(value)
        {return nil }
        if (value is NSNumber) {
            return (value as! NSNumber)
        }else if (value is String) {
            return NumberFormatter().number(from: (value as! String))
        }
        return nil
    }
    
    class func getSQLiteCompatibleStringValue(_ value:Any?, isForLocal:Bool) -> String? {
        if self.isObjectEmpty(value)
        {return nil}
        if (value is NSNumber) {
            return (value as! NSNumber).stringValue
        } else if (value is String) {
            if isForLocal {
                if (value as! String).contains("'") {
                    return (value as! String).replacingOccurrences(of: "'", with:"''")
                } else {
                    return value as? String
                }
            } else {
                if (value as! String).contains("''") {
                    return (value as! String).replacingOccurrences(of: "''", with:"'")
                }
                return value as? String
            }
        }
        return nil
    }
    
    class func getStringValue(_ value:Any?) -> String? {
        if self.isObjectEmpty(value){
            return nil
        }
        if (value is NSNumber) {
            return (value as! NSNumber).stringValue
        } else if (value is String) {
            return value as? String
        }
        return nil
    }
    
    class func isObjectEmpty(_ object:Any?) -> Bool {
        if object == nil{
            return true
        }else{
            return false
        }
    }
    
    @objc class func getCacheDirectoryURL() -> URL? {
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    }

    @objc class func moveFileToCache(atPath filePath: String) -> String? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: filePath) else { return nil }
        
        let sourceURL = URL(fileURLWithPath: filePath)
        let fileName = sourceURL.lastPathComponent
        guard let cacheDirectoryURL = getCacheDirectoryURL() else { return nil }
        let destinationURL = cacheDirectoryURL.appendingPathComponent(fileName)
        
        // Remove existing file at destination if any
        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }
        
        do {
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
            return destinationURL.path
        } catch {
            return nil
        }
    }
    
    class func downloadAnyData(from urlString: String?, completion: @escaping ((_ data: Data?) -> Void)) {
        guard let unwrapedURLString = urlString, let url = URL(string: unwrapedURLString) else {
            completion(nil)
            return
        }
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let httpURLResponse = response as? HTTPURLResponse, httpURLResponse.statusCode == 200, error == nil {
                guard let data = data else {
                    completion(nil)
                    return
                }
                completion(data)
            } else {
                completion(nil)
            }
        }.resume()
    }
    
    class func download(urlString: String, toFile fileUrlString: String, completion: @escaping (Error?) -> Void) {
        guard let remoteUrl = URL.init(string: urlString) else {
            // Invalid URL, call completion with error
            completion(NSError(domain: "FPUtility", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        // Create file URL from path
        let fileUrl = URL(fileURLWithPath: fileUrlString)
        
        // Download the remote URL to a file
        let task = URLSession.shared.downloadTask(with: remoteUrl) {
            (tempURL, response, error) in
            
            // Check for network errors
            if let error = error {
                completion(error)
                return
            }
            
            // Validate HTTP response status code
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let error = NSError(domain: "FPUtility", code: httpResponse.statusCode, 
                                  userInfo: [NSLocalizedDescriptionKey: "HTTP Error \(httpResponse.statusCode)"])
                completion(error)
                return
            }
            
            // Ensure we have a temp file
            guard let tempURL = tempURL else {
                completion(NSError(domain: "FPUtility", code: -1, 
                                 userInfo: [NSLocalizedDescriptionKey: "No temporary file"]))
                return
            }
            
            do {
                // Remove any existing document at file
                if FileManager.default.fileExists(atPath: fileUrl.path) {
                    try FileManager.default.removeItem(at: fileUrl)
                }
                
                // Copy the tempURL to file
                try FileManager.default.copyItem(
                    at: tempURL,
                    to: fileUrl
                )
                
                completion(nil)
            }
            
            // Handle potential file system errors
            catch let fileError {
                completion(fileError)
            }
        }
        
        // Start the download
        task.resume()
    }
    
    // MARK: - Filename Generation (matching main app convention)
    
    /// Generates a unique filename for images using timestamp (PNG format)
    class func generateImageFileName(moduleName: String = "InspectionForms") -> String {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        return String(format: "%@_%lld.png", moduleName, timestamp)
    }
    
    /// Generates a unique filename for JPEG images using timestamp
    class func generateJPEGImageFileName(moduleName: String = "InspectionForms") -> String {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        return String(format: "%@_%lld.jpeg", moduleName, timestamp)
    }
    
    /// Generates a unique filename for videos using timestamp (MP4/MOV format)
    class func generateVideoFileName(moduleName: String = "InspectionForms", extension fileExtension: String = "mov") -> String {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        return String(format: "%@_%lld.%@", moduleName, timestamp, fileExtension)
    }
    
    /// Generates a unique filename for documents using timestamp with original filename
    class func generateDocFileName(originalName: String, moduleName: String = "InspectionForms") -> String {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let fileNameWithoutExtension = (originalName as NSString).deletingPathExtension
        let fileExtension = (originalName as NSString).pathExtension
        return String(format: "%@_%@_%lld.%@", moduleName, fileNameWithoutExtension, timestamp, fileExtension)
    }
    
    class func downloadedImage(from urlString: String?, completion: @escaping ((_ image: UIImage?) -> Void)) {
        guard let unwrapedURLString = urlString, let url = URL(string: unwrapedURLString) else {
            completion(nil)
            return
        }
        DispatchQueue.global(qos: .utility).async {
            URLSession.shared.dataTask(with: url) { data, response, error in
                guard let httpURLResponse = response as? HTTPURLResponse, httpURLResponse.statusCode == 200,
                      let mimeType = response?.mimeType, mimeType.hasPrefix("image"),
                      let data = data, error == nil,
                      let image = UIImage(data: data) else {
                    completion(nil)
                    return
                }
                completion(image)
            }.resume()
        }
        
    }
    
}

// MARK: - AlertController

extension FPUtility {
    
    class func showErrorMessage(_ delegate:Any?, withTitle title:String?, withWarningMessage message:String?) {
        let alert = self.errorAlertController(title: title, message:message)
        DispatchQueue.main.async {
            self.topViewController()?.present(alert, animated:true, completion:nil)
        }
    }
    
    class func createAlertController(title:String?, andMessage detail:String?, withPositiveAction positiveButton:String?, andHandler positiveHandler: ((UIAlertAction?)->Void)?, withNegativeAction negativeButton:String?, andHandler negativeHandler: ((UIAlertAction?)->Void)?) -> UIAlertController {
        let alert = UIAlertController(title: title, message:detail, preferredStyle:.alert)
        if let positiveButton = positiveButton{
            let ok = UIAlertAction(title: positiveButton, style:.default, handler:positiveHandler)
            alert.addAction(ok)
        }
        
        if let negativeButton = negativeButton{
            let cancel = UIAlertAction(title: negativeButton, style:.default, handler:negativeHandler)
            alert.addAction(cancel)
        }
        alert.applyLegacyActionSheetStyle()
        return alert
    }
    
    class func showAlertController(title:String?, andMessage detail:String?, completion alertPresentCompletion: (()->Void)?, withPositiveAction positiveButton:String?, style positiveButtonStyle:UIAlertAction.Style, andHandler positiveHandler: ((UIAlertAction?)->Void)?, withNegativeAction negativeButton:String?, style negativeButtonStyle:UIAlertAction.Style, andHandler negativeHandler: ((UIAlertAction?)->Void)?, parentVC:UIViewController?) -> UIAlertController {
        let alert = UIAlertController(title: title, message:detail, preferredStyle:.alert)
        
        if let negativeButton = negativeButton{
            let cancel = UIAlertAction(title: negativeButton,style:negativeButtonStyle, handler:negativeHandler)
            alert.addAction(cancel)
        }
        
        if let positiveButton = positiveButton{
            let ok = UIAlertAction(title: positiveButton, style:positiveButtonStyle, handler:positiveHandler)
            alert.addAction(ok)
        }
        
        alert.applyLegacyActionSheetStyle()
        if (parentVC != nil) {
            DispatchQueue.main.async {
                parentVC?.present(alert, animated:true, completion:alertPresentCompletion)
            }
        }
        else {
            DispatchQueue.main.async {
                self.topViewController()?.present(alert, animated:true, completion:alertPresentCompletion)
            }
        }
        
        return alert
    }
    
    class func showAlertController(title:String?, andMessage detail:String?, completion alertPresentCompletion: (()->Void)?, withPositiveAction positiveButton:String?, style positiveButtonStyle:UIAlertAction.Style, andHandler positiveHandler: ((UIAlertAction?)->Void)?, withNegativeAction negativeButton:String?, style negativeButtonStyle:UIAlertAction.Style, andHandler negativeHandler: ((UIAlertAction?)->Void)?) -> UIAlertController {
        let alert = UIAlertController(title: title, message:detail, preferredStyle:.alert)
        
        if let positiveButton = positiveButton{
            let ok = UIAlertAction(title: positiveButton,
                                   style:positiveButtonStyle,
                                   handler:positiveHandler)
            alert.addAction(ok)
        }
        if let negativeButton = negativeButton{
            let cancel = UIAlertAction(title: negativeButton,
                                       style:negativeButtonStyle,
                                       handler:negativeHandler)
            
            alert.addAction(cancel)
        }
        alert.applyLegacyActionSheetStyle()
        self.topViewController()?.present(alert, animated:true, completion:alertPresentCompletion)
        return alert
    }
    
    class func showAlertController1(title:String?, andMessage detail:String?, completion alertPresentCompletion: (()->Void)?, withPositiveAction positiveButton:String?, style positiveButtonStyle:UIAlertAction.Style, andHandler positiveHandler: ((UIAlertAction?)->Void)?, withNegativeAction negativeButton:String?, style negativeButtonStyle:UIAlertAction.Style, andHandler negativeHandler: ((UIAlertAction?)->Void)?) -> UIAlertController {
        let alert = UIAlertController(title: title, message:detail, preferredStyle:.alert)
        

        if let negativeButton = negativeButton{
            let cancel = UIAlertAction(title: negativeButton,
                                       style:negativeButtonStyle,
                                       handler:negativeHandler)
            
            alert.addAction(cancel)
        }
        
        if let positiveButton = positiveButton{
            let ok = UIAlertAction(title: positiveButton,
                                   style:positiveButtonStyle,
                                   handler:positiveHandler)
            alert.addAction(ok)
        }
        
        alert.applyLegacyActionSheetStyle()
        self.topViewController()?.present(alert, animated:true, completion:alertPresentCompletion)
        return alert
    }
    
    class func errorAlertController(title:String?, message:String?) -> UIAlertController {
        let alert = FPUtility.createAlertController(title: title,
                                                  andMessage:message,
                                                  withPositiveAction:FPLocalizationHelper.localize("OK"),
                                                  andHandler:nil,
                                                  withNegativeAction:nil,
                                                  andHandler:nil)
        alert.applyLegacyActionSheetStyle()
        return alert
    }
    
    class func topViewController() -> UIViewController? {
        var topViewController = UIApplication.shared.keyWindow?.rootViewController
        while true
        {
            if (topViewController?.presentedViewController != nil) {
                topViewController = topViewController?.presentedViewController
            } else if (topViewController is UINavigationController) {
                let nav = topViewController as! UINavigationController
                topViewController = nav.topViewController
            } else if (topViewController is UITabBarController) {
                let tab = topViewController as! UITabBarController
                topViewController = tab.selectedViewController
            }else {
                break
            }
        }
        return topViewController
    }
    
    class func showAlertController(title:String?, message:String?, completion: (()->Void)?) -> UIAlertController {
        return self.showAlertController(title: title, message:message, viewController:nil, completion:completion)
    }
    
    class func showAlertController(title:String?, message:String?, viewController:UIViewController?, completion: (()->Void)?) -> UIAlertController {
        let alert = self.errorAlertController(title: title, message:message)
        alert.applyLegacyActionSheetStyle()
        if viewController != nil {
            viewController!.present(alert, animated:true, completion:completion)
        } else {
            self.topViewController()?.present(alert, animated:true, completion:completion)
        }
        return alert
    }
    
    class func showAlertController(title:String?, message:String?, parentVC:UIViewController?, completion: (()->Void)?) -> UIAlertController {
        
        let alert = FPUtility.createAlertController(title: title,
                                                    andMessage:message, withPositiveAction:FPLocalizationHelper.localize("OK"),
                                                    andHandler:nil,
                                                    withNegativeAction:nil,
                                                    andHandler:nil)
        if (parentVC != nil) {
            DispatchQueue.main.async {
                parentVC?.present(alert, animated:true, completion:completion)
            }
        }
        else {
            DispatchQueue.main.async {
                self.topViewController()?.present(alert, animated:true, completion:completion)
            }
        }
        return alert
    }
    
    class func showAlertControllerWithoutActionWithTitle(title:String?, message:String?, completion: (()->Void)?) -> UIAlertController {
        let alert = FPUtility.createAlertController(title: title,
                                                    andMessage:message,
                                                    withPositiveAction:nil,
                                                    andHandler:nil,
                                                    withNegativeAction:nil,
                                                    andHandler:nil)
        self.topViewController()?.present(alert, animated:true, completion:completion)
        return alert
    }
    
    
    
    // MARK: HUD
    
    class func showMessage(_ message:String, forDelay delay:Double) {
        let window = UIApplication.shared.windows.first ?? UIWindow()
        let hud = MBProgressHUD.showAdded(to: window, animated:true)
        hud.label.text = message
        hud.backgroundView.color = UIColor.green
        hud.detailsLabel.text = FPLocalizationHelper.localize("please_wait")
        hud.hide(animated: true, afterDelay:delay)
    }
    
    class func showHUDWithSaveMessage() -> MBProgressHUD {
        let window = UIApplication.shared.windows.first ?? UIWindow()
        let hud = MBProgressHUD.showAdded(to: window, animated:true)
        hud.label.text = FPLocalizationHelper.localize("Saving")
        hud.detailsLabel.text =  FPLocalizationHelper.localize("please_wait")
        hud.removeFromSuperViewOnHide = true
        return hud
    }
    
    class func showHUDWithDeleteMessage() -> MBProgressHUD {
        let window = UIApplication.shared.windows.first ?? UIWindow()
        let hud = MBProgressHUD.showAdded(to: window, animated:true)
        hud.label.text = FPLocalizationHelper.localize("Deleting")
        hud.detailsLabel.text =  FPLocalizationHelper.localize("please_wait")
        hud.removeFromSuperViewOnHide = true
        return hud
    }
    
    class func showHUDWithSyncingMessage() -> MBProgressHUD {
        let window = UIApplication.shared.windows.first ?? UIWindow()
        let hud = MBProgressHUD.showAdded(to: window, animated:true)
        hud.label.text = FPLocalizationHelper.localize("Syncing")
        hud.detailsLabel.text =  FPLocalizationHelper.localize("please_wait")
        hud.removeFromSuperViewOnHide = true
        return hud
    }
    
    class func showHUDWithLoadingMessage() {
        let window = UIApplication.shared.windows.first ?? UIWindow()
        let hud = MBProgressHUD.showAdded(to: window, animated:true)
        hud.label.text = FPLocalizationHelper.localize("Loading")
        hud.detailsLabel.text =  FPLocalizationHelper.localize("please_wait")
        hud.removeFromSuperViewOnHide = true
    }
    
    class func showHUDWithMessage(_ message:String, detailText:String?) -> MBProgressHUD {
        let window = UIApplication.shared.windows.first ?? UIWindow()
        let hud = MBProgressHUD.showAdded(to: window, animated:true)
        hud.label.text = message
        hud.detailsLabel.text = detailText
        hud.removeFromSuperViewOnHide = true
        return hud
    }
    
    
    class func hideHUD() {
        DispatchQueue.main.async {
            for window in UIApplication.shared.windows  {
                MBProgressHUD.hide(for: window, animated:true)
            }
        }
    }
    
    class func imageWithImage(image:UIImage, convertToSize size:CGSize) -> UIImage {
        UIGraphicsBeginImageContext(size)
        image.draw(in: CGRectMake(0, 0, size.width, size.height))
        guard let destImage =  UIGraphicsGetImageFromCurrentImageContext() else { return UIImage() }
        UIGraphicsEndImageContext()
        return destImage
    }
    class func printErrorAndShowAlert(error: Error?){
        DispatchQueue.main.async {
            let strmessage = error?.localizedDescription ?? FPLocalizationHelper.localize("lbl_Something_went_wrong")
            let alertController = UIAlertController(title: nil, message: strmessage, preferredStyle: .alert)
            let isValidHTML = self.isValidHtmlString(strmessage)
            if isValidHTML, let htmlData =  strmessage.data(using: .utf8), let attributedString = try? NSAttributedString(data: htmlData, options: [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil){
                alertController.setValue(attributedString, forKey: "attributedMessage")
            }
            let okAction = UIAlertAction(title: FPLocalizationHelper.localize("OK"), style: .default, handler: {_ in
            })
            alertController.addAction(okAction)
            alertController.applyLegacyActionSheetStyle()
            DispatchQueue.main.async {
                self.topViewController()?.present(alertController, animated:true, completion:nil)
            }
        }
    }
    
    
    class func getJsonFromData(data: Data) -> ([String:Any]?, Error?) {
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String : Any]
            return (json, nil)
        } catch {
            return (nil, error)
        }
    }
    
    class func isValidHtmlString(_ value: String) -> Bool {
        if value.isEmpty {
            return false
        }
        return (value.range(of: "<(\"[^\"]*\"|'[^']*'|[^'\">])*>", options: .regularExpression) != nil)
    }
    
    
    
}



// MARK: - Network FPUtility
extension FPUtility {
    
    class func showNoNetworkAlert() {
        FPUtility.showErrorMessage(nil, withTitle: nil, withWarningMessage:FPLocalizationHelper.localize("No_Network"))
    }
    
    
    static func isConnectedToNetwork() -> Bool{
        do {
            let reachability =  try Reachability()
            let valueInternet = reachability.connection != .unavailable
            return valueInternet
        }catch {}
        return true
    }
    
    static func getPath(_ fileName: String) -> String? {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        if let documentDirectory:URL = urls.first {
            let finalDatabaseURL = documentDirectory.appendingPathComponent(fileName)
            print("Database Path: \(finalDatabaseURL.path)")
            return finalDatabaseURL.path
        } else {
            return nil
        }
    }
    
    static func getPathForSupportDirectory(_ fileName: String) -> String? {
        do {
            let fileManager = FileManager()
            let folderURL = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("database", isDirectory: true)
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
            let dbURL = folderURL.appendingPathComponent(fileName)
            print("Database Path: \(dbURL.path)")
            return dbURL.path
        }catch {
            return nil
        }
    }
    
    static func getDatabasePath(_ fileName: String) -> String? {
        guard let dbPath = self.getPath(fileName) else { return nil }
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: fileName) {
            let bundle = Bundle.main.resourceURL
            guard let file = bundle?.appendingPathComponent(fileName) else { return nil }
            do {
                try fileManager.copyItem(atPath: file.path, toPath: dbPath)
            } catch {
                return nil
            }
        }
        return dbPath
    }
    
    static func getCurrentLanguageidentifier() -> String{
        let selectedLanguage = UserDefaults.standard.value(forKey: "selected-language") as? String ?? Bundle.main.preferredLocalizations.first ?? "en"
        if selectedLanguage == "en"{
            return "en-US"
        }else{
            return "es-MX"
        }
    }
}


extension String {
    
    func processApostrophe() -> String {
        if self.contains("'") {
            return self.replacingOccurrences(of: "'", with: "''")
        }else {
            return self
        }
    }
    
    func handleAndDisplayApostrophe() -> String {
        if self.contains("''") {
            return self.replacingOccurrences(of: "''", with:"'")
            
        }else {
            return self
        }
    }
    
    var trim: String {
        return self.trimmingCharacters(in: NSCharacterSet.whitespaces)
    }
    
    func getDictonary() -> [String:Any] {
        let dictonary = [String:Any]()
        if let data = self.data(using: .utf8) {
            do {
                if let  dictonary =  try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? [String:Any]  {
                    return dictonary
                }
                return dictonary
            } catch {
                return dictonary
            }
        }
        return dictonary
    }
    
    func getArray() -> [[String:Any]] {
        let array = [[String:Any]]()
        if let data = self.data(using: .utf8) {
            do {
                if let  array =  try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? [[String:Any]]  {
                    return array
                }
                return array
            } catch {
                return array
            }
        }
        return array
    }
}


extension Array {
    mutating func removeObject<U: Equatable>(_ object: U) -> Bool {
        for (idx, objectToCompare) in self.enumerated() {
            if let to = objectToCompare as? U {
                if object == to {
                    self.remove(at: idx)
                    return true
                }
            }
        }
        return false
    }
    private func json(shouldPretify: Bool) -> String {
        do {
            var writingOption : JSONSerialization.WritingOptions = shouldPretify ? [.sortedKeys, .prettyPrinted] : .sortedKeys
            if #available(iOS 13.0, *) {
                writingOption.insert(.withoutEscapingSlashes)
            }
            let jsonData = try JSONSerialization.data(withJSONObject: self, options: writingOption)
            let returnString = String(bytes: jsonData, encoding: .utf8) ?? invalidJson
            return returnString
        } catch {
            return invalidJson
        }
    }
    
    func getJson() -> String {
        return json(shouldPretify: false)
    }
    
    func getDatadogJson() -> String {
        let invalidJson = "Not a valid JSON"
        do {
            var writingOption : JSONSerialization.WritingOptions = .sortedKeys
            writingOption.insert(.withoutEscapingSlashes)
            let jsonData = try JSONSerialization.data(withJSONObject: self, options: writingOption)
            let returnString = String(bytes: jsonData, encoding: .utf8) ?? invalidJson
            return returnString
        } catch {
            return invalidJson
        }
    }
    
}

extension Dictionary {
    
    var queryString: String {
        var output: String = ""
        for (key,value) in self {
            output +=  "\(key)=\(value)&"
        }
        output = String(output.dropLast())
        return output
    }
    
    private func json(shouldPretify: Bool) -> String {
        do {
            var writingOption : JSONSerialization.WritingOptions = shouldPretify ? [.sortedKeys, .prettyPrinted] : .sortedKeys
            if #available(iOS 13.0, *) {
                writingOption.insert(.withoutEscapingSlashes)
            }
            let jsonData = try JSONSerialization.data(withJSONObject: self, options: writingOption)
            let returnString = String(bytes: jsonData, encoding: .utf8) ?? invalidJson
            return returnString
        } catch {
            return invalidJson
        }
    }
    func printJson() {
        print(json(shouldPretify: true))
    }
    func getJson() -> String {
        return json(shouldPretify: false)
    }
    subscript(keyPath keyPath: String) -> Any? {
        get {
            guard let keyPath = Dictionary.keyPathKeys(forKeyPath: keyPath)
            else { return nil }
            return getValue(forKeyPath: keyPath)
        }
        set {
            guard let keyPath = Dictionary.keyPathKeys(forKeyPath: keyPath),
                  let newValue = newValue else { return }
            self.setValue(newValue, forKeyPath: keyPath)
        }
    }
    
    static private func keyPathKeys(forKeyPath: String) -> [Key]? {
        let keys = forKeyPath.components(separatedBy: ".")
            .reversed().flatMap({ $0 as? Key })
        return keys.isEmpty ? nil : keys
    }
    
    // recursively (attempt to) access queried subdictionaries
    // (keyPath will never be empty here; the explicit unwrapping is safe)
    private func getValue(forKeyPath keyPath: [Key]) -> Any? {
        guard let value = self[keyPath.last!] else { return nil }
        return keyPath.count == 1 ? value : (value as? [Key: Any])
            .flatMap { $0.getValue(forKeyPath: Array(keyPath.dropLast())) }
    }
    
    // recursively (attempt to) access the queried subdictionaries to
    // finally replace the "inner value", given that the key path is valid
    private mutating func setValue(_ value: Any, forKeyPath keyPath: [Key]) {
        guard self[keyPath.last!] != nil else { return }
        if keyPath.count == 1 {
            (value as? Value).map { self[keyPath.last!] = $0 }
        }
        else if var subDict = self[keyPath.last!] as? [Key: Value] {
            subDict.setValue(value, forKeyPath: Array(keyPath.dropLast()))
            (subDict as? Value).map { self[keyPath.last!] = $0 }
        }
    }
}




// MARK: - Special Chars Handling

var dictSpecialChars = ["”":"__X22__",
                        "%":"__X25__",
                        "'":"__X27__",
                        "(":"__X28__",
                        ")":"__X29__",
                        ",":"__X2C__",
                        ".":"__X2E__",
                        "/":"__X2F__"]

extension FPUtility {
    
    func convertToCompataibleSpecialCharsDBString(strInput:String) -> String{
        var strConverted = strInput
        for (spChar, xvalue) in dictSpecialChars {
            strConverted = strConverted.replacingOccurrences(of: spChar, with: xvalue)
        }
        return strConverted
    }
    
    func fetchCompataibleSpecialCharsStringFromDB(strInput:String) -> String{
        var strConverted = strInput
        for (spChar, xvalue) in dictSpecialChars {
            strConverted = strConverted.replacingOccurrences(of: xvalue, with: spChar)
        }
        return strConverted
    }
    
    func getSQLiteSpecialCharsCompatibleString(value:Any?, isForLocal:Bool) -> String?{
        if value == nil{
            return nil
        }else if let numValue = value as? NSNumber{
            return numValue.stringValue
        }else if let strValue = value as? String{
            if isForLocal{
                return FPUtility().convertToCompataibleSpecialCharsDBString(strInput: strValue)
            }else{
                return FPUtility().fetchCompataibleSpecialCharsStringFromDB(strInput: strValue)
            }
        }else{
            return nil
        }
    }
    
    func handleUnicodeChars(strInput:String) -> String{
        var outputString = ""
        var scanner = Scanner(string: strInput)
        
        while !scanner.isAtEnd {
            if #available(iOS 13.0, *) {
                if scanner.scanString("\\u") != nil, let hexValue = scanner.scanUpToCharacters(from: CharacterSet(charactersIn: "\\;")) {
                    if let unicodeScalar = UnicodeScalar(Int(hexValue, radix: 16) ?? 0) {
                        outputString.append(String(unicodeScalar))
                    }
                } else {
                    var token: NSString?
                    scanner.scanUpToCharacters(from: CharacterSet(charactersIn: "\\") , into: &token)
                    if let token = token as String? {
                        outputString.append(token)
                    }
                }
            } else {
                // Fallback on earlier versions
                outputString = strInput
            }
        }
        return outputString
    }
    
}

extension Collection where Indices.Iterator.Element == Index {
    subscript (safe index: Index) -> Iterator.Element? {
        return indices.contains(index) ? self[index] : nil
    }
}


extension Date {
    
    func convertUTCToLocalInString(with format: String = "MMM dd, yyyy hh:mm a") -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone.current
        dateFormatter.dateFormat = format
        return dateFormatter.string(from: self)
    }
    
    var millisecondsSince1970: Int64 {
        Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }
    
    init(milliseconds: Int64) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
    
    func adding(years: Int) -> Date {
        return Calendar.current.date(byAdding: .year, value: years, to: self)!
    }
}


extension UITextField {
    
    private struct Holder {
        static var _myComputedProperty = [String:Bool]()
        static var _cutComputedProperty = [String:Bool]()
    }
    
    private var doesPastingAllowed: Bool {
        get {
            return Holder._myComputedProperty[Unmanaged<AnyObject>.passUnretained(self as AnyObject).toOpaque().debugDescription] ?? true
        }
        set(newValue) {
            Holder._myComputedProperty[Unmanaged<AnyObject>.passUnretained(self as AnyObject).toOpaque().debugDescription] = newValue
        }
    }
    private var doesCutAllowed: Bool {
        get {
            return Holder._cutComputedProperty[Unmanaged<AnyObject>.passUnretained(self as AnyObject).toOpaque().debugDescription] ?? true
        }
        set(newValue) {
            Holder._cutComputedProperty[Unmanaged<AnyObject>.passUnretained(self as AnyObject).toOpaque().debugDescription] = newValue
        }
    }
    
    override open func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        
        // Always ask UIKit first
        let allowedBySystem = super.canPerformAction(action, withSender: sender)
        
        // Control paste
        if action == #selector(paste(_:)) {
            return doesPastingAllowed && allowedBySystem
        }
        
        // Control cut
        if action == #selector(cut(_:)) {
            return doesCutAllowed && allowedBySystem
        }
        
        // IMPORTANT: allow all other system actions
        return allowedBySystem
    }
    
    func disablePaste() {
        self.doesPastingAllowed = false
    }
    func allowPaste() {
        self.doesPastingAllowed = true
    }
    func disableCut() {
        self.doesCutAllowed = false
    }
    func allowCut() {
        self.doesCutAllowed = true
    }
    func addDropDownView() {
        let rightView = UIView(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
        imageView.image = UIImage(named: "ic_down_arrow_black")
        rightView.addSubview(imageView)
        self.rightView = rightView
        self.rightViewMode = .always
        self.tintColor = UIColor.clear
    }
    
    func clearDropdownView() {
        self.rightView = nil
        self.rightViewMode = .never
    }
    
    func addCalendarIconRightView() {
        let rightView = UIView(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
        imageView.image = UIImage(systemName: "calendar")
        imageView.tintColor = .black
        imageView.center.y  =  rightView.frame.size.height / 2.0
        rightView.addSubview(imageView)
        self.rightView = rightView
        self.rightViewMode = .always
    }
    
}


extension UITextView {
    
    private struct Holder {
        static var _myComputedProperty = [String:Bool]()
        static var _cutComputedProperty = [String:Bool]()
        
    }
    
    private var doesPastingAllowed: Bool {
        get {
            return Holder._myComputedProperty[Unmanaged<AnyObject>.passUnretained(self as AnyObject).toOpaque().debugDescription] ?? true
        }
        set(newValue) {
            Holder._myComputedProperty[Unmanaged<AnyObject>.passUnretained(self as AnyObject).toOpaque().debugDescription] = newValue
        }
    }
    
    private var doesCutAllowed: Bool {
        get {
            return Holder._cutComputedProperty[Unmanaged<AnyObject>.passUnretained(self as AnyObject).toOpaque().debugDescription] ?? true
        }
        set(newValue) {
            Holder._cutComputedProperty[Unmanaged<AnyObject>.passUnretained(self as AnyObject).toOpaque().debugDescription] = newValue
        }
    }
    
    override open func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {

        // Ask UIKit first
        let allowedBySystem = super.canPerformAction(action, withSender: sender)

        // Control paste
        if action == #selector(paste(_:)) {
            return doesPastingAllowed && allowedBySystem
        }

        // Control cut
        if action == #selector(cut(_:)) {
            return doesCutAllowed && allowedBySystem
        }

        // Allow all other system actions
        return allowedBySystem
    }
    
    @objc func disablePaste() {
        self.doesPastingAllowed = false
    }
    @objc func allowPaste() {
        self.doesPastingAllowed = true
    }
    @objc func disableCut() {
        self.doesCutAllowed = false
    }
    @objc func allowCut() {
        self.doesCutAllowed = true
    }
    @objc func disablePasteAndAutoCorrection() {
        self.doesPastingAllowed = false
        self.autocorrectionType = .no
    }
    func enablePasteAndAutoCorrection() {
        self.doesPastingAllowed = true
        self.autocorrectionType = .default
    }
    @objc func enable() {
        self.isUserInteractionEnabled = true
        self.allowCut()
        self.allowPaste()
    }
    @objc func disable() {
        self.isUserInteractionEnabled = false
        self.disableCut()
        self.disablePaste()
    }
    
}


extension UIViewController {
    func presentAsPopoverFP(_ view: UIView, rect:CGRect? = nil, barButton: UIBarButtonItem? = nil, permittedArrowDirections:UIPopoverArrowDirection, preferredContentSize:CGSize, base:UIViewController) {
        self.modalPresentationStyle = .popover
        self.preferredContentSize = preferredContentSize
        if let popover = self.popoverPresentationController  {
            if let barButton = barButton{
                popover.barButtonItem = barButton
            }else{
                popover.sourceView = view
                if let rect  = rect{
                    popover.sourceRect = rect
                }else{
                    popover.sourceRect = view.bounds
                }
            }
            popover.permittedArrowDirections = permittedArrowDirections
            base.present(self, animated: true)
        }
    }
}

extension UserDefaults{
    
    class var dictConstants:[String:Any]?{
        get{
            return self.standard.object(forKey: "FPFormConstants") as? [String:Any]
        }
        set{
            self.standard.set(newValue,forKey: "FPFormConstants")
            self.standard.synchronize()
        }
    }
    
    class var computedFields:[String:Any]?{
        get{
            return self.standard.object(forKey: "COMPUTED_FIELDS") as? [String:Any]
        }
        set{
            guard var value = newValue else {
                self.standard.removeObject(forKey: "COMPUTED_FIELDS")
                self.standard.removeObject(forKey: "COMPUTED_FIELDS_ORDER")
                return
            }
            let existing = self.standard.object(forKey: "COMPUTED_FIELDS") as? [String: Any] ?? [:]
            var order = self.standard.stringArray(forKey: "COMPUTED_FIELDS_ORDER") ?? Array(existing.keys)
            // Move every written key to back (most-recently-used) — LRU eviction
            value.keys.forEach { key in
                order.removeAll { $0 == key }
                order.append(key)
            }
            // Evict oldest-first when over limit
            while value.count > 20, let oldest = order.first {
                value.removeValue(forKey: oldest)
                order.removeFirst()
            }
            self.standard.set(value, forKey: "COMPUTED_FIELDS")
            self.standard.set(order, forKey: "COMPUTED_FIELDS_ORDER")
        }
    }
    
    class var libCurrentLanguage : String {
        get{
            return self.standard.value(forKey: "selected-language") as? String ?? Bundle.main.preferredLocalizations.first ?? "en"
        }
        set{
            self.standard.set(newValue,forKey: "selected-language")
            self.standard.synchronize()
        }
    }
    
    class var currentScannerSectionId : NSNumber? {
        get{
            return self.standard.value(forKey: "currentScannerSectionId") as? NSNumber
        }
        set{
            self.standard.set(newValue,forKey: "currentScannerSectionId")
            self.standard.synchronize()
        }
    }
    
}

extension UIAlertController {

    func applyLegacyActionSheetStyle() {

        view.tintColor = .systemBlue
        
        // MARK: - Title (iOS 16 style)
        if let title = title {
            let attributedTitle = NSAttributedString(
                string: title,
                attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .headline),
                    .foregroundColor: UIColor.label
                ]
            )
            setValue(attributedTitle, forKey: "attributedTitle")
        }
        
        // MARK: - Message (iOS 16 style)
        if let message = message {
            let attributedMessage = NSAttributedString(
                string: message,
                attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .subheadline),
                    .foregroundColor: UIColor.secondaryLabel
                ]
            )
            setValue(attributedMessage, forKey: "attributedMessage")
        }
        
        // MARK: - Button Styling (Safer Way)
        actions.forEach { action in
            switch action.style {
            case .destructive:
                // Keep system destructive red
                action.setValue(UIColor.systemRed, forKey: "titleTextColor")
                
            case .cancel:
                // iOS 16 cancel uses tintColor (not gray)
                action.setValue(view.tintColor, forKey: "titleTextColor")
                
            default:
                action.setValue(view.tintColor, forKey: "titleTextColor")
            }
        }
    }
}


extension DispatchQueue {
    
    static func background(delay: Double = 0.0, background: (()->Void)? = nil, completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .background).async {
            background?()
            if let completion = completion {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: {
                    completion()
                })
            }
        }
    }
    
}

extension UIView {
    
    func dropShadow() {
        layer.shadowOpacity = 0.5
        layer.shadowOffset = CGSize(width: 1.0, height: 1.0)
        layer.shadowRadius = 5.0
        layer.shadowColor = UIColor.black.cgColor
        layer.masksToBounds = false
    }
    
    func applyShadow(height:CGFloat = 2.0) {
        layer.shadowOpacity = 0.3
        layer.shadowOffset = CGSize(width: 0, height: height)
        layer.shadowRadius = 4.0
        layer.shadowColor = UIColor.black.cgColor
        layer.masksToBounds = false
    }
}

extension Int {
    
    func isNonNegative() -> Bool {
        return self >= 0
    }
    
    func isInBetween(_ first:Int, _ second: Int) -> Bool {
        return (self >= first && self <= second)
    }
    
    func equalsTo(_ val:Int) -> Bool {
        return (self == val)
    }
    
    func getErrorMessage() -> String {
        switch self {
        case let status where status.isInBetween(100, 199):
            return "We have sent the request to the server"
        case let status where status.isInBetween(200, 299):
            return "Your request got success!!"
        case let status where status.isInBetween(300, 399):
            return "The server is redirected"
        case let status where status.isInBetween(400, 499):
            return "The request could not be understand by the server"
        case let status where status.isInBetween(500, 599):
            return "Server is not responding"
        default:
            return "Something went wrong!"
        }
    }
    
}

extension TimeZone {
    func timeZoneOffsetInMinutes() -> Int {
        let seconds = secondsFromGMT()
        let minutes = seconds / 60
        return -(minutes)
    }
    func offsetFromGMT() -> String
    {
        let localTimeZoneFormatter = DateFormatter()
        localTimeZoneFormatter.locale = Locale(identifier: "en_US_POSIX")
        localTimeZoneFormatter.timeZone = self
        localTimeZoneFormatter.dateFormat = "Z"
        return localTimeZoneFormatter.string(from: Date())
    }
    
}

extension Dictionary where Key == String  {
    func getErrorMessage() -> String? {
        if let code = ((self["exception"] as? [String: Any])?["error"] as? [String: Any])?["code"] as? String {
            if code == "E100" || code == "E101" || code == "E102" {
                return ((self["exception"] as? [String: Any])?["error"] as? [String: Any])?["description"] as? String
            } else {
                return ((self["exception"] as? [String: Any])?["error"] as? [String: Any])?["message"] as? String
            }
        } else {
            return ((self["exception"] as? [String: Any])?["error"] as? [String: Any])?["description"] as? String
        }
    }
    
}

private var datePickerKey: UInt8 = 0
extension UITextField {
    
    var datePicker: UIDatePicker? {
        get {
            objc_getAssociatedObject(self, &datePickerKey) as? UIDatePicker
        }
        set {
            objc_setAssociatedObject(self, &datePickerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    func addInputViewDatePicker(target: Any, selector: Selector,minimumDate: Date? = nil,currentDate:Date? = Date()) {
        
        let screenWidth = UIScreen.main.bounds.width
        
        //Add DatePicker as inputView
        var datePicker = UIDatePicker(frame: CGRect(x: 0, y: 0, width: screenWidth, height: 216))
        datePicker.datePickerMode = .date
        datePicker.date = currentDate ?? Date()
        if minimumDate == minimumDate{
            datePicker.minimumDate = minimumDate
        }
        if #available(iOS 13.4, *) {
            datePicker.preferredDatePickerStyle = .wheels
        } else {
            // Fallback on earlier versions
        }
        
        self.inputView = datePicker
        self.datePicker = datePicker
        
        //Add Tool Bar as input AccessoryView
        let toolBar = UIToolbar(frame: CGRect(x: 0, y: 0, width: screenWidth, height: 44))
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let cancelBarButton = UIBarButtonItem(title: FPLocalizationHelper.localize("Cancel"), style: .plain, target: self, action: #selector(cancelPressed))
        let doneBarButton = UIBarButtonItem(title: FPLocalizationHelper.localize("Done"), style: .plain, target: target, action: selector)
        toolBar.setItems([cancelBarButton, flexibleSpace, doneBarButton], animated: false)
        
        self.inputAccessoryView = toolBar
    }
    
    /// Helper to get selected date anytime
    func selectedDate() -> Date? {
        return datePicker?.date
    }
    
    /// Helper to update date later
    func updateSelectedDate(_ date: Date, animated: Bool = true) {
        datePicker?.setDate(date, animated: animated)
    }
    
    @objc func cancelPressed() {
        self.resignFirstResponder()
    }
}
