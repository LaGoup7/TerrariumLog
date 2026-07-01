import Foundation
import SwiftUI

struct PhotoStorage {
    static let shared = PhotoStorage()

    private let fileManager = FileManager.default

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    func saveImage(_ image: UIImage, for animalName: String) throws -> String {
        let fileName = "\(animalName.replacingOccurrences(of: " ", with: "_"))_\(UUID().uuidString).jpg"
        let url = documentsDirectory.appendingPathComponent(fileName)
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "PhotoStorage", code: 1, userInfo: [NSLocalizedDescriptionKey: "Impossible to encode image"])
        }
        try data.write(to: url, options: .atomic)
        return fileName
    }

    func loadImage(from path: String) -> UIImage? {
        let url = documentsDirectory.appendingPathComponent(path)
        return UIImage(contentsOfFile: url.path)
    }

    func deleteImage(at path: String) throws {
        let url = documentsDirectory.appendingPathComponent(path)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
}
