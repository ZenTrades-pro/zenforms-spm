//
//  NetworkLogger.swift
//  crm
//
//  Created by Soumya on 29/11/19.
//  Copyright © 2019 SmartServ. All rights reserved.
//

import Foundation
internal import Alamofire

enum FPLogServiceName:String {
    case database = "Database"
    case network = "Network"
}

extension URLRequest {
    mutating func addFPTraceId(_ traceId: String) {
        setValue(traceId, forHTTPHeaderField: "x-trace-id")
    }
}

enum FPTraceIdGenerator {
    static func generate() -> String {
        let companyId = UserDefaults.standard.string(forKey: "companyId") ?? "0"
        let userId = UserDefaults.standard.string(forKey: "userId") ?? "0"
        let uuid = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        return "\(companyId)-\(userId)-\(uuid)"
    }
}


struct AlamofireFPRequestContext {
    let traceId: String
    let startTime: Date

    init(traceId: String = FPTraceIdGenerator.generate()) {
        self.traceId = traceId
        self.startTime = Date()
    }

    func durationMs() -> Int {
        Int(Date().timeIntervalSince(startTime) * 1000)
    }
}


/// Masks secret values that APIs return in response bodies (login token, payment gateway key) before they are logged.
/// Works on the already-serialised message, so it adds no extra copy of the parsed JSON.
enum FPLogSecretMasker {
    private static let regex = try? NSRegularExpression(
        pattern: "\"(accessToken|refreshToken|fattmerchantAPIKey)\"\\s*:\\s*\"(?:[^\"\\\\]|\\\\.)*\"")

    static func mask(_ message: String) -> String {
        guard let regex, message.contains("Token\"") || message.contains("APIKey\"") else { return message }
        let range = NSRange(message.startIndex..., in: message)
        return regex.stringByReplacingMatches(in: message, options: [], range: range,
                                              withTemplate: "\"$1\":\"Removed for security\"")
    }
}

class FPNetworkLogger {
    @discardableResult static func log(request: URLRequest) -> [String:Any] {
        let urlAsString = request.url?.absoluteString ?? ""
        let method = request.httpMethod != nil ? "\(request.httpMethod ?? "")" : ""
        var dictionary = [String:Any]()
        dictionary["requestURI"] = "\(method) \(urlAsString)"
        var headers = request.allHTTPHeaderFields
        for key in headers?.keys.filter({ ["access-token", "refresh-token", "authorization"].contains($0.lowercased()) }) ?? [] {
            headers?[key] = "Removed for security"
        }
        dictionary["requestHeader"] = headers
        if let data = request.httpBody {
            var json: [String: Any]?
            do {
                json = try JSONSerialization.jsonObject(with: data, options: []) as? [String : Any]
                dictionary["requestPayload"] = json ?? "nil"
            }catch {
                dictionary["requestPayload"] = String(data: data, encoding: String.Encoding.utf8) ?? "nil"
            }
        }else {
            dictionary["requestPayload"] = "nil"
        }
        return dictionary
    }
    
