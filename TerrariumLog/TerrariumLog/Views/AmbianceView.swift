import SwiftUI
import SwiftData
import UIKit

/// Écran « Ambiances » : atmosphères décoratives (Cuba, océan, orage…), sons
/// d'ambiance et effets dynamiques. C'est un espace pour l'humain — séparé du
/// centre de contrôle de la lampe, qui reste dédié aux besoins des animaux
/// (cycle jour/nuit, observation nocturne).
struct AmbianceView: View {
    let light: Light

    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var activeAmbiance: LightAmbiance?
    /// Boucle d'animation des ambiances Pluie/Orage (annulée à la sortie).
    @State private var ambianceTask: Task<Void, Never>?
    @State private var isSoundPlaying = AmbientSoundEngine.shared.isPlaying
    @State private var isSoundPaused = AmbientSoundEngine.shared.isPaused
    /// "none" / "builtin" (sons intégrés) / "spotify".
    @AppStorage("ambianceSoundMode") private var ambianceSoundMode = "builtin"
    @AppStorage("ambianceVolume") private var ambianceVolume = 0.7

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if light.isConfigured {
                    ambiancesCard
                    soundCard
                    effectsCard
                } else {
                    Text("Configure d'abord l'adresse IP de la lampe pour utiliser les ambiances.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lightCard()
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Brand.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text("Ces ambiances sont décoratives (pour toi, pas pour les animaux). Le cycle jour/nuit de la lampe reprend la main à la prochaine synchronisation.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .background(Brand.backgroundGradient.ignoresSafeArea())
        .navigationTitle("Ambiances")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            ambianceTask?.cancel()
            ambianceTask = nil
        }
    }

    // MARK: Ambiances thématiques

    private var ambiancesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Atmosphères")
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
            Text("Les lumières Pluie/Orage s'animent tant que cet écran est ouvert.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .lightCard()
    }

    // MARK: Son d'ambiance

    private var soundCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Son d'ambiance")
                .font(.headline)
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

            Text("Son intégré : pluie, orage, vagues, criquets et feu de camp joués par l'app — le son continue téléphone verrouillé et sort sur l'enceinte Bluetooth connectée. Cuba et Coucher de soleil (musicales) passent par Spotify.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .lightCard()
    }

    // MARK: Effets dynamiques

    private var effectsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Effets dynamiques")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 12)], spacing: 12) {
                ForEach(LightEffect.dynamicOnly) { effect in
                    Button {
                        perform { try await WizLightService.shared.send(WizCommandBuilder.effect(effect), to: $0) }
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
            Text("À utiliser avec parcimonie : les animations rapides (clignotement, arc-en-ciel) peuvent stresser les animaux. Préfère-les terrarium vide ou pour une vitrine.")
                .font(.caption2)
                .foregroundStyle(Brand.warning)
        }
        .lightCard()
    }

    // MARK: Application

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

    /// Envoie une commande en gérant l'état d'envoi et les erreurs. Toute
    /// commande manuelle interrompt l'ambiance animée en cours.
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
}
