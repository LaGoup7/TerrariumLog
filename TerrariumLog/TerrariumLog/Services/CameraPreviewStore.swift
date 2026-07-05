import Foundation
import UIKit

/// Dernière image vue de chaque caméra, mise en cache sur disque (dossier
/// Caches) pour servir de vignette sur le Dashboard — façon Apple Home.
/// La clé est dérivée de la config de la caméra (URL/IP), stable entre
/// lancements.
struct CameraPreviewStore {
    static let shared = CameraPreviewStore()

    private var directory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("CameraPreviews", isDirectory: true)
    }

    private func key(for camera: Camera) -> String {
        let base = camera.streamURL ?? camera.ipAddress ?? camera.name
        let sanitized = base.map { $0.isLetter || $0.isNumber ? $0 : "-" }
        return String(sanitized)
    }

    private func fileURL(for camera: Camera) -> URL {
        directory.appendingPathComponent("preview-\(key(for: camera)).jpg")
    }

    func save(_ image: UIImage, for camera: Camera) {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: fileURL(for: camera), options: .atomic)
    }

    func load(for camera: Camera) -> UIImage? {
        UIImage(contentsOfFile: fileURL(for: camera).path)
    }
}
