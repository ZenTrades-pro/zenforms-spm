//
//  NetworkService.swift
//  crm
//
//  Created by Soumya on 29/11/19.
//  Copyright © 2019 SmartServ. All rights reserved.
//

import Foundation
internal import Alamofire

typealias FPNetworkRouterCompletion = (_ json: [String: Any]?, _ data: Data?, _ response: URLResponse?, _ error: Error?) -> Void
typealias FPNetworkCompletion<T:Codable> = (_ json: DataResponse<Any,AFError>?, _ error: Error?) -> Void
typealias FPDownloadRouterCompletion = (_ url: URL?, _ error: Error?) -> Void

protocol FPNetworkRouter: AnyObject {
    associatedtype EndPoint: FPEndPointType
    func request(_ route: EndPoint, completion: @escaping FPNetworkRouterCompletion)
    func download(_ route: EndPoint, completion: @escaping FPDownloadRouterCompletion)
    func cancel()
}

enum CERT_PATH {
    case STAGING
    case UAT
    case PROD
    case NOTIF_PROD
    case NOTIF_STAGE
    case NOTIF_UAT
}

// EndPoint is a container which contains properties of URL.
class FPRouter<EndPoint: FPEndPointType>: FPNetworkRouter {
    private var task: URLSessionTask?
    
