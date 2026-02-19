// DeviceActivityReportExtension.swift
//
// IMPORTANT: This file must be added to an App Extension target in Xcode,
// NOT built by SPM. It is excluded from the SPM build via Package.swift.
//
// To use this:
// 1. In Xcode, add a "Device Activity Monitor" extension target
// 2. Add this file to that extension target
// 3. Configure the App Group "group.com.vita.shared" for both the main app
//    and the extension
// 4. The extension writes threshold breach data to shared UserDefaults,
//    which the main app reads via ScreenTimeTracker.readZombieData()

#if os(iOS)
import DeviceActivity
import Foundation

// Uncomment and build in the Xcode extension target:
//
// class VITADeviceActivityMonitor: DeviceActivityMonitor {
//
//     let appGroupID = "group.com.vita.shared"
//
//     override func eventDidReachThreshold(
//         _ event: DeviceActivityEvent.Name,
//         activity: DeviceActivityName
//     ) {
//         guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
//
//         let thresholdMinutes: Double
//         switch event.rawValue {
//         case "vita.zombie.warn":
//             thresholdMinutes = 10
//         case "vita.zombie.alert":
//             thresholdMinutes = 20
//         case "vita.zombie.critical":
//             thresholdMinutes = 30
//         default:
//             return
//         }
//
//         defaults.set(thresholdMinutes * 60, forKey: "vita_zombie_duration_seconds")
//         defaults.set("Screen Time", forKey: "vita_zombie_category_name")
//         defaults.set(Date(), forKey: "vita_zombie_timestamp")
//     }
//
//     override func intervalDidEnd(for activity: DeviceActivityName) {
//         // Reset daily tracking
//         guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
//         defaults.removeObject(forKey: "vita_zombie_duration_seconds")
//         defaults.removeObject(forKey: "vita_zombie_category_name")
//         defaults.removeObject(forKey: "vita_zombie_timestamp")
//     }
// }

#endif
