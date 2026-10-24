# Rifugio espandibile — 0.4.1.34

Dopo il terzo edificio il comando del lotto libero poteva restare tagliato dal bordo destro, anche trascinando fino al limite. La telecamera riservava solo 220 unità oltre gli edifici: meno della larghezza del comando su PC e ancora meno rispetto agli sprite ingranditi su smartphone.

Ora il limite destro include un intero lotto aggiuntivo, le scritte e un margine di 24 pixel oltre all'eventuale rientro del display. Parte dalla posizione corrente del lotto libero, quindi avanza automaticamente di un lotto a ogni costruzione avviata, senza aspettarne il completamento. Disegno e area cliccabile condividono la geometria del comando; anche la didascalia resta cliccabile. Lo scorrimento rimane orizzontale e conserva lo zoom scelto.

La correzione si applica anche ai rifugi esistenti senza modificare i salvataggi.

## Verifiche del sorgente

- **604 controlli, zero fallimenti** con renderer OpenGL: PC, tablet, smartphone 16:9 e 20:9; tre dimensioni dell'interfaccia e tre livelli di zoom; rifugi con 0, 3, 4 e 12 lotti.
- Il test misura l'ingombro effettivo di lotto e scritte, verifica il margine rispetto all'area sicura, invia clic reali sul comando e controlla l'aumento del limite appena inizia il quarto cantiere.
- **390 controlli di layout** e **200 controlli del ciclo di costruzione**, senza fallimenti.
- Dati di prova isolati dalla partita del giocatore. Le prove su smartphone usano la simulazione del layout sul computer; non sono un nuovo collaudo su Pixel fisico.

Test: `tests/test_village_expansion.gd` e `tests/expansion_render_probe.gd`.

## Pacchetti

Setup Windows e APK **0.4.1.34 / Android 401034** generati in `builds/releases/0.4.1.34/`. Il test dell'espansione eseguito dal pacchetto Windows, nella propria cartella e senza sorgenti locali di gioco, supera gli stessi **604 controlli**. Le verifiche delle risorse Windows superano **87 controlli**; quelle dell'APK **41**. Nessun fallimento.

Firma Android v2/v3 con il certificato stabile del progetto, allineamento, versione e checksum verificati. Le otto anteprime `EXPANSION-*.png` del pacchetto sono conservate in `.runtime/expansion-packed-captures/`; i log del sorgente e del pacchetto nella cartella del rilascio. L'eseguibile Windows dei collegamenti è aggiornato; la precedente versione è conservata in `.runtime/NienteZombie-prima-espansione.exe`.
