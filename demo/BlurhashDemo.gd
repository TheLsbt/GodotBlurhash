extends Node

# Our valid blurhash
#LEHV6nWB2yk8pyo0adR*.7kCMdnj
@onready var original: TextureRect = $Original
@onready var output: TextureRect = $Blurhash


func _ready() -> void:
	var texture := original.texture
	var blurhash := Blurhash.encode(texture, 4, 3)
	#print(bh.is_blurhash_valid(blurhash))
	output.texture = Blurhash.blurhash_decode(blurhash, 100, 60, 1)
