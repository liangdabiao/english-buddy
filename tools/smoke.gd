extends SceneTree

const ProgressStoreScript = preload("res://scripts/ProgressStore.gd")

var app
var failures := 0
var save_existed := false
var save_backup := ""
var backup_existed := false
var backup_data := ""


func _init() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("SMOKE FAIL: " + message)


func _run() -> void:
	print("SMOKE_STEP start")
	save_existed = File.new().file_exists("user://english_buddy_profile.json")
	if save_existed:
		var file := File.new()
		file.open("user://english_buddy_profile.json", File.READ)
		save_backup = file.get_as_text()
		file.close()
	backup_existed = File.new().file_exists("user://english_buddy_profile.bak")
	if backup_existed:
		var file := File.new()
		file.open("user://english_buddy_profile.bak", File.READ)
		backup_data = file.get_as_text()
		file.close()
	var directory := Directory.new()
	directory.remove("user://english_buddy_profile.json")
	directory.remove("user://english_buddy_profile.bak")

	print("SMOKE_STEP profile_ready")
	var packed := load("res://scenes/Main.tscn")
	app = packed.instance()
	get_root().add_child(app)
	yield(self, "idle_frame")
	yield(self, "idle_frame")
	check(app.repo.courses.size() == 20, "expected 20 L1 nodes")
	check(app.repo.dictionary.size() == 275, "expected 275 dictionary entries")
	check(app.screen == "onboarding", "first launch should show hatching")
	yield(self, "idle_frame")
	_capture("01_onboarding")
	print("SMOKE_STEP onboarding")

	app.progress.hatch_buddy()
	app._show_home()
	yield(self, "idle_frame")
	check(app.screen == "home" and app.menu_panels.size() == 5, "home menu missing")
	yield(self, "idle_frame")
	_capture("02_home")

	app._open_course(0)
	yield(self, "idle_frame")
	check(app.screen == "reader", "reader did not open")
	check(app.word_view.words.size() > 0, "reader has no timed words")
	yield(self, "idle_frame")
	_capture("03_reader")
	print("SMOKE_STEP reader")
	app._play_reader()
	yield(self.create_timer(0.45), "timeout")
	check(app.audio.playing, "reader audio did not start")
	check(app.audio.current_word_index() >= 0, "playback position did not highlight a word")
	app.audio.stop()
	print("SMOKE_STEP audio")

	app._open_dictionary("apple", "l1_001")
	check(app.dictionary_open and not app.dictionary_entry.empty(), "dictionary lookup failed")
	yield(self, "idle_frame")
	_capture("04_dictionary")
	app._toggle_dictionary_favorite()
	check(app.progress.is_favorite("apple"), "favorite was not saved")
	app._close_dictionary()

	app._start_quiz(0)
	_check_image_quiz_answers()
	check(app.quiz_state == "result", "quiz did not reach result")
	check(bool(app.quiz_result.get("passed", false)), "perfect quiz should pass")
	check(app.progress.is_completed("node_l1_01"), "completion was not saved")
	check(int(app.progress.data.magicPower) > 0, "reward was not granted")
	check(app.progress.data.vocabulary.size() > 0, "lesson words were not learned")
	var first_reward := int(app.progress.data.magicPower)
	yield(self, "idle_frame")
	_capture("05_result")
	app._start_quiz(0)
	_check_image_quiz_answers()
	check(int(app.progress.data.magicPower) == first_reward, "repeat lesson granted duplicate rewards")

	var due_before_review: int = app.progress.due_count()
	app._show_review()
	check(not app.review_words.empty(), "review has no due words")
	while app.review_index < app.review_words.size():
		var entry: Dictionary = app.repo.get_dictionary_entry(app.review_words[app.review_index])
		var correct := String(entry.get("meaningCn", ""))
		var option_index := int(app.review_options.find(correct))
		check(option_index >= 0, "review options missing correct answer")
		app._answer_review(option_index)
		app._review_next()
	var due_after_review: int = app.progress.due_count()
	check(due_after_review == max(0, due_before_review - app.review_words.size()), "review did not reschedule words")

	app._start_quiz(14)
	var builder_seen := false
	while app.quiz_state != "result":
		var item: Dictionary = app.quiz_items[app.quiz_index]
		if item.type == "word_builder":
			builder_seen = true
			var target := String(item.correctAnswer)
			while app.quiz_built.size() < target.length():
				var needed := target[app.quiz_built.size()]
				var letter_index := -1
				for index in range(app.quiz_bank.size()):
					if not app.quiz_used[index] and app.quiz_bank[index] == needed:
						letter_index = index
						break
				check(letter_index >= 0, "word builder is missing a required letter")
				app._add_letter(letter_index)
		else:
			var correct_index := -1
			for index in range(item.options.size()):
				if String(item.options[index].value) == String(item.correctAnswer):
					correct_index = index
			app._answer_question(correct_index)
		if app.quiz_state == "feedback":
			app._quiz_next()
	check(builder_seen, "word builder quiz was not exercised")
	check(app.progress.is_completed("node_l1_15"), "word builder lesson did not complete")

	app.progress.save_game()
	var reloaded = ProgressStoreScript.new()
	get_root().add_child(reloaded)
	reloaded.load_game()
	check(reloaded.data.completed.size() >= 2, "saved completions did not reload")
	check(reloaded.is_favorite("apple"), "saved favorite did not reload")
	reloaded.free()

	app._show_home()
	yield(self, "idle_frame")
	_capture("06_home_progress")
	print("SMOKE_STEP finished")
	_restore_save(directory)
	print("SMOKE_RESULT failures=%d courses=%d dictionary=%d completed=%d favorites=%d" % [failures, app.repo.courses.size(), app.repo.dictionary.size(), app.progress.completed_count(), app.progress.data.favorites.size()])
	quit(0 if failures == 0 else 1)


func _check_image_quiz_answers() -> void:
	while app.quiz_state != "result":
		var item: Dictionary = app.quiz_items[app.quiz_index]
		if item.type == "image_choice":
			var correct_index := -1
			for index in range(item.options.size()):
				if String(item.options[index].value) == String(item.correctAnswer):
					correct_index = index
			check(correct_index >= 0, "image quiz missing correct option")
			app._answer_question(correct_index)
		else:
			check(false, "unexpected quiz type in image quiz")
		if app.quiz_state == "feedback":
			app._quiz_next()


func _capture(name: String) -> void:
	var directory := Directory.new()
	if not directory.dir_exists("res://.build/screenshots"):
		directory.make_dir_recursive("res://.build/screenshots")
	var image := get_root().get_texture().get_data()
	image.flip_y()
	var result := image.save_png("res://.build/screenshots/" + name + ".png")
	check(result == OK, "screenshot capture failed: " + name)


func _restore_save(directory: Directory) -> void:
	directory.remove("user://english_buddy_profile.json")
	directory.remove("user://english_buddy_profile.bak")
	directory.remove("user://english_buddy_profile.tmp")
	var file := File.new()
	if save_existed:
		file.open("user://english_buddy_profile.json", File.WRITE)
		file.store_string(save_backup)
		file.close()
	if backup_existed:
		file.open("user://english_buddy_profile.bak", File.WRITE)
		file.store_string(backup_data)
		file.close()
