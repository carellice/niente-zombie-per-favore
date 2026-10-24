# Avvio del gioco e icona Android

La schermata predefinita del motore è sostituita dall'immagine del gioco, su sfondo verde petrolio. Il progetto entra poi in `loading.tscn`: logo, titolo, barra e percentuale accompagnano la preparazione del rifugio prima del menu.

Le risorse grafiche vengono caricate in background, fino a tre richieste contemporanee; l'avanzamento deriva dalle richieste effettivamente completate. La scena e l'audio vengono inizializzati sul thread principale, mentre la schermata resta davanti. Il 100% compare dopo che il menu è pronto; una breve dissolvenza rivela il gioco. Non viene aggiunta un'attesa minima artificiale. Durante l'avvio la simulazione è in pausa e la partita caricata non viene modificata.

## Asset dell'icona

- Foreground adattivo: `assets/android/icon_foreground.png`, **1254 × 1254**, trasparente, generato con il tool **imagegen integrato**, poi copiato nel progetto senza modificarne i pixel. Il file originale di questa generazione è `exec-0202fb72-bc57-4f21-86ea-02c8ae4e32e6.png`.
- Background adattivo: `assets/android/icon_background.svg`, superficie uniforme `#173735`, esportata da Godot nelle densità Android.
- Riferimento: `assets/icon.png`. L'icona originale rimane in uso per Windows e per l'icona Android classica.
- Anteprima con maschera circolare: `docs/ICONA-ANDROID-PIXEL.png`. È un rendering di verifica, non un asset modificato del launcher.

Il foreground ha ampi margini trasparenti. Considerando tutti i pixel con opacità superiore al 2%, la distanza massima dal centro è **0,2841 volte il lato del canvas**, inferiore al limite conservativo del cerchio centrale **66/108/2 = 0,3056**. Anche la cornice completa rientra nel cerchio; non serve affidarsi al ritaglio degli angoli da parte del launcher.

## Prompt finale — imagegen integrato

```text
Precise layout edit only. Preserve the entire existing game icon in Image 1 unchanged: same full cream rounded-square frame, green zombie, red stop hand and wooden rail. Place the COMPLETE icon SMALL at the EXACT CENTER of a much larger fully TRANSPARENT square canvas. Aim for the icon to occupy only 40 percent of the total canvas width and height, never more than 42 percent. This means at least 29 percent empty transparent margin at left, right, top and bottom. Example proportions for a 1024 pixel canvas: emblem about 410 by 410 pixels, centered at 512,512, edges near 307 and 717. The full outside cream border must be visible and all artwork must be well inside a centered circle of diameter 60 percent of the full canvas. The transparent empty margin is the MOST important part of this Android Pixel adaptive icon export. Do NOT crop or zoom the icon. Do NOT add an outer circular container, backgrounds, text, checkerboard or extra shadows. Actual alpha transparency outside the entire intact scaled icon. Preserve the supplied art style and composition.
```

La generazione segue il riferimento senza garantire un'identità pixel per pixel; la validazione dell'area utile usa i pixel reali dell'output, non le sole proporzioni richieste nel prompt.

## Verifiche

Il test `tests/test_loading_screen.gd` esercita il caricamento reale, il passaggio unico al menu, la progressione, la pausa della simulazione, la presenza del PNG nativo e i margini dell'icona. Sono disponibili anche le anteprime `CARICAMENTO-1920x1080.png`, `CARICAMENTO-2400x1080.png` e `CARICAMENTO-2048x1536.png`, con notch e margine di sistema simulati.

`tests/test_android_launcher.gd` legge direttamente l'APK e verifica foreground, sfondo e ritaglio circolare nelle cinque densità, oltre alla presenza della schermata di caricamento e del PNG usato prima dell'avvio del motore. Firma, allineamento e versioni vengono controllati dalla procedura di rilascio.

Le anteprime sono renderizzate su desktop; non sono schermate acquisite da un Pixel reale.

Rilascio completato: **0.4.1.19 / Android 401019**. Sul pacchetto Windows esportato, avvio e passaggio al menu hanno superato **20 controlli**, senza risorse del progetto sfuse. Le risorse generali del gioco hanno superato gli **87 controlli** esistenti. L'APK finale ha superato **33 controlli** su bitmap, aree sicure, sfondi adattivi e PNG nativo. Firma, allineamento, versione e checksum sono validi; la firma Android è quella dei rilasci precedenti. Aggiornato anche l'eseguibile usato dai collegamenti Windows, con backup in `.runtime/NienteZombie-prima-caricamento.exe`.

Riferimenti ufficiali: [icone adattive Android](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive), [caricamento in background Godot 4.5](https://docs.godotengine.org/en/4.5/tutorials/io/background_loading.html), [impostazioni della schermata iniziale](https://docs.godotengine.org/en/4.5/classes/class_projectsettings.html#class-projectsettings-property-application-boot-splash-image).
