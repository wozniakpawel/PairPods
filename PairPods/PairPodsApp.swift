//
//  PairPodsApp.swift
//  PairPods
//
//  Created by Pawel Wozniak on 02/03/2024.
//

import SwiftUI

func prepareMenuIcon(imageName: String, targetWidth: CGFloat) -> NSImage {
    guard let originalImage = NSImage(systemSymbolName: imageName, accessibilityDescription: nil) else { return NSImage() }
    
    let paddedImage = NSImage(size: NSSize(width: targetWidth, height: originalImage.size.height))
    paddedImage.lockFocus()
    let xPosition = (targetWidth - originalImage.size.width) / 2
    originalImage.draw(at: CGPoint(x: xPosition, y: 0), from: .zero, operation: .sourceOver, fraction: 1)
    paddedImage.unlockFocus()
    
    return paddedImage
}

@main
struct PairPodsApp: App {
    @StateObject private var viewModel = AudioSharingViewModel()
    
    var body: some Scene {
        
        MenuBarExtra {
            
            Toggle(isOn: $viewModel.isSharingAudio) {
                Text("Share Audio")
            }.keyboardShortcut("s")

            Divider()

            Button("About") {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "PairPods\nVersion: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")\nVertex Forge © \(Calendar.current.component(.year, from: Date()))"
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }.keyboardShortcut("a")
            
            Button("Quit") {
                viewModel.isSharingAudio = false
                NSApplication.shared.terminate(nil)
            }.keyboardShortcut("q")
            
        } label: {
            let iconName = viewModel.isSharingAudio ? "airpodspro.chargingcase.wireless.radiowaves.left.and.right.fill" : "airpodspro.chargingcase.wireless.fill"
            let menuIcon = prepareMenuIcon(imageName: iconName, targetWidth: 30)
            Image(nsImage: menuIcon)
        }
    }
}
