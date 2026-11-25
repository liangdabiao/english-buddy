extends Control

const ContentRepositoryScript = preload("res://scripts/ContentRepository.gd")
const ProgressStoreScript = preload("res://scripts/ProgressStore.gd")
const AudioDirectorScript = preload("res://scripts/AudioDirector.gd")
const WordViewScript = preload("res://scripts/WordView.gd")
const UIKitScript = preload("res://scripts/UIKit.gd")
const ChromeScript = preload("res://scripts/Chrome.gd")
const PAGE_SIZE := 9

var repo
var progress
var audio
var ui: UIKit
var background: TextureRect
var chrome: Control
var screen_root: Control
var word_view
var dictionary_overlay: Control
var confirm_overlay: Control

var screen := "onboarding"
var title_text := "Magic English Buddy" setget _set_title_text
var footer_text := "" setget _set_footer_text
var menu_panels: Array = []
var menu_meta: Array = []
var menu_index := 0
var last_action_msec := 0

var hatch_hold := 0.0
var toast_text := ""
var toast_time := 0.0

var course_page := 0
var current_course_index := 0
var current_story: Dictionary = {}
var paragraph_index := 0
var reader_translation_visible := true
var reading_started_msec := 0

var quiz_items: Array = []
var quiz_index := 0
var quiz_correct := 0
var quiz_hints := 0
var quiz_state := "playing"
var quiz_feedback_correct := false
var quiz_hint_text := ""
var quiz_built: Array = []
var quiz_used: Array = []
var quiz_bank: Array = []
var quiz_result: Dictionary = {}

var review_words: Array = []
var review_index := 0
var review_correct := 0
var review_state := "playing"
var review_options: Array = []
var review_feedback_correct := false

var library_mode := 0
var library_page := 0
var dictionary_open := false
var dictionary_entry: Dictionary = {}
var dictionary_word := ""
var dictionary_story_id := ""
var reset_confirm := false


func _ready() -> void:
	ui = UIKitScript.new()
	repo = ContentRepositoryScript.new()
	progress = ProgressStoreScript.new()
	audio = AudioDirectorScript.new()
	add_child(repo)
	add_child(progress)
	add_child(audio)
	progress.content_repository = repo
	audio.set_sound_enabled(bool(progress.data.settings.sound))
	background = ui.texture(self, repo.background_path, Rect2(Vector2.ZERO, Vector2(640, 480)))
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	move_child(background, 0)
	chrome = ChromeScript.new()
	chrome.app = self
	chrome.rect_size = Vector2(640, 480)
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chrome)
	if progress.data.hatched:
		_show_home()
	else:
		_show_onboarding()


func _set_title_text(value: String) -> void:
	title_text = value
	_sync_chrome()


func _set_footer_text(value: String) -> void:
	footer_text = value
	_sync_chrome()


func _sync_chrome() -> void:
	if chrome != null and is_instance_valid(chrome):
		chrome.update()


func _process(delta: float) -> void:
	if toast_time > 0:
		toast_time -= delta
		if toast_time <= 0:
			toast_text = ""
			_sync_chrome()
	if screen == "onboarding" and not progress.data.hatched:
		if Input.is_action_pressed("accept"):
			hatch_hold += delta
			if hatch_hold >= 1.6:
				progress.hatch_buddy()
				_show_toast("孵化成功！你的学习伙伴醒来了")
				_show_home()
		else:
			hatch_hold = max(0, hatch_hold - delta * 2.0)
		_sync_chrome()
	if screen == "reader" and audio.playing and word_view != null:
		word_view.set_active(audio.current_word_index())


func _input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	if event is InputEventKey and event.echo:
		return
	var action := ""
	for candidate in ["nav_up", "nav_down", "nav_left", "nav_right", "accept", "back", "replay", "hint", "prev", "next", "menu"]:
		if event.is_action_pressed(candidate):
			action = candidate
			break
	if action == "":
		return
	var now := OS.get_ticks_msec()
	if now - last_action_msec < 70:
		return
	last_action_msec = now
	get_viewport().set_input_as_handled()
	match action:
		"nav_up": _navigate(-1, true)
		"nav_down": _navigate(1, true)
		"nav_left": _navigate(-1, false)
		"nav_right": _navigate(1, false)
		"accept": _accept()
		"back": _back()
		"replay": _replay()
		"hint": _hint()
		"prev": _previous()
		"next": _next()
		"menu": _learning_menu()


