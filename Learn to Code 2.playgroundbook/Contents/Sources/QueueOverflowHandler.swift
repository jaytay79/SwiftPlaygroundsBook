//
//  QueueOverflowHandler.swift
//
//  Copyright (c) 2016 Apple Inc. All Rights Reserved.
//

import Foundation
import PlaygroundSupport

extension Notification.Name {
    /// Indicates that the `commandQueue` is ready for more commands.
    /// (After being blocked at the `commandLimit` by the QueueOverflowHandler.
    static let queueIsReadyForMoreCommands = Notification.Name(rawValue: "QueueIsReadyForMoreCommands")
}

class QueueOverflowHandler: CommandQueueDelegate {
    
    // Allow 500 commands to be enqueued at a time before starting to run.
    static let commandLimit = 500
    
    unowned let world: GridWorld
    
    var isReadyForMoreCommands = true
    
    init(world: GridWorld) {
        self.world = world

        world.commandQueue.overflowDelegate = self
    }
    
    // MARK: CommandQueueDelegate
    
    func commandQueue(_ queue: CommandQueue, added _: Command) {
        guard isReadyForMoreCommands else { return }
        
        if queue.count > QueueOverflowHandler.commandLimit {
            isReadyForMoreCommands = false
            
            // Set the assessment status to update the hints. 
            setAssessmentStatus()
            
            sendCommands(for: world)
            queue.complete()
            
            // Clear the current queue.
            queue.clear()

            // Spin the runloop until the LiveView process is ready for more commands.
            repeat {
                RunLoop.main.run(mode: .defaultRunLoopMode, before: Date(timeIntervalSinceNow: 0.1))
            } while !isReadyForMoreCommands
        }
    }
    
    func commandQueue(_ queue: CommandQueue, willPerform _: Command) {}
    
    func commandQueue(_ queue: CommandQueue, didPerform _: Command) {
        // When these are only a few commands left to run, allow another batch to be enqueued.
        if queue.pendingCommands.count == QueueOverflowHandler.commandLimit / 10 {
            NotificationCenter.default.post(name: .queueIsReadyForMoreCommands, object: self)
        }        
    }
}
