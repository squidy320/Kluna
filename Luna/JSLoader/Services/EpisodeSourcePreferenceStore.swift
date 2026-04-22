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

struct RememberedEpisodeMatch: Codable, Equatable {
    let sourceId: String
    let providerResult: RememberedProviderResult?
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

    func setRememberedMatch(sourceId: String, providerResult: SearchItem?, for showId: Int) {
        var values = allPreferences()
        values[String(showId)] = RememberedEpisodeMatch(
            sourceId: sourceId,
            providerResult: providerResult.map(RememberedProviderResult.init(result:))
        )
        persist(values)
    }

    func setRememberedSourceId(_ sourceId: String, for showId: Int) {
        let existingResult = rememberedProviderResult(showId: showId)
        var values = allPreferences()
        values[String(showId)] = RememberedEpisodeMatch(sourceId: sourceId, providerResult: existingResult)
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
