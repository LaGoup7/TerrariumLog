import SwiftUI
import UIKit
import VLCKitSPM

/// État simplifié du flux, exposé aux vues SwiftUI sans qu'elles aient à
/// connaître VLCKit.
enum CameraStreamStatus: Equatable {
    case connecting
    case playing
    case ended
    case error
}

/// Affiche un flux vidéo live (RTSP, etc.) via VLCKit — iOS ne lit pas le RTSP
/// nativement. On branche un `VLCMediaPlayer` sur une `UIView` (drawable).
/// Réutilise l'`URL` fournie par `CameraStreamProvider` sans transcodage.
struct CameraStreamView: UIViewRepresentable {
    let url: URL
    var onStatusChange: (CameraStreamStatus) -> Void = { _ in }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        context.coordinator.start(url: url, on: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onStatusChange: onStatusChange)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator: NSObject, VLCMediaPlayerDelegate {
        private var player: VLCMediaPlayer?
        private let onStatusChange: (CameraStreamStatus) -> Void

        init(onStatusChange: @escaping (CameraStreamStatus) -> Void) {
            self.onStatusChange = onStatusChange
        }

        func start(url: URL, on view: UIView) {
            let player = VLCMediaPlayer()
            player.drawable = view
            player.delegate = self

            let media = VLCMedia(url: url)
            // RTSP sur TCP (plus fiable que l'UDP derrière un NAT) + faible latence.
            media.addOption(":rtsp-tcp")
            media.addOption(":network-caching=300")
            player.media = media
            player.play()
            self.player = player
            onStatusChange(.connecting)
        }

        func stop() {
            player?.stop()
            player?.drawable = nil
            player?.delegate = nil
            player = nil
        }

        func mediaPlayerStateChanged(_ aNotification: Notification) {
            guard let player else { return }
            switch player.state {
            case .playing:
                onStatusChange(.playing)
            case .error:
                onStatusChange(.error)
            case .ended, .stopped:
                onStatusChange(.ended)
            default:
                onStatusChange(.connecting)
            }
        }
    }
}
