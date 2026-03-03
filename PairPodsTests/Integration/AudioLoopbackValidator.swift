//
//  AudioLoopbackValidator.swift
//  PairPodsTests
//

import Accelerate
import AVFoundation
import CoreAudio

struct ValidationResult {
    let passed: Bool
    let silenceIntervals: [(startSeconds: Double, durationSeconds: Double)]
    let detectedFrequency: Double? // nil if no audio detected at all
    let artifactPath: String? // path to .wav file on failure
    let failureDescription: String? // human-readable failure reason
}

/// Thread-safe sample accumulator for audio tap callbacks.
private final class SampleAccumulator: @unchecked Sendable {
    private var samples: [Float] = []
    private let lock = NSLock()

    func append(_ buffer: UnsafePointer<Float>, count: Int) {
        lock.lock()
        samples.append(contentsOf: UnsafeBufferPointer(start: buffer, count: count))
        lock.unlock()
    }

    func drain() -> [Float] {
        lock.lock()
        let result = samples
        lock.unlock()
        return result
    }

    func reserveCapacity(_ n: Int) {
        lock.lock()
        samples.reserveCapacity(n)
        lock.unlock()
    }
}

final class AudioLoopbackValidator {
    let outputDeviceID: AudioDeviceID // the aggregate device
    let captureDeviceName: String // "BlackHole 2ch"
    let durationSeconds: Double
    let toneFrequency: Double = 440.0
    let silenceThresholdLinear: Float = 0.001 // ~ -60dB
    let silenceMinDurationSeconds: Double = 0.1 // 100ms
    let pitchTolerancePercent: Double = 2.0

    init(outputDeviceID: AudioDeviceID, captureDeviceName: String = "BlackHole 2ch", durationSeconds: Double = 30) {
        self.outputDeviceID = outputDeviceID
        self.captureDeviceName = captureDeviceName
        self.durationSeconds = durationSeconds
    }

    func validate() async throws -> ValidationResult {
        // 1. Find the capture device (BlackHole 2ch input)
        let captureDeviceUID = try findCaptureDevice()

        // 2. Set up playback engine → output to aggregate device
        let playbackEngine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        playbackEngine.attach(playerNode)

        let sampleRate = playbackEngine.outputNode.outputFormat(forBus: 0).sampleRate
        let actualSampleRate = sampleRate > 0 ? sampleRate : 48000.0
        let format = AVAudioFormat(standardFormatWithSampleRate: actualSampleRate, channels: 2)!

        playbackEngine.connect(playerNode, to: playbackEngine.mainMixerNode, format: format)

        // Set the output device on the playback engine
        try setAudioUnitDevice(playbackEngine.outputNode.audioUnit!, deviceID: outputDeviceID)

        // Generate tone buffer for the full duration (looped)
        let loopDurationSeconds = 1.0
        let loopFrameCount = Int(actualSampleRate * loopDurationSeconds)
        let toneBuffer = generateSineBuffer(sampleRate: actualSampleRate, frameCount: loopFrameCount)

        // 3. Set up capture engine → input from BlackHole 2ch
        let captureEngine = AVAudioEngine()
        try setAudioUnitDevice(captureEngine.inputNode.audioUnit!, deviceID: captureDeviceUID)

        let captureFormat = captureEngine.inputNode.inputFormat(forBus: 0)
        let captureSampleRate = captureFormat.sampleRate > 0 ? captureFormat.sampleRate : actualSampleRate
        let totalCaptureFrames = Int(captureSampleRate * durationSeconds)
        let accumulator = SampleAccumulator()
        accumulator.reserveCapacity(totalCaptureFrames)

        // 4. Install tap on capture engine's input node
        captureEngine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: captureFormat) { buffer, _ in
            guard let channelData = buffer.floatChannelData else { return }
            let frameCount = Int(buffer.frameLength)
            accumulator.append(channelData[0], count: frameCount)
        }

        // 5. Start both engines
        try playbackEngine.start()
        try captureEngine.start()

        // Schedule tone buffer to loop for the duration
        let loopCount = Int(ceil(durationSeconds / loopDurationSeconds))
        for _ in 0 ..< loopCount {
            playerNode.scheduleBuffer(toneBuffer, completionCallbackType: .dataPlayedBack, completionHandler: nil)
        }
        playerNode.play()

