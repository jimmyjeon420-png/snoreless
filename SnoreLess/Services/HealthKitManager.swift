import Foundation
import HealthKit

/// HealthKit 연동 매니저
/// 수면 분석, 심박수, HRV 데이터 읽기
class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()

    @Published var isAuthorized = false

    // MARK: - 권한 요청
    /// 수면 분석, 심박수, HRV 읽기 권한 요청
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("[HealthKit] 이 기기에서 HealthKit을 사용할 수 없습니다")
            return
        }

        let readTypes: Set<HKObjectType> = [
            HKCategoryType(.sleepAnalysis),
            HKQuantityType(.heartRate),
            HKQuantityType(.heartRateVariabilitySDNN)
        ]

        try await healthStore.requestAuthorization(toShare: Set(), read: readTypes)

        await MainActor.run {
            self.isAuthorized = true
        }
        print("[HealthKit] 권한 요청 완료")
    }

    // MARK: - 수면 데이터 가져오기
    /// 특정 날짜의 수면 단계 데이터 조회
    func fetchSleepData(for date: Date) async throws -> [HKCategorySample] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        // 수면은 전날 밤부터 시작할 수 있으므로 전날 저녁 6시부터 조회
        let queryStart = calendar.date(byAdding: .hour, value: -6, to: startOfDay) ?? startOfDay.addingTimeInterval(-21600)
        let queryEnd = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(86400)

        let sleepType = HKCategoryType(.sleepAnalysis)
        let predicate = HKQuery.predicateForSamples(
            withStart: queryStart,
            end: queryEnd,
            options: .strictStartDate
        )
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let categorySamples = (samples as? [HKCategorySample]) ?? []
                continuation.resume(returning: categorySamples)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - 심박수 가져오기
    /// 특정 시간 구간의 심박수 데이터 조회
    func fetchHeartRate(start: Date, end: Date) async throws -> [HeartRateEntry] {
        let heartRateType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let entries = (samples as? [HKQuantitySample])?.map { sample in
                    HeartRateEntry(
                        timestamp: sample.startDate,
                        bpm: sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    )
                } ?? []

                continuation.resume(returning: entries)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - HRV 가져오기
    /// 특정 시간 구간의 HRV(심박변이도) 데이터 조회
    func fetchHRV(start: Date, end: Date) async throws -> [HRVEntry] {
        let hrvType = HKQuantityType(.heartRateVariabilitySDNN)
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let entries = (samples as? [HKQuantitySample])?.map { sample in
                    HRVEntry(
                        timestamp: sample.startDate,
                        sdnn: sample.quantity.doubleValue(for: .secondUnit(with: .milli))
                    )
                } ?? []

                continuation.resume(returning: entries)
            }
            healthStore.execute(query)
        }
    }
}

// MARK: - 심박수 데이터 모델
struct HeartRateEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let bpm: Double
}

// MARK: - HRV 데이터 모델
struct HRVEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let sdnn: Double    // 밀리초 단위
}
