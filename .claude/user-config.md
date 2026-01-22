Mobile Runner Game - Save Data & Customization Integration Plan

Overview

This plan outlines the integration of persistent save data, player customization (skins and trails),
and record tracking for your Godot mobile runner game.

  ---
1. Save Data Architecture

1.1 Data Structure

{
"player_data": {
"selected_skin": "default",
"selected_trail": "default",
"unlocked_skins": ["default"],
"unlocked_trails": ["default"]
},
"records": {
"high_score": 0.0,
"longest_distance": 0.0,
"total_games_played": 0,
"total_distance_traveled": 0.0
},
"settings": {
"sfx_volume": 1.0,
"music_volume": 1.0
}
}

1.2 Save System Implementation

- Location: Create new SaveManager.gd autoload singleton
- Save Method: Use ConfigFile or JSON serialization
- File Path: user://save_data.json
- Auto-save triggers:
    - On game over (save new records)
    - On customization change
    - On settings change

  ---
2. Player Skin System

2.1 Skin Architecture

Current State: Player uses materials from materials_path for color changes
Enhancement: Add mesh/material variants for different skins

2.2 Skin Structure

res://assets/skins/
├── default/
│   └── player_mesh.tres
├── robot/
│   └── player_mesh.tres
├── neon/
│   └── player_mesh.tres

2.3 Implementation Changes

File: player.gd
- Add @export var current_skin: String = "default"
- Add var skins_path = "res://assets/skins/"
- Create load_skin(skin_name: String) function
- Modify change_color() to apply color to current skin mesh

  ---
3. Trail System

3.1 Trail Architecture

- Type: GPUParticles3D or CPUParticles3D attached to player
- Variants: Different particle effects (sparkles, energy, fire, etc.)

3.2 Trail Structure

res://assets/trails/
├── default.tscn (GPUParticles3D scene)
├── sparkle.tscn
├── energy.tscn
├── fire.tscn

3.3 Implementation Changes

File: player.gd
- Add @onready var trail_container: Node3D = $TrailContainer
- Add var current_trail: Node3D
- Create load_trail(trail_name: String) function
- Create update_trail_color() to match player color

  ---
4. Records System

4.1 Tracking Implementation

File: terrain_controller.gd
- Already tracks distance (line 15, 93)
- Expose distance via signal or getter

File: player.gd
- Already tracks points (line 42)
- Add var game_distance: float = 0.0

4.2 Record Comparison & Saving

On Game Over:
1. Compare current score vs high_score
2. Compare current distance vs longest_distance
3. Update records if beaten
4. Save to file via SaveManager
5. Show "NEW RECORD!" UI feedback

  ---
5. UI Integration

5.1 New UI Screens

Customization Menu

- Skins Tab: Grid of unlockable skins with preview
- Trails Tab: Grid of unlockable trails with preview
- Preview Area: 3D viewport showing player with selected customization

Records/Stats Screen

- High Score display
- Longest Distance display
- Total Games Played
- Total Distance Traveled
- Average Score per Run

5.2 Main Menu Updates

- Add "Customize" button
- Add "Records" button
- Show current skin/trail on main menu player preview

  ---
6. Unlock System (Optional Enhancement)

6.1 Unlock Criteria

{
"skins": {
"robot": {"type": "distance", "requirement": 500.0},
"neon": {"type": "score", "requirement": 1000.0},
"golden": {"type": "games_played", "requirement": 50}
},
"trails": {
"sparkle": {"type": "distance", "requirement": 250.0},
"energy": {"type": "score", "requirement": 500.0}
}
}

6.2 Check & Unlock Logic

- Run after each game
- Check if requirements met
- Show unlock notification
- Update unlocked_skins / unlocked_trails

  ---
7. Implementation Steps

Phase 1: Core Save System (Priority: High)

1. ✅ Create SaveManager.gd autoload
2. ✅ Implement save/load JSON functions
3. ✅ Create default save data structure
4. ✅ Test save persistence across sessions

Phase 2: Records Tracking (Priority: High)

1. ✅ Add record variables to SaveManager
2. ✅ Connect to player lose signal
3. ✅ Implement record comparison logic
4. ✅ Create Records UI screen
5. ✅ Test record persistence

Phase 3: Skin System (Priority: Medium)

1. ✅ Create skin directory structure
2. ✅ Design 3-5 base skins
3. ✅ Implement load_skin() in player.gd
4. ✅ Update change_color() to work with skins
5. ✅ Create Customization UI (Skins tab)
6. ✅ Integrate with SaveManager

Phase 4: Trail System (Priority: Medium)

1. ✅ Create trail particle scenes
2. ✅ Design 3-5 base trails
3. ✅ Implement load_trail() in player.gd
4. ✅ Add trail color synchronization
5. ✅ Create Customization UI (Trails tab)
6. ✅ Integrate with SaveManager

Phase 5: Unlock System (Priority: Low)

1. ✅ Define unlock requirements
2. ✅ Implement unlock checking logic
3. ✅ Create unlock notification UI
4. ✅ Test progression system

Phase 6: Polish (Priority: Low)

1. ✅ Add 3D preview in customization menu
2. ✅ Add unlock animations
3. ✅ Add "NEW RECORD!" screen effect
4. ✅ Mobile touch optimization
5. ✅ Save data migration system (for updates)

  ---
8. File Structure Overview

stroop-effect/
├── src/
│   ├── player/
│   │   └── player.gd (enhanced with skin/trail loading)
│   ├── controllers/
│   │   └── terrain_controller.gd (expose distance)
│   ├── managers/
│   │   └── save_manager.gd (NEW - autoload)
│   └── ui/
│       ├── customization_menu.tscn (NEW)
│       ├── customization_menu.gd (NEW)
│       ├── records_screen.tscn (NEW)
│       └── records_screen.gd (NEW)
├── assets/
│   ├── skins/ (NEW)
│   │   ├── default/
│   │   ├── robot/
│   │   └── neon/
│   └── trails/ (NEW)
│       ├── default.tscn
│       ├── sparkle.tscn
│       └── energy.tscn

  ---
9. Mobile Considerations

9.1 Performance

- Use CPUParticles3D instead of GPU particles for better mobile compatibility
- Limit particle count on lower-end devices
- Cache loaded skins/trails to avoid runtime loading

9.2 Touch UI

- Large touch targets (minimum 44x44 dp)
- Swipe gestures for customization browsing
- Touch-friendly preview rotation in 3D view

9.3 Storage

- Keep save file under 10KB
- Compress data if needed
- Add cloud save support (Google Play Games / Game Center) later

  ---
10. Testing Checklist

- Save data persists after app close
- Records update correctly on game over
- Skin changes apply immediately
- Trail changes apply immediately
- Unlocks trigger at correct thresholds
- UI responsive on various screen sizes
- No performance drops with trails active
- Save data handles missing files gracefully
- Migration works when adding new features

  ---
This plan provides a structured approach to adding persistent save data and customization to your
mobile runner game. Start with Phase 1 & 2 for core functionality, then expand to customization
features.