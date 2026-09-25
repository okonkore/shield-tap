extends Node2D

const W := 432.0
const H := 768.0
const ART = preload("res://assets/shield-tap-golem-diagonal-keyart-v3.png")
const FOUR_ARM_ART = preload("res://assets/shield-tap-fourarm-golem-battle-v1.png")
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
const ORE_DAMAGE_STEP := 14.0
const PRINCESS_CAST_PERIOD := 3.0
const PRINCESS_CHANT_RATIO := 0.48
const RECALL_CHANT_DURATION := 5.2
const SHIELD_POINT_BONUS := 0.08
const RESONANCE_GUARD_GOAL := 45.0
const PRINCESS_HP_MAX := 50
const PUZZLE_ORIGIN := Vector2(27, 145)
const PUZZLE_CELL := 42.0
const PUZZLE_COLORS := [
	Color("df6b83"), Color("e99a56"), Color("e8d36e"),
	Color("9acb71"), Color("57c4a7"), Color("64afd9"),
	Color("7186dc"), Color("a27bd9"), Color("d47db7"),
]
const PUZZLE_SOLUTION := [
	[5, 3, 4, 6, 7, 8, 9, 1, 2],
	[6, 7, 2, 1, 9, 5, 3, 4, 8],
	[1, 9, 8, 3, 4, 2, 5, 6, 7],
	[8, 5, 9, 7, 6, 1, 4, 2, 3],
	[4, 2, 6, 8, 5, 3, 7, 9, 1],
	[7, 1, 3, 9, 2, 4, 8, 5, 6],
	[9, 6, 1, 5, 3, 7, 2, 8, 4],
	[2, 8, 7, 4, 1, 9, 6, 3, 5],
	[3, 4, 5, 2, 8, 6, 1, 7, 9],
]
const PUZZLE_GIVENS := [
	[5, 3, 0, 0, 7, 0, 0, 0, 0],
	[6, 0, 0, 1, 9, 5, 0, 0, 0],
	[0, 9, 8, 0, 0, 0, 0, 6, 0],
	[8, 0, 0, 0, 6, 0, 0, 0, 3],
	[4, 0, 0, 8, 0, 3, 0, 0, 1],
	[7, 0, 0, 0, 2, 0, 0, 0, 6],
	[0, 6, 0, 0, 0, 0, 2, 8, 0],
	[0, 0, 0, 4, 1, 9, 0, 0, 5],
	[0, 0, 0, 0, 8, 0, 0, 7, 9],
]

enum Mode { TITLE, HOME, ARMORER, WANDER, PUZZLE, BATTLE, RECALL, DOWNED, RESULTS }
enum TitlePanel { MAIN, CONTINUE, NEW_GAME }
enum HomePanel { MAIN, EQUIPMENT, WAND_EQUIPMENT, BOSS_SELECT }
const SAVE_KEY_PREFIX := "shield-tap-save-v2-"
const SAVE_SLOT_COUNT := 3
var mode := Mode.TITLE
var title_panel := TitlePanel.MAIN
var home_panel := HomePanel.MAIN
var equipment_page := 0
var armorer_page := 0
var wand_equipment_page := 0
var wand_shop_page := 0
var selected_slot := -1
var save_slots: Array = []
var selected_boss := "cracked"

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
var owned_wands: Array = ["apprentice"]
var equipped_wand := "apprentice"

const SHIELDS := [
	{"id": "traveler", "name": "旅人の盾", "cost": 0, "weight": 1, "resist": 0, "efficient": 0, "note": "使い込まれた最初の盾"},
	{"id": "moon_iron", "name": "月鉄の丸盾", "cost": 3, "weight": 1, "resist": 1, "efficient": 0, "note": "最大腕力が削られにくいLv.1盾"},
	{"id": "black_leather", "name": "黒革の大盾", "cost": 4, "weight": 1, "resist": 0, "efficient": 1, "note": "構えている間の消耗が少ないLv.1盾"},
	{"id": "moon_iron_2", "name": "月鉄の大円盾", "cost": 6, "weight": 2, "resist": 2, "efficient": 0, "note": "上限耐性に特化したLv.2盾"},
	{"id": "black_leather_2", "name": "黒革の塔盾", "cost": 8, "weight": 2, "resist": 0, "efficient": 2, "note": "省力化に特化したLv.2盾"},
	{"id": "moon_iron_3", "name": "月鉄の城壁盾", "cost": 9, "weight": 3, "resist": 3, "efficient": 0, "note": "上限耐性に特化したLv.3盾"},
	{"id": "black_leather_3", "name": "黒革の城砦盾", "cost": 12, "weight": 3, "resist": 0, "efficient": 3, "note": "省力化に特化したLv.3盾"},
	{"id": "moon_iron_4", "name": "月鉄の要塞盾", "cost": 13, "weight": 4, "resist": 4, "efficient": 0, "note": "上限耐性に特化したLv.4盾"},
	{"id": "black_leather_4", "name": "黒革の守備盾", "cost": 17, "weight": 4, "resist": 0, "efficient": 4, "note": "省力化に特化したLv.4盾"},
	{"id": "moon_iron_5", "name": "蒼月の要塞盾", "cost": 17, "weight": 5, "resist": 5, "efficient": 0, "note": "上限耐性に特化したLv.5盾"},
	{"id": "black_leather_5", "name": "影革の守備盾", "cost": 22, "weight": 5, "resist": 0, "efficient": 5, "note": "省力化に特化したLv.5盾"},
	{"id": "moon_iron_6", "name": "星鉄の要塞盾", "cost": 22, "weight": 6, "resist": 6, "efficient": 0, "note": "上限耐性に特化したLv.6盾"},
	{"id": "black_leather_6", "name": "夜革の守備盾", "cost": 28, "weight": 6, "resist": 0, "efficient": 6, "note": "省力化に特化したLv.6盾"},
	{"id": "moon_iron_7", "name": "白銀の要塞盾", "cost": 28, "weight": 7, "resist": 7, "efficient": 0, "note": "上限耐性に特化したLv.7盾"},
	{"id": "black_leather_7", "name": "霊革の守備盾", "cost": 35, "weight": 7, "resist": 0, "efficient": 7, "note": "省力化に特化したLv.7盾"},
	{"id": "moon_iron_8", "name": "夜晶の要塞盾", "cost": 35, "weight": 8, "resist": 8, "efficient": 0, "note": "上限耐性に特化したLv.8盾"},
	{"id": "black_leather_8", "name": "月獣の守備盾", "cost": 43, "weight": 8, "resist": 0, "efficient": 8, "note": "省力化に特化したLv.8盾"},
	{"id": "moon_iron_9", "name": "天鉄の要塞盾", "cost": 43, "weight": 9, "resist": 9, "efficient": 0, "note": "上限耐性に特化したLv.9盾"},
	{"id": "black_leather_9", "name": "竜革の守備盾", "cost": 52, "weight": 9, "resist": 0, "efficient": 9, "note": "省力化に特化したLv.9盾"},
	{"id": "moon_iron_10", "name": "王鉄の要塞盾", "cost": 52, "weight": 10, "resist": 10, "efficient": 0, "note": "上限耐性に特化したLv.10盾"},
	{"id": "black_leather_10", "name": "神獣の守備盾", "cost": 62, "weight": 10, "resist": 0, "efficient": 10, "note": "省力化に特化したLv.10盾"},
	{"id": "resonance_break", "name": "砕岩の共鳴盾", "cost": 6, "weight": 1, "resist": 0, "efficient": 0, "resonance": "break", "note": "防御蓄積満タンで王女の次の一撃を強化"},
	{"id": "resonance_swift", "name": "迅詠の共鳴盾", "cost": 6, "weight": 1, "resist": 0, "efficient": 0, "resonance": "swift", "note": "防御蓄積満タンで王女の次の詠唱を短縮"},
	{"id": "resonance_ward", "name": "守りの共鳴盾", "cost": 7, "weight": 1, "resist": 0, "efficient": 0, "resonance": "ward", "note": "防御蓄積満タンで次の被弾を大幅軽減"},
	{"id": "resonance_mend", "name": "命脈の共鳴盾", "cost": 8, "weight": 1, "resist": 0, "efficient": 0, "resonance": "mend", "note": "防御蓄積満タンで王女のHPを25%回復"},
]

