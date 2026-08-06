//
//  FPDifferentialServiceManager.swift
//  crm
//
//  Created by SmartServ-Pooja on 9/3/21.
//  Copyright © 2021 SmartServ. All rights reserved.
//

import Foundation
@objc class FPDifferentialServiceManager : NSObject {
    
    @objc class func fetchDifferentialMeta(apiName:String, payload: String, completion: @escaping (([FPDifferentialMeta])->())) {
        DispatchQueue.global(qos: .utility).async {
            
            FPDifferentialMetaDatabaseManager().fetchFromDB(apiName: apiName, payload: payload) { results in
                completion(results)
            }
        }
    }
    @objc class func fetchDifferentialMeta(apiName:String, completion: @escaping (([FPDifferentialMeta])->())) {
        DispatchQueue.global(qos: .utility).async {
            FPDifferentialMetaDatabaseManager().fetchFromDB(apiName: apiName) { results in
                completion(results)
            }
        }
    }
    @objc class func updateDifferentialMeta(differentialMeta: FPDifferentialMeta, completion: @escaping ((Bool)->())) {
        DispatchQueue.global(qos: .utility).async {
            
            FPDifferentialMetaDatabaseManager().updateIntoDB(differentialMeta: differentialMeta) { success in
                completion(success)
            }
        }
        
    }
    @objc class func setDifferentialMetaIsFetchingFalse() {
        DispatchQueue.global(qos: .utility).async {
            FPDifferentialMetaDatabaseManager().setIsFetchingFalseForAll()
        }
        
    }
    @objc class func insertDifferentialMeta(differentialMeta: FPDifferentialMeta, completion: @escaping ((Bool)->())) {
        DispatchQueue.global(qos: .utility).async {
            FPDifferentialMetaDatabaseManager().insertIntoDB(differentialMeta: differentialMeta) { success in
                completion(success)
            }
        }
    }
    
    @objc class func upsertDifferentialMeta(differentialMeta: FPDifferentialMeta, shouldChangeUpdatedAt: Bool, completion: @escaping ((Bool, String)->())){
        DispatchQueue.global(qos: .utility).async {
            FPDifferentialMetaDatabaseManager().upsertDifferetialMeta(differentialMeta: differentialMeta, shouldChangeUpdatedAt: shouldChangeUpdatedAt) { success, updatedAt in
                completion(success, updatedAt)
            }
        }
    }
    
}
