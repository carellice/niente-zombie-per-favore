# Armi personali e scelte nelle spedizioni — 0.4.1.36

Ogni cittadino acquista la propria copia di un'arma e conserva le proprie munizioni per quel modello. Possedere o acquistare un'arma della torretta non fornisce copie gratuite ai residenti. Le copie personali si comprano direttamente dall'equipaggiamento, anche se il militare non ha ancora quel modello. Cambiare fra le armi già acquistate dalla stessa persona è gratuito; ogni acquisto equipaggia l'arma e include una prima scorta.

La pistola di servizio resta gratuita, con colpi infiniti: le spedizioni sono accessibili anche senza acquistare equipaggiamento avanzato.

## Prezzi e consumi

| Arma personale | Acquisto | Scorta inclusa | Rifornimento personale | Consumo per spedizione nelle zone attuali |
| --- | --- | --- | --- | --- |
| Pistola | Gratuita | Infiniti | Non necessario | 0 |
| Pompa | 310 monete + 12 provviste | 12 cartucce | 12 cartucce per 30 monete + 3 provviste | 2–4 cartucce |
| Precisione | 625 monete + 24 provviste | 6 proiettili | 6 proiettili per 36 monete + 4 provviste | 1–3 proiettili |
| Mitragliatore | 490 monete + 18 provviste | 36 colpi | 36 colpi per 45 monete + 5 provviste | 8–14 colpi |

Il consumo cresce con la minaccia della destinazione ed è mostrato prima della partenza. Viene pagato una sola volta, insieme alle provviste. Una squadra con scorte insufficienti non parte e non paga nulla: può rifornirsi oppure equipaggiare la pistola. I cittadini assenti non possono acquistare, rifornire o cambiare arma. Il bottino di munizioni continua a rifornire la torretta; il gioco lo indica esplicitamente.

## Quale arma scegliere

| Ambiente | Destinazioni | Vantaggio |
| --- | --- | --- |
| Spazi stretti | Minimarket, laboratorio, farmacia, deposito | Pompa ×2,35 |
| Spazi aperti | Orti, osservatorio | Precisione ×2,35 |
| Zona affollata | Stazione, avamposto | Mitragliatore ×2,35 |
| Percorso misto | Campeggio | Mitragliatore ×1,75; pompa e precisione ×1,65 |

Il fattore modifica il contributo del cittadino alla potenza della squadra. La probabilità effettiva considera anche salute, caratteristiche e minaccia e rimane limitata al 100%. Il fucile di precisione scende a ×1,25 negli spazi stretti, dove il pompa è più efficace; il pompa scende a ×1,25 all'aperto. Le altre combinazioni e i costi sono definiti in `scripts/expedition_gear.gd`.

La scelta della destinazione mostra ambiente e arma consigliata. In preparazione compaiono arma, scorta e consumo di ogni persona, probabilità aggiornata e costo complessivo alla partenza. **Arma e munizioni** apre gli acquisti di quella persona; **Torna alla squadra** conserva zona e selezione. Nel confronto dell'equipaggiamento sono visibili moltiplicatore e consumo per la rotta corrente. Il manuale del gioco spiega anche questi passaggi.

## Partite esistenti

Il formato dei salvataggi resta compatibile con la versione 2. Le armi già equipaggiate nei vecchi salvataggi diventano copie personali dei rispettivi cittadini con una prima scorta inclusa. Le altre armi della torretta rimangono disponibili al militare. Non vengono aggiunte copie avanzate ai cittadini che avevano soltanto la pistola.

Le spedizioni precedenti già in corso conservano esito e ricompense senza costi retroattivi. Nei nuovi viaggi colpi ed equipaggiamento pagati alla partenza sono persistenti: caricamento, rientro offline e ritiro del bottino non ripetono il pagamento. Proprietà e quantità personali vengono validate prima di caricare; sono rifiutati valori negativi, frazionari, non finiti, modelli sconosciuti e copie duplicate.

## Verifiche del sorgente

- **563 controlli del modello**, senza fallimenti: acquisti reali, budget esatti e insufficienti, scorte separate, vantaggi per tutte le nove zone, partenza atomica, salvataggio/ripresa di 36 combinazioni arma/rotta, migrazione e validazione.
- **446 controlli dell'interfaccia con OpenGL**, senza fallimenti: quattro profili PC/tablet/smartphone e tre scale UI; input touch e mouse emulato, acquisto, rifornimento, ritorno alla squadra, partenza e leggibilità orizzontale.
- Regressioni passate: **1.045 popolazione/spedizioni**, **751 simulazione prolungata**, **880 UX**, **2.621 layout Android**, **354 scroll touch**, **90 tutorial**, **63 interfaccia**, **200 costruzione** e **192 pulsanti difesa**.

I test usano dati isolati dal giocatore. I profili Android e i gesti sono simulati sul computer; non costituiscono un nuovo collaudo su Pixel fisico.

## Rilascio verificato

Setup Windows e APK **0.4.1.36 / Android 401036** completati in `builds/releases/0.4.1.36/`. I test eseguiti dalla cartella Windows senza sorgenti locali del gioco superano **563 controlli del modello** e **446 dell'interfaccia con OpenGL**, con gli stessi acquisti e salvataggi reali. Passano **87 verifiche delle risorse Windows** e **43 dell'APK**, inclusi i nuovi moduli dell'equipaggiamento. Nessun fallimento.

Firma Android v2/v3 stabile, allineamento, versione e checksum verificati. L'eseguibile dei collegamenti è aggiornato; la precedente versione è conservata in `.runtime/NienteZombie-prima-equipaggiamento-personale.exe`. I log di sorgente e pacchetti sono nella cartella del rilascio.

Le anteprime `GEAR-*.png` sono prodotte dal pacchetto esportato sui quattro profili. Esempi: [equipaggiamento smartphone](GEAR-PHONE169-LOADOUT.png), [preparazione squadra smartphone](GEAR-PHONE-TEAM.png), [equipaggiamento PC](GEAR-DESKTOP-LOADOUT.png).
