// 
//  Performer.swift
//
//  Copyright (c) 2016 Apple Inc. All Rights Reserved.
//
import SceneKit

// MARK: PerformerDelegate

protocol PerformerDelegate: class {
    func performerFinished(_ performer: Performer)
}

// MARK: Performer

protocol Performer: class, Identifiable {
    // Immediate state change.
    func applyStateChange(for action: Action)
    
    func perform(_ action: Action) -> Bool
    func cancel(_ action: Action)
}

extension Performer where Self: Item {
    // MARK: Performer Default Implementations

    func applyStateChange(for action: Action) {
        switch action {
        case .move(let dis, _): position = dis.to
        case .turn(let dis, _): rotation = dis.to
        default:
            fatalError("\(self) is not capable of performing \(action).")
        }
    }

    func perform(_ action: Action) -> Bool {
        applyStateChange(for: action)
        return false
    }

    func cancel(_ action: Action) {}
}

// MARK: ActorComponent

/// Used by the ActorComponents as a generic interface for running a action.
protocol ActorComponent: Performer {
    /// The actor with which this component applies to.
    unowned var actor: Actor { get }
    
    /// Performs the requested event, with the specified variation.
    /// Returns `true` if the event is running.
    func perform(event: EventGroup, variation: Int, speed: Float) -> Bool
}

extension ActorComponent {
    // MARK: ActorComponent Default Implementations

    var id: ItemID {
        return actor.id
    }
    
    var node: SCNNode {
        return actor.scnNode
    }
    
    var currentAction: Action? {
        return actor.currentAction
    }
    
    func key(for action: Action) -> String {
        return "\(self).\(action)"
    }
    
    func applyStateChange(for action: Action) {
        // Optional implementation.
    }
    
    /// Performs the first animation corresponding to the action (if one exists).
    func perform(_ action: Action) -> Bool {
        // Optional implementation.
        return false
    }
    
    func cancel(_ action: Action) {
        node.removeAnimation(forKey: key(for: action))
        node.removeAction(forKey: key(for: action))
    }
    
    /// Runs the animation, if one exists, for the specified type. Returns the duration.
    func perform(event: EventGroup, variation: Int) -> Bool {
        return perform(event: event, variation: variation, speed: Actor.commandSpeed)
    }
    
    func perform(event: EventGroup, variation: Int, speed: Float) -> Bool {
        // Fallback to the basic `perform` request if a more specific `perform(event:variation:speed)` is not provided.
        guard let action = actor.currentAction else { return false }
        
        return perform(action)
    }
}
