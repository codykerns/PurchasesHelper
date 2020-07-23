//
//  PurchasesHelper.swift
//
//  Copyright © 2020 Cody Kerns. All rights reserved.
//

import Foundation
import Purchases

public extension Purchases.Package {
    func packageTerms(recurring: Bool = true) -> String {
        let normalPrice = self.localizedPriceString
        let introPrice = self.localizedIntroductoryPriceString
        
        // - setup the normal product subscription length string
        var perTitle = "/\(packagePerTitle)".lowercased()
        
        if recurring == false {
            perTitle = "for \(displayTitle)".lowercased()
        }
        
        // - check for an introductory discount for a package
        if let intro = self.product.introductoryPrice {
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
                let introPerTitle = "\(introPrice)/\(intro.subscriptionPeriod.unit.title) for \(payAYGTitle)"
                return "\(introPerTitle), then \(normalPrice)\(perTitle)"
                
            @unknown default:
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

public extension Array where Element: Purchases.Package {
    enum SortedPackageType {
        case timeAscending
        case timeDescending
        case hasIntroductoryPrice
    }
    
    func sorted(by type: SortedPackageType = .timeAscending) -> [Purchases.Package] {
        switch type {
        case .timeAscending:
            // weekly -> monthly -> yearly
            return self.sorted(by: { $0.packageType.rawValue > $1.packageType.rawValue })
        case .timeDescending:
            // yearly -> monthly -> weekly
            return self.sorted(by: { $0.packageType.rawValue < $1.packageType.rawValue })
        case .hasIntroductoryPrice:
            // 3 day trial, yearly -> weekly -> monthly
            return self.sorted(by: {
                return $0.product.introductoryPrice != nil && $1.product.introductoryPrice == nil
            })
        }
    }
}

fileprivate extension SKProductSubscriptionPeriod {
    var periodLengthTitle: String {
        let isPlural = numberOfUnits != 1
        return "\(numberOfUnits) \(unit.title)\(isPlural ? "s" : "")"
    }
}

fileprivate extension SKProductDiscount {
    func periodLengthTitle(for unit: SKProduct.PeriodUnit) -> String {
        let isPlural = numberOfPeriods != 1
        return "\(numberOfPeriods) \(unit.title)\(isPlural ? "s" : "")"
    }
}

fileprivate extension SKProduct.PeriodUnit {
    var title: String {
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

public extension Purchases.Package {
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
        case .annual: return "Annually"
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
