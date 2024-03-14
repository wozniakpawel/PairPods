//
//  ToggleNSView.swift
//  PairPods
//
//  Created by Pawel Wozniak on 14/03/2024.
//

import AppKit

class ToggleNSView: NSView {
    var toggleSwitch = NSSwitch(frame: .zero)
    var label = NSTextField()
    var viewModel: AudioSharingViewModel!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with viewModel: AudioSharingViewModel) {
        self.viewModel = viewModel
        setupViews()
        updateToggleState()
    }
    
    private func setupViews() {
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
        
        toggleSwitch.target = self
        toggleSwitch.action = #selector(toggleAudioSharing(_:))
        
        // This ensures that the switch is aligned to the right and doesn't overlap with the text
        toggleSwitch.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        toggleSwitch.setContentCompressionResistancePriority(.required, for: .horizontal)

    }
    
    private func updateToggleState() {
         toggleSwitch.state = viewModel.isSharingAudio ? .on : .off
     }
    
    @objc func toggleAudioSharing(_ sender: NSSwitch) {
        viewModel.isSharingAudio = sender.state == .on
    }
    
}
