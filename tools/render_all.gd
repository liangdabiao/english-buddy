extends SceneTree

# Renders every screen of the app to PNG so layout can be inspected.
var app
var shot := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/Main.tscn")
	app = packed.instance()
	get_root().add_child(app)
	yield(self, "idle_frame")
	yield(self, "idle_frame")

	app.progress.hatch_buddy()
	app._show_home()
	yield(self, "idle_frame")
	yield(self, "idle_frame")

	app._show_courses()
	yield(self, "idle_frame")
	yield(self, "idle_frame")
	_capture("10_courses")

	app._show_settings()
	yield(self, "idle_frame")
	yield(self, "idle_frame")
	_capture("11_settings")

	app._show_controls()
	yield(self, "idle_frame")
	yield(self, "idle_frame")
	_capture("12_controls")

	# Word builder quiz = course index 14 (node_l1_15)
	app._start_quiz(14)
	yield(self, "idle_frame")
	yield(self, "idle_frame")
	var item: Dictionary = app.quiz_items[app.quiz_index]
	print("BUILDER item type=", item.type, " bank=", app.quiz_bank)
	_capture("13_wordbuilder")

	# library
	app.progress.data.favorites = ["apple", "cat", "dog", "red", "sun", "tree", "book", "milk", "book"]
	app._show_library()
	yield(self, "idle_frame")
	yield(self, "idle_frame")
	_capture("14_library")

	# review screen
	app._show_review()
	yield(self, "idle_frame")
	yield(self, "idle_frame")
	_capture("15_review")

	# quiz result screen
	app._start_quiz(0)
	while app.quiz_state != "result":
		var qi: Dictionary = app.quiz_items[app.quiz_index]
		if qi.type == "image_choice":
			var ci := -1
			for index in range(qi.options.size()):
				if String(qi.options[index].value) == String(qi.correctAnswer):
					ci = index
			app._answer_question(ci)
		if app.quiz_state == "feedback":
			app._quiz_next()
	yield(self, "idle_frame")
	yield(self, "idle_frame")
	_capture("16_result")

	# dictionary overlay
	app._open_dictionary("apple", "l1_001")
	yield(self, "idle_frame")
	yield(self, "idle_frame")
	_capture("17_dictionary")

	print("DONE")
	quit(0)


func _capture(name: String) -> void:
	var directory := Directory.new()
	if not directory.dir_exists("res://.build/screenshots"):
		directory.make_dir_recursive("res://.build/screenshots")
	var image := get_root().get_texture().get_data()
	image.flip_y()
	image.save_png("res://.build/screenshots/" + name + ".png")
