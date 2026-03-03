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

    static func == (lhs: MangaLibraryItem, rhs: MangaLibraryItem) -> Bool {
        lhs.aniListId == rhs.aniListId
    }
}
