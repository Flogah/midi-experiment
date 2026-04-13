extends Control

var amy
var patch: int = 121
var starting_note: int = 60
var target_scale: String = "f-moll"
var notes = []

var capture_dict_1: Dictionary = {}

@onready var button_1: Button = %Button1
@onready var button_2: Button = %Button2
@onready var button_3: Button = %Button3
@onready var button_4: Button = %Button4
@onready var metronome_audio_player_2d: AudioStreamPlayer2D = %MetronomeAudioPlayer2D
@onready var capture_toggle: Button = %CaptureToggle
@onready var time_label: Label = %TimeLabel
@onready var label_patch: Label = %LabelPatch
@onready var h_scroll_bar_patch: HScrollBar = %HScrollBarPatch

var capture_mode: bool = false
var time_signature: float = 0.0

var input_area:int = 0
	#  2 | 3 | 4
	#  1 | 0 | 5
	#  8 | 7 | 6

# newly simplified
	#  4 | 5 | 4
	#  3 | 0 | 3
	#  2 | 1 | 2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	label_patch.text = "Patch # " + str(patch)
	h_scroll_bar_patch.value = patch
	
	notes = get_octave()
	
	amy = Amy.new()
	add_child(amy)
	await get_tree().process_frame
	
	button_1.button_down.connect(func(): play_note_simple(1, 48, 0.8))
	button_1.button_up.connect(func(): play_note_simple(1, 0, 0.0))
	button_2.button_down.connect(func(): play_note_simple(2, 50, 0.8))
	button_2.button_up.connect(func(): play_note_simple(2, 0, 0.0))
	button_3.button_down.connect(func(): play_note_simple(3, 52, 0.8))
	button_3.button_up.connect(func(): play_note_simple(3, 0, 0.0))
	button_4.button_down.connect(func(): play_note_simple(4, 54, 0.8))
	button_4.button_up.connect(func(): play_note_simple(4, 0, 0.0))
	
	capture_toggle.toggled.connect(capture_mode_activation)

func _process(delta: float) -> void:
	time_signature += delta
	if time_signature >= 4.0:
		time_signature = 0.0
		metronome_tick()
	time_label.text = str(snapped(time_signature, 0.01))
	
	var l_stick_input = Input.get_vector("l_stick_left", "l_stick_right", "l_stick_down", "l_stick_up")
	if l_stick_input:
		joystick_input_mapping(l_stick_input)
	
	if Input.is_action_just_pressed("capture_mode"):
		capture_mode_activation(true)
	if Input.is_action_just_released("capture_mode"):
		capture_mode_activation(false)
	
	if capture_mode:
		capture_toggle.text = str(snapped(4.0 - time_signature, 0.01))
	playback_from_capture()

func joystick_input_mapping(input: Vector2):
	var new_input_area:int = 0
	
	var deadzone: float = 0.3
	
	if input.y < -deadzone:
		if input.x < -deadzone:
			new_input_area = 4
		elif input.x > -deadzone and input.x < deadzone:
			new_input_area = 5
		elif input.x > deadzone:
			new_input_area = 4
	
	elif input.y > deadzone:
		if input.x < -deadzone:
			new_input_area = 2
		elif input.x > -deadzone and input.x < deadzone:
			new_input_area = 1
		elif input.x > deadzone:
			new_input_area = 2
	
	elif input.y < deadzone:
		if input.x < -deadzone:
			new_input_area = 3
		elif input.x > -deadzone and input.x < deadzone:
			new_input_area = 0
		elif input.x > deadzone:
			new_input_area = 3
	
	if new_input_area == input_area:
		return
	else:
		if new_input_area == 0:
			#var data = {}
			#data["vel"] = 0.0
			#data["note"] = 0
			#data["synth"] = 1
			#play_note(data)
			input_area = new_input_area
			return
		
		var data = {}
		data["vel"] = 0.0
		data["note"] = 0
		data["synth"] = 1
		play_note(data)
		
		var scaled_notes = apply_scale(notes, target_scale)
		
		var new_data = {}
		new_data["vel"] = 0.8
		new_data["note"] = scaled_notes[new_input_area]
		new_data["synth"] = 1
		input_area = new_input_area
		play_note(new_data)

func play_note_simple(synth: int = 1, note: int = 52, vel: float = 1.0):
	var data = {
		"synth" : synth,
		"note" : note,
		"vel" : vel
	}
	play_note(data)

func play_note(data: Dictionary):
	var synth = data["synth"]
	var note = data["note"]
	var vel = data["vel"]
	amy.send({"synth": synth, "patch": patch, "num_voices": 6, "note": note, "vel": vel})
	print(note)
	
	if capture_mode:
		capture_note(data)

func capture_note(data: Dictionary):
	data["synth"] = 2
	capture_dict_1[snapped(time_signature, 0.01)] = data

func capture_mode_activation(toggle):
	if toggle:
		capture_toggle.text = str(4.0 - time_signature)
		# start a new capture, so delete old capture
		capture_dict_1 = {}
		capture_mode = true
	else:
		capture_toggle.text = "CAPTURE"
		capture_toggle.disabled = false
		capture_mode = false

func playback_from_capture():
	if time_signature >= 0.0:
		var time_sig = snapped(time_signature, 0.01)
		if capture_dict_1.has(time_sig):
			play_note(capture_dict_1[time_sig])

func metronome_tick():
	metronome_audio_player_2d.play()

func _on_h_scroll_bar_patch_value_changed(value: float) -> void:
	patch = value
	label_patch.text = "Patch # " + str(patch)

func get_octave(start_note: int = starting_note) -> Array:
	var octave:Array[int] = [
		0,
		start_note,
		start_note +2,
		start_note +4,
		start_note +8,
		start_note +10,
		start_note +12,
		start_note +14,
		start_note +16,
	]
	return octave

func apply_scale(note_array: Array, scale: String) -> Array:
	var new_array = note_array
	match scale:
		"d-moll":
			# d - e - f - g - a - h-moll - c - d.
			# shift base notes up or down
			for note in note_array:
				var remainder = note % 12
				match remainder:
					0: pass # C
					1: pass # C#
					2: pass # D
					3: pass # D#
					4: pass # E
					5: pass # F
					6: pass # F#
					7: pass # G
					8: pass # G#
					9: pass # A
					10: pass # A#
					11: note -= 1 # H -> H-moll
			# shift notes to the correct starting note
			new_array = note_array.map(func(n): return n + 2) # C -> D
		"f-moll":
			for note in note_array:
				var remainder = note % 12
				match remainder:
					0: pass # C
					1: pass # C#
					2: pass # D
					3: pass # D#
					4: note -= 1 # E -> E-moll
					5: pass # F
					6: pass # F#
					7: pass # G
					8: pass # G#
					9: note -= 1 # A -> A-moll
					10: pass # A#
					11: note -= 1 # H -> H-moll
			new_array = note_array.map(func(n): return n + 5) # C -> F
		"test":
			pass
	return new_array
