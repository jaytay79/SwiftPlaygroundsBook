//
//  CharacterPickerController.swift
//
//  Copyright (c) 2016 Apple Inc. All Rights Reserved.
//

import UIKit
import SceneKit
import SpriteKit

let focalBlurRadiusMax = CGFloat(20)
let focalDistanceMax   = CGFloat(0.2)

protocol CharacterPickerDelegate: class {
    func characterPicker(_ picker: CharacterPickerController, willDismissPicking: ActorType)
    func characterPicker(_ picker: CharacterPickerController, didDismissPicking: ActorType)
}

public class CharacterPickerController {
    // MARK: Types
    
    enum State: Int {
        case inactive
        case active
        case animatingToPicker
        case animatingToWorld
    }
    
    static let fadeDuration = 0.35
    
    // MARK: Properties
    
    weak var scnView: SCNView?
    weak var delegate: CharacterPickerDelegate?
    
    var overlayView = SCNView()
    
    var state: State = .inactive
    
    var isVisible: Bool {
        return state == .active
    }
    
    let bluActor = Actor(name: .blu)
    let byteActor = Actor(name: .byte)
    let hopperActor = Actor(name: .hopper)
    var pickerActors: [Actor] {
        return [
            bluActor,
            byteActor,
            hopperActor
        ]
    }
    
    var originalActorTransform: SCNMatrix4?
    var originalWorldActor: Actor?

    // MARK: Initialization
    
    init(view: SCNView) {
        self.scnView = view
    }
    
    /// Present the characterPicker. Pulls the actor from the world.
    func show(from actor: Actor) {
        guard state == .inactive,
            let leaveAnimation = AssetCache.cache(forType: actor.type).animation(for: .leave) else { return }
        
        // Use a speed of 1x for character picker animations.
        Actor.commandSpeed = 1
        
        state = .animatingToPicker
        originalWorldActor = actor
        originalActorTransform = actor.scnNode.transform
        actor.reset()
        
        // Reset the existing `pickerActors`. (They may have been recycled).
        for actor in pickerActors {
            actor.reset()
            actor.isInCharacterPicker = true
        }
        
        leaveAnimation.fadeInDuration = WorldConfiguration.Actor.animationFadeDuration
        actor.scnNode.runAction(.animate(with: leaveAnimation), forKey: "WorldLeaveAction") { [unowned self] in
            guard self.state == .animatingToPicker else { return }
            actor.scnNode.isHidden = true
            
            self.triggerDepthOfField(intro: true) { [unowned self] _ in
                self.loadAndDisplayCharacters()
            }
        }
    }
    
    /// Dismiss the character picker without a new actor choice.
    /// Returns the `originalWorldActor` to a continuous idle if `toIdle` is true.
    func dismiss(toIdle: Bool = true) {
        guard state == .active || state == .animatingToPicker else { return }
        
        self.originalWorldActor?.reset()

        UIView.animate(withDuration: CharacterPickerController.fadeDuration, animations: {
            self.overlayView.alpha = 0
            
        }, completion: { _ in
            guard let actor = self.originalWorldActor else { return }
            
            actor.scnNode.isHidden = false
            if toIdle {
                actor.startContinuousIdle()
            }
            
            self.cleanUpOnExit()
            
            self.triggerDepthOfField(intro: false) { _ in
                self.state = .inactive
                self.delegate?.characterPicker(self, didDismissPicking: actor.type)
            }
        })
    }
    
    func triggerDepthOfField(intro: Bool, completion: FinishedBlock? = nil) {
        guard let cameraNode = scnView?.scene?.rootNode.childNode(withName: "camera", recursively: true),
            let camera = cameraNode.camera else { return }
        
        camera.focalDistance = intro ? focalDistanceMax : 0
        camera.focalBlurRadius = intro ? focalBlurRadiusMax : 0
        camera.focalSize = 2
        
        let animation = CABasicAnimation(keyPath: "camera.focalBlurRadius")
        animation.fromValue = intro ? 0 : focalBlurRadiusMax
        animation.toValue = intro ? focalBlurRadiusMax : 0
        animation.fillMode = kCAFillModeForwards
        
        animation.stopCompletionBlock = { finished in
            DispatchQueue.main.async {
                completion?(finished)
            }
        }
        cameraNode.addAnimation(animation, forKey: "depthOfField")
    }
    
    func cleanUpOnExit() {
        overlayView.scene = nil
        overlayView.removeFromSuperview()
    }
    
