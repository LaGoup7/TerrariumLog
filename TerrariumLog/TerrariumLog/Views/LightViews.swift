import SwiftUI
import SwiftData
import UIKit

/// Centre de contrôle d'une lampe, pensé pour les animaux : réglage manuel
/// (marche/arrêt, intensité, blancs), observation nocturne en lumière rouge,
/// et cycle jour/nuit (photopériode fixe ou biotope) piloté par le
/// `LightScheduleEngine`. Les ambiances décoratives (sons, effets) vivent dans
/// leur propre écran (`AmbianceView`), hors du pilotage d'élevage.
struct LightControlView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let light: Light

    @State private var isOn: Bool
    @State private var brightness: Double
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var showingConfig = false
    @State private var showingDeleteConfirmation = false
    @State private var showingAmbiances = false
    /// Mode observation nocturne (lumière rouge faible) actif.
    @State private var nightObservationOn = false
    /// Dernier résultat de synchronisation du cycle (icône + texte).
    @State private var syncOutcome: LightSyncOutcome?

    private var controller: LightController {
        LightControllerFactory.controller(for: light.brand)
    }

    init(light: Light) {
        self.light = light
        _isOn = State(initialValue: light.lastKnownOn)
        _brightness = State(initialValue: Double(light.lastBrightness))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if light.isConfigured {
                    powerCard
                    brightnessCard
                    whiteCard
                    nightObservationCard
                    cycleCard
                    automationCard
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
                    if controller.supportsEffects {
                        Button {
                            showingAmbiances = true
                        } label: {
                            Label("Ambiances (déco & sons)", systemImage: "music.note")
                        }
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
        .navigationDestination(isPresented: $showingAmbiances) {
            AmbianceView(light: light)
        }
        // Suivi du cycle en direct tant que l'écran est ouvert : application
        // immédiate, puis toutes les 5 minutes.
        .task(id: light.scheduleModeRawValue) {
            guard light.scheduleMode != .manual else {
                syncOutcome = nil
                return
            }
            await runSync()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000_000)
                if Task.isCancelled { break }
                await runSync()
            }
        }
    }

    // MARK: Contrôle manuel

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
            if light.scheduleMode != .manual {
                Text("Un cycle est actif : ce réglage manuel sera écrasé à la prochaine synchronisation.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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

    // MARK: Observation nocturne (lumière rouge)

    /// La plupart des invertébrés et reptiles perçoivent très mal le rouge :
    /// une lueur rouge faible permet d'observer les espèces nocturnes sans
    /// perturber leur cycle.
    private var nightObservationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $nightObservationOn) {
                Label("Observation nocturne", systemImage: "moon.haze.fill")
                    .font(.headline)
                    .foregroundStyle(nightObservationOn ? Brand.error : Color.primary)
            }
            .tint(Brand.error)
            .disabled(isSending || !controller.supportsColor)
            .onChange(of: nightObservationOn) { _, active in
                if active {
                    perform {
                        try await controller.setPower(true, ip: $0)
                        try await controller.setColor(red: 180, green: 0, blue: 0, ip: $0)
                        try await controller.setBrightness(10, ip: $0)
                    }
                    light.lastKnownOn = true
                    try? context.save()
                } else if light.scheduleMode != .manual {
                    // Retour au cycle en cours.
                    Task { await runSync() }
                } else {
                    perform { try await controller.setPower(false, ip: $0) }
                    isOn = false
                    light.lastKnownOn = false
                    try? context.save()
                }
            }
            Text("Lueur rouge très faible pour observer les espèces nocturnes sans les déranger (la plupart des invertébrés et reptiles ne perçoivent pas le rouge).")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .lightCard()
    }

    // MARK: Cycle jour/nuit

    private var selectedBiotope: BiotopePreset? {
        BiotopePreset.preset(id: light.biotopePresetID)
    }

    private var cycleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Cycle jour/nuit", systemImage: "sun.max.fill")
                .font(.headline)

            Picker("Mode", selection: Binding(
                get: { light.scheduleMode },
                set: { newValue in
                    light.scheduleMode = newValue
                    try? context.save()
                    Task { await runSync() }
                }
            )) {
                ForEach(LightScheduleMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            switch light.scheduleMode {
            case .manual:
                Text("Aucun cycle : la lampe garde tes réglages manuels.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .fixed:
                fixedScheduleControls
            case .biotope:
                biotopeControls
            }

            if light.scheduleMode != .manual {
                moonToggle
                if let outcome = syncOutcome {
                    Label(outcome.statusText, systemImage: outcome.symbolName)
                        .font(.caption)
                        .foregroundStyle(Brand.accent)
                }
            }
        }
        .lightCard()
    }

    /// Photopériode fixe : lever, coucher, intensité du plateau. L'aube et le
    /// crépuscule progressifs sont calculés automatiquement (courbe naturelle).
    private var fixedScheduleControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            DatePicker(
                "Lever",
                selection: minutesBinding(\.dayStartMinutes),
                displayedComponents: .hourAndMinute
            )
            DatePicker(
                "Coucher",
                selection: minutesBinding(\.dayEndMinutes),
                displayedComponents: .hourAndMinute
            )
            VStack(alignment: .leading, spacing: 4) {
                Text("Intensité de jour : \(light.dayBrightness) %")
                    .font(.subheadline)
                Slider(value: Binding(
                    get: { Double(light.dayBrightness) },
                    set: { newValue in
                        light.dayBrightness = Int(newValue)
                        try? context.save()
                    }
                ), in: 10...100, step: 5) { editing in
                    if !editing {
                        Task { await runSync() }
                    }
                }
            }
            Text("La lumière monte progressivement après le lever (aube chaude), culmine à mi-journée et redescend avant le coucher — pas d'allumage brutal.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    /// Biotope : soleil réel de la région d'origine, avec options météo/orage.
    private var biotopeControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Région", selection: Binding(
                get: { light.biotopePresetID ?? "" },
                set: { newValue in
                    light.biotopePresetID = newValue.isEmpty ? nil : newValue
                    try? context.save()
                    Task { await runSync() }
                }
            )) {
                Text("Choisir…").tag("")
                ForEach(BiotopePreset.all) { preset in
                    Text(preset.name).tag(preset.id)
                }
            }

            if selectedBiotope != nil {
                Toggle(isOn: biotopeBinding(\.biotopeShiftedToLocal)) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Caler sur ma journée")
                            .font(.subheadline)
                        Text(light.biotopeShiftedToLocal
                             ? "La journée de là-bas est rejouée sur ton horaire."
                             : "Temps réel là-bas : le décalage horaire est vécu.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(Brand.primary)

                Toggle(isOn: biotopeBinding(\.biotopeWeatherEnabled)) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Météo réelle (la veille)")
                            .font(.subheadline)
                        Text("Le ciel d'hier là-bas module l'intensité (nuages, pluie).")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(Brand.accent)

                if light.biotopeWeatherEnabled {
                    Toggle(isOn: biotopeBinding(\.biotopeStormSyncEnabled)) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Orage synchronisé")
                                .font(.subheadline)
                            Text("S'il pleut là-bas : pénombre d'orage bleu-gris.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(Brand.accent)
                }
            }
        }
    }

    /// Veilleuse lunaire, valable pour les deux modes de cycle.
    private var moonToggle: some View {
        Toggle(isOn: biotopeBinding(\.biotopeMoonEnabled)) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Veilleuse lunaire")
                    .font(.subheadline)
                Text("Nuits proches de la pleine lune : lueur bleutée minimale au lieu du noir.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(Brand.accent)
    }

    /// Binding vers un booléen du modèle qui sauvegarde et resynchronise.
    private func biotopeBinding(_ keyPath: ReferenceWritableKeyPath<Light, Bool>) -> Binding<Bool> {
        Binding(
            get: { light[keyPath: keyPath] },
            set: { newValue in
                light[keyPath: keyPath] = newValue
                try? context.save()
                Task { await runSync() }
            }
        )
    }

    /// Binding DatePicker ↔ minutes depuis minuit pour la photopériode fixe.
    private func minutesBinding(_ keyPath: ReferenceWritableKeyPath<Light, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minutes = light[keyPath: keyPath]
                return Calendar.current.date(
                    bySettingHour: minutes / 60,
                    minute: minutes % 60,
                    second: 0,
                    of: .now
                ) ?? .now
            },
            set: { newDate in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                light[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
                try? context.save()
                Task { await runSync() }
            }
        )
    }

    /// Applique la consigne du moment via le moteur et met l'UI à jour.
    @MainActor
    private func runSync() async {
        guard light.scheduleMode != .manual else { return }
        nightObservationOn = false
        syncOutcome = await LightScheduleEngine.sync(light)
        if let outcome = syncOutcome {
            isOn = outcome.isOn
            brightness = Double(light.lastBrightness)
        }
        try? context.save()
    }

    // MARK: Automatisation (app fermée)

    /// iOS n'autorise pas l'app à piloter la lampe en arrière-plan : le cycle
    /// continu passe par UNE Automatisation iOS qui exécute « Synchroniser les
    /// lampes » à intervalle régulier.
    private var automationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quand l'app est fermée")
                .font(.headline)
            Text("Le cycle est appliqué en direct tant que cet écran est ouvert. Pour qu'il continue app fermée, crée UNE Automatisation iOS :")
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                automationStep("1", "Raccourcis → Automatisation → + → « Heure de la journée »")
                automationStep("2", "Choisis une heure, Quotidien, « Exécuter immédiatement », puis duplique-la pour couvrir la journée (ex. toutes les heures)")
                automationStep("3", "Action → Habitat → « Synchroniser les lampes »")
            }
            Button {
                if let url = URL(string: "shortcuts://") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Ouvrir Raccourcis", systemImage: "clock.arrow.2.circlepath")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Brand.primary)
            Text("La même automatisation applique le bon mode (horaires fixes ou biotope) à toutes les lampes. « Dis Siri, synchronise le biotope avec Habitat » fonctionne aussi.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .lightCard()
    }

    private func automationStep(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.caption2.bold())
                .foregroundStyle(Brand.primary)
                .frame(width: 16, height: 16)
                .background(Brand.primary.opacity(0.15), in: Circle())
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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
    private func perform(_ action: @escaping (String) async throws -> Void) {
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

extension View {
    /// Style de carte partagé par les blocs du centre de contrôle des lampes,
    /// aligné sur la carte standard « Habitat ». (Interne au module lampes ;
    /// aussi utilisé par `AmbianceView`.)
    func lightCard() -> some View {
        brandCard()
    }
}
