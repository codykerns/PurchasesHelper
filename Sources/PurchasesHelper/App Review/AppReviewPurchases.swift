//
//  File.swift
//  
//
//  Created by Cody Kerns on 10/6/22.
//

import Foundation
import RevenueCat

#if os(iOS)
import UIKit
#endif

@available(iOS 11.0, *)
public extension AppReviewChecker {

    /// App Review is notoriously one of the worst experiences for a developer. Use this method to display a message to the reviewer if things don't appear to be set up correctly in their environment.
    ///
    /// When using in-app purchases, App Review becomes even more difficult. The first release of an app with in-app purchases often gets rejected, typically because app reviewers don't first 'approve' the in-app products before attempting to review the app. Other rejections are just due to the sandbox environment being extremely unstable.
    ///
    /// This leads to developers having to submit build after build with no changes, just trying to get an app reviewer that either understands how it works, or to get lucky.
    ///
    /// This method checks for a specific offering, and if it doesn't exist, it means the products could not be fetched. At that point, it will inform App Review to first approve the products before attempting to make purchases.
    /// - Parameter offeringIdentifier: The identifier of the Offering the check. Nil to use the default `current` offering.
    func validateOfferingsIfInAppReview(offeringIdentifier: String? = nil, from viewController: UIViewController) {
        Purchases.shared.getOfferings { offerings, error in
            let offering = offeringIdentifier == nil ? offerings?.current : offerings?.offering(identifier: offeringIdentifier!)

            if offering == nil {
                self.isAppInReview { isInReview in
                    if isInReview {
                        self.log("App is currently in review, and failed to find the offering. Displaying message to App Review.")

                        let alert = UIAlertController(title: "Message to App Review", message: "Warning: It appears that this app is in under review, but products are currently *not* able to be fetched from Apple's own StoreKit API. \n\nTypically, this means that the sandbox environment has failed, or the products have not yet been approved.\n\nPlease approve the products associated with this review first, before continuing this review.\n\nIf this message continues to be displayed, please reinstall and/or wait for the products to propagate the App Store sandbox review environment.", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
                        alert.popoverPresentationController?.sourceView = viewController.view
                        viewController.present(alert, animated: true)
                    }
                }
            }
        }
    }
}
