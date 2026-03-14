class_name DialogueManagerExampleBalloon extends CanvasLayer
## A basic dialogue balloon for use with Dialogue Manager.


## CHANGE: SAVING POSTIION OF PORTRAIT NODES
## character: [mouth_pos, eyes_pos]
var portrait_pos: Dictionary = {
	"futaba" : [Vector2(342, 361), Vector2(404, 248)],
	"morgana" : [Vector2(297,314), Vector2(319, 144)],
	"akechi": [Vector2(290, 353), Vector2(348,241)],
	"ryuji": [Vector2(371,335), Vector2(397,236)],
	"default": [Vector2.ZERO, Vector2.ZERO]
}

## CHANGE: storing previous speaking character:
var past_char: String = ""


## The dialogue resource
@export var dialogue_resource: DialogueResource

## Start from a given title when using balloon as a [Node] in a scene.
@export var start_from_title: String = ""

## If running as a [Node] in a scene then auto start the dialogue.
@export var auto_start: bool = false

## If all other input is blocked as long as dialogue is shown.
@export var will_block_other_input: bool = true

## The action to use for advancing the dialogue
@export var next_action: StringName = &"ui_accept"

## The action to use to skip typing the dialogue
@export var skip_action: StringName = &"ui_cancel"

## A sound player for voice lines (if they exist).
@onready var audio_stream_player: AudioStreamPlayer = %AudioStreamPlayer

## Temporary game states
var temporary_game_states: Array = []

## See if we are waiting for the player
var is_waiting_for_input: bool = false

## See if we are running a long mutation and should hide the balloon
var will_hide_balloon: bool = false

## A dictionary to store any ephemeral variables
var locals: Dictionary = {}

var _locale: String = TranslationServer.get_locale()

## The current line
var dialogue_line: DialogueLine:
	set(value):
		if value:
			dialogue_line = value
			apply_dialogue_line()
		else:
			# The dialogue has finished so close the balloon
			if owner == null:
				queue_free()
			else:
				hide()
	get:
		return dialogue_line

## A cooldown timer for delaying the balloon hide when encountering a mutation.
var mutation_cooldown: Timer = Timer.new()

## The base balloon anchor
@onready var balloon: Control = %Balloon

## The label showing the name of the currently speaking character
@onready var character_label: RichTextLabel = %CharacterLabel

## The label showing the currently spoken dialogue
@onready var dialogue_label: DialogueLabel = %DialogueLabel

## The menu of responses
@onready var responses_menu: DialogueResponsesMenu = %ResponsesMenu


func _ready() -> void:
	balloon.hide()
	Engine.get_singleton("DialogueManager").mutated.connect(_on_mutated)

	# If the responses menu doesn't have a next action set, use this one
	if responses_menu.next_action.is_empty():
		responses_menu.next_action = next_action

	mutation_cooldown.timeout.connect(_on_mutation_cooldown_timeout)
	add_child(mutation_cooldown)

	if auto_start:
		if not is_instance_valid(dialogue_resource):
			assert(false, DMConstants.get_error_message(DMConstants.ERR_MISSING_RESOURCE_FOR_AUTOSTART))
		start()

func _unhandled_input(_event: InputEvent) -> void:
	# Only the balloon is allowed to handle input while it's showing
	if will_block_other_input:
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	## Detect a change of locale and update the current dialogue line to show the new language
	if what == NOTIFICATION_TRANSLATION_CHANGED and _locale != TranslationServer.get_locale() and is_instance_valid(dialogue_label):
		_locale = TranslationServer.get_locale()
		var visible_ratio: float = dialogue_label.visible_ratio
		dialogue_line = await dialogue_resource.get_next_dialogue_line(dialogue_line.id)
		if visible_ratio < 1:
			dialogue_label.skip_typing()


## Start some dialogue
func start(with_dialogue_resource: DialogueResource = null, title: String = "", extra_game_states: Array = []) -> void:
	temporary_game_states = [self] + extra_game_states
	is_waiting_for_input = false
	if is_instance_valid(with_dialogue_resource):
		dialogue_resource = with_dialogue_resource
	if not title.is_empty():
		start_from_title = title
	dialogue_line = await dialogue_resource.get_next_dialogue_line(start_from_title, temporary_game_states)
	show()


