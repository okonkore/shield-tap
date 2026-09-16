extends Node2D

const W := 432.0
const H := 768.0
const ART = preload("res://assets/shield-tap-golem-diagonal-keyart-v3.png")
const HOME_ART = preload("res://assets/shield-tap-home-interior-v1.png")
const ARMORER_ART = preload("res://assets/shield-tap-armorer-interior-night-v1.png")
const JP_FONT = preload("res://assets/fonts/NotoSansJP-VF.ttf")
const CX := 216.0
const HY := 300.0
const FOCAL := 250.0
const SHIELD := Vector2(125, 568)
const SHIELD_FOOT := Vector2(125, 662)
const PRINCESS_CAST := Vector2(178, 594)
const GOLEM_TARGET := Vector2(326, 212)
const ROCK_START_HEIGHT := 3.95
const ROCK_END_HEIGHT := -1.05
const ROCK_GRAVITY := 8.0

enum Mode { TITLE, HOME, ARMORER, BATTLE, RECALL, DOWNED }
enum TitlePanel { MAIN, CONTINUE, NEW_GAME }
enum HomePanel { MAIN, EQUIPMENT }
const SAVE_KEY_PREFIX := "shield-tap-save-v2-"
const SAVE_SLOT_COUNT := 3
var mode := Mode.TITLE
var title_panel := TitlePanel.MAIN
var home_panel := HomePanel.MAIN
var equipment_page := 0
var armorer_page := 0
var selected_slot := -1
var save_slots: Array = []
var needs_rest := false

# Persistent progression. Values are deliberately simple for the first playable slice.
var arm_level := 1
var level_xp := 0.0
var pending_xp := 0.0
var ore := 0
var base_cap := 100.0
var cap_resist := 0
var efficiency := 0
var owned_shields: Array = ["traveler"]
var equipped_shield := "traveler"

const SHIELDS := [
	{"id": "traveler", "name": "旅人の盾", "cost": 0, "weight": 1, "resist": 0, "efficient": 0, "note": "使い込まれた最初の盾"},
	{"id": "moon_iron", "name": "月鉄の丸盾", "cost": 3, "weight": 1, "resist": 1, "efficient": 0, "note": "最大腕力が削られにくいLv.1盾"},
	{"id": "black_leather", "name": "黒革の大盾", "cost": 4, "weight": 1, "resist": 0, "efficient": 1, "note": "構えている間の消耗が少ないLv.1盾"},
	{"id": "moon_iron_2", "name": "月鉄の大円盾", "cost": 6, "weight": 2, "resist": 2, "efficient": 0, "note": "上限耐性に特化したLv.2盾"},
	{"id": "black_leather_2", "name": "黒革の塔盾", "cost": 8, "weight": 2, "resist": 0, "efficient": 2, "note": "省力化に特化したLv.2盾"},
	{"id": "moon_iron_3", "name": "月鉄の城壁盾", "cost": 9, "weight": 3, "resist": 3, "efficient": 0, "note": "上限耐性に特化したLv.3盾"},
	{"id": "black_leather_3", "name": "黒革の城砦盾", "cost": 12, "weight": 3, "resist": 0, "efficient": 3, "note": "省力化に特化したLv.3盾"},
]

const COLLECTION_PER_PAGE := 5

# Expedition state. Boss health is reset on every departure.
var cap := 100.0
var stamina := 100.0
var boss_hp := 360.0
var boss_hp_max := 360.0
var princess_hp := 5
var blocks := 0
var run_ore := 0
var run_xp := 0.0
var recall_ready := false
var recall_time := 0.0
var exhausted_time := 0.0
var raising_time := 0.0
var raise_total := 0.0
var shield_lift := 0.0
var held := false
var guarding := false
var attack_active := false
var attack_t := 0.0
var attack_duration := 1.2
var attack_kind := "stone"
var attack_wait := 1.0
var attack_index := 0
var flash := 0.0
var battle_clock := 0.0
var message := "出撃してゴーレムに挑もう"
var dialog_visible := false
var dialog_title := ""
var dialog_body := ""
var last_press_msec := -1000
var last_press_pos := Vector2(-999.0, -999.0)

const PATTERN := [
	{"kind": "stone", "wait": 0.70}, {"kind": "stone", "wait": 0.55},
	{"kind": "volley", "wait": 0.35}, {"kind": "volley", "wait": 0.35},
	{"kind": "heavy", "wait": 1.05}, {"kind": "stone", "wait": 0.65},
	{"kind": "volley", "wait": 0.35}, {"kind": "heavy", "wait": 1.10},
]

var audio_player: AudioStreamPlayer
var audio_playback: AudioStreamGeneratorPlayback
var tone_frames := 0
var tone_total := 0
var tone_phase := 0.0
var tone_frequency := 120.0
var tone_noise := 0.0
var tone_drop := 0.0

func _ready() -> void:
	_setup_audio()
	_load_save_slots()
	queue_redraw()

func _setup_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 44100.0
	stream.buffer_length = 0.35
	audio_player.stream = stream
	add_child(audio_player)
	audio_player.play()
	audio_playback = audio_player.get_stream_playback()

