//
//  MangaCollectionDetailView.swift
//  Kanzen
//
//  Created by Luna on 2026.
//

import SwiftUI
import Kingfisher

#if !os(tvOS)
struct MangaCollectionDetailView: View {
    @ObservedObject var collection: MangaLibraryCollection
    @ObservedObject var libraryManager: MangaLibraryManager

    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 12)]

    var body: some View {
        Group {
            if collection.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "books.vertical")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No manga in this collection")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(collection.items) { item in
                            NavigationLink(destination: mangaDestination(for: item)) {
                                mangaCard(item)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    libraryManager.removeItem(from: collection.id, item: item)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func mangaCard(_ item: MangaLibraryItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            KFImage(URL(string: item.coverURL ?? ""))
                .placeholder { Rectangle().fill(Color.gray.opacity(0.2)) }
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 180)
                .clipped()
                .cornerRadius(8)

            Text(item.title)
                .font(.caption)
                .lineLimit(2)
                .foregroundColor(.primary)
        }
        .frame(width: 120)
    }

    @ViewBuilder
    private func mangaDestination(for item: MangaLibraryItem) -> some View {
        let manga = AniListManga(
            id: item.aniListId,
            title: AniListManga.AniListMangaTitle(romaji: item.title, english: nil, native: nil),
            chapters: item.totalChapters,
            volumes: nil,
            status: nil,
            coverImage: item.coverURL.map { AniListManga.AniListMangaCover(large: $0, medium: nil) },
            format: item.format,
            description: nil,
            genres: nil,
            averageScore: nil,
            countryOfOrigin: nil,
            startDate: nil
        )
        MangaDetailView(manga: manga)
    }
}
#endif
