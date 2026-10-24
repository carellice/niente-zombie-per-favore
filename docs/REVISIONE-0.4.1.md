# Niente Zombie Per Favore! — revisione 0.4.1

Questa versione integra i sei suoni forniti nella cartella `suoni/`: pistola, fucile a pompa, fucile di precisione, mitragliatore, ricarica e ambiente zombie. Gli originali sono conservati senza modifiche.

## Aggiornamento 0.4.1.4 — contatori senza decimali inutili

I talenti Cibo, Beni e Servizi nell'ammissione mostrano numeri interi anche dopo il caricamento della partita, che può rappresentare i valori JSON come `5.0`. Corretta la stessa eventualità nel messaggio delle ricompense delle spedizioni. I contatori abbreviati non aggiungono più lo zero decimale: `100 k` e `1 M`; le frazioni significative, come `12.5 k`, e i tempi delle armi rimangono visibili.

## Aggiornamento 0.4.1.3 — interazione con gli edifici

La barra dorata sotto l'edificio è sostituita da un contorno luminoso caldo che segue la sagoma dipinta. L'hover entra ed esce gradualmente, con un lieve chiarimento e un ingrandimento dello 0,5%. Il clic produce una piccola pressione e un rimbalzo di 0,30 secondi, continuando durante l'apertura immediata della scheda. Il movimento riguarda solo l'illustrazione: nomi, targhette, personaggi e aree cliccabili rimangono fermi.

Il puntatore viene rivalutato quando la visuale si muove: il risalto non rimane sull'edificio precedente. Si attenua passando sull'HUD, aprendo un dialogo o trascinando la scena. Le maschere della sagoma sono preparate una sola volta, ritagliate per ogni asset e mantenute in cache; il disegno non rilegge immagini o pixel a ogni fotogramma.

## Aggiornamento 0.4.1.2 — allineamento dell'interfaccia

Icone e testi dei cinque pulsanti di navigazione sono centrati come gruppo, con margini simmetrici e posizioni che seguono le dimensioni del pulsante. Anche il pulsante del cancello centra insieme icona, titolo e barra. Le schede Cibo, Beni e Servizi nell'ammissione centrano icona e numero, con didascalia centrata sotto. Lo stesso criterio è applicato ai contatori HUD, alle tre schede del menu principale e all'icona dell'avviso zombie. Tutti i pulsanti testuali mantengono l'allineamento centrale; i contenuti decorativi lasciano passare i clic.

## Aggiornamento 0.4.1.1 — clic dell'interfaccia

Un nuovo clic breve e morbido accompagna tutti i pulsanti, compresa la X dei dialoghi. Si sente anche aprendo una scheda da un edificio, dal cancello, da un sopravvissuto o dal lotto di costruzione. Il suono viene emesso una sola volta per interazione; i refresh automatici dei pannelli restano silenziosi. Deriva da campioni locali Kenney CC0, con volume ed equalizzazione adatti all'interfaccia. Rispetta le impostazioni del volume effetti e dell'audio generale.

## Spari e ricariche

Ogni arma usa la propria registrazione. I colpi si sentono quando l'arma spara effettivamente: un bersaglio fuori portata, una finestra aperta o un'arma ancora in attesa non fanno partire uno sparo. La raffica del mitragliatore resta legata alla pressione del giocatore e si interrompe al rilascio.

Il file del mitragliatore conteneva già una piccola raffica. È stato estratto un ciclo di 80 millisecondi per evitare che un solo proiettile produca tre colpi udibili. Le altre armi conservano il carattere e la coda del suono originale.

La registrazione di ricarica viene usata per i meccanismi fra i colpi: circa 0,38 secondi per il pompa, 0,58 per la precisione e un piccolo scatto di 65 millisecondi per il mitragliatore. Le azioni partono dopo lo sparo e rientrano nell'attesa dell'arma, con volume inferiore al colpo.

## Ambiente degli zombie

La registrazione degli zombie viene riprodotta intera, nello stesso ordine e alla velocità originale. Sono rimossi soltanto gli ultimi secondi di silenzio digitale: rimangono circa **93 secondi di performance**.

Quando la traccia sta per terminare, un secondo lettore entra con una **sfumatura di 2,5 secondi** mentre il primo si attenua. La ripartenza risulta meno percepibile rispetto al riavvio netto del file.

Il sottofondo segue gli zombie visibili, si sfuma entrando e uscendo dalla zona di difesa e si abbassa durante gli spari. Pausa, menu, mute e volumi delle impostazioni sono rispettati; il ritorno alla difesa riprende dalla posizione audio conservata. Non sono state reintrodotte voci dei sopravvissuti.

## Preparazione e provenienza

Gli effetti sono convertiti in asset locali ottimizzati, senza dipendenze di rete durante il gioco. Il guadagno viene applicato in virgola mobile prima di produrre i WAV, evitando il clipping causato dai picchi di alcuni MP3. I bordi dei campioni hanno brevi dissolvenze per evitare clic.

Le registrazioni sono state dichiarate di libera distribuzione dal creatore del progetto. I crediti distinguono questi suoni dalle raccolte CC0 precedenti; non vengono inventati autori o licenze. Fonti, metadati, ricette e SHA-256 sono conservati nel progetto.

- [Provenienza dei suoni forniti](USER_AUDIO_SOURCES.md).
- [Audio e licenze, con archivio storico](AUDIO_LICENSES.md).
- [Riproduzione della traccia zombie](CHARACTER_VOICES.md).

Il salvataggio e i progressi della partita restano compatibili: è possibile usare **Continua**.
