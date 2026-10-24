# Audio del gioco

## Clic dell'interfaccia dalla versione 0.4.1.1 — CC0

`assets/audio/ui_click.wav` è il nuovo clic breve e morbido per gli elementi
dell'interfaccia. Combina `click2.ogg` del **UI SFX Set** di **Kenney Vleugels**
con una piccola componente di `impactSoft_medium_000.ogg` di **Kenney Impact Sounds**.
Entrambe le raccolte locali includono una licenza **Creative Commons Zero**,
che consente anche modifica e distribuzione commerciale. Le licenze originali
sono conservate in `assets/audio/LICENSE-Kenney-UI.txt` e
`assets/audio/LICENSE-Kenney-Impact.txt`.

Il clic dura 110 ms, è mono PCM 16 bit a 44,1 kHz e ha picco −12 dBFS e
RMS −23,73 dBFS. Filtri dolci, lieve riduzione d'intonazione, compressione
del transiente e dissolvenze ai bordi lo rendono caldo e leggibile senza
un segnale acuto, eco o coda metallica. Il vecchio `ui_tap.wav` è conservato
come asset storico. `tools/prepare_ui_click.py` rigenera il nuovo file a
partire dalla cache locale senza scaricare nulla e aggiorna esclusivamente
la sua voce in `assets/audio/manifest.json`, che registra anche gli hash
dei due originali. I suoni forniti nella cartella `suoni/` non sono modificati.

## Registrazioni attive dalla versione 0.4.1

Gli spari, i meccanismi delle armi e il sottofondo degli zombie utilizzano le sei registrazioni aggiunte dal creatore del progetto nella cartella `suoni/`, dichiarate da lui di libera distribuzione. Gli originali sono conservati senza modifiche.

Non sono stati forniti identificatori di licenza, autori o URL di provenienza e tali informazioni non compaiono nei metadati incorporati. Queste registrazioni **non sono etichettate CC0**. La dichiarazione del proprietario, i metadati originali, gli hash e le ricette sono registrati in `assets/audio/user/manifest.json`. Ulteriori dettagli sono in [USER_AUDIO_SOURCES.md](USER_AUDIO_SOURCES.md).

| Evento attivo | Originale fornito | Asset derivato | Durata |
| --- | --- | --- | --- |
| Pistola | `suoni/pistola.mp3` | `assets/audio/user/shot_pistol.wav` | 0,557 s |
| Fucile a pompa | `suoni/fucile a pompa.mp3` | `assets/audio/user/shot_shotgun.wav` | 1,278 s |
| Precisione | `suoni/fucile di precisione.mp3` | `assets/audio/user/shot_sniper.wav` | 1,359 s |
| Mitragliatore | `suoni/mitragliatore.mp3` | `assets/audio/user/shot_smg.wav` | 0,080 s |
| Meccanismo della pompa | `suoni/ricarica arma.mp3` | `assets/audio/user/reload_shotgun.wav` | 0,383 s |
| Meccanismo della precisione | `suoni/ricarica arma.mp3` | `assets/audio/user/reload_sniper.wav` | 0,575 s |
| Ciclo del mitragliatore | `suoni/ricarica arma.mp3` | `assets/audio/user/reload_smg.wav` | 0,065 s |
| Ambiente zombie | `suoni/zombie.mp3` | `assets/audio/user/zombie.ogg` | 92,725 s |

`assets/audio/user/reload.wav` conserva anche la sequenza completa di ricarica, di 1,233 secondi, come asset di riferimento; durante il gioco vengono usati i tre cue brevi della tabella.

I colpi sono sincronizzati con i proiettili realmente sparati. Il file del mitragliatore contieneva una breve raffica: viene usato un singolo ciclo, così ogni proiettile corrisponde a un solo colpo udibile. Le ricariche partono dopo il transiente dello sparo e terminano entro l'attesa della relativa arma; hanno volume inferiore agli spari.

La preparazione decodifica gli MP3 in virgola mobile prima di regolare il guadagno: alcuni originali superano il fondo scala e una conversione intermedia diretta in PCM intero introdurrebbe clipping. I derivati WAV sono mono, PCM 16 bit a 44,1 kHz, con brevi dissolvenze ai bordi.

