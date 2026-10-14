import Foundation
import Combine
import SwiftGzip

struct IraqBuildingTile: Decodable, Sendable {
    let quadKey: String
    let url: URL
    let sizeBytes: Int64
    let uploadDate: String
}

private struct IraqBuildingIndex: Decodable {
    let release: String
    let license: String
    let totalBytes: Int64
    let tiles: [IraqBuildingTile]

    static let empty = IraqBuildingIndex(release: "", license: "", totalBytes: 0, tiles: [])
}

struct IraqBuildingViewport: Hashable, Sendable {
    let west: Double
    let south: Double
    let east: Double
    let north: Double

    func intersects(_ other: IraqBuildingViewport) -> Bool {
        west <= other.east && east >= other.west && south <= other.north && north >= other.south
    }

    var cacheViewport: IraqBuildingViewport {
        let step = 0.05
        return IraqBuildingViewport(
            west: floor(west / step) * step,
            south: floor(south / step) * step,
            east: ceil(east / step) * step,
            north: ceil(north / step) * step
        )
    }

    var cacheKey: String {
        [west, south, east, north]
            .map { String(Int(($0 * 100).rounded())) }
            .joined(separator: "_")
    }
}

private struct IraqTileDownloadOutcome: Sendable {
    let quadKey: String
    let bytes: Int64
    let error: String?
}

@MainActor
final class IraqBuildingFootprintsManager: ObservableObject {
    nonisolated static let release = "2026-08-13"
    nonisolated static let minimumDisplayZoom = 10.5

    @Published private(set) var completedTileCount = 0
    @Published private(set) var downloadedBytes: Int64 = 0
    @Published private(set) var isDownloading = false
    @Published private(set) var statusKey: String?
    @Published private(set) var failedTileCount = 0
    @Published var isVisible: Bool {
        didSet { UserDefaults.standard.set(isVisible, forKey: "ottu.iraqFootprintsVisible") }
    }

    private let index: IraqBuildingIndex
    private var downloadTask: Task<Void, Never>?

