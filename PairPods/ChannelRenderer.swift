//
//  ChannelRenderer.swift
//  PairPods
//

import CoreAudio

struct AudioChannels: OptionSet, Sendable {
    let rawValue: Int

    static let left = AudioChannels(rawValue: 1)
    static let right = AudioChannels(rawValue: 2)
    static let stereo: AudioChannels = [.left, .right]
}

struct ChannelRenderer {
    struct Output {
        let channelCount: Int
        let firstDeviceChannel: Int
        let monoDevice: Bool
        let channels: AudioChannels
    }

    let tapBufferIndex: Int
    let outputs: [Output]

    func write(input: UnsafePointer<AudioBufferList>, output: UnsafeMutablePointer<AudioBufferList>) {
        let inputs = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        let buffers = UnsafeMutableAudioBufferListPointer(output)
        guard tapBufferIndex < inputs.count, inputs[tapBufferIndex].mNumberChannels == 2,
              let source = inputs[tapBufferIndex].mData?.assumingMemoryBound(to: Float.self),
              buffers.count == outputs.count
        else { return }
        let inputFrames = Int(inputs[tapBufferIndex].mDataByteSize) / (2 * MemoryLayout<Float>.stride)

        // Core Audio clears the buffers before calling us. Muted and unused outputs stay silent.
        for (buffer, route) in zip(buffers, outputs) where !route.channels.isEmpty {
            guard Int(buffer.mNumberChannels) == route.channelCount,
                  let destination = buffer.mData?.assumingMemoryBound(to: Float.self)
            else { continue }
            let outputFrames = Int(buffer.mDataByteSize) / (route.channelCount * MemoryLayout<Float>.stride)
            let frames = min(inputFrames, outputFrames)
            let stereo = route.channels == .stereo
            let shouldMix = stereo && route.monoDevice
            for channel in 0 ..< route.channelCount {
                let deviceChannel = route.firstDeviceChannel + channel
                if stereo, deviceChannel > 1 {
                    break
                }
                let sourceChannel = route.channels == .right || (stereo && deviceChannel == 1) ? 1 : 0
                for frame in 0 ..< frames {
                    let sample = shouldMix
                        ? (source[2 * frame] + source[2 * frame + 1]) * 0.5
                        : source[2 * frame + sourceChannel]
                    destination[frame * route.channelCount + channel] = sample
                }
            }
        }
    }
}
