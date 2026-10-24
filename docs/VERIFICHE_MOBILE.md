# Layout smartphone — 23 ottobre 2026

Consegnata la build **0.4.1.17**, Android code **401017**. Il comando `CREA SETUP E APK.bat` ha prodotto APK firmato e setup Windows nella corrispondente cartella `builds/releases/`.

## Modifiche

- Formato `expand`, senza letterboxing del viewport. Il paesaggio si estende sotto i margini dell'area sicura, con proporzioni degli sprite conservate.
- Schermo intero automatico su Android, anche se nelle preferenze di una versione precedente era disattivato. Il comando per passare in finestra rimane disponibile su computer.
- Interfaccia mobile separata dalla scala del mondo: riferimento di 480 unità in altezza e almeno 820 in larghezza per tablet. Pulsanti di almeno 72 × 72 unità, testi leggibili, slider audio più grandi.
- Header compatto con risorse, giorno, abitanti, diario e pausa; navigazione inferiore grande; comandi zoom ampliati e spostamento tramite trascinamento.
- Menu iniziale, dialoghi e guida adattati all'area disponibile, con scorrimento verticale. L'avviso zombie non si sovrappone al testo dei dialoghi su mobile.
- Area sicura Android convertita da pixel dello schermo a coordinate dell'interfaccia, ricalcolata dopo resize, rotazione o ritorno all'app. Orientamento orizzontale nei due versi.

## Verifiche effettive

`tests/test_mobile_layout.gd` eseguito sia headless durante lo sviluppo sia con il renderer desktop OpenGL Compatibility. Ultima esecuzione renderizzata: **294 controlli, 0 errori**.

Formati verificati: **1920 × 1080**, **2400 × 1080**, **2560 × 1600**, **2048 × 1536**. I test simulano anche un notch laterale e un margine inferiore di sistema. Verificati viewport con lo stesso rapporto dello schermo, HUD contenuto, dimensioni dei pulsanti, menu, armeria, cittadini, costruzioni, impostazioni, pausa, ammissione, edificio e tutte le fasi della guida. Un evento di puntamento emulato attraversa il viewport reale e apre l'armeria dall'HUD ingrandito, verificando anche la trasformazione delle coordinate.

Regressioni desktop: **28 controlli menu**, **61 animazioni dei dialoghi**, **63 interfaccia**, tutti superati. I due test storici che usano percorsi `user://` hanno segnalato scritture dei salvataggi temporanei bloccate nell'ambiente di verifica; le asserzioni di interfaccia sono passate. I nuovi test mobile usano esclusivamente file dedicati in `.runtime/`. Il renderer desktop ha segnalato la cache shader non scrivibile nel profilo di prova: rendering e controlli sono terminati con codice 0.

La procedura di build usa ora un helper SHA-256 basato su .NET per evitare un problema di risoluzione di `Get-FileHash` fra script Windows PowerShell. **53 controlli della toolchain superati**, inclusi i vettori SHA-256 standard per file vuoto e `abc`, limiti delle versioni, aggiornamento configurazioni e lock.

APK finale: firma v2/v3 valida, allineamento verificato, package e versione corretti, nuovo script `device_layout` incluso. La firma è la stessa della 0.4.1.13 e permette l'aggiornamento dell'app esistente. Checksum di APK, setup ed eseguibile ricalcolati e coincidenti con il manifest. Log in `builds/releases/0.4.1.17/logs/`.

Pacchetto incorporato nell'eseguibile Windows 0.4.1.17 verificato da una cartella senza sorgenti: **87 controlli sulle risorse, 0 errori**.

Le immagini `MOBILE-1920x1080-*.png`, `MOBILE-2400x1080-*.png`, `MOBILE-2560x1600-*.png` e `MOBILE-2048x1536-*.png` sono anteprime renderizzate su desktop con il layout mobile, non schermate di un telefono. Non è stato eseguito un test su dispositivo Android reale o emulatore: rimangono da collaudare densità e diagonali reali, notch dei vari produttori, sospensione e ripresa, prestazioni e multitouch prolungato.