    // MARK: Gesture Recognizers
    
    dynamic func selectCharacter(_ recognizer: UITapGestureRecognizer) {
        guard state == .active else { return }
        
        let p = recognizer.location(in: overlayView)
        let hitResults = overlayView.hitTest(p, options: nil)
        
        // Compare the `scnNode`s to determine which actor was hit.
        guard let closestHit = hitResults.first,
            let hitActorNode = closestHit.node.anscestorNode(named: "Actor"),
            let selectedActor = pickerActors.first(where: { $0.scnNode == hitActorNode }) else {
            
            let originalType = originalWorldActor?.type ?? ActorType.loadDefault()
            self.delegate?.characterPicker(self, willDismissPicking: originalType)

            // We didn't hit an actor, so let's fade the picker away.
            dismiss()
            
            return
        }
        
        // Animate selected character off picker.
        state = .animatingToWorld

        selectedActor.stopContinuousIdle()
        selectedActor.reset()

        let type = selectedActor.type
        
        // Persist character choice.
        type.saveAsDefault()
        self.delegate?.characterPicker(self, willDismissPicking: type)
        
        if let leaveAnimation = AssetCache.cache(forType: selectedActor.type).animation(for: .leave) {
            leaveAnimation.fadeInDuration = WorldConfiguration.Actor.animationFadeDuration
            
            leaveAnimation.stopCompletionBlock = { _ in
                leaveAnimation.stopCompletionBlock = nil
                
                selectedActor.scnNode.isHidden = true
                selectedActor.reset()
                self.originalWorldActor?.reset()
                
                UIView.animate(withDuration: CharacterPickerController.fadeDuration, animations: {
                    self.overlayView.alpha = 0
                })
                
                self.triggerDepthOfField(intro: false) { _ in
                    self.jumpActorBackIntoWorld(actor: selectedActor)
                }
            }
            selectedActor.scnNode.addAnimation(leaveAnimation, forKey: "leaveAnimation")
        }
    }

    /// Swap the actor into the `originalActor`, applying the "WorldArriveAnimation" to the
    /// shell node of the original actor.
    func jumpActorBackIntoWorld(actor: Actor) {
        self.swapMainActor(for: actor)

        // Kick off world arrive animation.
        guard let originalActor = self.originalWorldActor else { fatalError("Failed to find original world actor.") }
        let worldArriveAnimation = AssetCache.cache(forType: originalActor.type).animation(for: .arrive)!
        
        worldArriveAnimation.stopCompletionBlock = { _ in
            worldArriveAnimation.stopCompletionBlock = nil            
            originalActor.startContinuousIdle()
            
            DispatchQueue.main.async {
                self.delegate?.characterPicker(self, didDismissPicking: originalActor.type)
            }

            self.state = .inactive
            self.cleanUpOnExit()
        }
        originalActor.scnNode.addAnimation(worldArriveAnimation, forKey: "WorldArriveAnimation")
    }
    
    private func swapMainActor(for actor: Actor) {
        guard let originalActor = originalWorldActor else { return }
        originalActor.scnNode.isHidden = false
        originalActor.scnNode.transform = self.originalActorTransform!
        
        actor.reset()
        originalActor.reset()
        originalActor.swap(with: actor)
    }
    
    // MARK: Arriving
    
    private func loadAndDisplayCharacters() {
        guard let mainSCNView = scnView else { return }
        
        // Setup overlay view & constraints
        overlayView.alpha = 0
        mainSCNView.addSubview(overlayView)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(selectCharacter(_:)))
        overlayView.gestureRecognizers = [tapGesture]

