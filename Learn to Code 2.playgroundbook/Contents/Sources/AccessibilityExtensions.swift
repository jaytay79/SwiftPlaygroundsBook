//
//  AccessibilityExtensions.swift
//
//  Copyright (c) 2016 Apple Inc. All Rights Reserved.
//

import UIKit
import SceneKit

class CoordinateAccessibilityElement: UIAccessibilityElement {
    
    let coordinate: Coordinate
    weak var world: GridWorld?
    
    /// Override `accessibilityLabel` to always return updated information about world state.
    override var accessibilityLabel: String? {
        get {
            return world?.speakableContents(of: coordinate)
        }
        set {}
    }
    
    init(coordinate: Coordinate, inWorld world: GridWorld, view: UIView) {
        self.coordinate = coordinate
        self.world = world
        super.init(accessibilityContainer: view)
    }
    
}

class GridWorldAccessibilityElement: UIAccessibilityElement {
    weak var world: GridWorld?
    
    init(world: GridWorld, view: UIView) {
        self.world = world
        super.init(accessibilityContainer: view)
    }
    
    override var accessibilityLabel: String? {
        get {
            return world?.speakableDescription
        }
        set {}
    }
}

// MARK: SceneController Accessibility

extension SceneController {
    
    func registerForAccessibilityNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(voiceOverStatusChanged), name: Notification.Name(rawValue: UIAccessibilityVoiceOverStatusChanged), object: nil)
    }
    
    func unregisterForAccessibilityNotifications() {
        NotificationCenter.default.removeObserver(self, name: Notification.Name(rawValue: UIAccessibilityVoiceOverStatusChanged), object: nil)
    }
    
    func voiceOverStatusChanged() {
        DispatchQueue.main.async {
            self.setVoiceOverForCurrentStatus()
        }
    }
    
    /**
    Configures the scene to account for the current VoiceOver status.
     - parameters:
         - forceLayout: Passing `true` will force the accessibility elements
        to be recalculated for the current grid.
    */
    func setVoiceOverForCurrentStatus(forceLayout: Bool = false) {
        guard isViewLoaded else { return }
        
        if UIAccessibilityIsVoiceOverRunning() {
            scnView.gesturesEnabled = false

            // Lazily recompute the `accessibilityElements`.
            if forceLayout || view.accessibilityElements?.isEmpty == true {
                cameraController?.switchToOverheadView()
                configureAccessibilityElementsForGrid()
                
                view.accessibilityElements?.append(speedButton)
            }
            
            speedButton.isAccessibilityElement = true
            speedButton.accessibilityHint = "Adjusts the speed of playback."
            
            // Add an AccessibilityComponent to each actor.
            for actor in scene.actors {
                actor.addComponent(AccessibilityComponent(actor: actor))
            }
        }
        else {
            // Set for UITesting. 
            view.isAccessibilityElement = true
            view.accessibilityElements = []
            view.accessibilityLabel = "The world is running."
            
            scnView.gesturesEnabled = true
            cameraController?.resetFromVoiceOver()
            
            for actor in scene.actors {
                actor.removeComponent(ofType: AccessibilityComponent.self)
            }
        }
    }
    
    private func configureAccessibilityElementsForGrid() {
        view.isAccessibilityElement = false
        view.accessibilityElements = []
        
        for coordinate in scene.gridWorld.columnRowSortedCoordinates {
            let gridPosition = coordinate.position
            let rootPosition = scene.gridWorld.grid.scnNode.convertPosition(gridPosition, to: nil)
            
            let offset = WorldConfiguration.coordinateLength / 2
            let upperLeft = scnView.projectPoint(SCNVector3Make(rootPosition.x - offset, rootPosition.y, rootPosition.z - offset))
            let lowerRight = scnView.projectPoint(SCNVector3Make(rootPosition.x + offset, rootPosition.y, rootPosition.z + offset))
            
            let point = CGPoint(x: CGFloat(upperLeft.x), y: CGFloat(upperLeft.y))
            let size = CGSize (width: CGFloat(lowerRight.x - upperLeft.x), height: CGFloat(lowerRight.y - upperLeft.y))
            
            let element = CoordinateAccessibilityElement(coordinate: coordinate, inWorld: scene.gridWorld, view: view)
            element.accessibilityFrame = CGRect(origin: point, size: size)
            view.accessibilityElements?.append(element)
        }
        
        let container = GridWorldAccessibilityElement(world: scene.gridWorld, view: view)
        container.accessibilityFrame = view.bounds
        view.accessibilityElements?.append(container)
    }
}

extension GridWorld {
    
    /// Returns all the possible coordinates sorted by column then row.
    var columnRowSortedCoordinates: [Coordinate] {
        return allPossibleCoordinates.sorted(by: columnRowSortPredicate)
    }
    
