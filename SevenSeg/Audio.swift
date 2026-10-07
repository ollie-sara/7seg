import Accelerate
import AVFoundation
import MediaPlayer
import SwiftUI

/// Alarm sounds: bundled files plus imports copied into `Library/Sounds`, where AlarmKit also finds them.
enum Sounds {
    static let defaultName = "Beep.caf"
    static let folder = URL.libraryDirectory.appending(path: "Sounds")
    static let extensions = ["caf", "wav", "m4a", "mp3", "aiff"]
    /// Per-alarm renders for AlarmKit live in `folder` too, under this prefix.
    static let renderedPrefix = "rendered-"
    // ponytail: renders run fade + 10 min, then AlarmKit loops back to the quiet start. Lengthen if alarms ring longer.
    static let renderedTail = 600.0

    static var bundled: [String] {
        extensions.flatMap { Bundle.main.urls(forResourcesWithExtension: $0, subdirectory: nil) ?? [] }
            .map(\.lastPathComponent).sorted()
    }

    /// Everything in `folder` but the renders: only the importer writes there, and it already limits picks to audio.
    static var imported: [String] {
        files.filter { !$0.hasPrefix(renderedPrefix) }.sorted()
    }

    private static var files: [String] {
        ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? [])
            .map(\.lastPathComponent)
    }

    static func delete(_ name: String) {
        try? FileManager.default.removeItem(at: folder.appending(path: name))
    }

    static func url(_ name: String) -> URL? {
        if let url = Bundle.main.url(forResource: name, withExtension: nil) { return url }
        let url = folder.appending(path: name)
        return FileManager.default.fileExists(atPath: url.path()) ? url : nil
    }

    static func displayName(_ name: String) -> String {
        (name as NSString).deletingPathExtension
    }

    /// Copies a picked file as-is. Returns its name.
    static func importFile(_ url: URL) throws -> String {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appending(path: url.lastPathComponent)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.copyItem(at: url, to: destination)
        return url.lastPathComponent
    }

    // MARK: Renders

    /// AlarmKit plays at ringer volume and has no volume or fade API, so both are baked into the file.
    /// The name encodes the settings, so a render is reused until one of them changes.
    static func renderedName(_ alarm: AlarmItem, fade: Bool) -> String {
        "\(renderedPrefix)2-\(alarm.id.uuidString)-\(Int((alarm.volume * 100).rounded()))-\(fade ? alarm.fadeSeconds ?? 0 : 0)-\(alarm.sound).caf"
    }

    /// The AlarmKit sound for `alarm`: scaled to `alarm.volume`, fading in over `alarm.fadeSeconds` when `fade` is set.
    /// Renders on first use. nil if rendering fails; the caller falls back to the system sound.
    static func rendered(_ alarm: AlarmItem, fade: Bool) -> String? {
        let name = renderedName(alarm, fade: fade)
        let file = folder.appending(path: name)
        if FileManager.default.fileExists(atPath: file.path()) { return name }
        guard let source = url(alarm.sound) ?? url(defaultName) else { return nil }
        let seconds = fade ? alarm.fadeSeconds ?? 0 : 0
        do {
            // Rendered aside and moved in, so a second sync never sees a half-written file.
            let temporary = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).caf")
            defer { try? FileManager.default.removeItem(at: temporary) }
            try render(source, to: temporary, gain: Float(alarm.volume), fade: Double(seconds), length: seconds > 0 ? Double(seconds) + renderedTail : nil)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: file)
            try FileManager.default.moveItem(at: temporary, to: file)
            return name
        } catch {
            print("render error: \(error)")
            return nil
        }
    }

    /// Deletes renders that none of `alarms` uses any more.
    static func pruneRendered(keeping alarms: [AlarmItem]) {
        let used = Set(alarms.flatMap { [renderedName($0, fade: true), renderedName($0, fade: false)] })
        for name in files where name.hasPrefix(renderedPrefix) && !used.contains(name) {
            delete(name)
        }
    }

    /// Writes `source` looped to `length` seconds (one pass if nil) as AAC, normalized and scaled by `gain`,
    /// rising from silence over `fade` s.
    static func render(_ source: URL, to destination: URL, gain: Float, fade: Double, length: Double?) throws {
        let input = try AVAudioFile(forReading: source)
        let format = input.processingFormat
        guard let loop = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(input.length)),
              let chunk = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 65_536)
        else { throw CocoaError(.fileReadCorruptFile) }
        try input.read(into: loop)
        let loopFrames = Int(loop.frameLength)
        guard loopFrames > 0 else { throw CocoaError(.fileReadCorruptFile) }
        // Normalized: many files peak well below full scale, so 100 % is the loudest this sound can be.
        // 0.97, not 1, leaves room for AAC overshoot.
        var peak: Float = 0
        for channel in 0..<Int(format.channelCount) {
            var channelPeak: Float = 0
            vDSP_maxmgv(loop.floatChannelData![channel], 1, &channelPeak, vDSP_Length(loopFrames))
            peak = max(peak, channelPeak)
        }
        guard peak > 0 else { throw CocoaError(.fileReadCorruptFile) }
        let gain = gain * 0.97 / peak
        let total = length.map { Int($0 * format.sampleRate) } ?? loopFrames
        let fadeFrames = fade * format.sampleRate
        let output = try AVAudioFile(
            forWriting: destination,
            settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: format.sampleRate, AVNumberOfChannelsKey: format.channelCount],
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        var position = 0
        while position < total {
            chunk.frameLength = 0
            while chunk.frameLength < chunk.frameCapacity, position < total {
                let offset = position % loopFrames
                let count = min(1024, loopFrames - offset, Int(chunk.frameCapacity - chunk.frameLength), total - position)
                // Quadratic, so loudness rises evenly to the ear. Steps every 1024 frames (~23 ms) are too small to hear.
                let ramp = fadeFrames > 0 ? min(1, Double(position) / fadeFrames) : 1
                var scale = gain * Float(ramp * ramp)
                for channel in 0..<Int(format.channelCount) {
                    vDSP_vsmul(loop.floatChannelData![channel] + offset, 1, &scale,
                               chunk.floatChannelData![channel] + Int(chunk.frameLength), 1, vDSP_Length(count))
                }
                chunk.frameLength += AVAudioFrameCount(count)
                position += count
            }
            try output.write(from: chunk)
        }
    }
}

