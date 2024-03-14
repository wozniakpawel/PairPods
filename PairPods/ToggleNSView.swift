//
//  ToggleNSView.swift
//  PairPods
//
//  Created by Pawel Wozniak on 14/03/2024.
//

import AppKit

class ToggleNSView: NSView {
    var toggleSwitch = NSSwitch(frame: NSRect(x: 0, y: 0, width: 40, height: 20))
    var label = NSTextField(string: "Share Audio")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(label)
        addSubview(toggleSwitch)
        
        label.translatesAutoresizingMaskIntoConstraints = false
        toggleSwitch.translatesAutoresizingMaskIntoConstraints = false
        
        label.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        label.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        label.stringValue = "Share Audio"
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        
        toggleSwitch.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        toggleSwitch.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
