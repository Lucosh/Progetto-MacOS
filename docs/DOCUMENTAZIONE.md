# Gestionale Fenice per iOS — Documentazione

**Piattaforma:** iOS / iPadOS 17+, SwiftUI · **Linguaggio:** Swift 5.9 · **Dati:** file JSON locale · **Test:** XCTest

## 1. Obiettivo e perimetro

L'app porta su iPhone e iPad il gestionale web per le ripetizioni di La Fenice. È un'applicazione **locale**: un
solo dispositivo (per esempio l'iPad della segreteria) con un database su file. Si entra con email e password e
l'interfaccia cambia in base al ruolo: **Studente**, **Tutor** o **Admin**.

Rispetto alla versione web è stato portato il **nucleo essenziale**:

| Incluso | Lasciato fuori (per ora) |
|---|---|
| Login, registrazione studenti, tre ruoli | Verifica dell'email con codice (non c'è un server SMTP) |
| Materie con tariffa globale o specifica | Colloqui con tutor/amministrazione |
| Fasce di disponibilità dei tutor | Lezioni settimanali ricorrenti |
| Prenotazione guidata con slot ogni 30 minuti | Proposte di anticipo della lezione |
| Saldo a debito, addebito 12 ore prima | Compensi dei tutor e resoconti mensili |
| Richieste di annullamento con approvazione e inoltro | Messaggi di massa, promemoria giornalieri |
| Gestione utenti e saldi da parte dell'admin | Backup programmati, foto profilo, calendario settimanale |
| Notifiche dentro l'app, profilo, cambio password | |

## 2. Architettura

Il codice è diviso in due moduli:

- **FeniceCore**: modelli, regole e salvataggio. Non importa SwiftUI, quindi si compila e si testa anche fuori
  da iOS (è anche un pacchetto Swift, `Package.swift`, usato per i test).
- **FeniceApp**: l'interfaccia SwiftUI per iOS, che usa FeniceCore.

`GestionaleFenice.xcodeproj` ha due target: il framework **FeniceCore** e l'app **GestionaleFenice**, che lo
include. I file vengono presi direttamente dalle cartelle `Sources/FeniceCore` e `Sources/FeniceApp`.

**Interfaccia.** Su iPhone si parte dal menu del proprio ruolo e si entra nelle sezioni; su iPad il menu resta
a sinistra e la sezione scelta a destra (`NavigationSplitView`). I moduli si aprono come fogli con *Annulla* e
conferma nella barra in alto.

```
 SwiftUI Views ──► AppState (ObservableObject) ──► FeniceStore ──► Persistence ──► database.json
                     ▲ timer 60 s: runMaintenance()      │
                     └───────── revision += 1 ◄──────────┘
```

**FeniceStore** è l'unico punto da cui passano letture e modifiche. Le funzioni sono divise per area in più file
(`+Auth`, `+Schedule`, `+Booking`, `+Cancellations`, `+Admin`, `+Profile`, `+Tutor`).

**Modifiche atomiche.** Ogni modifica passa da `mutate`: lavora su una copia del database, la salva e solo dopo
la rende effettiva. Se una validazione fallisce o il salvataggio non riesce, lo stato in memoria non cambia.

**Errori.** Le funzioni lanciano `FeniceError` con un messaggio già pronto per l'utente. L'interfaccia lo mostra
in un alert (`AppState.perform`) o dentro il foglio modale aperto (`AppState.attempt`).

**Tempo iniettabile.** Lo store riceve `now` e `calendar` dall'esterno: nei test l'orologio è finto e si può
spostare avanti per verificare addebiti e scadenze.

**Manutenzione.** All'avvio e poi ogni minuto `runMaintenance()` addebita le lezioni che iniziano entro 12 ore e
segna come svolte quelle finite. Salva su disco solo se qualcosa è cambiato.

**Password.** Le password non vengono mai salvate in chiaro: si salvano un salt casuale per utente e l'hash
PBKDF2-SHA256 con 120.000 iterazioni (CommonCrypto). Nel core l'algoritmo è un protocollo (`PasswordHasher`),
così i test usano una versione veloce.

## 3. Ruoli e permessi

| Funzionalità | Studente | Tutor | Admin |
|---|:---:|:---:|:---:|
| Registrarsi da solo | ✔ | | |
| Prenotare una lezione, chiedere l'annullamento | ✔ | | |
| Vedere saldo e movimenti propri | ✔ | | |
| Pubblicare ed eliminare fasce, scegliere le materie | | ✔ | |
| Agenda, elenco dei propri studenti con saldo | | ✔ | |
| Decidere gli annullamenti delle proprie lezioni / inoltrarli | | ✔ | |
| Decidere qualsiasi annullamento aperto | | | ✔ |
| Creare, modificare, disattivare utenti; reimpostare password | | | ✔ |
| Registrare pagamenti, aggiungere credito, impostare il saldo | | | ✔ |
| Materie, tariffa globale, dati di prova | | | ✔ |
| Notifiche e profilo | ✔ | ✔ | ✔ |

I controlli stanno nello store, non solo nell'interfaccia: per esempio `requireAdmin` rilegge l'utente e
verifica ruolo e stato attivo prima di ogni operazione di amministrazione.

## 4. Flussi principali

