# Niente Zombie Per Favore! — aggiornamento 0.3.0

## Ritocco grafico 0.3.0.1

Le quattro armi e le scorte di munizioni usano ora cinque illustrazioni dipinte
generate con imagegen integrato, al posto delle sagome procedurali. Metallo,
legno e cassetta salvia riprendono gli altri asset del gioco. Le icone sono
usate nell'armeria, nella scelta dell'equipaggiamento e nell'elenco cittadini,
con trasparenza, proporzioni conservate e filtro per le piccole dimensioni.
File originali e prompt sono documentati in
[WEAPON_ICON_PROMPTS.md](WEAPON_ICON_PROMPTS.md).

## Novità della 0.3.0

Il rifugio ora nasce davvero da zero. Con **Nuova partita** trovi il terreno
vuoto e il militare sulla torretta: una guida ti accompagna nel primo sparo,
nella costruzione della casa, nell'accoglienza, nell'apertura del caffè e nel
primo ciclo di produzione e vendita. Il tutorial si può ridurre o saltare;
salva il proprio avanzamento e protegge le risorse necessarie per iniziare.

**Per provare il nuovo inizio e il tutorial occorre scegliere Nuova partita.**
I salvataggi precedenti in versione 2 restano supportati: Continua conserva
il rifugio esistente e non avvia il tutorial. La conferma di Nuova partita
sostituisce il progresso salvato.

## Esplorazione e personaggi

- L'icona zombie porta alla postazione del militare con un movimento fluido
  della camera. L'arrivo resta segnalato dall'icona, senza annunci invadenti.
- Zombie e nuovi sopravvissuti entrano camminando da fuori dell'area visibile.
  Chi viene rifiutato continua ad allontanarsi a piedi.
- I sopravvissuti fuori dalle mura vengono lasciati in pace dagli zombie;
  non subiscono attacchi e possono proseguire lungo la strada.
- I nomi sono divisi per genere in base all'aspetto del personaggio. Anche i
  nomi incoerenti dei vecchi salvataggi vengono corretti, conservando il
  cognome e l'identità grafica.

## Difesa e armi

- Le ondate hanno quantità e composizioni casuali: da 2 a 8 zombie, con
  walker, runner e bruti meno comuni. La forza dei singoli zombie non cresce
  con il numero dell'ondata.
- Fra la fine di un'ondata e la successiva passano circa 2 minuti e 20 secondi
  fino a 3 minuti e 50 secondi. Il riposo comincia dopo l'eliminazione degli
  ultimi zombie.
- La pistola base infligge il doppio dei danni e conserva le munizioni
  infinite: basta un colpo contro un walker normale.
- Aggiunto il **Mitragliatore**: 38 danni, un colpo ogni 0,12 secondi,
  acquistabile per 980 monete e 35 provviste. Tenendo premuto su uno zombie
  continua a sparare e consuma le munizioni condivise.
- Pompa, precisione e mitragliatore hanno suoni meccanici sincronizzati con
  l'attesa fra i colpi. Il mitragliatore usa un ciclo breve del meccanismo.
- Il militare della torretta rimane al suo posto e spara al comando del
  giocatore. I cittadini si dedicano a lavoro e spedizioni: rimossa
  l'assegnazione «Di guardia al cancello».
- Rimosso il cerchio di mira attorno allo zombie selezionato.

## Suoni e interfaccia

- Disattivate le voci dei sopravvissuti, compresi i saluti nei dialoghi.
- Sostituiti i versi zombie con nove registrazioni scaricate dalle raccolte
  degli autori e pubblicate con licenza **CC0**, utilizzabili anche nella
  distribuzione commerciale del gioco. Sorgenti, licenze ed elaborazioni sono
  documentate in [CHARACTER_VOICES.md](CHARACTER_VOICES.md) e
  [AUDIO_LICENSES.md](AUDIO_LICENSES.md).
- Ogni scheda edificio ha un pulsante **?** in alto a destra che ne spiega
  funzione e utilizzo.
- Menu di pausa riorganizzato con spazi più compatti e azioni più chiare.
- Equipaggiamento dei cittadini in una scheda dedicata; armi e munizioni
  nell'armeria accompagnate da icone riconoscibili.
- I dialoghi conservano la posizione di scorrimento quando un'azione aggiorna
  la stessa scheda, evitando il ritorno automatico in cima.
- Rimosse le scritte sovrapposte nell'angolo inferiore sinistro della scena.

## Verifica della simulazione

Superati 750 controlli della nuova simulazione e 30 controlli sulla varietà
dei sopravvissuti. Una sessione di due ore simulate arriva al giorno 41 con
35 ondate, 153 uccisioni manuali e 120 spedizioni, mantenendo validi risorse,
salute, munizioni, produzione e scorte. La verifica della varietà genera
600 nomi simultanei unici e utilizza tutte le 12 identità grafiche.

La build Windows 0.3.0.0 ha superato altri 212 controlli sulle risorse
incorporate: tutorial completo tramite UI, scena, difesa, dialoghi, audio e
assenza dei vecchi campioni vocali dei sopravvissuti. Risultati e log in
[VERIFICHE.md](VERIFICHE.md).
