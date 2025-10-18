extends Node3D

@export var enemy_scene: PackedScene
@export var bullet_scene: PackedScene
@export var spawn_radius: float = 25.0
@export var spawn_interval: float = 2.5
@export var min_spawn_interval: float = 1.1
@export var enemy_health_start: float = 20.0
@export var enemy_health_growth: float = 4.0

@onready var player: CharacterBody3D = %Player
@onready var spawn_timer: Timer = %EnemySpawnTimer

var _enemies_spawned := 0


func _ready() -> void:
	randomize()
	if bullet_scene:
		player.bullet_scene = bullet_scene
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.start()
	_spawn_enemy()


func _on_spawn_timer_timeout() -> void:
	_spawn_enemy()
	var new_wait := spawn_timer.wait_time * 0.98
	spawn_timer.wait_time = max(min_spawn_interval, new_wait)


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
	return enemy_health_start + (enemy_health_growth * _enemies_spawned)


func _on_enemy_died(_enemy: Node) -> void:
	# Reserved for future score keeping or difficulty adjustments.
	pass
