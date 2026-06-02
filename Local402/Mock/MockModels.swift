//
//  MockModels.swift
//  Local402
//
//  Filler local-model options shown during onboarding.
//

import Foundation

enum MockModels {
    static let all: [LLMModelOption] = [
        LLMModelOption(
            id: "llama-3.1-8b",
            name: "Llama 3.1",
            parameters: "8B",
            sizeGB: 4.7,
            recommendedRAMGB: 16,
            description: "Balanced general-purpose model. Great default for most agent work.",
            isRecommended: true
        ),
        LLMModelOption(
            id: "mistral-7b",
            name: "Mistral",
            parameters: "7B",
            sizeGB: 4.1,
            recommendedRAMGB: 16,
            description: "Fast and lightweight, strong at reasoning over short contexts.",
            isRecommended: false
        ),
        LLMModelOption(
            id: "qwen-2.5-14b",
            name: "Qwen 2.5",
            parameters: "14B",
            sizeGB: 8.9,
            recommendedRAMGB: 32,
            description: "Higher quality for complex tasks. Needs more memory headroom.",
            isRecommended: false
        ),
        LLMModelOption(
            id: "phi-3-mini",
            name: "Phi-3 Mini",
            parameters: "3.8B",
            sizeGB: 2.3,
            recommendedRAMGB: 8,
            description: "Tiny and quick. Ideal for low-resource machines and quick tasks.",
            isRecommended: false
        )
    ]
}
