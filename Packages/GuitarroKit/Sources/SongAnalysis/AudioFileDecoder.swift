import AVFoundation
import Foundation

public enum AudioDecodingError: Error, LocalizedError, Sendable {
    case noAudioTrack
    case protected
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .noAudioTrack: "The file has no audio track."
        case .protected: "This track is copy-protected and cannot be analysed."
        case .failed(let message): message
        }
    }
}

/// Decodes any AVFoundation-readable audio into mono Float32 at the requested sample rate.
public enum AudioFileDecoder {
    public static func decode(url: URL, sampleRate: Double = 22_050, progress: (@Sendable (Double) -> Void)? = nil) async throws -> [Float] {
        let asset = AVURLAsset(url: url)
        if try await asset.load(.hasProtectedContent) {
            throw AudioDecodingError.protected
        }
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            throw AudioDecodingError.noAudioTrack
        }
        let duration = try await asset.load(.duration).seconds
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            throw AudioDecodingError.failed(error.localizedDescription)
        }
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw AudioDecodingError.failed("Cannot read audio track") }
        reader.add(output)
        guard reader.startReading() else {
            throw AudioDecodingError.failed(reader.error?.localizedDescription ?? "Cannot start reading")
        }

        var samples: [Float] = []
        samples.reserveCapacity(Int(duration * sampleRate) + 1024)
        while let buffer = output.copyNextSampleBuffer() {
            guard let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
            let length = CMBlockBufferGetDataLength(block)
            var chunk = [Float](repeating: 0, count: length / MemoryLayout<Float>.size)
            chunk.withUnsafeMutableBytes { bytes in
                _ = CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: bytes.baseAddress!)
            }
            samples.append(contentsOf: chunk)
            if duration > 0 { progress?(min(1, Double(samples.count) / sampleRate / duration)) }
        }
        if reader.status == .failed {
            throw AudioDecodingError.failed(reader.error?.localizedDescription ?? "Decoding failed")
        }
        return samples
    }
}
