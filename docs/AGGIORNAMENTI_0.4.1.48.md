# Aggiornamenti dal gioco e rifinitura grafica — 0.4.1.48

## Aggiornamenti dal gioco

All'avvio il gioco interroga l'ultima release pubblicata su GitHub
(`carellice/niente-zombie-per-favore`). Il menu principale mostra una scheda con la versione installata:

- **Windows**: se la release è più recente compare **Aggiorna**. Il setup viene scaricato in
  `%APPDATA%/Godot/app_userdata/Niente Zombie Per Favore!/updates/`, verificato (dimensione e SHA-256
  pubblicato da GitHub), poi avviato in modalità silenziosa. La partita viene salvata, il gioco si chiude
  e il setup lo riapre aggiornato.
- **Android**: compare **Scarica**. L'APK si apre nel browser; al termine del download toccalo per
  installarlo sopra la versione attuale. Alla prima volta Android chiede di consentire l'installazione
  dal browser. L'APK è firmato sempre con la stessa chiave, quindi i salvataggi restano.

Senza connessione la scheda indica che gli aggiornamenti non sono verificabili e offre **Riprova**; il
gioco resta completo offline. Test, editor e anteprime con argomenti da riga di comando non usano la rete.
L'APK richiede ora il permesso Internet, usato solo per questo controllo.

### Pubblicare una nuova versione

1. Esegui **CREA SETUP E APK.bat**.
2. Crea la release con tag `v<versione>` e allega setup e APK da `builds/releases/<versione>/`:

```powershell
gh release create v0.4.1.48 "builds/releases/0.4.1.48/Niente-Zombie-Per-Favore-Setup-0.4.1.48.exe" "builds/releases/0.4.1.48/Niente-Zombie-Per-Favore-0.4.1.48.apk" --title "0.4.1.48"
```

Il gioco sceglie l'asset che contiene `-Setup-` su Windows e quello `.apk` su Android.

## Rifinitura grafica

- Il cielo del villaggio usa una sfumatura morbida al posto della banda scura netta sotto la barra
  superiore; una seconda sfumatura appoggia la barra inferiore sulla strada.
- Su PC i dialoghi hanno uno sfondo a vetro smerigliato: il villaggio resta visibile ma sfocato.
  Su smartphone le pagine coprono già tutto lo schermo e non cambiano.
- Menu principale: panorama con lento movimento (disattivato da **Riduci animazioni**) e sfumature in
  alto e in basso che danno profondità e leggibilità al titolo.