## Riproduzione degli zombie

`scripts/zombie_soundscape.gd` riproduce l'intera performance di `zombie.ogg` nel suo ordine originale, senza cambiare velocità o intonazione e senza dividerla in versi isolati. Sono stati rimossi soltanto circa 3,3 secondi di silenzio digitale terminale del file originale di 96 secondi.

Due lettori sovrappongono la fine e l'inizio della traccia con una **dissolvenza di 2,5 secondi a potenza costante**. Il loop interno del decoder è disattivato: il passaggio viene gestito dal gioco per rendere meno percepibile la ripartenza.

L'ambiente si sente quando ci sono zombie vivi nella porzione di mondo visibile; l'ingresso e l'uscita hanno una breve sfumatura. Pausa e finestre che mettono in pausa il mondo congelano anche la posizione audio; menu, mute e controlli del volume sono rispettati. Dopo essersi allontanati o aver disattivato l'audio, il ritorno alla difesa riprende dalla posizione conservata. Durante gli spari l'ambiente viene attenuato per lasciare udibile l'arma.

I sopravvissuti restano silenziosi, sia nel mondo sia nei dialoghi. Il precedente scheduler di nove versi zombie non viene usato in partita. Il suo archivio è descritto sotto e in [CHARACTER_VOICES.md](CHARACTER_VOICES.md).

L'interfaccia conserva gli effetti Kenney e il sottofondo musicale originale di 40 secondi, descritti nelle rispettive sezioni.

## Archivio storico degli spari — CC0

Questa sezione documenta i campioni delle versioni precedenti, conservati come materiale storico. **Non sono gli spari attivi della 0.4.1**, che usa i file in `assets/audio/user/` elencati sopra.

**The Free Firearm Sound Library**, creata e registrata da **Ben Jaszczak,
Brian Nelson, Kevin Heras e Matthew Nanney**.

