//
//  MangaLibraryManager.swift
//  Kanzen
//
//  Created by Luna on 2026.
//

import Foundation
import Combine

final class MangaLibraryManager: ObservableObject {
    static let shared = MangaLibraryManager()

    @Published var collections: [MangaLibraryCollection] = [] {
        didSet {
            collections.forEach { observeCollection($0) }
            save()
        }
    }

    private let storageKey = "mangaLibraryCollections"
    private var collectionCancellables: [UUID: AnyCancellable] = [:]

    private init() {
        load()
        createDefaultBookmarksCollection()
        collections.forEach { observeCollection($0) }
    }

    // MARK: - Persistence

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([MangaLibraryCollection].self, from: data) {
            collections = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(collections) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func createDefaultBookmarksCollection() {
        if !collections.contains(where: { $0.name == "Bookmarks" }) {
            let bookmarks = MangaLibraryCollection(name: "Bookmarks", description: "Your bookmarked manga")
            collections.insert(bookmarks, at: 0)
        }
    }

    // MARK: - Collection CRUD

    func createCollection(name: String, description: String? = nil) {
        let collection = MangaLibraryCollection(name: name, description: description)
        collections.append(collection)
    }

    func deleteCollection(_ collection: MangaLibraryCollection) {
        guard collection.name != "Bookmarks" else { return }
        collectionCancellables[collection.id] = nil
        collections.removeAll { $0.id == collection.id }
    }

    // MARK: - Item CRUD

    func addItem(to collectionId: UUID, item: MangaLibraryItem) {
        guard let idx = collections.firstIndex(where: { $0.id == collectionId }),
              !collections[idx].items.contains(where: { $0.id == item.id }) else { return }
        collections[idx].items.append(item)
    }

    func removeItem(from collectionId: UUID, item: MangaLibraryItem) {
        guard let idx = collections.firstIndex(where: { $0.id == collectionId }) else { return }
        collections[idx].items.removeAll { $0.id == item.id }
    }

    func isItemInCollection(_ collectionId: UUID, item: MangaLibraryItem) -> Bool {
        guard let col = collections.first(where: { $0.id == collectionId }) else { return false }
        return col.items.contains { $0.id == item.id }
    }

    func collectionsContainingItem(_ item: MangaLibraryItem) -> [MangaLibraryCollection] {
        collections.filter { $0.items.contains { $0.id == item.id } }
    }

    // MARK: - Bookmark Shortcuts

    func toggleBookmark(_ item: MangaLibraryItem) {
        guard let bookmarks = collections.first(where: { $0.name == "Bookmarks" }) else { return }
        if isItemInCollection(bookmarks.id, item: item) {
            removeItem(from: bookmarks.id, item: item)
        } else {
            var newItem = item
            newItem.dateAdded = Date()
            addItem(to: bookmarks.id, item: newItem)
        }
    }

    func isBookmarked(_ item: MangaLibraryItem) -> Bool {
        guard let bookmarks = collections.first(where: { $0.name == "Bookmarks" }) else { return false }
        return isItemInCollection(bookmarks.id, item: item)
    }

    // MARK: - Observation

    private func observeCollection(_ collection: MangaLibraryCollection) {
        if collectionCancellables[collection.id] != nil { return }
        let cancellable = collection.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                    self?.save()
                }
            }
        collectionCancellables[collection.id] = cancellable
    }
}
