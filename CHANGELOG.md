# Changelog

All notable changes to PairPods will be documented in this file.

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