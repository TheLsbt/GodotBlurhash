extends Node

@onready var original: TextureRect = $Original
@onready var output: TextureRect = $Blurhash


func _ready() -> void:
	var texture := original.texture
	var blurhash := Blurhash.encode(texture, 4, 3)
	output.texture = Blurhash.decode(blurhash, 100, 60, 1)
