"""
Pure godot blurhash decoder with no additional dependencies, for
both de- and encoding.

Very close port of the original Swift implementation by Dag Ågren.
"""

extends  RefCounted
class_name Blurhash

# Alphabet for base 83
const alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#$%*+,-.:;=?@[]^_{|}~"


static func base83_decode(base83_str: String) -> int:
	# Decodes a base83 string, as used in blurhash, to an integer.
	var value := 0
	for base83_char in base83_str:
		value = value * 83 + alphabet.find(base83_char)
	return value


static func base83_encode(value: int, length: int) -> String:
	# Decodes an integer to a base83 string, as used in blurhash.

	# Length is how long the resulting string should be. Will complain
	# if the specified length is too short.
	var data := ""
	var div = 1
	for i in range(length - 1):
		div *= 83

	for i in range(length):
		data += alphabet[(value / div) % 83]
		div /= 83

	return data



static func srgb_to_linear(value: float):
	# srgb 0-255 integer to linear 0.0-1.0 floating point conversion.
	value = value / 255.0
	if value <= 0.04045:
		return value / 12.92
	return pow((value + 0.055) / 1.055, 2.4)


static func sign_pow(value: float, exp: float):
	# Sign-preserving exponentiation.
	var result := pow(abs(value), exp)
	return -result if value < 0 else result


static func linear_to_srgb(value: float) -> int:
	# linear 0.0-1.0 floating point to srgb 0-255 integer conversion.
	value = max(0.0, min(1.0, value))
	if value <= 0.0031308:
		return int(value * 12.92 * 255 + 0.5)
	return int((1.055 * pow(value, 1 / 2.4) - 0.055) * 255 + 0.5)


static func blurhash_components(blurhash: String) -> Vector2:
	# Decodes and returns the number of x and y components in the given blurhash.
	if blurhash.length() < 6:
		printerr("BlurHash must be at least 6 characters long.")

	# Decode metadata
	var size_info = base83_decode(blurhash[0])
	var size_y = int(size_info / 9) + 1
	var size_x = (size_info % 9) + 1

	return Vector2(size_x, size_y)


## Returns whether the supplied BlurHash is valid.
static func is_blurhash_valid(blurhash: String) -> bool:
	# Length must be 6 at minimum
	if blurhash.length() < 6:
		printerr("BlurHash must be at least 6 characters long.")
		return false

	# Reported data must match with reported size
	var components := base83_decode(blurhash.substr(0, 1))
	var size_y := (components / 9) + 1
	var size_x := (components % 9) + 1

	return blurhash.length() == 4 + 2 * (size_x * size_y)


static func blurhash_decode(blurhash: String, width: int, height: int, punch := 1.0) -> Texture:
	# Decodes the given blurhash to an image of the specified size.

	# Returns the resulting image a list of lists of 3-value sRGB 8 bit integer
	# lists. Set linear to True if you would prefer to get linear floating point
	# RGB back.

	# The punch parameter can be used to de- or increase the contrast of the
	# resulting image.

	# As per the original implementation it is suggested to only decode
	# to a relatively small size and then scale the result up, as it
	# basically looks the same anyways.

	if !is_blurhash_valid(blurhash):
		return null

	punch = max(1, punch)

	var components := base83_decode(blurhash.substr(0, 1))
	var size_y := (components / 9) + 1
	var size_x := (components % 9) + 1
	var max_value := (base83_decode(blurhash.substr(1, 1)) + 1) / 166.0
	if is_equal_approx(max_value, 0):
		return null

	var colors := []
	for i in range(size_x * size_y):
		if i == 0:
			var value := base83_decode(blurhash.substr(2, 4))
			if value == -1:
				return null
			colors.push_back(Color(
				srgb_to_linear(value >> 16),
				srgb_to_linear((value >> 8) & 255),
				srgb_to_linear(value & 255)
			))
		else:
			var value := base83_decode(blurhash.substr(4 + i * 2, 2))
			if value == -1:
				return null
			colors.push_back(
				Color(
					sign_pow((value / (19 * 19) - 9.0) / 9, 2) * max_value * punch,
					sign_pow((((value / 19) % 19) - 9.0) / 9, 2) * max_value * punch,
					sign_pow(((value % 19) - 9.0) / 9, 2) * max_value * punch
				))

	var data := PackedByteArray()
	data.resize(width * height * 3)
	for y in range(height):
		for x in range(width):
			var r := 0.0
			var g := 0.0
			var b := 0.0

			for j in range(size_y):
				for i in range(size_x):
					var basics := cos((PI * x * i) / width) * cos((PI * y * j) / height)
					var idx := i + j * size_x
					r += colors[idx].r * basics
					g += colors[idx].g * basics
					b += colors[idx].b * basics

			data[3 * (width * y + x)]     = int(clamp(linear_to_srgb(r), 0, 255))
			data[3 * (width * y + x) + 1] = int(clamp(linear_to_srgb(g), 0, 255))
			data[3 * (width * y + x) + 2] = int(clamp(linear_to_srgb(b), 0, 255))

	var img := Image.create_from_data(width, height, false, Image.FORMAT_RGB8, data)
	return ImageTexture.create_from_image(img)


