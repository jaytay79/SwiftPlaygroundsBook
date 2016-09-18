//
//  _LiveViewConfiguration.swift
//
//  Copyright (c) 2016 Apple Inc. All Rights Reserved.
//

import PlaygroundSupport

// MARK: Scene Loading

/// A global reference to the loaded scene.
private var loadedScene: Scene? = nil
public func loadGridWorld(named name: String) -> GridWorld {
    do {
        loadedScene = try Scene(named: name)
    }
    catch {
        presentAlert(title: "Failed To Load `\(name)`", message: "\(error)")
        return GridWorld(columns: 0, rows: 0)
    }
    
    return loadedScene!.gridWorld
}

// MARK: Scene Presentation

public func setUpLiveViewWith(_ gridWorld: GridWorld) {
    // Attempt to use the loaded scene or create one from the world.
    let scene = loadedScene ?? Scene(world: gridWorld)
    
    // At this point the world is fully built.
    scene.state = .built
    
    // Assign the liveView.
    let sceneController = SceneController(scene: scene)
    PlaygroundPage.current.liveView = sceneController
}

/// Used to present the world as the `currentPage`'s liveView.
public func startPlayback() {
    guard let sceneController = PlaygroundPage.current.liveView as? SceneController else {
        fatalError("The liveView has not been assigned a `SceneController`")
    }
    
    // Start playing the scene.
    sceneController.startPlayback()
}

/**
 Marks the end of unanimated world building, collapsing any placement commands 
 provided in the `collapsingCommands` closure, before removing `RandomItems`.
*/
public func finalizeWorldBuilding(for world: GridWorld, collapsingCommands: (() -> Void)? = nil) {
    // Animate any additional world elements that are added or removed.
    world.isAnimated = true
    
    let queue = world.commandQueue
    
    // Start after the current command.
    let startIndex = queue.isEmpty ? 0 : queue.endIndex + 1
    collapsingCommands?()
    let endIndex = queue.endIndex
    
    if startIndex < endIndex {
        queue.collapsePlacementCommands(in: startIndex..<endIndex)
    }
    
    // Add commands to remove the random nodes after the world is built.
    world.removeRandomNodes()
}
