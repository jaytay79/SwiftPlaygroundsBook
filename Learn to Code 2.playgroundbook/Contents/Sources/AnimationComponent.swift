//
//  AnimationComponent.swift
//
//  Copyright (c) 2016 Apple Inc. All Rights Reserved.
//
import SceneKit

class AnimationComponent: NSObject, CAAnimationDelegate, ActorComponent {
    static let defaultAnimationKey = "DefaultAnimation-Key"
    
    // MARK: Properties
    
    unowned let actor: Actor
    
    var animationCache: AssetCache {
        return AssetCache.cache(forType: self.actor.type)
    }

    private var animationNode: SCNNode {
        // The base `scnNode` holds the node animation should be 
        // applied to as it's first child.
        let geo = actor.scnNode.childNodes.first
        return geo ?? actor.scnNode
    }
    
    private var animationStepIndex = 0
    
    var currentAnimationDuration = 0.0
    
    private var isRunningContinousIdle = false
    
    // MARK: Initializers
    
    init(actor: Actor) {
        self.actor = actor
        super.init()
    }
    
    func setInitialState(for action: Action) {
        switch action {
        case .move(let dis, _): actor.position = dis.from
        case .turn(let dis, _): actor.rotation = dis.from
        default: break
        }
    }
    
    // MARK: Performer
    
    func applyStateChange(for action: Action) {
        switch action {
        case .move(let dis, _): actor.position = dis.to
        case .turn(let dis, _): actor.rotation = dis.to
        default: break
        }
    }
    
    func cancel(_: Action) {
        removeAnimations()
    }
    
    // MARK: ActorComponent
    
    func perform(event: EventGroup, variation index: Int, speed: Float) -> Bool {
        guard let action = actor.currentAction else { return false }
        // Ensure the initial state is correct.
        setInitialState(for: action)
        
        // If the actor is not in the world, execute the action immediatly.
        guard actor.isInWorld || actor.isInCharacterPicker else {
            applyStateChange(for: action)
            return false
        }
        
        let animation: CAAnimation?
        
        // Look for a faster variation of the requested action to play at speeds above `WorldConfiguration.Actor.walkRunSpeed`.
        if speed >= WorldConfiguration.Actor.walkRunSpeed,
            let fastVariation = event.fastVariation,
            let fastAnimation = animationCache.animation(for: fastVariation, index: animationStepIndex) {
            
            animation = fastAnimation
            animation?.speed = max(speed - WorldConfiguration.Actor.walkRunSpeed, 1)
            animationStepIndex = animationStepIndex == 0 ? 1 : 0
        }
        else {
            animation = animationCache.animation(for: event, index: index)
            animation?.speed = speed //EventGroup.walkingAnimations.contains(action) ? speed : 1.0
        }
        
        guard let readyAnimation = animation?.copy() as? CAAnimation else { return false }
        readyAnimation.delegate = self
        readyAnimation.setDefaultAnimationValues(isStationary: event.isStationary)
        
        // Remove any lingering animations that may still be attached to the node.
        removeAnimations()
        animationNode.addAnimation(readyAnimation, forKey: event.rawValue)
        
        // Set the current animation duration.
        currentAnimationDuration = readyAnimation.duration / Double(readyAnimation.speed)
        
        return true
    }
    
    // MARK: Remove
    
    func removeAnimations() {
        func removeAnimations(from node: SCNNode) {
            // Remove all animations.
            for key in node.animationKeys {
                node.removeAnimation(forKey: key)
            }
        }
        removeAnimations(from: actor.scnNode)
        removeAnimations(from: animationNode)
    }

    // MARK: CAAnimation Delegate
    
    func animationDidStop(_: CAAnimation, finished isFinished: Bool) {
        // Move the character after the animation completes.
        if isFinished {
            completeCurrentCommand()
        }
    }
    
    /// Translates the character based on the type of action.
    private func completeCurrentCommand() {
        // Cleanup current state.
        currentAnimationDuration = 0.0

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.0
        
        if let action = actor.currentAction {
            // Update the node's position.
            applyStateChange(for: action)
        }
        removeAnimations()
        
        SCNTransaction.commit()
        
        // Fire off the next animation.
        DispatchQueue.main.async {
            self.actor.performerFinished(self)
        }
    }
}