func draw_chrome(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 640, 54), Color(0.035, 0.075, 0.078, 0.94))
	ci.draw_rect(Rect2(0, 53, 640, 1), ui.LINE)
	ci.draw_string(ui.font(20), Vector2(20, 35), title_text, ui.TEXT)
	if progress != null and progress.data.hatched:
		var status := "%d  魔力   ·   %d/%d" % [int(progress.data.magicPower), progress.completed_count(), 20]
		var status_font := ui.font(15)
		var status_size := status_font.get_string_size(status)
		# U+2726 lives in the second face only, so the spark is drawn separately.
		var spark_font := ui.ipa_font(15)
		var spark_size := spark_font.get_string_size("✦")
		var spark_x := 620 - status_size.x - spark_size.x - 7
		ci.draw_string(spark_font, Vector2(spark_x, 33), "✦", ui.GOLD)
		ci.draw_string(status_font, Vector2(spark_x + spark_size.x + 7, 33), status, ui.GOLD)
	ci.draw_rect(Rect2(0, 444, 640, 36), Color(0.035, 0.075, 0.078, 0.94))
	ci.draw_rect(Rect2(0, 444, 640, 1), ui.LINE)
	ci.draw_string(ui.font(14), Vector2(20, 467), footer_text, ui.MUTED)
	if toast_text != "":
		var width := ui.font(17).get_string_size(toast_text).x + 40
		ci.draw_rect(Rect2((640 - width) / 2, 61, width, 38), Color(0.12, 0.25, 0.21, 0.96))
		ci.draw_string(ui.font(17), Vector2((640 - width) / 2 + 20, 87), toast_text, ui.GREEN)
	if screen == "onboarding":
		ci.draw_rect(Rect2(160, 414, 320, 12), Color("263833"))
		var fill_width: float = max(4, 320 * clamp(hatch_hold / 1.6, 0, 1))
		ci.draw_rect(Rect2(160, 414, fill_width, 12), ui.GOLD)


func _clear_screen() -> void:
	audio.stop()
	if is_instance_valid(screen_root):
		screen_root.free()
	screen_root = Control.new()
	screen_root.rect_size = Vector2(640, 480)
	screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen_root)
	# Keep the screen content between the background and the chrome overlay.
	move_child(screen_root, 1)
	menu_panels.clear()
	menu_meta.clear()
	menu_index = 0
	word_view = null
	dictionary_open = false
	dictionary_overlay = null
	reset_confirm = false
	confirm_overlay = null
	_sync_chrome()


func _show_onboarding() -> void:
	_clear_screen()
	screen = "onboarding"
	title_text = "Magic English Buddy"
	footer_text = "按住 A 孵化伙伴  ·  第一版离线英语学习"
	ui.label(screen_root, "SPROUT FOREST · 萌芽之森", Rect2(40, 82, 560, 30), 17, ui.GREEN, 1)
	ui.label(screen_root, "一颗蛋，正在等你的第一句英语", Rect2(40, 116, 560, 38), 25, ui.TEXT, 1)
	ui.texture(screen_root, repo.buddy_path(0), Rect2(220, 166, 200, 200))
	ui.label(screen_root, "按住 A 孵化你的学习伙伴", Rect2(80, 370, 480, 32), 23, ui.GOLD, 1)


func _show_home() -> void:
	_clear_screen()
	screen = "home"
	title_text = "Magic English Buddy"
	footer_text = "十字键/左摇杆 移动   A 确认   B 返回   Select 课程   Start 退出"
	ui.label(screen_root, "SPROUT FOREST", Rect2(28, 70, 250, 26), 16, ui.GREEN)
	ui.label(screen_root, "萌芽之森", Rect2(28, 94, 250, 40), 31, ui.TEXT)
	ui.texture(screen_root, repo.buddy_path(progress.buddy_stage()), Rect2(48, 142, 216, 216))
	ui.label(screen_root, progress.data.name, Rect2(28, 368, 260, 28), 20, ui.GOLD, 1)
	ui.label(screen_root, "成长 %d  ·  连胜 %d 天" % [int(progress.data.xp), int(progress.data.streak)], Rect2(28, 396, 260, 26), 16, ui.MUTED, 1)
	var next_index: int = progress.next_course_index()
	var next_course: Dictionary = repo.get_course(next_index)
	var items := [
		{"text": "继续学习 · " + String(next_course.get("titleCn", "课程")), "action": "continue", "enabled": true},
		{"text": "课程地图 · 20 个节点", "action": "courses", "enabled": true},
		{"text": "单词复习 · %d 到期" % progress.due_count(), "action": "review", "enabled": true},
		{"text": "我的词库 · %d 收藏" % progress.data.favorites.size(), "action": "library", "enabled": true},
		{"text": "设置与操作说明", "action": "settings", "enabled": true},
	]
	_build_menu(items, Rect2(304, 142, 312, 48), 54, 0)


func _show_courses() -> void:
	_clear_screen()
	screen = "courses"
	title_text = "萌芽之森 · 课程地图"
	footer_text = "上下键 选择   A 进入   B 首页   L/R 翻页   完成前一节点后解锁下一节点"
	var items := []
	var start := course_page * PAGE_SIZE
	for index in range(start, min(start + PAGE_SIZE, repo.courses.size())):
		var course: Dictionary = repo.get_course(index)
		var unlocked: bool = progress.is_unlocked(index)
		var completed: bool = progress.is_completed(course.id)
		var status: String = "已完成" if completed else ("锁定" if not unlocked else _course_type_name(course.type))
		items.append({
			"text": "%02d  %s · %s" % [index + 1, course.titleCn, course.title],
			"status": status,
			"icon": repo.emoji_path(course.emoji),
			"action": "course",
			"index": index,
			"enabled": unlocked,
		})
	_build_menu(items, Rect2(24, 66, 592, 35), 38, 0)
	ui.label(screen_root, "第 %d / %d 页" % [course_page + 1, int(ceil(float(repo.courses.size()) / PAGE_SIZE))], Rect2(430, 414, 186, 24), 14, ui.MUTED, 2)


