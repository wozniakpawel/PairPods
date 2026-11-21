//
//  DeviceChannelRouter.swift
//  PairPods
//

import CoreAudio
import Foundation

struct ChannelRoutingError: LocalizedError {
    let message: String
    let status: OSStatus?

    init(_ message: String, status: OSStatus? = nil) {
        self.message = message
        self.status = status
    }

    var errorDescription: String? {
        status.map { "\(message) (Core Audio: \($0))" } ?? message
    }
}

final class DeviceChannelRouter: Sendable {
    private let aggregateID: AudioDeviceID
    private let tapID: AudioObjectID
    private let ioProc: AudioDeviceIOProcID

    @available(macOS 14.2, *)
    init(routes: [(device: AudioDevice, channels: AudioChannels)]) throws {
        // A private aggregate lets us address each device separately without changing the Mac's output.
        let tap = CATapDescription(stereoGlobalTapButExcludeProcesses: Self.currentProcessObjects())
        tap.name = "PairPods Channel Routing"
        tap.isPrivate = true
        tap.muteBehavior = .mutedWhenTapped

        let captureError = "Can’t capture system audio. Check PairPods in System Settings → Privacy & Security → Screen & System Audio Recording."
        var tapID = AudioObjectID(kAudioObjectUnknown)
        try Self.check(AudioHardwareCreateProcessTap(tap, &tapID), captureError)
        var aggregateID = AudioDeviceID(kAudioObjectUnknown)
        var ioProc: AudioDeviceIOProcID?
        do {
            let master = routes[0].device.uid
            let composition: [String: Any] = [
                kAudioAggregateDeviceNameKey: "PairPods Channel Routing",
                kAudioAggregateDeviceUIDKey: UUID().uuidString,
                kAudioAggregateDeviceMasterSubDeviceKey: master,
                kAudioAggregateDeviceIsPrivateKey: 1,
                kAudioAggregateDeviceIsStackedKey: 0,
                kAudioAggregateDeviceSubDeviceListKey: routes.map { route in
                    let uid = route.device.uid
                    return [kAudioSubDeviceUIDKey: uid, kAudioSubDeviceDriftCompensationKey: uid == master ? 0 : 1]
                },
                kAudioAggregateDeviceTapListKey: [[kAudioSubTapUIDKey: tap.uuid.uuidString, kAudioSubTapDriftCompensationKey: 1]],
            ]
            try Self.check(AudioHardwareCreateAggregateDevice(composition as CFDictionary, &aggregateID), "Couldn’t combine the selected devices")

            let render = try ChannelRenderer(aggregate: aggregateID, routes: routes)
            try Self.check(AudioDeviceCreateIOProcIDWithBlock(&ioProc, aggregateID, nil) { _, input, _, output, _ in
                render.write(input: input, output: output)
            }, "Couldn’t prepare channel routing")
            guard let ioProc else { throw ChannelRoutingError("Couldn’t prepare channel routing.") }
            try render.useOnlyTapInput(aggregate: aggregateID, ioProc: ioProc)
            try Self.check(AudioDeviceStart(aggregateID, ioProc), captureError)
            self.tapID = tapID
            self.aggregateID = aggregateID
            self.ioProc = ioProc
        } catch {
            if let ioProc {
                AudioDeviceDestroyIOProcID(aggregateID, ioProc)
            }
            if aggregateID != kAudioObjectUnknown {
                AudioHardwareDestroyAggregateDevice(aggregateID)
            }
            AudioHardwareDestroyProcessTap(tapID)
            throw error
        }
    }

    deinit {
        AudioDeviceStop(aggregateID, ioProc)
        AudioDeviceDestroyIOProcID(aggregateID, ioProc)
        AudioHardwareDestroyAggregateDevice(aggregateID)
        if #available(macOS 14.2, *) {
            AudioHardwareDestroyProcessTap(tapID)
        }
    }

    @available(macOS 14.2, *)
    private static func currentProcessObjects() -> [AudioObjectID] {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var address = system.getPropertyAddress(selector: kAudioHardwarePropertyTranslatePIDToProcessObject)
        var pid = getpid()
        var process = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(system, &address, UInt32(MemoryLayout<pid_t>.size), &pid, &size, &process)
        return status == noErr && process != kAudioObjectUnknown ? [process] : []
    }

    fileprivate static func check(_ status: OSStatus, _ action: String) throws {
        guard status == noErr else { throw ChannelRoutingError(action, status: status) }
    }
}

