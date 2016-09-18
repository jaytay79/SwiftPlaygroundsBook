//
//  AssessmentObserver.swift
//
//  Copyright (c) 2016 Apple Inc. All Rights Reserved.
//

import Foundation
import PlaygroundSupport

class AssessmentObserver {
    var observers = [NSObjectProtocol]()
    
    /// Defers the assessment of the world until `finishedEvaluating` message
    /// has been received.
    var evaluate: () -> AssessmentResults
    
    /// Set to indicate if the current run is a pass or fail.
    /// (Only set within the User process).
    var passedCriteria = false
    
    init(evaluate: @escaping () -> AssessmentResults) {
        self.evaluate = evaluate
        
        let center = NotificationCenter.default
        self.observers = [
            center.addObserver(forName: .queueIsReadyForMoreCommands, object: nil, queue: .main, using: queueIsReady),
            
            /// Observer to look for `scenePlaybackDidComplete` from the LiveViewProcess.
            center.addObserver(forName: .scenePlaybackDidComplete, object: nil, queue: .main, using: sceneDidComplete)
        ]
    }
    
    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: Notification Callbacks
    
    private func queueIsReady(_: Notification) {
        guard PlaygroundPage.current.isLiveViewConnectionOpen else {
            log(message: "Attempting to send message, but the connection is closed.")
            return
        }
        
        let liveView = PlaygroundPage.current.liveView
        guard let liveViewMessageHandler = liveView as? PlaygroundLiveViewMessageHandler else { return }
        
        
        let message: PlaygroundValue = .dictionary([LiveViewMessageKey.readyForMoreCommands: .boolean(true)])
        liveViewMessageHandler.send(message)
    }
    
    private func sceneDidComplete(_: Notification) {
        // If an AlwaysOn connection is open, send assessment status to the other process.
        if PlaygroundPage.current.isLiveViewConnectionOpen {
            sendAssessmentMessage()
        }
        else {
            // Else set the status directly.
            setAssessmentStatus()
        }
    }
    
    func sendAssessmentMessage() {
        // Check that the connection is open.
        guard PlaygroundPage.current.isLiveViewConnectionOpen else {
            log(message: "Attempting to send assessment message, but the connection is closed.")
            return
        }
        
        let liveView = PlaygroundPage.current.liveView
        guard let liveViewMessageHandler = liveView as? PlaygroundLiveViewMessageHandler else { return }
        
        // Indicate from the LiveViewProcess that the world is finished and ready for the
        // hints to be displayed.
        let message: PlaygroundValue = .dictionary([LiveViewMessageKey.finishedEvaluating: .boolean(true)])
        liveViewMessageHandler.send(message)
    }
}
