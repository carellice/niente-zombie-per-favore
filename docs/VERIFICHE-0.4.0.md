# Verifiche della revisione 0.4.0

Aggiornamento del 23 ottobre 2026. Questa pagina riguarda la revisione
0.4.0, con versione Windows **0.4.0.0**. Le prove usano Godot
4.5.1 e salvataggi temporanei separati dal rifugio del giocatore.
[VERIFICHE.md](VERIFICHE.md) resta il registro storico della 0.3.0.

## Simulazione sul progetto sorgente

| Suite | Controlli superati | Copertura |
| --- | ---: | --- |
| `tests/test_content_defense_v04.gd` | 655 | Soglie delle quattro gittate; rifiuto dei colpi troppo lontani senza consumo, danno o effetti; ripiego alla pistola senza ereditare la gittata della precisione; blocco in pausa; 180 gruppi casuali con maggioranza di classici e varianti garantite; avviso finale senza numerazione; frequenza e velocità; otto edifici, ventuno prodotti, produzioni e vendite reali; nove destinazioni con costi individuali; trentadue obiettivi con id unici; cure; premi una sola volta; migrazione da otto obiettivi senza reset; aspetti condivisi e persistenti fra mondo, scheda, ammissione e partenza |
| `tests/test_revision_simulation.gd` | 751 | Ripartenza vuota, tutorial con primo zombie da attendere entro portata, ripresa dal salvataggio, persone al sicuro all'esterno, ingressi e partenze a piedi, posizione degli infiltrati rivelati, nomi coerenti con il genere, compatibilità dei salvataggi, danni e ricariche delle quattro armi, composizione casuale senza crescita esponenziale, riposo dopo il completamento e due ore di economia e difesa |

Entrambe le suite sono terminate con **zero fallimenti**. Log:

- `tests/content-defense-v04.log`
- `tests/sim-v04-regression.log`

La sessione di due ore simulate ha raggiunto il **giorno 41**, con
**48 gruppi di zombie**, **251 eliminazioni** e **120 spedizioni**.
Risorse, salute, munizioni, produzione e scorte sono rimaste valide.
Il contatore interno `wave` viene usato per salvataggi e diagnostica;
questi numeri non corrispondono a una numerazione mostrata al giocatore.

## Criteri della revisione

Il riposo deve iniziare soltanto dopo l'ultimo nemico e la fine della coda
degli ingressi. Un tiro fuori portata non può anticipare il cooldown,
consumare munizioni né emettere sparo, tracciante o ricarica. Il mitragliatore
deve rispettare gli stessi vincoli durante la pressione prolungata.

Le nuove attività devono produrre merci vendibili, usare il talento
corrispondente e applicare il bonus del lavoro ideale una sola volta.
Spedizioni e obiettivi devono avanzare tramite azioni reali. I vecchi
salvataggi devono conservare scorte, risorse, edifici e premi già riscossi;
caricare più volte una migrazione non deve aggiungere premi o progressi.

Gli aspetti pulito, sporco e sospetto devono restare coerenti fra strada e
ritratto e dopo il salvataggio. Lo sporco deve comparire anche sui sani.
Un infiltrato rivelato deve conservare look e posizione, senza teletrasporto.

## Interfaccia, grafica e build Windows

I PNG originali dei quattro atlanti condizionali mantengono la dimensione
1536×1024. Le dodici identità hanno varianti pulite, sporche e sospette;
ritratto e mondo usano la stessa sorgente. Gambe, scarpe e coordinate del rig
mantengono le texture originali per proteggere il ciclo alternato.
Le tre facciate sono allineate al terreno. Popolazione, undici icone prodotto
e facciate hanno mipmap d'importazione; i controlli di esportazione le
verificano anche all'interno dell'eseguibile.

Verifiche sul sorgente: 151 controlli delle condizioni e 156 con catture
native, 158 sulle identità e 510 sulla cinematica della camminata, tutti
superati. La UI è stata controllata a 1440×900 e 960×600 e con contatori
molto grandi; i pulsanti rimangono raggiungibili. Le immagini `V04-*.png`
mostrano i dialoghi e l'HUD; `SOPRAVVISSUTI-INDIZI-v04.png` confronta le tre
condizioni, `NUOVI-EDIFICI-v04.png` le facciate.

L'export Windows è terminato senza errori o warning, con versione file e
prodotto **0.4.0.0**, log `tests/export-0400.log`. L'eseguibile finale è
`builds/Niente Zombie Per Favore.exe`. Le seguenti suite sono state lanciate
direttamente da quell'eseguibile, con directory di lavoro `builds` e profili
temporanei isolati. Il controllo del pacchetto conferma `project.binary`
e l'assenza del motore sorgente nel percorso delle risorse.

