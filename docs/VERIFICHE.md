# Verifiche della revisione 0.3.0

Verifiche aggiornate al 23 ottobre 2026. Le suite usano salvataggi e preferenze
temporanei, separati dalla partita del giocatore. I risultati seguenti si
riferiscono al progetto sorgente eseguito con Godot 4.5.1; i risultati sulle
risorse impacchettate nell'eseguibile Windows sono riportati anche in fondo.

| Suite | Controlli superati | Copertura |
| --- | ---: | --- |
| `tests/test_revision_main.gd` | 21 headless / 24 nativi con catture | Rifugio inizialmente vuoto, militare permanente, navigazione fluida verso la difesa, nessuno sparo causato dall'icona, pistola potenziata, mitragliatore premuto/rilasciato con consumo reale di munizioni e danni, spawn oltre il bordo visibile e superstiti ignorati dagli zombie |
| `tests/test_tutorial_walkthrough.gd` | 81 headless / 82 nativi con cattura | Percorso completo nella scena reale tramite pulsanti e clic: introduzione, zombie, casa, accoglienza, caffè, lavoratore, rifornimento, scaffali e vendite. Verifica della guida a ogni passaggio e del timer con dialogo aperto |
| `tests/test_revision_simulation.gd` | 750 | Nuova partita senza edifici né residenti, tutorial e ripresa dal salvataggio, arrivi e partenze a piedi, infiltrato rivelato nella sua posizione senza teletrasporto, nomi associati al genere dell'aspetto, migrazione dei salvataggi, acquisto/equipaggiamento delle quattro armi, ricariche solo dopo colpi riusciti, ondate casuali e intervalli più lunghi, economia e simulazione prolungata |
| `tests/test_revision_ui.gd` | 54 headless / 61 nativi con catture | Ripartenza completa, tutorial iniziale, pausa a 1440×900 e 960×600, equipaggiamento senza incarico di guardia, icone di armi e munizioni, aiuto specifico degli edifici, conservazione dello scroll dopo azioni, crediti aggiornati e pulizia dei vecchi messaggi |
| `tests/test_menu.gd` | 28 | Avvio nel menu, Gioca/Continua, conferma e annullamento della nuova partita, impostazioni separate dal salvataggio, crediti e apertura corretta del tutorial |
| `tests/test_sound_bank.gd` | 47 | Spari e ricariche distinti dai click UI, alias di tutte le armi, cache, eventi sconosciuti silenziosi, durata del ciclo SMG e ambiente continuo |
| `tests/test_character_ambience.gd` | 44 headless e nativi | Soltanto zombie vivi visibili, nessun player umano e nessun saluto nei dialoghi, mute e volumi, pausa/menu, cambio camera, cadenza di 6–11 secondi, varianti non ripetute e precedenza degli spari |
| `tests/test_audio_assets.py` | 125 | Hash, PCM, attacchi immediati, picchi senza clipping, meccanismi udibili a volume inferiore agli spari e raccordo del loop stereo |
| `tests/test_character_voice_assets.py` | 2 test sui 9 file attivi | Banco esclusivamente zombie, registrazioni CC0 con pagina dell'autore e hash dei download, formati, durate, livelli e bordi sfumati |
| `tests/test_polish_integration.gd` | 28 nativi | Riproduzione reale dei versi zombie nella scena principale, dialoghi silenziosi, priorità degli spari, ricariche differite per pompa/precisione/SMG senza duplicati sui click bloccati, menu/pausa e un solo ripple per clic |
| `tests/test_actor_visuals.gd` | 158 | Dodici identità coerenti fra mondo e ritratto, alias dei vecchi look, pose di lavoro, sorgenti distinte delle due gambe e scarpe |
| `tests/test_gait_motion.gd` | 510 | Dodici civili e tre tipi zombie: sorpasso reale dei piedi sinistro/destro, passaggio oltre il bacino, simmetria, appoggi, raggiungibilità delle articolazioni, continuità e arresto |
| `tests/test_survivor_variety.gd` | 30 | Seicento nomi simultanei unici fra residenti, coda e partenze, dodici aspetti, pool di nomi distinti per genere e conservazione delle identità esistenti |

Tutte le suite elencate hanno completato l'esecuzione senza fallimenti.
La simulazione prolungata ha raggiunto il giorno 41, con 35 ondate,
153 zombie eliminati e 120 spedizioni completate.

