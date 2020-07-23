# PurchasesHelper

A set of helper utilities to use with RevenueCat's [*Purchases*](https://github.com/RevenueCat/purchases-ios) iOS SDK for building paywalls.

## Installation

### Swift Package Manager

Add this repository as a Swift Package in Xcode.

## Features

### Package Formatting

Although RevenueCat makes subscription logic simple, displaying the length and terms of a subscription package is not trivial when considering introductory and promotional offers, as well as recurring attributes that must be shown on your paywall.

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
let terms = myPackage.packageTerms(recurring: true)
// terms = '3 day free trial, then $24.99/year'
```

Set `recurring` to `false` to format your terms as non-recurring, like:

```swift
let terms = myPackage.packageTerms(recurring: false)
// terms = '3 day free trial, then $24.99 for 1 year'
```

The `packageTerms(recurring:)` method supports [introductory]() and [promotional]() offers.

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
