extends Node2D

var check1: bool = false
var num2: int = 3

func _ready():
	DialogueManager.show_dialogue_balloon(load("res://dialogue/morgana.dialogue"), "start")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_check_button_toggled(toggled_on):
	check1 = toggled_on

func _on_button_pressed():
	num2 += 1
	$RichTextLabel.text = "Num2: " + str(num2)