## Apply any changes to the balloon given a new [DialogueLine].
func apply_dialogue_line() -> void:
	mutation_cooldown.stop()

	is_waiting_for_input = false
	balloon.focus_mode = Control.FOCUS_ALL
	balloon.grab_focus()

	dialogue_label.hide()
	dialogue_label.dialogue_line = dialogue_line

	responses_menu.hide()
	responses_menu.responses = dialogue_line.responses
	
	character_label.visible = false
	
	## CHANGE: play fade animation for dialogue box
	if dialogue_line.character.to_lower() != past_char:
		$"Dialogue Box".play("fade")
		await $"Dialogue Box".animation_finished
	
	## CHANGE: spawning correct character portrait & animation
	if $Portrait/Base.sprite_frames.has_animation(dialogue_line.character.to_lower()):
		$Portrait/Base.play(dialogue_line.character.to_lower())
		for node in [$Portrait/Mouth, $Portrait/Eyes]:
			node.play(dialogue_line.character.to_lower()+"_"+dialogue_line.get_tag_value("emotion"))
		$Portrait/Mouth.position = portrait_pos[dialogue_line.character.to_lower()][0]
		$Portrait/Eyes.position = portrait_pos[dialogue_line.character.to_lower()][1]
	else:
		for node in [$Portrait/Base, $Portrait/Mouth, $Portrait/Eyes]:
			node.play("default")
	
	## CHANGE: creating dialogue box animation
	if dialogue_line.character.to_lower() != past_char:
		## CHANGE: creating dialogue animation
		var tween = create_tween()
		tween.tween_property($Portrait, "position", $Portrait.position + Vector2(-20, 0), 0)
		tween.chain().tween_property($Portrait, "position", $Portrait.position, 0.15)
		
		$"Dialogue Box".play("start")
		await $"Dialogue Box".animation_finished
		past_char = dialogue_line.character.to_lower()
		
	## CHANGE: loading + playing audio if tag exists
	if dialogue_line.has_tag("voice"):
		audio_stream_player.stream = load("res://assets/audio/" + dialogue_line.character.to_lower() + "/" + dialogue_line.get_tag_value("voice") + "_streaming_dec.wav")
		audio_stream_player.play()
		
	$"Dialogue Box".play("loop")
	
	character_label.visible = not dialogue_line.character.is_empty()
	var char_label_text = tr(dialogue_line.character, "dialogue")
	character_label.text = char_label_text[0] + " [bgcolor=black][color=white]" + char_label_text[1] + "[/color][/bgcolor] " + char_label_text.substr(2,len(char_label_text))
	
	# Show our balloon
	balloon.show()
	will_hide_balloon = false

	dialogue_label.show()
	if not dialogue_line.text.is_empty():
		dialogue_label.type_out()
		await dialogue_label.finished_typing
		
	# Wait for next line
	if dialogue_line.responses.size() > 0:
		balloon.focus_mode = Control.FOCUS_NONE
		responses_menu.show()
	elif dialogue_line.time != "":
		var time: float = dialogue_line.text.length() * 0.02 if dialogue_line.time == "auto" else dialogue_line.time.to_float()
		await get_tree().create_timer(time).timeout
		next(dialogue_line.next_id)
	else:
		is_waiting_for_input = true
		balloon.focus_mode = Control.FOCUS_ALL
		balloon.grab_focus()


## Go to the next line
func next(next_id: String) -> void:
	dialogue_line = await dialogue_resource.get_next_dialogue_line(next_id, temporary_game_states)


#region Signals


func _on_mutation_cooldown_timeout() -> void:
	if will_hide_balloon:
		will_hide_balloon = false
		balloon.hide()


func _on_mutated(_mutation: Dictionary) -> void:
	if not _mutation.is_inline:
		is_waiting_for_input = false
		will_hide_balloon = true
		mutation_cooldown.start(0.1)


func _on_balloon_gui_input(event: InputEvent) -> void:
	# See if we need to skip typing of the dialogue
	if dialogue_label.is_typing:
		var mouse_was_clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed()
		var skip_button_was_pressed: bool = event.is_action_pressed(skip_action)
		if mouse_was_clicked or skip_button_was_pressed:
			get_viewport().set_input_as_handled()
			dialogue_label.skip_typing()
			return

	if not is_waiting_for_input: return
	if dialogue_line.responses.size() > 0: return

	# When there are no response options the balloon itself is the clickable thing
	get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		next(dialogue_line.next_id)
	elif event.is_action_pressed(next_action) and get_viewport().gui_get_focus_owner() == balloon:
		next(dialogue_line.next_id)


func _on_responses_menu_response_selected(response: DialogueResponse) -> void:
	$AudioStreamPlayer2.stream = load("res://assets/audio/00104.wav")
	$AudioStreamPlayer2.play()
	await $AudioStreamPlayer2.finished
	next(response.next_id)

#endregion
