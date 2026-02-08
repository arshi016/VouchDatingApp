import Foundation
import UserNotifications

public protocol NotificationScheduling {
    func requestAuthorization() async -> Bool
}

public final class LocalNotificationScheduler: NotificationScheduling {
    public init() {}

    public func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }
}