func _course_type_name(type_name: String) -> String:
	match type_name:
		"boss": return "Boss"
		"bonus": return "奖励"
		"challenge": return "挑战"
	return "故事"


func _open_course(index: int) -> void:
	if not progress.is_unlocked(index):
		_show_toast("先完成前一个节点吧")
		return
	current_course_index = index
	current_story = repo.get_story(repo.get_course(index).storyId)
	paragraph_index = 0
	reader_translation_visible = bool(progress.data.settings.translation)
	reading_started_msec = OS.get_ticks_msec()
	_show_reader()


func _show_reader() -> void:
	_clear_screen()
	screen = "reader"
	title_text = String(current_story.get("titleCn", "阅读故事"))
	footer_text = "左右键 选词   A 查词   X 朗读   Y 翻译   L/R 翻段   末段 R 开始练习"
	var paragraph: Dictionary = current_story.content[paragraph_index]
	ui.label(screen_root, String(current_story.get("title", "")), Rect2(28, 64, 480, 26), 16, ui.MUTED)
	ui.label(screen_root, "段落 %d / %d" % [paragraph_index + 1, current_story.content.size()], Rect2(470, 64, 142, 26), 16, ui.GOLD, 2)
	ui.panel(screen_root, Rect2(24, 102, 592, 238), ui.PANEL, ui.LINE, 14)
	word_view = WordViewScript.new()
	word_view.rect_position = Vector2(34, 120)
	word_view.rect_size = Vector2(572, 202)
	word_view.set_words(paragraph.words)
	word_view.connect("word_activated", self, "_on_word_activated")
	screen_root.add_child(word_view)
	ui.progress_bar(screen_root, Rect2(28, 344, 584, 5), float(paragraph_index + 1) / float(current_story.content.size()), ui.GREEN)
	if reader_translation_visible:
		ui.label(screen_root, paragraph.translation, Rect2(32, 358, 576, 68), 19, ui.MUTED, 0, true)
	else:
		ui.label(screen_root, "Y 显示中文翻译", Rect2(32, 374, 576, 30), 18, ui.MUTED, 1)


func _on_word_activated(_index: int) -> void:
	_open_dictionary(word_view.selected_word(), String(current_story.get("id", "")))


func _play_reader() -> void:
	var paragraph: Dictionary = current_story.content[paragraph_index]
	if audio.playing:
		audio.stop()
		word_view.set_active(-1)
	else:
		audio.play(paragraph.audioFile, paragraph.words)


func _change_paragraph(step: int) -> void:
	var next_index := paragraph_index + step
	if next_index < 0 or next_index >= current_story.content.size():
		return
	paragraph_index = next_index
	_show_reader()


func _save_reading() -> void:
	if current_story.empty():
		return
	var story_id := String(current_story.get("id", ""))
	if story_id == "":
		return
	var seconds := int((OS.get_ticks_msec() - reading_started_msec) / 1000)
	progress.record_reading(story_id, seconds)


func _start_quiz(index: int) -> void:
	if screen == "reader":
		_save_reading()
	current_course_index = index
	current_story = repo.get_story(repo.get_course(index).storyId)
	quiz_items = current_story.get("quiz", []).duplicate(true)
	quiz_index = 0
	quiz_correct = 0
	quiz_hints = 0
	quiz_state = "playing"
	quiz_result = {}
	_prepare_quiz_item()
	_show_quiz()


func _show_quiz() -> void:
	_clear_screen()
	screen = "quiz"
	title_text = "练习 · " + String(current_story.get("titleCn", ""))
	if quiz_state == "result":
		_build_quiz_result()
		return
	if quiz_state == "feedback":
		_build_quiz_feedback()
		return
	if quiz_items.empty() or quiz_index < 0 or quiz_index >= quiz_items.size():
		footer_text = "A 确认   B 首页"
		ui.label(screen_root, "这一课暂时没有练习题", Rect2(60, 190, 520, 50), 26, ui.MUTED, 1)
		_build_menu([{"text": "回到首页", "action": "home", "enabled": true}], Rect2(170, 290, 300, 50), 0, 0)
		return
	var item: Dictionary = quiz_items[quiz_index]
	footer_text = "X 听相关故事   Y 提示   A 确认   B "
	footer_text += "撤回字母" if item.type == "word_builder" else "返回课程"
	ui.label(screen_root, "%d / %d" % [quiz_index + 1, quiz_items.size()], Rect2(28, 64, 584, 24), 15, ui.GOLD, 2)
	ui.label(screen_root, item.question, Rect2(40, 94, 560, 66), 24, ui.TEXT, 1, true)
	if quiz_hint_text != "":
		ui.label(screen_root, quiz_hint_text, Rect2(40, 158, 560, 28), 16, ui.GOLD, 1)
	if item.type == "word_builder":
		_build_word_builder(item)
	else:
		_build_image_choices(item)


func _build_image_choices(item: Dictionary) -> void:
	var items := []
	for option in item.get("options", []):
		items.append({
			"text": String(option.get("text", option.get("value", ""))),
			"icon": repo.emoji_path(String(option.get("image", ""))),
			"action": "answer",
			"index": items.size(),
			"enabled": true,
		})
	_build_menu(items, Rect2(104, 194, 432, 56), 64, 0)


