import AppKit
import SwiftUI

// Bootstrap AppKit — required for ImageRenderer to work
_ = NSApplication.shared

let outputDir: String = {
    if let idx = CommandLine.arguments.firstIndex(of: "--output-dir"),
       idx + 1 < CommandLine.arguments.count
    {
        return CommandLine.arguments[idx + 1]
    }
    return "/tmp/pairpods-screenshots"
}()

/// Create output directory
let fileManager = FileManager.default
try fileManager.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

let presets: [(String, ScreenshotPreset)] = [
    ("step-1", step1Preset),
    ("step-2", step2Preset),
    ("step-3", step3Preset),
]

// ImageRenderer is @MainActor; the process starts on the main thread so this is safe.
try MainActor.assumeIsolated {
    for (filename, preset) in presets {
        let view = ScreenshotView(preset: preset)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0

        guard let nsImage = renderer.nsImage,
              let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            fputs("Error: failed to encode \(filename) as PNG\n", stderr)
            exit(1)
        }

        let path = "\(outputDir)/\(filename).png"
        try pngData.write(to: URL(fileURLWithPath: path))
        let w = Int(nsImage.size.width)
        let h = Int(nsImage.size.height)
        print("Saved \(path) (\(w)x\(h) @2x)")
    }

    print("Done — generated \(presets.count) screenshots in \(outputDir)")
}
