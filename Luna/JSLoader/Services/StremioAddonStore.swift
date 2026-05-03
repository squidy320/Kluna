//
//  StremioAddonStore.swift
//  Luna
//
//  Created by Soupy on 2026.
//

import CoreData

final class StremioAddonStore {
    static let shared = StremioAddonStore()

    private var container: NSPersistentContainer? = nil

    private init() {
        container = NSPersistentContainer(name: "ServiceModels")

        let storeURL: URL
#if os(tvOS)
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        storeURL = cachesDirectory.appendingPathComponent("StremioAddonStore.sqlite")
#else
        let docsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        storeURL = docsDirectory.appendingPathComponent("StremioAddonStore.sqlite")
#endif

        guard let description = container?.persistentStoreDescriptions.first else {
            Logger.shared.log("Stremio: Missing store description", type: "Storage")
            return
        }

        description.url = storeURL
        description.type = NSSQLiteStoreType
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)

        container?.loadPersistentStores { _, error in
            if let error = error {
                Logger.shared.log("Stremio: Failed to load persistent store: \(error.localizedDescription)", type: "Storage")
            } else {
                self.container?.viewContext.automaticallyMergesChangesFromParent = true
                self.container?.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            }
        }
    }

    // MARK: - CRUD

    func storeAddon(id: UUID, configuredURL: String, manifestJSON: String, isActive: Bool, sortIndex: Int64? = nil) {
        guard let container = container else {
            Logger.shared.log("Stremio: Container not initialized: storeAddon", type: "Storage")
            return
        }

        container.viewContext.performAndWait {
            let context = container.viewContext
            let fetchRequest: NSFetchRequest<StremioAddonEntity> = StremioAddonEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1

            do {
                let results = try context.fetch(fetchRequest)
                let entity: StremioAddonEntity

                if let existing = results.first {
                    entity = existing
                } else {
                    entity = StremioAddonEntity(context: context)
                    entity.id = id

                    let countRequest: NSFetchRequest<StremioAddonEntity> = StremioAddonEntity.fetchRequest()
                    countRequest.includesSubentities = false
                    let count = try context.count(for: countRequest)
                    entity.sortIndex = sortIndex ?? Int64(count)
                }

                entity.configuredURL = configuredURL
                entity.manifestJSON = manifestJSON
                entity.isActive = isActive
                if let sortIndex {
                    entity.sortIndex = sortIndex
                }

                if context.hasChanges {
                    try context.save()
                }
            } catch {
                Logger.shared.log("Stremio: Store addon failed: \(error.localizedDescription)", type: "Storage")
            }
        }
    }

    func getAddons() -> [StremioAddon] {
        guard let container = container else {
            Logger.shared.log("Stremio: Container not initialized: getAddons", type: "Storage")
            return []
        }

        var result: [StremioAddon] = []

        container.viewContext.performAndWait {
            do {
                let request: NSFetchRequest<StremioAddonEntity> = StremioAddonEntity.fetchRequest()
                request.sortDescriptors = [NSSortDescriptor(key: "sortIndex", ascending: true)]
                let entities = try container.viewContext.fetch(request)
                result = entities.compactMap { $0.asModel }
            } catch {
                Logger.shared.log("Stremio: Fetch addons failed: \(error.localizedDescription)", type: "Storage")
            }
        }

        return result
    }

    func getEntities() -> [StremioAddonEntity] {
        guard let container = container else { return [] }

        var result: [StremioAddonEntity] = []

        container.viewContext.performAndWait {
            do {
                let request: NSFetchRequest<StremioAddonEntity> = StremioAddonEntity.fetchRequest()
                request.sortDescriptors = [NSSortDescriptor(key: "sortIndex", ascending: true)]
                result = try container.viewContext.fetch(request)
            } catch {
                Logger.shared.log("Stremio: Fetch entities failed: \(error.localizedDescription)", type: "Storage")
            }
        }

        return result
    }

    func remove(_ addon: StremioAddon) {
        guard let container = container else { return }

        container.viewContext.performAndWait {
            let request: NSFetchRequest<StremioAddonEntity> = StremioAddonEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", addon.id as CVarArg)
            do {
                if let entity = try container.viewContext.fetch(request).first {
                    container.viewContext.delete(entity)
                    if container.viewContext.hasChanges {
                        try container.viewContext.save()
                    }
                }
            } catch {
                Logger.shared.log("Stremio: Remove addon failed: \(error.localizedDescription)", type: "Storage")
            }
        }
    }

    func removeAll() {
        guard let container = container else { return }

        container.viewContext.performAndWait {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "StremioAddonEntity")
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            deleteRequest.resultType = .resultTypeObjectIDs

            do {
                let result = try container.viewContext.execute(deleteRequest) as? NSBatchDeleteResult
                let objectIDs = result?.result as? [NSManagedObjectID] ?? []
                if !objectIDs.isEmpty {
                    NSManagedObjectContext.mergeChanges(
                        fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                        into: [container.viewContext]
                    )
                }
                if container.viewContext.hasChanges {
                    try container.viewContext.save()
                }
            } catch {
                Logger.shared.log("Stremio: Remove all addons failed: \(error.localizedDescription)", type: "Storage")
            }
        }
    }

    func save() {
        guard let container = container else { return }

        container.viewContext.performAndWait {
            do {
                if container.viewContext.hasChanges {
                    try container.viewContext.save()
                }
            } catch {
                Logger.shared.log("Stremio: Save failed: \(error.localizedDescription)", type: "Storage")
            }
        }
    }
}
