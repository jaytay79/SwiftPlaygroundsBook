//
//  _AlwaysOn.swift
//
//  Copyright (c) 2016 Apple Inc. All Rights Reserved.
//

import PlaygroundSupport
import SceneKit

private var _isLiveViewConnectionOpen = false

extension PlaygroundPage {
    var isLiveViewConnectionOpen: Bool {
        return _isLiveViewConnectionOpen
    }
}

extension SceneController: PlaygroundLiveViewMessageHandler {
    // MARK: PlaygroundLiveViewMessageHandler
    
    public func liveViewMessageConnectionOpened() {
        _isLiveViewConnectionOpen = true
        
        let duration = characterPicker.isVisible ? CharacterPickerController.fadeDuration : WorldConfiguration.Scene.resetDuration
        
        // Mark the scene as `ready` to receive more commands.
        scene.reset(duration: duration)
        
        // Dismiss the character picker if it's currently showing.
        characterPicker.dismiss(toIdle: false)
    }
    
    public func receive(_ message: PlaygroundValue) {
        guard case let .dictionary(dict) = message else {
            log(message: "Received invalid message: \(message).")
            return
        }
        let world = scene.gridWorld
        
        // Finished sending commands.
        if case let .boolean(passed)? = dict[LiveViewMessageKey.finishedSendingCommands] {
            isPassingRun = passed
            startPlayback()
            
            // Attempt to find the criteria if more specific info is needed.
            if let criteriaMessage = dict[LiveViewMessageKey.successCriteriaInfo],
                let criteria = GridWorld.SuccessCriteria.init(message: criteriaMessage) {
                world.successCriteria = criteria
            }
        }
        else {
            // Received commands.
            let decoder = CommandDecoder(world: world)
            guard let command = decoder.command(from: message) else {
                log(message: "Failed to decode message: \(message).")
                return
            }
            
            // Directly add the performer.
            world.commandQueue.append(command)
        }
    }
    
    public func liveViewMessageConnectionClosed() {
        _isLiveViewConnectionOpen = false
        
        // Stop running the command queue.
        scene.commandQueue.runMode = .randomAccess
        scene.state = .initial
    }
}

// MARK: Send Commands

public func sendCommands(for world: GridWorld) {
    let liveView = PlaygroundPage.current.liveView
    guard let liveViewMessageHandler = liveView as? PlaygroundLiveViewMessageHandler else {
        log(message: "Attempting to send commands, but the connection is closed.")
        return
    }
    
    guard world.isAnimated else {
        presentAlert(title: "Failed To Send Commands.", message: "Missing call to `finalizeWorldBuilding(for: world)` in page sources.")
        return
    }
    
    // Complete the queue to ensure the last command is run. 
    world.commandQueue.complete()
    
    // Calculate the results before the world is reset.
    let results = world.calculateResults()
    let passed = results.passesCriteria
    assessmentObserver?.passedCriteria = passed
    
    // Reset the queue to reset state items like Switches, Portals, etc.
    world.commandQueue.rewind()
    
    let encoder = CommandEncoder(world: world)
    
    for command in world.commandQueue {
        let message = encoder.createMessage(from: command)
        liveViewMessageHandler.send(message)
        
        #if DEBUG
        // Testing in app.
        let appDelegate = (UIApplication.shared.delegate as! AppDelegate).rootVC
        appDelegate?.receive(message)
        #endif
    }
    
    // Mark that all the commands have been sent, and pass the result of the world.
    let passingRun = PlaygroundValue.boolean(passed)
    let finalMessage = [LiveViewMessageKey.finishedSendingCommands: passingRun,
                        LiveViewMessageKey.successCriteriaInfo: world.successCriteria.message]
    liveViewMessageHandler.send(.dictionary(finalMessage))
    
    #if DEBUG
    let appDelegate = (UIApplication.shared.delegate as! AppDelegate).rootVC
    appDelegate?.receive(.dictionary(finalMessage))
    #endif
}
