# Ambiente zombie e voci dei personaggi

## Riproduzione attiva dalla versione 0.4.1

I sopravvissuti restano silenziosi. Non vengono riprodotti vocalizzi ambientali, saluti nelle schede di ammissione o altre voci umane. I vecchi campioni dei sopravvissuti rimangono materiale di sviluppo escluso dall'esportazione.

Gli zombie utilizzano ora **l'intera registrazione fornita in `suoni/zombie.mp3`**, dichiarata di libera distribuzione dal creatore del progetto. Non sono stati forniti o incorporati nel file autori, URL o un identificatore di licenza: la nuova registrazione non viene attribuita agli autori delle vecchie raccolte e non è etichettata CC0.

Il derivato `assets/audio/user/zombie.ogg` dura **92,725 secondi**. Conserva in ordine tutte le vocalizzazioni della registrazione originale di circa 96 secondi; sono stati eliminati soltanto circa 3,3 secondi di silenzio digitale alla fine. Velocità e intonazione sono invariate. Sono applicati conversione mono, guadagno prima della quantizzazione e brevi dissolvenze ai bordi, senza scomporre il file in campioni.

`scripts/zombie_soundscape.gd` usa due lettori con loop interno disattivato. Durante gli ultimi **2,5 secondi**, la coda del primo lettore sfuma mentre entra l'inizio del secondo; i guadagni seguono una curva a potenza costante. In questo modo la ripartenza non produce uno stacco netto e la pausa finale dell'originale non si ripete.

La riproduzione dipende dagli zombie vivi visibili e si attenua durante gli spari. Il passaggio alla città, il menu e il mute sfumano il sottofondo conservando la posizione; tornando alla difesa, l'audio prosegue da quel punto. La pausa congela i lettori e l'eventuale sfumatura in corso. Le preferenze di volume generale ed effetti vengono rispettate. Aprire un dialogo non avvia né riavvia una voce.

Provenienza e ricette sono in [USER_AUDIO_SOURCES.md](USER_AUDIO_SOURCES.md). `assets/audio/user/manifest.json` conserva SHA-256 degli originali e dei derivati, metadati ffprobe, durate e livelli. Per preparare nuovamente gli asset: `python tools/prepare_user_audio.py`.

## Archivio delle precedenti registrazioni CC0

Il precedente banco di nove WAV locali non è più usato dal mondo di gioco. Rimane un archivio storico: tre versi per i walker, tre per i runner e tre per i brute, in PCM mono 16 bit a 44,1 kHz. Le fonti seguenti riguardano soltanto quel materiale.

- [Undead Moans, AntumDeluge](https://opengameart.org/content/undead-moans):
  la pagina originale indica CC0 e identifica l'autore come interprete.
  Archivio [undead-moans.zip](https://opengameart.org/sites/default/files/undead-moans.zip);
  campioni usati: `undead-1.ogg`, `undead-2.ogg`, `undead-4.ogg`.
- [Zombie / Skeleton / Monster Voice Effects, ArcadeParty](https://opengameart.org/content/zombie-skeleton-monster-voice-effects):
  pagina dell'autore con licenza CC0.
  [Archivio originale](https://opengameart.org/sites/default/files/Voice%20Effects%20Zombie-Skeleton-Monster%20Human%20Male.zip);
  campioni usati: `zombieYell3.wav`, `5`, `7` per i runner e `4`, `8`, `10` per i brute.
  Nessuna voce umana del pacchetto viene usata.

Le pagine e i file sono stati verificati e scaricati il 23 ottobre 2026.
La [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) consente copia,
modifica e distribuzione, anche commerciale, senza richiesta di attribuzione.
Manteniamo comunque autori, collegamenti e licenza nell'archivio del progetto.
Il testo CC0 originale incluso da AntumDeluge è in
`assets/audio/voices/LICENSE-CC0.txt`.

## Preparazione e verifica dell'archivio storico

`tools/prepare_audio_revision.py` applica un filtro leggero, piccoli adattamenti
di intonazione/tempo per le diverse corporature, compressione moderata,
rimozione della componente continua, dissolvenze e normalizzazione a −5,04 dBFS.
Le registrazioni restano riconoscibili come versi recitati, senza oscillatori
usati al posto di una voce. Durate: walker 1,41–1,95 s; runner 0,34–0,44 s;
brute 0,36–0,49 s.

`assets/audio/voices/manifest.json` contiene sorgente, licenza, elaborazione,
durata, livelli e hash SHA-256 dei nove file storici.
`assets/audio/revision-sources.json` contiene URL e SHA-256 dei download originali.
L'anteprima storica è `docs/ZOMBIE-CC0-ANTEPRIMA.wav`, che non rappresenta il sottofondo attuale.

Il precedente banco `character_voices.gd` restituisce soltanto zombie: l'API compatibile
`civilian()` restituisce `null`, e `civilian_count()` restituisce zero.
Il relativo scheduler storico crea un solo lettore, sceglie soltanto zombie vivi visibili,
evita la ripetizione consecutiva e mantiene intervalli di 6–11 secondi.
Pausa, menu, volume, mute e precedenza degli spari vengono rispettati.
`on_panel_changed()` non avvia alcun saluto. Queste API rimangono nel sorgente
per compatibilità e verifiche dell'archivio: `main.gd` usa `ZombieSoundscape`
senza eseguire anche il precedente scheduler.
