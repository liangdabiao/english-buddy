extends Control

const UIKitScript = preload("res://scripts/UIKit.gd")

signal word_activated(index)

var words: Array = []
var selected_index := 0
var active_index := -1
var word_rects: Array = []
var ui_font: DynamicFont
var ui: UIKit


func _ready() -> void:
	ui = UIKitScript.new()
	ui_font = ui.font(25)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_clip_contents(true)
	connect("resized", self, "_on_resized")


func set_words(value: Array) -> void:
	words = value
	selected_index = 0
	active_index = -1
	update()


func set_active(index: int) -> void:
	if active_index != index:
		active_index = index
		update()


func move_selection(step: int) -> void:
	if words.empty():
		return
	selected_index = posmod(selected_index + step, words.size())
	update()


func move_vertical(direction: int) -> void:
	if word_rects.empty():
		return
	var current: Rect2 = word_rects[selected_index]
	var best := -1
	var best_distance := INF
	for index in range(word_rects.size()):
		var candidate: Rect2 = word_rects[index]
		if direction < 0 and candidate.end.y <= current.position.y + 4:
			var distance := abs(candidate.get_center().x - current.get_center().x) + (current.position.y - candidate.end.y)
			if distance < best_distance:
				best_distance = distance
				best = index
		elif direction > 0 and candidate.position.y >= current.end.y - 4:
			var distance := abs(candidate.get_center().x - current.get_center().x) + (candidate.position.y - current.end.y)
			if distance < best_distance:
				best_distance = distance
				best = index
	if best >= 0:
		selected_index = best
		update()


func selected_word() -> String:
	if selected_index >= 0 and selected_index < words.size():
		return words[selected_index].word
	return ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		for index in range(word_rects.size()):
			if word_rects[index].has_point(event.position):
				selected_index = index
				emit_signal("word_activated", index)
				update()
				accept_event()
				return


func _on_resized() -> void:
	update()


func _draw() -> void:
	word_rects.clear()
	if words.empty():
		return
	var cursor := Vector2(8, 10)
	var line_height := 42.0
	for index in range(words.size()):
		var text: String = words[index].word
		var text_size := ui_font.get_string_size(text)
		var width := text_size.x + 18
		if cursor.x + width > rect_size.x - 8:
			cursor.x = 8
			cursor.y += line_height
		var rect := Rect2(cursor, Vector2(width, 34))
		word_rects.append(rect)
		var fill := Color(0, 0, 0, 0)
		var text_color := ui.TEXT
		if index == active_index:
			fill = Color(0.34, 0.67, 0.43, 0.42)
			text_color = Color("d8ffe0")
		if index == selected_index:
			fill = Color(0.96, 0.80, 0.45, 0.24)
			draw_rect(rect, ui.GOLD, false, 2.0)
		if fill.a > 0:
			draw_rect(rect, fill)
		var baseline := cursor.y + 25
		draw_string(ui_font, Vector2(cursor.x + 9, baseline), text, text_color)
		cursor.x += width + 5