Riferimenti: [scalabilità del viewport Godot 4.5](https://docs.godotengine.org/en/4.5/tutorials/rendering/multiple_resolutions.html) e [area sicura del display](https://docs.godotengine.org/en/4.5/classes/class_displayserver.html#class-displayserver-method-get-display-safe-area).

## Pulsanti separati — build 0.4.1.18

Rimosse le superfici comuni dietro l'HUD superiore, la navigazione inferiore e le azioni del menu principale, su mobile e desktop. Ogni pulsante e contatore mantiene il proprio sfondo, bordo e ombra; gli spazi fra gli elementi sono più ampi e trasparenti. I contenitori di layout dell'HUD non intercettano i clic negli spazi vuoti. Il panorama riempie anche le aree prima coperte dalle fasce e l'asfalto continua sotto la navigazione, conservando le dimensioni del marciapiede.

Verifica renderizzata su 16:9, 20:9, 16:10 e 4:3: **294 controlli layout, 0 errori**. Menu desktop: **32 controlli, 0 errori**, comprese le catture. Risorse del pacchetto Windows finale: **87 controlli, 0 errori**. Anteprima desktop in `FLOATING-DESKTOP.png`; anteprime mobile `MOBILE-*-GIOCO.png` e `MOBILE-*-MENU.png` aggiornate.

Il BAT ha completato la **0.4.1.18 / Android 401018** con setup, APK firmato, firma e allineamento verificati. Il normale eseguibile in `builds/`, usato dai collegamenti Windows, è stato aggiornato e verificato contro la copia del rilascio. La versione precedente è conservata in `.runtime/NienteZombie-prima-pulsanti-separati.exe`. Rimane valida la distinzione fra anteprime renderizzate e prove su dispositivo reale descritta sopra.

## Interfaccia Android più compatta

Il feedback sul Pixel segnalava controlli, menu e finestre troppo ingombranti. Il canvas mobile passa da 480 a 640 unità in altezza, con larghezza minima 1024: sui telefoni 16:9 e 20:9 la scala dei controlli diminuisce del **25%**. La soglia minima dei pulsanti resta 72 unità logiche; il corpo del testo passa da un minimo di 16 a 18 per compensare in parte la riduzione e mantenere la lettura. Le dimensioni desktop non cambiano.

I contatori superiori non si espandono più per riempire lo schermo; diario e pausa restano a destra. La navigazione inferiore si raccoglie al centro. I dialoghi hanno larghezza massima 880 e altezza massima 536, entro l'84% dell'altezza sicura, con contenuti scorrevoli e spaziature interne ridotte. Il menu principale si limita a 360 × 432 unità, centrato verticalmente. Compare una sola notifica mobile alla volta. Il contatore del cancello conserva spazio sufficiente per testo e barra.

Verifica con renderer OpenGL Compatibility e layout mobile nei quattro formati sopra: **362 controlli, 0 errori**. Sono controllati anche l'ingombro complessivo di header e footer (al massimo il 30% dell'altezza), i margini del menu e dei dialoghi, la larghezza della navigazione, la presenza di spazio per icone e testi nei pulsanti e l'attivazione dei comandi attraverso il viewport reale. Le catture `MOBILE-*-*.png` includono ora anche pausa, ammissione e scheda edificio.

Regressioni: **28 controlli menu desktop** e **20 controlli caricamento/icona adattiva**, tutti superati. Si tratta di anteprime e test sul computer; la nuova scala va confermata sul telefono.

Rilascio completato: **0.4.1.21 / Android 401021**, con APK firmato e setup Windows in `builds/releases/0.4.1.21/`. Firma v2/v3, allineamento, package e versione verificati dalla procedura. La chiave Android è quella dei rilasci precedenti. Sul pacchetto Windows incorporato, eseguito senza i sorgenti, sono passati **87 controlli**; sull'APK finale **33 controlli** verificano icone e risorse di avvio. Checksum degli artefatti ricalcolati contro il manifest. Il normale eseguibile Windows è aggiornato; la copia precedente è conservata in `.runtime/NienteZombie-prima-ui-compatta.exe`.

## Scorrimento touch dei dialoghi — 24 ottobre 2026

Il test sul dispositivo ha segnalato che armeria, spedizioni e altri dialoghi scorrevano soltanto iniziando il gesto in alcuni punti. Il difetto era riproducibile: le `PanelContainer` delle card e i pulsanti usavano `MOUSE_FILTER_STOP`, interrompendo la propagazione del mouse emulato dal touch prima che raggiungesse lo `ScrollContainer`.

La configurazione mobile comune ora permette ai controlli interni di passare il gesto al contenitore scorrevole. Le aree puramente decorative che ignoravano già l'input restano tali; slider, barre di scorrimento e contenitori scorrevoli annidati conservano la propria gestione. Il contenitore arresta la propagazione verso il mondo e mantiene lo scorrimento nativo, inclusi inerzia e annullamento del clic sui pulsanti quando viene riconosciuto un trascinamento. Non vengono cambiate dimensioni o grafica dell'interfaccia.

