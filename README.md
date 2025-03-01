# PairPods

<p align="center">
  <img src="PairPods/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" width="128" height="128" alt="PairPods Icon">
</p>

<p align="center">
  Share audio between two Bluetooth devices on your Mac with a single click
</p>

<p align="center">
  <a href="https://pairpods.app">
    <img src="https://img.shields.io/badge/Website-pairpods.app-blue.svg" alt="PairPods Website">
  </a>
  <a href="https://github.com/wozniakpawel/PairPods/actions/workflows/release.yml">
    <img src="https://github.com/wozniakpawel/PairPods/actions/workflows/release.yml/badge.svg" alt="Build & Release">
  </a>
  <a href="https://github.com/sponsors/wozniakpawel">
    <img src="https://img.shields.io/badge/Sponsor-GitHub-ea4aaa.svg" alt="Sponsor on GitHub">
  </a>
  <a href="https://www.buymeacoffee.com/wozniakpawel">
    <img src="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-Support-yellow.svg" alt="Buy Me A Coffee">
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="MIT License">
  </a>
</p>

## About

PairPods is a macOS menubar app that lets you share audio between two Bluetooth devices simultaneously. Whether you're watching a movie with a friend on a train or sharing your favorite music, PairPods makes it easy to create shared listening experiences.

## Features

- 🎧 Share audio between any two Bluetooth devices
- 🎵 Compatible with all macOS-supported Bluetooth audio devices
- 🔌 Simple plug-and-play interface
- ⚡️ Quick access from the menubar
- 🖥️ Native macOS app built with SwiftUI
- 💯 Completely free and open source

## Requirements

- macOS 13.5 (Ventura) or later
- Both Apple and Intel silicon are supported
- Two compatible Bluetooth audio devices

## Installation

### Homebrew

To install PairPods with Homebrew, simply run:

```bash
brew install --cask pairpods
```

### Updates
Please note that PairPods uses Sparkle to check for and notify you of new updates automatically. Homebrew does not provide update notifications.

### Manual Installation

1. Download the latest release from the [releases page](https://github.com/wozniakpawel/PairPods/releases)
2. Double click on the .zip file to unzip it.
3. Move PairPods.app to your Applications folder
4. Launch PairPods from your Applications folder

## Usage

1. Connect two Bluetooth devices to your Mac
2. Click on the PairPods menubar icon
3. Toggle "Share Audio" to start sharing
4. Toggle again to stop sharing

## Building from Source

1. Prerequisites:
   - macOS 15.0 (Sequoia) or later
   - Xcode 16.0 or later

2. Clone the repository
```bash
git clone https://github.com/wozniakpawel/PairPods.git
```

3. Open PairPods.xcodeproj in Xcode

4. Build and run the project (⌘R)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

Check out our [Contributing Guidelines](https://github.com/wozniakpawel/PairPods/blob/main/CONTRIBUTING.md) for detailed instructions on how to contribute to the project, including our development workflow and release process.

## Support

If you find PairPods useful, consider supporting its development:

- [GitHub Sponsors](https://github.com/sponsors/wozniakpawel)
- [Buy Me a Coffee](https://www.buymeacoffee.com/wozniakpawel)

## License

PairPods is MIT licensed. See [LICENSE](LICENSE) for details.