### Studente
1. **Prenota:** materia e durata (1 h, 1 h 30, 2 h) → disponibilità ad anticipare → tutor (solo quelli che
   insegnano la materia e hanno almeno uno slot libero) → giorno → orario → riepilogo con prezzo e nota
   facoltativa (max 300 caratteri) → conferma. Tutor e studente ricevono una notifica.
2. **Le mie lezioni:** saldo, lezioni in programma e storico; dal dettaglio di una lezione si chiede
   l'annullamento con un motivo.
3. **Saldo:** importo attuale e storico dei movimenti.

### Tutor
1. **Disponibilità:** giorno, ora di inizio e di fine (a passi di 30 minuti, fine entro le 23:30, almeno 1 ora).
   Le fasce non si possono sovrapporre e si eliminano solo se non hanno prenotazioni.
2. **Agenda:** lezioni confermate raggruppate per giorno, con nota e disponibilità ad anticipare.
3. **Annullamenti:** approva, rifiuta o inoltra all'amministrazione.
4. **Studenti** con saldo e prossima lezione, **Materie** insegnate.

### Admin
1. **Panoramica:** studenti e tutor attivi, lezioni in programma, annullamenti aperti, totale da incassare.
2. **Utenti:** ricerca, filtro per ruolo, scheda con anagrafica, saldo, account e lezioni.
3. **Annullamenti:** prima le richieste inoltrate, poi lo storico con chi ha deciso.
4. **Materie** e **Impostazioni** (tariffa globale, dati di prova, esportazione del database).

## 5. Regole di dominio

**Slot prenotabili.** Dentro una fascia gli inizi sono ogni 30 minuti dall'inizio della fascia. Uno slot è libero
se finisce entro la fascia, è nel futuro e non si sovrappone a lezioni confermate né del tutor né dello studente.
Due intervalli si sovrappongono se `inizioA < fineB && inizioB < fineA`.

**Prezzo.** `tariffa oraria × durata / 60`, dove la tariffa è quella della materia se impostata, altrimenti quella
globale (default 20 €). Il prezzo resta fissato al momento della prenotazione.

**Saldo a debito.** Prenotare non costa nulla subito. La lezione viene addebitata **12 ore prima dell'inizio**,
oppure subito se mancano meno di 12 ore. Saldo negativo = da pagare, positivo = credito.

**Annullamento.** Conta il momento della **richiesta**:

| Richiesta | Esito | Effetto sul saldo |
|---|---|---|
| ≥ 12 h prima | approvata | non si paga; se l'addebito era già partito viene stornato |
| < 12 h prima | approvata | lezione annullata ma addebitata |
| qualsiasi | rifiutata | la lezione resta confermata, non si può ripresentare |
| non decisa | la lezione finisce | la richiesta diventa "scaduta" |

Si può chiedere fino all'inizio della lezione e c'è una sola richiesta per lezione. Decide il tutor della lezione o
un admin, e vale la prima decisione.

## 6. Modello dati

Gli importi sono sempre in **centesimi** (`Int`) per evitare errori di arrotondamento. Gli id sono numeri
progressivi condivisi fra tutte le tabelle (`AppDatabase.nextId`).

| Entità | Campi principali |
|---|---|
| `User` | email, hash e salt della password, ruolo, nome, cognome, telefoni (anche dei genitori), saldo, attivo, materie (tutor) |
| `Subject` | nome, tariffa oraria facoltativa |
| `Availability` | tutor, inizio, fine |
| `Booking` | studente, tutor, materia, fascia, inizio/fine, durata, anticipo, nota, prezzo, stato, addebitata il, stornata il |
| `CancellationRequest` | lezione, motivo, chiesta il, `isEarly`, stato, deciso da/il |
| `BalanceTransaction` | utente, importo, tipo (addebito, storno, credito, pagamento, correzione), descrizione |
| `AppNotification` | utente, titolo, testo, letta il |
| `Settings` | tariffa oraria globale |

## 7. Test

`Tests/FeniceCoreTests` contiene 45 test che coprono:

- **Auth:** dati iniziali, email senza distinzione di maiuscole, registrazione e validazioni, cambio password,
  stato invariato se un'operazione fallisce;
- **Fasce e slot:** passi da 30 minuti, slot passati nascosti, validazioni delle fasce, sovrapposizioni;
- **Prenotazioni:** prezzo con tariffa globale o specifica, slot occupati, niente doppie prenotazioni dello
  studente con tutor diversi, notifiche;
- **Addebiti:** subito sotto le 12 ore, esattamente a −12 h con la manutenzione, mai due volte, lezioni svolte;
- **Annullamenti:** tutti i casi della tabella del §5, inoltro all'admin, permessi;
- **Admin:** operazioni sul saldo, disattivazione, materie, dati di prova idempotenti, notifiche;
- **Formattazione:** euro in formato italiano, lettura degli importi, durate.

Tutti i test passano (eseguiti in un container `swift:5.10-jammy`).

## 8. Limiti noti e sviluppi futuri

- I dati restano sul singolo dispositivo: per usarla da più iPhone servirebbe un server (si potrebbe riusare
  quello web come API).
- La parte SwiftUI è compilata dalla CI per il simulatore iOS; i test automatici coprono solo il core.
- Prossimi passi naturali: lezioni ricorrenti, colloqui, compensi dei tutor, esportazione CSV, notifiche push
  con `UserNotifications`.