Nuovo test `tests/test_touch_scroll.gd`: eventi `InputEventScreenTouch`/`InputEventScreenDrag` accompagnati dal mouse emulato, inviati al viewport effettivo, con il percorso touchscreen del motore abilitato. Verificati armeria, spedizioni, cittadini, costruzioni, impostazioni, diario, ammissione, edificio, crediti e aiuto su **1920 × 1080, 2400 × 1080 e 2048 × 1536**. Prima della correzione: **341 controlli, 60 errori**, tutti relativi al mancato scorrimento. Dopo la correzione: **341 controlli, 0 errori**. Estesa la verifica a inversione del gesto, trascinamento oltre il limite superiore e scorrimento durante l'animazione di ingresso: **351 controlli, 0 errori** con renderer OpenGL Compatibility.

Controllati anche pulsanti attivi e disabilitati, assenza di acquisti o selezioni involontarie durante lo swipe, tap singolo sulla destinazione, cursori audio orizzontali, trascinamenti ripetuti, isolamento della visuale del gioco e rotella desktop. Regressioni: **362 controlli layout mobile** e **28 controlli menu desktop**, tutti superati. Log in `.runtime/touch-scroll-before.log`, `.runtime/touch-scroll-after.log`, `.runtime/touch-scroll-render.log`, `.runtime/scroll-mobile-layout-regression.log` e `.runtime/scroll-menu-regression.log`. Queste verifiche sono eseguite sul computer con input simulato, non su un telefono fisico.

