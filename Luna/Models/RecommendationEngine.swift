//
//  RecommendationEngine.swift
//  Luna
//
//  Local recommendation engine that builds a genre taste profile
//  from watch history and bookmarks, then scores catalog items.
//

import Foundation

final class RecommendationEngine {
    static let shared = RecommendationEngine()
    private init() {
        cachedRecommendations = Self.loadFromDisk()
    }

    // Cache to avoid recomputing every time HomeViewModel loads
    private var cachedRecommendations: [TMDBSearchResult] = []
    private var cacheDate: Date?
    private let cacheTTL: TimeInterval = 300 // 5 minutes

    private static let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("RecommendationCache.json")
    }()

    /// Generate "Just For You" recommendations by scoring items from existing catalogs
    /// against the user's genre taste profile. Optionally fetches TMDB recommendations
    /// for the user's top watched items (throttled to avoid rate limiting).
    func generateRecommendations(
        catalogResults: [String: [TMDBSearchResult]],
        tmdbService: TMDBService
    ) async -> [TMDBSearchResult] {
        // Return cache if fresh
        if let cacheDate, Date().timeIntervalSince(cacheDate) < cacheTTL, !cachedRecommendations.isEmpty {
            return cachedRecommendations
        }

        let profile = buildTasteProfile()

        // No signals = no recommendations
        guard !profile.genreWeights.isEmpty else { return [] }

        // 1. Score every item from existing catalogs
        var candidateScores: [Int: (result: TMDBSearchResult, score: Double)] = [:]
        let watchedIds = profile.watchedIds
        let bookmarkedIds = profile.bookmarkedIds

        for (_, results) in catalogResults {
            for item in results {
                // Skip already-watched and bookmarked items
                guard !watchedIds.contains(item.id), !bookmarkedIds.contains(item.id) else { continue }
                guard candidateScores[item.id] == nil else { continue }

                let score = scoreItem(item, profile: profile)
                if score > 0 {
                    candidateScores[item.id] = (item, score)
                }
            }
        }

        // 2. Fetch TMDB recommendations for top 3 most-watched items (throttled)
        let tmdbRecs = await fetchTMDBRecommendations(profile: profile, tmdbService: tmdbService)
        for item in tmdbRecs {
            guard !watchedIds.contains(item.id), !bookmarkedIds.contains(item.id) else { continue }
            if let existing = candidateScores[item.id] {
                // Boost score for items that also appear in TMDB recs
                candidateScores[item.id] = (existing.result, existing.score * 1.5)
            } else {
                let score = scoreItem(item, profile: profile)
                candidateScores[item.id] = (item, max(score, 0.1))
            }
        }

        // 3. Rank, deduplicate, and take top 20
        let ranked = candidateScores.values
            .sorted { $0.score > $1.score }
            .prefix(20)
            .map { $0.result }

        cachedRecommendations = Array(ranked)
        cacheDate = Date()
        saveToDisk()
        return cachedRecommendations
    }

    func invalidateCache() {
        cachedRecommendations = []
        cacheDate = nil
    }

    // MARK: - Persistence

    private func saveToDisk() {
        guard !cachedRecommendations.isEmpty else { return }
        do {
            let data = try JSONEncoder().encode(cachedRecommendations)
            try data.write(to: Self.fileURL, options: .atomic)
        } catch { }
    }

    private static func loadFromDisk() -> [TMDBSearchResult] {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let results = try? JSONDecoder().decode([TMDBSearchResult].self, from: data) else {
            return []
        }
        return results
    }

    /// Returns the current recommendation cache for backup
    func getRecommendationCache() -> [TMDBSearchResult] {
        return cachedRecommendations
    }

    /// Restores recommendation cache from backup
    func restoreRecommendationCache(_ items: [TMDBSearchResult]) {
        cachedRecommendations = items
        cacheDate = Date()
        saveToDisk()
    }

    // MARK: - Taste Profile

    private struct TasteProfile {
        var genreWeights: [Int: Double] // genreId -> weight
        var watchedIds: Set<Int>
        var bookmarkedIds: Set<Int>
        var topWatchedMovieIds: [Int] // sorted by recency, for TMDB recs
        var topWatchedShowIds: [Int]
    }

    private func buildTasteProfile() -> TasteProfile {
        var genreWeights: [Int: Double] = [:]
        var watchedIds = Set<Int>()
        var bookmarkedIds = Set<Int>()
        var movieEntries: [(id: Int, date: Date)] = []
        var showEntries: [(id: Int, date: Date)] = []

        // 1. Watch history — strongest signal
        let progressData = ProgressManager.shared.getProgressData()

        for movie in progressData.movieProgress {
            watchedIds.insert(movie.id)
            if movie.progress >= 0.3 { // At least 30% watched = meaningful signal
                movieEntries.append((movie.id, movie.lastUpdated))
            }
        }

        // Group episodes by show
        var showLastWatched: [Int: Date] = [:]
        for episode in progressData.episodeProgress {
            watchedIds.insert(episode.showId)
            if episode.progress >= 0.3 {
                if let existing = showLastWatched[episode.showId] {
                    showLastWatched[episode.showId] = max(existing, episode.lastUpdated)
                } else {
                    showLastWatched[episode.showId] = episode.lastUpdated
                }
            }
        }
        for (showId, date) in showLastWatched {
            showEntries.append((showId, date))
        }

        // 2. Bookmarks — secondary signal
        let collections = LibraryManager.shared.collections
        for collection in collections {
            for item in collection.items {
                bookmarkedIds.insert(item.searchResult.id)
                if let genres = item.searchResult.genreIds {
                    for genreId in genres {
                        // Bookmarked = moderate weight
                        genreWeights[genreId, default: 0] += 2.0
                    }
                }
            }
        }

        // 3. Derive genre weights from bookmarked items for watched content
        //    (watched movies/shows don't carry genreIds in ProgressManager,
        //     so we use bookmarks + catalog cross-reference)
        //    The actual genre scoring happens at item-score time using the item's own genreIds.

        // Boost genres from recently watched content found in bookmarks
        let recentWatchedIds = Set(
            (movieEntries.sorted { $0.date > $1.date }.prefix(10).map { $0.id }) +
            (showEntries.sorted { $0.date > $1.date }.prefix(10).map { $0.id })
        )
        for collection in collections {
            for item in collection.items where recentWatchedIds.contains(item.searchResult.id) {
                if let genres = item.searchResult.genreIds {
                    for genreId in genres {
                        genreWeights[genreId, default: 0] += 3.0 // Watched + bookmarked = strong signal
                    }
                }
            }
        }

        // Sort by recency for TMDB rec fetching
        let topMovies = movieEntries.sorted { $0.date > $1.date }.prefix(3).map { $0.id }
        let topShows = showEntries.sorted { $0.date > $1.date }.prefix(3).map { $0.id }

        return TasteProfile(
            genreWeights: genreWeights,
            watchedIds: watchedIds,
            bookmarkedIds: bookmarkedIds,
            topWatchedMovieIds: Array(topMovies),
            topWatchedShowIds: Array(topShows)
        )
    }

    // MARK: - Scoring

    private func scoreItem(_ item: TMDBSearchResult, profile: TasteProfile) -> Double {
        guard let genres = item.genreIds, !genres.isEmpty else { return 0 }

        var score: Double = 0

        // Genre match scoring
        let maxWeight = profile.genreWeights.values.max() ?? 1
        for genreId in genres {
            if let weight = profile.genreWeights[genreId] {
                score += weight / maxWeight // Normalize to 0-1 per genre
            }
        }

        // Popularity boost (slight preference for popular content)
        let popularityBoost = min(item.popularity / 100.0, 0.5)
        score += popularityBoost

        // Rating boost
        if let rating = item.voteAverage, rating > 6.0 {
            score += (rating - 6.0) / 10.0 // 0 to 0.4 boost
        }

        return score
    }

    // MARK: - TMDB Recommendations (throttled)

    private func fetchTMDBRecommendations(
        profile: TasteProfile,
        tmdbService: TMDBService
    ) async -> [TMDBSearchResult] {
        var results: [TMDBSearchResult] = []

        // Fetch recs for top 2 movies + top 1 show (max 3 API calls)
        let movieIds = Array(profile.topWatchedMovieIds.prefix(2))
        let showIds = Array(profile.topWatchedShowIds.prefix(1))

        for movieId in movieIds {
            if let recs = try? await tmdbService.getMovieRecommendations(id: movieId) {
                let converted = recs.prefix(5).map { movie in
                    TMDBSearchResult(
                        id: movie.id,
                        mediaType: "movie",
                        title: movie.title,
                        name: nil,
                        overview: movie.overview,
                        posterPath: movie.posterPath,
                        backdropPath: movie.backdropPath,
                        releaseDate: movie.releaseDate,
                        firstAirDate: nil,
                        voteAverage: movie.voteAverage,
                        popularity: movie.popularity,
                        adult: movie.adult,
                        genreIds: movie.genreIds
                    )
                }
                results.append(contentsOf: converted)
            }
            // Brief delay between calls
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        for showId in showIds {
            if let recs = try? await tmdbService.getTVRecommendations(id: showId) {
                let converted = recs.prefix(5).map { show in
                    TMDBSearchResult(
                        id: show.id,
                        mediaType: "tv",
                        title: nil,
                        name: show.name,
                        overview: show.overview,
                        posterPath: show.posterPath,
                        backdropPath: show.backdropPath,
                        releaseDate: nil,
                        firstAirDate: show.firstAirDate,
                        voteAverage: show.voteAverage,
                        popularity: show.popularity,
                        adult: nil,
                        genreIds: show.genreIds
                    )
                }
                results.append(contentsOf: converted)
            }
        }

        return results
    }
}
