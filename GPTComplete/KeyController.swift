//
//  KeyController.swift
//  GPTComplete
//
//  Created by Matt McMurry on 3/30/23.
//

import Foundation

import Valet
final class KeyController: ObservableObject {
    
    let valet = Valet.sharedGroupValet(
        with: SharedGroupIdentifier(
            groupPrefix: "J3DWM3SH7G",
            nonEmptyGroup: "com.mcmurryapps.GPTComplete"
        )!, 
        accessibility: .whenUnlocked
    )
    private let apiKeyValue = "apiKey"
    private let organizationKeyValue = "organizationKey"
    
    @Published var apiKey = "" {
        didSet {
            do {
                try valet.setString(apiKey, forKey: apiKeyValue)
            } catch {
                print(error)
            }
        }
    }
    
    @Published var organization = "" {
        didSet {
            try? valet.setString(organization, forKey: organizationKeyValue)
        }
    }
    
    init() {
        apiKey = (try? valet.string(forKey: apiKeyValue)) ?? ""
        organization = (try? valet.string(forKey: organizationKeyValue)) ?? ""
    }
}