func _process(delta: float) -> void:
	_fill_audio()
	flash = maxf(0.0, flash - delta)
	if mode in [Mode.BATTLE, Mode.RECALL, Mode.DOWNED]:
		_process_expedition(delta)
	queue_redraw()

func _slot_key(slot: int) -> String:
	return "%s%d" % [SAVE_KEY_PREFIX, slot]

func _read_slot(slot: int) -> Dictionary:
	if not OS.has_feature("web"):
		return {}
	var raw = JavaScriptBridge.eval("localStorage.getItem('%s')" % _slot_key(slot), true)
	if not raw is String or raw.is_empty():
		return {}
	var json := JSON.new()
	if json.parse(raw) != OK or not json.data is Dictionary:
		return {}
	return json.data

func _load_save_slots() -> void:
	save_slots.clear()
	for slot in range(SAVE_SLOT_COUNT):
		save_slots.append(_read_slot(slot))

func _apply_save(data: Dictionary) -> void:
	arm_level = int(data.get("arm_level", 1))
	level_xp = float(data.get("level_xp", 0.0))
	pending_xp = float(data.get("pending_xp", 0.0))
	ore = int(data.get("ore", 0))
	base_cap = float(data.get("base_cap", 100.0))
	var saved_shields = data.get("owned_shields", ["traveler"])
	owned_shields = ["traveler"]
	if saved_shields is Array:
		for shield_id in saved_shields:
			var id := str(shield_id)
			if id != "traveler" and _shield_exists(id):
				owned_shields.append(id)
	equipped_shield = str(data.get("equipped_shield", "traveler"))
	if not owned_shields.has(equipped_shield) or not _shield_exists(equipped_shield):
		equipped_shield = "traveler"
	_apply_shield_effects()
	needs_rest = bool(data.get("needs_rest", false))

func _continue_game(slot: int) -> void:
	var data := _read_slot(slot)
	if data.is_empty():
		return
	selected_slot = slot
	_apply_save(data)
	message = "セーブ%dから再開した" % (slot + 1)
	mode = Mode.HOME
	title_panel = TitlePanel.MAIN

func _save_progress() -> void:
	if selected_slot < 0:
		return
	var data := {
		"arm_level": arm_level, "level_xp": level_xp, "pending_xp": pending_xp,
		"ore": ore, "base_cap": base_cap, "owned_shields": owned_shields,
		"equipped_shield": equipped_shield, "needs_rest": needs_rest,
	}
	if selected_slot < save_slots.size():
		save_slots[selected_slot] = data
	if not OS.has_feature("web"):
		return
	var payload := JSON.stringify(data)
	JavaScriptBridge.eval("localStorage.setItem('%s', %s)" % [_slot_key(selected_slot), JSON.stringify(payload)], true)

func _new_game(slot: int) -> void:
	selected_slot = slot
	arm_level = 1
	level_xp = 0.0
	pending_xp = 0.0
	ore = 0
	base_cap = 100.0
	owned_shields = ["traveler"]
	equipped_shield = "traveler"
	_apply_shield_effects()
	needs_rest = false
	message = "出撃してゴーレムに挑もう"
	mode = Mode.HOME
	title_panel = TitlePanel.MAIN

func _process_expedition(delta: float) -> void:
	battle_clock += delta
	# The princess damages the boss continuously. A successful full fight takes about 100 seconds.
	boss_hp = maxf(0.0, boss_hp - (3.45 + arm_level * 0.22) * delta)
	if boss_hp <= 0.0:
		_finish(true, "ゴーレムを鎮めた")
		return

	if mode == Mode.RECALL:
		recall_time -= delta
		message = "帰還魔法の詠唱中  %.1f" % maxf(0.0, recall_time)
		_update_guard(delta)
		if recall_time <= 0.0:
			_finish(true, "帰還魔法が完成した")
			return
	elif mode == Mode.DOWNED:
		guarding = false
		held = false
		shield_lift = maxf(0.0, shield_lift - delta * 7.0)
	elif exhausted_time > 0.0:
		exhausted_time -= delta
		guarding = false
		shield_lift = maxf(0.0, shield_lift - delta * 7.0)
		message = "息切れ中 — 盾を上げられない"
		if exhausted_time <= 0.0:
			stamina = maxf(stamina, cap * 0.52)
			message = "盾を構えられる"
	else:
		_update_guard(delta)
	_process_attack(delta)

func _update_guard(delta: float) -> void:
	if held and not guarding:
		raising_time -= delta
		shield_lift = clampf(1.0 - raising_time / maxf(raise_total, 0.001), 0.0, 1.0)
		if raising_time <= 0.0:
			guarding = true
	elif not held:
		guarding = false
		shield_lift = maxf(0.0, shield_lift - delta * 8.0)
	if guarding:
		shield_lift = 1.0
		stamina = maxf(0.0, stamina - 17.0 * (1.0 - efficiency * 0.09) * delta)
		if stamina <= 0.0:
			guarding = false
			held = false
			exhausted_time = 2.0
	else:
		stamina = minf(cap, stamina + 24.0 * delta)