const WANDS := [
	{"id": "apprentice", "name": "旅の魔術杖", "cost": 0, "period": 3.0, "flight": 1.56, "damage": 12.0, "note": "Lv.1　標準的な詠唱と採掘力"},
	{"id": "moon_spark", "name": "月火の魔術杖", "cost": 4, "period": 3.3, "flight": 1.20, "damage": 17.0, "note": "Lv.2　重い魔法ほど速く届く"},
	{"id": "azure_focus", "name": "蒼焦の魔術杖", "cost": 7, "period": 3.7, "flight": 1.02, "damage": 24.0, "note": "Lv.3　高威力の高速弾"},
	{"id": "comet_rod", "name": "彗星の魔術杖", "cost": 11, "period": 4.0, "flight": 0.84, "damage": 33.0, "note": "Lv.4　長詠唱・高速の一撃"},
	{"id": "starcore_staff", "name": "星核の魔術杖", "cost": 16, "period": 4.3, "flight": 0.70, "damage": 44.0, "note": "Lv.5　鉱脈を深く穿つ"},
	{"id": "deep_orbit", "name": "深環の魔術杖", "cost": 22, "period": 4.6, "flight": 0.60, "damage": 57.0, "note": "Lv.6　重い魔法が素早く飛ぶ"},
	{"id": "crystal_lance", "name": "晶槍の魔術杖", "cost": 29, "period": 4.9, "flight": 0.52, "damage": 72.0, "note": "Lv.7　高リスクの貫通魔法"},
	{"id": "meteor_staff", "name": "流星の魔術杖", "cost": 37, "period": 5.2, "flight": 0.45, "damage": 89.0, "note": "Lv.8　命中すれば大きく採掘"},
	{"id": "royal_aster", "name": "王星の魔術杖", "cost": 46, "period": 5.5, "flight": 0.39, "damage": 108.0, "note": "Lv.9　王家に伝わる重魔法"},
	{"id": "sovereign_core", "name": "天芯の魔術杖", "cost": 56, "period": 5.8, "flight": 0.34, "damage": 130.0, "note": "Lv.10　最も重く、最も速い一撃"},
	{"id": "swift_spark", "name": "星火の短杖", "cost": 6, "period": 1.8, "flight": 0.55, "damage": 5.8, "note": "派生杖　短詠唱・低DPSの安定型"},
	{"id": "piercing_core", "name": "穿孔の長杖", "cost": 10, "period": 4.8, "flight": 0.58, "damage": 26.0, "note": "派生杖　長詠唱・高DPSの重採掘型"},
]

const COLLECTION_PER_PAGE := 5

# Expedition state. Boss health is reset on every departure.
var cap := 100.0
var stamina := 100.0
var boss_hp := 360.0
var boss_hp_max := 360.0
var princess_hp := PRINCESS_HP_MAX
var blocks := 0
var run_ore := 0
var mined_damage := 0.0
var run_xp := 0.0
var recall_ready := false
var recall_time := 0.0
var exhausted_time := 0.0
var raising_time := 0.0
var raise_total := 0.0
var shield_lift := 0.0
var shield_drop_speed := 0.0
var shield_ground_impact := 0.0
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
var princess_cast_clock := 0.0
var princess_impact_time := 0.0
var princess_cast_cancel_time := 0.0
var princess_cast_empowered := false
var resonance_charge := 0.0
var resonance_ready := false
var resonance_flash := 0.0
var result_title := ""
var result_success := false
var result_ore := 0
var result_xp := 0
var result_levels := 0
var message := "出撃してゴーレムに挑もう"
var dialog_visible := false
var dialog_title := ""
var dialog_body := ""
var last_press_msec := -1000
var last_press_pos := Vector2(-999.0, -999.0)
var puzzle_solution: Array = []
var puzzle_cells: Array = []
var puzzle_givens: Array = []
var puzzle_selected := Vector2i(-1, -1)
var puzzle_complete := false

const PATTERN := [
	{"kind": "stone", "wait": 0.34}, {"kind": "stone", "wait": 0.28},
	{"kind": "volley", "wait": 0.18}, {"kind": "volley", "wait": 0.18},
	{"kind": "heavy", "wait": 0.55}, {"kind": "stone", "wait": 0.30},
	{"kind": "volley", "wait": 0.18}, {"kind": "heavy", "wait": 0.58},
]

const FOUR_ARM_PATTERN := [
	{"kind": "stone", "wait": 0.12}, {"kind": "volley", "wait": 0.08},
	{"kind": "volley", "wait": 0.08}, {"kind": "stone", "wait": 0.10},
	{"kind": "heavy", "wait": 0.24}, {"kind": "volley", "wait": 0.08},
	{"kind": "volley", "wait": 0.08}, {"kind": "stone", "wait": 0.14},
]

const BOSSES := [
	{"id": "cracked", "name": "ひび割れゴーレム", "hp": 360.0, "note": "投石の間を読み、護衛の基本を覚える巨像。"},
	{"id": "four_arm", "name": "四腕の連撃ゴーレム", "hp": 720.0, "note": "四本の腕で岩を連続投擲する、強敵の巨像。"},
]

var audio_player: AudioStreamPlayer
var audio_playback: AudioStreamGeneratorPlayback
var audio_unlocked := false
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

func _unlock_audio() -> void:
	# Safari blocks Web Audio until this runs in response to the player's first tap.
	if audio_unlocked:
		return
	audio_unlocked = true
	audio_player.play()
	audio_playback = audio_player.get_stream_playback()
	_play_sound(520.0, 0.08, 0.02, -0.04)

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
	# Older saves stored earned experience until sleeping. Fold it into the permanent total on load.
	pending_xp = 0.0
	var legacy_pending_xp := float(data.get("pending_xp", 0.0))
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
	var saved_wands = data.get("owned_wands", ["apprentice"])
	owned_wands = ["apprentice"]
	if saved_wands is Array:
		for wand_id in saved_wands:
			var id := str(wand_id)
			if id != "apprentice" and _wand_exists(id):
				owned_wands.append(id)
	equipped_wand = str(data.get("equipped_wand", "apprentice"))
	if not owned_wands.has(equipped_wand) or not _wand_exists(equipped_wand):
		equipped_wand = "apprentice"
	_apply_shield_effects()
	_grant_experience(legacy_pending_xp)

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
		"arm_level": arm_level, "level_xp": level_xp, "pending_xp": 0.0,
		"ore": ore, "base_cap": base_cap, "owned_shields": owned_shields,
		"equipped_shield": equipped_shield, "owned_wands": owned_wands,
		"equipped_wand": equipped_wand,
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
	owned_wands = ["apprentice"]
	equipped_wand = "apprentice"
	_apply_shield_effects()
	message = "出撃してゴーレムに挑もう"
	mode = Mode.HOME
	title_panel = TitlePanel.MAIN

func _process_expedition(delta: float) -> void:
	battle_clock += delta
	princess_cast_clock += delta
	princess_impact_time = maxf(0.0, princess_impact_time - delta)
	princess_cast_cancel_time = maxf(0.0, princess_cast_cancel_time - delta)
	resonance_flash = maxf(0.0, resonance_flash - delta)
	shield_ground_impact = maxf(0.0, shield_ground_impact - delta)
	var cast_period := _princess_cast_period()
	if princess_cast_clock >= cast_period:
		princess_cast_clock -= cast_period
		_princess_magic_hit()
		_begin_princess_chant()
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
		_drop_shield(delta)
	elif exhausted_time > 0.0:
		exhausted_time -= delta
		guarding = false
		_drop_shield(delta)
		message = "息切れ中 — 盾を上げられない"
		if exhausted_time <= 0.0:
			stamina = maxf(stamina, cap * 0.52)
			message = "盾を構えられる"
	else:
		_update_guard(delta)
	_process_attack(delta)

