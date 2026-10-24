# Difesa: pulsanti e risorse disponibili — 0.4.1.35

Il pulsante Potenzia del cancello restava attivo anche senza le risorse necessarie. La simulazione rifiutava correttamente la spesa, ma l'interfaccia permetteva comunque di premere il comando.

Ora Potenzia è disabilitato se mancano monete o provviste, o se la spesa intaccherebbe le monete riservate dal tutorial a casa, caffè e primo rifornimento. Il controllo del budget usato dall'interfaccia è silenzioso: non genera notifiche ripetute. La validazione al momento dell'acquisto resta attiva.

Anche Ripara tiene conto di entrambe le risorse, oltre a essere disabilitato quando il cancello è integro. Prezzo e stato dei due pulsanti si aggiornano nel dialogo aperto quando cambiano saldo, livello o danni. Nessuna modifica a prezzi, effetti degli acquisti o salvataggi.

## Verifiche del sorgente

- **192 controlli con OpenGL, zero fallimenti**: quattro profili PC/tablet/smartphone e tre scale UI. Input touch con puntatore emulato sui pulsanti effettivi; monete insufficienti anche per frazioni, provviste insufficienti, costo esatto, variazione del saldo senza riaprire, potenziamento e riparazione pagati una sola volta, prezzo del livello successivo, danni durante il dialogo e riserva del tutorial.
- **880 controlli UX** e **90 del tutorial completo**, senza fallimenti. L'asserzione finale del tutorial usa ora l'intervallo corretto per la popolazione presente; il precedente limite per rifugio vuoto poteva fallire casualmente dopo l'accoglienza del primo cittadino. Le regole degli arrivi non cambiano.
- Test e dati isolati dalla partita del giocatore. I profili Android sono simulati sul computer; nessun nuovo collaudo su Pixel fisico.

Test dedicato: `tests/test_gate_affordability.gd`.

## Pacchetti

Setup Windows e APK **0.4.1.35 / Android 401035** completati. Dalla cartella Windows senza sorgenti locali di gioco passano gli stessi **192 controlli di acquisto con OpenGL** e **87 verifiche delle risorse**; sull'APK passano **41 controlli**. Nessun fallimento. Firma Android v2/v3 stabile, allineamento, metadati e checksum verificati.

Pacchetti e log in `builds/releases/0.4.1.35/`. Eseguibile dei collegamenti aggiornato; precedente conservato in `.runtime/NienteZombie-prima-costi-difesa.exe`.
