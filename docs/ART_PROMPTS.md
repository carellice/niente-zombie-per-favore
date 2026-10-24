# Asset grafici — Niente Zombie Per Favore!

Tutti gli asset sono stati generati con il tool integrato `image_gen.imagegen` (modalità built-in), senza fallback CLI. I PNG originali sono stati copiati nel progetto senza modificare i pixel. Il runtime usa regioni UV per separarli.

## File e layout

| File | Dimensioni | Formato | Uso |
|---|---|---|---|
| `assets/art/settlement.png` | 1536 × 1024 | RGBA, sfondo trasparente | 3 colonne × 2 righe, celle 512 × 512: residenza, caffè, serra; officina, clinica, cancello. Pavimento intorno a y=480 nella cella. |
| `assets/art/characters.png` | 1536 × 1024 | RGBA, sfondo trasparente | 8 colonne × 4 pose: contadina, barista, meccanica, dottoressa, guardia, walker, runner, bruto. |
| `assets/art/background.png` | 1774 × 887 | RGB | Panorama crepuscolare senza elementi di gioco in primo piano. |
| `assets/art/ui_icons.png` | 1280 × 1280 | RGBA | 16 icone dipinte in griglia 4 × 4 per un HUD morbido e giocattoloso. |
| `assets/art/cherries.png` | 1280 × 1280 | RGBA, trasparente | Piccola ciliegia accanto al nome di Chiara; [prompt](CHERRIES_PROMPT.md). |
| `assets/art/weapons/pistol.png`, `shotgun.png`, `smg.png` | 1536 × 1024 ciascuno | RGBA | Armi dipinte isolate: pistola, pompa e mitragliatore. |
| `assets/art/weapons/sniper.png` | 1774 × 887 | RGBA | Fucile di precisione dipinto, con mirino ingrandito per la lettura alle piccole dimensioni. |
| `assets/art/weapons/ammo.png` | 1254 × 1254 | RGBA | Cassetta verde salvia con cartucce dorate. |
| `assets/art/checkpoint.png` | 1024 × 1536 | RGBA | Cancello alto, basamento continuo e piattaforma aperta per le guardie. |
| `assets/art/road-painted.png` | 2172 × 724 | RGB | Strada dipinta: asfalto, cordoli, crepe, muschio e riflessi. |
| `assets/art/walk-civilians.png` | 1536 × 1024 | RGBA | Quattro civili con sei fasi di passo ciascuno. |
| `assets/art/walk-zombies.png` | 1536 × 1024 | RGBA | Walker, runner e bruto con sei fasi di passo ciascuno. |
| `assets/icon.png` | 1280 × 1280 | RGBA | Nuova icona: zombie fermato dal simbolo di stop, usata da Windows, menu e HUD. |

Il generatore ha prodotto baseline e colonne dei personaggi irregolari. Il runtime usa rettangoli UV manuali per ciascuna delle 32 pose, ricavati dalle componenti alfa, per allineare i piedi ed evitare pezzi dei personaggi adiacenti. I PNG originali rimangono intatti.

Gli angoli 0,0 dei due atlas sono stati verificati trasparenti (alpha0). Le immagini sono state ispezionate visivamente. Non è stato eseguito editing con Python.

Il prompt completo del secondo passaggio grafico dedicato all'HUD giocattoloso è in [UI_ICON_PROMPT.md](UI_ICON_PROMPT.md). Anche questo atlas è stato generato con il tool integrato, poi ritagliato soltanto attraverso regioni UV in gioco.

La revisione 0.4.0 aggiunge un'icona popolazione (`assets/art/population.png`), undici icone merce in `assets/art/products/`, tre facciate in `assets/art/buildings/` e quattro varianti dipinte degli atlanti civili (`characters-dirty.png`, `characters-infected.png`, `survivors-expanded-dirty.png`, `survivors-expanded-infected.png`). Tutti sono PNG originali imagegen con alpha, copiati senza modificare i pixel. Gli atlanti conservano 1536×1024 e le UV del rig; i nuovi elementi UI usano mipmap isolate. Prompt completi in [SUSPICION_POPULATION_PROMPTS.md](SUSPICION_POPULATION_PROMPTS.md), [BUILDINGS_V04_PROMPTS.md](BUILDINGS_V04_PROMPTS.md), [PRODUCT_ICONS_V04_A.md](PRODUCT_ICONS_V04_A.md) e [PRODUCT_ICONS_V04_B.md](PRODUCT_ICONS_V04_B.md).

La revisione 0.3.0.1 sostituisce le sagome procedurali delle armi con cinque PNG generati separatamente tramite imagegen integrato. I file originali sono conservati senza modifiche; il runtime centra il canvas trasparente, genera mipmap per ciascuna icona e ne mantiene le proporzioni. Prompt finali in [WEAPON_ICON_PROMPTS.md](WEAPON_ICON_PROMPTS.md).

L'icona della revisione 0.2.3 è stata creata con imagegen integrato usando il walker originale come riferimento di stile. Il [prompt completo](ICON_PROMPT.md) e il PNG finale sono inclusi nel progetto. `docs/ICONA-WINDOWS.png` è una lettura dell'icona realmente incorporata nell'eseguibile esportato.

