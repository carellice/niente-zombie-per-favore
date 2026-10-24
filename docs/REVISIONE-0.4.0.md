# Niente Zombie Per Favore! — revisione 0.4.0

## Dialoghi animati — 0.4.0.2

Tutte le finestre si aprono con una breve dissolvenza, un piccolo movimento
verso l'alto e un leggero assestamento della scala. L'animazione dura circa
un quarto di secondo e funziona anche nei dialoghi di pausa e impostazioni.
Passando fra finestre, lo sfondo oscurato resta continuo.

Aggiornare un prodotto, comprare munizioni o assegnare una persona non fa
ripartire l'apertura della stessa scheda e mantiene lo scorrimento.
I comandi continuano a funzionare subito, senza attendere l'animazione.

## Contorno di portata — 0.4.0.1

Gli zombie raggiungibili con l'arma attuale hanno un contorno luminoso
dorato che segue la loro sagoma e le gambe in movimento. Compare quando
entrano nella gittata, cambia subito passando a un'altra arma e resta
stabile durante l'attesa fra i colpi. Le persone in attesa non sono evidenziate.
Con munizioni esaurite viene usata la portata effettiva della pistola.
Il tutorial e l'armeria spiegano il significato del contorno.

Anteprima: `docs/CONTORNO-PORTATA.png`.

## Novità della 0.4.0

La difesa richiede ora di scegliere il momento e l'arma adatti; il rifugio
offre più attività, prodotti, mete e obiettivi. L'interfaccia usa nuove
illustrazioni imagegen per rendere leggibili risorse e funzioni degli edifici.
La versione del pacchetto Windows è **0.4.0.0**. Lo stato delle
verifiche del sorgente e dell'export è riportato separatamente in
[VERIFICHE-0.4.0.md](VERIFICHE-0.4.0.md).

## Difesa e arrivi

- Il gioco non mostra più gruppi numerati: alla fine compare
  **Zombie respinti!**, accompagnato dalla ricompensa.
- Gli arrivi comprendono da due a otto zombie. I classici restano la
  maggioranza; corridori e colossi sono meno comuni. Una variante compare
  già nel primo gruppo dopo il tutorial, poi almeno in un gruppo ogni tre.
- Tutti e tre i tipi camminano più rapidamente. La salute e la forza restano
  proprie del tipo di zombie e non aumentano in modo esponenziale.
- Dopo aver eliminato l'ultima minaccia e terminato gli ingressi, il riposo
  dura da **55 a 95 secondi**. I singoli zombie entrano a distanza di
  **2,5–5 secondi** l'uno dall'altro, camminando da fuori schermo.
- Ogni arma ha una gittata: pompa corta, pistola media, mitragliatore ampia,
  precisione lunga. Un bersaglio troppo lontano deve prima avvicinarsi;
  il tentativo non consuma munizioni e non genera spari o ricariche.
- Il tutorial introduce questa attesa già con il primo zombie.

Le portate usate dalla simulazione, misurate dalla posizione del cancello,
sono 430 unità per il pompa, 650 per la pistola, 800 per il mitragliatore e
1.800 per la precisione. Le unità sono coordinate del mondo di gioco.
I tipi zombie usano velocità fisse di 34, 65 e 23 unità al secondo,
rispettivamente classico, corridore e colosso.

## Barra superiore e dialoghi

La barra non ripete più logo del gioco e nome del rifugio. Il giorno mantiene
il sole e viene scritto senza zeri iniziali, per esempio **Giorno 5**.
Giorno e numero di abitanti hanno ciascuno la propria card; la popolazione
è accompagnata da una nuova icona dipinta.

Le schede delle attività mostrano illustrazioni dei prodotti e descrizioni
brevi. Il caffè di sopravvivenza, per esempio, è merce da mettere sugli
scaffali e vendere per ottenere monete. Quantità, prezzo, preparazione e
lavoratori necessari spiegano le decisioni da prendere. Il pulsante **?**
resta disponibile per l'aiuto specifico dell'edificio.

Armi e munizioni conservano le illustrazioni imagegen introdotte nella
0.3.0.1. I nuovi asset comprendono popolazione, prodotti, tre facciate e
varianti delle condizioni dei personaggi; riprendono contorni, colori e
proporzioni della grafica giocattolosa del rifugio.

