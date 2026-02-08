import Foundation

public struct WaveQuota: Equatable, Codable {
    public var count: Int
    public var lastReset: Date

    public init(count: Int = 0, lastReset: Date = Date()) {
        self.count = count
        self.lastReset = lastReset
    }
}

public struct WaveThrottlePolicy: Equatable {
    public let maxPerDay: Int

    public init(maxPerDay: Int = 5) {
        self.maxPerDay = maxPerDay
    }
}

public struct WaveThrottler {
    private let policy: WaveThrottlePolicy
    private let calendar: Calendar

    public init(policy: WaveThrottlePolicy, calendar: Calendar = .current) {
        self.policy = policy
        self.calendar = calendar
    }

    public func canSendWave(quota: WaveQuota, now: Date = Date()) -> Bool {
        let resetQuota = normalizedQuota(quota, now: now)
        return resetQuota.count < policy.maxPerDay
    }

    public func consume(quota: WaveQuota, now: Date = Date()) -> WaveQuota {
        var updated = normalizedQuota(quota, now: now)
        updated.count += 1
        return updated
    }

    public func normalizedQuota(_ quota: WaveQuota, now: Date = Date()) -> WaveQuota {
        if calendar.isDate(quota.lastReset, inSameDayAs: now) {
            return quota
        }
        return WaveQuota(count: 0, lastReset: now)
    }
}