        // 6. Wait for duration
        try await Task.sleep(for: .seconds(durationSeconds))

        // 7. Stop both engines
        playerNode.stop()
        playbackEngine.stop()
        captureEngine.inputNode.removeTap(onBus: 0)
        captureEngine.stop()

        // 8. Analyze captured audio
        let samples = accumulator.drain()

        guard !samples.isEmpty else {
            return ValidationResult(
                passed: false,
                silenceIntervals: [],
                detectedFrequency: nil,
                artifactPath: nil,
                failureDescription: "No audio samples captured"
            )
        }

        // Run silence detection
        let silenceIntervals = detectSilence(samples: samples, sampleRate: captureSampleRate)

        // Run pitch detection
        let detectedFrequency = detectDominantFrequency(samples: samples, sampleRate: captureSampleRate)

        // Determine pass/fail
        var failures: [String] = []

        if !silenceIntervals.isEmpty {
            let totalSilence = silenceIntervals.reduce(0.0) { $0 + $1.durationSeconds }
            failures.append("Detected \(silenceIntervals.count) silence interval(s) totaling \(String(format: "%.2f", totalSilence))s")
        }

        if let freq = detectedFrequency {
            let tolerance = toneFrequency * pitchTolerancePercent / 100.0
            if abs(freq - toneFrequency) > tolerance {
                failures.append("Pitch shift detected: expected \(toneFrequency)Hz, got \(String(format: "%.1f", freq))Hz")
            }
        } else {
            failures.append("Could not detect dominant frequency (no audio signal)")
        }

        let passed = failures.isEmpty
        var artifactPath: String?

        if !passed {
            artifactPath = saveArtifact(samples: samples, sampleRate: captureSampleRate, label: "regression-failure")
        }

