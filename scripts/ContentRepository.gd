extends Node

var content: Dictionary = {}
var courses: Array = []
var stories: Dictionary = {}
var dictionary: Dictionary = {}
var emoji_icons: Dictionary = {}
var buddy_icons: Array = []
var background_path := ""


func _ready() -> void:
	var file := File.new()
	if file.open("res://data/content.json", File.READ) != OK:
		push_error("Could not open bundled course content")
		return
	content = JSON.parse(file.get_as_text()).result
	file.close()
	courses = content.get("courses", [])
	for story in content.get("stories", []):
		stories[story.id] = story
	for entry in content.get("dictionary", []):
		dictionary[normalize_word(entry.word)] = entry
	emoji_icons = content.get("emojiIcons", {})
	buddy_icons = content.get("buddyIcons", [])
	background_path = "res://assets/icons/" + content.get("backgroundImage", "")


func normalize_word(raw: String) -> String:
	var lower := raw.to_lower()
	var result := ""
	for index in range(lower.length()):
		var character := lower[index]
		if (character >= "a" and character <= "z") or character == "'" or character == "-":
			result += character
	return result


func get_course(index: int) -> Dictionary:
	if index < 0 or index >= courses.size():
		return {}
	return courses[index]


func get_story(story_id: String) -> Dictionary:
	return stories.get(story_id, {})


func get_dictionary_entry(raw: String) -> Dictionary:
	var word := normalize_word(raw)
	if dictionary.has(word):
		return dictionary[word]
	var candidates := ["ing", "ed", "es", "s"]
	for suffix in candidates:
		if word.length() > suffix.length() + 2 and word.ends_with(suffix):
			var stem := word.substr(0, word.length() - suffix.length())
			if dictionary.has(stem):
				return dictionary[stem]
			if stem.ends_with("i"):
				stem = stem.substr(0, stem.length() - 1) + "y"
				if dictionary.has(stem):
					return dictionary[stem]
	if word.ends_with("ies") and word.length() > 4:
		var stem := word.substr(0, word.length() - 3) + "y"
		if dictionary.has(stem):
			return dictionary[stem]
	return {}


func emoji_path(emoji: String) -> String:
	if emoji_icons.has(emoji):
		return "res://assets/icons/" + emoji_icons[emoji]
	return ""


func buddy_path(stage: int) -> String:
	if stage >= 0 and stage < buddy_icons.size():
		return "res://assets/icons/" + buddy_icons[stage]
	return ""


func audio_for_word(story_id: String, raw_word: String) -> String:
	var story := get_story(story_id)
	var target := normalize_word(raw_word)
	for paragraph in story.get("content", []):
		for timing in paragraph.get("words", []):
			if normalize_word(timing.word) == target:
				return paragraph.audioFile
	return ""


func unique_story_words(story_id: String) -> Array:
	var result := []
	var seen := {}
	var story := get_story(story_id)
	for paragraph in story.get("content", []):
		for timing in paragraph.get("words", []):
			var word := normalize_word(timing.word)
			if word != "" and not seen.has(word) and dictionary.has(word):
				seen[word] = true
				result.append(word)
	return result
