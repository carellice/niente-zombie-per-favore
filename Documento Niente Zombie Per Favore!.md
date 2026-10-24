# Niente Zombie Per Favore!

Questi sono i dettagli del videogioco che voglio creare! Per ora analizziamo insieme senza partire subito con lo sviluppo.

**Niente Zombie Per Favore!** è un gioco gestionale e di difesa a scorrimento laterale 2D landscape per piattaforme mobile, fortemente ispirato alle dinamiche di titoli come *Tiny Tower*, ma innestato su un'ambientazione survival post-apocalittica con meccaniche attive di shooting touch. Deve essere potenzialmente infinito come gioco 

Il **Core Loop** si articola su tre pilastri interconnessi:

1. **Accoglienza & Difesa alle Mura:** Monitorare l'ingresso della città. I sopravvissuti bussano per entrare; gli zombie avanzano e devono essere abbattuti manualmente via tap/aim prima che danneggino le difese o infettino l'insediamento.
2. **Assegnazione & Gestione Economica:** I sopravvissuti accolti vengono alloggiati nelle case e assegnati a edifici commerciali (negozi di cibo, beni, servizi). Qui producono risorse e monete tramite timer di rifornimento e vendita.
3. **Espansione, Equipaggiamento & Spedizioni:** Le monete e le risorse guadagnate servono a costruire nuovi lotti verso destra/sinistra lungo la strada, potenziare armi e barricate, ed equipaggiare i cittadini per spedizioni esplorative esterne alla ricerca di provviste rare e blueprint.

Architettura Dati e Sistemi di Gioco

### 1. Sistema Cittadini (Sopravvissuti)

Ogni PNG generato deve possedere una struttura dati definita:

- **Attributi Personali:** ID, Nome, Avatar (testa, corpo, accessori generati proceduralmente), Livello felicità.
- **Statistiche Lavorative:** Valori di affinità o punteggi specifici per settore (es. *Food*, *Goods*, *Entertainment*). Più alto è il valore, minore è il tempo/costo di rifornimento.
- **Lavoro Ideale (Dream Job):** Se assegnato all'attività esatta corrispondente al suo sogno, il cittadino raddoppia la capacità di stock o dimezza i costi di produzione, sbloccando un bonus permanente per quell'attività.
- **Stato Combat:** Punti vita (HP), slot arma equipaggiabile, danno base, precisione.

### 2. Struttura Urbana ed Edifici

La mappa si sviluppa orizzontalmente su un asse stradale 2D:

- **Barricata / Cancello Principale (Estrema Sinistra o Destra):** Il punto focale del gameplay d'azione. Ha una barra di integrità (HP barricata) potenziabile.
- **Alloggi (Residenze):** Determinano il cap della popolazione. Ogni residenza può ospitare un numero fisso di abitanti (es. da 3 a 5).
- **Edifici Commerciali / Produttivi:** Divisi in categorie (Cibo, Retail, Servizi, Sicurezza).
- Funzionamento a tier: ogni edificio supporta fino a 3 lavoratori.
- 1 lavoratore sblocca il prodotto Tier 1 (ciclo breve, profitto rapido).
- 2 lavoratori sbloccano il prodotto Tier 2 (ciclo medio).
- 3 lavoratori sbloccano il prodotto Tier 3 (ciclo lungo, alto rendimento passivo).
- **Meccanica di Produzione:** Richiede l'erogazione di un costo iniziale (Monete o Risorse Grezze), avvia un timer, richiede un tap per "Rifornire gli scaffali" a fine ciclo, e genera entrate passive man mano che i beni vengono venduti.

Gameplay Meccanico: Difesa Attiva e Minacce

### L'Ingresso della Città (The Gate)

La telecamera si sposta regolarmente o tramite notifica visiva verso la barricata. Due tipi di entità si presentano all'esterno:

- **Sopravvissuti Civili:** Camminano disarmati verso la porta. Il giocatore deve toccarli per aprire una finestra di dialogo, visualizzare le loro statistiche e decidere se accettarli (se ci sono posti letto liberi) o respingerli.
- **Zombie (Ondate e Singoli):**
- *Tipi di nemici:* Zombie standard lenti, corridori veloci a bassa vita, bruti corazzati lenti ad alto danno strutturale, e "zombie civili ingannevoli" che cercano di mascherarsi da superstiti.
- *Input di Combattimento:* Tap diretto sul bersaglio per sparare con l'arma del giocatore o meccanica a trascinamento di mira. Il giocatore può cambiare arma (pistola di base infinita, fucili a pompa ad area, fucili da cecchino per colpi critici a distanza).
- *Ricarica e Munizioni:* Le armi avanzate consumano munizioni craftate o hanno cooldown di ricarica che impongono gestione del ritmo.
- *Pattuglie Cittadine:* I residenti armati posizionati come guardie alla barricata forniscono fuoco di supporto automatico.

