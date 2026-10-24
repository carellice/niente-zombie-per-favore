# Creare setup Windows e APK Android

Fai doppio clic su **CREA SETUP E APK.bat**, nella cartella principale del progetto. Lo script incrementa la versione comune e genera insieme il setup Windows e l'APK Android firmato. Non servono argomenti. La finestra mostra le fasi e resta aperta alla fine per leggere il risultato.

I file da distribuire si trovano in `builds/releases/<versione>/`. Le build precedenti vengono conservate in cartelle separate.

## Requisiti e preparazione automatica

- Windows con **Windows PowerShell 5.1**; viene usato il Godot **4.5.1** già incluso in `tools/godot/`.
- Un **JDK 17 o superiore** completo, con `java`, `javac`, `keytool` e `jarsigner`. Lo script cerca `JAVA_HOME`, `tools/jdk/`, il `PATH` e le installazioni Java più comuni. Se manca, installa [OpenJDK 17](https://adoptium.net/temurin/releases/?version=17) oppure estrailo in `tools/jdk/`, quindi rilancia il BAT.
- Connessione Internet al primo avvio per i componenti mancanti. Download e strumenti vengono riutilizzati nelle build successive.

Il bootstrap riutilizza un SDK Android già completo oppure prepara `tools/android-sdk/` con i tre pacchetti necessari a questa esportazione: **Platform Tools**, **Build Tools 35.0.0** e **Android Platform 35**. Il percorso automatico installa soltanto dentro il progetto; un SDK esterno viene riutilizzato senza modificarlo. L'avvio della build esegue il bootstrap con accettazione delle [licenze Android SDK](https://developer.android.com/studio/terms) richieste da questi pacchetti.

Il preset Android usa l'esportazione APK standard con template Godot precompilati e Gradle disattivato. Questo flusso non compila Godot o estensioni native e non richiede Android Studio, Gradle, NDK o CMake. I template Android 4.5.1 mancanti vengono recuperati dall'archivio ufficiale con verifica degli hash.

Il compilatore **Inno Setup 6.7.3** viene preparato in `tools/inno-6.7.3/` dalla release ufficiale, verificando SHA-256. La sua modalità portatile non crea associazioni, collegamenti o registrazioni globali. Il setup del gioco installa per il singolo utente, offre un collegamento desktop facoltativo e include il disinstallatore; i salvataggi Windows rimangono conservati durante aggiornamento e disinstallazione.

## Versione automatica

`VERSION.json` è la fonte comune per le due piattaforme:

```json
{
  "version": "0.4.1.4",
  "android_version_code": 401004
}
```

I numeri qui sopra sono un esempio del formato. A ogni build reale lo script aumenta l'ultima delle quattro parti: per esempio `0.4.1.4` diventa `0.4.1.5`. Ogni parte Windows arriva fino a `65535`, poi scatta il riporto: `0.4.1.65535` diventa `0.4.2.0`. La stessa versione viene scritta nel progetto Godot, nell'eseguibile Windows, nel setup e nel `versionName` Android.

Il `versionCode` Android aumenta separatamente di uno e deve rimanere entro `2100000000`. Non viene ricavato concatenando le quattro parti: così resta crescente anche quando cambia la struttura del numero visibile.

Il numero viene **riservato prima di preparare gli strumenti e produrre gli artefatti**. Se la build fallisce dopo la prenotazione, quel numero resta consumato: il tentativo successivo ne usa uno nuovo. Le cartelle di rilascio esistenti non vengono sovrascritte. Un lock esclusivo rifiuta avvii contemporanei; il processo respinto non riserva una versione.

## Controllo senza creare una build

Da un prompt aperto nella cartella del progetto:

```bat
"CREA SETUP E APK.bat" -CheckOnly
```

Controlla la presenza del Godot previsto e la validità della versione corrente/prossima. **Non incrementa la versione, non scarica strumenti e non genera file di distribuzione.** Non è una verifica completa di SDK, firma Android o giocabilità mobile.

Per automazioni e CI, disabilita la pausa finale con la variabile `NZPF_BUILD_NO_PAUSE`:

```bat
set NZPF_BUILD_NO_PAUSE=1
call "CREA SETUP E APK.bat"
```

Il BAT restituisce codice `0` solo se la procedura termina correttamente; in caso di errore restituisce un codice diverso da zero. Lo script PowerShell sottostante è `tools/build_release.ps1`.

## File prodotti e controlli

Ogni cartella `builds/releases/<versione>/` contiene:

| Percorso | Contenuto |
| --- | --- |
| `windows/Niente Zombie Per Favore.exe` | Eseguibile Windows e documenti/licenze associati nella stessa cartella. |
| `Niente-Zombie-Per-Favore-Setup-<versione>.exe` | Setup Windows installabile. |
| `Niente-Zombie-Per-Favore-<versione>.apk` | APK Android release firmato. |
| `logs/` | Log delle singole fasi e diagnostica in caso di errore. |
| `release.json` | Versione, codice Android, stato del tentativo e riepilogo degli artefatti. |
| `SHA256SUMS.txt` | Checksum SHA-256 di setup, APK ed eseguibile. |

Prima di dichiarare il rilascio completo, lo script verifica le versioni dei file Windows, la firma e l'allineamento dell'APK, il nome del pacchetto Android e i suoi numeri di versione. `release.json` distingue i tentativi in corso, riusciti o falliti. `builds/releases/latest.json` viene aggiornato **soltanto al completamento** e identifica la versione completa più recente; un errore successivo non sostituisce questo riferimento con una build incompleta.

I log di bootstrap Android sono in `.runtime/android-bootstrap/`. Se una build si interrompe, conserva i log della sua cartella e rilancia il BAT dopo aver risolto la causa: non serve cancellare la versione fallita.

## Firma Android e aggiornamenti

Al primo avvio reale vengono creati:

```text
.release-private/
  android-release.keystore
  android-signing.json
```

La password è casuale e viene passata ai programmi attraverso variabili di ambiente, senza stamparla nei log. `android-signing.json` contiene le credenziali necessarie alla build. **Conserva un backup privato dell'intera cartella `.release-private/` e riutilizzala nelle build future**: la stessa firma permette di aggiornare l'APK già installato. Se manca uno solo dei due file, lo script si ferma invece di sostituire automaticamente la chiave.

La cartella è esclusa da Git e dagli export Godot. Non distribuirla insieme a setup, APK o sorgenti condivisi. Spostando la build su un altro computer, ripristina entrambi i file dal backup prima di generare aggiornamenti.

L'APK usa il pacchetto stabile `org.rifugio07.nientezombieperfavore`, include **ARMv7 e ARM64** e usa il renderer **GL Compatibility**. Il target minimo del template è **Android 7 / API 24**; la toolchain usa Android SDK API 35. L'output è un APK firmato per installazione diretta: questo script non pubblica sugli store e non genera AAB. Layout, touch e prestazioni su telefoni reali restano da collaudare come descritto in [MOBILE.md](MOBILE.md).

## Impostazioni isolate e fonti

La build copia i binari Godot in `.runtime/release-godot/`, attiva la modalità portatile con `_sc_` e usa `editor_data/editor_settings-4.5.tres` per i percorsi Java/Android. In questo solo profilo disattiva il salvataggio tramite rinomina di Godot, che interferisce con la scrittura ripetuta dell'APK temporaneo su Windows; gli artefatti completati vengono poi verificati. Anche `APPDATA` viene isolata e `TEMP`/`TMP` puntano a `.runtime/release-temp/` per il processo di build. Le impostazioni dell'editor interattivo e le variabili d'ambiente permanenti del computer non vengono cambiate.

Riferimenti ufficiali: [export Android Godot 4.5](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_android.html), [comandi di esportazione Godot](https://docs.godotengine.org/en/4.5/tutorials/editor/command_line_tutorial.html), [gestione pacchetti Android SDK](https://developer.android.com/tools/sdkmanager), [versionamento Android](https://developer.android.com/studio/publish/versioning), [modalità portatile di Inno Setup](https://jrsoftware.org/ishelp/topic_technotes.htm).
