extends Control

const MARKS := {
	"spark": [
		[Vector2(11, 2), Vector2(13, 8), Vector2(16, 10), Vector2(21, 11), Vector2(16, 13), Vector2(13, 16), Vector2(11, 21), Vector2(9, 15), Vector2(6, 13), Vector2(2, 11), Vector2(7, 9), Vector2(9, 7), Vector2(11, 2)],
		[Vector2(18, 3), Vector2(18, 8)], [Vector2(15.5, 5.5), Vector2(20.5, 5.5)],
	],
	"ripple": [
		[Vector2(2, 17), Vector2(6, 18), Vector2(10, 16), Vector2(13, 11), Vector2(12, 7), Vector2(16, 7), Vector2(20, 10), Vector2(21, 14), Vector2(19, 17), Vector2(16, 17), Vector2(16, 14), Vector2(18, 13)],
		[Vector2(4, 21), Vector2(8, 21.5), Vector2(12, 19.5)],
	],
	"guard": [
		[Vector2(12, 3), Vector2(16, 5.5), Vector2(20, 6), Vector2(19, 14), Vector2(17, 18), Vector2(12, 22), Vector2(7, 18), Vector2(5, 13), Vector2(4, 6), Vector2(8, 5.5), Vector2(12, 3)],
		[Vector2(12, 8), Vector2(12, 16)], [Vector2(8, 12), Vector2(16, 12)],
	],
	"tag": [
		[Vector2(4, 6), Vector2(16, 5), Vector2(21, 10), Vector2(21, 19), Vector2(14, 22), Vector2(4, 16), Vector2(4, 6)],
		[Vector2(7, 9), Vector2(9, 8), Vector2(10, 10), Vector2(8, 11), Vector2(7, 9)],
	],
	"voice": [
		[Vector2(4, 5), Vector2(10, 4), Vector2(19, 5), Vector2(21, 9), Vector2(21, 15), Vector2(14, 17), Vector2(8, 17), Vector2(4, 21), Vector2(5, 15), Vector2(3, 12), Vector2(4, 5)],
		[Vector2(8, 9), Vector2(16, 8.8)], [Vector2(8, 12.5), Vector2(14, 12.2)],
	],
	"coast": [
		[Vector2(0, 14), Vector2(2.5, 13.4), Vector2(3.6, 12.3), Vector2(6.3, 12.1), Vector2(8.5, 10.7), Vector2(10, 10.5), Vector2(12.6, 8.2), Vector2(14.2, 7.6), Vector2(15.4, 6.5), Vector2(18.2, 4.7), Vector2(19.8, 5.8), Vector2(20.9, 6), Vector2(22.7, 7.5), Vector2(24, 8)],
		[Vector2(8, 14.2), Vector2(10.5, 13.5), Vector2(12.8, 12.9), Vector2(13.7, 11.9), Vector2(16.1, 11.6), Vector2(17.3, 10.3), Vector2(18.8, 9.9), Vector2(20.5, 8.1)],
		[Vector2(2.4, 16.2), Vector2(5.4, 15.7), Vector2(7.1, 15.8)],
		[Vector2(14.7, 15.3), Vector2(16.3, 14.8), Vector2(18.9, 14.3), Vector2(21.5, 14.4)],
	],
}

var mark := "spark"
var ink := Color("#597f97")

func _draw() -> void:
	var scale_to_rect := size / 24.0
	for stroke: Array in MARKS[mark]:
		var points := PackedVector2Array()
		for point: Vector2 in stroke:
			points.append(point * scale_to_rect)
		draw_polyline(points, Color(ink, ink.a * 0.30), 2.25, true)
		draw_polyline(points, ink, 1.05, true)
