# Terrarium Log

Application SwiftUI iOS pour suivre l'évolution d'animaux en terrarium/vivarium (araignées sauteuses, colonies de fourmis, et plus tard d'autres espèces) : fiches animaux, terrariums, timeline d'événements, repas, mues, rappels locaux, mesures d'environnement.

## Architecture

- **SwiftUI + SwiftData**, données 100% locales, hors ligne. Un seul `ModelContainer` (`Services/PersistenceController.swift`) charge le schéma et sème des données de démonstration au premier lancement.
- **Modèles** (`Models/`) : `Animal`, `Terrarium`, `ObservationEntry` (timeline unifiée : observations, repas et mues sont un seul type d'événement avec des champs optionnels typés selon le cas), `Reminder`, `MeasurementEntry`, `Plant`, `PrintedPart`.
- **Services** (`Services/`) : `PhotoStorage` (stockage fichier local des photos), `NotificationService` (rappels locaux `UserNotifications`), `ReminderService` (complétion + récurrence des rappels), `FeedingStats`/`MoltStats` (calculs purs sur la timeline), `SensorDataProvider` (mock, point d'extension futur pour capteurs réels).
- **Vues** (`Views/`) : tab bar à 5 onglets — Dashboard, Animaux, Terrariums, Timeline, Réglages. Rappels et Mesures restent des écrans à part entière, accessibles par navigation depuis le Dashboard et la fiche Terrarium plutôt que via des onglets dédiés.

## Portée V1 (MVP)

Fait : CRUD animaux/terrariums, association animal ↔ terrarium, photos, notes, repas, mues, timeline automatique par animal et globale, rappels locaux avec récurrence, dashboard avec indicateur d'état coloré, plantes et pièces imprimées 3D rattachées au terrarium.

Volontairement **non implémenté** en V1 (voir cahier des charges complet pour le contexte) :

- **Capteurs ESP32 / automatisation** (`Device`, `Sensor`, `Actuator`) : `SensorDataProvider` est un point d'extension déjà en place (protocole + implémentation mock). Les vrais modèles de données ne seront créés qu'une fois le firmware ESP32 et le format des payloads connus, pour éviter une migration de schéma prématurée.
- **Analyse IA par photo** (`AIAnalysis`) : aucun placeholder de modèle n'a été créé volontairement — à concevoir quand un vrai jeu de données de photos annotées existe.
- **Synchronisation iCloud/CloudKit** : le schéma SwiftData est déjà conçu pour être compatible (relations optionnelles, valeurs par défaut sur toutes les propriétés stockées, aucune contrainte `@Attribute(.unique)`), mais la synchronisation n'est pas activée.
- **Export/import JSON** : non implémenté.
- **Bibliothèque de fichiers STL** : le modèle `PrintedPart` stocke des métadonnées (matériau, technologie, usage) mais pas de fichier associé.

## Lancer sur le simulateur

Le projet utilise [XcodeGen](https://github.com/yonaskolb/XcodeGen) : `project.yml` décrit les cibles `TerrariumLog` (app) et `TerrariumLogTests` (tests unitaires), le fichier `.xcodeproj` n'est pas versionné.

```bash
xcodegen generate --spec project.yml
xcodebuild -project TerrariumLog.xcodeproj -scheme TerrariumLog \
  -destination 'platform=iOS Simulator,name=<un simulateur disponible>' build
```

Le workflow GitHub Actions (`.github/workflows/build-ios.yml`) fait exactement ça sur chaque push, plus l'exécution des tests unitaires et une capture d'écran du Dashboard au premier lancement, publiée comme artifact `screenshots`.

## Publier sur TestFlight

Ces étapes ne peuvent pas être automatisées depuis ce dépôt/CI : elles nécessitent un compte Apple Developer et une configuration locale dans Xcode.

1. Rejoindre l'Apple Developer Program (si ce n'est pas déjà fait) et créer l'app dans [App Store Connect](https://appstoreconnect.apple.com).
2. Ouvrir `TerrariumLog.xcodeproj` (généré par `xcodegen`) dans Xcode, sélectionner la cible `TerrariumLog` → onglet *Signing & Capabilities* → choisir son Team, laisser *Automatically manage signing* activé.
3. Remplacer `PRODUCT_BUNDLE_IDENTIFIER` (actuellement `com.example.terrariumlog`, un identifiant de développement) par un identifiant réel enregistré sur son compte, dans `project.yml`.
4. Archiver : *Product → Archive*, puis *Distribute App → App Store Connect → Upload*.
5. Dans App Store Connect, ajouter le build à un groupe de testeurs internes/externes TestFlight.

## Tests

```bash
xcodebuild -project TerrariumLog.xcodeproj -scheme TerrariumLog \
  -destination 'platform=iOS Simulator,name=<un simulateur disponible>' test
```

Tests unitaires dans `TerrariumLogTests/` : récurrence des rappels (`Reminder.nextOccurrence`), calculs de statistiques repas/mues (`FeedingStats`, `MoltStats`), niveaux d'alerte de statut animal.
