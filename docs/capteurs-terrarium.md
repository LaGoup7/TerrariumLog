# Capteurs du terrarium — plan complet (Habitat × ESP32)

Objectif : mesurer **température, humidité de l'air et humidité du sol** dans le
terrarium, et pouvoir **brumiser** et **arroser les plantes** depuis l'app
**Habitat** — 100 % en réseau local, sans cloud, comme les lampes WiZ et la caméra.

---

## 1. Architecture

```
                    Wi-Fi local (2,4 GHz)
   iPhone (Habitat) ◄──────────────────────► ESP32 (serveur HTTP)
                                              │
                       ┌──────────────────────┼──────────────────────┐
                       │                      │                      │
                  DHT22 (air)         Capteur de sol           2× relais 5 V
                  temp + humidité     capacitif (analogique)    │         │
                                                           Brumisateur  Pompe
                                                           à ultrasons  d'arrosage
```

**API HTTP exposée par l'ESP32** (celle que l'app appelle déjà) :

| Route | Méthode | Rôle | Réponse |
|---|---|---|---|
| `/sensors` | GET | relevé instantané | `{"temperature":24.5,"humidity":78,"soil":41}` |
| `/mist` | POST | brumisation (durée fixe côté module) | `{"ok":true}` |
| `/water` | POST | arrosage (durée fixe côté module) | `{"ok":true}` |

L'app tolère aussi les clés `temp/hum/sol/lux`.

**Côté app (déjà en place)** :
- Champ **« Capteurs (ESP32) — Adresse IP »** dans le formulaire du terrarium.
- Carte **Capteurs** sur la fiche terrarium : tuiles Air / Humidité / Sol / Lumière,
  boutons **Brumiser** / **Arroser**, bouton **Enregistrer** qui verse le relevé
  dans l'historique de mesures (graphiques existants).

---

## 2. Liste du matériel

### Indispensable (~25-35 € hors kit)

| Objet | Rôle | Prix approx. | Remarques |
|---|---|---|---|
| **ESP32 DevKit** (ex. ESP32-WROOM-32) | cerveau + Wi-Fi | 6-10 € | ⚠️ l'UNO R3 n'a pas de Wi-Fi ; l'ESP32 le remplace avantageusement |
| **DHT22 / AM2302** | température + humidité de l'air | 4-6 € | plus précis que le DHT11 (souvent dans les kits Elegoo) |
| **Capteur d'humidité de sol capacitif v1.2** | humidité du substrat | 2-3 € | **capacitif obligatoire** (les résistifs à pointes s'oxydent en qq semaines) |
| **Module 2 relais 5 V** (opto-isolés) | commande brumisateur + pompe | 3-5 € | |
| **Mini pompe à eau 5 V** + tuyau silicone | arrosage | 3-5 € | immergée dans un réservoir |
| **Brumisateur à ultrasons 5 V** (mist maker) | brumisation | 5-8 € | ou une 2ᵉ pompe + buse de brumisation |
| Alimentation USB 5 V ≥ 2 A + câbles Dupont | | 0-8 € | alimenter pompes/brumisateur **séparément** de l'ESP32 |

### Optionnel
| Objet | Rôle | Prix |
|---|---|---|
| Photorésistance (LDR) + résistance 10 kΩ | luminosité (`lux` dans l'app) | ~1 € |
| Boîtier étanche / IP54 | protéger l'électronique de l'humidité | 5-10 € |
| Clapet anti-retour + réservoir | circuit d'eau propre | 3-5 € |

### Et l'Elegoo UNO R3 ?
Utilisable en **esclave d'actionneurs** (l'ESP32 lui parle en série) si tu veux
répartir, mais pour ce projet **l'ESP32 seul suffit** : moins de câblage, moins de
pannes. Garde l'UNO pour un prochain projet (distributeur de nourriture motorisé,
par ex. — le kit Elegoo a un servo SG90 parfait pour ça).

---

## 3. Câblage (ESP32)

| Composant | Broche composant | Broche ESP32 |
|---|---|---|
| DHT22 | VCC / DATA / GND | 3V3 / **GPIO 4** / GND (résistance 10 kΩ entre VCC et DATA si module nu) |
| Sol capacitif | VCC / AOUT / GND | 3V3 / **GPIO 34** (entrée analogique) / GND |
| Relais 1 (brumisateur) | IN1 | **GPIO 26** |
| Relais 2 (pompe) | IN2 | **GPIO 27** |
| LDR (option) | pont diviseur | **GPIO 35** |

⚠️ Règles d'or :
- **GND commun** entre ESP32, relais et alimentation des pompes.
- Les pompes/brumisateur sont alimentés par le **5 V de l'alim**, jamais par les
  broches de l'ESP32 (elles ne fournissent pas assez de courant).
- L'électronique reste **hors du terrarium** ; seules les sondes entrent.

---

## 4. Code ESP32 (sketch principal)

À flasher avec l'IDE Arduino (gestionnaire de cartes « esp32 », bibliothèques
`DHT sensor library` d'Adafruit + `ArduinoJson` facultative — ici JSON à la main).

