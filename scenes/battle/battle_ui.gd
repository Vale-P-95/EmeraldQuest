extends CanvasLayer
## L'interfaccia della battaglia: barre dei PS, PA, coda dei turni, messaggi e menu.
##
## Tutti i pezzi vengono creati da codice in _build_ui(), così è facile vedere
## com'è fatta: se vuoi spostare qualcosa, cambia i numeri delle posizioni lì.
## Questa scena NON decide niente: mostra quello che le dice BattleManager e
## gli manda indietro la scelta del giocatore con il segnale action_chosen.

## Il giocatore ha scelto un'azione dal menu.
signal action_chosen(action: BattleAction)
## Il giocatore ha scelto chi mandare in campo dopo un KO.
signal forced_switch_chosen(index: int)

const COLOR_PLAYER := Color(0.35, 0.65, 1.0)
const COLOR_ENEMY := Color(1.0, 0.45, 0.4)
const COLOR_PANEL := Color(0.08, 0.1, 0.14, 0.88)
const MESSAGE_LINES := 4

const ELEMENT_NAMES := ["Fuoco", "Acqua", "Flora", "Volt", "Terra", "Vento", "Gelo", "Luce", "Ombra"]
const ELEMENT_COLORS := [
	Color(1.0, 0.45, 0.2), Color(0.3, 0.6, 1.0), Color(0.35, 0.8, 0.35),
	Color(1.0, 0.9, 0.2), Color(0.75, 0.55, 0.3), Color(0.6, 0.9, 0.85),
	Color(0.7, 0.9, 1.0), Color(1.0, 0.95, 0.7), Color(0.6, 0.4, 0.8),
]

var engine: BattleEngine

# Pezzi dell'interfaccia (creati in _build_ui).
var _queue_box: HBoxContainer
var _enemy_name: Label
var _enemy_hp: ProgressBar
var _enemy_status: Label
var _enemy_break: ProgressBar
var _player_name: Label
var _player_hp: ProgressBar
var _player_hp_text: Label
var _player_ap: Label
var _player_status: Label
var _messages: Label
var _hint: Label
var _menu: VBoxContainer
var _menu_title: Label

var _message_log: Array[String] = []
## PS mostrati a schermo per ogni creatura (si aggiornano evento per evento,
## così le barre scendono nel momento giusto e non tutte insieme).
var _shown_hp := {}
var _shown_ap := {}
var _shown_status := {}
var _shown_break := {}
var _shown_player: BattleCreature
var _shown_enemy: BattleCreature


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS   # funziona anche con il mondo in pausa
	_build_ui()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	# Esc / B / Cerchio: torna al menu principale dai sottomenu.
	if visible and event.is_action_pressed("ui_cancel") and _menu.visible and _menu_title.text != "Comandi":
		get_viewport().set_input_as_handled()
		show_main_menu()


