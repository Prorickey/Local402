//
//  LLMModelOption.swift
//  Local402
//
//  A selectable local LLM (filler data for onboarding).
//

import Foundation

struct LLMModelOption: Identifiable, Hashable {
    let id: String
    let name: String
    let parameters: String
    let sizeGB: Double
    let recommendedRAMGB: Int
    let description: String
    let isRecommended: Bool

    var sizeLabel: String { String(format: "%.1f GB", sizeGB) }
    var ramLabel: String { "\(recommendedRAMGB) GB RAM" }
}
