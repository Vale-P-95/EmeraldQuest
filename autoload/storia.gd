extends Node
## Ponte tra i dialoghi (Dialogic) e il resto del gioco.
##
## È un "autoload": Godot lo crea da solo all'avvio e resta sempre disponibile
## da qualsiasi script con il nome Storia (vedi Progetto > Impostazioni > Globali).
##
## Che cosa fa:
##   1. avvia i dialoghi con Storia.avvia("nome_timeline");
##   2. ascolta i segnali che i dialoghi mandano con [signal arg="..."]
##      e aggiorna missioni, borsa, monete, squadra e prezzi;
##   3. tiene fermo il protagonista mentre si parla (vedi dialogo_attivo).
##
## PER PROVARE LA STORIA: avvia il gioco e premi il tasto T.
## Ogni pressione avvia la scena successiva della trama del capitolo 1.
##
## Borsa, monete e squadra qui sono volutamente semplici: quando esisteranno
## l'inventario e il sistema di battaglia veri, questo script passerà loro i dati.

## Emesso quando una missione inizia, avanza o finisce.
signal missione_aggiornata(id: String)
## Emesso quando cambia la quantità di un oggetto nella borsa.
signal borsa_cambiata(oggetto: String, quantita: int)
## Emesso quando un dialogo chiede una lotta. Il sistema di battaglia lo ascolterà.
signal battaglia_richiesta(id: String, cattura: bool)

## Le scene della trama principale, nell'ordine in cui si giocano.
## Ogni voce è [timeline, etichetta]. L'etichetta vuota vuol dire "dall'inizio".
const SCENE_CAPITOLO_1: Array = [
	["c1_01_prologo", ""],
	["c1_02_vento_storto", ""],
	["c1_03_prateria_velia", ""],
	["c1_04_assemblea", ""],
	["c1_05_ferro", "inizio"],
	["c1_05_ferro", "consegna"],
	["c1_06_grotta_ingresso", ""],
	["c1_07_grotta_brisa", ""],
	["c1_08_grotta_patto", ""],
	["c1_09_fauceverde_prima", ""],
	["c1_10_fauceverde_dopo", ""],
	["c1_11_frammento", ""],
]

## true mentre un dialogo è aperto. Il protagonista lo controlla per stare fermo.
var dialogo_attivo: bool = false

## Missioni conosciute. Chiave: id (es. "c1_m2").
## Valore: {"stato": "disponibile" / "attiva" / "conclusa", "obiettivo": numero, "esito": testo}
var missioni: Dictionary = {}
## Oggetti nella borsa. Chiave: id dell'oggetto, valore: quantità.
var borsa: Dictionary = {}
## Oggetti chiave (non si consumano e non si contano).
var oggetti_chiave: Array[String] = []
var monete: int = 0
## Id delle creature in squadra.
var squadra: Array[String] = []
var ricette: Array[String] = []
var zone_sbloccate: Array[String] = []
var voci_diario: Array[String] = []
## Sconti e rincari. Chiave: id del negozio, valore: percentuale (-10 = sconto del 10%).
var prezzi: Dictionary = {}
## Numero della prossima scena di SCENE_CAPITOLO_1 da avviare con il tasto T.
var prossima_scena: int = 0

## Com'era il mouse prima del dialogo, per rimetterlo a posto alla fine.
var _mouse_prima: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	_registra_dialoghi()
	# Colleghiamo i segnali di Dialogic alle nostre funzioni.
	Dialogic.signal_event.connect(_su_segnale)
	Dialogic.timeline_ended.connect(_su_dialogo_finito)

	# Usato solo dal controllo automatico su GitHub: vedi _prova_dialoghi().
	if "--prova-dialoghi" in OS.get_cmdline_user_args():
		_prova_dialoghi.call_deferred()


## Dice a Dialogic dove sono i file dei dialoghi e dei personaggi.
##
## Dialogic tiene un elenco "nome -> file" nelle impostazioni del progetto e lo
## aggiorna quando si usa il suo editor. Qui lo completiamo a ogni avvio guardando
## nella cartella res://dialogic, così un file nuovo funziona subito anche se
## l'elenco non è aggiornato. Il nome di un dialogo è il nome del file senza estensione.
func _registra_dialoghi() -> void:
	for estensione: String in ["dch", "dtl"]:
		var elenco: Dictionary = DialogicResourceUtil.get_directory(estensione)
		for percorso: String in DialogicResourceUtil.scan_folder("res://dialogic", "." + estensione):
			if not elenco.values().has(percorso):
				elenco = DialogicResourceUtil.add_resource_to_directory(percorso, elenco)
		DialogicResourceUtil.set_directory(estensione, elenco)


func _unhandled_input(event: InputEvent) -> void:
	# Tasto T: avvia la scena successiva della trama (comodo per provare).
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_T:
			avvia_prossima_scena()


