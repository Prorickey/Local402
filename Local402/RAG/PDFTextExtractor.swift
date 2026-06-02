//
//  PDFTextExtractor.swift
//  Local402
//
//  Extracts plain text from a PDF, page by page, using PDFKit. `nonisolated`
//  so it runs inside the RAGEngine actor (off the main thread), not on it.
//

import Foundation
import PDFKit

nonisolated enum PDFTextExtractor {
    struct Extraction: Sendable {
        let pageCount: Int
        let pages: [String]   // text content of each page, index 0 == page 1
    }

    static func extract(from url: URL) throws -> Extraction {
        guard let doc = PDFDocument(url: url) else {
            throw RAGError.couldNotOpenPDF(url.lastPathComponent)
        }

        var pages: [String] = []
        pages.reserveCapacity(doc.pageCount)
        for i in 0..<doc.pageCount {
            pages.append(doc.page(at: i)?.string ?? "")
        }

        let hasText = pages.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard hasText else { throw RAGError.noTextExtracted }

        return Extraction(pageCount: doc.pageCount, pages: pages)
    }
}
