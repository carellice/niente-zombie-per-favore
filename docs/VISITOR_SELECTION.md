# Identità dei superstiti nella scheda di ammissione

La coda riproduce gli screenshot: barista davanti (`x = 195`), persona con berretto al centro (`x = 141`), dottoressa dietro (`x = 87`). I ritratti usano già la stessa associazione `look` dei personaggi nella strada. Il problema era la selezione: le aree cliccabili si sovrappongono e il codice apriva il primo superstite compatibile nell'array, prima di verificare quello realmente più vicino al puntatore.

`tests/test_visitor_selection.gd` invia eventi di pressione e rilascio al viewport della scena principale, usando salvataggi e impostazioni isolati. Non chiama direttamente il selettore e non si limita a verificare l'associazione delle immagini.

Il test controlla:

- Testa, busto e piedi di tutti e tre i superstiti a zoom 0,60, 0,82 e 1,25.
- ID del dialogo, nome visualizzato, metadati e texture del ritratto effettivo.
- Coerenza tra evidenziazione sotto il puntatore e persona aperta.
- Selezione corretta anche invertendo l'ordine dell'array.
- Superstite e zombie vicini: aprire la persona non deve sparare allo zombie, e cliccare lo zombie deve ancora sparare.
- Accettazione e rifiuto della persona selezionata, mantenimento di nome e aspetto, aggiornamento della coda dopo una decisione.

Prima della correzione: **181 verifiche, 96 fallimenti**, registrati in `tests/visitor-selection-before.log`. I clic sul personaggio centrale e sull'ultimo aprivano un'altra persona a tutti i livelli di zoom. Anche le azioni di ammissione e rifiuto agivano sull'identità sbagliata.

Dopo la correzione: **181 verifiche, 0 fallimenti**, sia in modalità headless (`tests/visitor-selection-after.log`) sia con il renderer OpenGL e la scena reale (`tests/visitor-selection-render.log`). Il selettore confronta tutti gli attori compatibili prima di scegliere quello più vicino, e viene condiviso da evidenziazione e clic.

Le immagini riproducono lo stesso caso segnalato: nella [coda](SELEZIONE-CODA.png) la persona con berretto è al centro; dopo il clic sul suo busto, la [scheda di ammissione](SELEZIONE-CENTRALE.png) mostra **Marta Berretto**, con berretto turchese, maglia arancione, zaino e pantaloni verdi. Il nome è esplicitamente assegnato dal test per distinguere le tre identità. Gli altri due personaggi sono Ada Barista e Iris Dottoressa.

Esecuzione con acquisizione delle immagini:

```powershell
$env:APPDATA = Join-Path (Get-Location) '.runtime'
& '.\tools\godot\Godot_v4.5.1-stable_win64_console.exe' --path . --script tests/test_visitor_selection.gd --resolution 1440x900 --log-file 'C:/Users/flavi/Desktop/CODEX_niente_zombie_per_favore/tests/visitor-selection-render.log' -- --capture-selection
```