func _build_word_builder(item: Dictionary) -> void:
	ui.label(screen_root, "你的答案", Rect2(40, 194, 560, 24), 15, ui.MUTED, 1)
	ui.panel(screen_root, Rect2(100, 222, 440, 62), Color("15231f"), ui.GREEN, 12)
	var answer := ""
	for token in quiz_built:
		answer += token
	ui.label(screen_root, answer if answer != "" else "_ _ _", Rect2(110, 232, 420, 42), 31, ui.GREEN, 1)
	var items := []
	for index in range(quiz_bank.size()):
		items.append({
			"text": quiz_bank[index],
			"action": "letter",
			"index": index,
			"align": 1,
			"enabled": not bool(quiz_used[index]),
		})
	_build_menu(items, Rect2(100, 292, 440, 46), 50, 0)


func _answer_question(option_index: int) -> void:
	if quiz_state != "playing":
		return
	if quiz_items.empty() or quiz_index >= quiz_items.size():
		return
	var item: Dictionary = quiz_items[quiz_index]
	if item.type == "word_builder":
		_add_letter(option_index)
		return
	if option_index < 0 or option_index >= item.get("options", []).size():
		return
	var option: Dictionary = item.options[option_index]
	quiz_feedback_correct = String(option.value) == String(item.correctAnswer)
	if quiz_feedback_correct:
		quiz_correct += 1
	quiz_state = "feedback"
	_show_quiz()


func _add_letter(index: int) -> void:
	if index < 0 or index >= quiz_bank.size() or quiz_used[index]:
		return
	quiz_used[index] = true
	quiz_built.append(quiz_bank[index])
	if quiz_built.size() == quiz_bank.size():
		_submit_word_builder()
	else:
		_show_quiz()


func _remove_letter() -> void:
	if quiz_built.empty():
		return
	var removed: String = quiz_built.pop_back()
	for index in range(quiz_bank.size()):
		if quiz_bank[index] == removed and quiz_used[index]:
			quiz_used[index] = false
			break
	_show_quiz()


func _submit_word_builder() -> void:
	if quiz_items.empty() or quiz_index >= quiz_items.size():
		return
	var answer := ""
	for token in quiz_built:
		answer += token
	quiz_feedback_correct = answer == String(quiz_items[quiz_index].correctAnswer)
	if quiz_feedback_correct:
		quiz_correct += 1
	quiz_state = "feedback"
	_show_quiz()


func _build_quiz_feedback() -> void:
	var item: Dictionary = quiz_items[quiz_index]
	footer_text = "A 下一题   X 再听一次"
	ui.panel(screen_root, Rect2(80, 142, 480, 236), Color("14241f"), ui.GREEN if quiz_feedback_correct else ui.RED, 16)
	ui.label(screen_root, "答对啦！" if quiz_feedback_correct else "再接再厉", Rect2(100, 164, 440, 48), 31, ui.GREEN if quiz_feedback_correct else ui.RED, 1)
	ui.label(screen_root, "正确答案", Rect2(110, 222, 400, 24), 15, ui.MUTED, 1)
	ui.label(screen_root, String(item.correctAnswer), Rect2(110, 250, 400, 52), 29, ui.TEXT, 1)
	ui.label(screen_root, "按 A 继续", Rect2(110, 322, 400, 28), 17, ui.GOLD, 1)


func _quiz_next() -> void:
	if quiz_index + 1 >= quiz_items.size():
		_finish_quiz()
		return
	quiz_index += 1
	quiz_state = "playing"
	quiz_hint_text = ""
	quiz_built.clear()
	quiz_used.clear()
	_prepare_quiz_item()
	_show_quiz()


func _prepare_quiz_item() -> void:
	quiz_bank.clear()
	quiz_used.clear()
	if quiz_items.empty() or quiz_index < 0 or quiz_index >= quiz_items.size():
		return
	var item: Dictionary = quiz_items[quiz_index]
	if item.type == "word_builder":
		quiz_bank = item.get("shuffledWords", []).duplicate()
		quiz_bank.shuffle()
		quiz_used.resize(quiz_bank.size())
		quiz_used.fill(false)


func _finish_quiz() -> void:
	var course: Dictionary = repo.get_course(current_course_index)
	quiz_result = progress.complete_lesson(course, quiz_correct, quiz_items.size(), quiz_hints)
	quiz_state = "result"
	_show_quiz()


func _build_quiz_result() -> void:
	var passed := bool(quiz_result.get("passed", false))
	title_text = "练习结果"
	footer_text = "A 确认   B 首页"
	ui.texture(screen_root, repo.buddy_path(progress.buddy_stage()), Rect2(42, 126, 190, 190))
	ui.label(screen_root, "通过！" if passed else "再试一次就能通过", Rect2(236, 100, 360, 50), 30, ui.GREEN if passed else ui.GOLD, 1)
	ui.label(screen_root, "本次正确  %d / %d" % [quiz_correct, quiz_items.size()], Rect2(236, 160, 360, 34), 22, ui.TEXT, 1)
	ui.label(screen_root, "魔法奖励  +%d" % int(quiz_result.get("reward", 0)), Rect2(236, 200, 360, 32), 20, ui.GOLD, 1)
	if not bool(quiz_result.get("firstPass", false)) and passed:
		ui.label(screen_root, "首次通过的奖励已经领取", Rect2(236, 234, 360, 26), 15, ui.MUTED, 1)
	var items := [{"text": "重新练习", "action": "retry", "enabled": true}]
	if passed and current_course_index < 19 and progress.is_unlocked(current_course_index + 1):
		items.append({"text": "下一课", "action": "next_course", "enabled": true})
	items.append({"text": "回到首页", "action": "home", "enabled": true})
	_build_menu(items, Rect2(236, 282, 360, 42), 48, 0)


