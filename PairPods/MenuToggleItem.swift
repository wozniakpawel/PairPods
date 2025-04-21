//
//  MenuToggleItem.swift
//  PairPods
//
//  Created by m6511 on 21.04.2025.
//

import SwiftUI

struct MenuToggleItem<Label: View>: View {
    let isOn: Binding<Bool>
    let action: () -> Void
    let label: () -> Label

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    init(isOn: Binding<Bool>, action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.isOn = isOn
        self.action = action
        self.label = label
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if isHovered {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(hoverBackgroundColor)
                }
                HStack {
                    label()
                        .foregroundColor(.primary)
                    Spacer()
                    Toggle("", isOn: .constant(isOn.wrappedValue))
                        .labelsHidden()
                        .toggleStyle(.checkbox)
                        .allowsHitTesting(false)
                }
                .padding(.horizontal, 10)
            }
            .frame(height: 24)
        }
        .buttonStyle(PlainButtonStyle())
        .focusable(false)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var hoverBackgroundColor: Color {
        if colorScheme == .dark {
            Color(white: 0.9, opacity: 0.2)
        } else {
            Color(white: 0.5, opacity: 0.2)
        }
    }
}

#Preview {
    MenuToggleItem(
        isOn: .constant(false),
        action: {}
    ) {
        Text("Menu Toggle Item")
    }
    .frame(width: 300, height: 100)
}
