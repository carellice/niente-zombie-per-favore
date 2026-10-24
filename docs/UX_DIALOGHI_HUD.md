# Dialoghi, spedizioni e HUD — 24 ottobre 2026

Documento della revisione precedente. La presentazione smartphone è stata aggiornata nella [0.4.1.28](SMARTPHONE_HORIZONTAL_0.4.1.28.md); costruzioni e spedizioni sono ora descritte nella [0.4.1.29](COSTRUZIONI_SPEDIZIONI_0.4.1.29.md), con tre passaggi e azioni scorrevoli sui telefoni.

Implementati i cinque interventi concordati sull'interfaccia. La grafica mantiene font, illustrazioni e pulsanti separati già presenti.

## Comandi sempre raggiungibili

Il contenitore condiviso dei dialoghi distingue navigazione, contenuto scorrevole e azioni fisse. Ammissione, spedizioni, armeria, dettagli arma, cancello, impostazioni, pausa e diversi pulsanti di ritorno usano la zona delle azioni. Lo scroll conserva il comportamento touch corretto, compreso l'annullamento dei clic durante un trascinamento nell'elenco.

Su smartphone il ritratto dell'aspirante cittadino è più compatto; nome, talenti e lavoro ideale sono leggibili nella parte superiore. L'indizio sull'aspetto e i posti liberi restano insieme alle decisioni di accoglienza. La texture del ritratto continua a dipendere dalla stessa identità e variante del personaggio in strada.

## Spedizioni

La preparazione passa da **Destinazione** a **Squadra**. Si possono cambiare destinazione e membri tornando indietro, conservando anche la posizione dell'elenco. Le destinazioni mostrano durata, minaccia, costo e ricompense; la descrizione completa appare sulla destinazione selezionata. Il secondo passaggio mostra ritratto, incarico, salute, arma e potenza dei cittadini disponibili.

Il riepilogo fisso riporta destinazione, costo, membri e potenza della squadra. La partenza è disabilitata finché non ci sono da uno a tre membri disponibili e le provviste richieste. Il modello esegue comunque la validazione e addebita il costo al momento della partenza. Il ritiro delle ricompense è fisso; dopo il ritiro si torna alla scelta della destinazione.

## Armeria

Le quattro armi hanno righe compatte con illustrazione, nome, gittata, stato e costo/azione. Toccando l'illustrazione o il nome si apre la scheda completa con danno, intervallo fra i colpi e regole delle munizioni. Tornando al catalogo si conserva la posizione precedente. Munizioni disponibili e acquisto di 30 colpi sono fissi in basso, con costo esplicito di 40 monete e 10 provviste.

## Dimensione dell'interfaccia

**Impostazioni → Dimensione interfaccia** offre Compatta, Media e Grande. Compatta è il riferimento precedente; Media e Grande applicano rispettivamente +10% e +20% a controlli e testo. La scelta è immediata e memorizzata nelle preferenze del dispositivo. Modifica il canvas dell'interfaccia, lasciando invariata la scala del mondo e la partita. Durante il cambio la riga delle opzioni rimane raggiungibile e il comando Fatto resta fisso.

## Informazioni contestuali

La posizione della visuale determina il contesto: nella zona del cancello compaiono arma attiva, munizioni e indicazione del recupero fra i colpi, con barra che torna a Pronto. Il pulsante con l'arma apre l'armeria.

Nel villaggio compaiono solo le scorciatoie utili: prodotti pronti per gli scaffali, prodotti esauriti sbloccati dai lavoratori presenti e spedizione in corso/rientrata. I pulsanti dei negozi aprono la prima attività corrispondente e portano al relativo comando di rifornimento. Il tempo di rientro viene aggiornato; la scorciatoia della spedizione apre il dossier. Questi elementi si nascondono nei dialoghi e durante la guida espansa.

## Verifica

`tests/test_ux_flow.gd` verifica tutti e tre i formati dell'interfaccia su 16:9, 20:9, 16:10 e 4:3: menu, HUD, ammissione, armeria, entrambi i passaggi delle spedizioni, impostazioni e cancello. Controlla geometria, scorrimento indipendente dalle azioni, tap nel viewport scalato, salvataggio e ricaricamento delle preferenze, conservazione della partita e transazioni reali.

`tests/test_touch_scroll.gd` copre anche l'elenco della squadra. Le schede che ora entrano interamente nello spazio disponibile vengono verificate come contenuti senza necessità di scorrimento. Sono mantenute le verifiche per rotella desktop, gesture ripetute, slider, pulsanti attivi/disabilitati e ingresso animato dei dialoghi. Le prove con input simulato e renderer desktop non sostituiscono il collaudo su dispositivo Android fisico.

Anteprime `docs/UX-*.png`; copie dei sorgenti precedenti in `.runtime/ux-before-0.4.1.24/`.

## Rilascio 0.4.1.24

APK **401024** e setup Windows prodotti con il BAT, firma Android v2/v3 stabile, package/versione e allineamento verificati. I checksum di APK, setup ed eseguibile corrispondono al manifest del rilascio. La copia Windows usata dai collegamenti è aggiornata; precedente conservata in `.runtime/NienteZombie-prima-ux-dialoghi.exe`.

Risultati:

| Verifica | Controlli | Errori |
| --- | ---: | ---: |
| Flussi UX completi sul codice esportato, quattro formati mobile e tre dimensioni, più desktop | 830 | 0 |
| Percorso mirato con renderer desktop e catture, inclusi i tre formati desktop | 148 | 0 |
| Gesti touch, inclusi entrambi i passaggi delle spedizioni e schede corte senza scroll necessario | 354 | 0 |
| Menu desktop | 28 | 0 |
| Interfaccia e transazioni preesistenti | 63 | 0 |
| Animazione e sostituzione dei dialoghi | 61 | 0 |
| Catalogo e contenuti | 141 | 0 |
| Caricamento e icona adattiva | 20 | 0 |
| Risorse del pacchetto Windows | 87 | 0 |
| Risorse dell'APK, inclusi i nuovi pannelli compilati | 35 | 0 |

I test storici che usano `user://` segnalano scritture bloccate nel profilo di prova; le relative asserzioni passano. I nuovi test usano percorsi dedicati in `.runtime/`. Il renderer segnala la cache shader non scrivibile; il rendering e le catture terminano correttamente. I log sono conservati in `builds/releases/0.4.1.24/logs/`.

## Adattamento successivo per smartphone Android

Dalla 0.4.1.27 la presentazione dei telefoni è stata ridisegnata: pagine con una sola area scorrevole, chiusura laterale e margini simmetrici, senza fasce superiore e inferiore fisse. La scala del mondo è doppia rispetto alla 0.4.1.26 e le scritte del mondo sono raddoppiate. La descrizione seguente conserva il passaggio precedente; per il comportamento corrente vedere [SMARTPHONE_UI_0.4.1.27.md](SMARTPHONE_UI_0.4.1.27.md).

Sui telefoni Android sotto 600 dp lo sfondo dei dialoghi riempie l'intero display, con padding interno oltre i margini sicuri e impostazioni a due colonne quando c'è spazio. Le azioni principali restano fisse e lo scorrimento conserva la gestione touch comune. Tablet e PC mantengono le dimensioni precedenti. La scena sul telefono è ingrandita dell'80% rispetto alla scala PC/tablet, compreso il limite dello zoom, indipendentemente dalla dimensione scelta per l'interfaccia. Criteri e verifiche in [MOBILE.md](MOBILE.md) e [VERIFICHE_MOBILE.md](VERIFICHE_MOBILE.md).