func _show_review() -> void:
	_clear_screen()
	screen = "review"
	title_text = "单词复习"
	review_words = progress.due_words(10)
	review_index = 0
	review_correct = 0
	review_state = "playing"
	if review_words.empty():
		footer_text = "A 或 B 返回首页"
		ui.label(screen_root, "暂无到期单词", Rect2(60, 170, 520, 50), 31, ui.GREEN, 1)
		ui.label(screen_root, "完成课程或查词后，就能开始复习", Rect2(60, 226, 520, 40), 19, ui.MUTED, 1)
		_build_menu([{"text": "回到首页", "action": "home", "enabled": true}], Rect2(170, 304, 300, 50), 0, 0)
		return
	_build_review_question()


func _build_review_question() -> void:
	_clear_screen()
	screen = "review"
	title_text = "单词复习"
	if review_state == "feedback":
		footer_text = "A 继续"
		_build_review_feedback()
		return
	if review_index >= review_words.size():
		_build_review_result()
		return
	var word: String = review_words[review_index]
	var entry: Dictionary = repo.get_dictionary_entry(word)
	footer_text = "X 听故事中的单词   A 选择中文释义   B 首页"
	ui.label(screen_root, "%d / %d" % [review_index + 1, review_words.size()], Rect2(28, 64, 584, 24), 15, ui.GOLD, 2)
	ui.label(screen_root, entry.get("word", word), Rect2(40, 100, 560, 62), 38, ui.TEXT, 1)
	ui.label(screen_root, String(entry.get("phonetic", "")), Rect2(40, 160, 560, 28), 18, ui.MUTED, 1, false, ui.ipa_font(18))
	review_options = _make_meaning_options(entry)
	var items := []
	for option in review_options:
		items.append({"text": option, "action": "review_answer", "index": items.size(), "enabled": true})
	_build_menu(items, Rect2(70, 208, 500, 48), 54, 0)


func _make_meaning_options(correct_entry: Dictionary) -> Array:
	var correct := String(correct_entry.get("meaningCn", ""))
	var options := [correct]
	var attempts := 0
	while options.size() < 4 and attempts < 100:
		attempts += 1
		var candidate: Dictionary = repo.dictionary.values()[randi() % repo.dictionary.size()]
		var meaning := String(candidate.get("meaningCn", ""))
		if meaning != "" and int(options.find(meaning)) < 0:
			options.append(meaning)
	options.shuffle()
	return options


func _answer_review(index: int) -> void:
	if review_state != "playing":
		return
	var word: String = review_words[review_index]
	var entry: Dictionary = repo.get_dictionary_entry(word)
	review_feedback_correct = review_options[index] == String(entry.get("meaningCn", ""))
	if review_feedback_correct:
		review_correct += 1
	progress.record_review(word, review_feedback_correct)
	review_state = "feedback"
	_build_review_question()


func _build_review_feedback() -> void:
	var word: String = review_words[review_index]
	var entry: Dictionary = repo.get_dictionary_entry(word)
	ui.panel(screen_root, Rect2(70, 190, 500, 214), Color("14241f"), ui.GREEN if review_feedback_correct else ui.RED, 16)
	ui.label(screen_root, "记住了！" if review_feedback_correct else "下次会更好", Rect2(90, 210, 460, 46), 28, ui.GREEN if review_feedback_correct else ui.RED, 1)
	ui.label(screen_root, "%s  %s" % [entry.get("word", word), entry.get("meaningCn", "")], Rect2(90, 268, 460, 70), 22, ui.TEXT, 1, true)
	ui.label(screen_root, "按 A 继续", Rect2(90, 350, 460, 28), 17, ui.GOLD, 1)


func _review_next() -> void:
	review_index += 1
	review_state = "playing"
	_build_review_question()


func _build_review_result() -> void:
	footer_text = "A 返回首页   X 再复习一轮"
	ui.label(screen_root, "本轮复习完成", Rect2(60, 150, 520, 52), 32, ui.GREEN, 1)
	ui.label(screen_root, "答对 %d / %d" % [review_correct, review_words.size()], Rect2(60, 214, 520, 40), 24, ui.TEXT, 1)
	ui.label(screen_root, "按 A 返回首页", Rect2(60, 300, 520, 32), 19, ui.GOLD, 1)


