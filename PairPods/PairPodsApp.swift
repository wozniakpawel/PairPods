//
//  PairPodsApp.swift
//  PairPods
//
//  Created by Pawel Wozniak on 02/03/2024.
//

import SwiftUI

@main
struct PairPodsApp: App {
    var body: some Scene {
        MenuBarExtra("PairPods", systemImage: "airpods.gen3") {
            MenuBarContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
