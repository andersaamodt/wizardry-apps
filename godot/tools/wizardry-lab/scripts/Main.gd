extends Control

@onready var meta_label: Label = %Meta

func _ready() -> void:
	meta_label.text = "Platform: %s | Build: %s" % [OS.get_name(), Time.get_datetime_string_from_system()]