func _princess_magic_hit() -> void:
	# Each wand changes both the exposed chant time and the reward for completing it.
	var wand := _wand_data(equipped_wand)
	var magic_damage := float(wand["damage"]) * (1.0 + 0.064 * float(arm_level - 1))
	if princess_cast_empowered:
		magic_damage *= 1.85
		princess_cast_empowered = false
		resonance_flash = 0.34
		message = "砕岩共鳴を込めた魔法が炸裂"
		_play_sound(470.0, 0.18, 0.05, -0.28)
	elif resonance_ready and _resonance_type() == "swift":
		_consume_resonance("迅詠共鳴で王女の詠唱を短縮")
	boss_hp = maxf(0.0, boss_hp - magic_damage)
	mined_damage += magic_damage
	var newly_mined := int(floor(mined_damage / ORE_DAMAGE_STEP))
	if newly_mined > 0:
		run_ore += newly_mined
		mined_damage = fmod(mined_damage, ORE_DAMAGE_STEP)
	princess_impact_time = 0.32

func _begin_princess_chant() -> void:
	# 王女に付与済みの砕岩共鳴を、次の詠唱の一発へ固定する。
	if resonance_ready and _resonance_type() == "break":
		resonance_ready = false
		princess_cast_empowered = true
		resonance_flash = 0.48
		message = "砕岩共鳴を込めて詠唱を開始"
		_play_sound(620.0, 0.18, 0.03, 0.15)

func _princess_cast_period() -> float:
	return _princess_chant_duration() + _princess_flight_duration()

func _princess_chant_duration() -> float:
	var duration := float(_wand_data(equipped_wand)["period"]) * PRINCESS_CHANT_RATIO
	return duration * 0.58 if resonance_ready and _resonance_type() == "swift" else duration

func _princess_flight_duration() -> float:
	var wand := _wand_data(equipped_wand)
	var duration := float(wand.get("flight", float(wand["period"]) * (1.0 - PRINCESS_CHANT_RATIO)))
	return duration * 0.58 if resonance_ready and _resonance_type() == "swift" else duration

func _princess_is_chanting() -> bool:
	return princess_cast_clock < _princess_chant_duration()

func _resonance_type() -> String:
	return str(_shield_data(equipped_shield).get("resonance", ""))

func _resonance_name() -> String:
	return _resonance_label(_resonance_type())

func _resonance_label(resonance: String) -> String:
	match resonance:
		"break": return "砕岩共鳴"
		"swift": return "迅詠共鳴"
		"ward": return "守りの共鳴"
		"mend": return "命脈共鳴"
	return ""

func _clear_resonance() -> void:
	resonance_charge = 0.0
	resonance_ready = false

func _consume_resonance(note: String) -> void:
	resonance_charge = 0.0
	resonance_ready = false
	resonance_flash = 0.34
	message = note
	_play_sound(470.0, 0.18, 0.05, -0.28)

func _charge_resonance(guard_power: float) -> bool:
	if _resonance_type().is_empty() or resonance_ready:
		return false
	resonance_charge = minf(RESONANCE_GUARD_GOAL, resonance_charge + guard_power)
	if resonance_charge >= RESONANCE_GUARD_GOAL:
		if _resonance_type() == "mend":
			var recovered := maxi(1, int(ceil(float(PRINCESS_HP_MAX) * 0.25)))
			princess_hp = mini(PRINCESS_HP_MAX, princess_hp + recovered)
			resonance_charge = 0.0
			resonance_flash = 0.62
			message = "命脈共鳴が発動 — 王女HP +%d" % recovered
			_play_sound(720.0, 0.26, 0.02, 0.10)
			return true
		resonance_ready = true
		if _resonance_type() == "break":
			# The gauge's energy is spent now; the state moves to the princess.
			resonance_charge = 0.0
		resonance_flash = 0.62
		message = "砕岩共鳴が王女に宿った — 次の詠唱を強化" if _resonance_type() == "break" else "%sが発動 — 次の効果を待機" % _resonance_name()
		_play_sound(680.0, 0.22, 0.02, 0.18)
		return true
	return false

func _update_guard(delta: float) -> void:
	if held and not guarding:
		raising_time -= delta
		# A vertical ballistic heave: quick at first, slowing at the apex, then settling into guard.
		var lift_progress := clampf(1.0 - raising_time / maxf(raise_total, 0.001), 0.0, 1.0)
		# y = 2.748t - 1.748t²: apex is 8% above the guard position at t ≈ 0.79.
		shield_lift = 2.748 * lift_progress - 1.748 * lift_progress * lift_progress
		shield_drop_speed = 0.0
		shield_ground_impact = 0.0
		if raising_time <= 0.0:
			guarding = true
	elif not held:
		guarding = false
		_drop_shield(delta)
	if guarding:
		shield_lift = 1.0
		stamina = maxf(0.0, stamina - 17.0 * (1.0 - efficiency * SHIELD_POINT_BONUS) * delta)
		if stamina <= 0.0:
			guarding = false
			held = false
			exhausted_time = 2.0
	else:
		stamina = minf(cap, stamina + 24.0 * delta)

func _drop_shield(delta: float) -> void:
	# Let the weight take over after releasing the hold: a short, accelerating fall.
	if shield_lift <= 0.0:
		shield_lift = 0.0
		shield_drop_speed = 0.0
		return
	shield_drop_speed += 7.8 * delta
	shield_lift -= shield_drop_speed * delta
	if shield_lift <= 0.0:
		shield_lift = 0.0
		shield_drop_speed = 0.0
		shield_ground_impact = 0.20
		_play_sound(74.0, 0.16, 0.18, -0.08)

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
	var pattern := _boss_pattern()
	var entry: Dictionary = pattern[attack_index]
	attack_index = (attack_index + 1) % pattern.size()
	attack_kind = str(entry["kind"])
	var rapid := selected_boss == "four_arm"
	attack_duration = (0.58 if rapid else 0.76) if attack_kind == "stone" else ((0.34 if rapid else 0.46) if attack_kind == "volley" else (0.82 if rapid else 1.02))
	attack_t = 0.0
	attack_active = true

func _resolve_attack() -> void:
	attack_active = false
	var pattern := _boss_pattern()
	var last: Dictionary = pattern[(attack_index - 1 + pattern.size()) % pattern.size()]
	attack_wait = float(last["wait"])
	if mode != Mode.DOWNED and guarding:
		_block()
	else:
		_damage_princess(7 if attack_kind == "heavy" else (3 if attack_kind == "stone" else 2))

func _block() -> void:
	var attack_power := _attack_power()
	var cap_cost := attack_power * maxf(0.0, 1.0 - cap_resist * SHIELD_POINT_BONUS)
	if resonance_ready and _resonance_type() == "ward":
		cap_cost *= 0.22
		_consume_resonance("守りの共鳴が衝撃を受け止めた")
	stamina = maxf(0.0, stamina - cap_cost * 0.72)
	cap = maxf(0.0, cap - cap_cost)
	# Training follows the enemy's original attack power, not the shield's mitigated damage.
	run_xp += attack_power
	blocks += 1
	var skill_activated := _charge_resonance(attack_power)
	if blocks >= 4:
		recall_ready = true
	flash = 0.18
	_play_guard_sound()
	message = "防御 %d回　経験値 +%d（累計 %d）" % [blocks, int(attack_power), int(run_xp)]
	if skill_activated:
		message += "　%s発動" % _resonance_name()
	if cap <= 0.0:
		mode = Mode.DOWNED
		message = "腕が限界だ — 王女が一人で戦う"
	elif stamina <= 0.0:
		guarding = false
		held = false
		exhausted_time = 2.0