private extension ChannelRenderer {
    init(aggregate: AudioDeviceID, routes: [(device: AudioDevice, channels: AudioChannels)]) throws {
        let layoutError = ChannelRoutingError("Can’t route channels to these audio devices.")
        let inputStreams = try Self.streamFormats(on: aggregate, scope: kAudioObjectPropertyScopeInput)
        guard let lastInput = inputStreams.indices.last,
              inputStreams[lastInput].mChannelsPerFrame == 2,
              Self.isInterleavedFloat32(inputStreams[lastInput])
        else { throw layoutError }

        var outputRoutes: [Output] = []
        // The aggregate's subdevice order determines the order of its output streams.
        for (device, channels) in routes {
            let streams = try Self.streamFormats(on: device.id, scope: kAudioObjectPropertyScopeOutput)
                .map { Int($0.mChannelsPerFrame) }
            let totalChannels = streams.reduce(0, +)
            guard totalChannels > 0 else { throw layoutError }
            var firstDeviceChannel = 0
            for channelCount in streams {
                outputRoutes.append(Output(
                    channelCount: channelCount,
                    firstDeviceChannel: firstDeviceChannel,
                    monoDevice: totalChannels == 1,
                    channels: channels
                ))
                firstDeviceChannel += channelCount
            }
        }
        let outputStreams = try Self.streamFormats(on: aggregate, scope: kAudioObjectPropertyScopeOutput)
        guard outputStreams.allSatisfy(Self.isInterleavedFloat32),
              outputStreams.map({ Int($0.mChannelsPerFrame) }) == outputRoutes.map(\.channelCount)
        else { throw layoutError }
        self.init(tapBufferIndex: lastInput, outputs: outputRoutes)
    }

    func useOnlyTapInput(aggregate: AudioDeviceID, ioProc: AudioDeviceIOProcID) throws {
        // A duplex Bluetooth device can contribute input streams before the tap. Leave those inputs off.
        guard tapBufferIndex > 0 else { return }
        guard let offset = MemoryLayout<AudioHardwareIOProcStreamUsage>.offset(of: \.mStreamIsOn) else {
            throw ChannelRoutingError("Couldn’t select the system audio input.")
        }
        let inputCount = tapBufferIndex + 1
        let size = MemoryLayout<AudioHardwareIOProcStreamUsage>.size + tapBufferIndex * MemoryLayout<UInt32>.stride
        let data = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: MemoryLayout<AudioHardwareIOProcStreamUsage>.alignment)
        defer { data.deallocate() }
        data.assumingMemoryBound(to: AudioHardwareIOProcStreamUsage.self).initialize(to: AudioHardwareIOProcStreamUsage(
            mIOProc: unsafeBitCast(ioProc, to: UnsafeMutableRawPointer.self),
            mNumberStreams: UInt32(inputCount),
            mStreamIsOn: 0
        ))
        let usage = data.advanced(by: offset).assumingMemoryBound(to: UInt32.self)
        for index in 0 ..< inputCount {
            usage[index] = index == tapBufferIndex ? 1 : 0
        }
        var address = aggregate.getPropertyAddress(selector: kAudioDevicePropertyIOProcStreamUsage, scope: kAudioDevicePropertyScopeInput)
        try DeviceChannelRouter.check(AudioObjectSetPropertyData(aggregate, &address, 0, nil, UInt32(size), data), "Couldn’t select the system audio input")
    }

    private static func streamFormats(on device: AudioDeviceID, scope: AudioObjectPropertyScope) throws -> [AudioStreamBasicDescription] {
        var address = device.getPropertyAddress(selector: kAudioDevicePropertyStreams, scope: scope)
        var size: UInt32 = 0
        try DeviceChannelRouter.check(AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size), "Couldn’t read the audio stream layout")
        guard size > 0 else { return [] }
        var streamIDs = [AudioStreamID](repeating: 0, count: Int(size) / MemoryLayout<AudioStreamID>.stride)
        try DeviceChannelRouter.check(AudioObjectGetPropertyData(device, &address, 0, nil, &size, &streamIDs), "Couldn’t read the audio stream layout")
        return try streamIDs.prefix(Int(size) / MemoryLayout<AudioStreamID>.stride).map { stream in
            var format = AudioStreamBasicDescription()
            var formatSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            var formatAddress = stream.getPropertyAddress(selector: kAudioStreamPropertyVirtualFormat)
            try DeviceChannelRouter.check(AudioObjectGetPropertyData(stream, &formatAddress, 0, nil, &formatSize, &format), "Couldn’t read the audio stream format")
            return format
        }
    }

    private static func isInterleavedFloat32(_ format: AudioStreamBasicDescription) -> Bool {
        let flags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsNonInterleaved
        return format.mFormatID == kAudioFormatLinearPCM &&
            format.mChannelsPerFrame > 0 &&
            format.mFormatFlags & flags == kAudioFormatFlagsNativeFloatPacked &&
            format.mBitsPerChannel == 32 &&
            format.mBytesPerFrame == format.mChannelsPerFrame * UInt32(MemoryLayout<Float>.stride)
    }
}
