import AlarmKit
import AVFoundation
import MediaPlayer
import SwiftUI

enum Sounds {
    static let folder = URL.libraryDirectory.appending(path: "Sounds")
    static let silence = URL.cachesDirectory.appending(path: "silence.caf")

    /// Test tones rise in pitch (440 Hz + 20 Hz/s), so a loop restart or a cut-off is audible as a pitch drop.
    static func generate() {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        tone(folder.appending(path: "rise10.caf"), seconds: 10)
        tone(folder.appending(path: "rise45.caf"), seconds: 45)
        tone(folder.appending(path: "rise10.wav"), seconds: 10)
        tone(folder.appending(path: "rise10.m4a"), seconds: 10)
        tone(silence, seconds: 1, amplitude: 0)
    }

    static func list() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: folder.path())) ?? []).sorted()
    }

    static func importFile(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let destination = folder.appending(path: url.lastPathComponent)
        try? FileManager.default.removeItem(at: destination)
        do {
            try FileManager.default.copyItem(at: url, to: destination)
            Log.write("imported \(url.lastPathComponent)")
        } catch {
            Log.write("import error: \(error)")
        }
    }

    private static func tone(_ url: URL, seconds: Double, amplitude: Float = 0.5) {
        guard !FileManager.default.fileExists(atPath: url.path()) else { return }
        let rate = 44_100.0
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
        let frames = AVAudioFrameCount(seconds * rate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let samples = buffer.floatChannelData![0]
        var phase = 0.0
        for i in 0..<Int(frames) {
            let t = Double(i) / rate
            phase += 2 * .pi * (440 + 20 * t) / rate
            // 0.25 s on, 0.25 s off
            samples[i] = t.truncatingRemainder(dividingBy: 0.5) < 0.25 ? amplitude * Float(sin(phase)) : 0
        }
        let settings: [String: Any] = url.pathExtension == "m4a"
            ? [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: rate, AVNumberOfChannelsKey: 1]
            : [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: rate, AVNumberOfChannelsKey: 1,
               AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false]
        do {
            let file = try AVAudioFile(forWriting: url, settings: settings)
            try file.write(from: buffer)
        } catch {
            Log.write("tone error \(url.lastPathComponent): \(error)")
        }
    }
}

/// Spike 2: keep the app alive with silent audio, then ring ourselves at a chosen volume.
@MainActor
final class Loud {
    static let shared = Loud()
    static weak var volumeView: MPVolumeView?

    private var keepalive: AVAudioPlayer?
    private var ringer: AVAudioPlayer?
    private var observing = false

    func arm(at fireDate: Date, volume: Float, sound: String) {
        let sound = sound.isEmpty ? "rise10.caf" : sound
        observeSession()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            keepalive = try AVAudioPlayer(contentsOf: Sounds.silence)
            keepalive?.numberOfLoops = -1
            keepalive?.play()
        } catch {
            Log.write("loud: session error: \(error)")
            return
        }
        Log.write("loud: armed for \(fireDate.formatted(date: .omitted, time: .standard)), volume \(Int(volume * 100))%, lowPower=\(ProcessInfo.processInfo.isLowPowerModeEnabled)")

        Task {
            let fallback = await Alarms.schedule(at: fireDate, sound: sound)
            try? await Task.sleep(for: .seconds(max(0, fireDate.timeIntervalSinceNow - 5)))
            Log.write("loud: T-5 s, keepalive playing=\(keepalive?.isPlaying ?? false)")
            if let fallback {
                try? AlarmManager.shared.cancel(id: fallback)
            }
            await Alarms.schedule(at: fireDate + 60, sound: sound)
            try? await Task.sleep(for: .seconds(max(0, fireDate.timeIntervalSinceNow)))
            ring(volume: volume, sound: sound)
        }
    }

    func silence() {
        ringer?.stop()
        keepalive?.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
        Log.write("loud: silenced")
    }

    private func ring(volume: Float, sound: String) {
        let session = AVAudioSession.sharedInstance()
        Log.write("loud: ring, system volume before=\(session.outputVolume)")
        let slider = Loud.volumeView?.subviews.compactMap { $0 as? UISlider }.first
        if slider == nil { Log.write("loud: MPVolumeView slider not found") }
        slider?.value = volume
        do {
            ringer = try AVAudioPlayer(contentsOf: Sounds.folder.appending(path: sound))
            ringer?.numberOfLoops = -1
            ringer?.play()
        } catch {
            Log.write("loud: ringer error: \(error)")
        }
        Task {
            try? await Task.sleep(for: .seconds(1))
            Log.write("loud: system volume after=\(session.outputVolume), ringer playing=\(ringer?.isPlaying ?? false)")
        }
    }

    private func observeSession() {
        guard !observing else { return }
        observing = true
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { note in
            Log.write("loud: interruption \(note.userInfo ?? [:])")
        }
        NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { note in
            Log.write("loud: route change \(note.userInfo?[AVAudioSessionRouteChangeReasonKey] ?? "")")
        }
    }
}

/// Hidden system volume control; its slider is the unofficial way to set the system volume.
struct VolumeHack: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
        Loud.volumeView = view
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
