//
//  AccessibilityComponent.swift
//
//  Copyright (c) 2016 Apple Inc. All Rights Reserved.
//

import AVFoundation

class AccessibilityComponent: NSObject, ActorComponent, AVSpeechSynthesizerDelegate {
    // MARK: Properties
    
    unowned let actor: Actor
    
    let synthesizer = AVSpeechSynthesizer()
    
    init(actor: Actor) {
        self.actor = actor
    }
    
    // MARK: Performer
    
    func perform(_ command: Action) -> Bool {
        // Nothing should be reported when playing the default animation.
        guard command.event != .default else { return false }
        
        // Adjust the speed to a resonable rate based on the requested `commandSpeed`
        let speedOffSet = (0.25 * (Actor.commandSpeed - 1 ))
        
        /// Speak the command.
        let utterance = AVSpeechUtterance(string:  "\(actor.speakableName) " + speakableDescription(for: command) + ".")
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate + speedOffSet
        
        synthesizer.delegate = self
        synthesizer.speak(utterance)
        
        return true
    }
    
    func cancel(_: Action) {
        synthesizer.stopSpeaking(at: .word)
    }
    
    // MARK: AVSpeechSynthesizerDelegate
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Mark this component as finished when speech is complete.
        actor.performerFinished(self)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        actor.performerFinished(self)
    }
    
    // MARK: Command speakableDescription
    
    func speakableDescription(for action: Action) -> String {
        switch action {
        case let .move(displace, type):
            let to = displace.to
            let from = displace.from
            let typeDesc = type.speakableDescription
            
            let prefix: String
            if from.y.isClose(to: to.y) {
                prefix = "\(typeDesc) to "
            }
            else {
                let ascending = from.y < to.y
                let newHeight = actor.height + (ascending ? 1 : -1)
                prefix = "\(typeDesc) \(ascending ? "up" : "down") to height \(newHeight) "
            }

            return prefix + Coordinate(to).description
            
        case let .turn(displace, clkwise):
            let turnDirection = clkwise ? "right" : "left"
            let facingDirection = Direction(radians: displace.to).rawValue
            return "turned " + turnDirection + ", now facing " + facingDirection
            
        case .add(let ids):
            guard let world = actor.world, !ids.isEmpty else { return "" }
            let item = world.item(forID: ids[0])!
            
            return "placed node at " + item.coordinate.description
            
        case .remove(let ids):
            guard let world = actor.world, !ids.isEmpty else { return "" }
            let item = world.item(forID: ids[0])!

            return "picked up item at " + item.coordinate.description
            
        case .control(let contr):
            return contr.speakableDescription
            
        case let .run(type):
            return "playing \(type.0.rawValue) animation"
            
        case let .fail(command):
            return command.speakableDescription
        }
    }
}

extension Action.Movement {
    var speakableDescription: String {
        switch self {
        case .walk: return "walked"
        case .jump: return "jumped"
        case .teleport: return "teleported"
        }
    }
}

extension Controller {
    var speakableDescription: String {
        switch self.kind {
        case .movePlatforms:
            return "turn lock to move platforms \(state ? "up" : "down")"

        case .toggle:
            return "toggled switch \(state ? "open" : "closed")"

        case .activate:
            return "changed portal to \(state ? "active" : "inactive")"
        }
    }
}

extension IncorrectAction {
    var speakableDescription: String {
        switch self {
        case .missingGem:
            return "tried to collect gem, but no gem was found"
            
        case .missingSwitch:
            return "tried to toggle switch, but no switch was found"
            
        case .missingLock:
            return "tried to turn lock, but no lock was found"
            
        case .intoWall:
            return "failed to move forward, hit wall"

        case .offEdge:
            return "failed to move forward, almost fell off edge"
        }
    }
}
