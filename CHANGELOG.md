# Changelog

All notable changes to PairPods will be documented in this file.

## [0.5.0] - 2026-03-01

### Added
- Per-device share toggles — checkboxes next to each device let you choose which devices participate in sharing
- N-device audio sharing — share audio between 2 or more Bluetooth devices simultaneously (no longer limited to exactly two)
- Auto-rebuild when a device is toggled during active sharing
- Automatic reconnection when enough selected devices remain after a disconnect (2+ selected devices restart sharing immediately without waiting for timeout)
- Exclusion preferences persist across app launches

### Changed
- "Share Audio" toggle now disables when fewer than 2 devices are selected (previously checked compatible device count)
- Device selection sorting now prioritizes the majority sample rate group to minimize pitch-shifting across multiple devices
- Alert text updated to reference "selected" devices instead of "paired"

## [0.4.1] - 2026-02-28

### Added
- Automated test suite using Swift Testing framework
- Same-sample-rate device pair preference to avoid pitch-shifting

### Fixed
- Fixed aggregate device cleanup on app termination
- Fixed NotificationCenter observer leak in ContentView
- Fixed volume listeners accumulating without removal
- Fixed duplicate volume change notifications
- Fixed use-after-free in volume change listener callback
- Fixed incorrect comment about default volume fallback
- Replaced fatalError with graceful fallback in SparkleUpdater

### Changed
- Cancel in-flight tasks on cleanup and re-entry for safer state transitions
- Route stop transition through state machine for consistency
- Use mock audio system in SwiftUI previews
- Replaced deprecated APIs (onChange, NSApp.activate)
- Conformed AudioDevice to Identifiable
- Removed unused device state callback
- Volume control now works without active sharing
- Match devices by UID instead of ID when restoring output

## [0.4.0] - 2026-02-28

### Added
- Auto-reconnect when a shared device disconnects — polls for 10 seconds and automatically resumes sharing if both devices come back

### Fixed
- Fixed silent error swallowing — errors are now logged instead of silently discarded
- Fixed quit handler reliability — app termination no longer depends on an arbitrary delay
- Fixed audio pitch shifting between Bluetooth devices

### Changed
- Changed default fallback volume from 75% to 50%
- Improved logging: verbose volume-change logs demoted to debug level for cleaner output
- Extracted magic values into named constants for better maintainability
- Refactored volume change listener into focused, testable sub-methods
- Made audio sharing start/stop operations properly async

## [0.3.0] - 2025-04-24

### Added
- Added support for the Sparkle Installer XPC Service
- Added necessary app entitlements for sandboxed update installation
- Added automated workflow to update Homebrew cask on new releases

### Fixed
- Fixed and tested the update installation process
- Fixed appcast.xml structure for checking available updates

### Changed
- N/A

## [0.2.1] - 2025-04-21

### Added
- N/A

### Fixed
- Fix for the Sparkle updater issue ("error occurred while launching the installer")

### Changed
- Improved UI layout using a standardized toggle component
- Removed brew cask update step from the build & release workflow

## [0.2.0] - 2025-04-21

### Added
- Display the status and volume level for each connected audio device
- Individual volume controls for connected devices
- Real-time volume monitoring that updates when volume changes (e.g. user changes volume via hardware buttons)

### Changed
- Multiple changes to the UI, the menu now has real-time device monitoring built-in
- Switched from menuBarExtraStyle(.menu) to menuBarExtraStyle(.window) under the hood.

### Fixed
- Fixed all compiler warnings
- Code simplifications and optimizations
- UI consistency improvements

### Known Issues
- No functional issues are known
- UI/UX might need more work in the future releases, due to the change to menuBarExtraStyle(.window).

### Notes
- This release adds the most requested feature: individual volume controls for each connected device!
- Please report any issues or suggestions on the [GitHub repository](https://github.com/wozniakpawel/PairPods/issues).
- PairPods is open source and contributions are welcome. Check out the [Contributing Guidelines](https://github.com/wozniakpawel/PairPods/blob/main/CONTRIBUTING.md) for more details.

---

## [0.1.0] - Beta Release - 2025-02-26

### Added
- Initial beta release of PairPods, a macOS menubar app for sharing audio between two Bluetooth devices.
- Basic functionality to share audio between two connected Bluetooth devices.
- Menubar icon with a toggle to start and stop audio sharing.
- Homebrew installation option for easy setup.
- Sparkle integration to check for automatic updates.
- Option to Launch at login.
- Manual installation instructions for downloading and running the app directly.

### Changed
- N/A (Initial release, no changes yet)

### Fixed
- N/A (Initial release, no bug fixes yet)

### Known Issues
- N/A (Initial release, no known issues yet)

### Notes
- This is the first beta release of PairPods, and feedback is highly appreciated. Please report any issues or suggestions on the [GitHub repository](https://github.com/wozniakpawel/PairPods/issues).
- PairPods is open source and contributions are welcome. Check out the [Contributing Guidelines](https://github.com/wozniakpawel/PairPods/blob/main/CONTRIBUTING.md) for more details.

---

For future releases, this changelog will be updated to reflect new features, bug fixes, and improvements.