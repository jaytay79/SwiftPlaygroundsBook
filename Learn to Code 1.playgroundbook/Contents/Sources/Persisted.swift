//
//  Persisted.swift
//
//  Copyright (c) 2016 Apple Inc. All Rights Reserved.
//

import PlaygroundSupport
import Foundation

/// The name of the current page being presented.
/// Must be manually set in the pages auxiliary sources.
public var pageIdentifier = ""

enum Persisted {
    enum Key {
        static let characterName = "CharacterNameKey"
        
        static let speedIndex = "SpeedIndexKey"
        
        static let configPList = "Configuration"
        
        static var executionCount: String {
            return "\(pageIdentifier).executionCountKey"
        }
    }
    
    static let store = PlaygroundKeyValueStore.current
    
    static let configuration: NSDictionary? = {
        guard let url = Bundle.main.url(forResource: Key.configPList, withExtension: "plist") else {
            return nil
        }
        return NSDictionary(contentsOf: url)
    }()
    
    // MARK: Accessors
    
    static func integer(forKey key: String) -> Int? {
        guard case let .integer(i)? = store[key] else { return nil }
        return i
    }
    
    static func string(forKey key: String) -> String? {
        guard case let .string(str)? = store[key] else { return nil }
        return str
    }
    
    // MARK: Properties
    
    static var speedIndex: Int {
        get {
            let count = integer(forKey: Key.speedIndex)
            return count ?? 0
        }
        set {
            store[Key.speedIndex] = .integer(newValue)
        }
    }
}

/** 
    Reads the current page run count from UserDefaults.
    It relies on the `pageIdentifier` to be correctly set
    so that the page can be correctly identified.
 */
public var currentPageRunCount: Int {
    get {
        let runCount = Persisted.integer(forKey: Persisted.Key.executionCount)
        return runCount ?? 0
    }
    set {
        Persisted.store[Persisted.Key.executionCount] = .integer(newValue)
    }
}

extension ActorType {
    
    static func loadDefault() -> ActorType {
        let key = Persisted.Key.characterName
        
        let type: ActorType
        // Look for a previously saved type.
        if let value = Persisted.string(forKey: key),
            let loadedType = ActorType(rawValue: value) {
            type = loadedType
        }
        // Check the "Configuration.plist" for a default character.
        else if let value = Persisted.configuration?[key] as? String,
            let defaultValue = ActorType(rawValue: value.lowercased()) {
            type = defaultValue
        }
        // Return `.byte` as the fallback type if no saved value is found.
        else {
            type = .byte
        }
    
        return type
    }
    
    func saveAsDefault() {
        Persisted.store[Persisted.Key.characterName] = .string(self.rawValue)
    }
}