# =============================================================================
#  Costruzione
# =============================================================================

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# --- Coda dei turni (in alto al centro) ---
	var queue_panel := _panel(root, Vector2(250, 10), Vector2(780, 56))
	var qv := VBoxContainer.new()
	queue_panel.add_child(qv)
	var ql := Label.new()
	ql.text = "Prossimi turni"
	ql.add_theme_font_size_override("font_size", 12)
	qv.add_child(ql)
	_queue_box = HBoxContainer.new()
	_queue_box.add_theme_constant_override("separation", 4)
	qv.add_child(_queue_box)

	# --- Nemico (in alto a sinistra) ---
	var ep := _panel(root, Vector2(16, 80), Vector2(360, 110))
	var ev := VBoxContainer.new()
	ep.add_child(ev)
	_enemy_name = _label(ev, 20, COLOR_ENEMY)
	_enemy_hp = _bar(ev, Color(0.85, 0.25, 0.25))
	_enemy_status = _label(ev, 14, Color(1, 0.85, 0.4))
	_enemy_break = _bar(ev, Color(1.0, 0.75, 0.2))
	_enemy_break.custom_minimum_size.y = 8
	_enemy_break.tooltip_text = "Rottura: colpiscilo sulla sua debolezza per svuotarla"

	# --- Giocatore (in basso a sinistra) ---
	var pp := _panel(root, Vector2(16, 446), Vector2(380, 136))
	var pv := VBoxContainer.new()
	pp.add_child(pv)
	_player_name = _label(pv, 20, COLOR_PLAYER)
	_player_hp = _bar(pv, Color(0.3, 0.8, 0.4))
	_player_hp_text = _label(pv, 14, Color.WHITE)
	_player_ap = _label(pv, 18, Color(0.55, 0.85, 1.0))
	_player_status = _label(pv, 14, Color(1, 0.85, 0.4))

	# --- Messaggi (in basso al centro) ---
	var mp := _panel(root, Vector2(16, 594), Vector2(840, 114))
	_messages = _label(mp, 16, Color.WHITE)
	_messages.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# --- Menu dei comandi (in basso a destra) ---
	var menu_panel := _panel(root, Vector2(872, 316), Vector2(392, 392))
	var mv := VBoxContainer.new()
	menu_panel.add_child(mv)
	_menu_title = _label(mv, 16, Color(0.8, 0.9, 1.0))
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 4)
	mv.add_child(_menu)
	_hint = _label(mv, 13, Color(0.8, 0.8, 0.8))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = 370