func _process_attack(delta: float) -> void:
	if attack_active:
		attack_t += delta / attack_duration
		if attack_t >= 1.0:
			_resolve_attack()
	else:
		attack_wait -= delta
		if attack_wait <= 0.0:
			_start_attack()

func _start_attack() -> void:
	var entry: Dictionary = PATTERN[attack_index]
	attack_index = (attack_index + 1) % PATTERN.size()
	attack_kind = str(entry["kind"])
	attack_duration = 1.15 if attack_kind == "stone" else (0.82 if attack_kind == "volley" else 1.45)
	attack_t = 0.0
	attack_active = true

func _resolve_attack() -> void:
	attack_active = false
	var last: Dictionary = PATTERN[(attack_index - 1 + PATTERN.size()) % PATTERN.size()]
	attack_wait = float(last["wait"])
	if mode != Mode.DOWNED and guarding:
		_block()
	else:
		_damage_princess(2 if attack_kind == "heavy" else 1)

func _block() -> void:
	var base_cost := 9.0 if attack_kind == "stone" else (6.0 if attack_kind == "volley" else 23.0)
	var cap_cost := base_cost * (1.0 - cap_resist * 0.10)
	stamina = maxf(0.0, stamina - cap_cost * 0.72)
	cap = maxf(0.0, cap - cap_cost)
	run_xp += cap_cost
	blocks += 1
	if blocks % 2 == 0:
		run_ore += 1
	if blocks >= 4:
		recall_ready = true
	flash = 0.18
	# A bright, short shield clang contrasts with the dull damage sound.
	_play_sound(165.0 if attack_kind == "heavy" else 235.0, 0.14, 0.13, -0.12)
	message = "防御 %d回   鍛錬 +%d" % [blocks, int(run_xp)]
	if cap <= 0.0:
		mode = Mode.DOWNED
		message = "腕が限界だ — 王女が一人で戦う"
	elif stamina <= 0.0:
		guarding = false
		held = false
		exhausted_time = 2.0

func _damage_princess(damage: int) -> void:
	princess_hp = max(0, princess_hp - damage)
	flash = 0.24
	# A descending noisy thud makes an unblocked hit immediately recognizable.
	_play_sound(160.0, 0.34, 0.42, -0.62)
	if princess_hp <= 0:
		_finish(false, "王女が倒れた")
	else:
		message = "王女が被弾 — 盾で守れ"

func _start_expedition() -> void:
	if needs_rest:
		message = "遠征から帰った。まず眠って休もう"
		_show_dialog("休息が必要", "遠征から戻った後は、眠るまで再び出撃できません。")
		return
	mode = Mode.BATTLE
	boss_hp = boss_hp_max
	princess_hp = 5
	cap = base_cap
	stamina = cap
	blocks = 0
	run_ore = 0
	run_xp = 0.0
	recall_ready = false
	recall_time = 0.0
	exhausted_time = 0.0
	raise_total = 0.0
	shield_lift = 0.0
	battle_clock = 0.0
	attack_active = false
	attack_wait = 1.0
	attack_index = 0
	message = "画面を長押しして盾を構える"

func _start_recall() -> void:
	if recall_ready and mode == Mode.BATTLE:
		mode = Mode.RECALL
		recall_time = 2.6
		message = "帰還魔法を守れ"

func _finish(success: bool, result: String) -> void:
	if success:
		ore += run_ore
		pending_xp += run_xp
		message = "%s　鉱石 +%d　経験値 +%d" % [result, run_ore, int(run_xp)]
		_show_dialog(result, "鉱石 +%d\n経験値 +%d\n眠ると記録されます。" % [run_ore, int(run_xp)])
	else:
		message = "%s　今回の戦利品を失った" % result
		_show_dialog(result, "今回の戦利品と鍛錬は失われました。\n眠ると次の遠征へ出られます。")
	needs_rest = true
	mode = Mode.HOME

func _sleep() -> void:
	var recovered_xp := pending_xp
	level_xp += recovered_xp
	pending_xp = 0.0
	var levels_gained := 0
	while level_xp >= _need_xp():
		level_xp -= _need_xp()
		arm_level += 1
		base_cap += 12.0
		levels_gained += 1
	needs_rest = false
	message = "超回復！ 腕力 Lv.%d" % arm_level if levels_gained > 0 else ("休息を終えた" if recovered_xp <= 0.0 else "休息で鍛錬を吸収した")
	_save_progress()
	if levels_gained > 0:
		_show_dialog("腕力レベルアップ！", "腕力 Lv.%d\n最大腕力 +%d\nセーブしました。" % [arm_level, levels_gained * 12])
	else:
		_show_dialog("休息を終えた", "鍛錬を吸収しました。\nセーブしました。")

func _need_xp() -> float:
	return 70.0 + arm_level * 55.0

func _shield_data(id: String) -> Dictionary:
	for shield in SHIELDS:
		if str(shield["id"]) == id:
			return shield
	return SHIELDS[0]

