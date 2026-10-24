# Feedback del puntatore

`scripts/pointer_feedback.gd` espone un `CanvasLayer` autonomo da aggiungere alla scena principale. Il livello 100 disegna sopra HUD, menu e finestre. Il controllo trasparente usa `MOUSE_FILTER_IGNORE`; `_input` osserva la pressione prima della GUI senza consumare l'evento.

Ogni clic sinistro avvia due cerchi sottili color crema e miele, un piccolo centro luminoso e quattro puntini salvia/oro. L'effetto dura 0,42 secondi e raggiunge circa 24 pixel di raggio a 1440 pixel di larghezza; la scala è limitata per mantenere il feedback discreto. Rimane attivo durante la pausa e nei menu. Un massimo di 16 effetti evita accumuli nei clic rapidi.

Sono già riconosciute le pressioni `InputEventScreenTouch`, ignorando il relativo evento mouse emulato per evitare duplicazioni. Questo riguarda solo il feedback grafico e non aggiunge comandi touch al gioco.

API di integrazione: `const PointerFeedback = preload("res://scripts/pointer_feedback.gd")`, quindi `add_child(PointerFeedback.new())` durante l'inizializzazione della scena. Il segnale `pulse_started(position)` e `effect_count` permettono verifiche del percorso di input. `tests/test_pointer_feedback.gd` verifica clic su un vero pulsante, clic sul mondo, rilascio, scroll, duplicazione touch, pausa, scadenza e limite del pool.

Verifica eseguita: 13 controlli senza errori con il renderer headless; 15 controlli senza errori con OpenGL, aggiungendo `-- --capture-feedback` per acquisire il menu reale in `docs/CLICK-FEEDBACK.png`. Il cerchio rimane sottile e lascia leggibile il testo del pulsante.