#Calculates the blurhash for an image using the given x and y component counts.

#Image should be a 3-dimensional array, with the first dimension being y, the second
#being x, and the third being the three rgb components that are assumed to be 0-255
#srgb integers (incidentally, this is the format you will get from a PIL RGB image).

#You can also pass in already linear data - to do this, set linear to True. This is
#useful if you want to encode a version of your image resized to a smaller size (which
#you should ideally do in linear colour).
static func encode(texture: Texture2D, components_x: int = 4, components_y: int = 3) -> String:
	if components_x < 1 or components_x > 9 or components_y < 1 or components_y > 9:
		printerr("x and y component counts must be between 1 and 9 inclusive.")
		return ""

	var texture_data := texture.get_image().get_data()
	var format := texture.get_image().get_format()
	if format != Image.FORMAT_RGB8 and format != Image.FORMAT_RGBA8:
		printerr("Texture format not supported.")
		return ""

	var blurhash := ""

	var dc : Vector3
	var ac := []
	for y in range(components_y):
		for x in range(components_x):
			var color := multiply_basis(
				x,
				y,
				texture.get_width(),
				texture.get_height(),
				texture_data, format
			)
			if x | y == 0:
				dc = color
			else:
				ac.push_back(color)

	var size_flag := (components_x - 1) + (components_y - 1) * 9
	blurhash += base83_encode(size_flag, 1)

	var max_value : float
	if ac.size() > 0:
		var actual_max_value := 0.0
		for ac_color in ac:
			var color_max_value: float = max(abs(ac_color.x), max(abs(ac_color.y), abs(ac_color.z)))
			actual_max_value = max(color_max_value, actual_max_value)
		var quantised_max_value := int(max(0, min(82, floor(actual_max_value * 166 - 0.5))))
		max_value = (quantised_max_value + 1) / 166.0
		blurhash += base83_encode(quantised_max_value, 1)
	else:
		max_value = 1.0
		blurhash += base83_encode(0, 1)

	blurhash += base83_encode(
		(linear_to_srgb(dc.x) << 16) + (linear_to_srgb(dc.y) << 8) + linear_to_srgb(dc.z),
		4
		)


	for ac_color in ac:
		blurhash += base83_encode(
			int(max(0, min(18, floor(sign_pow(ac_color.x / max_value, 0.5) * 9 + 9.5)))) * 19 * 19 +
			int(max(0, min(18, floor(sign_pow(ac_color.y / max_value, 0.5) * 9 + 9.5)))) * 19 +
			int(max(0, min(18, floor(sign_pow(ac_color.z / max_value, 0.5) * 9 + 9.5)))),
			2
		)

	return blurhash


static  func multiply_basis(component_x: int, component_y: int, width: int, height: int, data: PackedByteArray, format: int) -> Vector3:
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var normalization := 2 if (component_x | component_y) else 1
	var stride : int
	match format:
		Image.FORMAT_RGB8:
			stride = 3
		Image.FORMAT_RGBA8:
			stride = 4

	for y in range(height):
		for x in range(width):
			var basis := cos(PI * component_x * x / width) * cos(PI * component_y * y / height)
			r += basis * srgb_to_linear(data[stride * (width * y + x)])
			g += basis * srgb_to_linear(data[stride * (width * y + x) + 1])
			b += basis * srgb_to_linear(data[stride * (width * y + x) + 2])

	var scale := normalization / float(width * height)
	print(r * scale)
	return Vector3(r * scale, g * scale, b * scale)