func _show_library() -> void:
	_clear_screen()
	screen = "library"
	title_text = "我的词库"
	footer_text = "L/R 切换收藏/已学   A 查词   B 首页"
	ui.label(screen_root, "收藏" if library_mode == 0 else "已学", Rect2(28, 64, 300, 28), 18, ui.GOLD)
	var words: Array = progress.data.favorites.duplicate() if library_mode == 0 else progress.data.vocabulary.keys()
	words.sort()
	var start := library_page * PAGE_SIZE
	var items := []
	for index in range(start, min(start + PAGE_SIZE, words.size())):
		var word: String = words[index]
		var entry: Dictionary = repo.get_dictionary_entry(word)
		items.append({
			"text": "%s  %s" % [entry.get("word", word), entry.get("meaningCn", "")],
			"icon": repo.emoji_path(String(entry.get("emoji", "🔎"))),
			"action": "lookup",
			"word": word,
			"enabled": true,
		})
	if items.empty():
		ui.label(screen_root, "这里还是空的", Rect2(60, 190, 520, 44), 27, ui.MUTED, 1)
		ui.label(screen_root, "阅读时按 A 查词并收藏", Rect2(60, 240, 520, 34), 18, ui.MUTED, 1)
	else:
		_build_menu(items, Rect2(24, 96, 592, 32), 34, 0)
	ui.label(screen_root, "第 %d / %d 页" % [library_page + 1, max(1, int(ceil(float(words.size()) / PAGE_SIZE)))], Rect2(430, 414, 186, 24), 14, ui.MUTED, 2)


func _show_settings() -> void:
	_clear_screen()
	screen = "settings"
	title_text = "设置"
	footer_text = "A 切换   B 返回首页"
	var translation := bool(progress.data.settings.translation)
	var sound := bool(progress.data.settings.sound)
	var items := [
		{"text": "显示中文翻译 · " + ("开" if translation else "关"), "action": "translation", "enabled": true},
		{"text": "声音 · " + ("开" if sound else "关"), "action": "sound", "enabled": true},
		{"text": "操作说明", "action": "controls", "enabled": true},
		{"text": "清除学习记录", "action": "reset", "enabled": true},
		{"text": "返回首页", "action": "home", "enabled": true},
	]
	_build_menu(items, Rect2(70, 104, 500, 50), 58, 0)
	ui.label(screen_root, "学习记录只保存在这台设备，不联网，不需要账号。", Rect2(50, 408, 540, 28), 15, ui.MUTED, 1)


func _show_controls() -> void:
	_clear_screen()
	screen = "controls"
	title_text = "掌机操作说明"
	footer_text = "B 返回设置"
	var rows := [
		["十字键 / 左摇杆", "移动选择"],
		["A", "确认 / 查词 / 选择字母"],
		["B", "返回 / 关闭 / 撤回字母"],
		["X", "重播语音"],
		["Y", "翻译 / 提示"],
		["L / R", "翻段 / 翻页 / 切词库"],
		["Select", "学习菜单 / 首页"],
		["Start", "退出到 PortMaster"],
	]
	for index in range(rows.size()):
		var y := 78 + index * 42
		ui.panel(screen_root, Rect2(54, y, 532, 36), ui.PANEL, ui.LINE, 8)
		ui.label(screen_root, rows[index][0], Rect2(70, y + 3, 210, 30), 17, ui.GOLD)
		ui.label(screen_root, rows[index][1], Rect2(286, y + 3, 284, 30), 17, ui.TEXT)


func _build_menu(items: Array, rect: Rect2, spacing: float, columns: int) -> void:
	for index in range(items.size()):
		var item: Dictionary = items[index]
		var y: float = rect.position.y + index * spacing if spacing > 0 else rect.position.y + index * (rect.size.y + 8)
		var panel := ui.panel(screen_root, Rect2(rect.position.x, y, rect.size.x, rect.size.y), ui.PANEL, ui.LINE, 10)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.connect("gui_input", self, "_on_menu_gui_input", [index])
		var text_x := 18.0
		if String(item.get("icon", "")) != "":
			ui.texture(panel, item.icon, Rect2(8, 5, rect.size.y - 10, rect.size.y - 10))
			text_x = rect.size.y + 4
		var status: String = String(item.get("status", ""))
		var status_width: float = ui.font(14).get_string_size(status).x + 8 if status != "" else 0
		var align := int(item.get("align", 0))
		ui.label(panel, item.text, Rect2(text_x, 3, rect.size.x - text_x - status_width - 12, rect.size.y - 6), 17 if rect.size.y >= 40 else 15, ui.TEXT, align)
		if status != "":
			ui.label(panel, status, Rect2(rect.size.x - status_width - 8, 3, status_width, rect.size.y - 6), 13, ui.GREEN if status == "已完成" else ui.MUTED, 2)
		if not bool(item.get("enabled", true)):
			panel.modulate = Color(1, 1, 1, 0.42)
		menu_panels.append(panel)
		menu_meta.append(item)
	_refresh_menu()


func _refresh_menu() -> void:
	for index in range(menu_panels.size()):
		var selected := index == menu_index
		var enabled := bool(menu_meta[index].get("enabled", true))
		var background_color: Color = ui.PANEL_LIGHT if selected else ui.PANEL
		var border_color: Color = ui.GOLD if selected else ui.LINE
		menu_panels[index].add_stylebox_override("panel", ui.style(background_color, border_color, 10, 2 if selected else 1))
		if enabled:
			menu_panels[index].modulate = Color(1, 1, 1, 1)


func _on_menu_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		menu_index = index
		_refresh_menu()
		_activate_menu()


