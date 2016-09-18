//
//  StartMarker.swift
//
//  Copyright (c) 2016 Apple Inc. All Rights Reserved.
//
import SceneKit

public final class StartMarker: Item, NodeConstructible {
    
    // MARK: Static
    
    static let template: SCNNode = {
        let node = Asset.node(named: "zon_prop_startTile_c", in: .item(.startMarker))!
        // Slight offset to avoid z-fighting.
        node.position.y = 0.01
        return node
    }()
    
    // MARK: Item
    
    public static let identifier: WorldNodeIdentifier = .startMarker
    
    public weak var world: GridWorld?
    
    public let node: NodeWrapper
    
    public var id = Identifier.undefined
    
    /// The type of actor this startMarker is used for. 
    let type: ActorType
    
    init(type: ActorType) {
        self.type = type
        
        node = NodeWrapper(identifier: .startMarker)
    }
    
    init?(node: SCNNode) {
        guard node.identifier == .startMarker
            && node.identifierComponents.count >= 2 else { return nil }
        guard let type = ActorType(rawValue: node.identifierComponents[1]) else { return nil }
        
        self.type = type
        
        self.node = NodeWrapper(node)
    }
    
    public func loadGeometry() {
        guard scnNode.childNodes.isEmpty else { return }
        scnNode.addChildNode(StartMarker.template.clone())
    }
}

import PlaygroundSupport

extension StartMarker: MessageConstructor {
    
    // MARK: MessageConstructor
    
    var message: PlaygroundValue {
        return .array(baseMessage + stateInfo)
    }
    
    var stateInfo: [PlaygroundValue] {
        return [.string(type.rawValue)]
    }
}