- [Pagina della raccolta e dichiarazione CC0 su OpenGameArt](https://opengameart.org/content/the-free-firearm-sound-library).
- [Archivio originale scaricato: Prepared SFX Library.7z](https://opengameart.org/sites/default/files/Prepared%20SFX%20Library.7z).
- [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/).

La pagina della raccolta identifica autori e licenza CC0; il vecchio sito del
progetto è ormai archiviato. L'archivio conservato su OpenGameArt contiene i WAV
preparati con i metadati originali dell'arma e della posizione di registrazione.
Il credito resta incluso anche se CC0 non lo impone.

| File dell'archivio | Registrazione originale | Arma registrata |
| --- | --- | --- |
| `assets/audio/shot_pistol.wav` | `Prepared SFX Library/1911/A_42P.wav` | Pistola 1911, .45, distanza ravvicinata |
| `assets/audio/shot_shotgun.wav` | `Prepared SFX Library/Model 12/K_17P.wav` | Winchester Model 12, fucile a pompa, calibro 12 |
| `assets/audio/shot_sniper.wav` | `Prepared SFX Library/Mosin Nagant/M_21P.wav` | Mosin Nagant, otturatore manuale, 7.62×54 |
| `assets/audio/shot_smg.wav` | `Prepared SFX Library/Carl Gustav M45/G_20P.wav` | Carl Gustav M45, mitragliatore 9 mm |

Elaborazione: isolamento del primo colpo, partenza allineata al transiente,
conversione mono 44,1 kHz/16 bit, filtro 65 Hz–10,5 kHz, riduzione dell'eco di
coda, rimozione DC, dissolvenza finale e guadagno con margine prima del clipping.
La pistola dura 0,68 s, il pompa 0,95 s e il fucile di precisione 1,15 s.
Non sono onde sinusoidali usate come sostituto dello sparo.
Il mitragliatore usa un singolo colpo di 0,15 s, sincronizzato con ogni proiettile
effettivamente sparato; la coda breve evita l'accumulo di echi durante il fuoco rapido.

## Archivio storico dei meccanismi e delle ricariche — CC0

Anche questi meccanismi sono sostituiti in partita dai derivati della registrazione fornita dal creatore del progetto. La sezione conserva le attribuzioni del materiale precedente.

I campioni sono stati scaricati il 23 ottobre 2026 dalle pagine dei rispettivi
autori, entrambe con indicazione esplicita CC0:

- [Gun reload sounds — SpringySpringo](https://opengameart.org/content/gun-reload-sounds):
  registrazioni di armi airsoft, 
  [shotguncock_0.wav](https://opengameart.org/sites/default/files/shotguncock_0.wav) e
  [assaultriflereload1_0.wav](https://opengameart.org/sites/default/files/assaultriflereload1_0.wav).
- [Gun Reload Sound Effects — Brian MacIntosh / BMacZero](https://opengameart.org/content/gun-reload-sound-effects):
  [singlebullet1.wav](https://opengameart.org/sites/default/files/singlebullet1.wav) e
  [clipload2.wav](https://opengameart.org/sites/default/files/clipload2.wav).

| File dell'archivio | Sorgente ed elaborazione | Durata |
| --- | --- | --- |
| `reload_shotgun.wav` | SpringySpringo, azione della pompa; taglio silenzio, EQ e dissolvenze | 0,384 s |
| `reload_sniper.wav` | BMacZero, inserimento cartuccia e chiusura metallica a 0/360 ms; cresta attenuata, EQ e dissolvenze | 0,600 s |
| `reload_smg.wav` | SpringySpringo, breve ciclo del meccanismo estratto dalla ricarica del fucile automatico | 0,065 s |

Le azioni meccaniche partono dopo il transiente dello sparo e hanno un volume
inferiore. Il mitragliatore usa un ciclo breve tra i colpi; non riproduce l'intero
cambio del caricatore dopo ogni proiettile. Gli autori sono citati volontariamente.
Il testo CC0 è conservato anche in `assets/audio/LICENSE-CC0-Revision.txt`.

## Interfaccia, avvisi e impatti — CC0

Il nuovo `ui_click.wav` usa anche **UI SFX Set** di **Kenney Vleugels (Kenney.nl)**,
con licenza originale in `assets/audio/LICENSE-Kenney-UI.txt`; preparazione e
caratteristiche sono descritte nella nota 0.4.1.1 sopra.

**Impact Sounds (1.0)**, creati e distribuiti da **Kenney**.

- [Pagina ufficiale, con licenza CC0](https://kenney.nl/assets/impact-sounds).
- [Archivio ufficiale scaricato](https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip).
- Licenza originale conservata in `assets/audio/LICENSE-Kenney-Impact.txt`.

| File nel gioco | Campioni Kenney utilizzati |
| --- | --- |
| `ui_click.wav` | UI SFX Set `click2.ogg`, Impact Sounds `impactSoft_medium_000.ogg` |
| `visitor.wav`, `ui_tap.wav` (storico) | `impactWood_light_001.ogg` |
| `cash.wav` | `impactMetal_light_000.ogg` |
| `build.wav` | `impactPlank_medium_000.ogg`, `impactWood_light_001.ogg` |
| `ready.wav` | `impactBell_heavy_000.ogg` |
| `reward.wav` | `impactBell_heavy_000.ogg`, `impactMetal_light_000.ogg` |
| `alarm.wav` | `impactBell_heavy_001.ogg` |
| `breach.wav` | `impactPlank_medium_000.ogg` |
| `impact.wav` | `impactSoft_medium_000.ogg` |
| `reject.wav` | `impactWood_light_003.ogg` |
| `expedition.wav` | `impactSoft_medium_000.ogg`, `impactWood_light_001.ogg` |

I campioni sono tagliati, filtrati e attenuati. Alcuni eventi combinano due
piccoli impatti; campane e avviso sono abbassati di intonazione. Gli impatti
UI hanno picchi tra circa −18 e −10 dBFS, inferiori ai picchi degli spari.

## Ambiente originale

`assets/audio/shelter_ambience.ogg` è una sintesi originale del progetto, senza
registrazioni o musica esterne. Il procedimento completo è in
`tools/prepare_audio.py`: accordo C6/9 morbido, armoniche leggere, piccoli
scostamenti stereo e vento generato da rumore filtrato. Oscillatori e
modulazioni completano cicli interi nei 40 secondi per permettere il loop.
È codificato Vorbis stereo 44,1 kHz e viene riprodotto dal canale musica con
volume separato dagli effetti.

## Archivio storico dei versi e voci dei personaggi

I nove precedenti versi zombie, ora conservati come archivio storico, provengono da
[Undead Moans di AntumDeluge](https://opengameart.org/content/undead-moans) e
[Zombie / Skeleton / Monster Voice Effects di ArcadeParty](https://opengameart.org/content/zombie-skeleton-monster-voice-effects),
entrambi pubblicati dai rispettivi autori con licenza CC0. Sono stati scaricati
e verificati il 23 ottobre 2026. I precedenti versi di artisticdude sono sostituiti.
Le voci dei sopravvissuti sono disabilitate sia nell'ambiente sia nei dialoghi;
i vecchi campioni umani sono esclusi dalla build. In partita viene riprodotta
la nuova traccia `assets/audio/user/zombie.ogg`, senza anche il vecchio scheduler.
Provenienza, elaborazioni e rigenerazione dell'archivio sono in
[CHARACTER_VOICES.md](CHARACTER_VOICES.md) e in
`assets/audio/voices/SOURCES.txt`.

## Rigenerazione e verifica delle registrazioni fornite

Per i nuovi asset: `python tools/prepare_user_audio.py`. Il processo legge esclusivamente i sei MP3 forniti, scrive i derivati dedicati e aggiorna `assets/audio/user/manifest.json`; con la stessa versione di FFmpeg i risultati sono identici anche negli hash del contenitore Ogg.

`tests/test_user_audio_assets.py` controlla integrità degli originali, SHA-256, formati, durate, picchi, attacchi, assenza di clipping, compatibilità delle ricariche con i cooldown e conservazione dell'intera performance zombie. I controlli Godot del banco audio e di `ZombieSoundscape` verificano il mapping degli eventi, la sfumatura e le condizioni di riproduzione.

## Riproducibilità dell'archivio precedente e degli effetti Kenney

`assets/audio/manifest.json` registra sorgente, elaborazione, durata, frequenza
di campionamento, picco, RMS e SHA-256 di ogni asset consegnato.

SHA-256 degli archivi originali verificati:

- `Prepared SFX Library.7z`: `cc1ab5a99a0a365105c7c5dd783f4b0b1fe90938114d3ceec53856bfe005f7d6`
- `kenney_impact-sounds.zip`: `029d734af1582474edf3a694d1b0cebc97c1c152f2f39fa34d4c2bafc5de77f8`

Per rigenerare gli asset precedenti e gli effetti Kenney ancora attivi:

1. Scaricare i due archivi indicati sopra in `.runtime/audio_sources`.
2. Estrarre i tre WAV indicati nella tabella conservando il percorso
   `Prepared SFX Library/...` e gli OGG Kenney in
   `.runtime/audio_sources/kenney_impact/Audio`.
3. Eseguire `python tools/prepare_audio.py` dalla cartella del progetto, con
   NumPy e FFmpeg disponibili.
4. Scaricare i nuovi sorgenti elencati in `assets/audio/revision-sources.json`
   nella cache `.runtime/audio_sources/revision`; estrarre `undead-moans.zip` in
   `undead/` e l'archivio ArcadeParty in `arcadeparty/`. Estrarre inoltre
   `Prepared SFX Library/Carl Gustav M45/G_20P.wav` dall'archivio degli spari.
5. Eseguire `python tools/prepare_audio_revision.py` per ricostruire i precedenti
   versi, mitragliatore e ricariche. Questo passaggio non usa sintesi vocale e
   non sovrascrive i derivati in `assets/audio/user/`.

`assets/audio/revision-sources.json` conserva URL originali e SHA-256 di tutti i
download dell'archivio. Per quei campioni CC0, la licenza e la pagina
dell'autore restano nel relativo manifest. La [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)
consente modifica e distribuzione anche commerciale, senza autorizzazioni aggiuntive.

`tests/test_sound_bank.gd` verifica i nomi degli eventi, gli alias di tutti gli
spari, la separazione tra effetti di arma e click UI, la cache, il silenzio per
eventi sconosciuti e il loop stereo del sottofondo. I controlli offline di
durata, clipping e attacco sono eseguiti da `tests/test_audio_assets.py`.
