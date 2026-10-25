# Niente Zombie Per Favore!

Un piccolo rifugio. Una grande voglia di ricominciare.

Gestionale e difesa in una città a spaccato laterale, realizzato in **Godot 4.5.1** dal documento di progetto, con grafica cartoon dipinta, animazioni, audio, economia e salvataggio. Revisione **0.4.1.39**: [demolizione con pressione prolungata](docs/DEMOLIZIONE_0.4.1.39.md); [conteggi e insegne illustrate degli edifici](docs/INSEGNE_EDIFICI_0.4.1.38.md); indicatore del cancello solo nella barra inferiore; [armi e munizioni personali per le spedizioni](docs/EQUIPAGGIAMENTO_PERSONALE_0.4.1.36.md), [pulsanti della difesa e risorse disponibili](docs/DIFESA_COSTI_0.4.1.35.md), [espansione del rifugio e lotto libero sempre raggiungibile](docs/ESPANSIONE_RIFUGIO_0.4.1.34.md), [cantieri animati e attese progressive](docs/CANTIERI_0.4.1.33.md) e [verifiche correnti](docs/VERIFICHE_MOBILE.md). Arma, colpi e recupero restano nella barra superiore, fra i contatori e i pulsanti del diario/pausa. Nei menu che prevedono spese, monete, provviste e banconote rimangono visibili anche scorrendo, con importi interi esatti. I cittadini liberi passeggiano verso mete casuali, si fermano e cambiano direzione senza attraversare i confini del villaggio. L'infermiera si chiama Chiara e ha una ciliegia dipinta accanto al nome, anche nei salvataggi precedenti. Gli edifici rispondono al puntatore con un contorno caldo e un breve rimbalzo al clic. Audio, dialoghi animati e contorno dei bersagli a portata restano in uso.

## Gioca subito su Windows

Doppio clic su **AVVIA GIOCO.cmd**, sul collegamento **Niente Zombie Per Favore.lnk** oppure su **builds/Niente Zombie Per Favore.exe**. Il gioco è autonomo e funziona senza installazione o connessione. L'eseguibile contiene tutte le risorse; nella cartella `builds` sono disponibili anche crediti e licenze.

All'avvio trovi **Gioca / Continua**, **Nuova partita**, **Impostazioni**, **Crediti** ed **Esci**. La partita resta ferma nel menu. **Nuova partita** richiede conferma e mantiene le preferenze audio e video. Dal menu pausa puoi salvare e tornare al titolo.

Prima del menu compare il caricamento con logo e colori del gioco, al posto della schermata Godot. Su Android l'icona adattiva ha margini più ampi per mantenere intera la cornice nei launcher circolari, come quello del Pixel. Asset, prompt e verifiche in [AVVIO_ICONA_ANDROID.md](docs/AVVIO_ICONA_ANDROID.md).

Per vedere il nuovo inizio guidato scegli **Nuova partita**: il rifugio parte senza edifici e senza residenti, con il solo militare permanente sulla torre. Il tutorial accompagna il primo zombie, la costruzione di una casa, l'accoglienza del primo superstite, il caffè, l'assegnazione del lavoro e il primo rifornimento. Puoi ridurre la scheda della guida o saltarla. I salvataggi precedenti conservano il loro rifugio.

## Genera setup Windows e APK Android

Doppio clic su **CREA SETUP E APK.bat**: incrementa automaticamente la versione comune e crea il setup Windows installabile e l'APK Android firmato in **builds/releases/<versione>/**. Ogni rilascio conserva i propri file e log; **builds/releases/latest.json** indica l'ultimo completato. La versione è gestita da **VERSION.json**.

