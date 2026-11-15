# Monster Merge art drop-in

The game uses these PNGs automatically when they exist. Missing files fall
back to the built-in drawn art, so you can add them one at a time.

```
art/monsters/tier_1.png ... tier_8.png   (8 monsters, transparent background)
art/bosses/boss_1.png  ... boss_5.png    (bosses, cycle every 5 levels)
```

- Size: 512x512 PNG, transparent background, creature centered with some padding.
- Style: strong rim light, front or 3/4 view, no text, no border.
- Add them in Termux, then commit and push (GitHub Actions imports them):

```bash
cd ~/Monster-Merge
mkdir -p art/monsters art/bosses
cp ~/storage/downloads/tier_*.png art/monsters/
git add art && git commit -m "Add monster art" && git push origin main
```

Tier names: 1 Blue Spotted Egg, 2 Cute Green Slime, 3 Baby Green Dino,
4 Winged Flame Wyrm, 5 Golden Phoenix, 6 Crystal Unicorn, 7 Robo-Rex, 8 Cosmic King Dragon.
