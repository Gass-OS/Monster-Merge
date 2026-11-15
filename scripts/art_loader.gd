extends RefCounted
class_name ArtLoader

## Optional PNG art. If a file is missing the game falls back to the
## procedural (code-drawn) art, so the build never breaks.
##   res://art/monsters/tier_1.png ... tier_8.png
##   res://art/bosses/boss_1.png ... boss_5.png

static var _cache: Dictionary = {}

static func monster(tier: int) -> Texture2D:
	return _load("res://art/monsters/tier_%d.png" % tier)

static func boss(level: int) -> Texture2D:
	return _load("res://art/bosses/boss_%d.png" % (((level - 1) % 5) + 1))

static func _load(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			tex = res
	_cache[path] = tex
	return tex
