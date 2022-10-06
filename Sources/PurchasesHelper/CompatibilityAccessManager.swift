//
//  CompatibilityAccessManager.swift
//
//  Copyright © 2020 Cody Kerns. All rights reserved.
//

import Foundation
import RevenueCat

public class CompatibilityAccessManager {
    public static let shared = CompatibilityAccessManager()

    private init() { }

    public struct BackwardsCompatibilityEntitlement: Equatable {
        public var entitlement: String
        public var compatibleVersions: [String]
        public var purchasedBefore: Date?

        // public structs need public inits
        public init(entitlement: String, compatibleVersions: [String], orPurchasedBeforeDate: Date? = nil) {
            self.entitlement = entitlement
            self.compatibleVersions = compatibleVersions
            self.purchasedBefore = orPurchasedBeforeDate
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.entitlement == rhs.entitlement
        }
    }

    public var debugLogsEnabled: Bool = true

    /**
     Because the sandbox `originalApplicationVersion` is always '1.0', set this property to test different version numbers.
    */
    public var sandboxVersionOverride: String? = nil

    /**
     Set this property to test different original purchase dates when providing a 'Purchased Before' date in backwards compatibility entitlements..
     */
    public var sandboxOriginalPurchaseDateOverride: Date? = nil

    fileprivate var registeredVersions: [BackwardsCompatibilityEntitlement] = []

    /**
     Optional configuration call to set entitlement versions as well as restore transactions if a receipt is available. **IMPORTANT**: this method should be called *after* you initialize the Purchases SDK.
     */
    public func syncReceiptIfNeededAndRegister(entitlements: [BackwardsCompatibilityEntitlement], completion: ((CustomerInfo?) -> Void)? = nil) {

        entitlements.forEach { (entitlement) in
            self.register(entitlement: entitlement)
        }

        /// If we don't have an originalApplicationVersion in the Purchases SDK, and we have a receipt available, automatically restore transactions to ensure a value for originalApplicationVersion in CustomerInfo

        self.log("Fetching CustomerInfo.")

        Purchases.shared.getCustomerInfo(fetchPolicy: .fetchCurrent) { (info, error) in
            if let originalApplicationVersion = info?.originalApplicationVersionFixed {
                self.log("Receipt already synced, originalApplicationVersion is \(originalApplicationVersion)")

                completion?(info)
            } else if let originalPurchaseDate = info?.originalPurchaseDateFixed {
                self.log("Receipt already synced, originalPurchaseDate is \(originalPurchaseDate)")

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
                    self.log("No receipt data found. Call restoreTransactions manually to sign in an fetch the latest receipt. The user's CustomerInfo may not include originalApplicationVersion or originalPurchaseDate until then.")

                    /// No receipt data - restoreTransactions will need to be called manually as it will likely require a sign-in
                    completion?(info)
                }
            }
        }

    }

    public func entitlementIsActiveWithCompatibility(entitlement: String, result: @escaping ((Bool, CustomerInfo?) -> Void)) {

        self.log("Checking access to entitlement '\(entitlement)'")

        Purchases.shared.getCustomerInfo { (info, error) in
            if let info = info {
                /// Check entitlement from returned CustomerInfo
                return result(info.entitlementIsActiveWithCompatibility(entitlement: entitlement), info)
            } else {
                #if os(macOS)
                let isSandbox = NSApplication.isSandbox
                #else
                let isSandbox = UIApplication.isSandbox
                #endif
                /// If in sandbox mode and sandbox version is set, use this

                if isSandbox,
                    let sandboxVersion = self.sandboxVersionOverride {

                    let isActive = self.entitlementActiveInCompatibilityVersions(entitlement, originalVersion: sandboxVersion)

                    /// CustomerInfo not available, but using sandbox test version

                    if isActive {
                        self.log("[SANDBOX] CustomerInfo not available, entitlement \(entitlement) active in sandbox version \(sandboxVersion).")
                    } else {
                        self.log("[SANDBOX] CustomerInfo not available, entitlement \(entitlement) not active in sandbox version \(sandboxVersion)")
                    }

                    return result(isActive, nil)
                }

                /// CustomerInfo not available, so not able to check against originalApplicationVersion
                self.log("CustomerInfo not available, entitlement \(entitlement) not active.")
                return result(false, nil)
            }
        }
    }

    fileprivate func entitlementActiveInCompatibilityVersions(_ entitlement: String, originalVersion: String) -> Bool {
        for version in CompatibilityAccessManager.shared.registeredVersions {
            if version.entitlement == entitlement, version.compatibleVersions.contains(originalVersion) {

                CompatibilityAccessManager.shared.log("Version \(originalVersion) found in registered backwards compatibility version for entitlement '\(entitlement)'.")
                return true
            }
        }
        return false
    }

    fileprivate func entitlementActiveInCompatibilityDate(_ entitlement: String, originalPurchaseDate: Date?) -> Bool {
        if let originalPurchaseDate = originalPurchaseDate {
            for version in CompatibilityAccessManager.shared.registeredVersions {
                if version.entitlement == entitlement,
                   let maximumPurchaseDateAllowed = version.purchasedBefore,
                   maximumPurchaseDateAllowed > originalPurchaseDate {

                    CompatibilityAccessManager.shared.log("App was originally purchased on \(originalPurchaseDate) which is before the maximum allowed date of \(maximumPurchaseDateAllowed) for entitlement '\(entitlement)', user has access.")
                    return true
                }
            }
            return false
        } else {
            return false
        }
    }
}