func _shield_exists(id: String) -> bool:
	for shield in SHIELDS:
		if str(shield["id"]) == id:
			return true
	return false

func _apply_shield_effects() -> void:
	var shield := _shield_data(equipped_shield)
	cap_resist = int(shield["resist"])
	efficiency = int(shield["efficient"])

func _shield_stats_text(shield: Dictionary) -> String:
	return "重さ %d　上限耐性 +%d　省力化 +%d" % [int(shield["weight"]), int(shield["resist"]), int(shield["efficient"])]

func _page_count(item_count: int) -> int:
	return maxi(1, int(ceil(float(item_count) / float(COLLECTION_PER_PAGE))))

func _show_dialog(title: String, body: String) -> void:
	dialog_title = title
	dialog_body = body
	dialog_visible = true

func _craft_shield(id: String) -> void:
	var shield := _shield_data(id)
	if owned_shields.has(id):
		_show_dialog("すでに所持しています", "装備は自室で切り替えられます。")
		return
	var cost := int(shield["cost"])
	if ore < cost:
		message = "鉱石が%d個必要" % cost
		_show_dialog("素材が足りない", "鉱石が%d個必要です。\n今は鉱石 %d個です。" % [cost, ore])
		return
	ore -= cost
	owned_shields.append(id)
	message = "%sを作成した" % str(shield["name"])
	_show_dialog("新しい盾を作成！", "%s\n%s\n装備は自室で切り替えられます。" % [str(shield["name"]), _shield_stats_text(shield)])

func _equip_shield(id: String) -> void:
	if not owned_shields.has(id):
		return
	equipped_shield = id
	_apply_shield_effects()
	var shield := _shield_data(id)
	message = "%sを装備した" % str(shield["name"])
	home_panel = HomePanel.MAIN
	_show_dialog("盾を装備した", "%s\n%s\n眠ると記録されます。" % [str(shield["name"]), _shield_stats_text(shield)])

func _input(event: InputEvent) -> void:
	var pressed := false
	var released := false
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch:
		pressed = event.pressed
		released = not event.pressed
		pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
		released = not event.pressed
		pos = event.position
	if released:
		held = false
		return
	if not pressed:
		return
	# Mobile browsers can report one physical tap as both touch and mouse input.
	# Ignore only the immediate duplicate at the same position, so it cannot act on a new screen.
	var now_msec := Time.get_ticks_msec()
	if now_msec - last_press_msec < 180 and pos.distance_to(last_press_pos) < 10.0:
		return
	last_press_msec = now_msec
	last_press_pos = pos
	if dialog_visible:
		dialog_visible = false
		return
	if mode == Mode.TITLE:
		if title_panel == TitlePanel.MAIN:
			if Rect2(40, 390, 352, 58).has_point(pos):
				title_panel = TitlePanel.CONTINUE
			elif Rect2(40, 464, 352, 58).has_point(pos):
				title_panel = TitlePanel.NEW_GAME
			return
		for slot in range(SAVE_SLOT_COUNT):
			var row_y := 338.0 + slot * 76.0
			var slot_data: Dictionary = save_slots[slot]
			if not Rect2(40, row_y, 352, 58).has_point(pos):
				continue
			if title_panel == TitlePanel.CONTINUE and not slot_data.is_empty():
				_continue_game(slot)
				return
			if title_panel == TitlePanel.NEW_GAME:
				_new_game(slot)
				return
		if Rect2(40, 594, 352, 48).has_point(pos):
			title_panel = TitlePanel.MAIN
		return
	if mode == Mode.HOME:
		if home_panel == HomePanel.EQUIPMENT:
			var owned_start := equipment_page * COLLECTION_PER_PAGE
			var owned_end := mini(owned_shields.size(), owned_start + COLLECTION_PER_PAGE)
			for index in range(owned_start, owned_end):
				if Rect2(24, 370 + (index - owned_start) * 47, 384, 43).has_point(pos):
					_equip_shield(str(owned_shields[index]))
					return
			if Rect2(24, 620, 186, 40).has_point(pos) and equipment_page > 0:
				equipment_page -= 1
				return
			if Rect2(222, 620, 186, 40).has_point(pos) and equipment_page < _page_count(owned_shields.size()) - 1:
				equipment_page += 1
				return
			if Rect2(24, 670, 384, 42).has_point(pos):
				home_panel = HomePanel.MAIN
			return
		if Rect2(40, 505, 352, 58).has_point(pos):
			_start_expedition()
		elif Rect2(20, 575, 124, 58).has_point(pos):
			_sleep()
		elif Rect2(154, 575, 124, 58).has_point(pos):
			home_panel = HomePanel.EQUIPMENT
			equipment_page = 0
		elif Rect2(288, 575, 124, 58).has_point(pos):
			mode = Mode.ARMORER
			armorer_page = 0
			message = "鉱石を使って新しい盾を作ろう"
		return
	if mode == Mode.ARMORER:
		var recipe_start := 1 + armorer_page * COLLECTION_PER_PAGE
		var recipe_end := mini(SHIELDS.size(), recipe_start + COLLECTION_PER_PAGE)
		for index in range(recipe_start, recipe_end):
			if Rect2(24, 378 + (index - recipe_start) * 47, 384, 43).has_point(pos):
				_craft_shield(str(SHIELDS[index]["id"]))
				return
		var recipe_count := SHIELDS.size() - 1
		if Rect2(24, 620, 186, 40).has_point(pos) and armorer_page > 0:
			armorer_page -= 1
			return
		if Rect2(222, 620, 186, 40).has_point(pos) and armorer_page < _page_count(recipe_count) - 1:
			armorer_page += 1
			return
		if Rect2(24, 674, 384, 42).has_point(pos):
			mode = Mode.HOME
		return
	if mode == Mode.BATTLE and recall_ready and Rect2(282, 688, 130, 35).has_point(pos):
		_start_recall()
		return
	if mode in [Mode.BATTLE, Mode.RECALL] and exhausted_time <= 0.0:
		held = true
		var shield_weight := float(_shield_data(equipped_shield)["weight"])
		# Weight tiers 1/2/3 map to practical timing factors 1.0/1.25/1.5.
		var weight_factor := 1.0 + (shield_weight - 1.0) * 0.25
		raise_total = maxf(0.08, 0.18 + (1.0 - cap / base_cap) * 0.52) * weight_factor
		raising_time = raise_total

