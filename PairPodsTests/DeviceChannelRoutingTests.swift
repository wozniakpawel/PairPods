//
//  DeviceChannelRoutingTests.swift
//  PairPodsTests
//

import CoreAudio
@testable import PairPods
import Testing

struct DeviceChannelRoutingTests {
    @Test("Each device can independently play left, right, stereo, or silence")
    func rendersIndependentChannelSelections() {
        let render = ChannelRenderer(tapBufferIndex: 0, outputs: [
            .init(channelCount: 2, firstDeviceChannel: 0, monoDevice: false, channels: .left),
            .init(channelCount: 2, firstDeviceChannel: 0, monoDevice: false, channels: .right),
            .init(channelCount: 2, firstDeviceChannel: 0, monoDevice: false, channels: .left),
            .init(channelCount: 2, firstDeviceChannel: 0, monoDevice: false, channels: .right),
            .init(channelCount: 2, firstDeviceChannel: 0, monoDevice: false, channels: .stereo),
            .init(channelCount: 2, firstDeviceChannel: 0, monoDevice: false, channels: []),
        ])
        let result = samples(render, channelCounts: [2, 2, 2, 2, 2, 2])

        #expect(result == [
            [0.25, 0.25, -0.5, -0.5],
            [0.5, 0.5, -0.25, -0.25],
            [0.25, 0.25, -0.5, -0.5],
            [0.5, 0.5, -0.25, -0.25],
            [0.25, 0.5, -0.5, -0.25],
            [0, 0, 0, 0],
        ])
    }

    @Test("Stereo is preserved across split streams and mixed to mono on one-channel devices")
    func rendersSplitAndMonoOutputs() {
        let render = ChannelRenderer(tapBufferIndex: 0, outputs: [
            .init(channelCount: 1, firstDeviceChannel: 0, monoDevice: false, channels: .stereo),
            .init(channelCount: 1, firstDeviceChannel: 1, monoDevice: false, channels: .stereo),
            .init(channelCount: 1, firstDeviceChannel: 0, monoDevice: true, channels: .stereo),
        ])

        #expect(samples(render, channelCounts: [1, 1, 1]) == [
            [0.25, -0.5],
            [0.5, -0.25],
            [0.375, -0.375],
        ])
    }

    @Test("Channel choices persist by device UID across restarts")
    @MainActor func savesChannelsByUID() async {
        guard #available(macOS 14.2, *) else { return }
        let defaults = TestDefaults.make()

        let manager = AudioDeviceManager(audioSystem: MockAudioSystem(), shouldShowAlerts: false, monitorHardware: false, userDefaults: defaults)
        let firstUID = "channel-test-\(UUID())"
        let secondUID = "channel-test-\(UUID())"
        #expect(manager.channels(for: firstUID) == .stereo)
        manager.setChannels(.left, for: firstUID)
        manager.setChannels([], for: secondUID)
        await manager.cleanup()

        let reopened = AudioDeviceManager(audioSystem: MockAudioSystem(), shouldShowAlerts: false, monitorHardware: false, userDefaults: defaults)
        #expect(reopened.channels(for: firstUID) == .left)
        #expect(reopened.channels(for: secondUID).isEmpty)
        await reopened.cleanup()
    }

    private func samples(_ render: ChannelRenderer, channelCounts: [Int]) -> [[Float]] {
        var source: [Float] = [0.25, 0.5, -0.5, -0.25]
        let outputs = AudioBufferList.allocate(maximumBuffers: channelCounts.count)
        for (index, count) in channelCounts.enumerated() {
            let data = UnsafeMutablePointer<Float>.allocate(capacity: count * 2)
            data.initialize(repeating: 0, count: count * 2)
            outputs[index] = AudioBuffer(mNumberChannels: UInt32(count), mDataByteSize: UInt32(count * 2 * MemoryLayout<Float>.stride), mData: data)
        }
        defer {
            for buffer in outputs {
                buffer.mData?.deallocate()
            }
            outputs.unsafeMutablePointer.deallocate()
        }

        source.withUnsafeMutableBytes { data in
            var input = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 2, mDataByteSize: UInt32(data.count), mData: data.baseAddress))
            render.write(input: &input, output: outputs.unsafeMutablePointer)
        }
        return outputs.map { buffer in
            let data = buffer.mData?.assumingMemoryBound(to: Float.self)
            return Array(UnsafeBufferPointer(start: data, count: Int(buffer.mDataByteSize) / MemoryLayout<Float>.stride))
        }
    }
}
