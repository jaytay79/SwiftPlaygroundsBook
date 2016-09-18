//
//  SceneController+StateChange.swift
//
//  Copyright (c) 2016 Apple Inc. All Rights Reserved.
//
import SceneKit

/// Used to mark actions that are run as part of scene completion.
/// These actions should all be mutually exclusive.

extension SceneController: SceneStateDelegate {
    // MARK: GridWorldStateDelegate
    
    func scene(_ scene: Scene, didEnterState state: Scene.State) {
        switch state {
        case .ready:
            // Ensure accessibility info is up to date.
            setVoiceOverForCurrentStatus()
            setCommandSpeedForSpeedIndex()
            
        case .run:
            updateCounterLabelRunningCounts()
            updateCounterLabelTotals()
            
        case .done:
            guard !isDisplayingEndState else { return }
            isDisplayingEndState = true
            
            OperationQueue.main.addOperation {
                self.sceneCompleted(scene: scene)
            }
            
        default:
            break
        }
    }
    
    // MARK: End State
    
    func sceneCompleted(scene: Scene) {
        // Determine if there is anything interesting to show.
        let hasCommands = !scene.commandQueue.completedCommands(for: scene.mainActor).isEmpty
        
        guard hasCommands else {
            for actor in scene.actors {
                actor.startContinuousIdle()
            }
            return
        }
        
        if isPassingRun {
            showSuccessState()
        }
        else {
            showDefeatedState()
        }
    }
    
    // MARK: Animations
    
    func showDefeatedState() {
        // Show the character defeated.
        for actor in scene.actors {
            actor.idleQueue.start(initialAnimations: [.defeat])
        }
        
        let defeatMessage = "The level is incomplete, Byte looks sad. Tap the hint button for more details."
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, defeatMessage)
    }

    func showSuccessState() {
        guard let mainActor = scene.mainActor else { return }

        // Disable gesture recognizers while camera pans.
        view.gesturesEnabled = false
        
        let (duration, _) = cameraController?.performFlyover(toFace: mainActor.rotation) ?? (0, 0)
        
        for actor in scene.actors {
            let successAnimations: [EventGroup] = [.celebration, .victory, .happyIdle]
            
            let shortenedDuration = duration * 0.7
            DispatchQueue.main.asyncAfter(deadline: .now() + shortenedDuration) {
                actor.idleQueue.start(initialAnimations: successAnimations)
            }
        }
        
        let cameraWait = SCNAction.wait(duration: duration)
        scene.rootNode.runAction(cameraWait) { [unowned self] in
            // Re-enable gestures after camera pan completes.
            self.view.gesturesEnabled = true
        }
    }
}
