import Foundation

/// مخطط مستقبلي لعرض المناطق المخزنة؛ تنزيل النطاق الحالي تنفذه OfflineMapManager.
protocol OfflineMapManaging: Sendable {
    func availableRegionIDs() async throws -> [String]
}

/// واجهة مستقبلية لمخزن متزامن؛ الأماكن التي يضيفها المستخدم تحفظ محليًا حاليًا.
protocol MunicipalPlaceStoring: Sendable {
    func places() async throws -> [Place]
    func save(_ place: Place) async throws
}