    func request(_ route: EndPoint, completion: @escaping FPNetworkRouterCompletion) {
        do {
            var request = try self.buildRequest(from: route)
            if !FPUtility.isConnectedToNetwork() {
                let myError = FPErrorHandler.getError(code: -1009, message: "The Internet connection appears to be offline.")
                completion(nil, nil, nil, myError)
                return
            }
            
            print("CURL----------------------------------------------------------\n\n\(request.cURL())\n---------------------------------------------------------\n\n")
            let context = AlamofireFPRequestContext()
            request.addFPTraceId(context.traceId)
            let apiMethod = request.httpMethod ?? "?"
            let apiPath = request.url?.path ?? "?"
            FPSSSessionManager.shared.session?.request(request).responseData(queue: .global(qos: .userInitiated)) { (responseData) in
                DispatchQueue.background {
                    var objMettics: APIFPTransactionMetrics?
                    if let obj = FPTempStore.shared.getAPITransactionMetrics(context.traceId){
                        objMettics = obj
                    }
                    FPNetworkLogger.sendResponseLogToDatadog(route: route, urlRequest: request, context: context, metrics: objMettics, responseData: responseData)
                } completion: {}
                let statusCode = responseData.response?.statusCode ?? (responseData.error == nil ? 200 : 0)
                let durationMs = context.durationMs()
                let startTime = context.startTime
                let errorDesc: String? = {
                    if let err = responseData.error { return err.localizedDescription }
                    if let code = responseData.response?.statusCode, !(200...299).contains(code) {
                        return "HTTP \(code)"
                    }
                    return nil
                }()
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.1) {
                    let metrics = FPTempStore.shared.getAPITransactionMetrics(context.traceId)
                    var info: [String: Any] = [
                        "endpoint": apiPath,
                        "method": apiMethod,
                        "statusCode": statusCode,
                        "durationMs": durationMs,
                        "timestamp": startTime
                    ]
                    if let desc = errorDesc { info["errorDescription"] = desc }
                    if let m = metrics {
                        if let v = m.dnsMs      { info["dnsMs"] = v }
                        if let v = m.tcpMs      { info["tcpMs"] = v }
                        if let v = m.tlsMs      { info["tlsMs"] = v }
                        if let v = m.requestMs  { info["requestMs"] = v }
                        if let v = m.responseMs { info["responseMs"] = v }
                        if let v = m.totalMs    { info["responseNetworkMs"] = v }
                        if let v = m.networkProtocol { info["protocol"] = v }
                    }
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ZTAPIPerformanceRecord"),
                        object: nil,
                        userInfo: info
                    )
                }
                if let error = responseData.error as NSError? {
                    completion(nil, nil, nil, error)
                    return
                }
                guard let data = responseData.data else {
                    DispatchQueue.main.async { FPUtility.hideHUD() }
                    completion(nil, nil, responseData.response, nil)
                    return
                }
                var json: [String:Any]?
                var error: Error?
                if let httpResponse = responseData.response, !httpResponse.statusCode.isInBetween(200, 299) {
                    var message = String()
                    if httpResponse.statusCode.equalsTo(401) {
                    } else {
                        (json, error) = FPUtility.getJsonFromData(data: data)
                        message = json?.getErrorMessage() ?? httpResponse.statusCode.getErrorMessage()
                        let myError = FPErrorHandler.getError(code: httpResponse.statusCode, message: message)
                        completion(nil, nil, nil, myError)
                    }
                    return
                }
                (json, error) = FPUtility.getJsonFromData(data: data)
                completion(json, nil, nil, error)
            }
        } catch {
            FPUtility.hideHUD()
            completion(nil, nil, nil, error)
        }
    }
    
    func download(_ route: EndPoint, completion: @escaping FPDownloadRouterCompletion) {
        do {
            let request = try self.buildRequest(from: route)
            FPSSSessionManager.shared.session?.download(request).responseData(completionHandler: { responseData in
                if let error = responseData.error as NSError? {
                    completion(nil, error)
                    return
                }
                let url = responseData.fileURL
                completion(url, nil)
            })
        } catch {
            FPUtility.hideHUD()
            completion(nil, error)
        }
    }
    
    func getJsonFromData(data: Data) -> ([String:Any]?, Error?) {
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String : Any]
           return (json, nil)
        } catch {
            return (nil, error)
        }
    }
    func cancel() {
        FPSSSessionManager.shared.session?.session.invalidateAndCancel()
    }
    
    fileprivate func buildRequest(from route: EndPoint) throws -> URLRequest {
        // Determine timeout based on endpoint type and payload size
        // Extended timeout (180s) for form create/update operations with large payloads (> 500KB)
        // Standard timeout (120s) for all other operations
        var timeoutInterval: TimeInterval = 120.0  // 2 minutes for non-form operations

        // Check if this is a form sync endpoint that needs extended timeout
        if let formsRoute = route as? FPFormsApiName {
            switch formsRoute {
            case .addCustomForm(let params), .updateCustomForm(let params), .updateCustomFormSection(let params):
                if hasLargePayload(params: params) {
                    timeoutInterval = 180.0  // 3 minutes for very large form data
                } else {
                    timeoutInterval = 120.0  // 2 minutes for standard form sync
                }
            default:
                timeoutInterval = 120.0  // 2 minutes for other operations
            }
        }
        
        var request = URLRequest(url: route.baseURL.appendingPathComponent(route.path),
                                 cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                                 timeoutInterval: timeoutInterval)
        request.httpMethod = route.httpMethod.name()
        do {
            switch route.task {
            case .request:
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            case .requestParameters(let bodyParameters,
                                    let bodyEncoding):
                try self.configureParameters(parameters: bodyParameters,
                                             bodyEncoding: bodyEncoding,
                                             requestType: route.httpMethod,
                                             request: &request)
            case .requestParametersAndHeaders(let bodyParameters,
                                              let bodyEncoding,
                                              let additionalHeaders):
                self.addAdditionalHeaders(additionalHeaders, request: &request)
                try self.configureParameters(parameters: bodyParameters,
                                             bodyEncoding: bodyEncoding,
                                             requestType: route.httpMethod,
                                             request: &request)
            }
            return request
        } catch {
            throw error
        }
    }
    
    private func hasLargePayload(params: [String: Any]) -> Bool {
        // Check if total serialized size exceeds 500KB
        if let data = try? JSONSerialization.data(withJSONObject: params, options: []), data.count > 500_000 {
            return true
        }
        return false
    }
    
    fileprivate func configureParameters(parameters: FPParameters?,
                                         bodyEncoding: FPParameterEncoding,
                                         requestType: FPHTTPMethod,
                                         request: inout URLRequest) throws {
        do {
            try bodyEncoding.encode(urlRequest: &request, parameters: parameters, requestType: requestType)
        } catch {
            throw error
        }
    }
    
    fileprivate func addAdditionalHeaders(_ additionalHeaders: FPHTTPHeaders?, request: inout URLRequest) {
        guard let headers = additionalHeaders else { return }
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }
    
}
extension Double {
    func roundedFP(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

final class FPNetworkMetricsMonitor: EventMonitor {
    let queue = DispatchQueue(label: "com.zentrades.lib.network.metrics")

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        guard let t = metrics.transactionMetrics.first else { return }
        func ms(_ start: Date?, _ end: Date?) -> Double? {
            guard let s = start, let e = end else { return nil }
//            return (e.timeIntervalSince(s) * 1000)
            let doublVal = (e.timeIntervalSince(s) * 1000)
            let intVal = Int(exactly: doublVal.rounded(.up))
            return doublVal.roundedFP(to: 2)
        }
        let dnsMs = ms(t.domainLookupStartDate, t.domainLookupEndDate)
        let tcpMs = ms(t.connectStartDate, t.connectEndDate)
        let tlsMs = ms(t.secureConnectionStartDate, t.secureConnectionEndDate)
        let requestMs = ms(t.requestStartDate, t.requestEndDate)
        let responseMs = ms(t.responseStartDate, t.responseEndDate)
        let xtotalMs = metrics.taskInterval.duration * 1000
        let totalMs = ms(t.fetchStartDate, t.responseEndDate)
        if let _ = task.response as? HTTPURLResponse {
            if let traceId = task.currentRequest?.headers["x-trace-id"] as? String, !traceId.isEmpty{
                let objMettics = APIFPTransactionMetrics(
                    dnsMs: dnsMs,
                    tcpMs: tcpMs,
                    tlsMs: tlsMs,
                    responseMs: responseMs,
                    requestMs: requestMs,
                    totalMs: totalMs,
                    networkProtocol: t.networkProtocolName)
                FPTempStore.shared.set(objMettics, for: traceId)
            }
        }
    }
}

struct APIFPTransactionMetrics{
    let dnsMs:Double?
    let tcpMs:Double?
    let tlsMs:Double?
    let responseMs:Double?
    let requestMs:Double?
    let totalMs:Double?
    let networkProtocol:String?
}

