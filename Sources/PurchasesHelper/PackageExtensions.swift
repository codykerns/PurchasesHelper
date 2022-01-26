//
//  PackageExtensions.swift
//
//  Copyright © 2020 Cody Kerns. All rights reserved.
//

import RevenueCat

public extension RevenueCat.Package {
    
    /// Customer-facing payment terms for a RevenueCat package. Not localized.
    /// - Parameter isRecurring: If the terms should be in a recurring format. `$99/year` vs `$99 for 1 year`. Defaults to `true`.
    /// - Parameter includesIntroTerms: If the terms should include the introductory price for the product. e.g. if a user has already redeemed a free trial, passing `false` would not include the free trial terms. Defaults to `true`.
    /// - Returns: A string with the terms of the package's product.
    /// e.g. `1 week free trial, then $24.99/year`
    func packageTerms(isRecurring: Bool = true, includesIntroTerms: Bool = true) -> String {
        let normalPrice = self.localizedPriceString
        
        guard self.packageType != .lifetime else {
            return normalPrice
        }
        
        // - setup the normal product subscription length string
        var perTitle = "/\(packagePerTitle)".lowercased()
        
        if isRecurring == false {
            perTitle = "for \(displayTitle)".lowercased()
        }
        
        // - check for an introductory discount for a package
        if #available(iOS 11.2, *), includesIntroTerms == true,
           let intro = self.storeProduct.introductoryDiscount,
           let introPrice = self.localizedIntroductoryPriceString {
            
            // - introductory offers
            let introLengthTitle = intro.subscriptionPeriod.periodLengthTitle
            
            switch intro.paymentMode {
            case .freeTrial:
                // - free trial title
                // - e.g. '3 day free trial, then $24.99/year'
                return "\(introLengthTitle) free trial, then \(normalPrice)\(perTitle)"
                
            case .payUpFront:
                // - pay up front title
                // - e.g. '$4.99 up front for 3 months, then $24.99/year'
                return "\(introPrice) up front for \(introLengthTitle), then \(normalPrice)\(perTitle)"
                
            case .payAsYouGo:
                // - pay as you go title
                // - e.g. '$1.99 per month for 6 months, then $24.99/year'
                let payAYGTitle = intro.periodLengthTitle(for: intro.subscriptionPeriod.unit)
                let introPerTitle = "\(introPrice)/\(intro.subscriptionPeriod.unit.unitTitle) for \(payAYGTitle)"
                return "\(introPerTitle), then \(normalPrice)\(perTitle)"
                
            default:
                // - an introductory product exists, but the type isn't known. display the intro price and the purchase dialog should display the appropriate terms
                return introPrice
            }
        } else {
            
            // - normal product, no discount
            // - e.g. '$24.99/year'
            return "\(normalPrice)\(perTitle)"
        }
    }
}

public extension Array where Element: RevenueCat.Package {
    enum SortedPackageType {
        case timeAscending
        case timeDescending
        case hasIntroductoryPrice
    }
    
    func sorted(by type: SortedPackageType = .timeAscending) -> [RevenueCat.Package] {
        switch type {
        case .timeAscending:
            // weekly -> monthly -> yearly
            return self.sorted(by: { $0.packageType.rawValue > $1.packageType.rawValue })
        case .timeDescending:
            // yearly -> monthly -> weekly
            return self.sorted(by: { $0.packageType.rawValue < $1.packageType.rawValue })
        case .hasIntroductoryPrice:
            // 3 day trial, yearly -> weekly -> monthly
            if #available(iOS 11.2, *) {
                return self.sorted(by: {
                    return $0.storeProduct.introductoryDiscount != nil && $1.storeProduct.introductoryDiscount == nil
                })
            } else {
                return self.sorted(by: .timeAscending)
            }
        }
    }
}

@available(iOS 11.2, *)
fileprivate extension RevenueCat.SubscriptionPeriod {
    var periodLengthTitle: String {
        let isPlural = self.value != 1
        return "\(self.value) \(unit.unitTitle)\(isPlural ? "s" : "")"
    }
}

@available(iOS 11.2, *)
fileprivate extension RevenueCat.StoreProductDiscount {
    func periodLengthTitle(for unit: RevenueCat.SubscriptionPeriod.Unit) -> String {
        let isPlural = subscriptionPeriod.value != 1
        return "\(subscriptionPeriod.value) \(unit.unitTitle)\(isPlural ? "s" : "")"
    }
}

@available(iOS 11.2, *)
fileprivate extension RevenueCat.SubscriptionPeriod.Unit {
    var unitTitle: String {
        switch self {
        case .day:
            return "day"
        case .month:
            return "month"
        case .week:
            return "week"
        case .year:
            return "year"
        default:
            return "unknown"
        }
    }
}

public extension RevenueCat.Package {
    fileprivate var packagePerTitle: String {
        switch self.packageType {
        case .lifetime: return "lifetime"
        case .annual: return "year"
        case .sixMonth: return "6 months"
        case .threeMonth: return "3 months"
        case .twoMonth: return "2 months"
        case .monthly: return "month"
        case .weekly: return "week"
        case .unknown: return "unknown"
        default: return self.identifier
        }
    }
    
    var displayTitle: String {
        switch self.packageType {
        case .lifetime: return "Lifetime"
        case .annual: return "1 Year"
        case .sixMonth: return "6 Months"
        case .threeMonth: return "3 Months"
        case .twoMonth: return "2 Months"
        case .monthly: return "1 Month"
        case .weekly: return "1 Week"
        case .unknown: return "Unknown"
        default: return self.identifier
        }
    }
    
    var displayTitleRecurring: String {
        switch self.packageType {
        case .lifetime: return "Lifetime"
        case .annual: return "Yearly"
        case .sixMonth: return "6 Months Recurring"
        case .threeMonth: return "3 Months Recurring"
        case .twoMonth: return "2 Months Recurring"
        case .monthly: return "Monthly"
        case .weekly: return "Weekly"
        case .unknown: return "Unknown"
        default: return self.identifier
        }
    }
}
