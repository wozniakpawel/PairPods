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
    var onToggle: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?
    private var effectView: NSVisualEffectView?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
        setupEffectView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

    @objc func toggleAudioSharing(_ sender: NSSwitch) {
        onToggle?(sender.state == .on)
    }
 
      var isSharingAudio: Bool {
          get { toggleSwitch.state == .on }
          set {
              toggleSwitch.state = newValue ? .on : .off
              onToggle?(newValue)
          }
      }
    
    private func setupEffectView() {
        effectView = NSVisualEffectView()
        effectView?.blendingMode = .withinWindow
        effectView?.state = .active
        effectView?.isHidden = true // Initially hidden
        addSubview(effectView!, positioned: .below, relativeTo: nil)
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let existingTrackingArea = trackingArea {
            removeTrackingArea(existingTrackingArea)
        }
        
        trackingArea = NSTrackingArea(rect: bounds, options: [.activeAlways, .mouseEnteredAndExited], owner: self, userInfo: nil)
        if let newTrackingArea = trackingArea {
            addTrackingArea(newTrackingArea)
        }
    }
    
    override func layout() {
        super.layout()
        effectView?.frame = bounds
    }

      override func mouseEntered(with event: NSEvent) {
          super.mouseEntered(with: event)
          effectView?.isHidden = false
          effectView?.material = .selection
      }

      override func mouseExited(with event: NSEvent) {
          super.mouseExited(with: event)
          effectView?.isHidden = true
      }

      override func mouseDown(with event: NSEvent) {
          isSharingAudio.toggle()
      }
      
}
