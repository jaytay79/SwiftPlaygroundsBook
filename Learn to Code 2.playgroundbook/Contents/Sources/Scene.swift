//
//  Scene.swift
//
//  Copyright (c) 2016 Apple Inc. All Rights Reserved.
//

import SceneKit

/// Reports changes to the worlds state.
protocol SceneStateDelegate: class {
    func scene(_ scene: Scene, didEnterState: Scene.State)
}

extension Notification.Name {
    /// Indicates that the `Scene.state == .done`.
    static let scenePlaybackDidComplete = Notification.Name(rawValue: "ScenePlaybackDidComplete")
}

public final class Scene: NSObject {
    // MARK: Types
    
    enum State {
        /// The starting state of the scene before anything has been added.
        case initial
        
        /// The state after all inanimate elements have been placed.
        case built
        
        /// The state which rewinds the `commandQueue` in preparation for playback.
        case ready
        
        /// The state which starts running commands in the `commandQueue`.
        case run
        
        /// The final state after all commands have been run.
        case done
    }
    
    enum EffectsLevel: Int {
        case high, med, low
    }
    
    // MARK: Properties
    
    private let source: SCNSceneSource
    
    let gridWorld: GridWorld
    
    /// The queue which all commands are added to before being run.
    public var commandQueue: CommandQueue {
        return gridWorld.commandQueue
    }
    
    lazy var scnScene: SCNScene = {
        let scene: SCNScene
        do {
            scene = try self.source.scene()
        }
        catch {
            presentAlert(title: "Failed To Load Scene.", message: "\(error)")
            fatalError("Failed To Load Scene.\n\(error)")
        }
        
        // Remove the old grid node that exists in loaded scenes. 
        scene.rootNode.childNode(withName: GridNodeName, recursively: false)?.removeFromParentNode()
        scene.rootNode.addChildNode(self.gridWorld.grid.scnNode)
        
        // Give the `rootNode` a name for easy lookup.
        scene.rootNode.name = "rootNode"
        
        // Load the skybox. 
        scene.background.contents = Asset.texture(named: "zon_bg_skyBox_a_DIFF")
        
        self.positionCameraToFitGrid(around: scene.rootNode)
        self.adjustDirectionalLight(in: scene.rootNode)
        self.cleanupScene(scene)
        
        return scene
    }()
    
    var rootNode: SCNNode {
        return scnScene.rootNode
    }
    
    weak var delegate: SceneStateDelegate?
    
    ///  Actors operating within this scene.
    var actors: [Actor] {
        return gridWorld.grid.actors
    }
    
    /// The first actor (which is not an expert) in the scene.
    var mainActor: Actor? {
        return actors.first(where: { type(of: $0) == Actor.self })
    }
    
    /// The duration used when rewinding the scene.
    var resetDuration: TimeInterval = 0.0
    
    var state: State = .initial {
        didSet {
            let newState = state
            enterState(newState)
            delegate?.scene(self, didEnterState: newState)
        }
    }
    
    // Effect Nodes
    lazy var highEffectsNode: SCNNode? = self.rootNode.childNode(withName: "HIGH_QUALITY_FX", recursively: true)
    
    lazy var lowEffectsNode: SCNNode? = self.rootNode.childNode(withName: "LOW_QUALITY_FX", recursively: true)
    
    var directionLight: SCNLight? = nil
    
    var effectsLevel: EffectsLevel = .high {
        didSet {
            let med = EffectsLevel.med.rawValue
            highEffectsNode?.isHidden = effectsLevel != .high
            lowEffectsNode?.isHidden = effectsLevel.rawValue > med
            
            directionLight?.shadowMapSize = effectsLevel.rawValue >= med ? CGSize(width:  1024, height:  1024) : CGSize(width:  2048, height:  2048)
            directionLight?.gobo!.contents = effectsLevel.rawValue >= med ? Asset.texture(named: "blobShadow", fileExtension: "jpg") : nil
            
            // Destructive
            if effectsLevel == .low {
                rootNode.enumerateChildNodes { node, _ in
                    for system in node.particleSystems ?? [] {
                        node.removeParticleSystem(system)
                    }
                }
                
                scnScene.fogStartDistance = 0
                scnScene.fogEndDistance = 0
            }
        }
    }
    
    // MARK: Initialization
    
    public init(world: GridWorld) {
        gridWorld = world
        
        // Load template scene.
        let worldTemplatePath = Asset.Directory.templates.path + "WorldTemplate"
        let worldURL = Bundle.main.url(forResource: worldTemplatePath, withExtension: "scn")!
        source = SCNSceneSource(url: worldURL, options: nil)!
    }
    
    public init(source: SCNSceneSource) throws {
        self.source = source
        
        // Check for `GridNodeName` node.
        guard let baseGridNode = source.entry(withID: GridNodeName, ofType: SCNNode.self) else {
            throw GridLoadingError.missingGridNode(GridNodeName)
        }

        gridWorld = GridWorld(node: baseGridNode)
        
        super.init()
        
        // Ensure at least one tile node is contained in the scene as the floor node.
        guard !gridWorld.existingItems(ofType: Block.self, at: gridWorld.allPossibleCoordinates).isEmpty else {
            throw GridLoadingError.missingFloor("No nodes of with name `Block` were found.")
        }
        
        let cols = gridWorld.columnCount
        let rows = gridWorld.rowCount
        guard cols > 0 && rows > 0 else { throw GridLoadingError.invalidDimensions(cols, rows) }
    }
    
