import AVFoundation
import MediaPlayer

/// Sons d'ambiance générés par synthèse en temps réel (aucun fichier audio
/// embarqué) : pluie, orage, vagues, criquets nocturnes, feu de camp.
///
/// La session audio est en catégorie `.playback` avec le mode background
/// « audio » : le son continue quand l'app passe en arrière-plan ou que
/// l'iPhone est verrouillé, et sort sur l'enceinte Bluetooth connectée,
/// comme n'importe quelle app de musique.
final class AmbientSoundEngine {
    static let shared = AmbientSoundEngine()

    enum Soundscape {
        case rain
        case storm
        case waves
        case crickets
        case crackle
    }

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var filePlayer: AVAudioPlayer?
    private(set) var isPlaying = false
    private(set) var isPaused = false
    private var currentTitle: String?
    private var remoteCommandsConfigured = false

    var volume: Float = 0.7 {
        didSet {
            engine.mainMixerNode.outputVolume = volume
            filePlayer?.volume = volume
        }
    }

    /// Joue le son d'une ambiance : un fichier audio embarqué
    /// (`ambiance-<nom>.m4a/.mp3` dans le bundle) s'il existe, sinon le
    /// paysage sonore synthétisé correspondant. Renvoie `false` si l'ambiance
    /// n'a aucun son (Cuba, Coucher de soleil sans fichier fourni).
    @discardableResult
    func play(ambiance: LightAmbiance, volume: Float) -> Bool {
        stop()
        currentTitle = "Ambiance \(ambiance.displayName)"
        let started: Bool
        if let url = bundledFileURL(for: ambiance) {
            started = playFile(url, volume: volume)
        } else if let soundscape = ambiance.builtinSoundscape {
            started = playSynthesized(soundscape, volume: volume)
        } else {
            started = false
        }
        if started {
            configureRemoteCommands()
            updateNowPlaying(playing: true)
        }
        return started
    }

    /// Met en pause (contrôlable depuis l'écran verrouillé / Centre de contrôle).
    func pause() {
        guard isPlaying, !isPaused else { return }
        filePlayer?.pause()
        if sourceNode != nil { engine.pause() }
        isPaused = true
        updateNowPlaying(playing: false)
    }

    /// Reprend la lecture après une pause.
    func resume() {
        guard isPlaying, isPaused else { return }
        filePlayer?.play()
        if sourceNode != nil { try? engine.start() }
        isPaused = false
        updateNowPlaying(playing: true)
    }

    /// Fichier optionnel fourni par l'utilisateur dans le bundle :
    /// `ambiance-rain.m4a`, `ambiance-cuba.mp3`, etc.
    private func bundledFileURL(for ambiance: LightAmbiance) -> URL? {
        for ext in ["m4a", "mp3", "wav", "aac"] {
            if let url = Bundle.main.url(forResource: "ambiance-\(ambiance.rawValue)", withExtension: ext) {
                return url
            }
        }
        return nil
    }

    private func playFile(_ url: URL, volume: Float) -> Bool {
        guard activateSession() else { return false }
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return false }
        player.numberOfLoops = -1
        player.volume = volume
        player.play()
        filePlayer = player
        isPlaying = true
        return true
    }

    private func activateSession() -> Bool {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            return true
        } catch {
            return false
        }
    }

    private func playSynthesized(_ soundscape: Soundscape, volume: Float) -> Bool {
        guard activateSession() else { return false }

        let sampleRate = 44_100.0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else { return false }
        let generator = SoundscapeGenerator(soundscape: soundscape, sampleRate: Float(sampleRate))
        let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            generator.render(frames: Int(frameCount), buffers: buffers)
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = volume
        do {
            try engine.start()
            sourceNode = node
            isPlaying = true
            return true
        } catch {
            engine.detach(node)
            return false
        }
    }

    func stop() {
        filePlayer?.stop()
        filePlayer = nil
        if let node = sourceNode {
            engine.stop()
            engine.detach(node)
            sourceNode = nil
        }
        isPlaying = false
        isPaused = false
        currentTitle = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Écran verrouillé / Centre de contrôle

    /// Boutons lecture/pause/stop de l'écran verrouillé, du Centre de contrôle
    /// et des écouteurs (AirPods, casque Bluetooth).
    private func configureRemoteCommands() {
        guard !remoteCommandsConfigured else { return }
        remoteCommandsConfigured = true
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.isPaused ? self.resume() : self.pause()
            return .success
        }
        center.stopCommand.addTarget { [weak self] _ in
            self?.stop()
            return .success
        }
    }

    private func updateNowPlaying(playing: Bool) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: currentTitle ?? "Ambiance",
            MPMediaItemPropertyArtist: "Habitat",
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0
        ]
    }
}

/// Générateur d'échantillons : un état par lecture, appelé depuis le rappel
/// temps réel (pas d'allocation ni de verrou — un RNG xorshift maison remplace
/// les générateurs système).
private final class SoundscapeGenerator {
    private let soundscape: AmbientSoundEngine.Soundscape
    private let sampleRate: Float

    private var rngState: UInt32 = 0x2EC27E5

    // Filtres partagés
    private var lowpass: Float = 0
    private var brown: Float = 0

    // Orage
    private var thunderEnvelope: Float = 0
    private var thunderLow: Float = 0
    private var samplesToNextThunder: Int = 0

    // Vagues
    private var wavePhase: Float = 0

    // Criquets
    private var cricketPhase: Float = 0
    private var chirpSamplesRemaining = 0
    private var samplesToNextChirp: Int = 0

