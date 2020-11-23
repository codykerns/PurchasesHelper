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
        
        // public structs need public inits
        public init(entitlement: String, versions: [String]) {
            self.entitlement = entitlement
            self.versions = versions
        }
        
        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.entitlement == rhs.entitlement
        }
    }
    
    public var debugLogsEnabled: Bool = true
    
    /**
     Because the sandbox originalApplicationVersion is always '1.0', set this property to test different version numbers.
    */
    public var sandboxVersionOverride: String? = nil
        
    fileprivate var registeredVersions: [BackwardsCompatibilityEntitlement] = []
    
    /**
     Optional configuration call to set entitlement versions as well as restore transactions if a receipt is available. **IMPORTANT**: this method should be called *after* you initialize the Purchases SDK.
     */
    public func configure(entitlements: [BackwardsCompatibilityEntitlement], completion: ((Purchases.PurchaserInfo?) -> Void)? = nil) {
        
        entitlements.forEach { (entitlement) in
            self.register(entitlement: entitlement)
        }
        
        /// If we don't have an originalApplicationVersion in the Purchases SDK, and we have a receipt available, automatically restore transactions to ensure a value for originalApplicationVersion in PurchaserInfo
        
        self.log("Fetching PurchaserInfo.")
        
        Purchases.shared.purchaserInfo { (info, error) in
            if let originalApplicationVersion = info?.originalApplicationVersionFixed {
                self.log("originalApplicationVersion is \(originalApplicationVersion)")

                completion?(info)
            } else {
                self.log("originalApplicationVersion is nil - checking for a receipt..")
                
                if let receiptURL = Bundle.main.appStoreReceiptURL,
                   let _ = try? Data(contentsOf: receiptURL) {
                    self.log("Receipt data found. Syncing with Purchases..")
                    
                    Purchases.shared.syncPurchases { (info, error) in
                        if error == nil {
                            self.log("Receipt synced.")
                        }
                        
                        completion?(info)
                    }
                } else {
                    self.log("No receipt data found.")
                    
                    /// No receipt data - restoreTransactions will need to be called manually as it will likely require a sign-in
                    completion?(nil)
                }
            }
        }
        
    }
    
    public func isActive(entitlement: String, result: @escaping ((Bool, Purchases.PurchaserInfo?) -> Void)) {
        
        self.log("Checking access to entitlement '\(entitlement)'")
        
        Purchases.shared.purchaserInfo { (info, error) in
            if let info = info {
                /// Check entitlement from returned PurchaserInfo
                return result(info.isActive(entitlement: entitlement), info)
            } else {
                
                /// If in sandbox mode and sandbox version is set, use this
                if UIApplication.isSandbox,
                    let sandboxVersion = self.sandboxVersionOverride {
                    
                    let isActive = self.entitlementActiveInCompatibility(entitlement, originalVersion: sandboxVersion)
                    
                    /// PurchaserInfo not available, but using sandbox test version
                    
                    if isActive {
                        self.log("[SANDBOX] PurchaserInfo not available, entitlement \(entitlement) active in sandbox version \(sandboxVersion).")
                    } else {
                        self.log("[SANDBOX] PurchaserInfo not available, entitlement \(entitlement) not active in sandbox version \(sandboxVersion)")
                    }
                    
                    return result(isActive, nil)
                }
                
                /// PurchaserInfo not available, so not able to check against originalApplicationVersion
                self.log("PurchaserInfo not available, entitlement \(entitlement) not active.")
                return result(false, nil)
            }
        }
    }
    
    fileprivate func entitlementActiveInCompatibility(_ entitlement: String, originalVersion: String) -> Bool {
        for version in CompatibilityAccessManager.shared.registeredVersions {
            if version.entitlement == entitlement, version.versions.contains(originalVersion) {
                
                CompatibilityAccessManager.shared.log("Version \(originalVersion) found in registered backwards compatibility version for entitlement '\(entitlement)'.")
                return true
            }
        }
        return false
    }
}

extension Purchases.PurchaserInfo {
    public func isActive(entitlement: String, usesRegisteredCompatibilityVersions: Bool = true) -> Bool {
        /// If a user has access to an entitlement, return true
        if self.entitlements[entitlement]?.isActive == true {
            CompatibilityAccessManager.shared.log("Entitlement '\(entitlement)' active in RevenueCat.")
            return true
        } else {
            
            if usesRegisteredCompatibilityVersions {
                /// If a user doesn't have access to an entitlement via RevenueCat, check original downloaded version and compare to registered backwards compatibility versions
                if CompatibilityAccessManager.shared.registeredVersions.count != 0,
                    let originalVersion = self.originalApplicationVersionFixed {
                    
                    return CompatibilityAccessManager.shared
                        .entitlementActiveInCompatibility(entitlement, originalVersion: originalVersion)
                }
            }
            
            /// No registered backwards compatibility versions, or no available originalApplicationVersion to check against
            CompatibilityAccessManager.shared.log("Entitlement \(entitlement) not active.")
            return false
        }
    }
    
    fileprivate var originalApplicationVersionFixed: String? {
        if UIApplication.isSandbox {
            return CompatibilityAccessManager.shared.sandboxVersionOverride ?? self.originalApplicationVersion
        } else {
            return self.originalApplicationVersion
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

/// UIApplication helpers
extension UIApplication {
    static var isSandbox: Bool {
        Bundle.main.appStoreReceiptURL?.path.contains("sandboxReceipt") == true
    }
}
