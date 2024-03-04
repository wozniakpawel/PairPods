//
//  ContentView.swift
//  PairPods
//
//  Created by Pawel Wozniak on 02/03/2024.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AudioSharingViewModel()

    var body: some View {
        VStack {
            Toggle("Share Audio", isOn: $viewModel.isSharingAudio)
                .padding()
                .onChange(of: viewModel.isSharingAudio) {
                    viewModel.toggleAudioSharing()
                }
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
