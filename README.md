![GitHub release (latest by date)](https://img.shields.io/github/v/release/codykerns/PurchasesHelper?color=orange&label=SPM&logo=swift&logoColor=white)
[![GitHub issues](https://img.shields.io/github/issues/codykerns/PurchasesHelper)](https://github.com/codykerns/PurchasesHelper/issues)
[![GitHub license](https://img.shields.io/github/license/codykerns/PurchasesHelper)](https://github.com/codykerns/PurchasesHelper/blob/master/LICENSE)

# PurchasesHelper

A set of helper utilities to use for building paywalls with RevenueCat's [*Purchases*](https://github.com/RevenueCat/purchases-ios) iOS SDK.

## Installation

### Swift Package Manager

Add this repository as a Swift Package in Xcode.

## Features

### CompabilityAccessManager

Many developers have paid apps that they would like to convert to subscription apps. PurchasesHelper includes `CompatibilityAccessManager` to be used as a source of truth for entitlement access. 

The easiest way to get started is to call `configure` on the shared instance of `CompatibilityAccessManager` after you initialize the Purchases SDK and provide an array of entitlement names and versions. For example, if your paid app was version 1.0 (50) and your subscription update is 1.1 (75), register your entitlement like the following:

```swift

CompatibilityAccessManager.configure(entitlements: [
    .init(entitlement: "premium_access", versions: ["50"])
])

```

If you don't want purchase restoration on launch, simply register an entitlement to a set of app versions that should be granted access. 

```swift

CompatibilityAccessManager.shared.register(entitlement:
    .init(entitlement: "premium_access", versions: ["50"])
)

```
As `CompatibilityAccessManager` is now your source of truth for entitlement access, you have a few options for checking if entitlements are active.

If you want `CompatibilityAccessManager` to asynchronously fetch purchaserInfo and check if your entitlement is active between RevenueCat or your registered entitlements, call `isActive`  on the shared `CompatibilityAccessManager`. This is safe to call as often as you need, as it relies on the Purchases SDK caching mechanisms for fetching purchaserInfo:

```swift

CompatibilityAccessManager.shared.isActive(entitlement: "premium_access") { (isActive, purchaserInfo) in

}

```

Or, you can check synchronously from an instance of PurchaserInfo:

```swift

purchaserInfo.isActive(entitlement: "premium_access")

```

##### Sandbox

In sandbox mode, the originalApplicationVersion is always '1.0'. To test different versions and how they behave, set the sandboxVersionOverride property to simulate a version number while only in sandbox mode:

```swift

CompatibilityAccessManager.shared.sandboxVersionOverride = "50"

```

### Package Formatting

Although RevenueCat makes subscription logic simple, displaying the length and terms of a subscription package is not trivial when considering introductory offers, as well as recurring attributes that must be shown on your paywall.

#### Package Title

PurchasesHelper adds new properties to RevenueCat's Package objects.

```swift
var title = myPackage.displayTitle
// displayTitle = '1 Month'

title = myPackage.displayTitleRecurring
// title = 'Monthly'
```

#### Package Terms

PurchasesHelper adds a new method to RevenueCat's Package objects that builds a string to display subscription terms to a customer.

```swift
let terms = myPackage.packageTerms()
// terms = '3 day free trial, then $24.99/year'
```

Set `recurring` to `false` to format your terms as non-recurring, like:

```swift
let terms = myPackage.packageTerms(recurring: false)
// terms = '3 day free trial, then $24.99 for 1 year'
```

### Package Sorting

Easily sort an array of Package objects.

After [fetching offerings](https://docs.revenuecat.com/docs/displaying-products#fetching-offerings), sort the `availablePackages` property or any array of Package objects with the new `sorted(by:)` method.

```swift
let packages = offering.availablePackages.sorted(by: .timeAscending)
// packages = [1 month, 3 month, 6 month]

let packages = offering.availablePackages.sorted(by: .timeDescending)
// packages = [6 month, 3 month, 1 month]
```

The available sorting options are:

> **.timeAscending**  
> Sorts by shortest duration -> longest duration

> **.timeDescending**  
> Sorts by longest duration -> shortest duration

> **.hasIntroductoryPrice**  
> Sorts by packages that have an introductory price (e.g. free trial) first. Requires iOS 11.2 minimum.