I log correnti sono `tests/final-revision_main.log`,
`tests/revision-main-native.log`, `tests/revision-simulation-final.log`,
`tests/ui-revision-checks-final.log`, `tests/ui-revision-native.log`,
`tests/menu-revision-checks.log`, `tests/audio-revision-bank.log`,
`tests/audio-revision-ambience.log`, `tests/audio-revision-ambience-native.log`,
`tests/ui-revision-polish-native.log`, `tests/final-actor_visuals.log`,
`tests/final-gait_motion.log` e `tests/revision-survivor-variety.log`.
Gli eventuali log più vecchi con lo stesso argomento documentano passaggi di
sviluppo precedenti e non sostituiscono questi risultati.

## Comportamenti verificati nella 0.3.0

La nuova partita azzera la colonia, gli edifici, la coda, le partenze, le minacce
e i progressi precedenti, mantenendo le preferenze del dispositivo. Il militare
sulla torre è un elemento permanente della difesa e spara soltanto su comando
del giocatore. Il tutorial introduce progressivamente difesa, accoglienza,
alloggi, assegnazione al lavoro e produzione; il suo avanzamento viene salvato.

Le nuove persone e gli zombie iniziano oltre il margine sinistro del mondo
visibile alla camera corrente, quindi entrano camminando. Cambiare camera non
teletrasporta chi è già presente. Gli zombie ignorano i superstiti, anche quando
si trovano nella stessa posizione sulla strada. Un rifiuto sposta la persona
nella lista delle partenze e la lascia uscire camminando.

L'icona zombie imposta una destinazione della camera: lo spostamento raggiunge
la torre con un'interpolazione fluida e non genera spari accidentali.
Il mitragliatore ripete colpi reali mentre il puntatore è premuto e interrompe
la raffica al rilascio. Le ricariche seguono il transiente dello sparo; premere
durante il cooldown non avvia un secondo ciclo sonoro.

I sopravvissuti non parlano né durante l'esplorazione né nelle schede di
ammissione. Gli unici vocalizzi attivi sono i nove versi zombie CC0 documentati
in [CHARACTER_VOICES.md](CHARACTER_VOICES.md). Provenienza e licenze di spari,
ricariche e versi sono raccolte in [AUDIO_LICENSES.md](AUDIO_LICENSES.md).
La vecchia anteprima con voci umane non rappresenta più l'audio della partita.

Le catture della revisione includono `docs/DIFESA-FLUIDA.png`,
`docs/REVISIONE-TUTORIAL.png`, `docs/REVISIONE-TUTORIAL-960.png`,
`docs/REVISIONE-PAUSA.png`, `docs/REVISIONE-PAUSA-960.png`,
`docs/REVISIONE-EQUIPAGGIAMENTO.png`, `docs/REVISIONE-ARMERIA.png`
e `docs/REVISIONE-AIUTO-EDIFICI.png`.

## Suite storiche da riallineare

Alcuni test precedenti conservano le regole e i dati iniziali delle revisioni
0.2.x. Non sono inclusi nella tabella delle verifiche correnti:

- `test_simulation.gd`, `test_interaction.gd`, `test_main_flow.gd` e
  `test_gait_integration.gd` assumevano residenti, visitatori o zombie già
  presenti subito dopo `_new_game()`; alcuni controlli assegnavano cittadini
  come guardie. La 0.3.0 parte vuota e usa un militare indipendente dai residenti.
- `test_survivor_lifecycle.gd` e `test_survivor_scene.gd` verificavano attacchi,
  ferite e morte dei superstiti per mano degli zombie. Questa meccanica è stata
  rimossa su richiesta ed è sostituita dai controlli di sicurezza nelle nuove suite.
- `test_zombie_alert.gd` richiedeva che il click impostasse immediatamente la
  posizione della camera sulla torre. La nuova suite principale verifica invece
  la transizione fluida e il suo completamento.
- I risultati audio 0.2.x relativi a saluti e due timbri umani sono storici.
  Le suite audio attuali verificano espressamente la loro assenza.

## Riscontri visivi storici ancora utili

