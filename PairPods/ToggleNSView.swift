//
//  ToggleNSView.swift
//  PairPods
//
//  Created by Pawel Wozniak on 14/03/2024.
//

import AppKit

class ToggleNSView: NSView {
    var toggleSwitch = NSSwitch(frame: .zero)
    var label = NSTextField(string: "Share Audio")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(label)
        addSubview(toggleSwitch)
        
        label.translatesAutoresizingMaskIntoConstraints = false
        toggleSwitch.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15), // Add padding to the label
            label.trailingAnchor.constraint(lessThanOrEqualTo: toggleSwitch.leadingAnchor, constant: -10), // Ensure there is space between label and switch
            
            toggleSwitch.centerYAnchor.constraint(equalTo: centerYAnchor),
            toggleSwitch.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10) // Add some padding to the right of the toggle switch
        ])
        
        label.stringValue = "Share Audio"
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        
        // This ensures that the switch is aligned to the right and doesn't overlap with the text
        toggleSwitch.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        toggleSwitch.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