Riferimenti del motore: [ScrollContainer 4.5](https://docs.godotengine.org/en/4.5/classes/class_scrollcontainer.html), [gestione delle card PanelContainer](https://github.com/godotengine/godot/blob/4.5-stable/scene/gui/panel_container.cpp) e [annullamento delle pressioni durante lo scroll](https://github.com/godotengine/godot/blob/4.5-stable/scene/gui/base_button.cpp).

Rilascio **0.4.1.23 / Android 401023** completato: APK firmato, setup Windows e versione autonoma nella relativa cartella `builds/releases/`. Il test touch è stato eseguito anche sul codice incorporato nel pacchetto Windows, da una cartella priva dei sorgenti: **351 controlli, 0 errori**. I file temporanei di quest'ultimo test sono isolati in `.runtime/exported-touch-scroll/`. Superati inoltre **87 controlli sulle risorse del pacchetto** e **33 controlli dell'APK**. Firma Android v2/v3 valida e identica ai rilasci precedenti, allineamento e versione verificati; checksum dei tre artefatti coincidenti con il manifest. Log conservati anche in `builds/releases/0.4.1.23/logs/`. Eseguibile dei collegamenti Windows aggiornato e verificato; copia precedente in `.runtime/NienteZombie-prima-scroll-touch.exe`.

## Nuovi dialoghi e HUD — build 0.4.1.24

Azioni principali fisse, spedizioni in due passaggi, armeria compatta con dettagli, tre dimensioni persistenti dell'interfaccia e informazioni contestuali per cancello/villaggio. Dettagli e risultati in [UX_DIALOGHI_HUD.md](UX_DIALOGHI_HUD.md).

Verifica completa sul codice esportato: **830 controlli, 0 errori**, inclusi quattro formati landscape, tutti e tre i formati dell'interfaccia e layout desktop ricreato. Verifica renderizzata mirata: **148 controlli, 0 errori**. Regressione dello scorrimento touch: **354 controlli, 0 errori**, con entrambe le liste delle spedizioni e controllo dei contenuti che ora entrano senza scorrere. Queste sono prove con input simulato sul computer; la conferma sul dispositivo fisico rimane distinta.

APK **401024**, setup Windows ed eseguibile autonomo in `builds/releases/0.4.1.24/`. Firma e allineamento verificati, stessa chiave Android, checksum coincidenti con il manifest. Superati **35 controlli sulle risorse dell'APK** e **87 sul pacchetto Windows**. Copia Windows dei collegamenti aggiornata e versione precedente conservata. Anteprime `UX-*.png` e log del rilascio disponibili.

## Dialoghi a schermo intero solo sui telefoni Android — 24 ottobre 2026

La classificazione usa il lato corto del display in dp: sotto 600 dp è uno smartphone Android, da 600 dp è un tablet. Non viene dedotta dalla sola risoluzione. Sono verificati anche due dispositivi 2400 × 1080 con densità differenti e la soglia esatta di 600 dp; desktop, altre piattaforme e densità sconosciuta non ricevono il trattamento telefono.

Sugli smartphone tutti i dialoghi occupano l'intera area sicura, conservando scorrimento, chiusura e azioni fisse. L'ingresso usa una dissolvenza senza spostare la finestra oltre i margini sicuri. Le spaziature interne sono più compatte; nella modalità Compatta sono visibili le quattro armi insieme. Audio e Schermo si affiancano quando la larghezza lo consente. Menu iniziale e HUD conservano la propria scala.

La scala del mondo è moltiplicata per 1,20 anche nei preset della telecamera e ai limiti dello zoom: massimo 1,50 sul telefono, 1,25 su PC e tablet. Il confronto misura edifici e altezze effettivamente inviate al disegno di sopravvissuti e zombie, oltre a conversione delle coordinate, selezione e danno dopo un tap nel viewport. Le preferenze dell'interfaccia non cambiano lo zoom della scena.

`tests/test_android_phone.gd`: **1.213 controlli, 0 errori**, con renderer OpenGL Compatibility. Confronta desktop, tablet e telefoni 16:9/20:9, le tre dimensioni dell'interfaccia e 18 tipi di dialogo. Comprende ammissione, armeria, dettagli arma, impostazioni, spedizioni e squadra, cittadini ed equipaggiamento, costruzione, edificio e aiuto, cancello, pausa, diario, guida, crediti, ripartenza e tutorial. Verifica anche le aree sicure durante l'animazione.

`tests/test_touch_scroll.gd` con `--android-phone-preview`: **288 controlli, 0 errori**, sia headless sia con renderer OpenGL. Le liste che entrano interamente nella finestra vengono verificate senza pretendere uno scorrimento inutile; per il gesto durante l'ingresso si usa la lista più lunga delle spedizioni. Restano coperti swipe su card e pulsanti, annullamento dei clic durante il gesto, slider orizzontali, scroll ripetuto e rotella desktop.

Regressione completa dei precedenti flussi PC/tablet: `tests/test_ux_flow.gd`, **830 controlli, 0 errori**. Anteprime `ANDROID-PHONE-*.png` e `ANDROID-PHONE169-*.png`, con riferimenti `ANDROID-TABLET-*.png` e `ANDROID-DESKTOP-*.png`. Le immagini e gli input sono prodotti sul computer: non è stato eseguito un collaudo su telefono fisico.

Rilascio completato: **0.4.1.25 / Android 401025**. APK firmato, setup Windows ed eseguibile autonomo in `builds/releases/0.4.1.25/`. Firma v2/v3 valida e identica ai rilasci precedenti, allineamento e metadati Android verificati. Checksum dei tre artefatti ricalcolati e coincidenti con il manifest.

Dal pacchetto Windows incorporato, eseguito senza sorgenti nella cartella di lavoro, sono passati nuovamente **1.213 controlli smartphone**, **830 controlli UX** e **87 controlli sulle risorse**. Sull'APK finale sono passati **35 controlli delle risorse di avvio**. Log conservati nel rilascio. Eseguibile dei collegamenti Windows aggiornato e verificato; copia precedente in `.runtime/NienteZombie-prima-smartphone.exe`.

## Dimensioni, padding e avvisi all'arrivo — revisione successiva

Il feedback sul dispositivo ha richiesto un aumento più visibile delle dimensioni. La scala del mondo sui telefoni Android passa da **1,20 a 1,80**: edifici, residenti, sopravvissuti e zombie sono quindi il **50% più grandi rispetto alla 0.4.1.25**. Il massimo zoom passa da 1,50 a **2,25**. La strada è collocata più in basso per usare meglio lo spazio verticale, mantenendo visibili i cartelli degli edifici sopra la navigazione. Le dimensioni di HUD, PC e tablet rimangono quelle precedenti.

Lo sfondo dei dialoghi ora copre **l'intero display**, compreso il margine precedentemente lasciato a sinistra per il notch. I contenuti evitano comunque le aree non sicure e aggiungono **24 unità logiche orizzontali e 18 verticali di padding**. La verifica distingue esplicitamente la superficie della finestra dai margini dei comandi. Le azioni fisse, lo scroll e le tre dimensioni dell'interfaccia sono conservati.

Il passo aumenta su tutte le piattaforme: residenti 19 → **30**, arrivi normali 32 → **52**, partenze 38 → **62**, zombie classici 34 → **54**, corridori 65 → **104**, bruti 23 → **37**, infiltrati 29 → **46** unità al secondo. Il tutorial passa da 45 a **72**. Le animazioni continuano a derivare la fase dei piedi dalla distanza realmente percorsa. Il caricamento applica le nuove velocità anche alle partite esistenti senza spostare i personaggi.

L'icona zombie non usa più timer o code di spawn: compare quando il rettangolo disegnato di un nemico entra nel viewport. Una minaccia avvistata resta segnalata se il giocatore torna a esplorare il villaggio; quando non restano nemici avvistati, l'icona scompare. Menu e dialoghi a schermo intero non scoprono zombie coperti. Il tap conserva il trasferimento fluido alla postazione militare.

Il messaggio e il suono del sopravvissuto partono al raggiungimento della posizione assegnata davanti al cancello. La scritta nel mondo, il fumetto e il titolo della guida condividono la stessa condizione. Ogni arrivo viene annunciato una sola volta, anche passando avanti nella fila o salvando e ricaricando. La migrazione distingue persone già in attesa da quelle ancora in cammino.

Verifiche del sorgente:

| Verifica | Controlli | Errori |
| --- | ---: | ---: |
| Layout smartphone, padding e confronto con PC/tablet, renderer OpenGL | 1.429 | 0 |
| Scorrimento touch nei nuovi dialoghi a schermo intero, renderer OpenGL | 288 | 0 |
| Avvisi visibili, arrivi, clic reali e migrazione dei salvataggi | 40 | 0 |
| Fase dei piedi, fermata, pausa e nuova velocità dei cittadini | 52 | 0 |
| Simulazione, migrazioni e sessione prolungata | 751 | 0 |
| Distanze delle armi, varianti, economia e contenuti | 655 | 0 |
| Tutorial completo attraverso i comandi effettivi | 81 | 0 |
| Transizione della visuale e input del mondo | 25 | 0 |

Anteprime `ANDROID-PHONE-VILLAGE.png`, `ANDROID-PHONE-WORLD.png` e `ANDROID-PHONE169-*.png` aggiornate. La fixture della camminata è stata adeguata all'avvio con rifugio vuoto: crea i propri edifici e personaggi. I due test storici del tutorial e dell'input segnalano scritture `user://` bloccate nell'ambiente di prova; le asserzioni sono passate. Le nuove prove usano `.runtime/`. Queste sono verifiche con input simulato sul computer, non prove su Android fisico.

Rilasciata la **0.4.1.26 / Android 401026**, con APK firmato, setup Windows ed eseguibile autonomo in `builds/releases/0.4.1.26/`. Firma v2/v3 valida e invariata rispetto ai precedenti rilasci, allineamento e metadati corretti, checksum dei tre artefatti coincidenti con il manifest. L'app può aggiornare la precedente installazione mantenendo la stessa firma.

Sul codice incorporato nel pacchetto Windows, eseguito senza sorgenti nella cartella di lavoro, sono passati **1.429 controlli smartphone**, **40 controlli su arrivi e notifiche**, **830 controlli UX** e **87 controlli risorse**, tutti senza errori. Gli arrivi sono stati verificati anche con renderer OpenGL e input nel viewport: **40 controlli, 0 errori**. Sull'APK finale sono passati **35 controlli delle risorse di avvio**. Eseguibile dei collegamenti aggiornato; copia della 0.4.1.25 conservata in `.runtime/NienteZombie-prima-visibilita.exe`. I log del rilascio includono sia i test del sorgente sia quelli del pacchetto.

## Mondo doppio e ridisegno delle pagine — build 0.4.1.27

La presentazione dei telefoni Android è ridisegnata: pagine scorrevoli con chiusura laterale, senza app bar e footer fissi, margini espliciti su entrambi i lati. Armeria, destinazioni, negozi, impostazioni e menu principale hanno una composizione dedicata. Personaggi, zombie ed edifici sono il doppio rispetto alla 0.4.1.26; scritte del mondo raddoppiate e visuale trascinabile anche verticalmente. Dimensioni e composizione PC/tablet conservate. Dettagli e anteprime in [SMARTPHONE_UI_0.4.1.27.md](SMARTPHONE_UI_0.4.1.27.md).

Rilascio **0.4.1.27 / Android 401027** completato e verificato. Sul codice esportato: **2.077 controlli layout**, **57 interazioni con renderer e input touch simulato**, **830 controlli UX**, **87 controlli risorse**; tutti senza errori. Sul profilo telefono sono passati anche **264 controlli scroll** e **40 controlli avvisi**. L'APK finale supera **36 controlli**, inclusa la presenza di `phone_pages.gdc`. Firma v2/v3 stabile, allineamento, metadati e checksum verificati. Eseguibile dei collegamenti aggiornato e copia precedente conservata. Le prove sono effettuate sul computer, non su Android fisico.

## Vista esclusivamente orizzontale e nuova pausa — build 0.4.1.28

Il test sul Pixel ha evidenziato che la 0.4.1.27 ingrandiva la telecamera e costringeva a esplorare in verticale. Ora le scale degli sprite sono indipendenti dalla telecamera: l'avvio e il minimo dello zoom mostrano l'intera altezza di edifici, torretta, militare e cartelli. Il mondo scorre esclusivamente in orizzontale; lo zoom ulteriore è volontario. La pausa distingue Riprendi, opzioni, salvataggio e ritorno al menu. Impostazioni e guida tornano alla pausa senza riprendere il gioco per errore. Dettagli e anteprime in [SMARTPHONE_HORIZONTAL_0.4.1.28.md](SMARTPHONE_HORIZONTAL_0.4.1.28.md).

Rilascio **0.4.1.28 / Android 401028** completato. Sul codice esportato sono passati **2.129 controlli layout**, **73 interazioni con renderer e input touch simulato**, **830 controlli UX** e **87 controlli risorse**, tutti senza errori. Sul sorgente anche **264 controlli scroll**, **751 simulazione/salvataggi**, **52 camminata** e **40 avvisi**. L'APK finale supera **36 controlli**. Firma stabile v2/v3, allineamento, metadati e checksum verificati. Copia Windows dei collegamenti aggiornata e versione precedente conservata. Prove eseguite sul computer, non su un nuovo Pixel fisico.

## Costruzioni, spedizioni e pressione della popolazione — build 0.4.1.29

Costruisci usa otto schede uniformi, con pulsanti a tutta larghezza sempre in fondo; il panificio conserva lo stesso allineamento delle altre costruzioni. Spedizioni distingue destinazione, dettagli e squadra: costo effettivo, entrambi i risultati possibili, guadagno netto, assenza dei lavoratori, salute e probabilità calcolata dal modello. La pressione degli zombie cresce gradualmente con le persone effettivamente presenti nel rifugio, escludendo ospiti in attesa e membri in spedizione. La pausa residua si adatta senza azzerarsi e senza applicare due volte la riduzione dopo un caricamento. La vista orizzontale della 0.4.1.28 rimane in uso. Dettagli in [COSTRUZIONI_SPEDIZIONI_0.4.1.29.md](COSTRUZIONI_SPEDIZIONI_0.4.1.29.md).

| Verifica | Controlli | Fallimenti |
| --- | ---: | ---: |
| Layout telefono 16:9/20:9, PC/tablet, tre scale, padding e allineamento di tutti gli edifici — sorgente e pacchetto | 2.621 per esecuzione | 0 |
| Tocchi reali nel viewport: spedizione in tre passaggi, costi e costruzione del panificio — sorgente e pacchetto | 85 per esecuzione | 0 |
| Navigazione, scelte conservate e transazioni UX — sorgente e pacchetto | 880 per esecuzione | 0 |
| Popolazione, frequenza/gruppi, timer, migrazione e risultati delle spedizioni — sorgente e pacchetto | 1.044 per esecuzione | 0 |
| Scroll touch anche attraverso pulsanti abilitati/disabilitati — sorgente | 354 | 0 |
| Simulazione e salvataggi, compresa una sessione di due ore — sorgente | 751 | 0 |
| Distanze delle armi, varianti, economia e contenuti — sorgente | 655 | 0 |
| Risorse effettivamente incorporate nel pacchetto Windows | 87 | 0 |
| Risorse dell'APK, inclusi i quattro controller UI compilati | 37 | 0 |

Rilascio **0.4.1.29 / Android 401029** completato in `builds/releases/0.4.1.29/`, con APK firmato e setup Windows. Firma v2/v3 stabile, allineamento, metadati e checksum dei tre artefatti verificati. Eseguibile dei collegamenti aggiornato, copia precedente conservata in `.runtime/NienteZombie-prima-cataloghi-spedizioni.exe`. I test del pacchetto girano dalla cartella Windows esportata, senza sorgenti di gioco locali; i log sono nel rilascio.

Anteprime dei pacchetti aggiornate, comprese `ANDROID-PHONE-BUILD-BAKERY.png`, `ANDROID-PHONE-EXPEDITION-TRADEOFFS.png` e i corrispondenti formati 16:9. Le prove grafiche usano renderer OpenGL e tocchi simulati sul computer: non costituiscono un collaudo su Pixel fisico. L'ambiente di prova impedisce la cache shader, senza fallimenti delle verifiche funzionali.

## Attività della board Notion — build 0.4.1.30

Implementate le quattro attività in Da fare: arma/colpi/ricarica fissi nella barra superiore, passeggiate casuali con soste e inversioni, contatori delle risorse nei menu di spesa, Chiara e ciliegia dipinta nelle schede dell'infermiera. I salvataggi esistenti sono compatibili; nomi dell'infermiera e alias storici vengono normalizzati conservando i cognomi quando non ci sono collisioni. La vista resta esclusivamente orizzontale. Dettagli e fonti: [BOARD_NOTION_0.4.1.30.md](BOARD_NOTION_0.4.1.30.md).

Sorgente: **789 controlli della board**, **2.621 layout**, **880 UX**, **354 scroll touch**, **85 interazioni smartphone**, **751 simulazione/salvataggi**, **655 combattimento/contenuti**, **54 camminata** e **30 varietà/600 identità**. Tutti passati. Le fixture della camminata usano i nuovi percorsi anziché il vecchio giro ad anello; il test di overscroll parte da un pulsante realmente visibile e copre il nuovo spazio occupato dai contatori.

Rilascio **0.4.1.30 / Android 401030** completato. Sul pacchetto Windows, eseguito dalla propria cartella senza i sorgenti di gioco, sono passati **789 controlli della board con renderer OpenGL**, **2.621 layout**, **85 interazioni**, **880 UX** e **87 risorse**. L'APK finale supera **39 controlli**, compresi il modulo delle passeggiate e la texture importata delle ciliegie. Firma v2/v3 stabile, allineamento, metadati e checksum verificati. Eseguibile dei collegamenti aggiornato con copia della precedente versione. Log nel rilascio.

Le immagini `BOARD-PHONE169-*.png`, `BOARD-PHONE-*.png`, `BOARD-TABLET-*.png` e `BOARD-DESKTOP-*.png` sono prodotte dal codice esportato. I test usano dati isolati e input sul computer; non è stato effettuato un nuovo test su Pixel fisico. La mancata cache shader nell'ambiente di prova non ha causato fallimenti funzionali.

## Cittadini, inversioni e indicatore del cancello — build 0.4.1.31

Corretto il parametro di rendering che faceva usare gli sprite zombie ai cittadini diretti a sinistra, senza specchiarli. Ora l'abitante rimane umano e si gira mantenendo la camminata alternata. Lo stato Ingresso rifugio conserva la posizione sullo schermo mentre cambiano zoom e telecamera ed è disegnato dopo tutta la scena, quindi non può finire dietro torre o militare. Si riadatta solo ai cambi di display, area sicura e scala dell'interfaccia. Nessuna modifica alla logica di sporco o infiltrati, ai salvataggi o allo scorrimento esclusivamente orizzontale. Dettagli in [CORREZIONI_RENDER_0.4.1.31.md](CORREZIONI_RENDER_0.4.1.31.md).

Sorgente: **1.728 controlli di rendering con OpenGL**, **2.621 layout** e **54 camminata**, senza fallimenti. Il nuovo test intercetta le chiamate realmente ricevute dal renderer per tutte le identità, compresi gli alias storici, tre condizioni visive e due direzioni; verifica inoltre l'inversione nel normale aggiornamento della scena, le pose di lavoro e il cancello alle tre scale UI. Questo copre anche la regressione che i precedenti test dei soli percorsi non rilevavano.

Rilascio **0.4.1.31 / Android 401031** completato in `builds/releases/0.4.1.31/`. Sul pacchetto Windows, eseguito dalla sua cartella senza sorgenti locali del gioco, passano **1.732 controlli di rendering**, **85 interazioni** e **87 risorse**; sull'APK **39 controlli**. Nessun fallimento. I quattro controlli aggiuntivi acquisiscono anche le viste del cancello prima dello zoom. Firma v2/v3 stabile, allineamento, metadati e checksum verificati. Copia Windows dei collegamenti aggiornata, precedente versione conservata in `.runtime/NienteZombie-prima-fix-render.exe`. Log nel rilascio.

Le anteprime `FIX-RENDER-*.png` mostrano i due versi e il confronto cancello panoramica/zoom sui quattro profili. Sono prodotte dal renderer OpenGL del computer; non sono un collaudo su Pixel fisico. L'ambiente impedisce la cache shader, senza effetti sulle verifiche funzionali.

## Cantieri animati e costruzione progressiva — build 0.4.1.33

Ogni nuova costruzione mostra ponteggi, attrezzi e polvere animati, edificio in formazione e conto alla rovescia. Il catalogo espone costo e durata prima della spesa. Le attese dipendono dal tipo e crescono con tutti i lotti avviati, compresi quelli ancora in costruzione. Letti, assegnazioni, merci, ricavi e obiettivi si attivano al completamento. Il dialogo del cantiere si trasforma automaticamente nella scheda operativa.

Il tutorial guida le prime attese di 6 e 10 secondi. I vecchi edifici restano pronti. Durata e tempo residuo sono persistenti e recuperano anche chiusure brevi; la ripresa Android riconcilia l'assenza senza contare due volte i frame già simulati in background. Nessun combattimento aggiuntivo viene simulato al rientro. Dettagli: [CANTIERI_0.4.1.33.md](CANTIERI_0.4.1.33.md).

| Verifica | Controlli | Fallimenti |
| --- | ---: | ---: |
| Ciclo, pacing, spese, disponibilità, migrazione, offline, sospensione/ripresa — sorgente e pacchetto | 200 per esecuzione | 0 |
| Avvio con input effettivo, interfaccia alle tre scale, quattro profili e animazioni — sorgente e pacchetto | 124 per esecuzione | 0 |
| Tutorial completo con attese reali accelerate — sorgente e pacchetto | 90 per esecuzione | 0 |
| UX e transazioni — sorgente e pacchetto | 880 per esecuzione | 0 |
| Layout telefono/PC/tablet — sorgente | 2.621 | 0 |
| Simulazione prolungata e salvataggi — sorgente | 751 | 0 |
| Economia e combattimento — sorgente | 655 | 0 |
| Scroll touch — sorgente | 354 | 0 |
| Integrazione camminata — sorgente | 54 | 0 |
| Risorse del pacchetto Windows | 87 | 0 |
| Risorse dell'APK, inclusi i due nuovi moduli | 41 | 0 |

Rilascio **0.4.1.33 / Android 401033** completato con APK firmato e setup Windows in `builds/releases/0.4.1.33/`. Firma v2/v3 stabile, allineamento, metadati e checksum verificati. Eseguibile dei collegamenti aggiornato, precedente conservato in `.runtime/NienteZombie-prima-cantieri.exe`. I test dei pacchetti girano dalla cartella Windows senza sorgenti di gioco locali; log nel rilascio.

Le anteprime `CONSTRUCTION-*.png` mostrano cantiere iniziale, metà lavori, completamento e dialogo. Le prove grafiche e touch usano il computer e le notifiche di sospensione sono simulate; non costituiscono un test su Pixel fisico. Nei test di persistenza sono attesi cinque avvisi per salvataggi deliberatamente invalidi; l'ambiente impedisce inoltre la cache shader. Nessun fallimento funzionale.

## Espansione del rifugio — build 0.4.1.34

Il limite destro riserva un intero lotto libero, comprende l'ingombro delle scritte e conserva un margine rispetto al display e al notch. Cresce di un lotto appena si avvia una costruzione: dopo il terzo edificio e nei rifugi più grandi il comando per costruire resta interamente raggiungibile. Area cliccabile e disegno condividono la geometria; il comando risponde anche sulla didascalia inferiore. La vista resta orizzontale e lo zoom non cambia. Salvataggi compatibili. Dettagli: [ESPANSIONE_RIFUGIO_0.4.1.34.md](ESPANSIONE_RIFUGIO_0.4.1.34.md).

**604 controlli del sorgente e 604 del pacchetto Windows con OpenGL**, senza fallimenti: PC, tablet e due formati smartphone, tre scale UI, tre livelli di zoom, rifugi con 0/3/4/12 lotti, area sicura e clic effettivi. Passano inoltre **390 controlli di layout**, **200 di costruzione**, **87 delle risorse Windows** e **41 dell'APK**. Dati isolati e notifiche del modello simulate sul computer; nessun nuovo collaudo su Pixel fisico.

Rilascio **0.4.1.34 / Android 401034** completato con setup Windows e APK firmato. Firma v2/v3 stabile, allineamento, versione e checksum verificati; eseguibile dei collegamenti aggiornato con copia della precedente versione. Log in `builds/releases/0.4.1.34/logs/`.

## Costi e pulsanti della difesa — build 0.4.1.35

Potenzia è disabilitato quando mancano monete o provviste, compreso il budget protetto del tutorial. Ripara richiede anch'esso entrambe le risorse e un cancello danneggiato. Prezzo e disponibilità si aggiornano a dialogo aperto quando cambiano risorse, danni o livello. Dettagli: [DIFESA_COSTI_0.4.1.35.md](DIFESA_COSTI_0.4.1.35.md).

Passano **192 controlli dedicati del sorgente e 192 del pacchetto Windows con OpenGL**, con input effettivo su quattro profili e tre scale UI. Passano inoltre **880 controlli UX**, **90 del tutorial**, **87 delle risorse Windows** e **41 dell'APK**. Nessun fallimento. Il test del tutorial ora verifica l'intervallo degli arrivi adeguato al primo cittadino presente, invece del precedente limite per rifugio vuoto. Nessun cambiamento alle regole degli arrivi.

Setup Windows e APK **0.4.1.35 / Android 401035** generati e verificati: firma v2/v3 stabile, allineamento, versione e checksum corretti. Eseguibile dei collegamenti aggiornato con backup della versione precedente. Log in `builds/releases/0.4.1.35/logs/`. Dati di prova isolati; layout Android simulati sul computer, senza nuovo collaudo su Pixel fisico.
