//
//  PlanDragDropTypes.swift
//  Production Runner
//
//  Extracted from PlanView.swift as part of refactoring
//  Drag & drop transfer types for casting actors and crew members
//

import Foundation
import UniformTypeIdentifiers
import CoreTransferable

// MARK: - Drag & Drop Transfer Types

/// Transferable wrapper for dragging actor IDs between sections
struct ActorDragItem: Codable, Transferable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .actorDragItem)
    }
}

/// Transferable wrapper for dragging crew member IDs between sections
struct CrewDragItem: Codable, Transferable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .crewDragItem)
    }
}

// MARK: - UTType Extensions

extension UTType {
    static var actorDragItem: UTType {
        UTType(exportedAs: "com.productionrunner.actor-drag-item")
    }

    static var crewDragItem: UTType {
        UTType(exportedAs: "com.productionrunner.crew-drag-item")
    }
}
