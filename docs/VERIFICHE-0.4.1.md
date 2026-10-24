# Verifiche — versione 0.4.1

## Aggiornamento 0.4.1.4 — formattazione dei contatori

Verificata la scheda di ammissione sull'eseguibile esportato usando un cittadino serializzato e riletto con JSON: i talenti sono realmente `float`, ma le tre etichette mostrano `5`, `9` e `6`. Verificati anche `5.0 → 5`, `10000 → 10 k`, `12500 → 12.5 k`, `100000 → 100 k`, `1000000 → 1 M` e `1500000 → 1.5 M`.

La riscossione di una spedizione riletta da JSON mostra `+100 monete, +5 provviste.`. Gli altri contatori erano già formattati come interi; conservati i decimali significativi delle abbreviazioni e dei tempi delle armi. Nessuna modifica ai valori della simulazione o al formato dei salvataggi.

Controllo delle risorse incorporate: `test_revision_package.gd`, 87 controlli, 0 errori. Verifiche dalla cartella `builds`, senza `--path`, con profili APPDATA isolati; log `.runtime/export-0414.log`, `.runtime/packed-0414-counters.log` e `.runtime/packed-0414-package.log`. La 0.4.1.3 rimane in `.runtime/previous-builds`; la 0.4.1.4 verificata sostituisce l'eseguibile abituale.

## Aggiornamento 0.4.1.3 — feedback degli edifici

Rimossa la linea dorata in `_draw_building`. Il nuovo disegno usa una maschera della sagoma con contorno caldo di 1,8 px e un'aura tenue di 3,6 px. L'ingresso dell'hover è smussato, mentre il clic ha un canale indipendente di 0,30 secondi. Maschere preparate una sola volta, massimo 512 px con mipmap; nessun SubViewport aggiuntivo.

| Verifica | Sorgente | Eseguibile Windows 0.4.1.3 |
|---|---|---|
| `test_revision_main.gd` | 25 controlli, 0 errori | — |
| `test_interface_audio.gd`, nativo | 15 controlli, 0 errori | 15 controlli, 0 errori |
| `test_visitor_selection.gd` | 181 controlli, 0 errori | 181 controlli, 0 errori |
| `test_revision_package.gd` | — | 87 controlli, 0 errori |

Anteprime native generate dal sorgente e dall'eseguibile: [hover](EDIFICI-HOVER.png) e [clic](EDIFICI-CLIC.png). La cattura confronta una scena congelata prima e dopo l'hover: nessun pixel cambia nella zona della vecchia barra, l'area cliccabile è identica e i nomi e le targhette restano fermi. Verificati risalto corretto sulla casa, cancellazione passando sull'HUD e durante il trascinamento, cambio di edificio dopo uno spostamento della camera a puntatore fermo e prosecuzione del clic durante il dialogo. Cache di nove sagome, senza contaminazione dagli elementi adiacenti dell'atlante.

La vecchia fixture di selezione dei superstiti è stata adeguata al rifugio inizialmente vuoto: salvataggi temporanei `user://`, tutorial saltato per questa prova, una casa per i letti e un residente valido per l'ammissione finale. Nessuna asserzione cambiata.

Prove sul pacchetto dalla cartella `builds`, senza `--path`, con APPDATA isolato. Log `.runtime/export-0413.log`, `.runtime/packed-0413-{preview,interaction,visitors,package}.log`. Il nuovo modulo `building_feedback.gd` è incluso nel pacchetto. Build verificata nel percorso abituale; versione 0.4.1.2 conservata in `.runtime/previous-builds`.

## Aggiornamento 0.4.1.2 — contenuti centrati

Controllo visivo delle catture native: barra inferiore, pulsante del cancello, contatori HUD, schede dei talenti nell'ammissione e menu principale. Verificate le finestre 1440×900 e 960×600. Icone e testo dei pulsanti rimangono un gruppo compatto centrato con margini simmetrici; titolo e barra del cancello sono centrati insieme. I contenuti decorativi nei pulsanti non intercettano gli eventi del puntatore.

| Verifica | Sorgente nativo | Eseguibile 0.4.1.2 |
|---|---|---|
| `test_v04_ui.gd` | 148 controlli, comprese 7 catture; 0 errori | 141 controlli senza catture; 0 errori |
| `test_menu.gd` | 32 controlli, comprese 4 catture; 0 errori | — |
| `test_interface_audio.gd` | 15 controlli, 0 errori | 15 controlli, 0 errori |
| `test_revision_package.gd` | — | 86 controlli, 0 errori |

Riutilizzate le verifiche esistenti, senza aggiungere nuovi test per le modifiche di allineamento. Le prove native dei clic confermano apertura dai pulsanti HUD, dagli edifici e dai superstiti, chiusura con la X e feedback audio. Le catture aggiornate sono in `docs/V04-HUD.png`, `docs/V04-HUD-960.png`, `docs/V04-AMMISSIONE-DUBBIO.png` e `.runtime/menu-title.png`.

Export e prove sull'eseguibile dalla cartella `builds`, senza `--path`, con profili APPDATA isolati. Log `.runtime/export-0412.log` e `.runtime/packed-0412-{ui,interaction,package}.log`. La versione precedente 0.4.1.1 è conservata in `.runtime/previous-builds`; la build verificata usa il percorso abituale dell'eseguibile.

## Aggiornamento 0.4.1.1 — clic dell'interfaccia

Nuovo `ui_click.wav` di 110 ms da sorgenti Kenney CC0 locali, con picco −12 dBFS e RMS −23,73 dBFS. Import PCM senza compressione; manifest, licenza originale e preparatore riproducibile inclusi nel progetto.