func _navigate(direction: int, vertical: bool) -> void:
	if dictionary_open:
		return
	if reset_confirm:
		return
	if screen == "reader" and word_view != null:
		if vertical:
			word_view.move_vertical(direction)
		else:
			word_view.move_selection(direction)
		return
	if menu_panels.empty():
		return
	if screen == "courses":
		var start := course_page * PAGE_SIZE
		var count: int = min(PAGE_SIZE, repo.courses.size() - start)
		if direction < 0 and menu_index == 0 and course_page > 0:
			course_page -= 1
			_show_courses()
			menu_index = max(0, min(PAGE_SIZE, repo.courses.size() - course_page * PAGE_SIZE) - 1)
			_refresh_menu()
			return
		if direction > 0 and menu_index == count - 1 and (course_page + 1) * PAGE_SIZE < repo.courses.size():
			course_page += 1
			_show_courses()
			return
	if screen == "library":
		var words: Array = progress.data.favorites.duplicate() if library_mode == 0 else progress.data.vocabulary.keys()
		var count: int = min(PAGE_SIZE, words.size() - library_page * PAGE_SIZE)
		if count > 0 and direction < 0 and menu_index == 0 and library_page > 0:
			library_page -= 1
			_show_library()
			menu_index = max(0, min(PAGE_SIZE, words.size() - library_page * PAGE_SIZE) - 1)
			_refresh_menu()
			return
		if count > 0 and direction > 0 and menu_index == count - 1 and (library_page + 1) * PAGE_SIZE < words.size():
			library_page += 1
			_show_library()
			return
	menu_index = posmod(menu_index + direction, menu_panels.size())
	_refresh_menu()


func _accept() -> void:
	if dictionary_open:
		_toggle_dictionary_favorite()
		return
	if reset_confirm:
		_confirm_reset()
		return
	if screen == "onboarding":
		return
	if screen == "reader":
		_open_dictionary(word_view.selected_word(), current_story.id)
		return
	if screen == "quiz" and quiz_state == "feedback":
		_quiz_next()
		return
	if screen == "review" and review_state == "feedback":
		_review_next()
		return
	if screen == "review" and review_index >= review_words.size():
		_show_home()
		return
	if not menu_panels.empty():
		_activate_menu()


func _activate_menu() -> void:
	if menu_index < 0 or menu_index >= menu_meta.size():
		return
	var item: Dictionary = menu_meta[menu_index]
	if not bool(item.get("enabled", true)):
		return
	var action := String(item.get("action", ""))
	match action:
		"continue": _open_course(progress.next_course_index())
		"courses": _show_courses()
		"review": _show_review()
		"library": _show_library()
		"settings": _show_settings()
		"home": _show_home()
		"course": _open_course(int(item.index))
		"answer": _answer_question(int(item.index))
		"letter": _add_letter(int(item.index))
		"retry": _start_quiz(current_course_index)
		"next_course": _open_course(current_course_index + 1)
		"review_answer": _answer_review(int(item.index))
		"lookup":
			dictionary_story_id = String(progress.data.vocabulary.get(item.word, {}).get("storyId", ""))
			_open_dictionary(item.word, dictionary_story_id)
		"translation":
			progress.set_setting("translation", not bool(progress.data.settings.translation))
			_show_settings()
		"sound":
			progress.set_setting("sound", not bool(progress.data.settings.sound))
			audio.set_sound_enabled(bool(progress.data.settings.sound))
			_show_settings()
		"controls": _show_controls()
		"reset": _show_reset_confirm()


func _back() -> void:
	if dictionary_open:
		_close_dictionary()
		return
	if reset_confirm:
		_close_reset_confirm()
		return
	match screen:
		"reader":
			_save_reading()
			_show_courses()
		"courses", "review", "library", "settings", "controls", "quiz":
			if screen == "quiz" and quiz_state == "playing" and not quiz_items.empty() \
					and quiz_index < quiz_items.size() \
					and quiz_items[quiz_index].type == "word_builder" and not quiz_built.empty():
				_remove_letter()
			else:
				_show_home()
		"home":
			return


func _replay() -> void:
	if dictionary_open:
		_play_dictionary_audio()
		return
	match screen:
		"reader": _play_reader()
		"quiz":
			if quiz_items.empty() or quiz_index >= quiz_items.size():
				return
			var item: Dictionary = quiz_items[quiz_index]
			var file: String = repo.audio_for_word(String(current_story.get("id", "")), String(item.get("correctAnswer", "")))
			if file != "":
				audio.play(file, [])
		"review":
			if review_index >= review_words.size():
				_show_review()
				return
			var word: String = review_words[review_index]
			var story_id := String(progress.data.vocabulary.get(word, {}).get("storyId", ""))
			var file: String = repo.audio_for_word(story_id, word)
			if file != "":
				audio.play(file, [])
		_:
			pass


func _hint() -> void:
	if dictionary_open or reset_confirm:
		return
	if screen == "reader":
		reader_translation_visible = not reader_translation_visible
		_show_reader()
	elif screen == "quiz" and quiz_state == "playing":
		if quiz_hint_text == "" and not quiz_items.empty() and quiz_index < quiz_items.size():
			quiz_hints += 1
			var answer := String(quiz_items[quiz_index].correctAnswer)
			quiz_hint_text = "提示：正确答案以 " + answer.substr(0, 1).to_upper() + " 开头（本题提示会扣奖励）"
			_show_quiz()


