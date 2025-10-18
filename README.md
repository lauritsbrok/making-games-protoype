# Making Games Prototype

Arcade survival shooter built in Godot 4.5. Stay alive against an endless wave of enemies while chaining mobility tools and temporary power ups.

## Gameplay Features
- **Scaling enemy threat** – Enemies spawn faster and with more health as time passes. Their pursuit speed now scales with their health, so late‑run foes are both tougher and quicker.
- **Responsive movement suite** – Sprint around the arena with smooth acceleration, double jump (on cooldown), air dash with knockback, and a short-range grapple teleport.
- **Auto-fire combat** – Energy bolts fire automatically toward the crosshair. Shots apply damage on hit and inherit upgrades like multi-shot or faster fire rate.
- **Player survivability** – A persistent health bar in the top-left tracks remaining HP. Taking damage adds brief invulnerability; death pauses the run.
- **Ability HUD** – Ability and power-up timers surface in the on-screen HUD so you can plan cooldown usage on the fly.
- **Power-up loop** – Fallen enemies can drop temporary boosts:
  - Multi Shot: radial burst of bullets each trigger.
  - Fast Fire: halves the fire interval.
  - Weaken Enemies: forces current enemies to 1 HP for a short window.

## Controls
- `WASD` / Arrow keys: Move relative to the camera
- Mouse movement: Aim
- `Space`: Jump / Double Jump
- `Shift`: Dash (knockback nearby enemies, starts cooldown timer)
- `E`: Grapple teleport
- `Esc`: Release mouse cursor
- Mouse button (any): Recapture mouse cursor

## Project Layout
- `scenes/Main.tscn`: Main arena scene that wires the player, spawners, HUD, and environment.
- `scripts/player.gd`: Player movement, combat, abilities, and health management.
- `scripts/enemy.gd`: Enemy AI, health, contact damage, and health-scaling movement.
- `scripts/main.gd`: Game loop, enemy spawning logic, power-up drops, and HUD bindings.
- `scripts/ability_hud.gd` & `scripts/player_health_bar.gd`: UI for cooldowns and the player health bar.

## Running the Prototype
1. Open the project in Godot 4.5 (Mono edition if you want to use `godot-mono --check-only` for script validation).
2. Load `scenes/Main.tscn`.
3. Press Play to jump straight into the survival loop.

To verify scripts without launching the editor, run:

```bash
godot-mono --check-only
```

## Contributing / Extending
- Adjust difficulty via exports in `scripts/main.gd` (spawn timing, enemy health growth) and `scripts/enemy.gd` (contact damage, speed scaling).
- Tweak player feel in `scripts/player.gd` (movement speeds, cooldowns, invulnerability window).
- Add new power-ups by creating a scene and hooking it into `_maybe_spawn_power_up` in `scripts/main.gd`.