        overlayView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            overlayView.centerXAnchor.constraint(equalTo: mainSCNView.centerXAnchor),
            overlayView.centerYAnchor.constraint(equalTo: mainSCNView.centerYAnchor),
            overlayView.widthAnchor.constraint(equalTo: mainSCNView.widthAnchor),
            overlayView.heightAnchor.constraint(equalTo: mainSCNView.heightAnchor)
        ])
        
        // Setup opacity fade in animation on overlayView.
        UIView.animate(withDuration: CharacterPickerController.fadeDuration) {
            self.overlayView.alpha = 1
        }
        
        /* Setup overlay scene */
        let overlayScene = SCNScene()
        overlayView.scene = overlayScene
        overlayScene.background.contents = UIColor.black.withAlphaComponent(0.5)
        
        /* Setup camera for overlay scene */
        let overlayCamera = SCNCamera()
        let overlayCameraNode = SCNNode()
        overlayCameraNode.camera = overlayCamera
        overlayCameraNode.position = SCNVector3(0, 1, 0.5)
        
        // ~15º offset
        overlayCameraNode.eulerAngles = SCNVector3(-0.261799, 0, 0)
        overlayScene.rootNode.addChildNode(overlayCameraNode)
        
        positionPickerCharacters(in: overlayScene)
        
        // Copy lights from main scene to the picker scene.
        let originalLight = mainSCNView.scene?.rootNode.childNode(withName: "Lights", recursively: true)
        if let lightNode = originalLight?.clone() {
            lightNode.position = SCNVector3(0, 1, 1)
            overlayScene.rootNode.addChildNode(lightNode)
        }
        
        // Hide the actor who will "arrive" in the scene.
        for actor in pickerActors where actor.type == originalWorldActor?.type {
            actor.scnNode.isHidden = true
        }
        
        // Prepare all the necessary items in the new scene.
        overlayView.prepare([overlayScene]) { [unowned self] _ in
            DispatchQueue.main.async {
                // Trigger the animations.
                self.playCharacterArriveArriveAnimations()
            }
        }
    }
    
    private func positionPickerCharacters(in scene: SCNScene) {
        var actorXOffset: CGFloat = -0.75
        
        for actor in pickerActors {
            actor.loadGeometry()
            
            let actualNode = actor.scnNode
            actualNode.position = SCNVector3(actorXOffset, -1, -2)
            actualNode.scale = SCNVector3(0.5, 0.5, 0.5)
            actorXOffset += 0.75
            
            scene.rootNode.addChildNode(actualNode)
        }
    }
    
    private func playCharacterArriveArriveAnimations() {
        guard let originalActor = originalWorldActor else { return }

        // Setup animations for the character to arrive in the picker, and the reactions the other two actors.
        let arriving: ActorEvent
        let firstReaction: ActorEvent
        let secondReaction: ActorEvent
        
        switch originalActor.type {
        case .byte:
            arriving = ActorEvent(actor: byteActor, event: .arrive)
            firstReaction = ActorEvent(actor: bluActor, event: .pickerReactLeft)
            secondReaction = ActorEvent(actor: hopperActor, event: .pickerReactRight)
            
        case .blu:
            arriving = ActorEvent(actor: bluActor, event: .arrive)
            firstReaction = ActorEvent(actor: byteActor, event: .pickerReactRight)
            secondReaction = ActorEvent(actor: hopperActor, event: .pickerReactRight)
            
        case .hopper:
            arriving = ActorEvent(actor: hopperActor, event: .arrive)
            firstReaction = ActorEvent(actor: byteActor, event: .pickerReactLeft)
            secondReaction = ActorEvent(actor: bluActor, event: .pickerReactLeft)
            
        case .expert:
            fatalError("Found `Expert` in the character picker.")
        }
        
        // Arriving
        arriving.animation?.startCompletionBlock = {
            arriving.actor.scnNode.isHidden = false
        }
        
        arriving.animation?.stopCompletionBlock = { finished in
            DispatchQueue.main.async {
                // Mark the state as `.active` after the arrival animation has finished.
                self.state = .active
            }
            guard finished else { return }
            arriving.actor.startContinuousIdle()
        }
        
        arriving.runAnimation(forKey: "ArriveAnimation")
        
        // First
        firstReaction.animation?.stopCompletionBlock = { finished in
            guard finished else { return }
            firstReaction.actor.startContinuousIdle()
        }
        firstReaction.runAnimation(forKey: "FirstActorReaction")
        
        // Second
        secondReaction.animation?.stopCompletionBlock = { finished in
            guard finished else { return }
            secondReaction.actor.startContinuousIdle()
        }
        secondReaction.runAnimation(forKey: "SecondActorReaction")
    }
}

// MARK: ActorEvent

private final class ActorEvent {
    let actor: Actor
    let event: EventGroup
    
    lazy var animation: CAAnimation? = AssetCache.cache(forType: self.actor.type).animation(for: self.event)
    
    init(actor: Actor, event: EventGroup) {
        self.actor = actor
        self.event = event
    }
    
    func runAnimation(forKey key: String) {
        guard let animation = animation else { return }
        actor.scnNode.addAnimation(animation, forKey: key)
    }
}
