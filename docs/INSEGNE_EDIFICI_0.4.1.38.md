# Conteggi e insegne degli edifici — 0.4.1.38

Ogni scheda di Costruisci mostra **Già costruiti: N**, contando gli edifici completati di quel tipo realmente presenti nel rifugio. I cantieri sono indicati separatamente con **In costruzione: M** e passano nel conteggio dei completati al termine del timer. I valori si aggiornano anche con il menu aperto, usando gli edifici attuali anziché i progressi storici del diario.

Nella città il nome sotto ogni fabbricato è sostituito da un'insegna illustrata sul tetto, presente anche durante la costruzione e cliccabile per aprire la scheda dell'edificio.

| Edificio | Simbolo |
| --- | --- |
| Casa | Casetta |
| Caffè | Tazza fumante |
| Orto | Cesto di verdure |
| Officina | Attrezzi |
| Clinica | Borsa di pronto soccorso |
| Panificio | Pane |
| Depuratore | Borracce d'acqua |
| Sartoria | Stoffa |

Sotto gli edifici rimangono posti, lavoratori, merce pronta, rifornimenti e tempi dei cantieri in una targhetta compatta. I nomi completi restano nei menu e nelle schede. Le insegne si adattano alla posizione dei pulsanti dell'HUD e sono disegnate davanti alle luci decorative per mantenere il simbolo visibile.

La grafica riutilizza le illustrazioni del gioco. Le texture delle insegne sono ritagliate, ridotte una sola volta a un massimo di 128 pixel con filtro Lanczos e mipmap e precaricate: non viene ridimensionato un PNG grande a ogni fotogramma. Nessuna modifica a economia, tempi, edifici o salvataggi.

## Verifiche del sorgente

- **184 controlli di costruzione e interfaccia con OpenGL**, senza fallimenti, su PC, tablet e due formati smartphone alle tre scale UI. Conteggi per tipo, distinzione dei cantieri, completamento, assenza del vecchio nome nella scena, rendering dell'insegna e apertura con input effettivo sul simbolo.
- **2.621 controlli del layout Android** e **354 dello scroll touch**, senza fallimenti.
- Galleria grafica di tutti gli otto tipi e degli stati delle attività su PC e smartphone 16:9/20:9, con conteggi di edifici pronti e cantieri nel catalogo. Dati isolati dal giocatore; Android simulato sul computer, senza nuovo collaudo su Pixel fisico.

## Rilascio verificato

Setup Windows e APK **0.4.1.38 / Android 401038** completati. Dalla cartella Windows senza sorgenti locali del gioco passano gli stessi **184 controlli di costruzione e interfaccia con OpenGL**, **87 delle risorse** e una galleria di **15 acquisizioni**. Sull'APK passano **44 controlli**, incluso il modulo delle insegne. Nessun fallimento. Firma Android v2/v3 stabile, allineamento, metadati e checksum verificati.

L'eseguibile dei collegamenti è aggiornato; precedente conservato in `.runtime/NienteZombie-prima-insegne-edifici.exe`. Log in `builds/releases/0.4.1.38/logs/`. La galleria completa del pacchetto è in `.runtime/building-signs-packed-gallery-captures/`.

Anteprime dal pacchetto: [città con insegne](INSEGNE-PHONE-0.4.1.38.png) e [conteggi nel catalogo](CONTEGGI-PHONE-0.4.1.38.png).
