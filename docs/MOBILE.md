# Versione smartphone

La distribuzione Windows dispone anche di una procedura per generare un APK Android firmato: [BUILD_WINDOWS_ANDROID.md](BUILD_WINDOWS_ANDROID.md). L'architettura usa già un progetto Godot 2D landscape, un viewport logico scalabile, pannelli con scroll e un livello di azioni indipendente dal puntatore. La presentazione e la simulazione non si chiamano attraverso eventi di tastiera: i pulsanti invocano azioni semantiche come `assign`, `restock`, `shoot` e `start_expedition`.

## Principi già adottati

- Su Android il gioco parte direttamente a schermo intero immersivo, indipendentemente dalla precedente preferenza desktop. Il formato `expand` riempie lo schermo senza bande laterali né deformare i personaggi; è possibile ruotare il telefono nei due orientamenti orizzontali.
- Sugli smartphone Android gli sprite hanno scale indipendenti dalla telecamera: personaggi e zombie 2,2, edifici 1,6, torretta 1,15 rispetto alla base desktop. La vista iniziale e lo zoom minimo vengono calcolati per contenere tutta l'altezza degli edifici, della torretta, del militare e dei cartelli tra HUD e strada. Solo il giocatore aumenta lo zoom, fino a 1,8 volte la vista completa. La telecamera scorre esclusivamente in orizzontale. PC e tablet conservano la loro scala. L'interfaccia mobile usa un canvas separato e mantiene Compatta, Media e Grande; il cambio delle dimensioni ricalcola la vista completa per continuare a mostrare gli edifici per intero.
- HUD mobile compatto: contatori della sola larghezza necessaria in alto a sinistra, diario e pausa a destra; navigazione raccolta al centro in basso. In modalità Compatta header e footer lasciano almeno il 70% dell'altezza fra loro nei formati collaudati. Arma, colpi e recupero sono fissi nella barra superiore, fra contatori e diario/pausa, sia nel villaggio sia sulla strada. Sotto compaiono soltanto le scorciatoie del villaggio. Nei dialoghi di spesa una riga compatta mantiene visibili gli importi interi esatti delle tre risorse anche scorrendo. Le notifiche mostrano un solo messaggio alla volta.
- Audio e guida sono disponibili dalla pausa e dalle impostazioni. Solo sugli smartphone Android lo sfondo dei dialoghi riempie l'intero display, compresi i margini del notch. I contenuti rispettano l'area sicura, con margine esterno di 16 unità orizzontali e 12 verticali e ulteriori 24 unità su entrambi i lati della pagina scorrevole. Una colonna laterale ospita chiusura e aiuto, mentre titolo, contenuti e azioni scorrono insieme, senza app bar e footer fissi. Le righe compatte permettono di vedere insieme le quattro armi nella modalità Compatta; le impostazioni affiancano Audio e Schermo quando c'è larghezza sufficiente. Sui tablet i dialoghi mantengono larghezza massima di 880 unità e altezza massima di 536, entro l'84% dell'area sicura. I contenuti in eccesso scorrono verticalmente. Le azioni del menu iniziale sono centrate e limitate a 360 × 432 unità. Il tutorial conserva la composizione mobile dedicata.
- Su PC e tablet le azioni principali dei dialoghi sono esterne allo scorrimento: accoglienza, preparazione/partenza e ritiro delle spedizioni, munizioni, acquisto dai dettagli arma, riparazioni, ripresa della partita e conferma delle impostazioni restano raggiungibili. Sui telefoni Android le azioni sono integrate nella pagina scorrevole; restano raggiungibili anche con il formato Grande. L'ammissione mostra l'indizio sull'aspetto prima delle decisioni. Le spedizioni hanno tre passaggi con scelte conservate: destinazione, costi/ricompense/conseguenze e squadra con probabilità di riuscita. Le costruzioni hanno tutte lo stesso comando a fondo scheda, compreso il panificio. L'armeria mostra righe compatte e una scheda di approfondimento per ogni arma.
- Nei contenuti scorrevoli il gesto touch passa anche attraverso card, ritratti, indicatori e pulsanti, inclusi quelli disabilitati. Superata la soglia del trascinamento, il pulsante non esegue il clic; un tap resta un'azione distinta. Lo scorrimento mantiene l'inerzia e i cursori audio conservano il proprio trascinamento orizzontale. La correzione si applica al contenitore condiviso da tutti i dialoghi e al menu mobile.
- Contatori e pulsanti dell'HUD sono elementi flottanti separati da spazi trasparenti, senza una fascia comune; anche le azioni del menu principale sono separate, con sfondi e ombre individuali. Il paesaggio e la strada proseguono dietro ai comandi.
- I controlli rispettano l'area sicura fornita da Android per notch e barre di sistema. Il paesaggio continua sotto questi margini, evitando di aggiungere bande nere; i margini vengono ricalcolati dopo cambi di risoluzione, rotazione e ritorno all'app.
- Nessuna azione essenziale richiede tastiera, tasto destro, doppio clic o hover.
- I bersagli hanno aree di selezione ampie e coerenti con gli sprite ingranditi. Lo scorrimento del mondo è soltanto orizzontale: uno swipe verticale non sposta la visuale e non attiva i personaggi. Le scritte del mondo rimangono grandi. Pinch e pulsanti + / − consentono uno zoom aggiuntivo volontario; il minimo riporta alla vista completa.
- L'HUD distingue risorse con icona e testo. Stati e allarmi usano anche etichette e barre, oltre al colore.
- Il trascinamento della strada resta distinto dal clic grazie a una soglia di spostamento.
- Il mondo riceve input solo quando un pannello non lo copre; il test del viewport verifica anche questo comportamento.
- I comandi zoom e pan sono disponibili sullo schermo. Le scorciatoie desktop sono aggiuntive.
- Gli edifici vengono individuati tramite ID stabili, così il layout può essere sostituito senza cambiare i salvataggi.
- Il rendering degli sprite, le animazioni e i timer usano il tempo trascorso e non il numero dei fotogrammi.
- Salvataggio alla sospensione/focus out e progresso offline sono nel modello. La produzione offline è limitata a otto ore; le ondate restano sospese durante la chiusura.