        return ValidationResult(
            passed: passed,
            silenceIntervals: silenceIntervals,
            detectedFrequency: detectedFrequency,
            artifactPath: artifactPath,
            failureDescription: passed ? nil : failures.joined(separator: "; ")
        )
    }

    // MARK: - Private

    private func findCaptureDevice() throws -> AudioDeviceID {
        let systemObject = AudioObjectID(kAudioObjectSystemObject)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var propSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &propSize) == noErr else {
            throw ValidationError.deviceNotFound(captureDeviceName)
        }

        let deviceCount = Int(propSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        guard AudioObjectGetPropertyData(systemObject, &address, 0, nil, &propSize, &deviceIDs) == noErr else {
            throw ValidationError.deviceNotFound(captureDeviceName)
        }

        for deviceID in deviceIDs {
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var cfName: Unmanaged<CFString>?
            var nameSize = UInt32(MemoryLayout<CFString?>.size)
            guard AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &cfName) == noErr,
                  let name = cfName?.takeRetainedValue() as String?
            else { continue }

            if name == captureDeviceName {
                return deviceID
            }
        }

        throw ValidationError.deviceNotFound(captureDeviceName)
    }

    private func setAudioUnitDevice(_ audioUnit: AudioUnit, deviceID: AudioDeviceID) throws {
        var devID = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &devID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            throw ValidationError.audioUnitError("Failed to set device on audio unit. Status: \(status)")
        }
    }

    private func generateSineBuffer(sampleRate: Double, frameCount: Int) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount))!
        buffer.frameLength = AVAudioFrameCount(frameCount)

        let omega = 2.0 * Double.pi * toneFrequency / sampleRate
        for i in 0 ..< frameCount {
            let sample = Float(sin(omega * Double(i))) * 0.5 // amplitude 0.5
            buffer.floatChannelData![0][i] = sample
            buffer.floatChannelData![1][i] = sample
        }

        return buffer
    }

    private func detectSilence(samples: [Float], sampleRate: Double) -> [(startSeconds: Double, durationSeconds: Double)] {
        let windowSize = min(2048, samples.count)
        let stride = windowSize / 2
        var silenceIntervals: [(startSeconds: Double, durationSeconds: Double)] = []
        var silenceStartSample: Int?

        var offset = 0
        while offset + windowSize <= samples.count {
            var rms: Float = 0
            samples.withUnsafeBufferPointer { ptr in
                vDSP_rmsqv(ptr.baseAddress! + offset, 1, &rms, vDSP_Length(windowSize))
            }

            if rms < silenceThresholdLinear {
                if silenceStartSample == nil {
                    silenceStartSample = offset
                }
            } else {
                if let start = silenceStartSample {
                    let durationSamples = offset - start
                    let durationSecs = Double(durationSamples) / sampleRate
                    if durationSecs >= silenceMinDurationSeconds {
                        silenceIntervals.append((
                            startSeconds: Double(start) / sampleRate,
                            durationSeconds: durationSecs
                        ))
                    }
                    silenceStartSample = nil
                }
            }

            offset += stride
        }

        // Handle trailing silence
        if let start = silenceStartSample {
            let durationSamples = samples.count - start
            let durationSecs = Double(durationSamples) / sampleRate
            if durationSecs >= silenceMinDurationSeconds {
                silenceIntervals.append((
                    startSeconds: Double(start) / sampleRate,
                    durationSeconds: durationSecs
                ))
            }
        }

        return silenceIntervals
    }

    private func detectDominantFrequency(samples: [Float], sampleRate: Double) -> Double? {
        let fftSize = 4096
        guard samples.count >= fftSize else { return nil }

        // Take a chunk from the middle of the recording
        let midpoint = samples.count / 2
        let startIdx = midpoint - fftSize / 2
        guard startIdx >= 0 else { return nil }

        var chunk = Array(samples[startIdx ..< startIdx + fftSize])

        // Check that the chunk has actual audio (not silence)
        var chunkRms: Float = 0
        vDSP_rmsqv(&chunk, 1, &chunkRms, vDSP_Length(fftSize))
        guard chunkRms > silenceThresholdLinear else { return nil }

        // Apply Hann window
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(chunk, 1, window, 1, &chunk, 1, vDSP_Length(fftSize))

        // FFT setup
        let log2n = vDSP_Length(log2(Float(fftSize)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return nil }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        // Prepare split complex and perform FFT
        let halfSize = fftSize / 2
        var realPart = [Float](repeating: 0, count: halfSize)
        var imagPart = [Float](repeating: 0, count: halfSize)
        var magnitudes = [Float](repeating: 0, count: halfSize)

        // Pack input, run FFT, compute magnitudes — all within safe pointer scope
        realPart.withUnsafeMutableBufferPointer { realBuf in
            imagPart.withUnsafeMutableBufferPointer { imagBuf in
                var split = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)

                // Pack input into split complex form
                chunk.withUnsafeBufferPointer { inputPtr in
                    inputPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfSize) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &split, 1, vDSP_Length(halfSize))
                    }
                }

                // Perform FFT
                vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))

                // Compute magnitude spectrum
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(halfSize))
            }
        }

        // Find peak bin (skip bin 0 = DC)
        var maxMag: Float = 0
        var maxIdx: vDSP_Length = 0
        vDSP_maxvi(Array(magnitudes.dropFirst()), 1, &maxMag, &maxIdx, vDSP_Length(halfSize - 1))
        let peakBin = Int(maxIdx) + 1 // offset for skipping DC

        // Convert to frequency
        return Double(peakBin) * sampleRate / Double(fftSize)
    }

    private func saveArtifact(samples: [Float], sampleRate: Double, label: String) -> String? {
        let artifactsDir = "PairPodsTests/Integration/Artifacts"
        let fileManager = FileManager.default

        // Determine the project root by looking for PairPodsTests directory
        var projectRoot = fileManager.currentDirectoryPath
        if !fileManager.fileExists(atPath: "\(projectRoot)/PairPodsTests") {
            // Try to find it relative to the test bundle
            if let bundlePath = Bundle.main.resourcePath {
                projectRoot = (bundlePath as NSString).deletingLastPathComponent
            }
        }

        let fullDir = "\(projectRoot)/\(artifactsDir)"
        try? fileManager.createDirectory(atPath: fullDir, withIntermediateDirectories: true)

        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let filePath = "\(fullDir)/\(label)-\(timestamp).wav"

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
            return nil
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        memcpy(buffer.floatChannelData![0], samples, samples.count * MemoryLayout<Float>.size)

        guard let audioFile = try? AVAudioFile(
            forWriting: URL(fileURLWithPath: filePath),
            settings: format.settings
        ) else { return nil }

        try? audioFile.write(from: buffer)
        return filePath
    }

    enum ValidationError: Error {
        case deviceNotFound(String)
        case audioUnitError(String)
    }
}