func _rock_pos(t: float) -> Vector2:
	var depth := lerpf(7.0, 1.0, t)
	var x := lerpf(1.80, -0.34, t)
	# Solve the initial vertical velocity from the actual flight duration.
	# Fast rocks travel on a flatter path; slow heavy rocks must be lobbed higher.
	var seconds := t * attack_duration
	var initial_velocity := (ROCK_END_HEIGHT - ROCK_START_HEIGHT + 0.5 * ROCK_GRAVITY * attack_duration * attack_duration) / attack_duration
	var y := ROCK_START_HEIGHT + initial_velocity * seconds - 0.5 * ROCK_GRAVITY * seconds * seconds
	return Vector2(CX + FOCAL * x / depth, HY - FOCAL * y / depth)

func _rock_radius(t: float) -> float:
	var size := 1.45 if attack_kind == "heavy" else (0.62 if attack_kind == "volley" else 1.0)
	return FOCAL * 0.16 * size / lerpf(7.0, 1.0, t)

func _play_sound(freq: float, duration: float, noise: float, drop: float) -> void:
	tone_frequency = freq
	tone_total = int(44100.0 * duration)
	tone_frames = tone_total
	tone_phase = 0.0
	tone_noise = noise
	tone_drop = drop

func _fill_audio() -> void:
	if audio_playback == null:
		return
	for _i in range(audio_playback.get_frames_available()):
		var sample := 0.0
		if tone_frames > 0:
			var env := pow(float(tone_frames) / float(tone_total), 2.2)
			sample = (sin(tone_phase) * 0.32 + sin(tone_phase * 2.02) * 0.10) * env
			sample += randf_range(-1.0, 1.0) * tone_noise * env
			var pitch := tone_frequency * (1.0 + tone_drop * (1.0 - env))
			tone_phase += TAU * pitch / 44100.0
			tone_frames -= 1
		audio_playback.push_frame(Vector2(sample, sample))

func _draw() -> void:
	var background := ART
	if mode in [Mode.TITLE, Mode.HOME]:
		background = HOME_ART
	elif mode == Mode.ARMORER:
		background = ARMORER_ART
	draw_texture_rect(background, Rect2(0, 0, W, H), false)
	draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.04, 0.10, 0.17), true)
	if mode == Mode.TITLE:
		_draw_title()
	elif mode == Mode.HOME:
		_draw_home()
	elif mode == Mode.ARMORER:
		_draw_armorer()
	else:
		_draw_battle()
	if dialog_visible:
		_draw_dialog()

