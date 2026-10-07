import AVFoundation
import Foundation
import Testing
@testable import SevenSeg

struct RenderTests {
    /// 0.5 s of a quiet (0.25) 440 Hz sine, rendered at gain 0.5 with a 2 s fade into 4 s:
    /// quiet at the start, normalized to about 0.5 at the end.
    @Test func fadesInToGain() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let sine = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 22_050)!
        sine.frameLength = 22_050
        for i in 0..<22_050 { sine.floatChannelData![0][i] = 0.25 * sin(2 * .pi * 440 * Float(i) / 44_100) }
        let source = folder.appending(path: "sine.caf")
        try AVAudioFile(forWriting: source, settings: format.settings).write(from: sine)

        let output = folder.appending(path: "out.caf")
        try Sounds.render(source, to: output, gain: 0.5, fade: 2, length: 4)

        let file = try AVAudioFile(forReading: output)
        let rendered = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
        try file.read(into: rendered)
        let samples = UnsafeBufferPointer(start: rendered.floatChannelData![0], count: Int(rendered.frameLength))
        #expect(abs(Double(samples.count) / 44_100 - 4) < 0.1)
        func peak(_ seconds: ClosedRange<Double>) -> Float {
            samples[Int(seconds.lowerBound * 44_100)..<Int(seconds.upperBound * 44_100)].map(abs).max()!
        }
        #expect(peak(0.1...0.3) < 0.05)
        #expect(abs(peak(3...3.9) - 0.5) < 0.05)
    }
}
