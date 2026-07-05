import SwiftUI
import SwiftData
import UIKit

/// Centre de contrôle d'une lampe : marche/arrêt, couleur RGB, luminosité,
/// blanc chaud/froid et effets dynamiques. Les contrôles indisponibles selon la
/// marque (couleur, effets) sont masqués via le `LightController`.
struct LightControlView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let light: Light

    @State private var isOn: Bool
    @State private var brightness: Double
    @State private var color: Color
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var showingConfig = false
    @State private var showingDeleteConfirmation = false
    @State private var activeAmbiance: LightAmbiance?
    /// Boucle d'animation des ambiances Pluie/Orage (annulée à la sortie).
    @State private var ambianceTask: Task<Void, Never>?
    @State private var isSoundPlaying = AmbientSoundEngine.shared.isPlaying
    @State private var isSoundPaused = AmbientSoundEngine.shared.isPaused
    /// "none" / "builtin" (sons intégrés) / "spotify".
    @AppStorage("ambianceSoundMode") private var ambianceSoundMode = "builtin"
    @AppStorage("ambianceVolume") private var ambianceVolume = 0.7

    private var controller: LightController {
        LightControllerFactory.controller(for: light.brand)
    }

    init(light: Light) {
        self.light = light
        _isOn = State(initialValue: light.lastKnownOn)
        _brightness = State(initialValue: Double(light.lastBrightness))
        _color = State(initialValue: .white)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if light.isConfigured {
                    powerCard
                    if controller.supportsColor {
                        colorCard
                    }
                    brightnessCard
                    whiteCard
                    if controller.supportsEffects {
                        ambiancesCard
                        effectsCard
                    }
                } else {
                    notConfiguredCard
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Brand.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .background(Brand.backgroundGradient.ignoresSafeArea())
        .navigationTitle(light.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingConfig = true
                    } label: {
                        Label("Configurer", systemImage: "gearshape")
                    }
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Supprimer la lampe", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "Supprimer \(light.name) ?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                context.delete(light)
                try? context.save()
                dismiss()
            }
        } message: {
            Text("La lampe est retirée de l'app. La lampe physique n'est pas affectée.")
        }
        .sheet(isPresented: $showingConfig) {
            LightConfigView(light: light)
        }
    }

    private var powerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $isOn) {
                Label(isOn ? "Allumée" : "Éteinte", systemImage: isOn ? "lightbulb.fill" : "lightbulb")
                    .foregroundStyle(isOn ? Brand.warning : Color.primary)
                    .font(.headline)
            }
            .disabled(isSending)
            .onChange(of: isOn) { _, newValue in
                perform { try await controller.setPower(newValue, ip: $0) }
                light.lastKnownOn = newValue
                try? context.save()
            }
            Text(light.brand.displayName + (light.terrarium.map { " · \($0.name)" } ?? ""))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .lightCard()
    }

    private var colorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Couleur")
                .font(.headline)
            ColorPicker("Choisir une couleur", selection: $color, supportsOpacity: false)
                .onChange(of: color) { _, newValue in
                    let rgb = Self.rgbComponents(newValue)
                    perform { try await controller.setColor(red: rgb.r, green: rgb.g, blue: rgb.b, ip: $0) }
                }
            HStack(spacing: 12) {
                ForEach(Self.presetColors, id: \.self) { preset in
                    Circle()
                        .fill(preset)
                        .frame(width: 34, height: 34)
                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 1))
                        .onTapGesture {
                            // Déclenche l'envoi via le `.onChange(of: color)` ci-dessus.
                            color = preset
                        }
                }
            }
        }
        .lightCard()
    }

    private var brightnessCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Luminosité : \(Int(brightness))%")
                .font(.headline)
            Slider(value: $brightness, in: 10...100, step: 5) { editing in
                if !editing {
                    perform { try await controller.setBrightness(Int(brightness), ip: $0) }
                    light.lastBrightness = Int(brightness)
                    try? context.save()
                }
            }
            .disabled(isSending)
        }
        .lightCard()
    }

    private var whiteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Blancs")
                .font(.headline)
            HStack(spacing: 12) {
                whiteButton("Chaud", kelvin: 2700)
                whiteButton("Neutre", kelvin: 4000)
                whiteButton("Froid", kelvin: 6500)
            }
        }
        .lightCard()
    }

    private func whiteButton(_ title: String, kelvin: Int) -> some View {
        Button {
            perform { try await controller.setColorTemperature(kelvin, ip: $0) }
        } label: {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(isSending)
    }

    // MARK: Ambiances thématiques

    private var ambiancesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ambiances")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 12)], spacing: 12) {
                ForEach(LightAmbiance.allCases) { ambiance in
                    Button {
                        applyAmbiance(ambiance)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: ambiance.symbolName)
                                .font(.title3)
                            Text(ambiance.displayName)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            (activeAmbiance == ambiance ? Brand.accent.opacity(0.22) : Brand.accent.opacity(0.10)),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(activeAmbiance == ambiance ? Brand.accent : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Picker("Son d'ambiance", selection: $ambianceSoundMode) {
                    Text("Silencieux").tag("none")
                    Text("Son intégré").tag("builtin")
                    Text("Spotify").tag("spotify")
                }
                .pickerStyle(.segmented)

                if ambianceSoundMode == "builtin" {
                    HStack(spacing: 10) {
                        Image(systemName: "speaker.wave.1")
                            .foregroundStyle(.secondary)
                        Slider(value: $ambianceVolume, in: 0...1)
                            .onChange(of: ambianceVolume) { _, newValue in
                                AmbientSoundEngine.shared.volume = Float(newValue)
                            }
                        Image(systemName: "speaker.wave.3")
                            .foregroundStyle(.secondary)
                    }
                    if isSoundPlaying {
                        HStack(spacing: 16) {
                            Button {
                                if AmbientSoundEngine.shared.isPaused {
                                    AmbientSoundEngine.shared.resume()
                                } else {
                                    AmbientSoundEngine.shared.pause()
                                }
                                isSoundPaused = AmbientSoundEngine.shared.isPaused
                            } label: {
                                Label(isSoundPaused ? "Reprendre" : "Pause",
                                      systemImage: isSoundPaused ? "play.circle.fill" : "pause.circle.fill")
                                    .font(.caption.weight(.semibold))
                            }
                            .tint(Brand.primary)
                            Button {
                                AmbientSoundEngine.shared.stop()
                                isSoundPlaying = false
                                isSoundPaused = false
                            } label: {
                                Label("Arrêter", systemImage: "stop.circle.fill")
                                    .font(.caption.weight(.semibold))
                            }
                            .tint(Brand.error)
                        }
                    }
                }
            }

            Text("Son intégré : pluie, orage, vagues, criquets et feu de camp joués par l'app — le son continue téléphone verrouillé et sort sur l'enceinte Bluetooth connectée. Cuba et Coucher de soleil (musicales) passent par Spotify. Les lumières Pluie/Orage s'animent tant que cet écran est ouvert.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .lightCard()
        .onDisappear {
            ambianceTask?.cancel()
            ambianceTask = nil
        }
    }

    private func applyAmbiance(_ ambiance: LightAmbiance) {
        ambianceTask?.cancel()
        ambianceTask = nil
        activeAmbiance = ambiance

        if let sceneId = ambiance.wizSceneId {
            perform { try await WizLightService.shared.send(WizCommandBuilder.scene(id: sceneId), to: $0) }
        } else {
            guard let ip = light.ipAddress, !ip.isEmpty else {
                errorMessage = "Aucune adresse IP configurée pour cette lampe."
                return
            }
            ambianceTask = Task { await runAnimatedAmbiance(ambiance, ip: ip) }
        }

        switch ambianceSoundMode {
        case "builtin":
            let played = AmbientSoundEngine.shared.play(ambiance: ambiance, volume: Float(ambianceVolume))
            isSoundPlaying = played
            if !played, ambiance.builtinSoundscape == nil {
                // Ambiance musicale sans fichier fourni : proposer Spotify.
                openSpotify(search: ambiance.spotifySearch)
            }
        case "spotify":
            AmbientSoundEngine.shared.stop()
            isSoundPlaying = false
            openSpotify(search: ambiance.spotifySearch)
        default:
            AmbientSoundEngine.shared.stop()
            isSoundPlaying = false
        }
    }

    /// Ambiances animées localement : la lampe WiZ n'a pas de scène pluie/orage,
    /// on séquence donc nous-mêmes couleurs et éclairs.
    private func runAnimatedAmbiance(_ ambiance: LightAmbiance, ip: String) async {
        let service = WizLightService.shared
        switch ambiance {
        case .rain:
            // Bleu-gris qui respire lentement, comme un ciel de pluie.
            while !Task.isCancelled {
                try? await service.send(WizCommandBuilder.color(red: 40, green: 70, blue: 110), to: ip)
                try? await service.send(WizCommandBuilder.brightness(35), to: ip)
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                if Task.isCancelled { break }
                try? await service.send(WizCommandBuilder.brightness(15), to: ip)
                try? await Task.sleep(nanoseconds: 2_500_000_000)
            }
        case .storm:
            // Pénombre bleutée entrecoupée de salves d'éclairs blancs.
            while !Task.isCancelled {
                try? await service.send(WizCommandBuilder.color(red: 25, green: 35, blue: 70), to: ip)
                try? await service.send(WizCommandBuilder.brightness(15), to: ip)
                try? await Task.sleep(nanoseconds: UInt64.random(in: 2_000_000_000...6_000_000_000))
                if Task.isCancelled { break }
                for _ in 0..<Int.random(in: 1...3) where !Task.isCancelled {
                    try? await service.send(WizCommandBuilder.color(red: 255, green: 255, blue: 255), to: ip)
                    try? await service.send(WizCommandBuilder.brightness(100), to: ip)
                    try? await Task.sleep(nanoseconds: UInt64.random(in: 80_000_000...200_000_000))
                    try? await service.send(WizCommandBuilder.color(red: 25, green: 35, blue: 70), to: ip)
                    try? await service.send(WizCommandBuilder.brightness(15), to: ip)
                    try? await Task.sleep(nanoseconds: UInt64.random(in: 100_000_000...300_000_000))
                }
            }
        default:
            break
        }
    }

    /// Ouvre Spotify sur la recherche d'ambiance (fiche App Store en repli).
    private func openSpotify(search: String) {
        let encoded = search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search
        guard let url = URL(string: "spotify:search:\(encoded)") else { return }
        UIApplication.shared.open(url, options: [:]) { success in
            if !success, let store = URL(string: "https://apps.apple.com/app/id324684580") {
                UIApplication.shared.open(store)
            }
        }
    }

    private var effectsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Effets")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 12)], spacing: 12) {
                ForEach(LightEffect.allCases) { effect in
                    Button {
                        perform { try await controller.setEffect(effect, ip: $0) }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: effect.symbolName)
                                .font(.title3)
                            Text(effect.displayName)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Brand.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSending)
                }
            }
        }
        .lightCard()
    }

    private var notConfiguredCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "lightbulb.slash")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Lampe non configurée")
                .font(.headline)
            Text("Renseigne l'adresse IP locale de la lampe pour la piloter. La lampe doit être sur le même réseau Wi-Fi que l'iPhone.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showingConfig = true
            } label: {
                Label("Configurer", systemImage: "gearshape.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .lightCard()
    }

    /// Envoie une commande au contrôleur en gérant l'état d'envoi et les erreurs.
    /// Toute commande manuelle interrompt l'ambiance animée en cours.
    private func perform(_ action: @escaping (String) async throws -> Void) {
        ambianceTask?.cancel()
        ambianceTask = nil
        guard let ip = light.ipAddress, !ip.isEmpty else {
            errorMessage = "Aucune adresse IP configurée pour cette lampe."
            return
        }
        isSending = true
        Task {
            do {
                try await action(ip)
                errorMessage = nil
            } catch {
                errorMessage = "Lampe injoignable à \(ip). Vérifie qu'elle est allumée et sur le même Wi-Fi."
            }
            isSending = false
        }
    }

    static func rgbComponents(_ color: Color) -> (r: Int, g: Int, b: Int) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Int(red * 255), Int(green * 255), Int(blue * 255))
    }

    static let presetColors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
}

