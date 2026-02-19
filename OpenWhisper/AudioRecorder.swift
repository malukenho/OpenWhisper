import Foundation
import AVFoundation

class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    private var audioRecorder: AVAudioRecorder?
    private let audioFilename: URL
    
    override init() {
        let tempDir = FileManager.default.temporaryDirectory
        self.audioFilename = tempDir.appendingPathComponent("recording.wav")
        super.init()
    }
    
    func startRecording() {
        print("Starting recording at: \(audioFilename.path)")
        let settings = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            let started = audioRecorder?.record() ?? false
            if started {
                print("Successfully started recording at: \(audioFilename.path)")
            } else {
                print("Failed to start recording (record() returned false)")
            }
        } catch {
            print("Could not start recording: \(error)")
        }
    }
    
    func updateMeters() -> Float {
        guard let recorder = audioRecorder, recorder.isRecording else { return -160.0 }
        recorder.updateMeters()
        let level = recorder.averagePower(forChannel: 0)
        // print("Audio Level: \(level)") // Uncomment for debug
        return level
    }
    
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        audioRecorder = nil
        print("Recording stopped.")
        return audioFilename
    }
}