### Esplorazioni Esterne (Dungeon Run / Scavenging)

Oltre alla difesa statica, implementa una mappa di spedizioni:

- Si selezionano da 1 a 3 cittadini armati da inviare in quartieri abbandonati.
- Mini-game a scorrimento automatico (on-rail shooter) o risoluzione automatica a tempo basata sulla comparazione tra statistiche della squadra e livello di minaccia della zona.
- Ricompense: valuta premium, materiali rari per upgrade, ricette di crafting e munizioni speciali.

Economia e Loop di Monetizzazione

| **Valuta / Risorsa**                  | **Metodo di Acquisizione**                             | **Utilizzo Principale**                                            |
| ------------------------------------- | ------------------------------------------------------ | ------------------------------------------------------------------ |
| **Monete (Soft Currency)**            | Vendita beni nei negozi, abbattimento zombie standard. | Costruzione lotti, acquisto stock base, upgrade barricata.         |
| **Provviste / Supplies**              | Drop zombie, ricompense quest, spedizioni.             | Rifornimento merci avanzate, manutenzione difese.                  |
| **Banconote / Gemme (Hard Currency)** | Level up, achievement rari, acquisto in-app (IAP).     | Salto immediato timer, armi esclusive, espansione istantanea slot. |

Specifiche Tecniche e Pipeline di Sviluppo

### Motore

- **Godot Engine**: Ideali per gestione di sprite atlas, rendering leggero su mobile e interfacce UI complesse.

### Gestione della Scena e Viewport

