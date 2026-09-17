import MediaPlayer
import SwiftUI

/// Wraps the system music library picker. Protected (Apple Music) tracks are hidden.
struct MediaPickerView: UIViewControllerRepresentable {
    let onPick: (MPMediaItem?) -> Void

    func makeUIViewController(context: Context) -> MPMediaPickerController {
        let picker = MPMediaPickerController(mediaTypes: .music)
        picker.allowsPickingMultipleItems = false
        picker.showsCloudItems = false
        picker.showsItemsWithProtectedAssets = false
        picker.prompt = String(localized: "usersongs.picker.prompt")
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: MPMediaPickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, MPMediaPickerControllerDelegate {
        let onPick: (MPMediaItem?) -> Void
        init(onPick: @escaping (MPMediaItem?) -> Void) { self.onPick = onPick }

        func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
            onPick(mediaItemCollection.items.first)
        }

        func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
            onPick(nil)
        }
    }
}