 final class FPSSSessionManager:NSObject{
    static let shared = FPSSSessionManager()
    public var session:Session?

    private override init(){
        super.init()
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true
        let monitor = FPNetworkMetricsMonitor()
        session = Session(configuration: configuration,interceptor: RequestInterceptor(), eventMonitors: [monitor])
        
    }
}

final class RequestInterceptor: Alamofire.RequestInterceptor {
      var retryLimit = 2
     var isRetrying = false
      let retryErrors = [NSURLErrorTimedOut,NSURLErrorCannotFindHost,NSURLErrorCannotParseResponse,NSURLErrorCannotConnectToHost,NSURLErrorCancelled]
    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var urlRequest = urlRequest
        /* MARK: Keeping commented for future use (centralised header for all).*/
        urlRequest.setValue(TimeZone.current.identifier, forHTTPHeaderField: "timezonename")
        urlRequest.setValue(String(TimeZone.current.timeZoneOffsetInMinutes()), forHTTPHeaderField: "timezone-offset")

        completion(.success(urlRequest))
    }
    
    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        if let urlError = error.asAFError?.underlyingError as? URLError{
            if shouldRetry(request, urlError) {
                debugPrint("retrying>>>")
                completion(.retry)
            } else {
                completion(.doNotRetry)
            }
        }else{
            completion(.doNotRetry)
        }
    }
    
    fileprivate func shouldRetry(_ request: Request, _ urlError: URLError) -> Bool {
        return request.retryCount < self.retryLimit && retryErrors.contains(urlError.errorCode)
    }

    
}


extension URLRequest {
    public func cURL(pretty: Bool = true) -> String {
        let newLine = pretty ? "\\\n" : ""
        let method = (pretty ? "--request " : "-X ") + "\(self.httpMethod ?? "GET") \(newLine)"
        let url: String = (pretty ? "--url " : "") + "\'\(self.url?.absoluteString ?? "")\' \(newLine)"
        
        var cURL = "curl "
        var header = ""
        var data: String = ""
        
        if let httpHeaders = self.allHTTPHeaderFields, httpHeaders.keys.count > 0 {
            for (key,value) in httpHeaders {
                header += (pretty ? "--header " : "-H ") + "\'\(key): \(value)\' \(newLine)"
            }
        }
        
        if let bodyData = self.httpBody, let bodyString = String(data: bodyData, encoding: .utf8),  !bodyString.isEmpty {
            data = "--data '\(bodyString)'"
        }
        
        cURL += method + url + header + data
        
        return cURL
    }
}
