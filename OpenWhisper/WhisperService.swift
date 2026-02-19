import Foundation

class WhisperService {
    func transcribe(audioURL: URL, completion: @escaping (String?) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/whisper")
        
        // Setup environment to include Homebrew bin path for ffmpeg
        var env = ProcessInfo.processInfo.environment
        let homebrewPath = "/opt/homebrew/bin"
        if let currentPath = env["PATH"] {
            env["PATH"] = "\(homebrewPath):\(currentPath)"
        } else {
            env["PATH"] = homebrewPath
        }
        process.environment = env
        
        // Output to a temp directory to find the result
        let tempDir = FileManager.default.temporaryDirectory
        let outputDir = tempDir.appendingPathComponent("whisper_output")
        
        // Ensure output dir exists
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        // whisper [audio] --output_dir [dir] --output_format txt --model base
        process.arguments = [
            audioURL.path,
            "--output_dir", outputDir.path,
            "--output_format", "txt",
            "--model", "base",
            "--language", "en"
        ]
        
        let pipe = Pipe()
        process.standardError = pipe // Whisper often logs to stderr
        
        process.terminationHandler = { _ in
            let baseName = audioURL.deletingPathExtension().lastPathComponent
            let txtFile = outputDir.appendingPathComponent("\(baseName).txt")
            
            print("Whisper process finished. Looking for: \(txtFile.path)")
            
            if let content = try? String(contentsOf: txtFile, encoding: .utf8) {
                print("Transcription success: \(content.prefix(50))...")
                completion(content.trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                print("Failed to read transcription file at: \(txtFile.path)")
                completion(nil)
            }
            
            // Cleanup
            try? FileManager.default.removeItem(at: txtFile)
            try? FileManager.default.removeItem(at: audioURL)
        }
        
        do {
            print("Running Whisper command: \(process.executableURL?.path ?? "") \(process.arguments?.joined(separator: " ") ?? "")")
            try process.run()
        } catch {
            print("Failed to run whisper: \(error)")
            completion(nil)
        }
    }
}
