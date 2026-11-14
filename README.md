# Monster Merge 🎮

A portrait 2D monster evolution game for Android, built with Godot 4 and GDScript.

## Gameplay
- 4×4 board with 16 monster slots.
- Spawn a Tier 1 egg manually or automatically every 3 seconds.
- Drag matching monsters together to evolve through eight tiers.
- Earn +10 coins for every merge and passive coins from evolved monsters.
- Discover all eight creatures in the gallery.
- Automatically saves coins, discoveries and board state to `user://monster_merge_save.json`.

## Build
Every push to any branch starts **Monster Merge Android APK** in GitHub Actions. The downloadable artifact is named **Monster-Merge-Android-APK**.

The Android export targets arm64-v8a and locks the display to portrait.

## Monster evolution
1. Blue Spotted Egg
2. Cute Green Slime
3. Baby Green Dino
4. Winged Flame Wyrm
5. Golden Phoenix
6. Crystal Unicorn
7. Robo-Rex
8. Cosmic King Dragon

The initial art is generated procedurally in Godot, so no external asset packs or third-party runtime dependencies are required.
