//
//  EmojiMetadataRepository.swift
//  DiscourseAssetKit
//

import Foundation
import os.log

private let repoLog = Logger(subsystem: "DiscourseAssetKit", category: "EmojiMetadataRepository")

public struct EmojiRefreshResult: Equatable, Sendable {
    public enum Kind: Sendable { case notModified, updated, failed }
    public let kind: Kind
    public let errorDescription: String?
}

public final class EmojiMetadataRepository: Sendable {
    public struct Config: Sendable {
        public let endpoint: URL
        public let bundledResourceName: String
        public let bundledResourceExt: String
        public let cacheFileName: String

        public init(endpoint: URL, bundledResourceName: String, bundledResourceExt: String, cacheFileName: String) {
            self.endpoint = endpoint
            self.bundledResourceName = bundledResourceName
            self.bundledResourceExt = bundledResourceExt
            self.cacheFileName = cacheFileName
        }
    }

    private let config: Config
    private let session: URLSession

    private let etagKey = "emoji_remote_etag"
    private let lastModifiedKey = "emoji_remote_last_modified"
    private let lastForegroundRefreshKey = "emoji_last_foreground_refresh_ts"

    public init(config: Config, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    // MARK: - Public

    public func loadBestAvailableData() throws -> Data {
        if let cached = try? Data(contentsOf: cacheFileURL()) {
            return cached
        }
        return try loadBundledData()
    }

    public func decode(_ data: Data) throws -> [String: [EmojiJSONEntry]] {
        let decoder = JSONDecoder()
        return try decoder.decode([String: [EmojiJSONEntry]].self, from: data)
    }

    /// Throttled "foreground refresh" (e.g., app launch / resume / open picker)
    public func refreshRemoteIfStale(minInterval: TimeInterval) async -> EmojiRefreshResult {
        let now = Date().timeIntervalSince1970
        let last = UserDefaults.standard.double(forKey: lastForegroundRefreshKey)
        if last > 0, (now - last) < minInterval {
            return EmojiRefreshResult(kind: .notModified, errorDescription: nil)
        }

        let res = await refreshRemote()
        if res.kind != .failed {
            UserDefaults.standard.set(now, forKey: lastForegroundRefreshKey)
        }
        return res
    }

    /// Unthrottled refresh (used by background task).
    public func refreshRemote() async -> EmojiRefreshResult {
        var request = URLRequest(url: config.endpoint)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData

        if let etag = UserDefaults.standard.string(forKey: etagKey) {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        if let lastModified = UserDefaults.standard.string(forKey: lastModifiedKey) {
            request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return EmojiRefreshResult(kind: .failed, errorDescription: "Non-HTTP response")
            }

            switch http.statusCode {
            case 304:
                return EmojiRefreshResult(kind: .notModified, errorDescription: nil)

            case 200:
                // Validate JSON shape before saving
                _ = try decode(data)

                // Persist headers
                if let etag = http.value(forHTTPHeaderField: "ETag") {
                    UserDefaults.standard.set(etag, forKey: etagKey)
                }
                if let lastMod = http.value(forHTTPHeaderField: "Last-Modified") {
                    UserDefaults.standard.set(lastMod, forKey: lastModifiedKey)
                }

                try atomicWrite(data: data, to: cacheFileURL())
                NotificationCenter.default.post(name: .emojiMetadataDidUpdate, object: nil)

                return EmojiRefreshResult(kind: .updated, errorDescription: nil)

            default:
                return EmojiRefreshResult(kind: .failed, errorDescription: "HTTP \(http.statusCode)")
            }
        } catch {
            return EmojiRefreshResult(kind: .failed, errorDescription: String(describing: error))
        }
    }

    // MARK: - Paths / IO

    private func loadBundledData() throws -> Data {
        guard let url = Bundle.module.url(forResource: config.bundledResourceName,
                                          withExtension: config.bundledResourceExt) else {
            throw NSError(domain: "EmojiRepo", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bundled emoji.json not found"])
        }
        return try Data(contentsOf: url)
    }

    private func cacheFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("EmojiCache", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            repoLog.warning("Failed to create emoji cache directory: \(error.localizedDescription)")
        }
        return dir.appendingPathComponent(config.cacheFileName, isDirectory: false)
    }

    /// Remove the on-disk cache file. Called when cache appears corrupted.
    public func deleteCacheFile() {
        let url = cacheFileURL()
        try? FileManager.default.removeItem(at: url)
    }

    private func atomicWrite(data: Data, to url: URL) throws {
        let tmp = url.deletingLastPathComponent()
            .appendingPathComponent(url.lastPathComponent + ".tmp")
        try data.write(to: tmp, options: [.atomic])
        // Use replaceItemAt for safe atomic swap (handles existing file)
        _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
    }
}

public extension Foundation.Notification.Name {
    static let emojiMetadataDidUpdate = Foundation.Notification.Name("emojiMetadataDidUpdate")
}
