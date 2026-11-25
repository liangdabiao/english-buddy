extends Node

signal changed

const SAVE_PATH := "user://english_buddy_profile.json"
const BACKUP_PATH := "user://english_buddy_profile.bak"
const TEMP_PATH := "user://english_buddy_profile.tmp"

var data: Dictionary = default_data()
var content_repository: Node


func _ready() -> void:
	load_game()


func default_data() -> Dictionary:
	return {
		"version": 1,
		"hatched": false,
		"name": "Magic Friend",
		"magicPower": 0,
		"xp": 0,
		"buddyStage": 0,
		"completed": {},
		"lessonScores": {},
		"favorites": [],
		"vocabulary": {},
		"reading": {},
		"history": [],
		"settings": {"translation": true, "sound": true},
		"streak": 0,
		"lastStudyDay": "",
	}


func load_game() -> void:
	var file := File.new()
	if file.file_exists(SAVE_PATH) and file.open(SAVE_PATH, File.READ) == OK:
		var parsed = JSON.parse(file.get_as_text()).result
		file.close()
		if parsed is Dictionary and int(parsed.get("version", 0)) == 1:
			data = _merge_defaults(parsed)
			return
	if file.file_exists(BACKUP_PATH) and file.open(BACKUP_PATH, File.READ) == OK:
		var parsed = JSON.parse(file.get_as_text()).result
		file.close()
		if parsed is Dictionary and int(parsed.get("version", 0)) == 1:
			data = _merge_defaults(parsed)
	emit_signal("changed")


func _merge_defaults(saved: Dictionary) -> Dictionary:
	var merged := default_data()
	for key in saved:
		merged[key] = saved[key]
	return merged


func save_game() -> void:
	var file := File.new()
	if file.open(TEMP_PATH, File.WRITE) != OK:
		push_error("Could not write learning profile")
		return
	file.store_string(JSON.print(data))
	file.close()
	var directory := Directory.new()
	if file.file_exists(SAVE_PATH):
		directory.rename(SAVE_PATH, BACKUP_PATH)
	if directory.rename(TEMP_PATH, SAVE_PATH) != OK:
		if file.file_exists(BACKUP_PATH):
			directory.rename(BACKUP_PATH, SAVE_PATH)
		push_error("Could not replace learning profile")
		return
	if file.file_exists(BACKUP_PATH):
		directory.remove(BACKUP_PATH)
	emit_signal("changed")


func hatch_buddy() -> void:
	if data.hatched:
		return
	data.hatched = true
	data.buddyStage = 1
	_touch_study_day()
	save_game()


func buddy_stage() -> int:
	if not data.hatched:
		return 0
	data.buddyStage = 2 if int(data.xp) >= 80 else 1
	return int(data.buddyStage)


func is_unlocked(course_index: int) -> bool:
	if course_index <= 0:
		return true
	if course_index >= 20:
		return false
	return bool(data.completed.get("node_l1_%02d" % course_index, false))


func is_completed(course_id: String) -> bool:
	return bool(data.completed.get(course_id, false))


func completed_count() -> int:
	return int(data.completed.size())


func next_course_index() -> int:
	for index in range(20):
		if not is_completed("node_l1_%02d" % (index + 1)):
			return index
	return 0


func complete_lesson(course: Dictionary, correct: int, total: int, hints: int) -> Dictionary:
	var course_id: String = course.id
	var passed := total > 0 and float(correct) / float(total) >= 0.6
	var first_pass := passed and not is_completed(course_id)
	var reward: int = max(0, correct * 3 - hints * 5) if first_pass else 0
	if first_pass:
		data.completed[course_id] = true
		data.magicPower = int(data.magicPower) + reward
		data.xp = int(data.xp) + reward
		_learn_story_words(course.storyId)
	data.lessonScores[course_id] = max(int(data.lessonScores.get(course_id, 0)), correct)
	data.history.push_front({
		"storyId": course.storyId,
		"correct": correct,
		"total": total,
		"passed": passed,
		"time": int(OS.get_unix_time()),
	})
	if data.history.size() > 30:
		data.history.resize(30)
	_touch_study_day()
	save_game()
	return {"passed": passed, "firstPass": first_pass, "reward": reward}


func _learn_story_words(story_id: String) -> void:
	for word in content_repository.unique_story_words(story_id):
		_ensure_vocabulary(word, story_id)


func _ensure_vocabulary(word: String, story_id: String = "") -> void:
	if data.vocabulary.has(word):
		if story_id != "" and String(data.vocabulary[word].get("storyId", "")) == "":
			data.vocabulary[word].storyId = story_id
		return
	data.vocabulary[word] = {
		"mastery": 0,
		"due": int(OS.get_unix_time()),
		"storyId": story_id,
	}


func lookup_word(word: String, story_id: String = "") -> void:
	_ensure_vocabulary(word, story_id)
	save_game()


func toggle_favorite(word: String) -> bool:
	var normalized := word.to_lower()
	var index := int(data.favorites.find(normalized))
	if index >= 0:
		data.favorites.remove(index)
		save_game()
		return false
	data.favorites.append(normalized)
	save_game()
	return true


func is_favorite(word: String) -> bool:
	return int(data.favorites.find(word.to_lower())) >= 0


func due_words(limit: int = 10) -> Array:
	var result := []
	var now := int(OS.get_unix_time())
	for word in data.vocabulary:
		var row = data.vocabulary[word]
		if int(row.get("due", 0)) <= now:
			result.append(word)
	result.sort()
	if result.size() > limit:
		result.resize(limit)
	return result


func due_count() -> int:
	var count := 0
	var now := int(OS.get_unix_time())
	for word in data.vocabulary:
		if int(data.vocabulary[word].get("due", 0)) <= now:
			count += 1
	return count


func record_review(word: String, correct: bool) -> void:
	if not data.vocabulary.has(word):
		return
	var row = data.vocabulary[word]
	var mastery := int(row.get("mastery", 0))
	mastery = min(3, mastery + 1) if correct else 0
	var days: int = [1, 1, 3, 7][mastery]
	row.mastery = mastery
	row.due = int(OS.get_unix_time()) + days * 86400
	_touch_study_day()
	save_game()


func record_reading(story_id: String, seconds: int) -> void:
	if seconds <= 0:
		return
	var row = data.reading.get(story_id, {"seconds": 0, "sessions": 0})
	row.seconds = int(row.seconds) + seconds
	row.sessions = int(row.sessions) + 1
	data.reading[story_id] = row
	_touch_study_day()
	save_game()


func reset_game() -> void:
	data = default_data()
	save_game()


func set_setting(key: String, value: bool) -> void:
	data.settings[key] = value
	save_game()


func _touch_study_day() -> void:
	var now := OS.get_datetime()
	var today := "%04d-%02d-%02d" % [now.year, now.month, now.day]
	if data.lastStudyDay != today:
		data.streak = int(data.streak) + 1
		data.lastStudyDay = today
