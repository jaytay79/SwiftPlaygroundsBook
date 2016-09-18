//
//  ContinuousIdleQueue.swift
//
//  Copyright (c) 2016 Apple Inc. All Rights Reserved.
//

import Foundation

/// Runs a set of initial commands before having the actor idle continuously.
final class ContinuousIdleQueue: CommandQueueDelegate {
    
    unowned let actor: Actor
    private let queue = CommandQueue()
    
    init(actor: Actor) {
        self.actor = actor
        
        // Wire up the delegates.
        queue.delegate = self
    }
    
    deinit {
        stop()
    }
    
    func start(initialAnimations: [EventGroup]) {
        queue.clear()
        
        // Fill the queue with the initial commands.
        let commands = actor.animationCommands(initialAnimations)
        queue.append(commands)
        
        actor.commandDriver = queue
        
        // Manually drive the commandQueue.
        queue.runMode = .randomAccess

        queue.runNextCommand()
    }
    
    func stop() {
        actor.commandDriver = nil
        
        // Clear the queue to ensure that it is not still running.
        queue.clear()
    }
    
    // MARK: CommandQueueDelegate
    
    func commandQueue(_ queue: CommandQueue, added _: Command) {}
    
    func commandQueue(_ queue: CommandQueue, willPerform _: Command) {
        #if os(iOS)
        // Remove the accessibility component.
        actor.removeComponent(ofType: AccessibilityComponent.self)
        #endif
    }
    
    func commandQueue(_ queue: CommandQueue, didPerform cmd: Command) {
        assert(queue === self.queue)
        
        if queue.isFinished {
            queue.clear()
            
            // Add a random delay of `default` breathing animations.
            let delay = actor.animationCommand(.default)
            
            for _ in 0..<randomInt(from: 1, to: 5) {
                queue.append(delay)
            }
            
            // Add a random idle to the end.
            let idle = actor.animationCommand(.idle)
            queue.append(idle)
            
            
            // Must run the next command because the queue has been cleared. 
            queue.runNextCommand()
        }
        else {
            // Continue to run the queue. 
            queue.runCurrentCommand()
        }
    }
}
