# Gestionale Fenice per iOS

App nativa per iPhone e iPad (SwiftUI) per gestire le ripetizioni di La Fenice: studenti che prenotano lezioni nelle
fasce dei tutor, saldo a debito con addebito 12 ore prima, richieste di annullamento e pannello di amministrazione.

È il porting mobile del gestionale web (Next.js) "Ardentis Fenice", limitato al nucleo essenziale.
I dettagli sono in [docs/DOCUMENTAZIONE.md](docs/DOCUMENTAZIONE.md).

## Requisiti

- iOS / iPadOS 17 o successivo
- Un Mac con Xcode 16 o successivo (Swift 5.9+)

## Avvio

Apri `GestionaleFenice.xcodeproj` in Xcode, scegli lo schema `GestionaleFenice` e un simulatore
(per esempio iPhone 15) e premi ⌘R.

Per installarla su un iPhone vero: collega il telefono, in **Signing & Capabilities** scegli il tuo team
(basta un Apple ID gratuito) e premi ⌘R con l'iPhone selezionato come destinazione.

Al primo avvio viene creato il database con cinque materie e l'amministratore:

| Email | Password |
|---|---|
| `admin@ardentisfenice.it` | `admin1234` |

Da **Impostazioni → Dati di prova** si aggiungono `tutor@demo.it` e `studente@demo.it` (password `demo12345`).

## Test

```bash
swift test
```

La logica (`FeniceCore`) non dipende da SwiftUI, quindi i test girano anche su Linux, per esempio con Docker:

```bash
docker run --rm -v "$PWD:/src" -w /src swift:5.10-jammy swift test
```

La workflow in `.github/workflows/build.yml` a ogni push lancia i test e compila l'app per il simulatore iOS
su un runner macOS.

## Struttura

```
GestionaleFenice.xcodeproj  # progetto dell'app iOS (target app + framework FeniceCore)
Package.swift               # pacchetto con il solo core, per i test
Sources/
├── FeniceCore/          # logica e dati, senza interfaccia
│   ├── Models/          # User, Subject, Availability, Booking, CancellationRequest, ...
│   ├── Store/           # FeniceStore e le sue estensioni per area (auth, fasce, prenotazioni, ...)
│   └── Format.swift     # euro, date e durate in italiano
└── FeniceApp/           # app SwiftUI
    ├── FeniceApp.swift  # @main
    ├── AppState.swift   # stato condiviso, sessione, manutenzione ogni minuto
    ├── MainView.swift   # menu per ruolo (a colonne su iPad)
    ├── Student/ Tutor/ Admin/ Bookings/ Common/
    └── PBKDF2Hasher.swift
Tests/FeniceCoreTests/   # 45 test XCTest sulle regole di dominio
docs/                    # documentazione
```

## Dati

Tutto è salvato nel file `database.json` dentro la cartella Application Support dell'app, sul dispositivo.
Per un backup l'admin può esportarne una copia da **Impostazioni → Database**; per ripartire da zero basta
disinstallare l'app.
