import SwiftUI
import UIKit

/// Sélecteur de photo (galerie ou appareil photo) avec l'étape de recadrage
/// carré intégrée d'iOS (`allowsEditing`). L'utilisateur choisit précisément la
/// zone à afficher au moment de la sélection ; l'image renvoyée est déjà
/// recadrée, donc stockée et affichée telle quelle partout — plus besoin de la
/// repositionner ensuite.
struct CroppingImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CroppingImagePicker

        init(_ parent: CroppingImagePicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            // `.editedImage` = zone recadrée choisie par l'utilisateur ; on retombe
            // sur l'originale si l'édition n'a rien renvoyé (cas improbable).
            if let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage) {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

/// Petit wrapper `Identifiable` pour présenter le sélecteur via `.fullScreenCover(item:)`
/// en distinguant la source (galerie vs appareil photo).
struct ImagePickerSource: Identifiable {
    let id = UUID()
    let type: UIImagePickerController.SourceType
}
