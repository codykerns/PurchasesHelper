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
        public var entitlement: String
        public var versions: [String]
        
        public init(entitlement: String, versions: [String]) {
            self.entitlement = entitlement
            self.versions = versions
        }
        
        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.entitlement == rhs.entitlement
        }
    }
    
    public var debugLogsEnabled: Bool = true
        
    fileprivate var registeredVersions: [BackwardsCompatibilityEntitlement] = []
    
    public func isActive(entitlement: String, result: @escaping ((Bool, Purchases.PurchaserInfo?) -> Void)) {
        
        self.log("Checking access to entitlement '\(entitlement)'")
        
        Purchases.shared.purchaserInfo { (info, error) in
            if let info = info {
                /// Check entitlement from returned PurchaserInfo
                return result(info.isActive(entitlement: entitlement), info)
            } else {
                /// PurchaserInfo not available, so not able to check against originalApplicationVersion
                self.log("PurchaserInfo not available, entitlement \(entitlement) not active.")
                return result(false, nil)
            }
        }
    }
}

extension Purchases.PurchaserInfo {
    public func isActive(entitlement: String) -> Bool {
        /// If a user has access to an entitlement, return true
        if self.entitlements[entitlement]?.isActive == true {
            CompatibilityAccessManager.shared.log("Entitlement '\(entitlement)' active in RevenueCat.")
            return true
        } else {
            /// If a user doesn't have access to an entitlement via RevenueCat, check original downloaded version and compare to registered backwards compatibility versions
            if CompatibilityAccessManager.shared.registeredVersions.count != 0,
                let originalVersion = self.originalApplicationVersion {
                
                for version in CompatibilityAccessManager.shared.registeredVersions {
                    if version.entitlement == entitlement, version.versions.contains(originalVersion) {
                        
                        CompatibilityAccessManager.shared.log("Version \(originalVersion) found in registered backwards compatibility version for entitlement '\(entitlement)'.")
                        return true
                    }
                }
            }
            
            /// No registered backwards compatibility versions, or no available originalApplicationVersion to check against
            CompatibilityAccessManager.shared.log("Entitlement \(entitlement) not active.")
            return false
        }
    }
}

/// Version and entitlement registration
extension CompatibilityAccessManager {
    public func register(entitlement: BackwardsCompatibilityEntitlement) {
        if !registeredVersions.contains(entitlement) {
            registeredVersions.append(entitlement)
            self.log("Registered entitlement '\(entitlement.entitlement)' for versions \(entitlement.versions.joined(separator: ", ")).")
        } else {
            self.log("Entitlement '\(entitlement.entitlement)' already registered.")
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
        guard self.debugLogsEnabled else { return }
        
        print("[CompatibilityAccessManager] \(message)")
    }
}
