//
//  FPErrorHandler.swift
//  crm
//
//  Created by Mayur on 17/01/20.
//  Copyright © 2020 SmartServ. All rights reserved.
//

import Foundation

class FPErrorHandler: NSObject {
    
    class func getError(code: Int = 401, message: String = "Data could not be read because it is not in json format") -> Error {
        let error = NSError(domain:"", code:code, userInfo:[NSLocalizedDescriptionKey: message])
        return error
    }
    /// Keeps the parsed error body so callers can read structured details such as `extras`.
    class func getError(code: Int, message: String, responseJSON: [String: Any]?) -> Error {
        var info: [String: Any] = [NSLocalizedDescriptionKey: message]
        if let responseJSON { info[responseJSONKey] = responseJSON }
        return NSError(domain: "", code: code, userInfo: info)
    }
    static let responseJSONKey = "ZenForms.responseJSON"
    class func localDBError() -> Error {
        let error = NSError(domain:"", code:0, userInfo:[NSLocalizedDescriptionKey: FPLocalizationHelper.localize("lbl_Something_went_wrong")])
        return error
    }
    class func jsonFormatterError() -> Error {
        let error = NSError(domain:"", code:0, userInfo:[NSLocalizedDescriptionKey: FPLocalizationHelper.localize("lbl_Something_went_wrong")])
        return error
    }
}