Le camminate usano due piedi indipendenti che si alternano sulla stessa
traiettoria longitudinale. Il corpo non saltella; i raccordi del bacino e delle
caviglie sono continui. Le gallerie `docs/SOPRAVVISSUTI-VARIANTI-00.png`,
`-25.png`, `-50.png` e `-75.png` confrontano ritratto, scala di gioco e
camminata delle dodici identità. Gli otto aspetti aggiuntivi hanno un atlante
dipinto e proporzioni delle gambe dedicate; i vecchi look 4–7 conservano gli
alias delle quattro identità originali.

`docs/CAMMINATA.mp4` e `docs/CAMMINATA-CONTROLLO.mp4` documentano la revisione
dell'animazione, con le scarpe S/D identificate. Il vecchio controllo che
sottraeva la media dei piedi non provava il sorpasso reale: la suite corrente
controlla direttamente l'ordine delle suole davanti e dietro il bacino.
Gli atlanti sperimentali a sei pose non sono usati nell'animazione runtime.
Le vecchie immagini di superstiti sotto attacco mostrano una regola rimossa.

Il filtro delle icone introdotto nella 0.2.5.4 conserva mipmap separate per
ciascun simbolo e una cache delle texture, evitando contaminazioni fra icone
dell'atlante. La verifica storica GPU comprendeva 77 controlli e 36 casi subpixel
di monete/provviste contro un riferimento integrato 8×, con una riduzione del
34,74% dell'errore medio di ricampionamento. Confronti in
`docs/ICONE-HUD-CONFRONTO.png` e `docs/ICONE-HUD-PIXEL.png`; procedimento in
[ICONS-SCALING.md](ICONS-SCALING.md). Quei risultati sulle risorse impacchettate
riguardano la build 0.2.5.4, non costituiscono una verifica dell'export 0.3.0.

## Verifica della build Windows 0.3.0

Esportato `builds/Niente Zombie Per Favore.exe`, con versione file e prodotto
**0.3.0.0** e risorse incorporate. L'export è terminato senza errori o warning.
Le seguenti suite sono state avviate direttamente su questo eseguibile, senza
usare il progetto sorgente come percorso delle risorse:

| Suite sull'eseguibile | Controlli superati | Log |
| --- | ---: | --- |
| Integrità pacchetto | 24 | `tests/packed-030-package.log` |
| Scena principale e interazioni, renderer nativo | 24 | `tests/packed-030-main.log` |
| Dialoghi e menu, renderer nativo | 54 | `tests/packed-030-ui.log` |
| Audio e ripple, renderer nativo | 28 | `tests/packed-030-audio.log` |
| Tutorial completo, renderer nativo | 82 | `tests/packed-030-tutorial.log` |

**212 controlli superati, zero fallimenti e nessun errore nei log.** La verifica
del pacchetto carica i nove versi zombie e i sette suoni delle armi, controlla
la presenza di sorgenti e licenze e l'assenza dei vecchi file `civilian_*`.
Le immagini `NUOVA-PARTITA-TUTORIAL.png`, `RIFUGIO-VUOTO.png`,
`DIFESA-FLUIDA.png` e `TUTORIAL-COMPLETATO.png` sono state rigenerate da questa
esecuzione dell'eseguibile Windows. I profili di prova sono separati dai dati
del giocatore.

## Icone dipinte: build Windows 0.3.0.1

Cinque PNG originali generati con imagegen integrato sostituiscono le sagome
procedurali. Verificata la resa nativa in armeria ed equipaggiamento, compresa
la cassetta delle munizioni: trasparenza, proporzioni e ridimensionamento
restano corretti. Le immagini originali non sono state elaborate su disco.
Anteprime aggiornate in `docs/REVISIONE-ARMERIA.png`,
`docs/REVISIONE-EQUIPAGGIAMENTO.png` e
`docs/ARMERIA-MUNIZIONI-DIPINTE.png`.

- Suite UI nativa con catture: **62 controlli superati**, log
  `tests/weapon-art-ui-native.log`.
- Esportazione completata: versione file/prodotto **0.3.0.1**, log
  `tests/export-0301-final.log`.
- Eseguibile finale avviato dalla cartella `builds`, senza progetto sorgente
  come directory di lavoro: **30 controlli pacchetto** e **54 controlli UI**,
  tutti superati. Il controllo conferma `project.binary` e i cinque PNG
  incorporati. Log `tests/packed-0301-package.log` e
  `tests/packed-0301-ui.log`.

Asset e prompt finali in [WEAPON_ICON_PROMPTS.md](WEAPON_ICON_PROMPTS.md).