| Suite sull'eseguibile | Controlli superati | Log |
| --- | ---: | --- |
| Integrità di risorse, immagini, mipmap e cataloghi | 67 | `tests/packed-0400-package.log` |
| Scena principale, camera e armi con portata | 28 | `tests/packed-0400-main.log` |
| HUD, prodotti, diario, dialoghi e dimensioni estreme | 141 | `tests/packed-0400-ui.log` |
| Audio reale, ricariche e feedback dei clic | 28 | `tests/packed-0400-audio.log` |
| Tutorial completo tramite interfaccia e clic | 82 | `tests/packed-0400-tutorial.log` |
| Identità, condizioni, rig e nuove facciate | 156 | `tests/packed-0400-visuals.log` |

**502 controlli superati, zero fallimenti e nessun errore nei log.** Le
catture della scena, dei tre edifici, delle condizioni e del tutorial sono
state rigenerate dall'eseguibile distribuito.

## Contorno luminoso — build 0.4.0.1

Una piccola viewport trasparente ricompone la stessa sagoma animata del
personaggio; il passaggio luminoso viene disegnato prima del corpo e del
cancello. Segue camminata, colpi e orientamento, conservando le occlusioni.
Le maschere sono riutilizzate solo per minacce visibili entro portata e
rimosse dopo morte, uscita dall'inquadratura o ritorno al menu.

Il contorno segnala la distanza dell'arma effettiva, compreso il ripiego
alla pistola quando le munizioni sono esaurite. Il cooldown non lo spegne.
Non viene applicato ai cittadini o ai superstiti in attesa.
Tutorial e armeria spiegano il significato della luce dorata.

La suite dedicata ha superato 43 controlli headless e 49 nativi. Il confronto
GPU sulla stessa scena congelata rileva zero pixel modificati attorno allo
zombie lontano e più di 35 per ciascuno dei tre tipi vicini. Verificate le
soglie delle quattro armi, cambio arma, munizioni zero, cooldown, pausa,
menu, infiltrati rivelati, pose e rimozione delle maschere. Un controllo sul
vero `_process()` conferma che corpo e contorno tornano insieme dalla posa
colpita a quella di camminata.

Export riuscito senza errori o warning: versione file/prodotto **0.4.0.1**,
log `tests/export-0401.log`. Verifiche dirette sull'eseguibile finale dalla
cartella `builds`, con profili isolati:

| Suite sull'eseguibile | Controlli superati | Log |
| --- | ---: | --- |
| Pacchetto e risorse | 67 | `tests/packed-0401-package.log` |
| Contorno, gittate e confronto GPU | 49 | `tests/packed-0401-outline.log` |
| Scena principale e armi | 25 | `tests/packed-0401-main.log` |
| Tutorial completo | 81 | `tests/packed-0401-tutorial.log` |

**222 controlli superati, zero fallimenti.** `docs/CONTORNO-PORTATA.png`
è una cattura dell'eseguibile aggiornato.

## Apertura dei dialoghi — build 0.4.0.2

Animazione centralizzata di 0,26 secondi: dissolvenza di finestra e sfondo,
scala morbida e piccolo scorrimento verso l'alto. Un aggiornamento della
stessa scheda conserva il progresso del Tween e lo scroll. Cambiare finestra
riavvia solo la sua comparsa, mantenendo continuo lo sfondo oscurato.
Il Tween agisce sul controller vivo, con riferimenti aggiornati alle finestre:
nessun callback continua a modificare nodi ormai eliminati. Il pivot segue
il ridimensionamento della finestra. La logica dei pulsanti e della pausa
rimane immediata.

Il test dedicato verifica stati intermedi, durata, monotonia, assestamento,
continuità del fondale, acquisto reale di munizioni, scroll, cambio edificio,
menu, impostazioni, pausa, sostituzioni rapide e ridimensionamento durante
l'apertura. Le tre immagini `DIALOGO-APERTURA-INIZIO.png`, `-META.png` e
`-FINE.png` mostrano campioni della transizione nella scena reale.

Export senza errori o warning: versione file/prodotto **0.4.0.2**, log
`tests/export-0402.log`. Prove sull'eseguibile finale dalla cartella `builds`
con profili isolati:

| Suite sull'eseguibile | Controlli superati | Log |
| --- | ---: | --- |
| Pacchetto e risorse | 67 | `tests/packed-0402-package.log` |
| Animazioni e continuità dei dialoghi, con catture GPU | 64 | `tests/packed-0402-dialogs.log` |
| Azioni UI, scroll, equipaggiamento, aiuti e menu | 63 | `tests/packed-0402-ui.log` |
| Tutorial completo | 81 | `tests/packed-0402-tutorial.log` |

**275 controlli superati, zero fallimenti e nessun errore nei log.** Le tre
anteprime della transizione sono state rigenerate dall'eseguibile distribuito.
