# Godot Blurhash
 A [Blurhash](https://blurha.sh) implementation in the [Godot Game Engine](https://github.com/godotengine/godot).

## Decode a image from a blurhash
```
var hash: String = "LU9Rquj[H;fQRjfQoffQH;ayx^fQ"

# blurhash, width, height, punch
var decoded_texture: Texture = Blurhash.decode(hash, 128, 128, 1.0)

# texture_rect is reference to a TextureRect node in the scene
texture_rect.texture = decoded_texture 
```

## Encode a blurhash icon.svg
```
 var texture: Texture2d = preload("res://icon.svg")
 var hash: String = Blurhash.encode(texture, 4, 3) #LU9Rquj[H;fQRjfQoffQH;ayx^fQ
 print(hash)
```
> **Note!**<br>
> As per the original implementation it is suggested to only decode
> to a relatively small size and then scale the result up, as it
> basically looks the same anyways.

## Licence
This repository is under the [MIT licence.](https://github.com/TheLsbt/GodotBlurhash/blob/main/LICENSE)