extension CustomerInfo {
    public func entitlementIsActiveWithCompatibility(entitlement: String, shouldCheckRegisteredCompatibilityVersions: Bool = true) -> Bool {
        /// If a user has access to an entitlement, return true
        if self.entitlements[entitlement]?.isActive == true {
            CompatibilityAccessManager.shared.log("Entitlement '\(entitlement)' active in RevenueCat.")
            return true
        } else {

            if shouldCheckRegisteredCompatibilityVersions {

                /// If a user doesn't have access to an entitlement via RevenueCat, check original downloaded version and compare to registered backwards compatibility versions. If version is not available, check the original purchase date to the date in the registered entitlements.
                if CompatibilityAccessManager.shared.registeredVersions.count != 0 {

                    if let originalVersion = self.originalApplicationVersionFixed {
                        if CompatibilityAccessManager.shared
                            .entitlementActiveInCompatibilityVersions(entitlement, originalVersion: originalVersion) == true {
                            return true
                        }
                    }

                    if let originalPurchaseDate = self.originalPurchaseDateFixed {
                        if CompatibilityAccessManager.shared.entitlementActiveInCompatibilityDate(entitlement, originalPurchaseDate: originalPurchaseDate) == true {
                            return true
                        }
                    }
                }
            }

            /// No registered backwards compatibility versions, or no available originalApplicationVersion to check against
            CompatibilityAccessManager.shared.log("Entitlement \(entitlement) not active.")
            return false
        }
    }

    fileprivate var originalApplicationVersionFixed: String? {
        #if os(macOS)
        let isSandbox = NSApplication.isSandbox
        #else
        let isSandbox = UIApplication.isSandbox
        #endif
        if isSandbox {
            return CompatibilityAccessManager.shared.sandboxVersionOverride ?? self.originalApplicationVersion
        } else {
            return self.originalApplicationVersion
        }
    }

    fileprivate var originalPurchaseDateFixed: Date? {
        #if os(macOS)
        let isSandbox = NSApplication.isSandbox
        #else
        let isSandbox = UIApplication.isSandbox
        #endif
        if isSandbox {
            return CompatibilityAccessManager.shared.sandboxOriginalPurchaseDateOverride ?? self.originalPurchaseDate
        } else {
            return self.originalPurchaseDate
        }
    }
}

/// Version and entitlement registration
extension CompatibilityAccessManager {
    public func register(entitlement: BackwardsCompatibilityEntitlement) {
        if !registeredVersions.contains(entitlement) {
            registeredVersions.append(entitlement)
            self.log("Registered entitlement '\(entitlement.entitlement)' for versions \(entitlement.compatibleVersions.joined(separator: ", ")).")
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

#if os(macOS)
// NSApplication helpers

import AppKit

extension NSApplication {
    static var isSandbox: Bool {
        Bundle.main.appStoreReceiptURL?.path.contains("sandboxReceipt") == true
    }
}
#else
/// UIApplication helpers
import UIKit

extension UIApplication {
    static var isSandbox: Bool {
        Bundle.main.appStoreReceiptURL?.path.contains("sandboxReceipt") == true
    }
}
#endif
