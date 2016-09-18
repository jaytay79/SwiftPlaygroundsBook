//
//  SceneController+Controls.swift
//
//  Copyright (c) 2016 Apple Inc. All Rights Reserved.
//

import PlaygroundSupport
import SceneKit

/// An indication that the conforming type functions as a control element in the 
/// `SceneController`.
protocol WorldControl {}

// Retroactively model views within the `SceneController` that function as controls
// as `WorldViewControl`s.
extension UIButton: WorldControl {}
extension GoalCounter: WorldControl {}

// Magic color
public let AppTintColor = UIColor(red: 254.0/255.0 as CGFloat, green: 75.0/255.0, blue: 38.0/255.0, alpha: 1.0)

public extension UIColor {
    func colorWithRelativeBrightness(_ relativeBrighness: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        brightness *= relativeBrighness
        return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
    }
}

extension SceneController: PlaygroundLiveViewSafeAreaContainer {
    
    // MARK: Overlay view
    private class OverlayView: UIView, WorldControl {
        
        fileprivate override init(frame: CGRect) {
            let blurEffect = UIBlurEffect(style: .extraLight)
            let blurEffectView = UIVisualEffectView(effect: blurEffect)
            blurEffectView.layer.cornerRadius = 22
            blurEffectView.clipsToBounds = true
            blurEffectView.translatesAutoresizingMaskIntoConstraints = true
            blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            
            super.init(frame: frame)
            
            addSubview(blurEffectView)
            blurEffectView.frame = bounds
            
            let whiteOverBlurView = UIView()
            whiteOverBlurView.translatesAutoresizingMaskIntoConstraints = true
            whiteOverBlurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(whiteOverBlurView)
            whiteOverBlurView.frame = bounds
        }
        
        private required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    // MARK: Layout constants
    
    struct ControlLayout {
        static let verticalOffset: CGFloat = 18
        static let height: CGFloat = 44
        static let width: CGFloat = 44
        static let edgeOffset: CGFloat = 20
    }
    
    // MARK: Buttons
    
    func addControlButtons() {
        // Speed button containing view
        let containingView = OverlayView(frame: CGRect.zero)
        containingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containingView)
        
        // Speed button
        
        speedButton.translatesAutoresizingMaskIntoConstraints = true
        speedButton.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        speedButton.setTitleColor(AppTintColor, for: [])
        speedButton.setTitleColor(AppTintColor.colorWithRelativeBrightness(0.6), for: .highlighted)
        
        speedButton.addTarget(self, action: #selector(adjustSpeedAction(_:)), for: .touchUpInside)
        
        containingView.addSubview(speedButton)
        
        
        NSLayoutConstraint.activate([
            containingView.topAnchor.constraint(equalTo: liveViewSafeAreaGuide.topAnchor, constant: ControlLayout.verticalOffset),
            containingView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -ControlLayout.edgeOffset),
            containingView.heightAnchor.constraint(equalToConstant: ControlLayout.height),
            containingView.widthAnchor.constraint(equalToConstant: ControlLayout.width)
        ])
    }
    
    // MARK: Actions
    
    func adjustSpeedAction(_ button: UIButton) {
        // Increment the speed index.
        // This will set the appropriate speed for both the actor and the world, 
        // and update the button image.
        speedIndex += 1
    }
    
    /// A helper method to adjust button image for index.
    func setSpeedImage(for button: UIButton) {
        let speedLabels = ["1x", "2x", "4x"]
        
        button.setTitle(speedLabels[speedIndex], for: [])
        button.bounds = CGRect(x: 0, y: 0, width: 44, height: 44)
        
        button.accessibilityLabel = "Speed " + speedLabels[speedIndex]
    }
    
    // MARK: Goal Counter
    
    func addGoalCounter() {
        view.addSubview(goalCounter)
        goalCounter.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            goalCounter.topAnchor.constraint(equalTo: liveViewSafeAreaGuide.topAnchor, constant: ControlLayout.verticalOffset),
            goalCounter.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            goalCounter.heightAnchor.constraint(equalToConstant: ControlLayout.height),
        ])
    }
    
    func updateCounterLabelTotals() {
        let world = scene.gridWorld
        
        switch world.successCriteria {
        case .all:
            let existingGoals = world.existingGoals()
            let collectedGems = scene.commandQueue.collectedGemCount()
            
            goalCounter.totalGemCount = existingGoals.gems.count + collectedGems
            goalCounter.totalSwitchCount = existingGoals.switches.count
        
        case let .count(collectedGems: gems, openSwitches: switches):
            goalCounter.totalGemCount = gems
            goalCounter.totalSwitchCount = switches
            
        case .pageSpecific(_):
            break
        }
    }
    
    func updateCounterLabelRunningCounts() {
        goalCounter.gemCount = scene.commandQueue.collectedGemCount()
        
        let switches = scene.gridWorld.existingItems(ofType: Switch.self)
        goalCounter.switchCount = switches.reduce(0) { onCount, item in
            return onCount + (item.isOn ? 1 : 0)
        }
    }
}

extension SceneController {
    // MARK: Touch Gestures 
    
    func registerForTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapAction(_:)))
        view.addGestureRecognizer(tapGesture)
    }
    
    func tapAction(_ recognizer: UITapGestureRecognizer) {
        let p = recognizer.location(in: scnView)
        let hitResults = scnView.hitTest(p, options: [:])
        
        guard let closestHit = hitResults.first else { return }
        
        if scene.shouldShowPicker(from: closestHit.node), let actor = scene.mainActor {
            // Hit actor node, display the characterPicker.
            characterPicker.delegate = self
            characterPicker.show(from: actor)
            
            cameraController?.shouldSuppressGestureControl = true
            showControls(false)
        }
        else {
            // Display coordinate marker.
            overlay?.displayMarkerFor(hit: closestHit)
        }
    }
}

extension SceneController: CharacterPickerDelegate {
    // MARK: CharacterPickerDelegate
    
    func characterPicker(_ picker: CharacterPickerController, willDismissPicking: ActorType) {
        //
    }
    
    func characterPicker(_ picker: CharacterPickerController, didDismissPicking: ActorType) {
        showControls(true)
        cameraController?.shouldSuppressGestureControl = false
        
        // Create a fresh character picker. 
        characterPicker = CharacterPickerController(view: scnView)
    }
}
