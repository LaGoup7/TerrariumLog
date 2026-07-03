# Terrarium Log

Application SwiftUI iOS pour suivre l'évolution d'animaux en terrarium/vivarium (araignées sauteuses, colonies de fourmis, et plus tard d'autres espèces) : fiches animaux, terrariums, timeline d'événements, repas, mues, rappels locaux, mesures d'environnement.

## Architecture

- **SwiftUI + SwiftData**, données 100% locales, hors ligne. Un seul `ModelContainer` (`Services/PersistenceController.swift`) charge le schéma et sème des données de démonstration au premier lancement.
- **Modèles** (`Models/`) : `Animal`, `Terrarium`, `ObservationEntry` (timeline unifiée : observations, repas et mues sont un seul type d'événement avec des champs optionnels typés selon le cas), `Reminder`, `MeasurementEntry`, `Plant`.
- **Services** (`Services/`) : `PhotoStorage` (stockage fichier local des photos), `NotificationService` (rappels locaux `UserNotifications`), `ReminderService` (complétion + récurrence des rappels), `FeedingStats`/`MoltStats` (calculs purs sur la timeline), `WizCommand`/`WizLightService` (contrôle local en UDP d'une ampoule WiZ par terrarium), `SensorDataProvider` (mock, point d'extension futur pour capteurs réels).
- **Vues** (`Views/`) : tab bar à 5 onglets — Dashboard, Animaux, Terrariums, Timeline, Réglages. Rappels et Mesures restent des écrans à part entière, accessibles par navigation depuis le Dashboard et la fiche Terrarium plutôt que via des onglets dédiés.
- **Widget** (`TerrariumLogWidget/`) : extension WidgetKit affichant les prochains rappels sur l'écran d'accueil. Ne lit **jamais** le store SwiftData principal directement — elle lit un petit instantané JSON (`Shared/WidgetSnapshot.swift`) écrit par l'app via un App Group (`group.com.example.terrariumlog`) à chaque création/suppression/complétion de rappel. Ce choix est délibéré : si l'App Group n'est pas disponible avec la signature utilisée (voir plus bas), la sauvegarde/lecture du snapshot échoue silencieusement sans jamais toucher aux vraies données de l'utilisateur — seul le widget reste vide.

## Portée V1 (MVP)

Fait : CRUD (créer/modifier/supprimer) animaux/terrariums, association animal ↔ terrarium, photos (animaux et terrariums), notes, repas, mues/diapause selon l'espèce, timeline automatique par animal et globale, rappels locaux avec récurrence et complétion directe depuis la notification, calendrier des rappels, dashboard avec indicateur d'état coloré, plantes et caméras rattachées au terrarium, contrôle local d'une ampoule WiZ (allumer/éteindre, intensité, teinte), export/import JSON des données (avec photos), widget d'écran d'accueil pour les prochains rappels, graphiques d'environnement (température/humidité/luminosité, filtrables 24h/semaine/mois via `EnvironmentChartsView`) sur la fiche animal, la fiche terrarium et l'écran Mesures, filtres de galerie par catégorie, vue "Life Story" par animal (frise groupée par année), sections Santé et Statistiques sur la fiche animal, vidéos par animal (titre/notes/date, lecture locale via AVKit, import avec barre de progression et annulation), export/import JSON incluant photos et vidéos, date d'arrivée éditable, photo principale terrarium/animal recadrable au doigt (carré, glisser-déposer, `RepositionableSquareImage`), ajout de rappel et accès au calendrier directement depuis le Dashboard, gestion des animaux affichés/masqués sur le Dashboard, ajout direct de photos dans la galerie d'un animal, sélection multiple d'animaux à la création d'un rappel (crée un rappel par animal sélectionné).

Volontairement **non implémenté** en V1 (voir cahier des charges complet pour le contexte) :

- **Capteurs ESP32 / automatisation** (`Device`, `Sensor`, `Actuator`) : `SensorDataProvider` est un point d'extension déjà en place (protocole + implémentation mock). Les vrais modèles de données ne seront créés qu'une fois le firmware ESP32 et le format des payloads connus, pour éviter une migration de schéma prématurée.
- **Analyse IA par photo** (`AIAnalysis`) : aucun placeholder de modèle n'a été créé volontairement — à concevoir quand un vrai jeu de données de photos annotées existe.
- **Synchronisation iCloud/CloudKit** : le schéma SwiftData est déjà conçu pour être compatible (relations optionnelles, valeurs par défaut sur toutes les propriétés stockées, aucune contrainte `@Attribute(.unique)`), mais la synchronisation n'est pas activée.

## Lancer sur le simulateur

Le projet utilise [XcodeGen](https://github.com/yonaskolb/XcodeGen) : `project.yml` décrit les cibles `TerrariumLog` (app) et `TerrariumLogTests` (tests unitaires), le fichier `.xcodeproj` n'est pas versionné.

```bash
xcodegen generate --spec project.yml
xcodebuild -project TerrariumLog.xcodeproj -scheme TerrariumLog \
  -destination 'platform=iOS Simulator,name=<un simulateur disponible>' build
```

Le workflow GitHub Actions (`.github/workflows/build-ios.yml`) fait exactement ça sur chaque push, plus l'exécution des tests unitaires et une capture d'écran du Dashboard au premier lancement, publiée comme artifact `screenshots`.

## Tester sur son iPhone sans compte Apple Developer payant (Windows/sideloading)

Pas besoin de Mac ni de compte payant pour installer l'app sur son propre iPhone :

1. Le workflow CI génère aussi un `.ipa` non signé à chaque push, publié comme artifact **`TerrariumLog-unsigned-ipa`** (onglet *Actions* du dépôt GitHub → sélectionner le run → section *Artifacts*).
2. Télécharger ce `.ipa` sur son PC Windows.
3. Installer [Sideloadly](https://sideloadly.io/) (gratuit) sur Windows, connecter l'iPhone en USB.
4. Dans Sideloadly, glisser le `.ipa`, se connecter avec un **Apple ID gratuit** (pas besoin du programme payant) : Sideloadly le signe et l'installe directement sur l'iPhone.
5. Limite d'Apple pour les Apple ID gratuits : l'app expire au bout de **7 jours**, il faut la réinstaller/re-signer (Sideloadly peut automatiser un rafraîchissement périodique en Wi-Fi tant que l'iPhone reste sur le même réseau que le PC).

C'est la solution la plus rapide pour itérer depuis Windows sans compte Developer. TestFlight (ci-dessous) reste préférable pour une distribution plus stable ou à plusieurs testeurs.

### Statut connu : widget + App Group sur signature gratuite

Les App Groups (nécessaires pour que le widget lise les données de l'app) sont une capacité qui doit normalement être activée sur un App ID via le portail développeur Apple. Sans compte payant, il n'est pas certain que ça fonctionne avec un Apple ID gratuit signé via Sideloadly — ni ce dépôt/CI (build non signé, simulateur uniquement) ni l'auteur de ce code n'ont pu le vérifier sur un vrai appareil. Si le widget reste vide une fois installé (aucun crash attendu, voir plus haut), c'est probablement cette limitation ; le reste de l'app continue de fonctionner normalement dans ce cas.

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