    /// Expects an ".scn" scene.
    public convenience init(named sceneName: String) throws {
        let path = Asset.Directory.scenes.path + sceneName
    
        guard
            let sceneURL = Bundle.main.url(forResource: path, withExtension: "scn"),
            let source = SCNSceneSource(url: sceneURL, options: nil) else {
                throw GridLoadingError.invalidSceneName(sceneName)
        }
        
        try self.init(source: source)
    }
    
    // MARK: Scene Adjustments
    
    func enterState(_ newState: State) {
        switch newState {
        case .initial:
            break
            
        case .built:
            // Never animate `built` steps.
            gridWorld.applyChanges() {
                gridWorld.verifyNodePositions()
            }
            
        case .ready:
            SCNTransaction.begin()
            SCNTransaction.animationDuration = resetDuration
            // Reset the state of the world for playback.
            commandQueue.rewind()
            SCNTransaction.commit()
            
            // Ensure the dimensions of the `gridWorld` are correct.
            gridWorld.calculateRowColumnCount()
            
        case .run:
            // Set all actors to drive commands through the central queue. 
            for actor in actors {
                actor.commandDriver = commandQueue
            }
            
            if commandQueue.isFinished {
                // If there are no commands, mark the scene as done.
                state = .done
            }
            else {
                DispatchQueue.main.asyncAfter(deadline: .now() + resetDuration) {
                    self.commandQueue.runMode = .continuous
                    self.commandQueue.runCommand(atIndex: 0)
                }
            }
            
        case .done:
            // Recalculate the dimensions of the world for any placed items.
            gridWorld.calculateRowColumnCount()
            
            NotificationCenter.default.post(name: .scenePlaybackDidComplete, object: self)
        }
    }
    
    func adjustDirectionalLight(in root: SCNNode) {
        guard let lightNode = root.childNode(withName: DirectionalLightName, recursively: true) else { return }
        
        var light: SCNLight?
        lightNode.enumerateHierarchy { node, stop in
            if let directional = node.light {
                light = directional
                stop.initialize(to: true)
            }
        }
    
        directionLight = light
        light?.orthographicScale = 10
        light?.shadowMapSize = CGSize(width:  2048, height:  2048)

        // Turn off shadows for scenery nodes.
        for node in root.childNodes where node != gridWorld.grid.scnNode {
            node.enumerateChildNodes { child, _ in
                child.castsShadow = false
            }
        }
    }
    
    func positionCameraToFitGrid(around node: SCNNode) {
        // Set up the camera.
        let cameraNode = node.childNode(withName: "camera", recursively: true)!
        let boundingNode = node.childNode(withName: "Scenery", recursively: true) ?? gridWorld.grid.scnNode
        
        var (_, sceneWidth) = boundingNode.boundingSphere
        // Expand so we make sure to get the whole thing with a bit of overlap.
        sceneWidth *= 2
        
        let dominateDimension = Float(max(gridWorld.rowCount, gridWorld.columnCount))
        sceneWidth = max(dominateDimension * 2.5, sceneWidth)
        guard sceneWidth.isFinite && sceneWidth > 0 else { return }
        
        let cameraDistance = Double(cameraNode.position.z)
        let halfSceneWidth = Double(sceneWidth / 2.0)
        let distanceToEdge = sqrt(cameraDistance * cameraDistance + halfSceneWidth * halfSceneWidth)
        let cos = cameraDistance / distanceToEdge
        let sin = halfSceneWidth / distanceToEdge
        let halfAngle = atan2(sin, cos)
        
        cameraNode.camera?.yFov = 2.0 * halfAngle * 180.0 / M_PI
    }
    
    /// Removes unnecessary adornments in scene file.
    func cleanupScene(_ scene: SCNScene) {
        let root = scene.rootNode
        
        let bokeh = root.childNode(withName: "bokeh particles", recursively: true)
        bokeh?.removeFromParentNode()
        
        let reflectionPlane = root.childNode(withName: "reflections", recursively: true)
        reflectionPlane?.removeFromParentNode()
        
        // Flatten scenery elements.
        func flattenSwap(node: SCNNode) {
            let flatNode = node.flattenedClone()
            flatNode.transform = node.transform
            node.parent?.addChildNode(flatNode)
            node.removeFromParentNode()
        }
        
        let sceneryNode = root.childNode(withName: "Scenery", recursively: false)
        let flattenableIdentifiers = [
            "",
//            "PROPS_BELOW",
//            "PROPS_ABOVE",
//            "ACTIVE_FLOOR"
        ]
        
        for id in flattenableIdentifiers {
            if let node = sceneryNode?.childNode(withName: id, recursively: true) {
                flattenSwap(node: node)
            }
        }
    }
    
    /// Reset's the scene in preparation for another run.
    func reset(duration: TimeInterval) {
        resetDuration = duration
        
        // Rewinds the commandQueue to correct all world state.
        state = .ready
        
        // Remove all commands from previous run.
        commandQueue.clear()
        
        // Clear any items no longer in the world from the previous run.
        // (Before receiving more commands).
        gridWorld.grid.removeItemsNotInWorld()
    }
}

extension Scene {
    /**
     The character picker should be useable when the `commandQueue` is finished
     (no pending commands remain) or the `commandQueue` is not being continually
     run.
     */
    func shouldShowPicker(from node: SCNNode) -> Bool {
        let commandQueueIsReady = commandQueue.isFinished == true || commandQueue.runMode == .randomAccess
        
        // Look for the first actor (not an expert).
        let rootNode = node.anscestorNode(named: "Actor") ?? SCNNode()
        let isMainActor = mainActor?.scnNode == rootNode
        
        // Filter out experts.
        let actorCount = actors.filter {
            return type(of: $0) == Actor.self
        }.count
        
        return commandQueueIsReady
            && isMainActor
            && actorCount == 1
    }
}