# ------------------------------------------------------------------------------
# AVVIARE I DIALOGHI
# ------------------------------------------------------------------------------

## Avvia un dialogo. "etichetta" è facoltativa: fa partire la timeline da una "label".
## Esempi:  Storia.avvia("c1_01_prologo")   Storia.avvia("c1_s1_mulino", "nido")
func avvia(timeline: String, etichetta: String = "") -> void:
	if dialogo_attivo:
		return
	if not DialogicResourceUtil.timeline_resource_exists(timeline):
		push_warning("[Storia] La timeline '%s' non esiste." % timeline)
		return

	dialogo_attivo = true
	# Durante il dialogo il mouse deve essere libero per cliccare le risposte.
	_mouse_prima = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Diciamo ai dialoghi che cosa c'è nella borsa in questo momento.
	_aggiorna_variabili_dalla_borsa()
	Dialogic.start(timeline, etichetta)


## Avvia la prossima scena della trama principale del capitolo 1.
func avvia_prossima_scena() -> void:
	if dialogo_attivo:
		return
	if prossima_scena >= SCENE_CAPITOLO_1.size():
		print("[Storia] Il capitolo 1 è finito. Riavvia il gioco per ricominciare.")
		return

	var scena: Array = SCENE_CAPITOLO_1[prossima_scena]
	prossima_scena += 1

	# AIUTO PER LE PROVE: Ferro vuole dei materiali che per ora non si possono
	# raccogliere nel mondo, quindi li mettiamo in borsa noi. Da togliere quando
	# la Prateria avrà i suoi punti di raccolta.
	if scena[0] == "c1_05_ferro" and scena[1] == "consegna":
		aggiungi_oggetto("ciuffo_di_saltarupe", 3)
		aggiungi_oggetto("legno_di_deriva", 1)

	avvia(scena[0], scena[1])


func _su_dialogo_finito() -> void:
	dialogo_attivo = false
	Input.mouse_mode = _mouse_prima


# ------------------------------------------------------------------------------
# REPUTAZIONE E VARIABILI
# ------------------------------------------------------------------------------

## Reputazione con una fazione: "Gilda", "Villaggi" oppure "Confraternita".
func reputazione(fazione: String) -> int:
	return int(Dialogic.VAR.get_variable("Rep." + fazione, 0))


## Legge una variabile dei dialoghi, per esempio variabile("Trama.Bivio1").
func variabile(nome: String) -> Variant:
	return Dialogic.VAR.get_variable(nome)


## Scrive una variabile dei dialoghi. Il sistema di battaglia userà questa funzione,
## per esempio: Storia.imposta_variabile("Cap1.FauceRotta", true)
func imposta_variabile(nome: String, valore: Variant) -> void:
	Dialogic.VAR.set_variable(nome, valore)


## Alcune risposte dipendono da che cosa hai in borsa. Prima di ogni dialogo
## copiamo queste informazioni nelle variabili che le timeline controllano.
func _aggiorna_variabili_dalla_borsa() -> void:
	var ha_materiali: bool = quantita("ciuffo_di_saltarupe") >= 3 and quantita("legno_di_deriva") >= 1
	imposta_variabile("Cap1.HaMateriali", ha_materiali)
	imposta_variabile("Cap1.HaAntidoto", quantita("antidoto_di_salvia") >= 1)
	imposta_variabile("Cap1.HaFocaccia", quantita("focaccia_di_semi") >= 1)


# ------------------------------------------------------------------------------
# BORSA
# ------------------------------------------------------------------------------

## Quanti pezzi di un oggetto ci sono nella borsa.
func quantita(oggetto: String) -> int:
	return int(borsa.get(oggetto, 0))


func aggiungi_oggetto(oggetto: String, numero: int = 1) -> void:
	borsa[oggetto] = quantita(oggetto) + numero
	borsa_cambiata.emit(oggetto, quantita(oggetto))


func togli_oggetto(oggetto: String, numero: int = 1) -> void:
	# maxi() impedisce di scendere sotto zero.
	borsa[oggetto] = maxi(quantita(oggetto) - numero, 0)
	borsa_cambiata.emit(oggetto, quantita(oggetto))


# ------------------------------------------------------------------------------
# SEGNALI IN ARRIVO DAI DIALOGHI
# ------------------------------------------------------------------------------

