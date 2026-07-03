import Foundation

struct VideoStorage {
    static let shared = VideoStorage()

    private let fileManager = FileManager.default

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Copies a video file (e.g. received from a PhotosPicker transfer) into local storage
    /// under a unique filename, mirroring `PhotoStorage.saveImage`.
    func saveVideo(from sourceURL: URL, for animalName: String) throws -> String {
        let fileExtension = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        let fileName = "\(animalName.replacingOccurrences(of: " ", with: "_"))_\(UUID().uuidString).\(fileExtension)"
        let destination = documentsDirectory.appendingPathComponent(fileName)
        try fileManager.copyItem(at: sourceURL, to: destination)
        return fileName
    }

    func url(for path: String) -> URL {
        documentsDirectory.appendingPathComponent(path)
    }

    func deleteVideo(at path: String) throws {
        let url = documentsDirectory.appendingPathComponent(path)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    /// Copies an external file (e.g. from an imported backup) into local video storage under the given filename.
    func importVideo(from sourceURL: URL, filename: String) throws {
        let destination = documentsDirectory.appendingPathComponent(filename)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: sourceURL, to: destination)
    }
}