func _draw_title() -> void:
	draw_rect(Rect2(20, 74, 392, 220), Color(0.02, 0.04, 0.10, 0.82), true)
	draw_string(JP_FONT, Vector2(62, 145), "護衛のリズム", HORIZONTAL_ALIGNMENT_LEFT, -1, 35, Color.WHITE)
	draw_string(JP_FONT, Vector2(62, 180), "王女を守り、巨像に挑む。", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("d7c9f5"))
	if title_panel == TitlePanel.MAIN:
		draw_string(JP_FONT, Vector2(62, 218), "データは眠ったときに、この端末へ保存されます。", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("a9bfdc"))
		_button(Rect2(40, 390, 352, 58), "つづきから", Color("4d6680"))
		_button(Rect2(40, 464, 352, 58), "はじめから", Color("76516f"))
		return
	var heading := "つづきから — セーブデータを選ぶ" if title_panel == TitlePanel.CONTINUE else "はじめから — 保存先を選ぶ"
	draw_string(JP_FONT, Vector2(62, 218), heading, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d7c9f5"))
	draw_string(JP_FONT, Vector2(62, 250), "つづきからは、自室から再開します。", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("a9bfdc"))
	for slot in range(SAVE_SLOT_COUNT):
		var row_y := 338.0 + slot * 76.0
		var slot_data: Dictionary = save_slots[slot]
		var slot_label := "セーブ%d：データなし" % (slot + 1)
		var continue_color := Color("252d3a")
		if not slot_data.is_empty():
			slot_label = "セーブ%d：腕力 Lv.%d　鉱石 %d" % [slot + 1, int(slot_data.get("arm_level", 1)), int(slot_data.get("ore", 0))]
			continue_color = Color("4d6680")
		if title_panel == TitlePanel.NEW_GAME:
			var new_label := "セーブ%dで始める" % (slot + 1)
			if not slot_data.is_empty():
				new_label += "（上書き）"
			_button(Rect2(40, row_y, 352, 58), new_label, Color("76516f"))
		else:
			_button(Rect2(40, row_y, 352, 58), slot_label, continue_color)
	_button(Rect2(40, 594, 352, 48), "戻る", Color("3e4a61"))

func _draw_home() -> void:
	if home_panel == HomePanel.EQUIPMENT:
		_draw_equipment()
		return
	draw_rect(Rect2(20, 22, 392, 92), Color(0.02, 0.04, 0.10, 0.86), true)
	draw_string(JP_FONT, Vector2(40, 52), "護衛の仮宿", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color.WHITE)
	draw_string(JP_FONT, Vector2(40, 78), "腕力 Lv.%d    経験値 %d / %d    今回 +%d" % [arm_level, int(level_xp), int(_need_xp()), int(pending_xp)], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("c9daf5"))
	draw_string(JP_FONT, Vector2(40, 101), "鉱石 %d    最大腕力 %d" % [ore, int(base_cap)], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f2d092"))
	draw_rect(Rect2(30, 370, 372, 112), Color(0.02, 0.04, 0.10, 0.78), true)
	draw_string(JP_FONT, Vector2(48, 400), "巨大ゴーレムが町を包囲している", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	draw_string(JP_FONT, Vector2(48, 427), "王女を守り、鉱石を持ち帰り、眠って強くなる。", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c9daf5"))
	draw_string(JP_FONT, Vector2(48, 455), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f2a5c7"))
	var expedition_color := Color("3a6384") if not needs_rest else Color("293846")
	_button(Rect2(40, 505, 352, 58), "出撃 — ひび割れゴーレム" if not needs_rest else "眠るまで出撃できない", expedition_color)
	_button(Rect2(20, 575, 124, 58), "眠る", Color("4d5979"))
	_button(Rect2(154, 575, 124, 58), "盾を装備", Color("536f7b"))
	_button(Rect2(288, 575, 124, 58), "防具屋へ", Color("785a45"))
	var shield := _shield_data(equipped_shield)
	draw_string(JP_FONT, Vector2(36, 662), "装備中：%s" % str(shield["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f2d092"))
	draw_string(JP_FONT, Vector2(36, 685), _shield_stats_text(shield), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("d9e5ff"))
	if needs_rest:
		draw_string(JP_FONT, Vector2(36, 711), "遠征後のため、眠ると次の出撃が可能になります。", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f4c6d7"))

func _draw_equipment() -> void:
	draw_rect(Rect2(18, 18, 396, 90), Color(0.02, 0.04, 0.10, 0.86), true)
	draw_string(JP_FONT, Vector2(38, 50), "盾の装備", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	draw_string(JP_FONT, Vector2(38, 78), "所持している盾を選んで装備します。", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("c9daf5"))
	draw_string(JP_FONT, Vector2(38, 100), "変更は、眠ったときに保存されます。", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f2d092"))
	draw_rect(Rect2(18, 354, 396, 300), Color(0.02, 0.04, 0.10, 0.84), true)
	var owned_start := equipment_page * COLLECTION_PER_PAGE
	var owned_end := mini(owned_shields.size(), owned_start + COLLECTION_PER_PAGE)
	for index in range(owned_start, owned_end):
		var shield := _shield_data(str(owned_shields[index]))
		var equipped := str(owned_shields[index]) == equipped_shield
		var label := "%s　%s" % [str(shield["name"]), _shield_stats_text(shield)]
		if equipped:
			label += "　【装備中】"
		_button(Rect2(24, 370 + (index - owned_start) * 47, 384, 43), label, Color("6d547d") if equipped else Color("536f7b"))
	var owned_pages := _page_count(owned_shields.size())
	_button(Rect2(24, 620, 186, 40), "前のページ", Color("3e4a61") if equipment_page > 0 else Color("293846"))
	_button(Rect2(222, 620, 186, 40), "次のページ", Color("3e4a61") if equipment_page < owned_pages - 1 else Color("293846"))
	draw_string(JP_FONT, Vector2(184, 645), "%d / %d" % [equipment_page + 1, owned_pages], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("d9e5ff"))
	_button(Rect2(24, 670, 384, 42), "戻る", Color("3e4a61"))

func _draw_armorer() -> void:
	draw_rect(Rect2(18, 18, 396, 90), Color(0.02, 0.04, 0.10, 0.84), true)
	draw_string(JP_FONT, Vector2(38, 49), "夜の防具屋", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	draw_string(JP_FONT, Vector2(38, 76), "鉱石 %d　　素材から盾を作る" % ore, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f2d092"))
	draw_string(JP_FONT, Vector2(38, 99), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("d9e5ff"))
	draw_rect(Rect2(18, 346, 396, 318), Color(0.02, 0.04, 0.10, 0.84), true)
	draw_string(JP_FONT, Vector2(38, 369), "性能を確認して、素材から盾を作る。装備は自室で。", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("c9daf5"))
	var recipe_start := 1 + armorer_page * COLLECTION_PER_PAGE
	var recipe_end := mini(SHIELDS.size(), recipe_start + COLLECTION_PER_PAGE)
	for index in range(recipe_start, recipe_end):
		var shield: Dictionary = SHIELDS[index]
		var id := str(shield["id"])
		var owned := owned_shields.has(id)
		var rect := Rect2(24, 378 + (index - recipe_start) * 47, 384, 43)
		var color := Color("785a45") if not owned else Color("435562")
		draw_rect(rect, color, true)
		draw_rect(rect, Color("b7d6ec"), false, 1.0)
		var status := "所持済み" if owned else "鉱石 %d" % int(shield["cost"])
		draw_string(JP_FONT, Vector2(34, rect.position.y + 17), "%s　%s" % [str(shield["name"]), status], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		draw_string(JP_FONT, Vector2(34, rect.position.y + 34), _shield_stats_text(shield), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("d9e5ff"))
	var recipe_pages := _page_count(SHIELDS.size() - 1)
	_button(Rect2(24, 620, 186, 40), "前の5種", Color("3e4a61") if armorer_page > 0 else Color("293846"))
	_button(Rect2(222, 620, 186, 40), "次の5種", Color("3e4a61") if armorer_page < recipe_pages - 1 else Color("293846"))
	draw_string(JP_FONT, Vector2(184, 645), "%d / %d" % [armorer_page + 1, recipe_pages], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("d9e5ff"))
	_button(Rect2(24, 674, 384, 42), "自室へ戻る", Color("3e4a61"))

func _draw_princess_attack() -> void:
	# A repeating arcing spell shot makes the princess's continuous damage visible.
	var shot_t := fmod(battle_clock, 0.92) / 0.92
	var trail := PackedVector2Array()
	for index in range(18):
		var t := shot_t * float(index) / 17.0
		var point := PRINCESS_CAST.lerp(GOLEM_TARGET, t)
		point.y -= sin(PI * t) * 58.0
		trail.append(point)
	draw_polyline(trail, Color(0.74, 0.48, 1.0, 0.28), 2.0, true)
	var orb := PRINCESS_CAST.lerp(GOLEM_TARGET, shot_t)
	orb.y -= sin(PI * shot_t) * 58.0
	draw_circle(orb, 15.0, Color(0.60, 0.26, 0.95, 0.16))
	draw_circle(orb, 8.0, Color(0.77, 0.54, 1.0, 0.72))
	draw_circle(orb, 3.0, Color("f4e5ff"))
	if shot_t < 0.22:
		var cast_radius := 17.0 + sin(shot_t / 0.22 * PI) * 10.0
		draw_arc(PRINCESS_CAST, cast_radius, 0.0, TAU, 18, Color(0.78, 0.53, 1.0, 0.45), 2.0, true)

func _draw_recall_effect() -> void:
	if mode != Mode.RECALL:
		return
	var progress := clampf(1.0 - recall_time / 2.6, 0.0, 1.0)
	var center := PRINCESS_CAST
	var radius := lerpf(38.0, 106.0, progress)
	var spin := battle_clock * 3.8
	draw_circle(center, radius, Color(0.55, 0.22, 0.94, 0.08 + progress * 0.10))
	draw_arc(center, radius, spin, spin + TAU * 0.72, 36, Color(0.88, 0.60, 1.0, 0.78), 3.0, true)
	draw_arc(center, radius * 0.62, -spin * 1.4, -spin * 1.4 + TAU * 0.66, 28, Color(0.55, 0.82, 1.0, 0.64), 2.0, true)
	for index in range(8):
		var angle := spin + TAU * float(index) / 8.0
		var spark_radius := radius * (0.48 + 0.45 * fmod(battle_clock * 0.8 + float(index) * 0.13, 1.0))
		var spark := center + Vector2(cos(angle), sin(angle)) * spark_radius
		draw_circle(spark, 3.0 + progress * 3.0, Color("f2d4ff"))
	draw_string(JP_FONT, center + Vector2(-52, radius + 24), "帰還魔法を詠唱中", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f4d7ff"))

func _draw_battle() -> void:
	if flash > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(0.62, 0.88, 1.0, flash * 0.42), true)
	var path := PackedVector2Array()
	for i in range(25):
		path.append(_rock_pos(float(i) / 24.0))
	draw_polyline(path, Color(0.45, 0.72, 0.98, 0.15), 2.0, true)
	_draw_princess_attack()
	if attack_active:
		var tip := _rock_pos(attack_t)
		var before := _rock_pos(maxf(0.0, attack_t - 0.025))
		var direction := (tip - before).normalized()
		var wing := direction.orthogonal()
		var radius := _rock_radius(attack_t)
		draw_circle(tip + Vector2(radius * 0.24, radius * 0.34), radius * 1.16, Color(0.01, 0.02, 0.04, 0.48))
		draw_colored_polygon(PackedVector2Array([tip - direction * radius, tip + wing * radius * 0.82, tip + direction * radius, tip - wing * radius * 0.82]), Color("555a72"))
	# The shield is always visible: it rests by the guardian's feet and rises while held.
	var shield_pos := SHIELD_FOOT.lerp(SHIELD, shield_lift)
	var shield_radius := lerpf(42.0, 68.0, shield_lift)
	draw_circle(shield_pos + Vector2(5, 8), shield_radius, Color(0.01, 0.02, 0.05, 0.42))
	draw_circle(shield_pos, shield_radius, Color("355d8d"))
	draw_arc(shield_pos, shield_radius, 0.0, TAU, 28, Color("9ed6ea"), 3.0, true)
	draw_arc(shield_pos, shield_radius * 0.65, PI * 0.12, PI * 0.88, 16, Color("6f9fcc"), 3.0, true)
	if guarding:
		draw_circle(shield_pos, shield_radius + 8, Color(0.25, 0.75, 1.0, 0.20))
		draw_arc(shield_pos, shield_radius + 8, PI, TAU, 28, Color("d9f5ff"), 6)
	elif held and shield_lift > 0.0:
		draw_string(JP_FONT, shield_pos + Vector2(-39, -shield_radius - 12), "持ち上げ中", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("d9f5ff"))
	_draw_recall_effect()
	if mode == Mode.DOWNED:
		draw_circle(SHIELD + Vector2(0, 32), 30, Color(0.01, 0.02, 0.05, 0.62))
		draw_string(JP_FONT, Vector2(58, 568), "力尽きた", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("f2a5c7"))
	_draw_hud()

func _draw_hud() -> void:
	draw_rect(Rect2(16, 18, 400, 92), Color(0.02, 0.04, 0.10, 0.84), true)
	draw_string(JP_FONT, Vector2(32, 44), "ひび割れゴーレム", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_rect(Rect2(32, 53, 240, 10), Color("2c2940"), true)
	draw_rect(Rect2(32, 53, 240 * boss_hp / boss_hp_max, 10), Color("d8709b"), true)
	draw_string(JP_FONT, Vector2(288, 63), "敵HP %d%%" % int(100.0 * boss_hp / boss_hp_max), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f3c8d7"))
	draw_string(JP_FONT, Vector2(32, 86), "腕力 %d / %d" % [int(stamina), int(cap)], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("d9e5ff"))
	draw_rect(Rect2(112, 76, 160, 11), Color("102038"), true)
	draw_rect(Rect2(112, 76, 160 * cap / base_cap, 11), Color("355d8d"), true)
	draw_rect(Rect2(112, 76, 160 * stamina / base_cap, 11), Color("66c8d9"), true)
	draw_string(JP_FONT, Vector2(288, 86), "王女 %d" % princess_hp, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f2a5c7"))
	draw_rect(Rect2(16, 731, 400, 25), Color(0.02, 0.04, 0.10, 0.84), true)
	draw_string(JP_FONT, Vector2(28, 749), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e8f1ff"))
	if recall_ready and mode == Mode.BATTLE:
		_button(Rect2(282, 688, 130, 35), "帰還する", Color("8a4f91"))
		draw_string(JP_FONT, Vector2(29, 712), "帰還魔法の準備完了", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f0bbff"))
	elif not recall_ready:
		draw_string(JP_FONT, Vector2(29, 712), "帰還準備：防御 %d / 4 回" % blocks, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("d6c8ed"))

func _draw_dialog() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.01, 0.02, 0.06, 0.68), true)
	draw_rect(Rect2(28, 244, 376, 250), Color("14233a"), true)
	draw_rect(Rect2(28, 244, 376, 250), Color("b7d6ec"), false, 2.0)
	draw_string(JP_FONT, Vector2(56, 292), dialog_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	var body_lines := dialog_body.split("\n")
	for index in range(body_lines.size()):
		draw_string(JP_FONT, Vector2(56, 334 + index * 27), str(body_lines[index]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d9e5ff"))
	draw_string(JP_FONT, Vector2(56, 460), "タップして閉じる", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f2d092"))

func _button(rect: Rect2, label: String, color: Color) -> void:
	draw_rect(rect, color, true)
	draw_rect(rect, Color("b7d6ec"), false, 1.0)
	draw_string(JP_FONT, Vector2(rect.position.x + 8, rect.position.y + rect.size.y * 0.62), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
