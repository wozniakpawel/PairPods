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

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
        setupTrackingArea()
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
    
    @objc func toggleSwitchChanged(_ sender: NSSwitch) {
          // Instead of directly calling onToggle, change the state
          // This allows the entire view to control the state change
          isSharingAudio = sender.state == .on
      }

      var isSharingAudio: Bool {
          get { toggleSwitch.state == .on }
          set {
              toggleSwitch.state = newValue ? .on : .off
              onToggle?(newValue)
          }
      }
      
      private func setupTrackingArea() {
          if let existingTrackingArea = trackingArea {
              removeTrackingArea(existingTrackingArea)
          }
          
          trackingArea = NSTrackingArea(rect: bounds, options: [.activeAlways, .mouseEnteredAndExited], owner: self, userInfo: nil)
          if let newTrackingArea = trackingArea {
              addTrackingArea(newTrackingArea)
          }
      }
      
      override func mouseEntered(with event: NSEvent) {
          super.mouseEntered(with: event)
          // Highlight the view by changing the background color or other visual cues
      }

      override func mouseExited(with event: NSEvent) {
          super.mouseExited(with: event)
          // Remove highlight
      }
      
      override func updateTrackingAreas() {
          super.updateTrackingAreas()
          setupTrackingArea()
      }

      override func mouseDown(with event: NSEvent) {
          isSharingAudio.toggle()
      }
      
      override func draw(_ dirtyRect: NSRect) {
          super.draw(dirtyRect)
          // Drawing code for custom highlight or other styles if needed
      }
    
}
