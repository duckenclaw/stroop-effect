class_name ColorUtil
## Single source of truth for the game's colors.
##
## A color's identity is the basename of its outline material: "blue.tres" is the color "blue".
## Everything that needs to compare, apply, or tint by color goes through here rather than
## re-deriving names from resource paths at the call site.

const MATERIALS_DIR := "res://assets/resources/materials/outline-materials"

## The colors that actually ship. Kept as an explicit list rather than a directory scan so the
## set is knowable without touching the filesystem at runtime.
const NAMES: Array[String] = ["blue", "green", "red"]

## Tint sources for the wind puffs and the speed trail. The outline materials carry a black
## outline_color and get their visible color from next_pass -> obstacle-materials/<color>.tres,
## whose color lives in an albedo_texture, so there is no Color to read off the material.
const TINTS := {
	"blue": Color(0.106, 0.259, 0.471),
	"green": Color(0.184, 0.439, 0.247),
	"red": Color(0.431, 0.031, 0.035),
}

static var _material_cache: Dictionary = {}

## The outline material for a color, or null if there isn't one.
static func material_for(color_name: String) -> ShaderMaterial:
	if _material_cache.has(color_name):
		return _material_cache[color_name]
	var material := load("%s/%s.tres" % [MATERIALS_DIR, color_name]) as ShaderMaterial
	if material == null:
		push_warning("ColorUtil: no outline material for color '%s'" % color_name)
	_material_cache[color_name] = material
	return material

## The color name a material represents. Only needed for nodes that carry a material but no
## script to remember the name for them.
static func name_of(material: Material) -> String:
	if material == null:
		return ""
	return material.resource_path.get_file().get_basename()

static func random_name() -> String:
	return NAMES.pick_random()

## The color's hue at full brightness. The stored tints are averages of dark albedo textures, so
## they read muddy as-is; normalising by the peak channel keeps the hue but restores the punch.
static func vivid(color_name: String) -> Color:
	var base: Color = TINTS.get(color_name, Color.WHITE)
	var peak := maxf(base.r, maxf(base.g, base.b))
	if peak <= 0.0:
		return base
	return Color(base.r / peak, base.g / peak, base.b / peak)
