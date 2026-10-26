# Android fino a 120 Hz — 0.4.1.42

Il gioco richiede fino a **120 Hz su Android**, dal caricamento ai menu e al villaggio. In **Impostazioni → Schermo → Fluidità fino a 120 Hz** puoi scegliere **Sì** (fino a 120 Hz) oppure **No** (60 Hz, minori consumi). La scelta è salvata nelle preferenze del dispositivo e rimane quando inizi una nuova partita. Installazioni e preferenze precedenti partono con l'opzione attiva.

Il supporto è disponibile su telefoni e tablet Android compatibili. La frequenza effettiva dipende da schermo, prestazioni, impostazioni del dispositivo, temperatura e risparmio energetico: il gioco esprime una preferenza e lascia ad Android il controllo del pannello. Non garantisce 120 fotogrammi al secondo su ogni dispositivo. Il comportamento video di Windows e il formato dei salvataggi restano invariati.

## Implementazione

- `display_performance.gd`, avviato dopo le preferenze, gestisce esclusivamente Android reale. Imposta un limite di rendering di 120 o 60 fps con VSync attivo, senza cambiare la frequenza della fisica o la velocità del gioco.
- `android_frame_rate.gd` usa `AndroidRuntime` e `JavaClassWrapper`, già inclusi nei template Godot 4.5.1. La richiesta riguarda la `Surface` effettivamente usata dal renderer, ottenuta da `Activity → Godot → RenderView → SurfaceHolder`.
- Da Android 11 / API 30 chiama `Surface.setFrameRate` con compatibilità `DEFAULT`. Da API 31 usa esplicitamente `CHANGE_FRAME_RATE_ONLY_IF_SEAMLESS`, evitando cambi di risoluzione o richieste di cambio modalità con schermo nero.
- Sulle API precedenti seleziona fra le modalità dichiarate dal dispositivo quella più veloce entro il limite scelto e con la risoluzione attuale; aggiorna i campi pubblici di `WindowManager.LayoutParams` tramite reflection pubblica. Mantiene la risoluzione anche sui pannelli con più modalità.
- Le operazioni Android avvengono sul thread UI nativo; il risultato torna al thread Godot tramite chiamata differita. Una `Surface` non ancora pronta viene ritentata per un massimo di quattro volte dopo il primo tentativo. Eccezioni, assenza del runtime e diniego della richiesta non causano un ciclo continuo.
- La richiesta viene riapplicata dopo ritorno in primo piano, ripresa e ridimensionamento. Le risposte e i tentativi appartenenti a una richiesta superata sono ignorati. Non vengono modificati permessi, impostazioni di sistema o politiche energetiche.

Riferimenti primari: [Frame Rate API Android](https://developer.android.com/media/optimize/performance/frame-rate), [Surface](https://developer.android.com/reference/android/view/Surface), [WindowManager.LayoutParams](https://developer.android.com/reference/android/view/WindowManager.LayoutParams), [integrazione Android di Godot 4.5](https://docs.godotengine.org/en/4.5/tutorials/platform/android/javaclasswrapper_and_androidruntimeplugin.html).

## Verifiche

`tests/test_display_performance.gd` esercita il codice di produzione con oggetti sostitutivi del ponte JNI: overload API 30 e 31+, compatibilità e strategia seamless, modalità 60/90/119,88/144 Hz, filtro della risoluzione, Surface assente/non valida, eccezioni, preferenze precedenti e persistenti, lifecycle e tentativi limitati. Confronta anche il movimento effettivo di zombie e visitatori, il tempo di gioco e il recupero dell'arma a parità di due secondi simulati a 60/90/120 fps.

La nuova opzione viene inoltre toccata attraverso input effettivo nei test dell'interfaccia, su telefoni 16:9/20:9 e tablet, alle tre scale UI; sul computer non compare.

| Verifica sul sorgente | Controlli | Fallimenti |
| --- | ---: | ---: |
| Gestione display, ponte JNI simulato, preferenze, lifecycle e tempi di gioco | 71 | 0 |
| Interfaccia OpenGL, quattro profili e tre scale, con acquisizioni | 4.006 | 0 |
| Gesti e trascinamento del mondo | 135 | 0 |
| Gameplay cozy e persistenza | 144 | 0 |
| Animazioni dei dialoghi e preferenze | 65 | 0 |

Il pacchetto Windows esportato supera inoltre **71 controlli del display**, **4.006 dell'interfaccia con OpenGL** e **96 delle risorse incorporate**. L'APK supera **54 controlli**, inclusa la presenza dei due moduli compilati per il refresh. Nessun fallimento.

Rilascio **0.4.1.42 / Android 401042** completato in `builds/releases/0.4.1.42/`, con setup Windows e APK. Verificati i checksum dei tre artefatti, metadati, allineamento e firma Android v2/v3 con lo stesso certificato delle versioni precedenti. L'eseguibile dei collegamenti Windows è aggiornato; la copia precedente è in `.runtime/NienteZombie-prima-120hz.exe`. I log sono nella cartella `logs` del rilascio.

Le prove native Android sono simulate sul computer: non è stato misurato il refresh su un Pixel fisico. Il collaudo sul dispositivo deve includere opzione di fluidità del sistema attiva, confronto 120/60, ritorno dal background e risparmio energetico. L'indicatore Android della frequenza del display misura gli Hz del pannello, non gli fps effettivamente renderizzati dal gioco.
