//
//  CompatibilityAccessManager.swift
//
//  Copyright © 2020 Cody Kerns. All rights reserved.
//

import Foundation
import Purchases

public class CompatibilityAccessManager {
    public static let shared = CompatibilityAccessManager()

    private init() { }
    
    public struct BackwardsCompatibilityEntitlement: Equatable {
        var entitlement: String
        var versions: [String]
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.entitlement == rhs.entitlement
        }
    }
        
    private var registeredVersions: [BackwardsCompatibilityEntitlement] = []
    
    public func isActive(entitlement: String, result: @escaping ((Bool) -> Void)) {
        
        self.log("Checking access to entitlement '\(entitlement)'")
        
        Purchases.shared.purchaserInfo { (info, error) in
            if let info = info {
                /// If a user has access to an entitlement, return true
                if info.entitlements[entitlement]?.isActive == true {
                    self.log("Entitlement '\(entitlement)' active in RevenueCat.")
                    return result(true)
                } else {
                    /// If a user doesn't have access to an entitlement via RevenueCat, check original downloaded version and compare to registered backwards compatibility versions
                    if self.registeredVersions.count != 0,
                        let originalVersion = info.originalApplicationVersion {
                        
                        for version in self.registeredVersions {
                            if version.entitlement == entitlement, version.versions.contains(originalVersion) {
                                
                                self.log("Version \(originalVersion) found in registered backwards compatibility version for entitlement '\(entitlement)'.")
                                return result(true)
                            }
                        }
                    }
                    
                    /// No registered backwards compatibility versions, or no available originalApplicationVersion to check against
                    self.log("Entitlement \(entitlement) not active.")
                    return result(false)
                }
                
            } else {
                /// PurchaserInfo not available, so not able to check against originalApplicationVersion
                self.log("PurchaserInfo not available, entitlement \(entitlement) not active.")
                return result(false)
            }
        }
    }
}

/// Version and entitlement registration
extension CompatibilityAccessManager {
    public func register(entitlement: BackwardsCompatibilityEntitlement) {
        if !registeredVersions.contains(version) {
            registeredVersions.append(version)
            self.log("Registered entitlement '\(version.entitlement)' for versions \(version.versions.joined(separator: ", ")).")
        } else {
            self.log("Entitlement '\(version.entitlement)' already registered.")
        }
    }
    
    public func unregister(entitlement: String) {
        registeredVersions.removeAll(where: { $0.entitlement == entitlement })
        self.log("Unregistered entitlement '\(entitlement)'.")
    }
}

/// Logging
extension CompatibilityAccessManager {
    fileprivate func log(_ message: String) {
        print("[CompatibilityAccessManager] \(message)")
    }
}
