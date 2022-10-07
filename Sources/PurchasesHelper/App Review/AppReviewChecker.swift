//
//  AppReviewChecker.swift
//  Based on Volkswagen.swift by Jake Mor.
//  https://github.com/jakemor/Volkswagen.swift
//
//  Created by Jake on 4/30/19.
//  Copyright © 2019 Jake Mor. All rights reserved.
//

import Foundation

public class AppReviewChecker {
    public enum TestingStatus {
        case forceIsInAppReview
        case shippingApp
    }

	public static let shared = AppReviewChecker()

    init() { }

    public var debugLogsEnabled: Bool = true

    public static func configure(appleAppId: String,
                          testingStatus: TestingStatus = .shippingApp) {
        shared.appleAppId = appleAppId
        shared.testingStatus = testingStatus
    }

    /// The Apple ID of your app. Found in App Store Connect -> App -> App Information
    private var appleAppId: String? {
		didSet {
			getLiveAppStoreVersion()
		}
	}

    /// Use this value to force AppReviewChecker to pretend your app is in review. When shipping your app, set this to `shippingApp`
    public var testingStatus: TestingStatus = .shippingApp

    private var liveVersion: String?
    private var currentVersion: String {
        return Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
    }

	private var currentVersionLookupURL: URL? {
        if let appleAppId {
            return URL(string: "https://itunes.apple.com/lookup?id=\(appleAppId)")
        }

        return nil
	}

    public func isAppInReview(completion: @escaping (Bool) -> ()) {
        guard appleAppId != nil else {
            return self.log("Call `AppReviewChecker.configure()` before checking if the app is in review.")
        }

        if self.testingStatus == .forceIsInAppReview {
            completion(true)
        } else {
            if let liveVersion = liveVersion {

                let order = currentVersion.compare(liveVersion, options: .numeric)

                if order == .orderedDescending {
                    completion(true)
                } else {
                    completion(false)
                }

            } else {
                getLiveAppStoreVersion {
                    self.isAppInReview(completion: completion)
                }
            }
        }
    }
	
	private func getLiveAppStoreVersion(completion: (() -> ())? = nil) {
		if let appleAppId,
            let currentVersionLookupURL {

            self.log("Fetching current app version..")

			let task = URLSession.shared.dataTask(with: currentVersionLookupURL) { (data, response, error) in
				
				if let data = data {
					do {
						// Convert the data to JSON
						let jsonSerialized = try JSONSerialization.jsonObject(with: data, options: []) as? [String : Any]
						
						// Get Live App Store Version
						if let json = jsonSerialized, let results = json["results"] as? [[String: Any]] {

                            if results.count > 0,
                               let version = results[0]["version"] as? String {
                                self.log("Found current live version of: \(version)")
                                self.liveVersion = version
                            } else {
                                self.log("Unable to find app based on the Apple ID: \(appleAppId)")
                                self.setToDefaultUnknown()
                            }

                            completion?()

						} else {
                            self.log("Invalid data from Apple's API.")
                            self.setToDefaultUnknown()
                            completion?()

						}
					}  catch let error as NSError {
                        self.log("Failed to decode API response: \(error.localizedDescription).")
                        self.setToDefaultUnknown()
                        completion?()
					}
				} else if let error = error {
                    self.log("Failed to fetch data: \(error.localizedDescription).")
                    self.setToDefaultUnknown()
                    completion?()
				}
			}
			
			task.resume()

		} else {
            self.log("No Apple App ID set.")
            self.setToDefaultUnknown()
			completion?()
		}
	}

    private func setToDefaultUnknown() {
        self.log("Defaulting to current live version of `0.0.0`")
        self.liveVersion = "0"
    }
	
}

extension AppReviewChecker {
    internal func log(_ message: String) {
        guard self.debugLogsEnabled else { return }

        print("[🚓 AppReviewChecker] \(message)")
    }
}
