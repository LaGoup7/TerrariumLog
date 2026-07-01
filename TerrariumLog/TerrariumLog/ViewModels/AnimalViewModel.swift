import Foundation
import SwiftData

@MainActor
final class AnimalViewModel: ObservableObject {
    @Published var animals: [Animal] = []

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        self.animals = (try? context.fetch(FetchDescriptor<Animal>())) ?? []
    }

    func refresh() {
        animals = (try? context.fetch(FetchDescriptor<Animal>())) ?? []
    }

    func addAnimal(_ animal: Animal) {
        context.insert(animal)
        try? context.save()
        refresh()
    }
}
