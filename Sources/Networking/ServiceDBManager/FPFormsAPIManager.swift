//
//  FormsAPIManager.swift
//  crm
//
//  Created by SmartServ-Shristi on 6/29/20.
//  Copyright © 2020 SmartServ. All rights reserved.
//

import Foundation
internal import DatadogCore
internal import DatadogLogs
enum FPFormsApiName {
    case getCustomFormsForTicket(_ params: [String: Any])
    case addCustomForm(_ params: [String: Any])
    case updateCustomForm(_ params: [String: Any])
    case updateCustomFormSection(_ params: [String: Any])
    case getPreviousFPForms(_ params: [String: Any])
    case getFPFormDetails(_ params: [String: Any])
    case getComputedFields(_ params: [String: Any])
    case getFPFormConstants(_ params: [String: Any])
    case deleteCustomForms(_ params: [String: Any])
    case downloadCustomForm(_ params: [String: Any])
    case requestDownloadCustomForm(_ formId: String, params: [String: Any])
    case fetchDownloadStatus(params: [String: Any])
    case getCommonTemplates(_ params : [String: Any])
    case getFPFormTemplates
    case preCompileFPForm(_ formId: String, params: [String: Any])
    case addSignaturesToFPForm(_ formId: String, params: [String: Any])
    case getRecommendationSuggestions(_ params: [String: Any])
    case getChecklistAndSummary(_ params: [String: Any])
    case getInspectionForms(_ params: [String: Any])
    case queryInspectionForms(_ params: [String: Any])
}

extension FPFormsApiName: FPEndPointType {
    var baseURL: URL {
        switch self {
        case .getChecklistAndSummary,.getRecommendationSuggestions:
            return URL(string: aibaseUrlString)!
        default:
            return URL(string:baseUrlString)!
        }
    }
    
    var path: String {
        switch self {
        case .getCustomFormsForTicket:
            return "common/fp/form/ticket"
        case .addCustomForm:
            return "common/fp/form/create"
        case .updateCustomForm:
            return "common/fp/form/update"
        case .updateCustomFormSection:
            return "common/fp/form/section/update"
        case .getFPFormDetails:
            return "common/fp/form/getById"
        case .getComputedFields:
            return "common/fp/form/computedFields"
        case .getFPFormConstants:
            return "common/fp/forms/constants"
        case .getPreviousFPForms:
            return "common/fp/form/serviceaddress"
        case .deleteCustomForms:
            return "common/fp/form/ticket/deleteBulk"
        case .downloadCustomForm:
            return "common/fp/form/download"
        case .requestDownloadCustomForm(let formId, _):
            return "common/fp/form/\(formId)/download-request"
        case .fetchDownloadStatus:
            return "common/fp/form/downloads/recent/status"
        case .getCommonTemplates:
            return "common/templates"
        case .getFPFormTemplates:
            return "common/fp/formtemplatecf/list"
        case .preCompileFPForm(let formId, _):
            return "common/fp/form/\(formId)/precompile"
        case .addSignaturesToFPForm(let formId, _):
            return "common/fp/form/\(formId)/signature"
        case .getRecommendationSuggestions:
            return "ml/agent/citationRecommendations"
        case .getChecklistAndSummary:
            return "ml/deficiencyHelper"
        case .getInspectionForms:
            return "common/fp/form/list/v2"
        case .queryInspectionForms:
            return "common/fp/form/bulk"
        }
    }

    var httpMethod: FPHTTPMethod {
        switch self {
        case .getComputedFields, .getFPFormConstants, .getCustomFormsForTicket,.getPreviousFPForms, .downloadCustomForm, .getFPFormTemplates, .fetchDownloadStatus:
            return .get
        case .addCustomForm, .updateCustomForm, .updateCustomFormSection, .getFPFormDetails, .getCommonTemplates,
            .preCompileFPForm, .addSignaturesToFPForm,.requestDownloadCustomForm,  .getRecommendationSuggestions,.getChecklistAndSummary,
            .getInspectionForms, .queryInspectionForms:
            return .post
        case .deleteCustomForms:
            return .put
        }
    }
    