func _previous() -> void:
	match screen:
		"reader": _change_paragraph(-1)
		"courses":
			if course_page > 0:
				course_page -= 1
				_show_courses()
		"library":
			if library_mode == 0:
				library_mode = 1
			else:
				library_mode = 0
			library_page = 0
			_show_library()


func _next() -> void:
	match screen:
		"reader":
			if paragraph_index + 1 < current_story.content.size():
				_change_paragraph(1)
			else:
				_start_quiz(current_course_index)
		"courses":
			if (course_page + 1) * PAGE_SIZE < repo.courses.size():
				course_page += 1
				_show_courses()
		"library":
			library_mode = 1 if library_mode == 0 else 0
			library_page = 0
			_show_library()


func _learning_menu() -> void:
	if dictionary_open:
		_close_dictionary()
		return
	if reset_confirm:
		_close_reset_confirm()
		return
	if screen == "onboarding":
		return
	if screen == "reader":
		_save_reading()
	if screen == "home":
		_show_courses()
	else:
		_show_home()


func _open_dictionary(raw_word: String, story_id: String) -> void:
	var word: String = repo.normalize_word(raw_word)
	var entry: Dictionary = repo.get_dictionary_entry(word)
	if entry.empty():
		_show_toast("词典里暂时没有这个词")
		return
	dictionary_open = true
	dictionary_entry = entry
	dictionary_word = word
	dictionary_story_id = story_id
	progress.lookup_word(word, story_id)
	_build_dictionary_overlay()


func _build_dictionary_overlay() -> void:
	if is_instance_valid(dictionary_overlay):
		dictionary_overlay.free()
	dictionary_overlay = Control.new()
	dictionary_overlay.rect_size = Vector2(640, 480)
	dictionary_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dictionary_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.04, 0.82)
	shade.rect_size = Vector2(640, 480)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	dictionary_overlay.add_child(shade)
	ui.panel(dictionary_overlay, Rect2(54, 72, 532, 356), Color("172925"), ui.GOLD, 16)
	ui.texture(dictionary_overlay, repo.emoji_path(String(dictionary_entry.get("emoji", "🔎"))), Rect2(72, 88, 58, 58))
	ui.label(dictionary_overlay, String(dictionary_entry.get("word", dictionary_word)), Rect2(142, 82, 420, 48), 31, ui.TEXT)
	ui.label(dictionary_overlay, "%s   %s" % [dictionary_entry.get("phonetic", ""), dictionary_entry.get("partOfSpeech", "")], Rect2(142, 128, 420, 28), 17, ui.GOLD, 0, false, ui.ipa_font(17))
	ui.label(dictionary_overlay, String(dictionary_entry.get("meaningCn", "")), Rect2(76, 176, 488, 54), 22, ui.GREEN, 0, true)
	ui.label(dictionary_overlay, String(dictionary_entry.get("meaningEn", "")), Rect2(76, 232, 488, 46), 16, ui.MUTED, 0, true)
	var example := ""
	var examples: Array = dictionary_entry.get("examples", [])
	if not examples.empty():
		example = String(examples[0])
	ui.label(dictionary_overlay, example, Rect2(76, 286, 488, 58), 18, ui.TEXT, 0, true)
	var favorite: bool = progress.is_favorite(dictionary_word)
	ui.label(dictionary_overlay, "A " + ("取消收藏" if favorite else "加入收藏") + "    X 重播    B 关闭", Rect2(76, 374, 488, 30), 17, ui.GOLD, 1)


func _close_dictionary() -> void:
	dictionary_open = false
	if is_instance_valid(dictionary_overlay):
		dictionary_overlay.free()
	dictionary_overlay = null


func _toggle_dictionary_favorite() -> void:
	progress.toggle_favorite(dictionary_word)
	_build_dictionary_overlay()


func _play_dictionary_audio() -> void:
	var file: String = repo.audio_for_word(dictionary_story_id, dictionary_word)
	if file != "":
		audio.play(file, [])
	else:
		_show_toast("这个故事里没有找到对应语音")


func _show_reset_confirm() -> void:
	reset_confirm = true
	confirm_overlay = Control.new()
	confirm_overlay.rect_size = Vector2(640, 480)
	confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(confirm_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.04, 0.86)
	shade.rect_size = Vector2(640, 480)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_overlay.add_child(shade)
	ui.panel(confirm_overlay, Rect2(100, 150, 440, 190), Color("2a2220"), ui.RED, 16)
	ui.label(confirm_overlay, "确定清除全部学习记录？", Rect2(120, 174, 400, 50), 25, ui.TEXT, 1)
	ui.label(confirm_overlay, "A 确定清除    B 取消", Rect2(120, 250, 400, 36), 20, ui.GOLD, 1)


func _confirm_reset() -> void:
	progress.reset_game()
	_close_reset_confirm()
	_show_onboarding()


func _close_reset_confirm() -> void:
	reset_confirm = false
	if is_instance_valid(confirm_overlay):
		confirm_overlay.free()
	confirm_overlay = null


func _show_toast(text: String) -> void:
	toast_text = text
	toast_time = 2.4
	_sync_chrome()


func learned_words_for(story_id: String) -> Array:
	return repo.unique_story_words(story_id)
