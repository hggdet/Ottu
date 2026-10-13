import CoreLocation
import Combine
import Foundation
import MapLibre

@MainActor
final class OfflineMapManager: ObservableObject {
    @Published private(set) var progress: Double?
    @Published private(set) var statusKey: String?
    @Published private(set) var isDownloading = false
    @Published private(set) var hasOfflineArea = false

    var offlineAreaSize: String? {
        guard let pack = currentAreaPack else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(pack.progress.countOfBytesCompleted), countStyle: .file)
    }

    private var progressObserver: NSObjectProtocol?
    private var errorObserver: NSObjectProtocol?

    init() {
        progressObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.MLNOfflinePackProgressChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let pack = notification.object as? MLNOfflinePack else { return }
            guard String(data: pack.context, encoding: .utf8) == "ottu-current-area-v1" else { return }
            let completed = pack.progress.countOfResourcesCompleted
            let expected = pack.progress.countOfResourcesExpected
            Task { @MainActor in
                guard expected > 0 else { return }
                let fraction = min(1, Double(completed) / Double(expected))
                self?.progress = fraction
                self?.statusKey = fraction >= 1 ? "offline.complete" : "offline.downloading"
                self?.isDownloading = fraction < 1
            }
        }
        errorObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.MLNOfflinePackError,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let pack = notification.object as? MLNOfflinePack,
                  String(data: pack.context, encoding: .utf8) == "ottu-current-area-v1" else { return }
            Task { @MainActor in
                self?.hasOfflineArea = true
                self?.statusKey = "offline.failed"
                self?.isDownloading = false
            }
        }
        if let pack = currentAreaPack {
            hasOfflineArea = true
            let completed = pack.progress.countOfResourcesCompleted
            let expected = pack.progress.countOfResourcesExpected
            if expected > 0 {
                progress = min(1, Double(completed) / Double(expected))
                isDownloading = progress.map { $0 < 1 } ?? false
                statusKey = isDownloading ? "offline.downloading" : "offline.complete"
                if isDownloading { pack.resume() }
            }
        }
    }

    deinit {
        if let progressObserver { NotificationCenter.default.removeObserver(progressObserver) }
        if let errorObserver { NotificationCenter.default.removeObserver(errorObserver) }
    }

    func downloadArea(around center: GeoCoordinate, styleURL: URL) {
        guard !isDownloading, (progress ?? 0) < 1 else {
            if isDownloading { statusKey = "offline.downloading"; return }
            statusKey = "offline.already_complete"
            return
        }
        // نطاق تقريبي صغير حول المركز الحالي، لتجنب تنزيل عدد ضخم من البلاطات.
        let delta = 0.035
        let southWest = CLLocationCoordinate2D(latitude: center.latitude - delta, longitude: center.longitude - delta)
        let northEast = CLLocationCoordinate2D(latitude: center.latitude + delta, longitude: center.longitude + delta)
        let bounds = MLNCoordinateBounds(sw: southWest, ne: northEast)
        let region = MLNTilePyramidOfflineRegion(
            styleURL: styleURL,
            bounds: bounds,
            fromZoomLevel: 9,
            toZoomLevel: 14
        )
        let context = Data("ottu-current-area-v1".utf8)
        statusKey = "offline.starting"
        isDownloading = true
        MLNOfflineStorage.shared.addPack(for: region, withContext: context) { [weak self] pack, error in
            guard let pack, error == nil else {
                Task { @MainActor in
                    self?.statusKey = "offline.failed"
                    self?.isDownloading = false
                }
                return
            }
            pack.resume()
            Task { @MainActor in
                self?.hasOfflineArea = true
                self?.progress = 0
                self?.statusKey = "offline.downloading"
            }
        }
    }

    func removeDownloadedArea() {
        guard let pack = currentAreaPack else {
            hasOfflineArea = false
            progress = nil
            isDownloading = false
            statusKey = nil
            return
        }
        statusKey = "offline.removing"
        MLNOfflineStorage.shared.removePack(pack) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if error == nil {
                    self.hasOfflineArea = false
                    self.progress = nil
                    self.isDownloading = false
                    self.statusKey = "offline.removed"
                } else {
                    self.statusKey = "offline.remove_failed"
                }
            }
        }
    }

    private var currentAreaPack: MLNOfflinePack? {
        MLNOfflineStorage.shared.packs?.first {
            String(data: $0.context, encoding: .utf8) == "ottu-current-area-v1"
        }
    }
}
