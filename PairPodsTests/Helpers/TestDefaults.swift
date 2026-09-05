//
//  TestDefaults.swift
//  PairPodsTests
//

import Foundation

/// A fresh, isolated `UserDefaults` per test.
///
/// Swift Testing runs suites in parallel, and `AudioDeviceManager` persists device
/// exclusions and device order while `AudioSharingManager` persists the reconnect
/// timeout. Sharing `.standard` across concurrent tests meant one test's exclusions
/// could drop another test's selection below two devices, which is what made the
/// reconnect tests fail intermittently, and reliably so under the sanitizers, where the
/// timing shifts.
enum TestDefaults {
    static func make(_ label: String = #function) -> UserDefaults {
        let suiteName = "PairPodsTests.\(label).\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else { return .standard }
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