## Persone al cancello

Il puntino verde sul viso è sostituito da varianti dipinte dei personaggi:
pelle e abiti possono apparire puliti, sporchi o mostrare segni iniziali
sospetti. Anche persone sane possono essere sporche o graffiate. Gli indizi
descrittivi lasciano un dubbio fra stanchezza, ferite del viaggio e contagio.

Il ritratto e il personaggio sulla strada usano la stessa identità e la stessa
variante. L'aspetto si mantiene nell'ammissione, nella partenza dopo un
rifiuto e nel salvataggio. Un infiltrato rivelato conserva aspetto e posizione
invece di trasformarsi in una persona diversa o apparire accanto al cancello.
Gli zombie continuano a lasciare in pace i superstiti fuori dalle mura.

## Otto edifici e ventuno prodotti

Alle cinque categorie esistenti si aggiungono tre attività, ognuna con una
facciata dedicata e tre livelli di produzione:

| Attività | Talento utile | Prodotti |
| --- | --- | --- |
| Panificio del mattino | Cibo | Pane della ripartenza, Panini del viaggio, Torta del buonumore |
| Acqua di domani | Servizi | Borracce d'acqua, Scorta filtrata, Riserva cristallina |
| Ago & coraggio | Beni | Calze rammendate, Giacche resistenti, Zaini d'avventura |

Il catalogo comprende ora otto tipi di edificio: casa, caffè, orto, officina,
clinica, panificio, depuratore e sartoria. Le sette attività offrono
ventuno prodotti. Anche i nuovi lavori possono essere il sogno di un
cittadino e ricevono il relativo bonus di capacità. I talenti corretti
accelerano la preparazione; due e tre lavoratori sbloccano i livelli successivi.

## Nove destinazioni e trentadue obiettivi

Minimarket abbandonato, Stazione ferroviaria e Laboratorio 13 restano
disponibili negli stessi indici dei vecchi salvataggi. Si aggiungono
Orti di periferia, Farmacia della piazza, Deposito municipale, Campeggio sul
lago, Avamposto dimenticato e Osservatorio sulla collina. Ogni zona ha
durata, costo in provviste, difficoltà e ricompense propri.

Il diario passa da otto a **trentadue obiettivi**, dedicati anche a costruzioni
specifiche, assegnazioni, vendite, nuove produzioni, destinazioni differenti,
armi possedute, cure, riparazioni e tipi di zombie. Il progresso viene dalle
azioni effettive della partita; ogni ricompensa si può riscuotere una sola volta.

## Compatibilità e nuova partita

**Continua** mantiene il rifugio esistente: il formato dei salvataggi resta
compatibile con la versione 2. Nuovi contenuti e metadati vengono aggiunti
senza sostituire gli edifici o le scorte già presenti. Il diario usa
identificatori stabili e una migrazione versionata: i vecchi progressi e i
premi già riscossi vengono conservati, senza accrediti duplicati.

**Nuova partita** rimane una scelta esplicita con conferma: svuota il rifugio,
mantiene il militare sulla torre e avvia il tutorial. Non è necessaria per
accedere ai nuovi edifici, alle spedizioni e agli obiettivi della revisione.
Le preferenze audio e video rimangono separate dal progresso.

## Asset e verifiche finali

Le illustrazioni sono state create con imagegen integrato e conservate come
PNG originali nel progetto. Prompt e percorsi degli asset:

- [Popolazione e varianti dei superstiti](SUSPICION_POPULATION_PROMPTS.md)
- [Tre nuove facciate](BUILDINGS_V04_PROMPTS.md)
- [Prodotti: set A](PRODUCT_ICONS_V04_A.md) e [set B](PRODUCT_ICONS_V04_B.md)

L'eseguibile Windows 0.4.0.0 ha superato **502 controlli**, comprendenti il
tutorial completo, la portata delle armi, i dialoghi, i nuovi asset e l'audio.
Il pacchetto contiene le immagini e le relative mipmap; non dipende da file
del progetto sorgente. Tutte le prove usano dati temporanei separati dalla
partita del giocatore. Dettagli in [VERIFICHE-0.4.0.md](VERIFICHE-0.4.0.md).