| Verifica | Sorgente | Eseguibile Windows 0.4.1.1 |
|---|---|---|
| Integrità e livelli di tutti gli asset, `test_audio_assets.py` | 131 controlli superati | — |
| Banco suoni, `test_sound_bank.gd` | 56 controlli, 0 errori | 56 controlli, 0 errori |
| Input e playback nativi, `test_interface_audio.gd` | 15 controlli, 0 errori | 15 controlli, 0 errori |
| Risorse incorporate, `test_revision_package.gd` | — | 86 controlli, 0 errori |

La prova interattiva usa il vero input del viewport: edifici, sopravvissuti, cancello e lotto aprono il dialogo con un solo clic udibile; la X e la navigazione HUD producono un solo feedback. Refresh e chiusure programmatiche rimangono silenziosi, gli spari mantengono il proprio suono e il mute e lo slider effetti vengono rispettati. L'avvio del playback è rilevato quando viene emesso l'evento, così il caricamento iniziale del catalogo costruzioni non può mascherare un breve campione già terminato.

Le prove sull'eseguibile sono state eseguite dalla cartella `builds`, senza `--path`, su profili APPDATA isolati. Il pacchetto conferma il nuovo clic attivo e la licenza Kenney UI incorporata. Log in `.runtime/export-0411.log` e `.runtime/packed-0411-{interface-final,bank,package}.log`. La build verificata sostituisce l'eseguibile abituale; la 0.4.1.0 è conservata in `.runtime/previous-builds`.

## Verifiche della versione 0.4.1.0

Verifiche del 23 ottobre 2026, Godot 4.5.1 su Windows. Ogni esecuzione usa un profilo APPDATA isolato dai salvataggi del giocatore.

## Sorgenti e asset

| Verifica | Esito |
|---|---|
| `test_user_audio_assets.py` | 10 test superati |
| `test_sound_bank.gd` | 54 controlli, 0 errori |
| `test_zombie_soundscape.gd`, headless | 67 controlli, 0 errori |
| `test_zombie_soundscape.gd`, renderer e audio nativi | 76 controlli, 0 errori |
| `test_polish_integration.gd`, scena completa e audio nativo | 33 controlli, 0 errori |
| `test_menu.gd` | 28 controlli, 0 errori |
| `test_main_flow.gd` | 11 controlli, 0 errori |
| `test_revision_main.gd` | 25 controlli, 0 errori |

I test Python confrontano gli SHA-256 di tutti i sei MP3 originali e dei nove asset derivati con il manifest, verificano assenza di clipping e di campioni vuoti, attacchi e bordi dei colpi, singolo ciclo del mitragliatore, durate delle ricariche e conservazione di tutta la performance zombie. La conversione è deterministica.

La suite del sottofondo verifica due lettori con loop interno disattivato, sovrapposizioni ripetute a potenza costante, volume effetti applicato una sola volta, priorità agli spari, pausa di entrambi i cursori e ripresa dopo menu, mute e spostamento in città. La prova nativa usa anche il vero Ogg di 92,725 secondi, portandolo vicino alla fine: i due lettori si sovrappongono prima dell'EOF e la lettura entrante continua dopo il passaggio senza ripetere i primi secondi.

L'integrazione della scena principale controlla il menu iniziale silenzioso, la sola installazione di ZombieSoundscape, i quattro spari reali, le tre ricariche ritardate senza duplicazioni nel cooldown, l'assenza di voci dei superstiti, pausa nelle schede, prosecuzione tramite Continua e feedback dei clic.

È stata aggiornata la vecchia fixture di `test_main_flow.gd`, che presumeva uno zombie già presente all'avvio. Il nuovo rifugio parte correttamente vuoto; la prova aggiunge ora il proprio bersaglio dopo l'avvio e usa file temporanei nel profilo isolato.

## Eseguibile Windows autonomo

Export release **0.4.1.0**, risorse incorporate. Le verifiche seguenti sono state eseguite sull'eseguibile esportato, con directory di lavoro `builds`, senza `--path` e senza usare le risorse sciolte del progetto.

| Verifica sul pacchetto | Esito |
|---|---|
| `test_revision_package.gd` | 84 controlli, 0 errori |
| `test_sound_bank.gd` | 54 controlli, 0 errori |
| `test_polish_integration.gd`, nativo | 33 controlli, 0 errori |
| `test_zombie_soundscape.gd`, nativo | 76 controlli, 0 errori |

Il controllo del pacchetto conferma `project.binary`, l'assenza del motore di sviluppo nel PCK, l'origine effettiva degli spari e delle ricariche in `assets/audio/user/`, lo stream zombie completo, il manifest incorporato, le risorse grafiche e il catalogo di gioco. Gli originali `suoni/*.mp3` non sono duplicati nel pacchetto. I precedenti campioni CC0 restano come archivio, senza un secondo gestore attivo nella scena.

Log dell'export in `.runtime/export-0410.log`; log delle prove sul pacchetto in `.runtime/packed-0410-{package,bank,integration,bed}.log`. La build verificata è stata rinominata nel percorso abituale `builds/Niente Zombie Per Favore.exe`; il launcher esistente la avvia senza modifiche. La precedente 0.4.0.2 è conservata in `.runtime/previous-builds`.

Le verifiche precedenti di economia, tutorial, animazioni e contenuti sono documentate in [VERIFICHE-0.4.0.md](VERIFICHE-0.4.0.md).
