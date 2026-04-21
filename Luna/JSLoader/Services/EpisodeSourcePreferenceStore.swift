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

final class EpisodeSourcePreferenceStore {
    static let shared = EpisodeSourcePreferenceStore()

    private let key = "rememberedEpisodeSourcesByShow"

    private init() {}

    func rememberedSourceId(showId: Int) -> String? {
        allPreferences()[String(showId)]
    }

    func setRememberedSourceId(_ sourceId: String, for showId: Int) {
        var values = allPreferences()
        values[String(showId)] = sourceId
        UserDefaults.standard.set(values, forKey: key)
    }

    func clearRememberedSource(for showId: Int) {
        var values = allPreferences()
        values.removeValue(forKey: String(showId))
        UserDefaults.standard.set(values, forKey: key)
    }

    func resolveRememberedSource(
        showId: Int,
        services: [Service] = ServiceManager.shared.activeServices,
        addons: [StremioAddon] = StremioAddonManager.shared.activeAddons
    ) -> RememberedSource? {
        guard let sourceId = rememberedSourceId(showId: showId) else { return nil }
        return resolve(sourceId: sourceId, services: services, addons: addons)
    }

    func resolve(
        sourceId: String,
        services: [Service] = ServiceManager.shared.activeServices,
        addons: [StremioAddon] = StremioAddonManager.shared.activeAddons
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

    private func allPreferences() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
    }
}
