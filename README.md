# Oldies 👓

**Din svenska AI-assistent i Meta Ray-Ban-glasögonen.**

Oldies är en iOS-app som låter dig prata med en AI-assistent (GPT-4o, Claude eller Ollama) direkt via dina Meta Ray-Ban smarta glasögon — på svenska. Assistenten kan se vad du ser via glasögonens kamera och svara med talsyntes i glasögonens högtalare.

---

## Funktioner

- **Svenska röstkommandon** — SFSpeechRecognizer med sv-SE-modell, helt on-device
- **Text-till-tal** — Apples Alva-röst (sv-SE), spelas upp i glasögonens högtalare
- **Kameravision** — bifoga bild från glasögonen automatiskt eller manuellt
- **Multi-provider AI:**
  - OpenAI GPT-4o (med bildstöd)
  - Anthropic Claude (claude-opus-4-6, claude-sonnet-4-6, claude-haiku-4-5-20251001)
  - Ollama (self-hosted, konfigurerbar URL)
- **Konfigurerbar systemprompt** — anpassa assistentens personlighet
- **Fullt onboarding-flöde** — koppla glasögon + sätt upp AI-nyckel vid första start

---

## Krav

| Komponent | Version |
|---|---|
| iOS | 17.0+ |
| Xcode | 15.0+ |
| Meta Ray-Ban glasögon | Alla modeller med Meta AI-appen |
| Meta AI-appen | Senaste versionen |
| Swift | 5.10 |

---

## Kom igång

### 1. Klona repot

```bash
git clone https://github.com/MrPink12/Oldies.git
cd Oldies
```

### 2. Kör setup-skriptet

```bash
chmod +x setup.sh && ./setup.sh
```

Skriptet installerar Homebrew + XcodeGen (om de saknas), genererar `Oldies.xcodeproj` och öppnar projektet i Xcode.

### 3. Bygg & kör

1. Välj din iPhone som körmål i Xcode
2. Tryck **⌘R**
3. Appen guidar dig genom att ansluta glasögonen + ange AI-nyckel

---

## Projektstruktur

```
Oldies/
├── project.yml                          # XcodeGen-konfiguration
├── setup.sh                             # Installations- och genereringsskript
├── Sources/Oldies/
│   ├── App/
│   │   ├── OldiesApp.swift              # @main, Wearables.configure()
│   │   └── RootView.swift               # Onboarding ↔ AssistantView
│   ├── Core/
│   │   ├── AI/
│   │   │   ├── AIProvider.swift         # Protokoll + AIMessage
│   │   │   ├── OpenAIProvider.swift     # GPT-4o med streaming + vision
│   │   │   ├── OllamaProvider.swift     # Ollama /api/chat
│   │   │   ├── ClaudeProvider.swift     # Anthropic Messages API
│   │   │   └── AIEngine.swift           # Factory + konversationshistorik
│   │   ├── Glasses/
│   │   │   └── GlassesManager.swift     # Meta DAT SDK-wrapper
│   │   ├── Storage/
│   │   │   └── AppSettings.swift        # @AppStorage-inställningar
│   │   └── Voice/
│   │       ├── SpeechRecognizer.swift   # STT (sv-SE, on-device)
│   │       └── SpeechSynthesizer.swift  # TTS (Alva, sv-SE)
│   ├── Features/
│   │   ├── Assistant/
│   │   │   ├── AssistantView.swift      # Chattgränssnitt
│   │   │   └── AssistantViewModel.swift # Röst→AI→TTS-pipeline
│   │   ├── Camera/
│   │   │   └── CameraPreviewView.swift  # Live-kameraström
│   │   ├── Settings/
│   │   │   └── SettingsView.swift       # AI-leverantör, API-nycklar, röst
│   │   └── Onboarding/
│   │       └── OnboardingView.swift     # Välkommen → Anslut → AI → Klar
│   └── Resources/
│       ├── Info.plist                   # URL-schema, MWDAT, behörigheter
│       ├── Oldies.entitlements          # Associated Domains
│       └── Assets.xcassets/             # Ikon, accentfärg
```

---

## Distribution

> **Obs:** Meta DAT stöder ännu inte TestFlight eller App Store. Appen distribueras via **Metas egna releasekanaler** (liknande enterprise-distribution). Se [Meta DAT-dokumentationen](https://developer.meta.com/wearables-dat/) för aktuell distributionsstatus.

För testning under utveckling: anslut din iPhone direkt via USB och kör från Xcode med ditt Apple Developer-konto (Team ID: WU26G28D5P).

---

## Konfiguration

### AI-leverantör

Välj leverantör i **Inställningar → AI-leverantör**:

| Leverantör | Kräver |
|---|---|
| OpenAI | API-nyckel från platform.openai.com |
| Claude | API-nyckel från console.anthropic.com |
| Ollama | Tillgänglig server (standard: https://hagstrom.ddns.net/ollama) |

### Systemprompt

Ändra assistentens beteende i **Inställningar → Systemprompt**. Standard:
> "Du är en hjälpsam svensk AI-assistent inbyggd i Meta Ray-Ban-glasögon. Svara alltid på svenska. Var kortfattad och tydlig."

---

## Teknik

| Komponent | Teknologi |
|---|---|
| Meta SDK | Meta Wearables DAT (MWDATCore + MWDATCamera) |
| Röst in | Apple Speech (SFSpeechRecognizer, sv-SE) |
| Röst ut | AVSpeechSynthesizer (Alva, sv-SE) |
| AI-anrop | Async/await + SSE-streaming |
| UI | SwiftUI + MVVM |
| Inställningar | @AppStorage (UserDefaults) |
| Projektsystem | XcodeGen (project.yml) |

---

## Meta App-uppgifter

| Fält | Värde |
|---|---|
| App ID | 1958523175039520 |
| Bundle ID | com.hagstrom.oldies |
| Team ID | WU26G28D5P |
| URL-schema | `oldies://` |
| Universal Link | https://hagstroem.net/oldies |

---

## Licens

MIT © Peter Hagström
