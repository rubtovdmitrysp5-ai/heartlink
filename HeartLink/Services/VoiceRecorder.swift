import AVFoundation
import Foundation

@MainActor
final class VoiceRecorder {
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?

    var isRecording: Bool {
        recorder?.isRecording == true
    }

    func start() async throws {
        let hasPermission = await requestMicrophonePermission()
        guard hasPermission else {
            throw VoiceRecorderError.microphoneDenied
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("heartlink_voice_\(UUID().uuidString)")
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.prepareToRecord()
        recorder.record()
        self.recorder = recorder
        recordingURL = url
    }

    func stop() throws -> VoiceRecording {
        guard let recorder, let recordingURL else {
            throw VoiceRecorderError.noRecording
        }

        let duration = max(1, recorder.currentTime)
        recorder.stop()
        self.recorder = nil
        self.recordingURL = nil

        let data = try Data(contentsOf: recordingURL)
        try? FileManager.default.removeItem(at: recordingURL)
        return VoiceRecording(data: data, duration: duration)
    }

    func cancel() {
        recorder?.stop()
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        recorder = nil
        recordingURL = nil
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

struct VoiceRecording {
    let data: Data
    let duration: TimeInterval
}

enum VoiceRecorderError: Error {
    case microphoneDenied
    case noRecording
}
