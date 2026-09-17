import AVFoundation
import Foundation
import MediaPlayer
import MusicTheory
import Observation
import SongAnalysis
import SwiftData

/// Brings a track into the app: copy or export it, decode, analyse, store.
@MainActor
@Observable
final class SongImporter {
    enum Phase: Equatable {
        case idle
        case preparing
        case decoding(Double)
        case analysing(Double)
        case done
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var currentTitle = ""

    var isBusy: Bool {
        switch phase {
        case .preparing, .decoding, .analysing: true
        default: false
        }
    }

    func reset() { phase = .idle }

    // MARK: Sources

    /// A library item. DRM-free tracks are exported and analysed; protected or cloud tracks are
    /// registered for the system player and learn their chords on the first playback.
    func importMediaItem(_ item: MPMediaItem, into context: ModelContext) async {
        currentTitle = item.title ?? ""
        guard let assetURL = item.assetURL, !item.hasProtectedAsset, !item.isCloudItem else {
            let song = UserSong(
                title: item.title ?? "", artist: item.artist ?? "", fileName: "", analysis: nil,
                source: .appleMusic, mediaPersistentID: String(item.persistentID), duration: item.playbackDuration
            )
            context.insert(song)
            try? context.save()
            phase = .done
            return
        }
        phase = .preparing
        let destination = UserSongStore.newFileURL(extension: "m4a")
        do {
            let asset = AVURLAsset(url: assetURL)
            guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
                throw AudioDecodingError.failed("Export not possible")
            }
            try await session.export(to: destination, as: .m4a)
        } catch {
            phase = .failed(error.localizedDescription)
            return
        }
        await analyse(fileURL: destination, title: item.title ?? destination.lastPathComponent, artist: item.artist ?? "", into: context)
    }

    /// A file picked from the Files app (security-scoped).
    func importFile(_ url: URL, into context: ModelContext) async {
        currentTitle = url.deletingPathExtension().lastPathComponent
        phase = .preparing
        let destination = UserSongStore.newFileURL(extension: url.pathExtension.isEmpty ? "audio" : url.pathExtension)
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            try FileManager.default.copyItem(at: url, to: destination)
        } catch {
            phase = .failed(error.localizedDescription)
            return
        }
        await analyse(fileURL: destination, title: currentTitle, artist: "", into: context)
    }

    #if DEBUG
    /// Simulator helper: a synthesised progression so the pipeline can be tried without a library.
    func importDemo(into context: ModelContext) async {
        currentTitle = "Demo: G D Em C"
        phase = .preparing
        let destination = UserSongStore.newFileURL(extension: "wav")
        let samples = await Task.detached(priority: .userInitiated) {
            DemoSongRenderer.render(chordIDs: ["G", "D", "Em", "C", "G", "D", "C", "G"], secondsPerChord: 2.4, bpm: 100, sampleRate: 22_050)
        }.value
        do {
            try WAVWriter.write(samples: samples, sampleRate: 22_050, to: destination)
        } catch {
            phase = .failed(error.localizedDescription)
            return
        }
        await analyse(fileURL: destination, title: currentTitle, artist: "Guitarro", into: context)
    }
    #endif

    // MARK: Pipeline

    private func analyse(fileURL: URL, title: String, artist: String, into context: ModelContext) async {
        phase = .decoding(0)
        do {
            let samples = try await AudioFileDecoder.decode(url: fileURL, sampleRate: 22_050) { [weak self] progress in
                Task { @MainActor in self?.phase = .decoding(progress) }
            }
            phase = .analysing(0)
            let analysis = await Task.detached(priority: .userInitiated) { [weak self] in
                ChordTimelineAnalyzer().analyze(samples: samples) { progress in
                    Task { @MainActor in self?.phase = .analysing(progress) }
                }
            }.value
            let song = UserSong(title: title, artist: artist, fileName: fileURL.lastPathComponent, analysis: analysis)
            context.insert(song)
            try context.save()
            phase = .done
        } catch {
            try? FileManager.default.removeItem(at: fileURL)
            phase = .failed(error.localizedDescription)
        }
    }
}

extension MPMediaLibrary {
    static func requestAccess() async -> Bool {
        switch authorizationStatus() {
        case .authorized: return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                requestAuthorization { continuation.resume(returning: $0 == .authorized) }
            }
        default: return false
        }
    }
}
