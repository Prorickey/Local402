//
//  Embedder.swift
//  Local402
//
//  Turns text into a vector, fully on-device. The protocol is the seam: swap
//  NLEmbedder for a Core ML / MLX sentence-transformer later and nothing else
//  in the pipeline changes. `nonisolated` so it runs inside the engine actor.
//

import Foundation
import NaturalLanguage

protocol Embedder: Sendable {
    nonisolated var dimension: Int { get }
    nonisolated func embed(_ text: String) -> [Float]?
}

/// On-device embeddings via Apple's NaturalLanguage framework.
/// No network, no bundled model files — the model ships with macOS.
nonisolated final class NLEmbedder: Embedder, @unchecked Sendable {
    // @unchecked: NLEmbedding isn't marked Sendable, but this instance is only
    // ever touched from inside the RAGEngine actor, which serializes access.
    private let embedding: NLEmbedding
    let dimension: Int

    init?(language: NLLanguage = .english) {
        guard let model = NLEmbedding.sentenceEmbedding(for: language) else { return nil }
        self.embedding = model
        self.dimension = model.dimension
    }

    func embed(_ text: String) -> [Float]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let vector = embedding.vector(for: trimmed) else { return nil }
        return vector.map(Float.init)
    }
}