Gli strumenti mancanti vengono preparati al primo avvio. Conserva un backup privato di **.release-private/**: contiene la firma da riutilizzare per aggiornare l'app Android. Istruzioni, requisiti e diagnostica in [BUILD_WINDOWS_ANDROID.md](docs/BUILD_WINDOWS_ANDROID.md); risultati effettivi in [VERIFICHE_BUILD.md](docs/VERIFICHE_BUILD.md).

## Come giocare

1. Aspetta che gli zombie entrino nella portata dell'arma e cliccali per sparare. Il militare spara soltanto al tuo comando. La pistola ha munizioni infinite ed elimina uno zombie classico con un colpo, ma non raggiunge i bersagli più lontani. Quando arriva una minaccia compare un'icona in alto a sinistra: premila per raggiungere la torre con un movimento fluido della visuale. **Al cancello** resta sempre disponibile.
2. I superstiti e gli zombie arrivano camminando da fuori schermo. Clicca un superstite per vedere il suo ritratto, i talenti e i possibili segni di contagio. Polvere, graffi e macchie possono esserci anche su persone sane: osserva l'aspetto e leggi gli indizi prima di decidere. Ogni casa offre cinque letti. Gli zombie lasciano in pace le persone all'esterno; chi viene rifiutato si gira e se ne va camminando. Nome, aspetto e scheda appartengono sempre alla stessa persona.
3. Usa **Costruisci** per aggiungere case, caffè, orti, officine, cliniche, **panificio, depuratore e sartoria**. Ogni scheda mostra quanti edifici di quel tipo sono già pronti e quanti sono ancora in costruzione. Nella città le insegne illustrate sopra i tetti sostituiscono i nomi sotto gli edifici: puoi toccarle per aprire le rispettive schede. Tieni premuto su un edificio o sulla sua insegna per circa 0,65 secondi per aprire la conferma di demolizione: è gratuita ma non rimborsa il costo, libera i lavoratori e richiede alloggi sufficienti per gli abitanti. Prima di pagare vedi costo e durata: il cantiere mostra ponteggi animati e un conto alla rovescia, poi diventa operativo automaticamente. Le attese crescono con i lotti già avviati e proseguono anche a gioco chiuso; il tutorial mantiene brevi le prime due costruzioni. Ogni edificio ha un **?** nella scheda con la spiegazione delle sue funzioni. Trascina il paesaggio per vedere i lotti.
4. Da **Cittadini**, assegna i residenti alle attività. Il lavoro ideale aumenta la capacità produttiva; due e tre lavoratori sbloccano i prodotti successivi. Ogni cittadino compra la propria copia di un'arma e le relative scorte. La pistola è gratuita e ha colpi infiniti; pompa, precisione e mitragliatore offrono vantaggi diversi secondo l'ambiente della spedizione. Dalla squadra puoi aprire Arma e munizioni e tornare senza perdere la selezione. Il militare sulla torre non occupa un posto fra i cittadini.
5. Apri un'attività, scegli uno dei suoi tre prodotti, paga il rifornimento e, al termine dell'attesa, premi **Metti sugli scaffali**. Le icone e le descrizioni spiegano la merce; caffè, pane, acqua e gli altri prodotti vengono venduti per generare monete nel tempo. Le sette attività offrono **21 prodotti** complessivi. I pulsanti mostrano la valuta dei costi; le schede mantengono lo scorrimento dopo le azioni.
6. In **Armeria** trovi pistola, fucile a pompa, fucile di precisione e **mitragliatore**, con icone dipinte, danno, gittata e intervallo fra i colpi. Il pompa serve da vicino; la pistola a media distanza; il mitragliatore copre un'area più ampia; la precisione raggiunge gli zombie più lontani. Le tre armi avanzate consumano munizioni. Con il mitragliatore tieni premuto su uno zombie per continuare a sparare; rilascia per fermarti. Puoi comprare munizioni, riparare e potenziare il cancello.
7. In **Spedizioni**, scegli fra **nove destinazioni**, esamina costi e risultati possibili, poi prepara da uno a tre residenti. La probabilità di bottino completo tiene conto della salute e dell'arma adatta all'ambiente: pompa negli spazi stretti, precisione all'aperto e mitragliatore nelle zone affollate. Alla partenza paghi provviste e consumi i colpi personali mostrati nella preparazione; le scorte della torretta restano separate. Chi parte sospende il lavoro. Tutti rientrano, ma un esito difficile riduce il bottino al 40%, senza banconote, e comporta una maggiore perdita di salute. Puoi leggere il guadagno netto prima di decidere e ritirare le risorse al ritorno. Nel **Diario** trovi **32 obiettivi** su costruzioni, lavoro, produzioni, esplorazione, equipaggiamento, cure e difesa.

Gli zombie arrivano in gruppi casuali, senza numerazione mostrata al giocatore. Più cittadini sono presenti nel rifugio, più numerosi e frequenti diventano i gruppi, con una curva graduale e un limite fisso alla difficoltà. Con rifugio vuoto i gruppi hanno 2–8 zombie e pause di 55–95 secondi; con 20 persone presenti hanno 5–16 zombie e pause di circa 39–67 secondi. I superstiti fuori dalle mura e i membri in spedizione non contano. I classici restano la maggioranza, accompagnati da corridori e colossi; salute e forza dei singoli tipi restano fisse. Quando hai eliminato tutte le minacce compare **Zombie respinti!**, poi comincia la pausa prima del prossimo gruppo.

Tutte le azioni essenziali sono disponibili con pulsanti e puntatore. Scorciatoie facoltative: **A/D o frecce** per scorrere, **G** per il cancello, **C** per il rifugio, rotella per lo zoom, **1/2/3/4** per le armi, **Esc** per pausa o chiusura, **F1** per l'aiuto e **F11** per lo schermo intero.

## Grafica e audio

- Dodici identità civili con nomi distinti per genere, cognomi e particolarità; ritratto e personaggio condividono l'illustrazione. Varianti dipinte aggiungono sporco e possibili primi segni di contagio, senza il precedente puntino verde sul viso. I nomi incoerenti dei vecchi salvataggi vengono corretti mantenendo aspetto e cognome.
- Due gambe articolate per civili e zombie: i piedi si alternano davanti e dietro il bacino, il passo segue la distanza percorsa e il tessuto raccorda continuamente busto e gambe. Le camminate già migliorate restano in uso.
- Panorama, edifici, strada e personaggi dipinti; font arrotondati **Fredoka Bold** e **Nunito Sans Bold**; HUD con carta crema, legno, salvia e pulsanti ampi. Giorno e abitanti hanno schede separate, con sole e nuova icona della popolazione; il giorno non usa zeri iniziali. Rimossi logo e nome del rifugio dalla barra superiore. Le piccole icone usano mipmap isolate e un filtro dedicato al ridimensionamento. Le etichette dei lavoratori hanno uno sfondo leggibile.
- Armi, munizioni, popolazione, prodotti, nuove facciate e varianti dei personaggi usano illustrazioni create con imagegen, coerenti con la grafica del rifugio. I prodotti sono accompagnati da spiegazioni della loro funzione economica.
- Ripple crema e oro sui clic, anche nei menu e nei dialoghi. Nessun cerchio di mira sugli zombie. Icona del gioco con zombie e simbolo di stop.
- Le registrazioni della cartella `suoni` sostituiscono spari, ricariche e versi zombie. Ogni colpo riproduce il proprio sparo; tenendo premuto il mitragliatore la raffica segue i proiettili effettivi. La traccia zombie conserva tutti i versi in ordine, con 2,5 secondi di sovrapposizione fra fine e inizio per attenuare la ripartenza. Si sente quando sono presenti zombie visibili, si sospende in pausa e si abbassa durante gli spari. **Le voci dei sopravvissuti restano rimosse.**
- Le sei registrazioni sono state fornite dal proprietario del progetto e dichiarate di libera distribuzione; provenienza e preparazione sono documentate in [USER_AUDIO_SOURCES.md](docs/USER_AUDIO_SOURCES.md). Effetti d'interfaccia e altre fonti rimangono documentati in [AUDIO_LICENSES.md](docs/AUDIO_LICENSES.md); il funzionamento dei versi è in [CHARACTER_VOICES.md](docs/CHARACTER_VOICES.md). Tutti i suoni necessari sono inclusi e il gioco funziona senza servizi online.

## Salvataggi

Su Windows la partita si trova in **%APPDATA%/Godot/app_userdata/Niente Zombie Per Favore!/rifugio_save.json**; le preferenze sono separate in **preferences.cfg**. Il formato dei salvataggi resta compatibile con la versione 2. **Continua** mantiene residenti, edifici, prodotti e risorse esistenti e aggiunge i nuovi contenuti. L'aggiornamento del diario conserva i progressi e i premi già riscossi; non eroga nuovamente le ricompense. Il tutorial salva i progressi; una partita precedente non viene azzerata automaticamente.

Salvataggio automatico e alla chiusura, caricamento validato e produzione offline fino a otto ore. Gli zombie non avanzano mentre il gioco è chiuso. Dopo una breccia puoi ripartire senza perdere definitivamente il rifugio. I test usano profili o file temporanei separati dalla partita del giocatore.

## Base per smartphone

La simulazione in **game_state.gd** è separata da visualizzazione e puntamento in **main.gd** e dall'interfaccia in **game_ui.gd**. Il viewport orizzontale scala con la finestra; i pannelli scorrono, i bersagli hanno aree di selezione generose e il gioco non richiede hover o tastiera. L'interfaccia conserva lo stile giocattoloso con elementi grandi e arrotondati.

Su Android lo schermo intero è automatico e il paesaggio si espande al formato del dispositivo. Solo sugli smartphone Android lo sfondo dei dialoghi occupa l'intero display, con contenuti distanziati dai bordi e dal notch, e gli sprite sono ingranditi indipendentemente dalla telecamera: la vista iniziale mostra edifici e torretta per intero in altezza, con scorrimento esclusivamente orizzontale e zoom aggiuntivo volontario; PC e tablet conservano le dimensioni precedenti. L'interfaccia dedicata usa una scala compatta: contatori della larghezza necessaria, navigazione centrata in basso, pulsanti separati e margini per notch e barre di sistema. Il BAT produce un APK firmato con puntamento touch emulato. Prima della pubblicazione sugli store serviranno prove su dispositivi reali, sospensione e ripresa, prestazioni e accessibilità; iOS richiede una pipeline dedicata. Non sono inclusi acquisti reali, pubblicità o servizi online. La valuta rara si guadagna giocando. Note in [MOBILE.md](docs/MOBILE.md) e [verifiche del layout](docs/VERIFICHE_MOBILE.md).

Su PC e tablet le azioni principali dei dialoghi restano fisse mentre scorrono le informazioni; sui telefoni sono integrate nella pagina. Le spedizioni seguono **Destinazione → Dettagli → Squadra**, conservando le scelte quando si torna indietro. Le costruzioni usano schede uniformi con illustrazione, funzione e pulsante sempre in fondo. L'armeria offre schede compatte e dettagli apribili toccando l'arma. Da **Impostazioni → Dimensione interfaccia** puoi scegliere **Compatta, Media o Grande**, anche su computer. Al cancello compaiono arma, colpi e recupero; nel villaggio le scorciatoie mostrano prodotti pronti, rifornimenti da avviare e stato delle spedizioni.

## Sviluppo e verifiche

Apri **APRI PROGETTO.cmd**, oppure importa **project.godot** in Godot 4.5.1. Il motore portatile e il template Windows sono inclusi in `tools`. In PowerShell, dalla cartella del progetto:

```powershell
$env:APPDATA = Join-Path (Get-Location) '.runtime/dev-profile'
& '.\tools\godot\Godot_v4.5.1-stable_win64_console.exe' --headless --path . --script tests/test_revision_simulation.gd --log-file (Join-Path (Get-Location) 'tests/dev-simulation.log')
& '.\tools\godot\Godot_v4.5.1-stable_win64_console.exe' --headless --path . --script tests/test_content_defense_v04.gd --log-file (Join-Path (Get-Location) 'tests/dev-content-defense.log')
& '.\tools\godot\Godot_v4.5.1-stable_win64_console.exe' --headless --path . --script tests/test_revision_main.gd --log-file (Join-Path (Get-Location) 'tests/dev-main.log')
& '.\tools\godot\Godot_v4.5.1-stable_win64_console.exe' --headless --path . --export-release Windows 'builds/Niente Zombie Per Favore.exe' --log-file (Join-Path (Get-Location) 'tests/dev-export.log')
```

Le verifiche audio correnti sono in [VERIFICHE-0.4.1.md](docs/VERIFICHE-0.4.1.md). Le [verifiche della 0.4.0](docs/VERIFICHE-0.4.0.md) comprendono tutorial, ripartenza vuota, salvataggi, economia per due ore, nomi, arrivi fuori schermo, sicurezza dei superstiti, gittate, varianti zombie, nuovi edifici, prodotti, spedizioni e migrazione del diario. I documenti distinguono le verifiche del sorgente dai risultati sull'eseguibile Windows. [VERIFICHE.md](docs/VERIFICHE.md) conserva i risultati storici della 0.3.0.

Le anteprime della revisione sono `docs/NUOVA-PARTITA-TUTORIAL.png`, `docs/RIFUGIO-VUOTO.png`, `docs/DIFESA-FLUIDA.png` e le immagini `docs/REVISIONE-*.png`. `docs/CAMMINATA.mp4` e `docs/CAMMINATA-CONTROLLO.mp4` documentano i cicli delle gambe. I vecchi atlanti di camminata sono conservati come materiale storico e non vengono usati durante il gioco.

Prompt grafici in [ART_PROMPTS.md](docs/ART_PROMPTS.md) e [ICON_PROMPT.md](docs/ICON_PROMPT.md). Licenze OFL dei font in `assets/fonts`; licenza MIT di Godot in `docs/GODOT_LICENSE.txt`. Motore e template dalla [release ufficiale Godot 4.5.1](https://godotengine.org/download/archive/4.5.1-stable/).


La nuova interfaccia smartphone usa pagine scorrevoli con chiusura laterale e margini simmetrici, senza app bar o footer fissi. Armeria, spedizioni, negozi, impostazioni e menu principale hanno una composizione dedicata. Dettagli e anteprime in [SMARTPHONE_UI_0.4.1.27.md](docs/SMARTPHONE_UI_0.4.1.27.md).


La revisione 0.4.1.28 ripristina la visuale orizzontale e ridisegna la pausa con Riprendi, opzioni e salvataggio distinti. Dettagli in [SMARTPHONE_HORIZONTAL_0.4.1.28.md](docs/SMARTPHONE_HORIZONTAL_0.4.1.28.md).

