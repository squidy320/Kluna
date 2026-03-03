//
//  KanzenHistoryView.swift
//  Kanzen
//
//  Created by Luna on 2026.
//

import SwiftUI
import Kingfisher

#if !os(tvOS)
struct KanzenHistoryView: View {
    @ObservedObject private var progressManager = MangaReadingProgressManager.shared

    private var historyItems: [(id: Int, progress: MangaProgress)] {
        progressManager.recentlyReadMangaIds()
    }

    var body: some View {
        NavigationView {
            Group {
                if historyItems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No reading history")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Manga you read will appear here.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(historyItems, id: \.id) { item in
                            NavigationLink(destination: mangaDestination(for: item)) {
                                HStack(spacing: 12) {
                                    KFImage(URL(string: item.progress.coverURL ?? ""))
                                        .placeholder { Rectangle().fill(Color.gray.opacity(0.2)) }
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 50, height: 75)
                                        .clipped()
                                        .cornerRadius(6)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.progress.title ?? "Unknown Manga")
                                            .font(.headline)
                                            .lineLimit(2)

                                        if let lastCh = item.progress.lastReadChapter {
                                            Text("Ch. \(lastCh)")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }

                                        if let date = item.progress.lastReadDate {
                                            Text(date, style: .relative)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    @ViewBuilder
    private func mangaDestination(for item: (id: Int, progress: MangaProgress)) -> some View {
        let manga = AniListManga(
            id: item.id,
            title: AniListManga.AniListMangaTitle(
                romaji: item.progress.title,
                english: nil,
                native: nil
            ),
            chapters: item.progress.totalChapters,
            volumes: nil,
            status: nil,
            coverImage: item.progress.coverURL.map {
                AniListManga.AniListMangaCover(large: $0, medium: nil)
            },
            format: item.progress.format,
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
