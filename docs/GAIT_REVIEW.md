# Revisione della camminata

Versione 0.2.2.

## Problema iniziale degli atlanti

Il confronto diretto di `docs/CAMMINATE.png`, dei due atlanti delle camminate e di `scripts/actor_visuals.gd` mostra che le pose 1/4, 2/5 e 3/6 ripetono sostanzialmente la stessa gamba in primo piano. La posa di passaggio alza sempre lo stesso ginocchio. Sei immagini differenti non equivalgono quindi a un ciclo completo delle due gambe: il difetto è nel contenuto delle pose, non nel numero di frame o nella sola frequenza.

La normalizzazione alla testa e al piede più basso elimina alcuni scatti, ma non può assegnare alle gambe i rispettivi ruoli di appoggio e oscillazione. Inoltre `main.gd` usa una frequenza globale: il cittadino avanza a 19 unità/s e il visitatore a 32, entrambi a 1,4 cicli/s; walker e bruto usano entrambi 1,1 cicli/s pur avanzando rispettivamente a 18 e 11 unità/s di base. Il movimento dei piedi non può quindi seguire coerentemente il terreno.

## Difetto della prima versione articolata

La prima correzione conservava la separazione orizzontale delle anche dipinte anche nei bersagli dei piedi. Ciascuna gamba oscillava attorno a una linea diversa: una continuava a stare davanti all'altra. Il test precedente sottraeva la posizione media di ciascun piede prima di confrontarli, nascondendo proprio questo difetto. Tale ricentratura è stata rimossa.

La riproduzione con coordinate effettive ha prodotto 44 fallimenti su 231 controlli. Questi erano gli intervalli di `piede_sinistro.x - piede_destro.x`, in unità di altezza del personaggio:

| Personaggio | Minimo prima | Massimo prima | Minimo dopo | Massimo dopo |
| --- | ---: | ---: | ---: | ---: |
| Contadina | -0,2546 | +0,0254 | -0,1700 | +0,1700 |
| Barista | -0,2768 | +0,0032 | -0,1700 | +0,1700 |
| Meccanica | -0,2780 | +0,0020 | -0,1700 | +0,1700 |
| Dottoressa | -0,2946 | -0,0146 | -0,1700 | +0,1700 |
| Walker | -0,2738 | +0,0262 | -0,1800 | +0,1800 |
| Runner | -0,3286 | +0,1114 | -0,2300 | +0,2300 |
| Bruto | -0,4460 | -0,2260 | -0,1500 | +0,1500 |

Dottoressa e bruto non invertivano mai l'ordine dei piedi; il sorpasso di barista e meccanica era praticamente invisibile. Il taglio sul bacino aveva una causa separata: il busto terminava su una riga fissa del PNG, mentre la medesima zona del tessuto sulle gambe era spostata dal rig.

## Soluzione implementata

Il nuovo renderer usa le texture originali dei personaggi e due gambe articolate indipendenti, renderizzate mediante poligoni con UV del PNG originale. Identità, colori e testa rimangono quelli originali. Torso, gamba lontana e gamba vicina sono separati; il torso copre l'attacco delle gambe, specialmente sotto grembiule e camice.

- La fase avanza con `abs(spostamento_x) / lunghezza_falcata`, congelandosi quando il personaggio si ferma.
- Le fasi delle gambe differiscono esattamente di mezzo ciclo.
- Entrambe le suole percorrono la stessa traiettoria longitudinale, davanti e dietro a una proiezione comune del bacino. La separazione delle gambe in profondità non diventa una distanza permanente avanti/dietro. Ogni mezzo ciclo i due piedi si scambiano realmente posizione.
- La fase di appoggio occupa 0,60 del ciclo per i civili, 0,62 per walker/bruto e 0,58 per il runner. Il piede è alla quota del terreno; rispetto al bacino arretra linearmente. L'escursione totale è `lunghezza_falcata * frazione_appoggio`, così la sua velocità relativa compensa quella del personaggio e il piede resta piantato nel mondo.
- Nella fase aerea il piede torna avanti lungo una curva di Hermite con tangenti raccordate all'appoggio e altezza `sin(PI * t)² * altezza_passo`. Nessun riposizionamento istantaneo nel passaggio fra appoggio e oscillazione; la velocità verticale si annulla a decollo e contatto.
- Il bacino mantiene quota fissa; nessun salto del corpo. Una soluzione a due segmenti posiziona ginocchio e caviglia. Il ginocchio flette verso la direzione di avanzamento. La suola rimane orizzontale.
- La falcata è 0,34 volte l'altezza renderizzata per i civili, 0,36 per walker, 0,46 per runner e 0,30 per bruto. Le lunghezze delle due ossa sono rispettivamente 0,121, 0,127, 0,142 e 0,075 volte l'altezza, mantenendo tutti i bersagli raggiungibili.
- Alla fermata le gambe si raccordano alla posa neutra in 0,125 secondi. La fase non avanza quando l'attore raggiunge la coda o il cancello. Teletrasporti e riassegnazioni non contano come passi.

## Riferimenti UV del PNG originale

Coordinate globali in `assets/art/characters.png`, riga idle. Intervalli verificati leggendo il canale alpha, soglia 40/255; sono riferimenti per tracciare i poligoni, non rettangoli pronti da applicare a entrambe le gambe. Le zone superiori condivise richiedono sovrapposizione sotto il torso, evitando di inglobare mani, attrezzi, borse e camice nei poligoni delle gambe.