```cpp
// Habitat — module capteurs terrarium (ESP32)
// API : GET /sensors · POST /mist · POST /water
#include <WiFi.h>
#include <WebServer.h>
#include <DHT.h>

// ==== À ADAPTER ====
const char* WIFI_SSID = "TON_WIFI";
const char* WIFI_PASS = "TON_MOT_DE_PASSE";
const int   MIST_SECONDS  = 5;   // durée de brumisation
const int   WATER_SECONDS = 3;   // durée d'arrosage
// Étalonnage du capteur de sol : valeurs lues à sec et dans l'eau
const int   SOIL_DRY = 3200;     // valeur brute "sec"
const int   SOIL_WET = 1300;     // valeur brute "trempé"
// ===================

#define DHT_PIN   4
#define DHT_TYPE  DHT22
#define SOIL_PIN  34
#define MIST_PIN  26
#define WATER_PIN 27
// Beaucoup de modules relais sont actifs à l'état BAS :
#define RELAY_ON  LOW
#define RELAY_OFF HIGH

DHT dht(DHT_PIN, DHT_TYPE);
WebServer server(80);

float readSoilPercent() {
  int raw = analogRead(SOIL_PIN);
  float pct = 100.0 * (SOIL_DRY - raw) / (float)(SOIL_DRY - SOIL_WET);
  return constrain(pct, 0, 100);
}

void handleSensors() {
  float t = dht.readTemperature();
  float h = dht.readHumidity();
  String json = "{";
  bool first = true;
  if (!isnan(t)) { json += "\"temperature\":" + String(t, 1); first = false; }
  if (!isnan(h)) { json += String(first ? "" : ",") + "\"humidity\":" + String(h, 0); first = false; }
  json += String(first ? "" : ",") + "\"soil\":" + String(readSoilPercent(), 0);
  json += "}";
  server.send(200, "application/json", json);
}

void pulse(int pin, int seconds) {
  digitalWrite(pin, RELAY_ON);
  delay(seconds * 1000UL);      // durées courtes : blocage acceptable
  digitalWrite(pin, RELAY_OFF);
}

void handleMist()  { pulse(MIST_PIN,  MIST_SECONDS);  server.send(200, "application/json", "{\"ok\":true}"); }
void handleWater() { pulse(WATER_PIN, WATER_SECONDS); server.send(200, "application/json", "{\"ok\":true}"); }

void setup() {
  Serial.begin(115200);
  pinMode(MIST_PIN, OUTPUT);  digitalWrite(MIST_PIN, RELAY_OFF);
  pinMode(WATER_PIN, OUTPUT); digitalWrite(WATER_PIN, RELAY_OFF);
  dht.begin();

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  while (WiFi.status() != WL_CONNECTED) { delay(500); Serial.print("."); }
  Serial.println();
  Serial.print("Module capteurs prêt : http://");
  Serial.println(WiFi.localIP());   // ← cette IP va dans Habitat

  server.on("/sensors", HTTP_GET,  handleSensors);
  server.on("/mist",    HTTP_POST, handleMist);
  server.on("/water",   HTTP_POST, handleWater);
  server.begin();
}

void loop() { server.handleClient(); }
```

### Étalonnage du capteur de sol (5 min)
1. Ouvre le moniteur série, note la valeur brute **capteur à l'air libre** → `SOIL_DRY`.
2. Plonge la partie striée **dans un verre d'eau** → `SOIL_WET`.
3. Reporte les deux valeurs dans le sketch, re-flashe.

---

## 5. Variante avec l'UNO R3 (optionnelle)

Si tu tiens à utiliser l'UNO comme esclave d'actionneurs (relais branchés dessus),
l'ESP32 lui envoie `M\n` (mist) ou `W\n` (water) en série (TX2→RX, GND commun).

```cpp
// Elegoo UNO R3 — esclave actionneurs (optionnel)
#define MIST_PIN  7
#define WATER_PIN 8
#define RELAY_ON  LOW
#define RELAY_OFF HIGH

void setup() {
  Serial.begin(9600);
  pinMode(MIST_PIN, OUTPUT);  digitalWrite(MIST_PIN, RELAY_OFF);
  pinMode(WATER_PIN, OUTPUT); digitalWrite(WATER_PIN, RELAY_OFF);
}

void pulse(int pin, unsigned long ms) {
  digitalWrite(pin, RELAY_ON); delay(ms); digitalWrite(pin, RELAY_OFF);
}

void loop() {
  if (Serial.available()) {
    char c = Serial.read();
    if (c == 'M') pulse(MIST_PIN, 5000);
    if (c == 'W') pulse(WATER_PIN, 3000);
  }
}
```

---

## 6. Mise en service (checklist)

1. ☐ Flasher l'ESP32, ouvrir le moniteur série, noter **l'IP affichée**.
2. ☐ Réserver cette IP dans la box (bail DHCP statique) — comme pour la caméra.
3. ☐ Tester depuis un navigateur du PC : `http://<ip>/sensors` doit afficher le JSON.
4. ☐ Dans **Habitat** : Terrariums → ton terrarium → Modifier → **Capteurs (ESP32)** → saisir l'IP.
5. ☐ La carte **Capteurs** apparaît sur la fiche terrarium : valeurs, Brumiser, Arroser.
6. ☐ **Enregistrer** un relevé → il alimente les graphiques Température/Humidité.

## 7. Évolutions prévues côté app
- Relevé automatique périodique (à l'ouverture de l'app) + seuils/notifications
  (« humidité < 60 % → rappel brumisation »).
- Automatisation : arrosage auto sous un seuil de sol, avec garde-fous.
- Tuile capteurs sur le Dashboard.
