extends Node

const TURN_THRESHOLD = 1000

@onready var dungeon = get_tree().get_root().get_node("Main/Dungeon")
@onready var player = get_tree().get_root().get_node("Main/Dungeon/Player")
@onready var camera: Camera3D = get_viewport().get_camera_3d()
@onready var battle_ui = $BattleUI
@onready var enemy_grid = $EnemyFormation

enum BattleState {
	IDLE,
	PROCESS_TURNS,
	PLAYER_TURN,
	ENEMY_TURN,
	ANIMATING,
	CHECK_END,
	WIN,
	LOSE
}

var current_state = BattleState.IDLE

var party: Array[CharacterInstance] = []
var enemies: Array[CharacterInstance] = []
var battlers: Array[CharacterInstance] = []
var turn_queue: Array[CharacterInstance] = []
var enemy_slots: Array[Node] = []

func _ready():
	TargetingManager.configure_for_battle(camera)
	TargetingManager.connect("target_clicked", Callable(self, "_on_enemy_target_selected"))
	TargetingManager.connect("target_hovered", Callable(self, "_on_enemy_hovered"))
	TargetingManager.connect("target_unhovered", Callable(self, "_on_enemy_unhovered"))
	battle_ui.action_selected.connect(_on_player_action_selected)
	battle_ui.hide()
	party = PartyManager.members
	var skeleton = CharacterRegistry.get_character(101)
	var instance3 = CharacterInstance.new(skeleton)
	var instance4 = CharacterInstance.new(skeleton)
	var instance5 = CharacterInstance.new(skeleton)
	var instance6 = CharacterInstance.new(skeleton)
	var instance7 = CharacterInstance.new(skeleton)
	var instance8 = CharacterInstance.new(skeleton)

	enemies.append(instance3)
	enemies.append(instance4)
	
	load_enemies()

	battlers = party + enemies
	for b in battlers:
		b.turn_meter = 0

	current_state = BattleState.PROCESS_TURNS

func _process(_delta):
	match current_state:
		BattleState.PROCESS_TURNS:
			_process_turn_queue()
		BattleState.PLAYER_TURN:
			pass
		BattleState.ENEMY_TURN:
			_process_enemy_turn()
		BattleState.ANIMATING:
			pass
		BattleState.CHECK_END:
			_check_end_conditions()
		BattleState.WIN:
			_handle_win()
		BattleState.LOSE:
			_handle_lose()

func load_enemies():
	enemy_grid.place_all_enemies(enemies)

func _process_turn_queue():
	while turn_queue.is_empty():
		for b in battlers:
			if b.current_health <= 0:
				continue
			b.turn_meter += b.speed
			if b.turn_meter >= TURN_THRESHOLD and not turn_queue.has(b):
				turn_queue.append(b)

	if not turn_queue.is_empty():
		var next_battler = turn_queue.pop_front()
		next_battler.turn_meter -= TURN_THRESHOLD
		_start_turn(next_battler)

func _start_turn(battler: CharacterInstance):
	if battler.current_health <= 0:
		return
	if battler in party:
		current_state = BattleState.PLAYER_TURN
		TargetingManager.enable_targeting()
		print("Player turn for:", battler.resource.name)
		battle_ui.show()
	else:
		current_state = BattleState.ENEMY_TURN
		_current_enemy = battler
		
func _on_player_action_selected(action: String):
	var target = enemies.pick_random()
	if target:
		player_action_selected(action, target)
	else:
		print("No valid enemy target.")

func _on_enemy_target_selected(target: EnemySlot):
	var character_instance = target.character_instance
	if current_state == BattleState.PLAYER_TURN:
		TargetingManager.disable_targeting()
		player_action_selected("attack", character_instance)

func player_action_selected(action: String, target: CharacterInstance):
	if action == "attack":
		var damage = 10
		target.current_health = max(0, target.current_health - damage)
		print("Player attacked ", target.resource.name, " for ", damage)

	current_state = BattleState.CHECK_END

var _current_enemy: CharacterInstance = null

func _process_enemy_turn():
	if _current_enemy == null:
		current_state = BattleState.CHECK_END
		return

	var valid_targets = party.filter(func(p): return p.current_health > 0)
	if valid_targets.is_empty():
		current_state = BattleState.CHECK_END
		return

	var target = valid_targets.pick_random()
	var damage = 5
	print(_current_enemy.resource.name, " attacked ", target.resource.name, " for ", damage)
	target.set_current_health(max(0, target.current_health - damage))

	_current_enemy = null
	current_state = BattleState.CHECK_END

func _check_end_conditions():
	if party.all(func(p): return p.current_health <= 0):
		current_state = BattleState.LOSE
	elif enemies.all(func(e): return e.current_health <= 0):
		current_state = BattleState.WIN
	else:
		current_state = BattleState.PROCESS_TURNS

func _handle_win():
	print("Victory! Handle rewards here.")
	EncounterManager.end_encounter("win")
	current_state = BattleState.IDLE
	#dungeon.visible = true
	#player.in_battle = false
	get_tree().get_root().get_node("Main").remove_child(self)
	queue_free()

func _handle_lose():
	print("Defeat! Handle game over here.")
	EncounterManager.end_encounter("lose")
	#current_state = BattleState.IDLE
	#dungeon.visible = true
	#player.in_battle = false
	get_tree().get_root().get_node("Main").remove_child(self)
	queue_free()

func _on_enemy_hovered(target: EnemySlot):
	target.hover()
	
func _on_enemy_unhovered(target: EnemySlot):
	target.unhover()
