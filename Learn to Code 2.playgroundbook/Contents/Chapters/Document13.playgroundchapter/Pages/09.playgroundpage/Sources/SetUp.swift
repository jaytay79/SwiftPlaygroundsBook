// 
//  SetUp.swift
//
//  Copyright (c) 2016 Apple Inc. All Rights Reserved.
//
import Foundation

// MARK: Globals
public let world = GridWorld(columns: 8, rows: 8)

public func playgroundPrologue() {
    Display.coordinateMarkers = true
    // Must be called in `playgroundPrologue()` to update with the current page contents.
    registerAssessment(world, assessment: assessmentPoint)
    
    world.successCriteria = .all
    
    //// ----
    // Any items added or removed after this call will be animated.
    finalizeWorldBuilding(for: world)
    //// ----
}

public func presentWorld() {
    setUpLiveViewWith(world)
}

// MARK: Epilogue
    
public func playgroundEpilogue(block: @escaping (GridWorld) -> Swift.Void) {
    // Call it once to simulate a normal run of the world.
    block(world)

    let handler = assessment(world.randomizedLandscape(worldConfig: block))
    world.successCriteria = .pageSpecific(handler)
    
    sendCommands(for: world)
}
