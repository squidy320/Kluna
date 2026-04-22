//
//  EpisodeSourcePreferenceStore.swift
//  Luna
//
//  Created by OpenAI on 2026.
//

import Foundation

enum RememberedSource: Equatable {
    case service(Service)
    case stremio(StremioAddon)

    var id: String {
        switch self {
        case .service(let service):
            return "service:\(service.id.uuidString)"
        case .stremio(let addon):
            return "stremio:\(addon.id.uuidString)"
        }
    }

    var displayName: String {
        switch self {
        case .service(let service):
            return service.metadata.sourceName
        case .stremio(let addon):
            return addon.manifest.name
        }
    }

    var logoURL: String? {
        switch self {
        case .service(let service):
            return service.metadata.iconUrl
        case .stremio(let addon):
            return addon.manifest.logo
        }
    }
}

struct RememberedProviderResult: Codable, Equatable {
    let title: String
    let imageUrl: String
    let href: String

    init(result: SearchItem) {
        self.title = result.title
        self.imageUrl = result.imageUrl
        self.href = result.href
    }

    func matches(_ result: SearchItem) -> Bool {
        if !href.isEmpty {
            return href == result.href
        }

        return normalizedTitle == Self.normalize(result.title)
            && normalizedImageUrl == Self.normalize(result.imageUrl)
    }

    private var normalizedTitle: String {
        Self.normalize(title)
    }

    private var normalizedImageUrl: String {
        Self.normalize(imageUrl)
    }

    private static func normalize(_ value: String) -> String {
        value
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct RememberedStreamSelection: Codable, Equatable {
    let name: String
    let url: String
    let subtitle: String?

    init(option: StreamOption) {
        self.name = option.name
        self.url = option.url
        self.subtitle = option.subtitle
    }

    func matches(_ option: StreamOption) -> Bool {
        if !url.isEmpty {
            return url == option.url
        }

        return normalizedName == Self.normalize(option.name)
            && normalizedSubtitle == Self.normalize(option.subtitle ?? "")
    }

    private var normalizedName: String {
        Self.normalize(name)
    }

    private var normalizedSubtitle: String {
        Self.normalize(subtitle ?? "")
    }

    private static func normalize(_ value: String) -> String {
        value
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct RememberedSubtitleSelection: Codable, Equatable {
    let url: String?
    let title: String?
    let isNone: Bool

    static let none = RememberedSubtitleSelection(url: nil, title: nil, isNone: true)

    func matches(url candidateURL: String) -> Bool {
        guard !isNone, let url else { return false }
        return url == candidateURL
    }
}

struct RememberedEpisodeMatch: Codable, Equatable {
    let sourceId: String
    let providerResult: RememberedProviderResult?
    let streamSelection: RememberedStreamSelection?
    let subtitleSelection: RememberedSubtitleSelection?
}

final class EpisodeSourcePreferenceStore {
    static let shared = EpisodeSourcePreferenceStore()

    private let key = "rememberedEpisodeMatchesByShow"

    private init() {}

    func rememberedMatch(showId: Int) -> RememberedEpisodeMatch? {
        allPreferences()[String(showId)]
    }

    func rememberedSourceId(showId: Int) -> String? {
        rememberedMatch(showId: showId)?.sourceId
    }

    func rememberedProviderResult(showId: Int) -> RememberedProviderResult? {
        rememberedMatch(showId: showId)?.providerResult
    }

    func rememberedStreamSelection(showId: Int) -> RememberedStreamSelection? {
        rememberedMatch(showId: showId)?.streamSelection
    }

    func rememberedSubtitleSelection(showId: Int) -> RememberedSubtitleSelection? {
        rememberedMatch(showId: showId)?.subtitleSelection
    }

    func setRememberedMatch(sourceId: String, providerResult: SearchItem?, for showId: Int) {
        var values = allPreferences()
        values[String(showId)] = RememberedEpisodeMatch(
            sourceId: sourceId,
            providerResult: providerResult.map(RememberedProviderResult.init(result:)),
            streamSelection: nil,
            subtitleSelection: nil
        )
        persist(values)
    }

    func setRememberedSourceId(_ sourceId: String, for showId: Int) {
        let existingMatch = rememberedMatch(showId: showId)
        var values = allPreferences()
        values[String(showId)] = RememberedEpisodeMatch(
            sourceId: sourceId,
            providerResult: existingMatch?.providerResult,
            streamSelection: existingMatch?.streamSelection,
            subtitleSelection: existingMatch?.subtitleSelection
        )
        persist(values)
    }

    func setRememberedStreamSelection(_ option: StreamOption, for showId: Int) {
        guard let existingMatch = rememberedMatch(showId: showId) else { return }
        var values = allPreferences()
        values[String(showId)] = RememberedEpisodeMatch(
            sourceId: existingMatch.sourceId,
            providerResult: existingMatch.providerResult,
            streamSelection: RememberedStreamSelection(option: option),
            subtitleSelection: existingMatch.subtitleSelection
        )
        persist(values)
    }

    func setRememberedSubtitleSelection(_ selection: RememberedSubtitleSelection, for showId: Int) {
        guard let existingMatch = rememberedMatch(showId: showId) else { return }
        var values = allPreferences()
        values[String(showId)] = RememberedEpisodeMatch(
            sourceId: existingMatch.sourceId,
            providerResult: existingMatch.providerResult,
            streamSelection: existingMatch.streamSelection,
            subtitleSelection: selection
        )
        persist(values)
    }

    func clearRememberedMatch(for showId: Int) {
        var values = allPreferences()
        values.removeValue(forKey: String(showId))
        persist(values)
    }

    func clearRememberedSource(for showId: Int) {
        clearRememberedMatch(for: showId)
    }

    func resolveRememberedSource(
        showId: Int,
        services: [Service],
        addons: [StremioAddon]
    ) -> RememberedSource? {
        guard let sourceId = rememberedSourceId(showId: showId) else { return nil }
        return resolve(sourceId: sourceId, services: services, addons: addons)
    }

    func resolve(
        sourceId: String,
        services: [Service],
        addons: [StremioAddon]
    ) -> RememberedSource? {
        if sourceId.hasPrefix("service:") {
            let value = String(sourceId.dropFirst("service:".count))
            guard let uuid = UUID(uuidString: value),
                  let service = services.first(where: { $0.id == uuid }) else { return nil }
            return .service(service)
        }

        if sourceId.hasPrefix("stremio:") {
            let value = String(sourceId.dropFirst("stremio:".count))
            guard let uuid = UUID(uuidString: value),
                  let addon = addons.first(where: { $0.id == uuid }) else { return nil }
            return .stremio(addon)
        }

        return nil
    }

    private func allPreferences() -> [String: RememberedEpisodeMatch] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [:] }

        do {
            return try JSONDecoder().decode([String: RememberedEpisodeMatch].self, from: data)
        } catch {
            Logger.shared.log("Failed to decode remembered episode matches: \(error.localizedDescription)", type: "Error")
            return [:]
        }
    }

    private func persist(_ values: [String: RememberedEpisodeMatch]) {
        do {
            let data = try JSONEncoder().encode(values)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            Logger.shared.log("Failed to encode remembered episode matches: \(error.localizedDescription)", type: "Error")
        }
    }
}