func _damage_princess(damage: int) -> void:
	var chanting := _princess_is_chanting()
	var attached_break_buff := resonance_ready and _resonance_type() == "break"
	var empowered_cancelled := princess_cast_empowered or attached_break_buff
	if empowered_cancelled:
		# A direct hit disperses the princess's stored energy whether she has begun the spell or not.
		princess_cast_empowered = false
		if attached_break_buff:
			_clear_resonance()
		resonance_flash = 0.34
	princess_hp = max(0, princess_hp - damage)
	flash = 0.24
	# A descending noisy thud makes an unblocked hit immediately recognizable.
	_play_sound(160.0, 0.34, 0.42, -0.62)
	if princess_hp <= 0:
		_finish(false, "王女が倒れた")
	elif chanting:
		# A hit breaks the spell before it is released; the next spell must be chanted from the start.
		princess_cast_clock = 0.0
		princess_cast_cancel_time = 0.56
		message = "王女が被弾 — 強化詠唱が中断された" if empowered_cancelled else "王女が被弾 — 詠唱が中断された"
	else:
		message = "王女が被弾 — 盾で守れ"

func _start_expedition() -> void:
	mode = Mode.BATTLE
	boss_hp_max = float(_boss_data()["hp"])
	boss_hp = boss_hp_max
	princess_hp = PRINCESS_HP_MAX
	cap = base_cap
	stamina = cap
	blocks = 0
	run_ore = 0
	mined_damage = 0.0
	run_xp = 0.0
	recall_ready = false
	recall_time = 0.0
	exhausted_time = 0.0
	raise_total = 0.0
	shield_lift = 0.0
	shield_drop_speed = 0.0
	shield_ground_impact = 0.0
	battle_clock = 0.0
	princess_cast_clock = 0.0
	princess_impact_time = 0.0
	princess_cast_cancel_time = 0.0
	princess_cast_empowered = false
	resonance_charge = 0.0
	resonance_ready = false
	resonance_flash = 0.0
	attack_active = false
	attack_wait = 1.0
	attack_index = 0
	message = "画面を長押しして盾を構える"

func _start_recall() -> void:
	if recall_ready and mode == Mode.BATTLE:
		mode = Mode.RECALL
		recall_time = RECALL_CHANT_DURATION
		message = "帰還魔法を守れ"

func _finish(success: bool, result: String) -> void:
	result_title = result
	result_success = success
	result_ore = 0
	result_xp = 0
	result_levels = 0
	if success:
		ore += run_ore
		result_ore = run_ore
		result_xp = int(run_xp)
		result_levels = _grant_experience(run_xp)
		message = "%s　鉱石 +%d　経験値 +%d" % [result, run_ore, int(run_xp)]
	else:
		message = "%s　今回の戦利品を失った" % result
	mode = Mode.RESULTS

func _grant_experience(amount: float) -> int:
	level_xp += amount
	var levels_gained := 0
	while level_xp >= _need_xp():
		level_xp -= _need_xp()
		arm_level += 1
		base_cap += 12.0
		levels_gained += 1
	return levels_gained

func _need_xp() -> float:
	return 70.0 + arm_level * 55.0

func _shield_data(id: String) -> Dictionary:
	for shield in SHIELDS:
		if str(shield["id"]) == id:
			return shield
	return SHIELDS[0]

func _wand_data(id: String) -> Dictionary:
	for wand in WANDS:
		if str(wand["id"]) == id:
			return wand
	return WANDS[0]

func _wand_exists(id: String) -> bool:
	for wand in WANDS:
		if str(wand["id"]) == id:
			return true
	return false

func _boss_data() -> Dictionary:
	for boss in BOSSES:
		if str(boss["id"]) == selected_boss:
			return boss
	return BOSSES[0]

func _boss_pattern() -> Array:
	return FOUR_ARM_PATTERN if selected_boss == "four_arm" else PATTERN

func _attack_power() -> float:
	var base_power := 9.0 if attack_kind == "stone" else (6.0 if attack_kind == "volley" else 23.0)
	return base_power * 1.32 if selected_boss == "four_arm" else base_power

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
	var resonance := str(shield.get("resonance", ""))
	if not resonance.is_empty():
		return "重さ %d　%s" % [int(shield["weight"]), _resonance_label(resonance)]
	return "重さ %d　上限耐性 %d%%　省力化 %d%%" % [int(shield["weight"]), int(float(shield["resist"]) * SHIELD_POINT_BONUS * 100.0), int(float(shield["efficient"]) * SHIELD_POINT_BONUS * 100.0)]

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
	_show_dialog("盾を装備した", "%s\n%s\n次の戦闘リザルトで保存されます。" % [str(shield["name"]), _shield_stats_text(shield)])

func _wand_stats_text(wand: Dictionary) -> String:
	var chant := float(wand["period"]) * PRINCESS_CHANT_RATIO
	var flight := float(wand.get("flight", float(wand["period"]) * (1.0 - PRINCESS_CHANT_RATIO)))
	return "詠唱 %.1f秒　飛翔 %.2f秒　威力 %.1f　DPS %.1f" % [chant, flight, float(wand["damage"]), float(wand["damage"]) / (chant + flight)]

func _buy_wand(id: String) -> void:
	var wand := _wand_data(id)
	if owned_wands.has(id):
		_show_dialog("すでに所持しています", "装備は自室で切り替えられます。")
		return
	var cost := int(wand["cost"])
	if ore < cost:
		_show_dialog("鉱石が足りない", "%sには鉱石 %d個が必要です。\n今は鉱石 %d個です。" % [str(wand["name"]), cost, ore])
		return
	ore -= cost
	owned_wands.append(id)
	message = "%sを購入した" % str(wand["name"])
	_show_dialog("新しい杖を購入！", "%s\n%s\n装備は自室で切り替えられます。" % [str(wand["name"]), _wand_stats_text(wand)])

func _equip_wand(id: String) -> void:
	if not owned_wands.has(id):
		return
	equipped_wand = id
	var wand := _wand_data(id)
	message = "%sを王女に託した" % str(wand["name"])
	home_panel = HomePanel.MAIN
	_show_dialog("杖を装備した", "%s\n%s\n次の戦闘リザルトで保存されます。" % [str(wand["name"]), _wand_stats_text(wand)])

func _start_puzzle() -> void:
	var color_order := range(9)
	color_order.shuffle()
	puzzle_solution.clear()
	puzzle_cells.clear()
	puzzle_givens.clear()
	for row in range(9):
		var solution_row: Array = []
		var cells_row: Array = []
		var givens_row: Array = []
		for column in range(9):
			var value := int(PUZZLE_SOLUTION[row][column]) - 1
			var color_id := int(color_order[value])
			solution_row.append(color_id)
			var is_given := int(PUZZLE_GIVENS[row][column]) != 0
			cells_row.append(color_id if is_given else -1)
			givens_row.append(is_given)
		puzzle_solution.append(solution_row)
		puzzle_cells.append(cells_row)
		puzzle_givens.append(givens_row)
	puzzle_selected = Vector2i(-1, -1)
	puzzle_complete = false
	message = "鉱石を並べて、盤面を整えよう"
	mode = Mode.PUZZLE

func _puzzle_has_conflict(row: int, column: int) -> bool:
	var value := int(puzzle_cells[row][column])
	if value < 0:
		return false
	for index in range(9):
		if index != column and int(puzzle_cells[row][index]) == value:
			return true
		if index != row and int(puzzle_cells[index][column]) == value:
			return true
	var box_row := (row / 3) * 3
	var box_column := (column / 3) * 3
	for box_y in range(box_row, box_row + 3):
		for box_x in range(box_column, box_column + 3):
			if (box_y != row or box_x != column) and int(puzzle_cells[box_y][box_x]) == value:
				return true
	return false

func _puzzle_is_solved() -> bool:
	for row in range(9):
		for column in range(9):
			if int(puzzle_cells[row][column]) != int(puzzle_solution[row][column]):
				return false
	return true

