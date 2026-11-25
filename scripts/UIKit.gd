class_name UIKit
extends Reference

const FONT_PATH := "res://assets/fonts/ui.ttf"
# DengXian subset has no IPA extensions and no U+2726, so phonetics and the
# magic-power spark are drawn with this second face (DejaVu Sans Mono).
const IPA_FONT_PATH := "res://assets/fonts/ipa.ttf"
const BG := Color("101b1d")
const PANEL := Color("1a2c2c")
const PANEL_LIGHT := Color("27413b")
const LINE := Color("3c5b50")
const TEXT := Color("f3f1df")
const MUTED := Color("a9bbb0")
const GREEN := Color("83d69a")
const GOLD := Color("f4cc73")
const RED := Color("ef8b87")
const BLUE := Color("91bdf0")

var font_cache: Dictionary = {}
var ipa_font_cache: Dictionary = {}
var texture_cache: Dictionary = {}


func font(size: int) -> DynamicFont:
	if font_cache.has(size):
		return font_cache[size]
	var result := DynamicFont.new()
	result.font_data = load(FONT_PATH)
	result.size = size
	font_cache[size] = result
	return result


func ipa_font(size: int) -> DynamicFont:
	if ipa_font_cache.has(size):
		return ipa_font_cache[size]
	var result := DynamicFont.new()
	var data = load(IPA_FONT_PATH)
	result.font_data = data if data != null else load(FONT_PATH)
	result.size = size
	ipa_font_cache[size] = result
	return result


func style(background: Color, border: Color = Color(0, 0, 0, 0), radius: int = 10, border_width: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	return box


func panel(parent: Node, rect: Rect2, background: Color = PANEL, border: Color = LINE, radius: int = 10) -> Panel:
	var result := Panel.new()
	result.rect_position = rect.position
	result.rect_size = rect.size
	result.add_stylebox_override("panel", style(background, border, radius))
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result


func label(parent: Node, text: String, rect: Rect2, size: int = 20, color: Color = TEXT, align: int = 0, wrap: bool = false, custom_font: Font = null) -> Label:
	var result := Label.new()
	result.text = text
	result.rect_position = rect.position
	result.rect_size = rect.size
	result.add_font_override("font", custom_font if custom_font != null else font(size))
	result.add_color_override("font_color", color)
	result.align = align
	result.valign = 1
	result.autowrap = wrap
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result


func texture(parent: Node, path: String, rect: Rect2) -> TextureRect:
	var result := TextureRect.new()
	result.rect_position = rect.position
	result.rect_size = rect.size
	result.expand = true
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if path != "":
		if not texture_cache.has(path):
			texture_cache[path] = load(path)
		result.texture = texture_cache[path]
	parent.add_child(result)
	return result


func progress_bar(parent: Node, rect: Rect2, value: float, color: Color = GREEN) -> void:
	panel(parent, rect, Color("263833"), Color(0, 0, 0, 0), 5)
	if value > 0:
		var fill_width: float = max(4, rect.size.x * clamp(value, 0, 1))
		panel(parent, Rect2(rect.position, Vector2(fill_width, rect.size.y)), color, Color(0, 0, 0, 0), 5)
