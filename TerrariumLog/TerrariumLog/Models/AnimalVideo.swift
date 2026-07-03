import Foundation
import SwiftData

@Model
final class AnimalVideo {
    var title: String
    var notes: String
    var date: Date
    var videoPath: String

    var animal: Animal?

    init(
        title: String,
        notes: String = "",
        date: Date = .now,
        videoPath: String,
        animal: Animal? = nil
    ) {
        self.title = title
        self.notes = notes
        self.date = date
        self.videoPath = videoPath
        self.animal = animal
    }
}