func _handle_puzzle_input(pos: Vector2) -> void:
	if Rect2(24, 670, 186, 42).has_point(pos):
		_start_puzzle()
		return
	if Rect2(222, 670, 186, 42).has_point(pos):
		mode = Mode.HOME
		return
	var board := Rect2(PUZZLE_ORIGIN, Vector2(PUZZLE_CELL * 9.0, PUZZLE_CELL * 9.0))
	if board.has_point(pos):
		var column := int((pos.x - PUZZLE_ORIGIN.x) / PUZZLE_CELL)
		var row := int((pos.y - PUZZLE_ORIGIN.y) / PUZZLE_CELL)
		if not bool(puzzle_givens[row][column]):
			puzzle_selected = Vector2i(column, row)
			_play_sound(420.0, 0.05, 0.02, 0.04)
		else:
			message = "最初から置かれた鉱石は動かせない"
		return
	if Rect2(27, 548, 378, 42).has_point(pos) and puzzle_selected.x >= 0 and not puzzle_complete:
		var color_id := clampi(int((pos.x - 27.0) / 42.0), 0, 8)
		puzzle_cells[puzzle_selected.y][puzzle_selected.x] = color_id
		if _puzzle_is_solved():
			puzzle_complete = true
			message = "盤面が整った！"
			_show_dialog("鉱石パズル完成！", "九つの鉱石を、すべての行・列・区画に一つずつ配置しました。")
			_play_sound(720.0, 0.30, 0.02, 0.12)
		elif _puzzle_has_conflict(puzzle_selected.y, puzzle_selected.x):
			message = "同じ色が重なっている"
			_play_sound(150.0, 0.10, 0.10, -0.20)
		else:
			message = "鉱石を配置した"
			_play_sound(600.0, 0.08, 0.02, 0.02)

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
	_unlock_audio()
	if dialog_visible:
		dialog_visible = false
		return
	if mode == Mode.RESULTS:
		if Rect2(40, 640, 352, 58).has_point(pos):
			_save_progress()
			message = "リザルトを記録した。次の遠征へ出られる"
			home_panel = HomePanel.MAIN
			mode = Mode.HOME
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
	if mode == Mode.PUZZLE:
		_handle_puzzle_input(pos)
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
		if home_panel == HomePanel.WAND_EQUIPMENT:
			var wand_start := wand_equipment_page * COLLECTION_PER_PAGE
			var wand_end := mini(owned_wands.size(), wand_start + COLLECTION_PER_PAGE)
			for index in range(wand_start, wand_end):
				if Rect2(24, 370 + (index - wand_start) * 47, 384, 43).has_point(pos):
					_equip_wand(str(owned_wands[index]))
					return
			if Rect2(24, 620, 186, 40).has_point(pos) and wand_equipment_page > 0:
				wand_equipment_page -= 1
				return
			if Rect2(222, 620, 186, 40).has_point(pos) and wand_equipment_page < _page_count(owned_wands.size()) - 1:
				wand_equipment_page += 1
				return
			if Rect2(24, 670, 384, 42).has_point(pos):
				home_panel = HomePanel.MAIN
			return
		if home_panel == HomePanel.BOSS_SELECT:
			for index in range(BOSSES.size()):
				if Rect2(24, 382 + index * 94, 384, 78).has_point(pos):
					selected_boss = str(BOSSES[index]["id"])
					_start_expedition()
					return
			if Rect2(24, 670, 384, 42).has_point(pos):
				home_panel = HomePanel.MAIN
			return
		if Rect2(40, 482, 352, 58).has_point(pos):
			home_panel = HomePanel.BOSS_SELECT
		elif Rect2(20, 552, 186, 52).has_point(pos):
			home_panel = HomePanel.EQUIPMENT
			equipment_page = 0
		elif Rect2(226, 552, 186, 52).has_point(pos):
			mode = Mode.ARMORER
			armorer_page = 0
			message = "鉱石を使って新しい盾を作ろう"
		elif Rect2(20, 616, 186, 52).has_point(pos):
			home_panel = HomePanel.WAND_EQUIPMENT
			wand_equipment_page = 0
		elif Rect2(226, 616, 186, 52).has_point(pos):
			mode = Mode.WANDER
			wand_shop_page = 0
			message = "王女のための杖を選ぼう"
		elif Rect2(20, 676, 392, 42).has_point(pos):
			_start_puzzle()
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
	if mode == Mode.WANDER:
		var shop_start := 1 + wand_shop_page * COLLECTION_PER_PAGE
		var shop_end := mini(WANDS.size(), shop_start + COLLECTION_PER_PAGE)
		for index in range(shop_start, shop_end):
			if Rect2(24, 378 + (index - shop_start) * 47, 384, 43).has_point(pos):
				_buy_wand(str(WANDS[index]["id"]))
				return
		var shop_count := WANDS.size() - 1
		if Rect2(24, 620, 186, 40).has_point(pos) and wand_shop_page > 0:
			wand_shop_page -= 1
			return
		if Rect2(222, 620, 186, 40).has_point(pos) and wand_shop_page < _page_count(shop_count) - 1:
			wand_shop_page += 1
			return
		if Rect2(24, 670, 384, 42).has_point(pos):
			mode = Mode.HOME
		return
	if mode == Mode.BATTLE and recall_ready and Rect2(282, 688, 130, 35).has_point(pos):
		_start_recall()
		return
	if mode in [Mode.BATTLE, Mode.RECALL] and exhausted_time <= 0.0:
		held = true
		shield_drop_speed = 0.0
		shield_ground_impact = 0.0
		var shield_weight := float(_shield_data(equipped_shield)["weight"])
		# Even the Lv.10 shields stay usable; their weight raises the time by at most 50%.
		var weight_factor := 1.0 + (shield_weight - 1.0) * 0.055
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
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.shieldTapAudio&&window.shieldTapAudio.play(%f,%f,%f,%f)" % [freq, duration, noise, drop], true)
		return
	tone_frequency = freq
	tone_total = int(44100.0 * duration)
	tone_frames = tone_total
	tone_phase = 0.0
	tone_noise = noise
	tone_drop = drop

func _play_guard_sound() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.shieldTapAudio&&window.shieldTapAudio.playGuard()", true)
		return
	# The provided MP3 is served in the Web build; retain the synthetic clang for local editor runs.
	_play_sound(210.0, 0.16, 0.13, -0.12)

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
	if mode in [Mode.TITLE, Mode.HOME, Mode.WANDER, Mode.PUZZLE]:
		background = HOME_ART
	elif mode == Mode.ARMORER:
		background = ARMORER_ART
	elif selected_boss == "four_arm":
		background = FOUR_ARM_ART
	draw_texture_rect(background, Rect2(0, 0, W, H), false)
	draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.04, 0.10, 0.17), true)
	if mode == Mode.TITLE:
		_draw_title()
	elif mode == Mode.HOME:
		_draw_home()
	elif mode == Mode.ARMORER:
		_draw_armorer()
	elif mode == Mode.WANDER:
		_draw_wander()
	elif mode == Mode.PUZZLE:
		_draw_puzzle()
	elif mode == Mode.RESULTS:
		_draw_battle()
		_draw_results()
	else:
		_draw_battle()
	if dialog_visible:
		_draw_dialog()

