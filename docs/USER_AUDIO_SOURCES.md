# Registrazioni fornite dal proprietario del progetto

Le sei registrazioni nella cartella `suoni/` sono state aggiunte dal proprietario del progetto, che le ha dichiarate di libera distribuzione e ne ha chiesto l'integrazione nel gioco. Gli originali sono conservati senza modifiche. Non è stata attribuita loro una licenza CC0 o un'autorialità non documentata: i file non contengono nomi degli autori, indirizzi di provenienza o identificatori di licenza. I soli metadati di codifica presenti sono conservati nel manifest.

Le precedenti fonti CC0 del gioco rimangono documentate separatamente in `AUDIO_LICENSES.md`. Questa integrazione usa le registrazioni fornite, senza scaricare altri suoni.

| Originale | Asset utilizzato | Preparazione |
|---|---|---|
| `pistola.mp3` | `shot_pistol.wav` | Colpo singolo, rimosse soltanto le pause ai bordi. |
| `fucile a pompa.mp3` | `shot_shotgun.wav` | Colpo singolo con riverbero originale e coda conservata. |
| `fucile di precisione.mp3` | `shot_sniper.wav` | Colpo singolo con coda; eliminato il silenzio finale inutilizzato. |
| `mitragliatore.mp3` | `shot_smg.wav` | Un ciclo di 80 ms dalla raffica registrata: un colpo del gioco produce un colpo udibile. |
| `ricarica arma.mp3` | `reload.wav`, `reload_shotgun.wav`, `reload_sniper.wav`, `reload_smg.wav` | Sequenza completa archiviata e cue meccanici adatti alle attese delle singole armi. |
| `zombie.mp3` | `zombie.ogg` | Intera performance di circa 93 secondi, riprodotta in ordine e alla velocità originale; rimossi soltanto circa 3,3 secondi di silenzio digitale alla fine. |

Gli effetti sono in `assets/audio/user/`, separati dagli originali. I colpi e le ricariche sono WAV PCM mono a 44,1 kHz, riprodotti soltanto in corrispondenza degli eventi del gioco. La raffica del mitragliatore continua solo durante il fuoco del giocatore.

Lo zombie è uno stream Ogg Vorbis con il loop interno disattivato: il gioco sovrappone con una dissolvenza di 2,5 secondi la fine di una lettura e l'inizio della successiva. Questo riduce la percezione della ripartenza. Le singole vocalizzazioni non sono state divise in campioni, cambiate di tono o rimescolate.

La decodifica di alcuni originali MP3 produce picchi superiori al fondo scala. La preparazione lavora in virgola mobile, applica il guadagno prima della conversione a PCM e controlla anche il risultato decodificato dell'Ogg. I bordi degli effetti hanno brevi dissolvenze per evitare clic; il volume delle ricariche è inferiore a quello degli spari.

`assets/audio/user/manifest.json` contiene gli SHA-256 degli originali e degli asset, i metadati ffprobe, formati, durate, picchi, livelli RMS e le ricette di conversione. La preparazione è riproducibile con:

```text
python tools/prepare_user_audio.py
python -m unittest discover -s tests -p test_user_audio_assets.py -v
```

Servono Python, NumPy, FFmpeg e ffprobe. Il processo legge gli originali nella cartella `suoni/` e scrive esclusivamente gli asset derivati nella cartella dedicata.