/// In-app playback: the ringing screen and previews.
@MainActor
final class Audio {
    static let shared = Audio()
    fileprivate static weak var volumeView: MPVolumeView?

    private var player: AVAudioPlayer?

    var isRinging: Bool { player?.isPlaying == true && player?.numberOfLoops == -1 }

    private init() {
        // A call can interrupt the ringing screen; pick up again when it's over.
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { note in
            guard note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt == AVAudioSession.InterruptionType.ended.rawValue else { return }
            MainActor.assumeIsolated {
                try? AVAudioSession.sharedInstance().setActive(true)
                Audio.shared.player?.play()
            }
        }
    }

    /// Loops `sound` at system volume `volume` until `stop()`.
    func ring(_ sound: String, volume: Double) {
        setSystemVolume(Float(volume))
        start(sound, loops: -1)
    }

    func preview(_ sound: String) {
        start(sound, loops: 0)
    }

    func stop() {
        player?.stop()
        player = nil
    }

    private func start(_ sound: String, loops: Int) {
        stop()
        guard let url = Sounds.url(sound) ?? Sounds.url(Sounds.defaultName) else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.numberOfLoops = loops
        player?.play()
    }

    /// Unofficial but widely used: the hidden MPVolumeView's slider sets the system volume.
    private func setSystemVolume(_ value: Float) {
        Self.volumeView?.subviews.compactMap { $0 as? UISlider }.first?.value = value
    }
}

/// Must be in the view hierarchy for `Audio.setSystemVolume` to work.
struct VolumeHack: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
        Audio.volumeView = view
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
