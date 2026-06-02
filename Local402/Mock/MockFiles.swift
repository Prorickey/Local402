//
//  MockFiles.swift
//  Local402
//
//  Filler company files for the data-drop onboarding step.
//

import Foundation

enum MockFiles {
    /// Pre-seeded files shown as already added.
    static let seeded: [ContextFile] = [
        ContextFile(fileName: "employee_handbook.pdf", sizeBytes: 2_415_919),
        ContextFile(fileName: "q3_financials.xlsx", sizeBytes: 845_201)
    ]

    /// Pool of plausible files used when the user "drops" or adds a file.
    static let pool: [ContextFile] = [
        ContextFile(fileName: "product_roadmap.pdf", sizeBytes: 1_204_322),
        ContextFile(fileName: "customers.csv", sizeBytes: 532_104),
        ContextFile(fileName: "schema.sql", sizeBytes: 48_220),
        ContextFile(fileName: "brand_guidelines.pdf", sizeBytes: 6_104_882),
        ContextFile(fileName: "support_macros.json", sizeBytes: 84_410),
        ContextFile(fileName: "meeting_notes.md", sizeBytes: 22_140),
        ContextFile(fileName: "pricing.yaml", sizeBytes: 9_820),
        ContextFile(fileName: "infra_diagram.png", sizeBytes: 1_882_004)
    ]

    /// Returns a file from the pool that isn't already present, falling back to a fabricated one.
    static func nextFile(excluding existing: [ContextFile]) -> ContextFile {
        let existingNames = Set(existing.map(\.fileName))
        if let candidate = pool.first(where: { !existingNames.contains($0.fileName) }) {
            return ContextFile(fileName: candidate.fileName, sizeBytes: candidate.sizeBytes)
        }
        let index = existing.count + 1
        return ContextFile(fileName: "context_\(index).txt", sizeBytes: 12_000 + index * 1_500)
    }
}