    var totalTileCount: Int { index.tiles.count }
    var totalBytes: Int64 { index.totalBytes }
    var isComplete: Bool { totalTileCount > 0 && completedTileCount == totalTileCount }
    var hasDownloadedTiles: Bool { completedTileCount > 0 }
    var downloadProgress: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1, Double(downloadedBytes) / Double(totalBytes))
    }
    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
    var formattedDownloadedSize: String {
        ByteCountFormatter.string(fromByteCount: downloadedBytes, countStyle: .file)
    }

    init() {
        index = Self.loadIndex()
        isVisible = UserDefaults.standard.object(forKey: "ottu.iraqFootprintsVisible") as? Bool ?? true
        refreshAvailability()
    }

    func downloadIraq() {
        guard !isDownloading, !isComplete, !index.tiles.isEmpty else { return }
        isDownloading = true
        failedTileCount = 0
        statusKey = "iraq.downloading"
        downloadTask = Task { [weak self] in
            await self?.performDownloads()
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        statusKey = "iraq.download_paused"
    }

    func removeIraqPackage() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        try? FileManager.default.removeItem(at: Self.packageDirectory)
        try? FileManager.default.removeItem(at: Self.renderCacheDirectory)
        refreshAvailability()
        statusKey = "iraq.removed"
    }

    func visibleGeoJSONFiles(in viewport: IraqBuildingViewport, zoom: Double) async -> [String: URL] {
        guard isVisible, zoom >= Self.minimumDisplayZoom, completedTileCount > 0 else { return [:] }

        let candidates = index.tiles.filter { tile in
            Self.tileViewport(for: tile.quadKey).intersects(viewport) && Self.isDownloaded(tile, in: Self.packageDirectory)
        }
        // Avoid doing heavy conversion while the camera is zoomed out over many source partitions.
        guard !candidates.isEmpty, candidates.count <= 8 else { return [:] }

        let cacheDirectory = Self.renderCacheDirectory
        let packageDirectory = Self.packageDirectory
        let queryViewport = viewport.cacheViewport
        return await withTaskGroup(of: (String, URL?).self, returning: [String: URL].self) { group in
            var nextIndex = 0
            for _ in 0..<min(2, candidates.count) {
                let tile = candidates[nextIndex]
                nextIndex += 1
                group.addTask { await Self.render(tile, in: packageDirectory, cache: cacheDirectory, viewport: queryViewport) }
            }
            var files: [String: URL] = [:]
            for await (quadKey, url) in group {
                if let url { files[quadKey] = url }
                if nextIndex < candidates.count {
                    let tile = candidates[nextIndex]
                    nextIndex += 1
                    group.addTask { await Self.render(tile, in: packageDirectory, cache: cacheDirectory, viewport: queryViewport) }
                }
            }
            return files
        }
    }

    private nonisolated static func render(
        _ tile: IraqBuildingTile,
        in packageDirectory: URL,
        cache cacheDirectory: URL,
        viewport: IraqBuildingViewport
    ) async -> (String, URL?) {
        let compressedURL = fileURL(for: tile, in: packageDirectory)
        let outputURL = cacheDirectory.appendingPathComponent("\(tile.quadKey)_\(viewport.cacheKey).geojson")
        let work = Task.detached(priority: .utility) {
            try await makeViewportGeoJSON(from: compressedURL, to: outputURL, viewport: viewport)
        }
        do {
            let url = try await withTaskCancellationHandler {
                try await work.value
            } onCancel: {
                work.cancel()
            }
            return (tile.quadKey, url)
        } catch {
            return (tile.quadKey, nil)
        }
    }

    private func performDownloads() async {
        let packageDirectory = Self.packageDirectory
        do {
            try FileManager.default.createDirectory(at: packageDirectory, withIntermediateDirectories: true)
            let pending = index.tiles.filter { !Self.isDownloaded($0, in: packageDirectory) }
            await withTaskGroup(of: IraqTileDownloadOutcome.self) { group in
                var nextIndex = 0
                let initialCount = min(3, pending.count)
                for _ in 0..<initialCount {
                    let tile = pending[nextIndex]
                    nextIndex += 1
                    group.addTask { await Self.download(tile, into: packageDirectory) }
                }
                while let outcome = await group.next() {
                    if outcome.error == nil {
                        self.downloadedBytes += outcome.bytes
                    } else if outcome.error != "cancelled" {
                        self.failedTileCount += 1
                    }
                    self.refreshAvailability()
                    if !Task.isCancelled, nextIndex < pending.count {
                        let tile = pending[nextIndex]
                        nextIndex += 1
                        group.addTask { await Self.download(tile, into: packageDirectory) }
                    }
                }
            }
            refreshAvailability()
            isDownloading = false
            statusKey = isComplete ? "iraq.download_complete" : (failedTileCount > 0 ? "iraq.download_failed" : "iraq.download_paused")
        } catch {
            isDownloading = false
            statusKey = "iraq.download_failed"
        }
        downloadTask = nil
    }

    private func refreshAvailability() {
        let downloaded = index.tiles.filter { Self.isDownloaded($0, in: Self.packageDirectory) }
        completedTileCount = downloaded.count
        downloadedBytes = downloaded.reduce(Int64(0)) { $0 + Self.fileSize(for: $1, in: Self.packageDirectory) }
    }

    private nonisolated static func download(_ tile: IraqBuildingTile, into directory: URL) async -> IraqTileDownloadOutcome {
        let destination = fileURL(for: tile, in: directory)
        do {
            let (temporaryURL, response) = try await URLSession.shared.download(from: tile.url)
            guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let attributes = try FileManager.default.attributesOfItem(atPath: temporaryURL.path)
            let byteCount = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            guard byteCount > 0 else { throw URLError(.zeroByteResource) }
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: temporaryURL, to: destination)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var savedDestination = destination
            try? savedDestination.setResourceValues(values)
            return IraqTileDownloadOutcome(quadKey: tile.quadKey, bytes: byteCount, error: nil)
        } catch is CancellationError {
            return IraqTileDownloadOutcome(quadKey: tile.quadKey, bytes: 0, error: "cancelled")
        } catch let error as URLError where error.code == .cancelled {
            return IraqTileDownloadOutcome(quadKey: tile.quadKey, bytes: 0, error: "cancelled")
        } catch {
            return IraqTileDownloadOutcome(quadKey: tile.quadKey, bytes: 0, error: error.localizedDescription)
        }
    }

    private nonisolated static func isDownloaded(_ tile: IraqBuildingTile, in directory: URL) -> Bool {
        fileSize(for: tile, in: directory) > 0
    }

    private nonisolated static func fileSize(for tile: IraqBuildingTile, in directory: URL) -> Int64 {
        let url = fileURL(for: tile, in: directory)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber else { return 0 }
        return size.int64Value
    }

    private nonisolated static func fileURL(for tile: IraqBuildingTile, in directory: URL) -> URL {
        directory.appendingPathComponent("\(tile.quadKey).csv.gz")
    }

    private nonisolated static var packageDirectory: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("IraqBuildingFootprints-\(release)", isDirectory: true)
    }

    private nonisolated static var renderCacheDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("IraqBuildingFootprintsGeoJSON", isDirectory: true)
    }

    private nonisolated static func loadIndex() -> IraqBuildingIndex {
        guard let url = Bundle.main.url(forResource: "iraq_buildings_index", withExtension: "json")
                ?? Bundle.main.url(forResource: "iraq_buildings_index", withExtension: "json", subdirectory: "Resources"),
              let data = try? Data(contentsOf: url),
              let index = try? JSONDecoder().decode(IraqBuildingIndex.self, from: data) else { return .empty }
        return index
    }

    private nonisolated static func tileViewport(for quadKey: String) -> IraqBuildingViewport {
        var x = 0
        var y = 0
        let level = quadKey.count
        for (position, digit) in quadKey.enumerated() {
            let mask = 1 << (level - position - 1)
            switch digit {
            case "1": x |= mask
            case "2": y |= mask
            case "3": x |= mask; y |= mask
            default: break
            }
        }
        let dimension = Double(1 << level)
        let west = Double(x) / dimension * 360 - 180
        let east = Double(x + 1) / dimension * 360 - 180
        let north = Self.latitude(forMercatorY: Double(y) / dimension)
        let south = Self.latitude(forMercatorY: Double(y + 1) / dimension)
        return IraqBuildingViewport(west: west, south: south, east: east, north: north)
    }

    private nonisolated static func latitude(forMercatorY y: Double) -> Double {
        atan(sinh(.pi * (1 - 2 * y))) * 180 / .pi
    }

    private nonisolated static func makeViewportGeoJSON(from compressedURL: URL, to outputURL: URL, viewport: IraqBuildingViewport) async throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let attributes = try? fileManager.attributesOfItem(atPath: outputURL.path),
           ((attributes[.size] as? NSNumber)?.int64Value ?? 0) > 16 {
            return outputURL
        }

        let expandedURL = fileManager.temporaryDirectory.appendingPathComponent("ottu-\(UUID().uuidString).geojsonl")
        defer { try? fileManager.removeItem(at: expandedURL) }
        guard let input = InputStream(url: compressedURL),
              let expanded = OutputStream(url: expandedURL, append: false) else {
            throw URLError(.cannotOpenFile)
        }
        try await GzipDecompressor().unzip(inputStream: input, outputStream: expanded)
        try Task.checkCancellation()

        let temporaryOutput = outputURL.appendingPathExtension("\(UUID().uuidString).tmp")
        guard fileManager.createFile(atPath: temporaryOutput.path, contents: nil) else {
            throw URLError(.cannotCreateFile)
        }
        do {
            let output = try FileHandle(forWritingTo: temporaryOutput)
            try output.write(contentsOf: Data("{\"type\":\"FeatureCollection\",\"features\":[".utf8))
            var firstFeature = true
            let inputFile = try FileHandle(forReadingFrom: expandedURL)
            for try await line in inputFile.bytes.lines {
                try Task.checkCancellation()
                guard let data = line.data(using: .utf8),
                      let feature = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let geometry = feature["geometry"] as? [String: Any],
                      let coordinates = geometry["coordinates"] else { continue }
                var featureBounds = [Double.infinity, Double.infinity, -Double.infinity, -Double.infinity]
                Self.collectCoordinateBounds(coordinates, into: &featureBounds)
                guard featureBounds[0] <= viewport.east,
                      featureBounds[2] >= viewport.west,
                      featureBounds[1] <= viewport.north,
                      featureBounds[3] >= viewport.south else { continue }
                if !firstFeature { try output.write(contentsOf: Data(",".utf8)) }
                try output.write(contentsOf: data)
                firstFeature = false
            }
            try inputFile.close()
            try output.write(contentsOf: Data("]}".utf8))
            try output.close()
            try? fileManager.removeItem(at: outputURL)
            try fileManager.moveItem(at: temporaryOutput, to: outputURL)
            Self.pruneRenderCache()
            return outputURL
        } catch {
            try? fileManager.removeItem(at: temporaryOutput)
            throw error
        }
    }

    private nonisolated static func pruneRenderCache() {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: renderCacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
        ) else { return }
        let entries: [(url: URL, size: Int64, modified: Date)] = urls.compactMap { url in
            guard url.pathExtension == "geojson",
                  let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
                  let fileSize = values.fileSize else { return nil }
            return (url, Int64(fileSize), values.contentModificationDate ?? .distantPast)
        }
        var total = entries.reduce(Int64(0)) { $0 + $1.size }
        let maximumSize: Int64 = 512 * 1024 * 1024
        let targetSize: Int64 = 384 * 1024 * 1024
        guard total > maximumSize else { return }
        let cutoff = Date().addingTimeInterval(-3600)
        for entry in entries.sorted(by: { $0.modified < $1.modified }) where entry.modified < cutoff {
            try? FileManager.default.removeItem(at: entry.url)
            total -= entry.size
            if total <= targetSize { break }
        }
    }

    private nonisolated static func collectCoordinateBounds(_ value: Any, into bounds: inout [Double]) {
        if let coordinate = value as? [NSNumber], coordinate.count >= 2 {
            let longitude = coordinate[0].doubleValue
            let latitude = coordinate[1].doubleValue
            bounds[0] = min(bounds[0], longitude)
            bounds[1] = min(bounds[1], latitude)
            bounds[2] = max(bounds[2], longitude)
            bounds[3] = max(bounds[3], latitude)
            return
        }
        if let values = value as? [Any] {
            for child in values { Self.collectCoordinateBounds(child, into: &bounds) }
        }
    }
}