    /// Describes the entire contents of the world including all the important locations.
    var speakableDescription: String {
        let sortedItems = grid.allItemsInGrid.sorted { item1, item2 in
            return columnRowSortPredicate(item1.coordinate, item2.coordinate)
        }
        
        let actors = sortedItems.flatMap { $0 as? Actor }
        let randomItems = sortedItems.filter { $0.identifier == .randomNode }
        let goals = sortedItems.filter {
            switch $0.identifier {
            case .switch, .portal, .item, .platformLock: return true
            default: return false
            }
        }
        
        var description = "The world is \(columnCount) columns by \(rowCount) rows. "
        if actors.isEmpty {
            description += "There is no character placed in this world. You must place your own."
        }
        else {
            for node in actors {
                let name = node.type.rawValue
                description += "\(name) starts at \(node.locationDescription)."
            }
        }
        
        if !goals.isEmpty {
            description += " The important locations are: "
            for (index, goalNode) in goals.enumerated() {
                description += "\(goalNode.identifier.rawValue) at \(goalNode.locationDescription)"
                description += index == goals.endIndex ? "." : "; "
            }
        }
        
        if !randomItems.isEmpty {
            for (index, item) in randomItems.enumerated() {
                let object = item as! RandomNode
                let nodeType = object.resemblingNode.identifier.rawValue
                description += "random \(nodeType) marker at \(item.locationDescription)"
                description += index == randomItems.endIndex ? "." : "; "
            }
        }
        
        return description + " To repeat this description, tap outside of the world grid."
    }
    
    func speakableContents(of coordinate: Coordinate) -> String {
        let prefix = "\(coordinate.description), "
        
        let contents = excludingNodes(ofType: Block.self, at: coordinate).reduce("") { str, item in
            let tileDescription: String
            
            switch item.identifier {
            case .actor:
                let actor = item as? Actor
                let name = actor?.type.rawValue ?? "Actor"
                tileDescription = name + item.description(with: [.height, .direction])
                
            case .stair:
                let baseDesc = item.description(with: [.name, .noSuffix])
                let directionDesc = " leading to \(coordinate.neighbor(inDirection: item.heading))"
                let heightDesc = " from height \(item.height) to \(item.height - 1), "
                tileDescription = baseDesc + directionDesc + heightDesc
                
            case .switch:
                let switchItem = item as! Switch
                let switchState = switchItem.isOn ? "open" : "closed"
                tileDescription = "\(switchState) " + item.description(with: [.name, .height])
                
            case .portal:
                var desc = item.description(with: [.name, .height, .noSuffix])
                if let connected = (item as? Portal)?.linkedPortal {
                    desc += " connected to \(connected.coordinate.description)" + connected.description(with: [.height])
                }
                tileDescription = desc
                
            case .wall:
                guard let wall = item as? Wall else { fatalError("Incorrect identifier on \(item)") }
                var desc = wall.description(with: [.name, .height])
                for neighbor in coordinate.neighbors
                    where wall.blocksMovement(from: coordinate, to: neighbor) {
                    desc += "blocking movement to \(neighbor.description), "
                }
                tileDescription = desc

            case .water:
                tileDescription = item.description(with: [.name])
                
            case .startMarker:
                tileDescription = item.description(with: [.name, .height, .direction])
                
            default:
                tileDescription = item.description(with: [.name, .height])
            }
            
            return str + tileDescription
        }
        
        let suffix = !contents.isEmpty ? contents : blockDescription(at: coordinate)
        return completeSentence(prefix + suffix)
    }
    
    // MARK: Helper Methods
    
    /// Returns if the coordinate contains a block, or is unreachable.
    func blockDescription(at coordinate: Coordinate) -> String {
        guard let block = topBlock(at: coordinate) else {
            return "is unreachable."
        }
        return block.description(with: [.name, .height])
    }
    
    /// Removes ", " from the end of a string and replaces it with ".".
    private func completeSentence(_ sentence: String) -> String {
        let chars = sentence.characters
        let end = chars.suffix(2)
        guard String(end) == ", " else { return sentence + "." }
        
        return String(chars.dropLast(2)) + "."
    }
    
    func columnRowSortPredicate(_ coor1: Coordinate, _ coor2: Coordinate) -> Bool {
        if coor1.column == coor2.column {
            return coor1.row < coor2.row
        }
        return coor1.column < coor2.column
    }
}

// MARK: DescriptionComponents

struct ItemDescriptionComponents: OptionSet {
    let rawValue: Int
    
    static let name  = ItemDescriptionComponents(rawValue: 1 << 0)
    static let height  = ItemDescriptionComponents(rawValue: 1 << 1)
    static let direction  = ItemDescriptionComponents(rawValue: 1 << 2)
    
    /// Indicates that ", " should not be appended to the description.
    static let noSuffix  = ItemDescriptionComponents(rawValue: 1 << 3)
}

extension Actor {
    
    var speakableName: String {
        return type.rawValue
    }
}

extension Item {
    
    var locationDescription: String{
        return "\(coordinate.description), height \(height)"
    }
    
    func description(with components: ItemDescriptionComponents) -> String {
        var description = ""
        
        if components.contains(.name) {
            description += identifier.rawValue.lowercased()
        }
        
        if components.contains(.height) {
            description += " at height \(height)"
        }
        
        if components.contains(.direction) {
            description += " facing \(heading)"
        }
        
        // Add a suffix.
        let suffix = components.contains(.noSuffix) ? "" : ", "
        
        return description + suffix
    }
}

