# Monster Merge art drop-in

The game uses these PNGs automatically when they exist. Missing files fall
back to the built-in drawn art, so you can add them one at a time.

```
art/monsters/tier_1.png ... tier_8.png   (8 monsters, transparent background)
art/bosses/boss_1.png  ... boss_5.png    (5 bosses, cycle every 5 levels)
```

- Size: 512x512 PNG, transparent background, creature centered with some padding.
- Style: dark-fantasy, strong rim light, front or 3/4 view, no text, no border.
- Add them in Termux, then commit and push (GitHub Actions imports them):

```bash
cd ~/Monster-Merge
mkdir -p art/monsters art/bosses
cp ~/storage/downloads/tier_*.png art/monsters/
cp ~/storage/downloads/boss_*.png art/bosses/
git add art && git commit -m "Add monster and boss art" && git push origin main
```

Tier names (for prompts): 1 Blue Spotted Egg, 2 Cute Green Slime, 3 Baby Green Dino,
4 Winged Flame Wyrm, 5 Golden Phoenix, 6 Crystal Unicorn, 7 Robo-Rex, 8 Cosmic King Dragon.

Prompt template:
"dark fantasy mobile game monster, <NAME>, glowing eyes, rim lighting, painterly
stylized 3D render look, centered, transparent background, 512x512, no text"
