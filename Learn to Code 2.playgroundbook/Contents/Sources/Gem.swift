//
//  Gem.swift
//
//  Copyright (c) 2016 Apple Inc. All Rights Reserved.
//
import SceneKit

public final class Gem: Item, LocationConstructible, NodeConstructible {
    
    // MARK: Static
    
    static let moveKey = "MoveGem"
    static let spinKey = "Spin"
    
    static var template = Asset.neutralPose(in: .item(.item), fileExtension: "scn")!
    
    static var popEmitter: SCNNode = {
        let node = Asset.node(named: "PopAnimation", in: .item(.item), fileExtension: "scn")!
        node.position.y += 0.2
        
        return node
    }()
    
    // MARK: Item
    
    public static let identifier: WorldNodeIdentifier = .item
    
    public weak var world: GridWorld?
    
    public let node: NodeWrapper
    
    public var id = Identifier.undefined
    
    var animationNode: SCNNode? {
        return scnNode.childNodes.first
    }
    
    // MARK: Initialization
    
    public init() {
        node = NodeWrapper(identifier: .item)
    }
    
    init?(node: SCNNode) {
        guard node.identifier == .item else { return nil }
        self.node = NodeWrapper(node)
    }
    
    /// Animates the removal of the gem from the world.
    func collect(withDuration animationDuration: TimeInterval) {
        guard isInWorld else {
            log(message: "Attempting to collect a gem \(self) which is not in a world.")
            return
        }
        
        // Remove the gem from the world immediately.
        world = nil
        
        let halfDuration = animationDuration / 2
        let wait = SCNAction.wait(duration: halfDuration)
        let scale = SCNAction.scale(to: 0.0, duration: halfDuration / 2)
        let wait2 = SCNAction.wait(duration: halfDuration / 2)

        let emitterNode = Gem.popEmitter
        let emitterDuration = CGFloat(halfDuration)

        let system = emitterNode.particleSystems![0]
        system.emissionDuration = emitterDuration
        system.birthRate = emitterDuration
        system.particleLifeSpan = emitterDuration
        
        scnNode.addChildNode(emitterNode)
        
        animationNode?.runAction(.sequence([wait, scale, wait2])) { [unowned self] _ in
            self.scnNode.removeFromParentNode()
            
            // Restore the node.
            emitterNode.removeFromParentNode()
            self.animationNode?.scale = SCNVector3Make(1, 1, 1)
        }
    }
    
    func move(up: Bool, withDuration duration: TimeInterval) {
        guard let world = world else { return }

        // Ensure starting position of the gem is correct.
        let height = world.nodeHeight(at: coordinate)
        let startHeight = up ? height : height + WorldConfiguration.gemDisplacement
        let endHeight = up ? height + WorldConfiguration.gemDisplacement : height
        
        guard !duration.isLessThanOrEqualTo(0.0) else {
            // If the `duration` is <= 0, move the gem immediately and remove existing animations.
            scnNode.removeAction(forKey: Gem.moveKey)
            position.y = endHeight
            return
        }
        
        let deltaY = CGFloat(endHeight - startHeight)
        let duration = duration / 1.5
        let move = SCNAction.moveBy(x: 0, y: deltaY, z: 0, duration: duration)
        
        let bounceDelta: CGFloat = up ? 0.1 : -0.1
        let bounceDuration = duration / 6
        let bounce1 = SCNAction.moveBy(x: 0, y: bounceDelta, z: 0, duration: bounceDuration)
        let bounce2 = SCNAction.moveBy(x: 0, y: -bounceDelta, z: 0, duration: bounceDuration)
        bounce2.timingMode = up ? .easeOut : .easeIn
        
        let delay = up ? 0 : duration / 6
        scnNode.runAction(.sequence([.wait(duration: delay), move, bounce1, bounce2]), forKey: Gem.moveKey)
    }
    
    public func loadGeometry() {
        guard scnNode.childNodes.isEmpty else { return }
        let gem = Gem.template.clone()
        scnNode.addChildNode(gem)
        
        scnNode.addAnimation(.spinAnimation(), forKey: Gem.spinKey)
    }
    
    // MARK: Animations
    
    public func reset() {
        scnNode.opacity = 1.0
        scnNode.scale = SCNVector3(x: 1, y: 1, z: 1)
        
        animationNode?.scale = SCNVector3Make(1, 1, 1)
        animationNode?.removeAllActions()
        
        Gem.popEmitter.removeFromParentNode()
    }
    
    public func placeAction(withDuration duration: TimeInterval) -> SCNAction {
        scnNode.scale = SCNVector3Zero
        scnNode.opacity = 0.0
        
        return .group([.scale(to: 1.0, duration: duration), .fadeIn(duration: duration)])
    }
}

import PlaygroundSupport

extension Gem: MessageConstructor {
    
    // MARK: MessageConstructor
    
    var message: PlaygroundValue {
        return .array(baseMessage)
    }
}