func _draw_title() -> void:
	draw_rect(Rect2(20, 74, 392, 220), Color(0.02, 0.04, 0.10, 0.82), true)
	draw_string(JP_FONT, Vector2(62, 145), "護衛のリズム", HORIZONTAL_ALIGNMENT_LEFT, -1, 35, Color.WHITE)
	draw_string(JP_FONT, Vector2(62, 180), "王女を守り、巨像に挑む。", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("d7c9f5"))
	if title_panel == TitlePanel.MAIN:
		draw_string(JP_FONT, Vector2(62, 218), "戦闘リザルトで、この端末へ保存されます。", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("a9bfdc"))
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
	if home_panel == HomePanel.WAND_EQUIPMENT:
		_draw_wand_equipment()
		return
	if home_panel == HomePanel.BOSS_SELECT:
		_draw_boss_select()
		return
	draw_rect(Rect2(20, 22, 392, 92), Color(0.02, 0.04, 0.10, 0.86), true)
	draw_string(JP_FONT, Vector2(40, 52), "護衛の仮宿", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color.WHITE)
	draw_string(JP_FONT, Vector2(40, 78), "腕力 Lv.%d    経験値 %d / %d" % [arm_level, int(level_xp), int(_need_xp())], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("c9daf5"))
	draw_string(JP_FONT, Vector2(40, 101), "鉱石 %d    最大腕力 %d" % [ore, int(base_cap)], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f2d092"))
	draw_rect(Rect2(30, 370, 372, 112), Color(0.02, 0.04, 0.10, 0.78), true)
	draw_string(JP_FONT, Vector2(48, 400), "巨大ゴーレムが町を包囲している", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	draw_string(JP_FONT, Vector2(48, 427), "王女を守り、鉱石を持ち帰って強くなる。", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c9daf5"))
	draw_string(JP_FONT, Vector2(48, 455), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f2a5c7"))
	_button(Rect2(40, 482, 352, 58), "出撃先を選ぶ", Color("3a6384"))
	_button(Rect2(20, 552, 186, 52), "盾を装備", Color("536f7b"))
	_button(Rect2(226, 552, 186, 52), "防具屋へ", Color("785a45"))
	_button(Rect2(20, 616, 186, 52), "杖を装備", Color("66547f"))
	_button(Rect2(226, 616, 186, 52), "杖屋へ", Color("7d4f72"))
	_button(Rect2(20, 676, 392, 42), "パズル", Color("4c6a73"))
	var shield := _shield_data(equipped_shield)
	var wand := _wand_data(equipped_wand)
	draw_string(JP_FONT, Vector2(36, 744), "盾：%s　　杖：%s" % [str(shield["name"]), str(wand["name"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f2d092"))

func _draw_puzzle() -> void:
	draw_rect(Rect2(18, 16, 396, 108), Color(0.03, 0.07, 0.13, 0.90), true)
	draw_string(JP_FONT, Vector2(38, 47), "鉱石パズル", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color.WHITE)
	draw_string(JP_FONT, Vector2(38, 74), "各行・列・3×3区画に、九色の鉱石を一つずつ。", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c9daf5"))
	draw_string(JP_FONT, Vector2(38, 101), "マスを選んで、下の鉱石をタップ。", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f2d092"))
	for row in range(9):
		for column in range(9):
			var cell_rect := Rect2(PUZZLE_ORIGIN + Vector2(column * PUZZLE_CELL, row * PUZZLE_CELL), Vector2(PUZZLE_CELL, PUZZLE_CELL))
			var is_given := bool(puzzle_givens[row][column])
			var value := int(puzzle_cells[row][column])
			draw_rect(cell_rect.grow(-1.0), Color("24354d") if is_given else Color("172941"), true)
			if value >= 0:
				var center := cell_rect.get_center()
				var gem_color: Color = PUZZLE_COLORS[value]
				var radius := 13.5 if is_given else 11.5
				draw_circle(center + Vector2(1.5, 2.0), radius, Color(0.01, 0.02, 0.05, 0.42))
				draw_colored_polygon(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius * 0.80, 0), center + Vector2(0, radius), center + Vector2(-radius * 0.80, 0)]), gem_color)
				draw_circle(center + Vector2(-3.0, -4.0), radius * 0.28, Color(1.0, 1.0, 1.0, 0.34))
			var border_color := Color("d96876") if _puzzle_has_conflict(row, column) else Color("49627d")
			draw_rect(cell_rect, border_color, false, 1.0)
			if puzzle_selected == Vector2i(column, row):
				draw_rect(cell_rect.grow(-2.0), Color("f7e6a0"), false, 3.0)
	for section in range(4):
		var offset := float(section) * PUZZLE_CELL * 3.0
		draw_line(PUZZLE_ORIGIN + Vector2(offset, 0), PUZZLE_ORIGIN + Vector2(offset, PUZZLE_CELL * 9.0), Color("b7d6ec"), 2.0)
		draw_line(PUZZLE_ORIGIN + Vector2(0, offset), PUZZLE_ORIGIN + Vector2(PUZZLE_CELL * 9.0, offset), Color("b7d6ec"), 2.0)
	draw_string(JP_FONT, Vector2(28, 534), "置く鉱石", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("d9e5ff"))
	for color_id in range(9):
		var palette_rect := Rect2(27 + color_id * 42, 548, 42, 42)
		draw_rect(palette_rect.grow(-2.0), Color("25364c"), true)
		var palette_center := palette_rect.get_center()
		draw_circle(palette_center + Vector2(1.5, 2.0), 13.0, Color(0.01, 0.02, 0.05, 0.42))
		draw_colored_polygon(PackedVector2Array([palette_center + Vector2(0, -13), palette_center + Vector2(10, 0), palette_center + Vector2(0, 13), palette_center + Vector2(-10, 0)]), PUZZLE_COLORS[color_id])
		draw_rect(palette_rect.grow(-2.0), Color("f7e6a0") if puzzle_selected.x >= 0 and int(puzzle_cells[puzzle_selected.y][puzzle_selected.x]) == color_id else Color("5e7892"), false, 1.0)
	var hint := "完成！　新しい盤面で再挑戦できる。" if puzzle_complete else message
	draw_string(JP_FONT, Vector2(28, 622), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f2d092"))
	_button(Rect2(24, 670, 186, 42), "新しい盤面", Color("496d7c"))
	_button(Rect2(222, 670, 186, 42), "自室へ戻る", Color("3e4a61"))

func _draw_boss_select() -> void:
	draw_rect(Rect2(18, 18, 396, 90), Color(0.02, 0.04, 0.10, 0.86), true)
	draw_string(JP_FONT, Vector2(38, 50), "出撃先を選ぶ", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	draw_string(JP_FONT, Vector2(38, 78), "挑む巨像を選んで遠征へ向かう。", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("c9daf5"))
	draw_string(JP_FONT, Vector2(38, 100), "強敵ほど、一撃の経験値も大きい。", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f2d092"))
	draw_rect(Rect2(18, 354, 396, 330), Color(0.02, 0.04, 0.10, 0.84), true)
	for index in range(BOSSES.size()):
		var boss: Dictionary = BOSSES[index]
		var rect := Rect2(24, 382 + index * 94, 384, 78)
		var color := Color("73516f") if str(boss["id"]) == "four_arm" else Color("4d6680")
		draw_rect(rect, color, true)
		draw_rect(rect, Color("b7d6ec"), false, 1.0)
		draw_string(JP_FONT, Vector2(38, rect.position.y + 25), str(boss["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
		draw_string(JP_FONT, Vector2(38, rect.position.y + 47), "HP %d　%s" % [int(boss["hp"]), str(boss["note"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("d9e5ff"))
		draw_string(JP_FONT, Vector2(38, rect.position.y + 67), "タップして出撃", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("f2d092"))
	_button(Rect2(24, 670, 384, 42), "戻る", Color("3e4a61"))

func _draw_equipment() -> void:
	draw_rect(Rect2(18, 18, 396, 90), Color(0.02, 0.04, 0.10, 0.86), true)
	draw_string(JP_FONT, Vector2(38, 50), "盾の装備", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	draw_string(JP_FONT, Vector2(38, 78), "所持している盾を選んで装備します。", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("c9daf5"))
	draw_string(JP_FONT, Vector2(38, 100), "変更は、次の戦闘リザルトで保存されます。", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f2d092"))
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

func _draw_wand_equipment() -> void:
	draw_rect(Rect2(18, 18, 396, 90), Color(0.08, 0.04, 0.14, 0.88), true)
	draw_string(JP_FONT, Vector2(38, 50), "王女の杖", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	draw_string(JP_FONT, Vector2(38, 78), "杖で詠唱時間・一撃・DPSが変わります。", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e1c9ff"))
	draw_string(JP_FONT, Vector2(38, 100), "変更は、次の戦闘リザルトで保存されます。", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f2d092"))
	draw_rect(Rect2(18, 346, 396, 300), Color(0.03, 0.02, 0.09, 0.84), true)
	var wand_start := wand_equipment_page * COLLECTION_PER_PAGE
	var wand_end := mini(owned_wands.size(), wand_start + COLLECTION_PER_PAGE)
	for index in range(wand_start, wand_end):
		var wand := _wand_data(str(owned_wands[index]))
		var equipped := str(owned_wands[index]) == equipped_wand
		var label := "%s　%s" % [str(wand["name"]), _wand_stats_text(wand)]
		if equipped:
			label += "　【装備中】"
		_button(Rect2(24, 370 + (index - wand_start) * 47, 384, 43), label, Color("76558b") if equipped else Color("5a4872"))
	var wand_pages := _page_count(owned_wands.size())
	_button(Rect2(24, 620, 186, 40), "前のページ", Color("3e4a61") if wand_equipment_page > 0 else Color("293846"))
	_button(Rect2(222, 620, 186, 40), "次のページ", Color("3e4a61") if wand_equipment_page < wand_pages - 1 else Color("293846"))
	draw_string(JP_FONT, Vector2(184, 645), "%d / %d" % [wand_equipment_page + 1, wand_pages], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("d9e5ff"))
	_button(Rect2(24, 670, 384, 42), "戻る", Color("3e4a61"))

func _draw_wander() -> void:
	draw_rect(Rect2(18, 18, 396, 90), Color(0.10, 0.04, 0.14, 0.88), true)
	draw_string(JP_FONT, Vector2(38, 50), "夜の杖屋", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	draw_string(JP_FONT, Vector2(38, 77), "鉱石 %d　　王女の戦い方を選ぶ" % ore, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f2d092"))
	draw_string(JP_FONT, Vector2(38, 100), "高威力ほど長詠唱。ただし魔法弾は速く届く。", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("e1c9ff"))
	draw_rect(Rect2(18, 346, 396, 300), Color(0.03, 0.02, 0.09, 0.84), true)
	var shop_start := 1 + wand_shop_page * COLLECTION_PER_PAGE
	var shop_end := mini(WANDS.size(), shop_start + COLLECTION_PER_PAGE)
	for index in range(shop_start, shop_end):
		var wand: Dictionary = WANDS[index]
		var id := str(wand["id"])
		var owned := owned_wands.has(id)
		var rect := Rect2(24, 378 + (index - shop_start) * 47, 384, 43)
		draw_rect(rect, Color("6c456b") if not owned else Color("435562"), true)
		draw_rect(rect, Color("d8b8ee"), false, 1.0)
		var status := "所持済み" if owned else "鉱石 %d" % int(wand["cost"])
		draw_string(JP_FONT, Vector2(34, rect.position.y + 17), "%s　%s" % [str(wand["name"]), status], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		draw_string(JP_FONT, Vector2(34, rect.position.y + 34), _wand_stats_text(wand), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("e1c9ff"))
	var shop_pages := _page_count(WANDS.size() - 1)
	_button(Rect2(24, 620, 186, 40), "前の5種", Color("3e4a61") if wand_shop_page > 0 else Color("293846"))
	_button(Rect2(222, 620, 186, 40), "次の5種", Color("3e4a61") if wand_shop_page < shop_pages - 1 else Color("293846"))
	draw_string(JP_FONT, Vector2(184, 645), "%d / %d" % [wand_shop_page + 1, shop_pages], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("d9e5ff"))
	_button(Rect2(24, 670, 384, 42), "自室へ戻る", Color("3e4a61"))

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
	var chant_duration := _princess_chant_duration()
	var flight_duration := _princess_flight_duration()
	if resonance_ready and _resonance_type() == "break":
		var aura_radius := 38.0 + sin(battle_clock * 5.0) * 5.0
		draw_circle(PRINCESS_CAST, aura_radius, Color(1.0, 0.66, 0.28, 0.13))
		draw_arc(PRINCESS_CAST, aura_radius, battle_clock * 2.0, battle_clock * 2.0 + TAU * 0.72, 24, Color("ffbd6a"), 2.0, true)
		draw_string(JP_FONT, PRINCESS_CAST + Vector2(-42, -aura_radius - 12), "砕岩共鳴 付与中", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("ffd394"))
	if princess_cast_clock < chant_duration:
		var chant_t := princess_cast_clock / chant_duration
		var cast_radius := 22.0 + chant_t * 33.0
		var spin := battle_clock * 4.0
		var chant_color := Color("ffb35f") if princess_cast_empowered else Color(0.58, 0.25, 0.96, 0.06 + chant_t * 0.10)
		draw_circle(PRINCESS_CAST, cast_radius, Color(chant_color, 0.13 + chant_t * 0.11) if princess_cast_empowered else chant_color)
		draw_arc(PRINCESS_CAST, cast_radius, spin, spin + TAU * 0.76, 28, Color(0.78, 0.53, 1.0, 0.62), 2.0, true)
		draw_arc(PRINCESS_CAST, cast_radius * 0.58, -spin * 1.4, -spin * 1.4 + TAU * 0.62, 22, Color(0.64, 0.82, 1.0, 0.55), 2.0, true)
		for index in range(5):
			var angle := spin + TAU * float(index) / 5.0
			var spark := PRINCESS_CAST + Vector2(cos(angle), sin(angle)) * cast_radius * 0.72
			draw_circle(spark, 2.0 + chant_t * 2.0, Color("ead7ff"))
		draw_string(JP_FONT, PRINCESS_CAST + Vector2(-43, -cast_radius - 14), "強化詠唱中" if princess_cast_empowered else "詠唱中", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffd394") if princess_cast_empowered else Color("efd9ff"))
	else:
		var shot_t := clampf((princess_cast_clock - chant_duration) / flight_duration, 0.0, 1.0)
		var trail := PackedVector2Array()
		for index in range(18):
			var t := shot_t * float(index) / 17.0
			var point := PRINCESS_CAST.lerp(GOLEM_TARGET, t)
			point.y -= sin(PI * t) * 58.0
			trail.append(point)
		draw_polyline(trail, Color(0.74, 0.48, 1.0, 0.34), 2.0, true)
		var orb := PRINCESS_CAST.lerp(GOLEM_TARGET, shot_t)
		orb.y -= sin(PI * shot_t) * 58.0
		var orb_color := Color("ffad55") if princess_cast_empowered else Color(0.77, 0.54, 1.0, 0.78)
		draw_circle(orb, 17.0, Color(orb_color, 0.22))
		draw_circle(orb, 9.0, orb_color)
		draw_circle(orb, 3.0, Color("f4e5ff"))
	if princess_impact_time > 0.0:
		var impact_t := princess_impact_time / 0.32
		draw_circle(GOLEM_TARGET, 14.0 + (1.0 - impact_t) * 22.0, Color(0.64, 0.42, 1.0, 0.34 * impact_t))
		draw_circle(GOLEM_TARGET, 5.0, Color("e9d4ff"))
	if princess_cast_cancel_time > 0.0:
		var cancel_t := princess_cast_cancel_time / 0.56
		var burst_radius := 28.0 + (1.0 - cancel_t) * 38.0
		draw_circle(PRINCESS_CAST, burst_radius, Color(0.95, 0.42, 0.72, 0.10 * cancel_t))
		for index in range(6):
			var angle := TAU * float(index) / 6.0 + (1.0 - cancel_t) * 0.5
			var spark := PRINCESS_CAST + Vector2(cos(angle), sin(angle)) * burst_radius
			draw_circle(spark, 2.0 + cancel_t * 2.0, Color(1.0, 0.64, 0.82, cancel_t))
		draw_string(JP_FONT, PRINCESS_CAST + Vector2(-36, -burst_radius - 12), "詠唱中断", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffc0d9"))

func _draw_recall_effect() -> void:
	if mode != Mode.RECALL:
		return
	var progress := clampf(1.0 - recall_time / RECALL_CHANT_DURATION, 0.0, 1.0)
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
	# The shield rises straight upward, overshoots its guard point a little, then settles back down.
	var shield_pos := SHIELD_FOOT.lerp(SHIELD, shield_lift)
	var impact_ratio := shield_ground_impact / 0.20
	shield_pos.y += impact_ratio * 8.0
	var shield_radius := lerpf(42.0, 68.0, shield_lift) * (1.0 - impact_ratio * 0.12)
	draw_circle(shield_pos + Vector2(5, 8), shield_radius, Color(0.01, 0.02, 0.05, 0.42))
	draw_circle(shield_pos, shield_radius, Color("355d8d"))
	draw_arc(shield_pos, shield_radius, 0.0, TAU, 28, Color("9ed6ea"), 3.0, true)
	draw_arc(shield_pos, shield_radius * 0.65, PI * 0.12, PI * 0.88, 16, Color("6f9fcc"), 3.0, true)
	_draw_resonance_effect(shield_pos, shield_radius)
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

func _draw_results() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.01, 0.02, 0.07, 0.72), true)
	draw_rect(Rect2(24, 150, 384, 500), Color("14233a"), true)
	draw_rect(Rect2(24, 150, 384, 500), Color("b7d6ec"), false, 2.0)
	var heading := "遠征成功" if result_success else "遠征失敗"
	var heading_color := Color("f2d092") if result_success else Color("f2a5c7")
	draw_string(JP_FONT, Vector2(52, 205), heading, HORIZONTAL_ALIGNMENT_LEFT, -1, 29, heading_color)
	draw_string(JP_FONT, Vector2(52, 239), result_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("d9e5ff"))
	draw_rect(Rect2(48, 267, 336, 1), Color("6f8ba5"), true)
	if result_success:
		draw_string(JP_FONT, Vector2(56, 315), "獲得した鉱石", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("c9daf5"))
		draw_string(JP_FONT, Vector2(322, 315), "+%d" % result_ore, HORIZONTAL_ALIGNMENT_RIGHT, 54, 23, Color("f2d092"))
		draw_string(JP_FONT, Vector2(56, 366), "獲得した経験値", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("c9daf5"))
		draw_string(JP_FONT, Vector2(322, 366), "+%d" % result_xp, HORIZONTAL_ALIGNMENT_RIGHT, 54, 23, Color("bce7ff"))
		if result_levels > 0:
			draw_string(JP_FONT, Vector2(56, 422), "腕力レベルアップ！  Lv.%d" % arm_level, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("f4cb78"))
			draw_string(JP_FONT, Vector2(56, 448), "最大腕力 +%d" % (result_levels * 12), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("d9e5ff"))
		else:
			draw_string(JP_FONT, Vector2(56, 422), "腕力 Lv.%d　経験値 %d / %d" % [arm_level, int(level_xp), int(_need_xp())], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("d9e5ff"))
	else:
		draw_string(JP_FONT, Vector2(56, 328), "王女は力尽き、遠征は失敗した。", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("f2c4d4"))
		draw_string(JP_FONT, Vector2(56, 367), "今回獲得した鉱石・経験値は失われた。", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("d9e5ff"))
		draw_string(JP_FONT, Vector2(56, 420), "失った鉱石　+0", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("a9bfdc"))
		draw_string(JP_FONT, Vector2(56, 450), "失った経験値　+0", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("a9bfdc"))
	draw_string(JP_FONT, Vector2(56, 555), "セーブ%dに現在の進行を記録します。" % (selected_slot + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("c9daf5"))
	_button(Rect2(40, 640, 352, 58), "セーブして自室へ戻る", Color("4d6680"))

func _resonance_color() -> Color:
	match _resonance_type():
		"break": return Color("ffb35f")
		"swift": return Color("b890ff")
		"ward": return Color("78e7d2")
		"mend": return Color("ff8fb5")
	return Color.TRANSPARENT

func _draw_resonance_effect(shield_pos: Vector2, shield_radius: float) -> void:
	if _resonance_type().is_empty() or shield_lift < 0.92:
		return
	# 砕岩共鳴は満タン時点で王女へ移るため、盾側には待機エフェクトを残さない。
	if resonance_ready and _resonance_type() == "break":
		return
	var color := _resonance_color()
	var charge_ratio := resonance_charge / RESONANCE_GUARD_GOAL
	var ring_radius := shield_radius + 12.0 + charge_ratio * 17.0
	var spin := battle_clock * (2.3 if resonance_ready else 1.1)
	draw_circle(shield_pos, ring_radius, Color(color, 0.045 + charge_ratio * 0.06))
	draw_arc(shield_pos, ring_radius, spin, spin + TAU * (0.20 + charge_ratio * 0.56), 26, Color(color, 0.42 + charge_ratio * 0.36), 2.0, true)
	if resonance_ready:
		for index in range(6):
			var angle := spin + TAU * float(index) / 6.0
			var spark := shield_pos + Vector2(cos(angle), sin(angle)) * (ring_radius + 8.0)
			draw_circle(spark, 3.0, color)
		draw_string(JP_FONT, shield_pos + Vector2(-43, -ring_radius - 14), _resonance_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
	if resonance_flash > 0.0:
		draw_circle(shield_pos, ring_radius + (1.0 - resonance_flash / 0.62) * 34.0, Color(color, 0.38 * resonance_flash / 0.62))

func _draw_hud() -> void:
	# Keep the central upper field clear so the giant can always be read at a glance.
	draw_rect(Rect2(14, 14, 204, 74), Color(0.02, 0.04, 0.10, 0.82), true)
	draw_rect(Rect2(226, 14, 192, 74), Color(0.02, 0.04, 0.10, 0.82), true)
	draw_string(JP_FONT, Vector2(26, 39), str(_boss_data()["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	draw_rect(Rect2(26, 49, 176, 10), Color("2c2940"), true)
	draw_rect(Rect2(26, 49, 176 * boss_hp / boss_hp_max, 10), Color("d8709b"), true)
	draw_string(JP_FONT, Vector2(26, 79), "敵HP %d%%　鉱石 +%d" % [int(100.0 * boss_hp / boss_hp_max), run_ore], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f3c8d7"))
	draw_string(JP_FONT, Vector2(238, 39), "腕力 %d / %d　王女 %d / %d" % [int(stamina), int(cap), princess_hp, PRINCESS_HP_MAX], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("d9e5ff"))
	draw_rect(Rect2(238, 49, 166, 8), Color("102038"), true)
	draw_rect(Rect2(238, 49, 166 * stamina / base_cap, 8), Color("66c8d9"), true)
	if not _resonance_type().is_empty():
		var resonance_status := "%s 蓄積 %d / %d" % [_resonance_name(), int(resonance_charge), int(RESONANCE_GUARD_GOAL)]
		if resonance_ready:
			resonance_status = "砕岩共鳴 王女に付与中" if _resonance_type() == "break" else "%s 待機中" % _resonance_name()
		elif princess_cast_empowered:
			resonance_status = "砕岩共鳴 強化詠唱中"
		draw_string(JP_FONT, Vector2(238, 76), resonance_status, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, _resonance_color())
		draw_rect(Rect2(238, 80, 166, 5), Color("102038"), true)
		var meter_ratio := 1.0 if (resonance_ready and _resonance_type() != "break") or princess_cast_empowered else resonance_charge / RESONANCE_GUARD_GOAL
		draw_rect(Rect2(238, 80, 166 * meter_ratio, 5), _resonance_color(), true)
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
