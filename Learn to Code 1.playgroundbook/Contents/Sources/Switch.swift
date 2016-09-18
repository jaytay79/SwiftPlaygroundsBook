//
//  Switch.swift
//
//  Copyright (c) 2016 Apple Inc. All Rights Reserved.
//
import SceneKit

public final class Switch: Item, LocationConstructible, NodeConstructible {
    // MARK: Static
    
    static var directory: Asset.Directory {
        return .item(identifier)
    }

    static let turnOnAnimation = Asset.animation(named: "SwitchOn", in: directory)!
    
    static let turnOffAnimation = Asset.animation(named: "SwitchOff", in: directory)!
    
    // MARK: Item
    
    public static let identifier: WorldNodeIdentifier = .switch
    
    public weak var world: GridWorld?
    
    public let node: NodeWrapper
    
    public var id = Identifier.undefined
    
    /// Private state to allow updating the switch without animation. 
    /// @see `setState(on:animated:)`
    fileprivate var _isOn = false
    
    /// The state of the Switch.
    public var isOn: Bool {
        get {
            return _isOn
        }
        set {
            guard newValue != _isOn else { return }
            _isOn  = newValue
            
            if world?.isAnimated == true {
                let controller = Controller(identifier: id, kind: .toggle, state: isOn)
                world?.add(action: .control(controller))
            }
            else {
                setState(isOn, animated: false)
            }
        }
    }
    
    fileprivate let onKey = "Switch-On"
    fileprivate let offKey = "Switch-Off"
    
    fileprivate var animationNode: SCNNode? {
        return scnNode.childNode(withName: "CHARACTER_Switch", recursively: true)
    }
    
    private var lightNode: SCNNode? {
        return scnNode.childNode(withName: "pointLight1", recursively: true)
    }
    
    public convenience init(open: Bool = false) {
        self.init()
        isOn = open
    }
    
    public init() {
        node = NodeWrapper(identifier: .switch)
    }
    
    init?(node: SCNNode) {
        guard let identifier = node.identifier, identifier == .switch else { return nil }
        self.node = NodeWrapper(node)
    }
    
    public func toggle() {
        isOn = !isOn
    }

    public func loadGeometry() {
        guard scnNode.childNodes.isEmpty else { return }
        let firstChild = Asset.neutralPose(in: .item(.switch))!
        firstChild.position.y = 0.02
        
        firstChild.enumerateHierarchy { node, _ in
            node.castsShadow = false
        }
        
        // Add a random rotation (so all Switches don't look the same).
        firstChild.rotation = SCNVector4(x: 0, y: 1, z: 0, w: SCNFloat(randomInt(from: 0, to: 40) % 4) * π / 2)
        
        scnNode.addChildNode(firstChild)
        
        // Warm up the `Switch` animations. 
        let _ = Switch.turnOnAnimation
        let _ = Switch.turnOffAnimation
        
        // Apply the animation now that the node has loaded.
        setState(isOn, animated: false)
        lightNode?.light?.categoryBitMask = WorldConfiguration.characterLightBitMask
    }
}

extension Switch: Controllable {
    // MARK: Controllable
    
    @discardableResult
    func setState(_ state: Bool, animated: Bool) -> TimeInterval {
        // Update the state of the switch.
        _isOn = state
        
        // 1000 so that the state change does not appear animated,
        // but we need the correct NeutralPose.
        let speed = animated ? Actor.commandSpeed : 1000
        
        let animation: CAAnimation
        if state {
            animation = Switch.turnOnAnimation
            animation.speed = speed
            animationNode?.addAnimation(animation, forKey: onKey)
        }
        else {
            animation = Switch.turnOffAnimation
            animation.speed = speed
            animationNode?.addAnimation(animation, forKey: offKey)
        }
        
        return animation.duration / Double(animation.speed)
    }
}

import PlaygroundSupport

extension Switch: MessageConstructor {

    // MARK: MessageConstructor
    
    var message: PlaygroundValue {
        return .array(baseMessage + stateInfo)
    }
    
    var stateInfo: [PlaygroundValue] {
        return [.boolean(isOn)]
    }
}
