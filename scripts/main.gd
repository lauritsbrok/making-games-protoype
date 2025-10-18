extends Node3D

@export var enemy_scene: PackedScene
@export var bullet_scene: PackedScene
@export var spawn_radius: float = 25.0
@export var spawn_interval: float = 2.5
@export var min_spawn_interval: float = 1.1
@export var enemy_health_start: float = 20.0
@export var enemy_health_growth: float = 4.0
@export_range(0.0, 1.0) var power_up_drop_chance: float = 0.2
@export var multi_shot_power_up_scene: PackedScene = preload("res://scenes/powerups/YellowPowerUp.tscn")
@export var fast_fire_power_up_scene: PackedScene = preload("res://scenes/powerups/RedPowerUp.tscn")
@export var weaken_enemies_power_up_scene: PackedScene = preload("res://scenes/powerups/PinkPowerUp.tscn")

@onready var player: CharacterBody3D = %Player
@onready var spawn_timer: Timer = %EnemySpawnTimer

var _enemies_spawned := 0
var _enemy_health_override_timer := 0.0


func _ready() -> void:
	randomize()
	if bullet_scene:
		player.bullet_scene = bullet_scene
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.start()
	set_process(true)
	_spawn_enemy()


func _on_spawn_timer_timeout() -> void:
	_spawn_enemy()
	var new_wait := spawn_timer.wait_time * 0.98
	spawn_timer.wait_time = max(min_spawn_interval, new_wait)


func _process(delta: float) -> void:
	if _enemy_health_override_timer > 0.0:
		_enemy_health_override_timer = max(0.0, _enemy_health_override_timer - delta)


func _spawn_enemy() -> void:
	if not enemy_scene or not is_instance_valid(player):
		return
	var enemy: Node3D = enemy_scene.instantiate()
	add_child(enemy)
	enemy.global_position = _random_spawn_position()
	enemy.setup(_current_enemy_health(), player)
	enemy.died.connect(_on_enemy_died)
	_enemies_spawned += 1


func _random_spawn_position() -> Vector3:
	var angle := randf() * PI * 2.0
	var offset := Vector3(cos(angle), 0.0, sin(angle)) * spawn_radius
	return player.global_position + offset


func _current_enemy_health() -> float:
	if _enemy_health_override_timer > 0.0:
		return 1.0
	return enemy_health_start + (enemy_health_growth * _enemies_spawned)


func _on_enemy_died(_enemy: Node) -> void:
	if _enemy and _enemy is Node3D:
		_maybe_spawn_power_up((_enemy as Node3D).global_position)


func _maybe_spawn_power_up(position: Vector3) -> void:
	if randf() > power_up_drop_chance:
		return
	var scenes := []
	if multi_shot_power_up_scene:
		scenes.append(multi_shot_power_up_scene)
	if fast_fire_power_up_scene:
		scenes.append(fast_fire_power_up_scene)
	if weaken_enemies_power_up_scene:
		scenes.append(weaken_enemies_power_up_scene)
	if scenes.is_empty():
		return
	var index := randi_range(0, scenes.size() - 1)
	var power_up_scene: PackedScene = scenes[index]
	var power_up := power_up_scene.instantiate()
	if power_up is Node3D:
		add_child(power_up)
		(power_up as Node3D).global_position = position
	elif power_up is Node2D:
		add_child(power_up)
		(power_up as Node2D).global_position = Vector2(position.x, position.z)


func apply_enemy_health_override(duration: float) -> void:
	_enemy_health_override_timer = max(_enemy_health_override_timer, duration)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("force_health"):
			enemy.force_health(1.0)