/// Formulaire d'ajout/édition d'une lampe. Utilisable seul (ajout depuis le
/// Dashboard, avec choix du terrarium) ou pour une lampe existante.
struct LightConfigView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<Terrarium>(\.name)]) private var terrariums: [Terrarium]

    let existingLight: Light?

    @State private var name: String
    @State private var brand: LightBrand
    @State private var ipAddress: String
    @State private var notes: String
    @State private var selectedTerrariumID: PersistentIdentifier?

    init(light: Light? = nil, terrarium: Terrarium? = nil) {
        self.existingLight = light
        _name = State(initialValue: light?.name ?? "")
        _brand = State(initialValue: light?.brand ?? .wiz)
        _ipAddress = State(initialValue: light?.ipAddress ?? "")
        _notes = State(initialValue: light?.notes ?? "")
        _selectedTerrariumID = State(initialValue: light?.terrarium?.persistentModelID ?? terrarium?.persistentModelID)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Informations") {
                    TextField("Nom (ex: Lampe terrarium)", text: $name)
                    Picker("Marque", selection: $brand) {
                        ForEach(LightBrand.allCases, id: \.self) { brand in
                            Text(brand.displayName).tag(brand)
                        }
                    }
                }

                Section("Accès réseau") {
                    TextField("Adresse IP locale (ex: 192.168.1.50)", text: $ipAddress)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    if brand == .wiz {
                        Text("La lampe WiZ doit avoir le contrôle local activé dans l'app WiZ (Réglages → Local Communication).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Terrarium") {
                    Picker("Terrarium", selection: $selectedTerrariumID) {
                        Text("Aucun").tag(PersistentIdentifier?.none)
                        ForEach(terrariums) { terrarium in
                            Text(terrarium.name).tag(Optional(terrarium.persistentModelID))
                        }
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: $notes)
                }
            }
            .navigationTitle(existingLight == nil ? "Ajouter une lampe" : "Modifier la lampe")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Enregistrer") {
                        save()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private func save() {
        let selectedTerrarium = terrariums.first { $0.persistentModelID == selectedTerrariumID }
        let light = existingLight ?? Light(name: "")
        light.name = name
        light.brand = brand
        light.ipAddress = ipAddress.isEmpty ? nil : ipAddress
        light.notes = notes
        light.terrarium = selectedTerrarium
        if existingLight == nil {
            context.insert(light)
        }
        try? context.save()
    }
}

private extension View {
    /// Style de carte partagé par les blocs du centre de contrôle des lampes,
    /// aligné sur la carte standard « Habitat ».
    func lightCard() -> some View {
        brandCard()
    }
}