func _panel(parent: Control, pos: Vector2, size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = pos
	p.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", style)
	parent.add_child(p)
	return p


func _label(parent: Control, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _bar(parent: Control, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(300, 16)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.2, 0.2, 0.25)
	bg.set_corner_radius_all(4)
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", bg)
	parent.add_child(b)
	return b


# =============================================================================
#  Aggiornamento
# =============================================================================

## Prepara l'interfaccia per una nuova battaglia.
func open(e: BattleEngine) -> void:
	engine = e
	_message_log.clear()
	_shown_hp.clear()
	_shown_ap.clear()
	_shown_status.clear()
	_shown_break.clear()
	for c in engine.player_party + engine.enemy_party:
		_remember(c)
	_shown_player = engine.player_active()
	_shown_enemy = engine.enemy_active()
	_messages.text = ""
	hide_menu()
	_refresh_panels()
	refresh_queue()
	visible = true


func close() -> void:
	visible = false
	engine = null


## Mostra un evento del motore (messaggio e barre). BattleManager li passa uno alla volta.
func show_event(ev: Dictionary) -> void:
	var target: BattleCreature = ev.get("target")
	if target != null:
		if ev.has("hp"):
			_shown_hp[target] = ev["hp"]
			_shown_ap[target] = ev["ap"]
			_shown_status[target] = ev["status"]
			_shown_break[target] = ev["break"]
		if ev["kind"] == "switch":
			_remember(target)
			if target in engine.player_party:
				_shown_player = target
			else:
				_shown_enemy = target
		if ev["kind"] == "damage":
			_shake(_player_hp if target == _shown_player else _enemy_hp)
	if ev["text"] != "":
		_message_log.append(ev["text"])
		while _message_log.size() > MESSAGE_LINES:
			_message_log.pop_front()
		_messages.text = "\n".join(_message_log)
	_refresh_panels()


## Allinea tutto allo stato vero del motore (alla fine di una serie di eventi).
func sync_with_engine() -> void:
	for c in engine.player_party + engine.enemy_party:
		_remember(c)
	_shown_player = engine.player_active()
	_shown_enemy = engine.enemy_active()
	_refresh_panels()
	refresh_queue()


func _remember(c: BattleCreature) -> void:
	_shown_hp[c] = c.hp
	_shown_ap[c] = c.ap
	_shown_status[c] = c.status
	_shown_break[c] = c.break_gauge


func _refresh_panels() -> void:
	var e := _shown_enemy
	_enemy_name.text = "%s  Lv %d" % [e.get_display_name(), e.level]
	_set_bar(_enemy_hp, _shown_hp[e], e.max_hp)
	_enemy_status.text = _status_text(_shown_status[e], e)
	_enemy_break.visible = e.is_large()
	_enemy_break.max_value = BattleCreature.BREAK_MAX
	_enemy_break.value = _shown_break[e]

	var p := _shown_player
	_player_name.text = "%s  Lv %d" % [p.get_display_name(), p.level]
	_set_bar(_player_hp, _shown_hp[p], p.max_hp)
	_player_hp_text.text = "PS %d / %d" % [_shown_hp[p], p.max_hp]
	var ap: int = _shown_ap[p]
	_player_ap.text = "PA " + "●".repeat(ap) + "○".repeat(BattleCreature.MAX_AP - ap)
	_player_status.text = _status_text(_shown_status[p], p)


func _status_text(s: BattleCreature.Status, c: BattleCreature) -> String:
	var parts: Array[String] = []
	if s != BattleCreature.Status.NESSUNO:
		parts.append(BattleCreature.status_name(s))
	for stat in c.stat_stages:
		var stage: int = c.stat_stages[stat]["stage"]
		parts.append("%s %s%d" % [BattleEngine.STAT_NAMES[stat], "+" if stage > 0 else "", stage])
	if c.is_defending:
		parts.append("In difesa")
	return "  ".join(parts)


## La barra scende con un'animazione invece di saltare.
func _set_bar(bar: ProgressBar, value: int, max_value: int) -> void:
	bar.max_value = max_value
	var tw := create_tween()
	tw.tween_property(bar, "value", value, 0.25)


## Piccola scossa del pannello di chi viene colpito.
func _shake(node: Control) -> void:
	var panel := node.get_parent().get_parent() as Control
	# Ricordiamo la posizione "vera" la prima volta, così due scosse di fila non lo spostano.
	if not panel.has_meta("home"):
		panel.set_meta("home", panel.position)
	var start: Vector2 = panel.get_meta("home")
	var tw := create_tween()
	for i in 3:
		tw.tween_property(panel, "position", start + Vector2(6, 0), 0.03)
		tw.tween_property(panel, "position", start - Vector2(6, 0), 0.03)
	tw.tween_property(panel, "position", start, 0.03)


## Disegna la coda dei prossimi 8 turni: blu = tue creature, rosso = nemico.
func refresh_queue() -> void:
	for child in _queue_box.get_children():
		child.queue_free()
	if engine == null:
		return
	var first := true
	for c in engine.predict_turns(8):
		var l := Label.new()
		l.text = c.get_display_name()
		l.custom_minimum_size = Vector2(90, 0)
		l.clip_text = true
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 15 if first else 13)
		l.add_theme_color_override("font_color", COLOR_PLAYER if c in engine.player_party else COLOR_ENEMY)
		_queue_box.add_child(l)
		first = false


# =============================================================================
#  Menu
# =============================================================================

func hide_menu() -> void:
	_menu.visible = false
	_menu_title.text = ""
	_hint.text = ""


## Il menu principale: Attacco, Abilità, Difendi, Cambio, Oggetto, Cattura, Fuga.
func show_main_menu() -> void:
	_clear_menu("Comandi")
	var p := engine.player_active()
	_add_button("Attacco", "Colpo base: non costa PA.",
		func(): action_chosen.emit(BattleAction.basic_attack()))
	_add_button("Abilità", "Mosse speciali: costano PA (ne hai %d)." % p.ap, _show_skill_menu)
	_add_button("Difendi", "Dimezzi i danni fino al tuo prossimo turno e guadagni +2 PA. Torni a giocare prima.",
		func(): action_chosen.emit(BattleAction.defend()))
	var can_switch := false
	for i in engine.player_party.size():
		can_switch = can_switch or engine.can_enter(i)
	_add_button("Cambio", "Cambia creatura: costa il turno. Subito dopo un'abilità dello stesso elemento diventa una Staffetta!",
		_show_switch_menu.bind(false), not can_switch)
	_add_button("Oggetto", "Usa un oggetto della borsa.", _show_item_menu)
	_add_button("Cattura", "Arriverà in M3.", Callable(), true)
	_add_button("Fuga", "Prova a scappare." if engine.is_wild else "Non puoi fuggire da questa lotta!",
		func(): action_chosen.emit(BattleAction.flee()), not engine.is_wild)
	_focus_first()


func _show_skill_menu() -> void:
	_clear_menu("Abilità")
	var p := engine.player_active()
	var e := engine.enemy_active()
	for s in p.skills:
		var mult := BattleRules.type_multiplier(engine.chart, s.element, e)
		var hint := "%s · %s · Potenza %d · Precisione %d%%\n%s" % [
			ELEMENT_NAMES[s.element], _category_name(s.category), s.power, s.accuracy, s.description]
		if s.category != SkillData.Category.SUPPORTO:
			hint += "\n" + _effectiveness_text(mult)
		var text := "%s   [%d PA]" % [s.display_name, s.ap_cost]
		var b := _add_button(text, hint, func(): action_chosen.emit(BattleAction.use_skill(s)), not p.can_use(s))
		b.add_theme_color_override("font_color", ELEMENT_COLORS[s.element])
	_add_back_button()
	_focus_first()


## forced = true dopo un KO: il cambio è gratis e non si può tornare indietro.
func _show_switch_menu(forced: bool) -> void:
	_clear_menu("Chi mandi in campo?" if forced else "Cambio")
	for i in engine.player_party.size():
		var c := engine.player_party[i]
		var text := "%s  Lv %d   PS %d/%d" % [c.get_display_name(), c.level, c.hp, c.max_hp]
		var hint := "Tipi: " + ", ".join(c.get_types().map(func(t): return ELEMENT_NAMES[t]))
		var relay := not forced and engine.can_relay(i)
		if relay:
			text = "★ STAFFETTA  " + text
			hint += "\nStaffetta: entra subito con un attacco potenziato (costa 3 PA a chi esce)."
		if i == engine.player_index:
			text += "  (in campo)"
		var cb := (func(): forced_switch_chosen.emit(i)) if forced \
			else (func(): action_chosen.emit(BattleAction.switch_to(i)))
		var b := _add_button(text, hint, cb, not engine.can_enter(i))
		if relay:
			b.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	if not forced:
		_add_back_button()
	_focus_first()


func show_forced_switch() -> void:
	_show_switch_menu(true)


func _show_item_menu() -> void:
	_clear_menu("Oggetti")
	for id in BattleEngine.ITEMS:
		var item: Dictionary = BattleEngine.ITEMS[id]
		var count: int = engine.inventory.get(id, 0)
		_add_button("%s  x%d" % [item["name"], count], item["desc"],
			func(): action_chosen.emit(BattleAction.use_item(id)), count <= 0)
	_add_back_button()
	_focus_first()


func _clear_menu(title: String) -> void:
	for child in _menu.get_children():
		_menu.remove_child(child)
		child.queue_free()
	_menu_title.text = title
	_hint.text = ""
	_menu.visible = true


func _add_button(text: String, hint: String, on_press: Callable, disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = disabled
	b.custom_minimum_size.y = 34
	if on_press.is_valid():
		b.pressed.connect(func():
			hide_menu()
			on_press.call())
	# La descrizione compare sia passando col mouse sia muovendosi con tastiera/controller.
	b.focus_entered.connect(func(): _hint.text = hint)
	b.mouse_entered.connect(func(): _hint.text = hint)
	_menu.add_child(b)
	return b


func _add_back_button() -> void:
	_add_button("← Indietro", "Torna ai comandi (anche con Esc).", show_main_menu)


func _focus_first() -> void:
	for b in _menu.get_children():
		if b is Button and not b.disabled:
			b.grab_focus()
			return


func _category_name(c: SkillData.Category) -> String:
	match c:
		SkillData.Category.FISICA: return "Fisica"
		SkillData.Category.MAGICA: return "Magica"
	return "Supporto"


func _effectiveness_text(mult: float) -> String:
	if mult == 0.0:
		return "Contro questo nemico: nessun effetto!"
	if mult > 1.0:
		return "Contro questo nemico: superefficace (x%s)" % str(mult)
	if mult < 1.0:
		return "Contro questo nemico: poco efficace (x%s)" % str(mult)
	return "Contro questo nemico: danno normale"