    // Feu de camp
    private var popSamplesRemaining = 0
    private var popAmplitude: Float = 0
    private var samplesToNextPop: Int = 0

    init(soundscape: AmbientSoundEngine.Soundscape, sampleRate: Float) {
        self.soundscape = soundscape
        self.sampleRate = sampleRate
        samplesToNextThunder = Int(4 * sampleRate)
        samplesToNextChirp = Int(0.8 * sampleRate)
        samplesToNextPop = Int(0.2 * sampleRate)
    }

    func render(frames: Int, buffers: UnsafeMutableAudioBufferListPointer) {
        guard buffers.count >= 1 else { return }
        let left = buffers[0].mData?.assumingMemoryBound(to: Float.self)
        let right = buffers.count > 1 ? buffers[1].mData?.assumingMemoryBound(to: Float.self) : nil
        for frame in 0..<frames {
            let sample = nextSample()
            left?[frame] = sample
            right?[frame] = sample
        }
    }

    /// Bruit blanc dans [-1, 1] via xorshift (sûr en contexte temps réel).
    private func whiteNoise() -> Float {
        rngState ^= rngState << 13
        rngState ^= rngState >> 17
        rngState ^= rngState << 5
        return Float(Int32(bitPattern: rngState)) / Float(Int32.max)
    }

    /// Valeur pseudo-aléatoire dans [0, 1].
    private func randomUnit() -> Float {
        abs(whiteNoise())
    }

    private func nextSample() -> Float {
        switch soundscape {
        case .rain: return rainSample()
        case .storm: return stormSample()
        case .waves: return wavesSample()
        case .crickets: return cricketsSample()
        case .crackle: return crackleSample()
        }
    }

    /// Pluie : bruit blanc adouci (passe-bas) + un soupçon de crépitement aigu.
    private func rainSample() -> Float {
        let white = whiteNoise()
        lowpass += 0.08 * (white - lowpass)
        return lowpass * 0.8 + white * 0.05
    }

    /// Orage : pluie + grondements graves à intervalles aléatoires (8-22 s).
    private func stormSample() -> Float {
        var sample = rainSample()

        if samplesToNextThunder <= 0 {
            thunderEnvelope = 0.9
            samplesToNextThunder = Int((8 + randomUnit() * 14) * sampleRate)
        } else {
            samplesToNextThunder -= 1
        }

        if thunderEnvelope > 0.001 {
            thunderLow += 0.015 * (whiteNoise() - thunderLow)
            sample += thunderLow * thunderEnvelope * 4.0
            thunderEnvelope *= 0.99996
        }
        return max(-1, min(1, sample))
    }

    /// Vagues : bruit brun dont l'amplitude respire lentement (~14 s par vague).
    private func wavesSample() -> Float {
        brown += 0.02 * whiteNoise()
        brown *= 0.995
        wavePhase += (2 * .pi * 0.07) / sampleRate
        if wavePhase > 2 * .pi { wavePhase -= 2 * .pi }
        let swell = 0.35 + 0.30 * sin(wavePhase)
        return max(-1, min(1, brown * 2.2 * swell))
    }

    /// Nuit tropicale : fond très doux + stridulations aiguës périodiques.
    private func cricketsSample() -> Float {
        let white = whiteNoise()
        lowpass += 0.03 * (white - lowpass)
        var sample = lowpass * 0.12

        if chirpSamplesRemaining > 0 {
            chirpSamplesRemaining -= 1
            cricketPhase += (2 * .pi * 4200) / sampleRate
            if cricketPhase > 2 * .pi { cricketPhase -= 2 * .pi }
            // Trille : porteuse aiguë modulée à ~35 Hz.
            let trill = 0.5 + 0.5 * sin(2 * .pi * 35 * Float(chirpSamplesRemaining) / sampleRate)
            sample += sin(cricketPhase) * 0.18 * trill
        } else if samplesToNextChirp <= 0 {
            chirpSamplesRemaining = Int(0.25 * sampleRate)
            samplesToNextChirp = Int((0.6 + randomUnit() * 1.4) * sampleRate)
        } else {
            samplesToNextChirp -= 1
        }
        return sample
    }

    /// Feu de camp : souffle grave + craquements brefs aléatoires.
    private func crackleSample() -> Float {
        brown += 0.02 * whiteNoise()
        brown *= 0.995
        var sample = brown * 0.5

        if popSamplesRemaining > 0 {
            popSamplesRemaining -= 1
            sample += whiteNoise() * popAmplitude
            popAmplitude *= 0.9992
        } else if samplesToNextPop <= 0 {
            popSamplesRemaining = Int((0.004 + randomUnit() * 0.02) * sampleRate)
            popAmplitude = 0.15 + randomUnit() * 0.5
            samplesToNextPop = Int((0.05 + randomUnit() * 0.45) * sampleRate)
        } else {
            samplesToNextPop -= 1
        }
        return max(-1, min(1, sample))
    }
}

extension LightAmbiance {
    /// Paysage sonore intégré correspondant à l'ambiance, s'il existe.
    /// Cuba et Coucher de soleil sont musicales : pas de synthèse crédible,
    /// Spotify reste la meilleure option pour elles.
    var builtinSoundscape: AmbientSoundEngine.Soundscape? {
        switch self {
        case .rain: return .rain
        case .storm: return .storm
        case .deepOcean, .reef: return .waves
        case .rainforest, .night: return .crickets
        case .campfire: return .crackle
        case .cuba, .sunset: return nil
        }
    }
}