## Dialogic chiama questa funzione ogni volta che una timeline incontra
## una riga [signal arg="..."]. Il testo ha la forma "tipo:dettaglio:numero".
func _su_segnale(argomento: Variant) -> void:
	if not (argomento is String):
		return
	# "oggetto:cristallo_cattura:5" diventa ["oggetto", "cristallo_cattura", "5"].
	var parti: PackedStringArray = (argomento as String).split(":")
	var tipo: String = parti[0]
	var dettaglio: String = parti[1] if parti.size() > 1 else ""
	var extra: String = parti[2] if parti.size() > 2 else ""

	match tipo:
		"missione_disponibile":
			if not missioni.has(dettaglio):
				_imposta_missione(dettaglio, "disponibile", 0, "")
		"missione_inizio":
			_imposta_missione(dettaglio, "attiva", 1, "")
		"missione_obiettivo":
			_imposta_missione(dettaglio, "attiva", int(extra), "")
		"missione_fine":
			_imposta_missione(dettaglio, "conclusa", 0, extra)
		"oggetto":
			aggiungi_oggetto(dettaglio, int(extra) if extra != "" else 1)
		"oggetto_togli":
			togli_oggetto(dettaglio, int(extra) if extra != "" else 1)
		"oggetto_chiave":
			_aggiungi_una_volta(oggetti_chiave, dettaglio)
		"monete":
			monete += int(dettaglio)
		"ricetta":
			_aggiungi_una_volta(ricette, dettaglio)
		"creatura":
			_aggiungi_una_volta(squadra, dettaglio)
		"sblocca":
			_aggiungi_una_volta(zone_sbloccate, dettaglio)
		"diario":
			_aggiungi_una_volta(voci_diario, dettaglio)
		"prezzi":
			prezzi[dettaglio] = int(extra)
		"rango_su":
			# Il rango vero sta nella variabile Giocatore.Rango, che cambia la timeline.
			print("[Storia] Nuovo rango: ", variabile("Giocatore.Rango"))
		"battaglia", "battaglia_cattura":
			_chiedi_battaglia(dettaglio, tipo == "battaglia_cattura")
		_:
			# Segnali che per ora non hanno un sistema dietro (alleato, negozio,
			# boss_modifica, rivale_compagno, ...): li scriviamo nell'Output.
			print("[Storia] Segnale non ancora gestito: ", argomento)


func _imposta_missione(id: String, stato: String, obiettivo: int, esito: String) -> void:
	missioni[id] = {"stato": stato, "obiettivo": obiettivo, "esito": esito}
	missione_aggiornata.emit(id)
	print("[Storia] Missione %s: %s %s" % [id, stato, esito])


## Aggiunge un testo a un elenco solo se non c'è già.
func _aggiungi_una_volta(elenco: Array[String], voce: String) -> void:
	if not elenco.has(voce):
		elenco.append(voce)


## Un dialogo chiede una lotta. La ascolta BattleManager (scenes/battle/battle_manager.gd),
## che mette in pausa il dialogo con Dialogic.paused = true, fa partire la lotta e
## a lotta finita lo fa ripartire. Contro Fauceverde imposta anche "Cap1.FauceRotta"
## se la barra di Rottura è stata svuotata.
## Se nella scena non c'è nessun BattleManager, il dialogo prosegue come se la lotta fosse vinta.
func _chiedi_battaglia(id: String, cattura: bool) -> void:
	print("[Storia] Lotta richiesta: %s" % id)
	battaglia_richiesta.emit(id, cattura)


# ------------------------------------------------------------------------------
# CONTROLLO AUTOMATICO
# ------------------------------------------------------------------------------

## Fa leggere a Dialogic tutte le timeline e segnala quelle che non riesce a leggere.
## Lo usa il controllo automatico su GitHub, che avvia il gioco così:
##   godot --headless --path . -- --prova-dialoghi
func _prova_dialoghi() -> void:
	var elenco: Dictionary = DialogicResourceUtil.get_timeline_directory()
	var totale_eventi: int = 0
	var totale_risposte: int = 0
	var personaggi: Dictionary = DialogicResourceUtil.get_character_directory()

	if elenco.is_empty():
		push_error("[Storia] Nessuna timeline trovata.")

	for id: String in elenco:
		var timeline: DialogicTimeline = DialogicResourceUtil.get_timeline_resource(id)
		if timeline == null:
			push_error("[Storia] Non riesco a caricare la timeline '%s'." % id)
			continue
		# process() trasforma le righe di testo in eventi veri e propri.
		timeline.process()
		if timeline.events.is_empty():
			push_error("[Storia] La timeline '%s' è vuota." % id)
		for evento: Variant in timeline.events:
			totale_eventi += 1
			if evento is DialogicChoiceEvent:
				totale_risposte += 1
			# Ogni battuta deve avere un personaggio che esiste davvero.
			if evento is DialogicTextEvent:
				var battuta: DialogicTextEvent = evento
				var chi: String = battuta.character_identifier
				if chi != "" and not personaggi.has(chi):
					push_error("[Storia] In '%s' parla un personaggio sconosciuto: %s" % [id, chi])

	for id: String in personaggi:
		if DialogicResourceUtil.get_character_resource(id) == null:
			push_error("[Storia] Non riesco a caricare il personaggio '%s'." % id)

	print("[Storia] Prova dialoghi: %d timeline, %d eventi, %d risposte." % [elenco.size(), totale_eventi, totale_risposte])
	get_tree().quit()