    var task: FPHTTPTask {
        switch self {
        case .getCustomFormsForTicket(let params):
            return .requestParametersAndHeaders(parameters: params, bodyEncoding: .jsonEncoding, additionHeaders: self.headers)
        case .addCustomForm(let params):
            return .requestParametersAndHeaders(parameters: params, bodyEncoding: .jsonEncoding, additionHeaders: self.headers)
        case .updateCustomForm(let params):
            return .requestParametersAndHeaders(parameters: params, bodyEncoding: .jsonEncoding, additionHeaders: self.headers)
        case .updateCustomFormSection(let params):
            return .requestParametersAndHeaders(parameters: params, bodyEncoding: .jsonEncoding, additionHeaders: self.headers)
        case .getFPFormDetails(let params):
            return .requestParametersAndHeaders(parameters: params, bodyEncoding: .jsonEncoding, additionHeaders: self.headers)
        case .getPreviousFPForms(let params):
            return .requestParametersAndHeaders(parameters: params, bodyEncoding: .jsonEncoding, additionHeaders: self.headers)
        case .getComputedFields(let params):
            return .requestParametersAndHeaders(parameters: params, bodyEncoding: .jsonEncoding, additionHeaders: self.headers)
        case .getFPFormConstants(let params):
            return .requestParametersAndHeaders(parameters: params, bodyEncoding: .jsonEncoding, additionHeaders: self.headers)
        case .downloadCustomForm(let params):
            return .requestParametersAndHeaders(parameters: params, bodyEncoding: .jsonEncoding, additionHeaders: self.headers)
        case .deleteCustomForms(let params):
            return .requestParametersAndHeaders(parameters: params, bodyEncoding: .jsonEncoding, additionHeaders: self.headers)
        case .getCommonTemplates(let params):
            return .requestParametersAndHeaders(parameters: params, bodyEncoding: .jsonEncoding, additionHeaders: self.headers)
        case .getFPFormTemplates:
            return .requestParametersAndHeaders(parameters: nil, bodyEncoding: .jsonEncoding, additionHeaders: self.headers)
        case .preCompileFPForm(_, let params):
            return .requestParametersAndHeaders(parameters: params, bodyEncoding: .jsonEncoding, additionHeaders: self.headers)
        case .addSignaturesToFPForm(_, let params):
            return .requestParametersAndHeaders(parameters: params, bodyEncoding: .jsonEncoding, additionHeaders: self.headers)
        case .requestDownloadCustomForm(_, let params):
            return .requestParametersAndHeaders(parameters: params, bodyEncoding: .jsonEncoding, additionHeaders: self.headers)
        case .fetchDownloadStatus(let params):
            return .requestParametersAndHeaders(parameters: params, bodyEncoding: .jsonEncoding, additionHeaders: self.headers)
        case .getRecommendationSuggestions(let params):
            return .requestParametersAndHeaders(parameters: params, bodyEncoding: .jsonEncoding, additionHeaders: self.headers)
        case .getChecklistAndSummary(let params):
            return .requestParametersAndHeaders(parameters: params, bodyEncoding: .jsonEncoding, additionHeaders: self.headers)
        case .getInspectionForms(let params), .queryInspectionForms(let params):
            return .requestParametersAndHeaders(parameters: params, bodyEncoding: .jsonEncoding, additionHeaders: self.headers)
        }
    }
    
    var headers: FPHTTPHeaders? {
        var headers = FPHTTPHeaders()
        headers["request-from"] = "iOS"
        headers["accept-language"] = UserDefaults.libCurrentLanguage == "es" ? "es-MX" :  UserDefaults.libCurrentLanguage
        headers["user-id"] = strUserId
        headers["company-id"] = strCompanyId
        headers["access-token"] = strAccessToken
        headers["refresh-token"] = strRefreshToken
        return headers
    }
    var fpLoggerModal: FPLoggerModal? {
        let ddLogerModal = FPLoggerModal()
        ddLogerModal.loggerName = FPLoggerNames.customForms
        switch self {
        case .queryInspectionForms, .getFPFormTemplates:
            // common/fp/form/bulk and common/fp/formtemplatecf/list return full form definitions
            // (several MB); never log the whole body.
            ddLogerModal.summarizesSuccessBody = true
            ddLogerModal.errorBodyMaxBytes = 16_000
        default:
            break
        }
//        ddLogerModal.maskers = [FPMasker.init(primaryKey: "templateObjects", secondaryKey: "file.data"), FPMasker.init(primaryKey: "file", secondaryKey: "data")]
        return ddLogerModal
    }
    
}









