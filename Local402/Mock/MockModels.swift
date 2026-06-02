//
//  MockModels.swift
//  Local402
//
//  The local-model catalog shown during onboarding. These are REAL on-device
//  models: each `id` is the Hugging Face `mlx-community` repo that `LLMEngine`
//  downloads and runs via MLX. All are 4-bit quantized and tool-calling capable,
//  so they fit comfortably on an Apple-silicon Mac.
//
//  Qwen2.5 1.5B is the recommended default — ~1 GB, fast on M-series, and strong
//  at grounded RAG answers and function calling.
//

import Foundation

enum MockModels {
    static let all: [LLMModelOption] = [
        LLMModelOption(
            id: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
            name: "Qwen2.5 1.5B",
            parameters: "1.5B",
            sizeGB: 1.0,
            recommendedRAMGB: 8,
            description: "Compact, fast, and tool-call capable. The recommended default — great for grounded RAG chat on any Apple-silicon Mac.",
            isRecommended: true
        ),
        LLMModelOption(
            id: "mlx-community/Llama-3.2-1B-Instruct-4bit",
            name: "Llama 3.2 1B",
            parameters: "1B",
            sizeGB: 0.8,
            recommendedRAMGB: 8,
            description: "The lightest option. Fastest tokens-per-second with a modest quality trade-off — ideal for low-memory machines.",
            isRecommended: false
        ),
        LLMModelOption(
            id: "mlx-community/Qwen2.5-3B-Instruct-4bit",
            name: "Qwen2.5 3B",
            parameters: "3B",
            sizeGB: 1.8,
            recommendedRAMGB: 16,
            description: "Higher quality reasoning and tool use. A bit more memory and a little slower, but noticeably sharper answers.",
            isRecommended: false
        ),
        LLMModelOption(
            id: "mlx-community/Llama-3.2-3B-Instruct-4bit",
            name: "Llama 3.2 3B",
            parameters: "3B",
            sizeGB: 1.8,
            recommendedRAMGB: 16,
            description: "Meta's instruction-tuned 3B. Balanced general-purpose alternative with solid function-calling support.",
            isRecommended: false
        ),
    ]

    /// The default model used before onboarding picks one.
    static let `default`: LLMModelOption = all.first { $0.isRecommended } ?? all[0]
}
