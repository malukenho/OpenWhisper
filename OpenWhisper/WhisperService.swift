import Foundation

class WhisperService {
    func transcribe(
        audioURL: URL,
        whisperPath: String,
        ffmpegPath: String,
        model: String = "base",
        language: String = "",
        initialPrompt: String = "",
        completion: @escaping (String?) -> Void
    ) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: whisperPath)
        
        // Add ffmpeg's directory to PATH so whisper can find it
        let ffmpegDir = URL(fileURLWithPath: ffmpegPath).deletingLastPathComponent().path
        var env = ProcessInfo.processInfo.environment
        if let currentPath = env["PATH"] {
            env["PATH"] = "\(ffmpegDir):\(currentPath)"
        } else {
            env["PATH"] = ffmpegDir
        }
        process.environment = env
        
        // Output to a temp directory to find the result
        let tempDir = FileManager.default.temporaryDirectory
        let outputDir = tempDir.appendingPathComponent("whisper_output")
        
        // Ensure output dir exists
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        var args: [String] = [
            audioURL.path,
            "--output_dir", outputDir.path,
            "--output_format", "txt",
            "--model", model.isEmpty ? "base" : model
        ]
        if !language.isEmpty {
            args += ["--language", language]
        }
        if !initialPrompt.isEmpty {
            args += ["--initial_prompt", initialPrompt]
        }
        process.arguments = args
        
        let pipe = Pipe()
        process.standardError = pipe // Whisper often logs to stderr
        
        process.terminationHandler = { _ in
            let baseName = audioURL.deletingPathExtension().lastPathComponent
            let txtFile = outputDir.appendingPathComponent("\(baseName).txt")
            
            print("Whisper process finished. Looking for: \(txtFile.path)")
            
            if let content = try? String(contentsOf: txtFile, encoding: .utf8) {
                // Remove newlines and collapse multiple spaces
                let cleanedContent = content
                    .replacingOccurrences(of: "\\n", with: " ", options: .regularExpression)
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                print("Transcription success: \(cleanedContent.prefix(50))...")
                completion(cleanedContent)
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
