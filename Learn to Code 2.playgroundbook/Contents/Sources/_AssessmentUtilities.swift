//
//  _AssessmentUtilities.swift
//
//  Copyright (c) 2016 Apple Inc. All Rights Reserved.
//

import Foundation
import PlaygroundSupport

public typealias AssessmentResults = PlaygroundPage.AssessmentStatus

// MARK: Assessment Hooks

/// The user process delegate which handles communication from the LiveView.
private var delegate: UserProcessDelegate?
var assessmentObserver: AssessmentObserver?

// MARK: Assessment Registration

public func registerAssessment(_ world: GridWorld, assessment: @escaping () -> AssessmentResults) {
    // Add an `QueueOverflowHandler` to catch infinite loops.
    let overflowHandler = QueueOverflowHandler(world: world)
    
    // The assessment observer handles the assessment notifications.
    assessmentObserver = AssessmentObserver(evaluate: assessment)
    
    // Configure the delegate. 
    delegate = UserProcessDelegate(assessmentObserver: assessmentObserver, overflowHandler: overflowHandler)
    
    let page = PlaygroundPage.current
    
    // Mark the page as needing indefinite execution to wait for assessment.
    page.needsIndefiniteExecution = true
    
    let proxy = page.liveView as? PlaygroundRemoteLiveViewProxy
    proxy?.delegate = delegate
    
    #if DEBUG
    mockProxy.delegate = delegate
    #endif
}

// MARK: AssessmentStatus

/// A helper function to be used when writing assessment code to produce the correct `AssessmentResults`.
public func updateAssessment(successMessage: String, failureHints: [String], solution: String?) -> AssessmentResults {
    if let passed = assessmentObserver?.passedCriteria, passed {
        return .pass(message: successMessage)
    }
    else {
        return .fail(hints: failureHints, solution: solution)
    }
}

func setAssessmentStatus() {
    PlaygroundPage.current.assessmentStatus = assessmentObserver?.evaluate()
}

// MARK: Criteria Message

extension GridWorld.SuccessCriteria: MessageConstructible {
    var message: PlaygroundValue {
        var values = [PlaygroundValue]()
        switch self {
        case .all:
            break
        
        case let .count(collectedGems: gems, openSwitches: switches):
            values += [.integer(gems), .integer(switches)]
            
        case .pageSpecific(_):
            // Show no values for `pageSpecific(_)` criteria. 
            // This will be evaluated as a `.count(collectedGems:openSwitches:)` when the 
            // message is unpacked.
            values += [.integer(0), .integer(0)]
        }
        
        return .array(values)
    }
    
    init?(message: PlaygroundValue) {
        guard case let .array(values) = message, values.count == 2 else { return nil }
        guard case let .integer(gems) = values[0],
            case let .integer(switches) = values[1] else { return nil }
        
        self = .count(collectedGems: gems, openSwitches: switches)
    }
}

// MARK: World Assessment

/// Wraps an assessment function for ease of creating `.pageSpecific(_)` assessment.
public func assessment(_ handler: @autoclosure @escaping () -> Bool) -> GridWorld.AssessmentHandler {
    return handler
}

extension GridWorld {
    
    public func coveredInCharacters(at locations: [Coordinate]) -> Bool {
        for coor in locations {
            if self.existingCharacters(at: [coor]).isEmpty {
                return false
            }
        }
        return true
    }
    
    public func coveredInGemsAndSwitches() -> Bool {
        for coor in row(1) {
            if existingGems(at: [coor]).isEmpty || existingSwitches(at: [coor]).isEmpty {
                return false
            }
        }
        return true
        
    }
    
    public func blockStandardDeviation() -> Double {
        let heights = allPossibleCoordinates.map {
            return Double(height(at: $0))
        }
        
        let average = heights.reduce(0, +) / Double(heights.count)
        let standardDeviation = heights.reduce(0.0) { sd, height in
            let delta = height - average
            return sd + delta * delta
        }
        
        
        return standardDeviation
    }
    
    public func randomizedLandscape(worldConfig: (GridWorld) -> ()) -> Bool {
        var lastDeviation = 0
        
        for _ in 0..<10 {
            // Create new worlds the same size of this world to test with.
            let newWorld = GridWorld(columns: columnCount, rows: rowCount)
            worldConfig(newWorld)
        
            // Compare the new standardDeviation from the latest run against the last run. 
            let newDeviation = Int(newWorld.blockStandardDeviation())
            if lastDeviation == newDeviation {
                return false
            }
            log(message: "\(newWorld.existingBlocks(at: allPossibleCoordinates).count)")
            lastDeviation = newDeviation
        }
        
        return true
    }
    
    public func coveredInBlocks() -> Bool {
        // 100 is not that high of an SD
        return blockStandardDeviation() > 100
    }
    
    public func blocksPresent(count: Int, at locations: [Coordinate]) -> Bool {
        for coor in locations {
            if self.numberOfBlocks(at: coor) != count {
                return false
            }
        }
        let emptyLocations = Set(allPossibleCoordinates).subtracting(Set(locations))
        for coor in emptyLocations {
            if self.numberOfBlocks(at: coor) > 1 {
                return false
            }
        }
        return true
    }
    
    public func charactersInOrder() -> Bool {
        let characterPlacements = coordinates(inColumns: [1], intersectingRows: [0,1,2,3])
        let types: [ActorType] = [.blu, .expert, .byte, .hopper]
        
        for (type, coor) in zip(types, characterPlacements) {
            let char = existingCharacter(at: coor) ?? existingExpert(at: coor)
            
            if char?.type != type {
                return false
            }
        }
        return true
    }
   
    public func buildAnIsland() -> Bool {
        let perimeter = coordinates(inColumns: [0,1,2,3,4,5,6,7,8,9,10,11], intersectingRows: [0,11]) + coordinates(inColumns: [0,11], intersectingRows: [1,2,3,4,5,6,7,8,9,10])
        for coor in perimeter {
            if existingWater(at: [coor]).isEmpty {
                return false
            }
        }
        let allBlocks = existingBlocks(at: allPossibleCoordinates)
        let heightOf2 = allBlocks.filter {
            $0.height >= 1
        }
        if heightOf2.count < 4 {
            return false
        }
        
        return true
    }
    
    // Checks for 12 characters added and 8 blocks with a height of 13
    public func appendingRemovedValues() -> Bool {
        let row2 = row(2)

        if existingCharacters(at: row2).count != 12 {
            return false
        }
        let row2Blocks = existingBlocks(at: row2)
        let heightTwelveBlocks = row2Blocks.filter {
            $0.height > 11
        }
        if heightTwelveBlocks.count != 9 {
            return false
        }
        
        return true
    }
    
    public func charactersDidBoogie() -> Bool {
        let characters = existingCharacters(at: allPossibleCoordinates)
        var performedCommands = 0
        for character in characters {
            let actorCommands = commandQueue.completedCommands(for: character).count
            performedCommands += actorCommands
        }
    
        return performedCommands >= 15
        
        
    }
    

    
}