## Lavoro necessario prima degli store

1. Collaudare la nuova scala su telefoni reali di diagonali e densità differenti. Le anteprime e i test coprono 16:9, 20:9, 16:10 e 4:3; le dimensioni logiche non equivalgono a punti fisici garantiti.
2. Verificare su hardware reale notch, bordi arrotondati, indicatori di sistema e rotazioni. Le aree sicure sono integrate e coperte da simulazioni, ma i comportamenti dei produttori vanno controllati sui dispositivi.
3. Completare e verificare il routing touch, la distinzione tap/drag/pinch, il multitouch e il comportamento quando un dito lascia lo schermo. Il codice di input è separato dalle azioni per permetterlo.
4. Provare la sospensione reale Android/iOS e il ripristino dopo terminazione del processo. Verificare salvataggio atomico, audio, blocco schermo e rotazione.
5. Misurare memoria, caricamento, surriscaldamento e consumo su dispositivi di fascia media/bassa; creare atlanti ottimizzati, mipmap e texture compresse per il target.
6. Completare la preparazione per gli store: icone adaptive e schermate promozionali, accessibilità, privacy e requisiti di distribuzione sulle funzionalità effettivamente presenti. Per Android sono predisposti preset, SDK API 35, template Godot 4.5.1 e firma release stabile; `CREA SETUP E APK.bat` genera l'APK standard ARMv7/ARM64 con versione automatica, senza Gradle. Un eventuale rilascio Google Play richiederà un flusso AAB dedicato e la configurazione dell'account editore. Preset, SDK e firma iOS restano da preparare.

Le verifiche del layout mobile sono documentate in [VERIFICHE_MOBILE.md](VERIFICHE_MOBILE.md). Non è ancora dichiarato un collaudo su telefono reale.

## Riconoscimento degli smartphone Android

Il lato più corto del display viene convertito in dp usando i pixel e la densità logica Android. Sotto 600 dp si applicano dialoghi a schermo intero, sprite ingranditi e vista iniziale adattata; da 600 dp in su rimane la presentazione tablet. La sola risoluzione non distingue i dispositivi: lo stesso schermo 2400 × 1080 può avere classificazioni differenti in base alla densità. Se la densità non è disponibile, non vengono applicate le modifiche specifiche per telefono. iOS e desktop conservano il comportamento precedente.

Riferimenti: [classi di dimensione Android](https://developer.android.com/develop/ui/compose/layouts/adaptive/support-different-display-sizes), [densità restituita da Godot 4.5 su Android](https://github.com/godotengine/godot/blob/4.5-stable/platform/android/java/lib/src/org/godotengine/godot/GodotIO.java).

Anteprime locali: `--android-phone-preview` e `--android-tablet-preview`. `--mobile-preview` continua a mostrare il layout mobile precedente, utile per le regressioni. Il test `tests/test_android_phone.gd` confronta i tre profili, le dimensioni effettive disegnate e i tocchi nel viewport.


