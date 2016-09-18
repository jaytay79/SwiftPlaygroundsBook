//
//  UserProcessDelegate.swift
//
//  Copyright (c) 2016 Apple Inc. All Rights Reserved.
//

import PlaygroundSupport

final class UserProcessDelegate: PlaygroundRemoteLiveViewProxyDelegate {
    var assessmentObserver: AssessmentObserver?
    var overflowHandler: QueueOverflowHandler?
    
    init(assessmentObserver: AssessmentObserver?, overflowHandler: QueueOverflowHandler?) {
        self.assessmentObserver = assessmentObserver
        self.overflowHandler = overflowHandler
    }
    
    // MARK: PlaygroundRemoteLiveViewProxyDelegate
    
    /*
     PlaygroundRemoteLiveViewProxyDelegate lives in the user processor.
     
     The methods below are only called in the user process.
     */
    
    func remoteLiveViewProxyConnectionClosed(_ remoteLiveViewProxy: PlaygroundRemoteLiveViewProxy) {
        
        // Kill user process if LiveView process closed.
        PlaygroundPage.current.finishExecution()
    }
    
    func remoteLiveViewProxy(_ remoteLiveViewProxy: PlaygroundRemoteLiveViewProxy, received message: PlaygroundValue) {
        guard case let .dictionary(dict) = message else { return }

        if case .boolean(_)? = dict[LiveViewMessageKey.finishedEvaluating] {
            setAssessmentStatus()
            
            // Finish the user process execution.
            PlaygroundPage.current.finishExecution()
        }
        else if case .boolean(_)? = dict[LiveViewMessageKey.readyForMoreCommands] {
            // Indicate that the handler is ready for more commands.
            overflowHandler?.isReadyForMoreCommands = true
        }
    }
}

