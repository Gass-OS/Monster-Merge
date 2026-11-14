extends RefCounted
class_name GalleryArt

## Static helper for the high-res gallery showcase art (v1.2, Worker D).
##
## One large polished procedural PNG per tier lives in
## res://assets/gallery/tier1.png … tier8.png (1024x1024, drawn with
## tools/generate_gallery_art.py). This helper loads them on demand.
##
##   var tex := GalleryArt.load_showcase(tier)  # Texture2D or null
##   var tex := GalleryArt.load_showcase_or_silhouette(tier, unlocked)
##
## Returns null when the file is missing, so callers can fall back to a
## MonsterTile. Do NOT call this every frame — cache the result.

const ART_PATH := "res://assets/gallery/tier%d.png"

static func load_showcase(tier: int) -> Texture2D:
	if tier < 1 or tier > 8:
		return null
	var path := ART_PATH % tier
	if not ResourceLoader.exists(path):
		return null
	var tex := load(path)
	return tex as Texture2D

static func has_showcase(tier: int) -> bool:
	if tier < 1 or tier > 8:
		return false
	return ResourceLoader.exists(ART_PATH % tier)
