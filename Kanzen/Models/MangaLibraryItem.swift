//
//  MangaLibraryItem.swift
//  Kanzen
//
//  Created by Luna on 2026.
//

import Foundation

struct MangaLibraryItem: Codable, Identifiable, Equatable {
    var id: Int { aniListId }

    let aniListId: Int
    let title: String
    let coverURL: String?
    let format: String?
    let totalChapters: Int?
    var dateAdded: Date = Date()

    /// Create a library item from module search content.
    /// Produces a stable negative ID from the module + content identifier
    /// so it never collides with AniList IDs (which are always positive).
    static func fromModule(moduleId: UUID, contentId: String, title: String, coverURL: String?, isNovel: Bool) -> MangaLibraryItem {
        let combined = "\(moduleId.uuidString):\(contentId)"
        // Use a stable hash; make it negative to avoid AniList ID collisions
        let hash = combined.utf8.reduce(into: 5381) { h, c in h = ((h &<< 5) &+ h) &+ Int(c) }
        let stableId = hash < 0 ? hash : -hash - 1
        return MangaLibraryItem(
            aniListId: stableId,
            title: title,
            coverURL: coverURL,
            format: isNovel ? "NOVEL" : "MANGA",
            totalChapters: nil
        )
    }

    static func == (lhs: MangaLibraryItem, rhs: MangaLibraryItem) -> Bool {
        lhs.aniListId == rhs.aniListId
    }
}
