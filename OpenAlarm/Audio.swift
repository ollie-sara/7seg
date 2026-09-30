import AVFoundation
import MediaPlayer
import SwiftUI

/// Alarm sounds: bundled files plus imports copied into `Library/Sounds`, where AlarmKit also finds them.
enum Sounds {
    static let defaultName = "Beep.caf"
    static let folder = URL.libraryDirectory.appending(path: "Sounds")
    static let extensions = ["caf", "wav", "m4a", "mp3", "aiff"]

    static var bundled: [String] {
        extensions.flatMap { Bundle.main.urls(forResourcesWithExtension: $0, subdirectory: nil) ?? [] }
            .map(\.lastPathComponent).sorted()
    }

    static var imported: [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: folder.path())) ?? [])
            .filter { extensions.contains(($0 as NSString).pathExtension.lowercased()) }.sorted()
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
}

/// In-app playback: the ringing screen, previews, and Loud mode (silent keepalive, system volume, fade-in).
@MainActor
final class Audio {
    static let shared = Audio()
    fileprivate static weak var volumeView: MPVolumeView?

    private var player: AVAudioPlayer?
    private var keepalive: AVAudioPlayer?
    private var fade: Task<Void, Never>?

    var isRinging: Bool { player?.isPlaying == true && player?.numberOfLoops == -1 }

    /// Loops `sound` until `stop()`. `volume` set = Loud mode: drive the system volume, optionally fading in over 15 s.
    func ring(_ sound: String, volume: Double?, fadeIn: Bool) {
        start(sound, loops: -1)
        guard let volume else { return }
        fade?.cancel()
        fade = Task {
            let steps = fadeIn ? 15 : 1
            for step in 1...steps {
                setSystemVolume(Float(volume) * Float(step) / Float(steps))
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
            }
        }
    }

    func preview(_ sound: String) {
        start(sound, loops: 0)
    }

    func stop() {
        fade?.cancel()
        player?.stop()
        player = nil
    }

    /// Plays silence in the background so the process stays alive to ring in Loud mode.
    func setKeepalive(_ on: Bool) {
        guard on != (keepalive != nil) else { return }
        if on {
            activate()
            keepalive = try? AVAudioPlayer(contentsOf: Self.silence())
            keepalive?.numberOfLoops = -1
            keepalive?.play()
        } else {
            keepalive?.stop()
            keepalive = nil
        }
    }

    private func start(_ sound: String, loops: Int) {
        stop()
        guard let url = Sounds.url(sound) ?? Sounds.url(Sounds.defaultName) else { return }
        activate()
        player = try? AVAudioPlayer(contentsOf: url)
        player?.numberOfLoops = loops
        player?.play()
    }

    private func activate() {
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    /// Unofficial but widely used: the hidden MPVolumeView's slider sets the system volume.
    private func setSystemVolume(_ value: Float) {
        Self.volumeView?.subviews.compactMap { $0 as? UISlider }.first?.value = value
    }

    private static func silence() -> URL {
        let url = URL.cachesDirectory.appending(path: "silence.caf")
        if !FileManager.default.fileExists(atPath: url.path()) {
            let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44_100)!
            buffer.frameLength = 44_100 // zero-filled
            try? AVAudioFile(forWriting: url, settings: format.settings).write(from: buffer)
        }
        return url
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