Il nuovo confine del rifugio usa un asset dedicato generato con imagegen integrato, documentato in [CHECKPOINT_PROMPT.md](CHECKPOINT_PROMPT.md). Il runtime sovrappone i personaggi sulla pedana e riapplica la regione UV dei sacchi di sabbia davanti alle loro gambe, per mantenere una profondità coerente. Le guardie sono rivolte a sinistra verso l'esterno; il tiro è sincronizzato al segnale `guard_fired` della simulazione.

La revisione del 22 ottobre aggiunge la [strada dipinta](ROAD_PROMPT.md) e i [cicli di camminata](WALK_PROMPTS.md). Tutti questi PNG provengono dal tool imagegen integrato. La guardia spara solo su comando manuale; `guard_fired` ora segue `shoot()` e non un timer automatico.

## Prompt originali

### Edifici

```text
Use case: stylized-concept. Asset type: production 2D game building sprite atlas, PNG with genuine transparent background, canvas 1536x1024. Exactly 3 columns and 2 rows, six equal 512x512 cells, no visible grid. Each cell contains ONE isolated full building, carefully centered within its own cell with 24px empty transparent padding on all sides, all soles/floors aligned at y=480 inside each cell. Orthographic flat side-view cutaway dollhouse, never isometric, no ground plane, no background, no people. Row1 left: cozy patched two-story teal residence with little balconies and rooftop water tank; row1 middle: lovely cream cafe with coral striped awning, warm coffee machine and counter, small sign reading CAFFE; row1 right: sage-green greenhouse with vegetable beds, pumpkin, glass roof. Row2 left: ochre-yellow workshop, tools on wall, shelves and service counter, solar roof; row2 middle: mint clinic with large simple white medical cross, beds and cabinet, roof antenna; row2 right: ramshackle fortified gate with timber and metal panel, small elevated guard tower, sandbags and spotlight. Premium hand-painted cartoon mobile management game art, clean modular silhouette with dark colored outlines, attractive crafted details, warm glowing amber interiors, teal/coral/sage/cream palette, whimsical and inviting post-apocalypse. Keep each asset entirely in its cell, no objects between cells, no shadows crossing cell borders. No UI, no labels except cafe sign, no watermark.
```

### Personaggi

```text
Use case: stylized-concept. Asset type: production 2D game animation character sprite atlas with genuinely TRANSPARENT background. Canvas 1536x1024, precisely 8 columns and 4 rows, 32 separate sprites in equal 192x256 cells, no drawn grid. Each column is ONE consistent character, each row is a different animation pose of same character. Row1 idle facing right three-quarter profile; row2 left foot forward walk right; row3 right foot forward walk right; row4 action firing or flinch. Every full character entirely fits in its own cell with at least20px transparent gap all sides, feet baseline238 local y, similar scale except brute larger. Columns left to right:1 female farmer brown skin teal beanie burnt-orange shirt;2 male cafe barista moustache cream apron and brown trousers;3 dark-skinned woman mechanic navy overalls yellow scarf;4 female doctor pale skin white coat teal trousers;5 male guard green helmet orange vest holding chunky gray rifle;6 olive-green zombie walker torn brown jacket outstretched arms;7 blue-gray skinny runner zombie in tattered red sports jacket;8 huge rotund barrel-armored zombie brute. Style: high-quality clean whimsical hand-painted cartoon game asset, 3-head-high chibi proportions, large simple oval heads, minimal dark button eyes, short chunky legs and shoes, readable small silhouettes, softly colored dark outlines. Muted teal, coral, sage and warm beige palette, friendly cozy postapocalypse, not gore or horror. All views strict side-view suitable horizontal 2D game, no perspective ground. No shadows across cells, no text, no labels, no background, no decorative objects outside the sprites, no watermark.
```

### Fondale

```text
Use case: stylized-concept. Asset type: polished parallax background for a side-scrolling 2D cozy post-apocalyptic town survival management videogame. Wide horizontal panorama 2048x1024 pixels. A pale dusty rosy-peach evening sky taking upper45 percent with billowing soft long clouds, tiny birds, warmly glowing low sunset. Far distance hazy blue-sage rounded mountains, muted abandoned city skyline with squat rooftops, water towers, thin antennae, a few broken smokestacks, subtle barely-visible rust and plants. Middle distance subdued desaturated sage and gray industrial ruins as a continuous low silhouette only, height around 50percent. Lower40percent is a broad EMPTY side-view flat muted gray-green asphalt roadway continuing across all image, with a few tiny fine cracks and tiny weeds at distant verge. Leave all foreground road space empty for game buildings and characters to be composited. Premium hand-painted clean cartoon illustration with delicate textured edges, muted cinematic colors, attractive atmospheric depth, inviting hopeful whimsical cozy apocalypse. Soft atmospheric lighting, low contrast behind foreground. Strict orthographic flat side-view horizon, no vanishing-point road, no isometric view, no people, no zombies, no foreground standalone buildings, no UI, no letters, no text, no watermark.
```


