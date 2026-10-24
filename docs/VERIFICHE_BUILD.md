# Verifiche della pipeline Windows e Android

Verifiche eseguite il 23 ottobre 2026 su Windows, usando il comando reale `CREA SETUP E APK.bat` e Windows PowerShell 5.1.

- Due build complete consecutive terminate con codice 0: **0.4.1.12 / Android 401012** e **0.4.1.13 / Android 401013**. Entrambe hanno prodotto setup Windows, eseguibile autonomo e APK release firmato.
- Versione comune aggiornata in `VERSION.json`, `project.godot`, preset Windows/Android, risorse PE di gioco/setup e metadati APK. L'APK finale dichiara pacchetto `org.rifugio07.nientezombieperfavore`, min SDK 24 e target SDK 35.
- Firma APK verificata con `apksigner`: schemi v2 e v3 validi. Certificato SHA-256 identico nei due rilasci: `d28f4beccf59c0e40977de7db1e12c7a48e2463dc6824f8b5c7347f1638c8f3f`.
- Allineamento ZIP/APK controllato con `zipalign -c -P 16 -v 4` in entrambe le build.
- APK finale: letti integralmente tutti i **302 membri ZIP**, CRC corretti e nessun nome duplicato; librerie ELF ARM64/ARMv7 verificate e **96 riferimenti import/remap** risolti. Presenti le risorse aggiornate; assenti strumenti di sviluppo, chiavi private, credenziali e MP3 originali della cartella `suoni`.
- I tre checksum della build finale sono stati ricalcolati indipendentemente e corrispondono a `release.json` e `SHA256SUMS.txt`.
- `latest.json` è rimasto alla 0.4.1.12 durante la build successiva ed è passato alla 0.4.1.13 solo dopo il completamento.
- Un secondo avvio del BAT durante una build è stato respinto con codice 1, senza modificare `VERSION.json`. Dopo il completamento, `-CheckOnly` ha restituito codice 0, indicando correttamente la prossima 0.4.1.14 / 401014 senza incrementarla.
- `tests/test_release_tools.ps1`: **50 controlli superati su Windows PowerShell 5.1**, comprendenti riporti e limiti delle versioni, aggiornamento delle sezioni Godot, scrittura UTF-8 atomica e lock esclusivo.
- `tests/test_revision_package.gd`, eseguito contro il pacchetto incorporato nell'eseguibile Windows finale da una cartella priva dei sorgenti: **87 controlli, 0 errori**. Verificate risorse grafiche, font, animazioni, audio e contenuti del gioco distribuiti.
- Setup Inno compilato e versionato correttamente. Una variante di collaudo dello stesso script, con sola registrazione del disinstallatore disattivata e installazione dentro `.runtime`, ha superato installazione e disinstallazione reali: codici 0, hash dell'eseguibile identico, licenze incluse, nessun collegamento esterno e dati utente di prova conservati. Le build di rilascio mantengono la normale registrazione del disinstallatore.

I log del rilascio finale sono in `builds/releases/0.4.1.13/logs/`. I tentativi precedenti restano disponibili per diagnostica e i loro numeri non vengono riutilizzati.

Queste verifiche attestano la generazione e l'integrità dei pacchetti. Non è stato eseguito un collaudo su dispositivo Android o emulatore; touch, layout, prestazioni e ciclo di sospensione/ripresa richiedono ancora le prove descritte in [MOBILE.md](MOBILE.md).
