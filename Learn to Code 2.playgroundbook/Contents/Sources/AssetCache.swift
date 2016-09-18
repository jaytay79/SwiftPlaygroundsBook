// 
//  AssetCache.swift
//
//  Copyright (c) 2016 Apple Inc. All Rights Reserved.
//
import SceneKit

class AssetCache {
    // MARK: Types
    
    typealias Animations = [CAAnimation]
    typealias Sounds = [SCNAudioSource]

    // MARK: Static
    
    private static let cacheForType: [ActorType: AssetCache] = {
        var cacheForType = [ActorType: AssetCache]()
        for type in ActorType.cases {
            cacheForType[type] = AssetCache(type: type)
        }
        return cacheForType
    }()
    
    static func cache(forType type: ActorType) -> AssetCache {
        return self.cacheForType[type]!
    }

    // MARK: Properties
    
    let type: ActorType
    var animationsForAsset = [EventGroup: Animations]()
    var soundsForAsset = [EventGroup: Sounds]()
    
    // Retrive a valid AssetCache form `AssetCache.cache(forType:)`.
    private init(type: ActorType) {
        self.type = type
    }
    
    // MARK: Asset Loading
    
    func loadAnimations(forAssets groups: [EventGroup]) {
        for group in groups {
            // Don't reload existing animations.
            guard animationsForAsset[group] == nil else { continue }
            
            // Load the new animations.
            animationsForAsset[group] = type.animations(for: group)
        }
    }
    
    func loadSounds(forAssets groups: [EventGroup]) {
        for group in groups {
            // Don't reload existing sounds.
            guard soundsForAsset[group] == nil else { continue }
            
            let sounds = type.sounds(for: group)
            soundsForAsset[group] = sounds
        }
    }
    
    func animations(for action: EventGroup) -> Animations {
        if animationsForAsset[action] == nil {
            log(message: "Animation cache miss. Loading '\(action)' action for \(type).")
            loadAnimations(forAssets: [action])
        }
        
        // Attempt to recover, but there may not be an animation for the requested action. 
        return animationsForAsset[action] ?? []
    }
    
    /// An animation of the provided type, if one exists.
    ///
    /// If an invalid index is provided this wall fall back to a random animation
    /// for the action (if one exists).
    /// `nil` returns a random animation for the provided action.
    func animation(for action: EventGroup, index: Int? = nil) -> CAAnimation? {
        return animations(for: action).retrieveElement(for: index)
    }
    
    func sounds(for action: EventGroup) -> Sounds {
        if soundsForAsset[action] == nil {
            log(message: "Sounds cache miss. Loading '\(action)' action for \(type).")
            loadSounds(forAssets: [action])
        }
        
        return soundsForAsset[action] ?? []
    }
    
    /// A sound of the provided type, if one exists.
    ///
    /// If an invalid index is provided this wall fall back to a random sound
    /// for the action (if one exists).
    /// `nil` returns a random animation for the provided action.
    func sound(for action: EventGroup, index: Int? = nil) -> SCNAudioSource? {
        return sounds(for: action).retrieveElement(for: index)
    }
}

extension Array {
    
    /// Returns a random element if the index is invalid or `nil`.
    fileprivate func retrieveElement(for index: Int?) -> Element? {
        guard !isEmpty else { return nil }
        
        let index = index ?? randomIndex
        if indices.contains(index) {
            return self[index]
        }
        else {
            return randomElement
        }
    }
}


