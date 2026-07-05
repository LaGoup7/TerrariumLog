import Foundation
import ImageIO
import UIKit

/// Miniatures d'images à la demande : décode les photos en taille réduite
/// (downsampling ImageIO, sans jamais charger la pleine résolution en mémoire)
/// et les garde en cache. Les listes et grilles restent fluides même avec des
/// centaines de photos ; la visionneuse plein écran continue d'utiliser
/// `PhotoStorage.loadImage` (pleine résolution).
final class ThumbnailStore {
    static let shared = ThumbnailStore()

    private let cache = NSCache<NSString, UIImage>()

    init() {
        cache.countLimit = 500
    }

    /// Miniature de la photo stockée sous `path`, limitée à `maxDimension`
    /// pixels sur son plus grand côté (pense aux points × échelle d'écran).
    func thumbnail(for path: String, maxDimension: CGFloat = 240) -> UIImage? {
        let key = "\(path)#\(Int(maxDimension))" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let url = PhotoStorage.shared.url(for: path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let image = UIImage(cgImage: cgImage)
        cache.setObject(image, forKey: key)
        return image
    }
}
