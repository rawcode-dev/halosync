// HaloSync — Profiles/ProfileStore.swift
// Protocol and UserDefaults implementation for profile persistence.

import Foundation

// MARK: - ProfileStoreError

public enum ProfileStoreError: Error {
    case notFound(id: UUID)
    case encodingFailed
    case decodingFailed
}

// MARK: - ProfileStoreProtocol

public protocol ProfileStoreProtocol: AnyObject, Sendable {
    func save(_ profile: Profile) throws
    func load(id: UUID) throws -> Profile
    func listAll() -> [Profile]
    func delete(id: UUID) throws
}

// MARK: - UserDefaultsProfileStore

/// Persists profiles as JSON in UserDefaults.
/// For v1 this is sufficient — can migrate to CoreData or CloudKit later.
public final class UserDefaultsProfileStore: ProfileStoreProtocol, @unchecked Sendable {

    private let key = "com.halosync.profiles.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        // Seed built-in profiles if first launch.
        if listAll().isEmpty {
            Profile.builtIns.forEach { try? save($0) }
        }
    }

    public func save(_ profile: Profile) throws {
        var all = storedProfiles()
        if let idx = all.firstIndex(where: { $0.id == profile.id }) {
            all[idx] = profile
        } else {
            all.append(profile)
        }
        try persist(all)
        HaloLogger.profiles.debug("Saved profile '\(profile.name)'")
    }

    public func load(id: UUID) throws -> Profile {
        guard let profile = storedProfiles().first(where: { $0.id == id }) else {
            throw ProfileStoreError.notFound(id: id)
        }
        return profile
    }

    public func listAll() -> [Profile] {
        storedProfiles()
    }

    public func delete(id: UUID) throws {
        var all = storedProfiles()
        guard let idx = all.firstIndex(where: { $0.id == id }) else {
            throw ProfileStoreError.notFound(id: id)
        }
        guard !all[idx].isBuiltIn else { return } // Cannot delete built-ins.
        all.remove(at: idx)
        try persist(all)
        HaloLogger.profiles.debug("Deleted profile \(id)")
    }

    // MARK: - Private

    private func storedProfiles() -> [Profile] {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let profiles = try? decoder.decode([Profile].self, from: data)
        else {
            return []
        }
        return profiles
    }

    private func persist(_ profiles: [Profile]) throws {
        guard let data = try? encoder.encode(profiles) else {
            throw ProfileStoreError.encodingFailed
        }
        UserDefaults.standard.set(data, forKey: key)
    }
}