| Personaggio | Sezione delle gambe | Sezione inferiore | Piedi a y=280 |
| --- | --- | --- | --- |
| Contadina | y=240: x=71–102 / 106–132 | y=260: x=67–92 / 110–133 | x=64–93 / 116–142 |
| Barista | y=250: x=243–272 / 282–307 | y=260: x=240–267 / 282–307 | x=236–264 / 297–316 |
| Meccanica | y=240: x=433–471 / 473–509 | y=260: x=429–461 / 479–504 | x=425–454 / 495–509 |
| Dottoressa | y=250: x=627–656 / 665–691 | y=260: x=623–651 / 666–691 | x=619–645 / 673–697 |
| Walker | y=230: x=975–1002 / 1007–1037 | y=260: x=957–988 / 1011–1039 | x=958–990 / 1015–1056 |
| Runner | y=240: x=1158–1212 / 1217–1234 | y=260: x=1144–1159 / 1216–1228 | x=1134–1171 / 1212–1250 |
| Bruto | y=260: x=1348–1407 / 1443–1488 | y=270: x=1344–1397 / 1443–1495 | x=1343–1400 / 1442–1495 |

## Verifica

I 238 controlli della cinematica campionano 240 fasi per tutti e sette i personaggi. Confrontano le coordinate effettive dei piedi, senza ricentrarle separatamente: entrambi devono superare l'altro, passare davanti e dietro al bacino comune e scambiarsi posizione ogni mezzo ciclo. Sono inoltre verificati l'appoggio mondiale delle suole, la continuità, l'assenza di salti, la raggiungibilità di ogni caviglia e la costanza delle lunghezze ossee con tolleranza di 0,00001 altezze. I 52 controlli di integrazione verificano distanza percorsa, arresto, pausa, zoom e riposizionamenti.

I 64 controlli GPU di `tests/test_gait_render.gd` misurano i pixel delle scarpe realmente renderizzate, comprese texture, alpha e occlusione. Una tinta di sola verifica colora la scarpa sinistra in rosso e quella destra in blu senza alterarne la geometria. Per ogni personaggio vengono catturati gli appoggi a fase 0 e 0,5, poi si calcola il baricentro dei pixel visibili di ciascuna scarpa. La differenza fra i due centri deve cambiare segno con un margine di almeno 0,08 altezze, ed entrambe le scarpe devono passare davanti e dietro alla linea comune del bacino. Ogni scarpa deve conservare almeno venti pixel visibili: un piede occultato non può far passare la verifica.

La verifica visiva usa `tests/render_gait_preview.gd`, con cattura del rendering Godot nativo a 24 fps, personaggi alle dimensioni effettive del gioco e dettaglio a scala 3×. La modalità `--normalized-gait` registra 96 frame: due cicli sincronizzati di due secondi per tutti e sette i personaggi. `--debug-gait` aggiunge anca, ossa e bersagli delle suole: S arancio e D blu. L'offset del bacino è lo stesso usato dal renderer, per poter confrontare i cerchi con le scarpe realmente disegnate. Le quattro fasi 0, 0,25, 0,5 e 0,75 corrispondono ai frame 0, 12, 24 e 36. La modalità predefinita conserva la cattura di dieci secondi alle velocità effettive del gioco. Le tacche a terra evidenziano la stabilità del piede in appoggio.

Le catture finali sono state ripetute dopo la correzione del contorno irregolare della pancia del bruto, insieme ai 64 controlli GPU. Tutti i controlli sono passati. I file di anteprima sono generati esclusivamente da queste catture finali:

| File | Contenuto | Durata | Formato |
| --- | --- | ---: | --- |
| `docs/PASSI.gif` | Due cicli sincronizzati puliti | 4 s | 48 frame, 12 fps, 1024×1012 |
| `docs/CAMMINATA-CONTROLLO.mp4` | Due cicli con marker sinistro/destro | 4 s | 96 frame, 24 fps, 1760×1740 |
| `docs/CAMMINATA.mp4` | Velocità effettive del gioco | 10 s | 240 frame, 24 fps, 1760×1740 |
| `docs/CAMMINATA.gif` | Estratto a velocità effettive | 6 s | 72 frame, 12 fps, 1024×1012 |

## Rig implementato

`scripts/walking_rig.gd` renderizza due mesh UV articolate con le texture originali e stivali separati, poi sovrappone la parte superiore del personaggio. Le sezioni del tessuto rimangono orizzontali attraverso anca, ginocchio e caviglia: ruotare l'intera larghezza di una caviglia chibi intorno a una tibia corta causava poligoni invertiti e punte sotto il terreno. Le bande usano triangoli espliciti con bordi condivisi. Il piede conserva una suola orizzontale e la sua quota corrisponde al punto di appoggio calcolato dalla cinematica.

Il busto e la prima riga delle mesh inferiori condividono esattamente le stesse coordinate sorgente e destinazione. Dodici righe di tessuto raccordano progressivamente il bordo fisso al ginocchio e alla caviglia mobili; spostamento e relativa derivata sono nulli sul bordo condiviso. Anche l'ombreggiatura della gamba lontana inizia dal bianco su tale bordo, evitando una linea orizzontale di tinta. Lo scarto del bacino rispetto al rettangolo alpha viene conservato per tutte le articolazioni: borse e braccia non devono spostare l'attacco delle gambe. Le suole sono centrate sui rispettivi bersagli comuni, evitando che un vecchio offset della scarpa annulli il sorpasso calcolato dalla cinematica.

Il runner richiede una maschera specifica: nel dipinto originale una mano blu pende davanti ai pantaloncini, nello stesso rettangolo della coscia. Il rig legge una striscia pulita di pantaloncino e polpaccio per quella gamba e mantiene entrambe le mani fisse mediante regioni UV separate. Nessun PNG viene modificato o generato per questa correzione.

Il bruto conserva il contorno originale irregolare della pancia in una maschera statica. Il tessuto marrone delle gambe si deforma al di sotto, senza trascinare i pixel della pelle in strisce sottili sopra le scarpe.