- **Visuale:** Assonometrica 2D o vista puramente laterale "a sezione" (side-view cutaway).
- **Camera Controller:** Script con pan orizzontale a scorrimento (clampato tra coordinata zero del cancello e l'ultimo edificio costruito) e pinch-to-zoom per passare dalla vista micro (gestione singolo negozio) alla vista macro (panoramica cittadina).

### Sistema di Timer e Stato Offline (Idle Engine)

- Architettura orientata al timestamp locale (con controlli anti-tampering) per calcolare la produzione maturata durante la chiusura dell'app.
- Formule di vendita proporzionali al tempo trascorso offline, con un tetto massimo di accumulo (es. magazzini pieni dopo 8 ore).

### Sound & Art Direction

- **Grafica:** Pixel art dettagliata o cartoon stilizzato pulito (vettoriale rasterizzato). Contrasto cromatico netto tra l'ambiente grigio/desaturato post-apocalittico e i colori caldi/vibranti dei negozi illuminati all'interno della safe-zone.
- **Feedback Audio:** Feedback tattile e sonoro pesante sugli spari, suoni distinti per "cassa registratrice" al ritiro incassi, campana di allarme quando gli zombie toccano la barricata.

## Stile grafico nel dettaglio

L'identità visiva di *Niente Zombie Per Favore!* non punta all'orrore viscerale o al realismo cupo, ma al **cartoon stilizzato 2D**, pulito, ironico e modulare (vettoriale rasterizzato o sprite ad alta risoluzione senza contorni neri pesanti, usando invece tonalità scure del colore base per definire i bordi).

La palette cromatica opera per netto contrasto:

- **Esterno/Mondo Selvaggio:** Toni desaturati, grigio asfalto, marroni ruggine, cieli plumbei o crepuscoli velati di fumo.
- **Interno dell'Insediamento/Negozi:** Luci calde, tinte pastello sature, insegne al neon vibranti e colori vivaci che trasmettono un senso di rifugio sicuro, ordine e prosperità.

## 1. Design e Anatomia dei Personaggi (Sopravvissuti)

I personaggi hanno proporzioni "super-deformed" o semi-chibi:

- **Proporzioni:** Circa 3 - 3.5 "teste" di altezza complessiva. Testa larga, ovale o squadrata con angoli smussati; busto compatto; gambe corte e leggermente arcuate; piedi e mani stilizzati (senza dita separate, mani a manopola/mitten).
- **Volto e Tratti:** Occhi neri a bottone o con puntino bianco di riflesso; espressioni facciali minimaliste (sorriso sereno se occupati o felici, linea neutra se disoccupati, sopracciglia aggrottate quando combattono).
- **Sistema Modulare a Strati (Paperdoll):** Per consentire la generazione procedurale, il modello deve essere suddiviso in sprite impilabili:
  1. Base corpo (tonalità pelle: chiaro, medio, scuro, zombie pallido/verdastro).
  2. Occhi/Bocca (espressione).
  3. Capelli/Barba/Copricapo (pettinature da ufficio, creste punk, caschi da cantiere, cappelli da chef, bandane).
  4. Top/Vestito (camicie, grembiuli da barista, giacche di pelle, armature improvvisate con cartelli stradali).
  5. Gambe/Pantaloni (jeans strappati, pantaloni eleganti, tute mimetiche).
  6. Accessori/Arma primaria impugnata (tenuta a due mani o a una mano lungo il fianco).
- **Animazioni (Rigging 2D Skeletal o Frame-by-Frame essenziale):**
  - *Idle:* Respiro leggero (squash & stretch verticale continuo dell'1-2%), battito di palpebre occasionale.
  - *Walk:* Camminata saltellante e rapida (bobbing su e giù).
  - *Work:* Animazioni contestuali al bancone (pulire con uno straccio, battere a macchina, mescolare un pentolone).
  - *Combat:* Flinch quando colpiti, puntamento orizzontale dell'arma con rinculo secco all'indietro.

## 2. Design dei Mob (Zombie ed Entità Esterne)

Gli zombie riprendono le stesse proporzioni dei civili per mantenere coerenza e permettere il trucco visivo dei "falsi sopravvissuti", ma con marcati elementi di alterazione:

### Categorie Visive dei Nemici

- **Walker Standard:**
  - Pelle grigio-bluastra o verde oliva marcio.
  - Abiti strappati e logori (ex-lavoratori, tute da ufficio sfilacciate).
  - Postura curva, testa inclinata lateralmente, braccia penzolanti o protese in avanti, deambulazione trascinata e zoppicante.
- **Runner / Berserker:**
  - Silhouette più snella o rannicchiata in avanti.
  - Spesso a torso nudo o in abbigliamento sportivo logoro, occhi rossi/gialli incandescenti.
  - Corsa veloce con falcate larghe, animazione nervosa e scattosa.
- **Bruto / Tank:**
  - Dimensioni doppie rispetto ai civili (4-5 teste, torso massiccio e spallacci improvvisati).
  - Armature ricavate da barili di metallo, pneumatici o portiere d'auto legate con catene.
  - Camminata pesante che genera un leggero screen-shake visivo ad ogni passo.
- **Infiltrati (Fake Survivors):**
  - Identici ai sopravvissuti amichevoli nel vestiario e nell'aspetto frontale a prima vista, ma con dettagli rivelatori: una macchia di sangue sulla schiena, un occhio velato, un ticchettio anomalo nella camminata o bava verdastra/grigia all'angolo della bocca.

## 3. Stile Architettonico degli Edifici

La struttura della città adotta la logica visiva a **spaccato laterale (cutaway side-view)**: gli edifici sono aperti sul lato dello schermo per mostrare cosa accade all'interno, come una casa delle bambole.

### Facciate Esterne e Struttura

- **Piano Terra e Strade:** Asfalto crepato con strisce pedonali sbiadite, marciapiedi di cemento grigio, erbacce e rampicanti che spuntano tra le crepe. Lampioni artigianali collegati da cavi aerei penzolanti.
- **Edifici Sovrapponibili / Adiacenti:**
  - Architettura ibrida: strutture pre-apocalittiche in mattoni, cemento e metallo, riparate con assi di legno, lamiere ondulate e sacchi di sabbia.
  - Tetti con antenne radio artigianali, pannelli solari arrangiati, serbatoi dell'acqua in legno e torrette di guardia con riflettori.
- **Insegne:** Ogni negozio deve avere un'insegna esterna sporgente in metallo, legno o neon rétro, con icone chiare e grafiche del tipo di prodotto venduto (es. tazza fumante per il bar, t-shirt per il negozio di abiti).

### Spaccato Interno (I Negozi)

Ogni lotto commerciale ha una griglia interna standardizzata (lunghezza e altezza fisse per consentire l'allineamento orizzontale/verticale):

- **Sfondo Parete:** Texture a tema (piastrelle bianche da macelleria, carta da parati vintage, scaffali di libreria in legno scuro, pareti metalliche industriali).
- **Punto di Vendita (Centerpiece):** Un bancone centrale dove si posiziona il cassiere/commesso capo, con registratore di cassa vintage o monitor CRT verde.
- **Postazioni Lavoratori (Fino a 3 slot):**
  - Slot 1 (a sinistra del bancone): es. fornetto / macchina del caffè.
  - Slot 2 (dietro il bancone): postazione cassa / servizio.
  - Slot 3 (a destra del bancone): scaffale delle merci esposte / magazzino a vista.
- **Indicatori Visivi di Stato:**
  - *Vuoto/Esaurito:* Scaffali spogli, luci interne spente o fioche, cartello "Sold Out" o icona a forma di scatola vuota fluttuante.
  - *In Lavorazione:* Lavoratori animati, scatole sul pavimento, carrello merci.
  - *Pieno/Attivo:* Scaffali carichi di pacchi colorati, cesti di frutta, bottiglie; illuminazione brillante, clienti che entrano, toccano la merce e lasciano monete d'oro fluttuanti.

### Le Mura e la Barricata Principale (The Gate)

- **Tier 1 (Base):** Recinzione a catena rinforzata con assi di legno incrociate, filo spinato improvvisato in cima e bidoni di metallo.
- **Tier 2 (Medio):** Palizzata di tronchi o lamiere spesse, porta carrabile in ferro battuto, torretta rialzata con sacchi di sabbia per un cecchino.
- **Tier 3 (Avanzato):** Blocchi di cemento armato (jersey barriere), porta blindata con spuntoni, fari alogeni ad alta intensità, torretta automatizzata o postazione per mitragliatrice pesante calibro .50 montata su treppiede.

## 4. Visual Design di Armi ed Equipaggiamenti

Le armi devono essere leggibili istantaneamente anche a risoluzioni ridotte su schermo mobile:

- **Stile:** Proporzioni leggermente ingigantite (armi "chunky") rispetto al corpo dei personaggi, con sagome nette e angoli ben definiti.
- **Pistole e Revolver:** Corpo canna corta grigio ferro, impugnatura in legno marrone scuro, vampa di fuoco (muzzle flash) circolare gialla brillante a ogni colpo.
- **Fucili a Pompa (Shotguns):** Canna lunga e spessa, calciolo in legno classico, caricamento a pompa animato con bossolo rosso espulso ad arco verso l'alto; cono di sparo ad ampia rosa visibile per pochi frame.
- **Fucili d'Assalto / SMG:** Sagome squadrate tipo Uzi o AK-47 con caricatori a banana o tamburo; raffica di 3 colpi con traccianti luminosi arancioni.
- **Armi da Cecchino (Sniper):** Canna molto lunga con mirino ottico sproporzionato; scia di fumo bianco/azzurro orizzontale tesa che attraversa lo schermo all'impatto.
- **Armi Improvvisate / Esotiche:** Balestre in metallo con frecce piumate, lanciarazzi artigianali ricavati da tubi idraulici, bottiglie Molotov con straccio infuocato gocciolante.

## 5. UI, HUD e Linguaggio Iconografico

L'interfaccia utente deve completare lo stile "sopravvivenza organizzata":

- **Texture Finestre UI:** Riquadri grigio scuro opaco o cartelle portadocumenti in cartone avana logoro, con clip metalliche, scotch adesivo grigio ai bordi e angoli leggermente usurati.
- **Tipografia:** Caratteri bold, compatti e sans-serif per valori numerici e statistiche; titoli di sezione e nomi dei negozi con font stencil militari o in stile macchina da scrivere vintage.
- **Iconografia Risorse:**
  - *Monete d'oro:* Tonde, dorate, con incisione centrale a forma di cranio o "Z" stilizzata.
  - *Supplies (Rifornimenti):* Cassa di legno militare con maniglie in corda o scatola verde con croce bianca/gialla.
  - *Hard Currency (Banconote):* Mazzette di dollari verdi legate da una fascetta di carta bancaria.
- **Icone di Stato e Notifiche:** Balloon a fumetto arrotondati che spuntano sulla testa dei negozi o del cancello (es. punto esclamativo rosso per attacco imminente, moneta rotante per incasso pronto, scatola aperta verde per rifornimento completato).

## Creazione degli Sprites

gli sprites e tutto cio’ che ti serve a livello grafico generalo tu generando le immagini per una qualità piu alta rispetto a scriverli a codice. ovviamente devi pensare anche a tutte le varianti degli sprites e alle animazioni. fai un BEL LAVORO!!!!