     static func sendResponseLogToDatadog(route: FPEndPointType, urlRequest:URLRequest? = nil, context:AlamofireFPRequestContext, metrics:APIFPTransactionMetrics?, responseData:DataResponse<Data,AFError>? = nil) {
        print("\n - - - - - - - - - - INCOMING - - - - - - - - - - \n")
        defer { print("\n - - - - - - - - - -  END - - - - - - - - - - \n") }
        var dictionary = [String:Any]()
        if let request = responseData?.request {
            dictionary = self.log(request: request)
        }
        let isSuccessResponse: Bool = {
            guard responseData?.error?.underlyingError == nil else { return false }
            guard let code = responseData?.response?.statusCode else { return true }
            return code.isInBetween(200, 299) || code.equalsTo(401)
        }()
        // Memory-pressure window: skip all body work for successful responses (errors still logged).
        if isSuccessResponse && FPLogGate.isSuppressing && (responseData?.data?.count ?? 0) > FPLogGate.largeResponseBytes {
            FPTempStore.shared.remove(context.traceId)
            return
        }
        let loggerModalForRoute = route.fpLoggerModal
        if let data = responseData?.data {
            if loggerModalForRoute?.summarizesSuccessBody == true && isSuccessResponse {
                // No JSON parse: log byte size plus the first ~1 KB so an app-level error in a 200 is still visible.
                dictionary["responseBody"] = String(decoding: data.prefix(1_000), as: UTF8.self) + "... [summary only]"
                dictionary["responseBytes"] = data.count
            } else if let maxBytes = loggerModalForRoute?.errorBodyMaxBytes, data.count > maxBytes {
                dictionary["responseBody"] = String(decoding: data.prefix(maxBytes), as: UTF8.self) + "... [Truncated]"
                dictionary["responseBytes"] = data.count
            } else {
                var json: [String: Any]?
                do {
                    json = try JSONSerialization.jsonObject(with: data, options: []) as? [String : Any]
                    dictionary["responseBody"] = json ?? "nil"
                }catch {
                    dictionary["responseBody"] = String(data: data, encoding: String.Encoding.utf8) ?? "nil"
                }
            }
        }else {
            dictionary["responseBody"] = "nil"
        }
        #if DEBUG
        var printDictioanryWithoutPayload = dictionary
        printDictioanryWithoutPayload.removeValue(forKey: "requestPayload")
        printDictioanryWithoutPayload.printJson()
        #endif
        if let loggerModal = loggerModalForRoute {
            if !route.path.isEmpty{
                var dictAttributes = [String:Any]()
                dictAttributes = ["requestURI": dictionary["requestURI"] as? String ?? "",
                                  "network.method": route.httpMethod.name(),
                                  "network.status_code": responseData?.response?.statusCode ?? 0,
                                  "duration_ms": context.durationMs(),
                                  "trace_id": context.traceId,
                                  "endpoint": route.path]
                if let metrics = metrics{
                    dictAttributes["transaction.dns_lookup_ms"] = metrics.dnsMs
                    dictAttributes["transaction.tcp_connect_ms"] = metrics.tcpMs
                    dictAttributes["transaction.tls_handshake_ms"] = metrics.tlsMs
                    dictAttributes["transaction.request_time_ms"] = metrics.requestMs
                    dictAttributes["transaction.response_time_ms"] = metrics.responseMs
                    dictAttributes["transaction.network_time_ms"] = metrics.totalMs
                    dictAttributes["transaction.network_protocol"] = metrics.networkProtocol
                    FPTempStore.shared.remove(context.traceId)
                }
                loggerModal.attributes = dictAttributes
                debugPrint("logger-attributes-\(dictAttributes)")
            }else{
                loggerModal.attributes = ["requestURI": dictionary["requestURI"] as? String ?? ""]
            }
            loggerModal.message = FPLogSecretMasker.mask([dictionary].getDatadogJson())
            loggerModal.serviceName = FPLogServiceName.network.rawValue
            if let error = responseData?.error?.underlyingError as Error? {
                loggerModal.error = error
                FPDatadogWrapper.shared.sendErrorLog(loggerModal)
                return
            }
            if let httpResponse = responseData?.response, !httpResponse.statusCode.isInBetween(200, 299), !httpResponse.statusCode.equalsTo(401) {
                FPDatadogWrapper.shared.sendErrorLog(loggerModal)
                return
            }
            FPDatadogWrapper.shared.sendDebugLog(loggerModal)
        }
    }
}

final class FPTempStore {

    static let shared = FPTempStore()
    private init() {}

    private var storage: [String: Any] = [:]
    private let queue = DispatchQueue(label: "com.zentrades.lib.tempstore", attributes: .concurrent)

    // Write
    func set(_ value: APIFPTransactionMetrics?, for key: String) {
        queue.async(flags: .barrier) {
            guard let _ = self.storage as? [String:Any] else { return  }
            self.storage[key] = value
        }
    }

    func getAPITransactionMetrics(_ key: String) -> APIFPTransactionMetrics? {
        queue.sync {
            guard let storage = storage as? [String:Any], let value = storage[key] else { return nil }
            if let dict = value as? APIFPTransactionMetrics {
                return dict
            }
            return nil
        }
    }

    // Remove
    func remove(_ key: String) {
        queue.async(flags: .barrier) {
            guard let _ = self.storage as? [String:Any] else { return  }
            self.storage.removeValue(forKey: key)
        }
    }

    // Clear all (useful on logout / memory warning)
    func clear() {
        queue.async(flags: .barrier) {
            guard let _ = self.storage as? [String:Any] else { return  }
            self.storage.removeAll()
        }
    }
}
