// 
//  LiveViewMessageKey.swift
//
//  Copyright (c) 2016 Apple Inc. All Rights Reserved.
//

import PlaygroundSupport

enum LiveViewMessageKey {
    
    static let finishedSendingCommands = "FinishedSendingCommands"
    
    static let successCriteriaInfo = "successCriteriaInfo"
    
    static let readyForMoreCommands = "ReadyForMoreCommands"
    
    // The message key sent from the
    // LiveView process indicating that the world is complete.
    // Form: [String - finishedEvaluating: Bool - success]
    static let finishedEvaluating = "FinishedEvaluating"
}
