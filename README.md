# PurchasesHelper

A set of helper utilities to use for building paywalls with RevenueCat's [*Purchases*](https://github.com/RevenueCat/purchases-ios) iOS SDK.

## Installation

### Swift Package Manager

Add this repository as a Swift Package in Xcode.

## Features

### CompabilityAccessManager

Many developers have paid apps that they would like to convert to subscription apps. PurchasesHelper includes `CompatibilityAccessManager` to be used as a source of truth for entitlement access. 

To use it, simply register an entitlement to a set of app versions that should be granted access. For example, if your paid app was version 1.0 (50) and your subscription update is 1.1 (75), register your entitlement like the following:

```swift

CompatibilityAccessManager.shared.register(entitlement:
    .init(entitlement: "Premium", versions: ["50"])
)

```

To check if your entitlement is active between RevenueCat or these registered entitlements:

```swift

CompatibilityAccessManager.shared.isActive(entitlement: "Premium") { (isActive) in

}

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
> Sorts by packages that have an introductory price (e.g. free trial) first
