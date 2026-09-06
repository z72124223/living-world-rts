extends Node2D
var kind := "tree"
var footprint := Vector2(40, 32)

func setup(data: Dictionary) -> void:
	kind = data.kind
	var rect: Rect2 = data.rect
	position = Vector2(rect.get_center().x, rect.end.y)
	footprint = rect.size
	queue_redraw()

func poly(points: Array, color: String) -> void:
	draw_colored_polygon(PackedVector2Array(points), Color(color))

func _draw() -> void:
	var w := footprint.x / 2
	var h := footprint.y
	if kind == "tree":
		draw_set_transform(Vector2(8, -8), 0, Vector2(1, 0.40))
		draw_circle(Vector2.ZERO, 54, Color(0.07, 0.14, 0.1, 0.44))
		draw_set_transform(Vector2.ZERO)
		draw_rect(Rect2(-9, -65, 18, 62), Color("594736"))
		draw_rect(Rect2(-4, -62, 5, 56), Color("8b7452"))
		poly([Vector2(-56,-42),Vector2(-56,-60),Vector2(-42,-60),Vector2(-42,-83),Vector2(-26,-83),Vector2(-26,-105),Vector2(-10,-105),Vector2(-10,-132),Vector2(8,-132),Vector2(8,-114),Vector2(28,-114),Vector2(28,-90),Vector2(43,-90),Vector2(43,-68),Vector2(58,-68),Vector2(58,-45),Vector2(40,-45),Vector2(40,-32),Vector2(-35,-32),Vector2(-35,-42)], "233e31")
		poly([Vector2(-42,-63),Vector2(-25,-83),Vector2(-10,-114),Vector2(6,-126),Vector2(18,-93),Vector2(38,-64),Vector2(26,-50),Vector2(-16,-48)], "3c5d3d")
		for p in [Vector2(-12,-104),Vector2(-31,-76),Vector2(5,-86),Vector2(21,-58)]:
			draw_rect(Rect2(p,Vector2(18,6)),Color("547548"))
	elif kind == "tent":
		draw_rect(Rect2(-w-10,-h+10,footprint.x+24,h),Color(0.1,0.13,0.1,0.35))
		poly([Vector2(-w,0),Vector2(-w,-h),Vector2(0,-h-65),Vector2(w,-h),Vector2(w,0)], "514b3b")
		poly([Vector2(-w,-h),Vector2(0,-h-65),Vector2(w,-h),Vector2(0,-34)], "c1b384")
		poly([Vector2(-w,-h),Vector2(0,-34),Vector2(0,0),Vector2(-w,0)], "9d926c")
		poly([Vector2(0,-34),Vector2(w,-h),Vector2(w,0),Vector2(0,0)], "6d7055")
		poly([Vector2(12,-4),Vector2(w-18,-4),Vector2(w-18,-67)], "31382f")
		draw_line(Vector2(-w,-h),Vector2(0,-h-65),Color("ded0a2"),4)
		draw_line(Vector2(0,-h-65),Vector2(w,-h),Color("ded0a2"),4)
		for x in [-w-12,w+12]: draw_rect(Rect2(x,-12,4,18),Color("b8a675"))
	elif kind == "wall":
		draw_rect(Rect2(-w-5,-h-29,footprint.x+10,h+33),Color("393f38"))
		for y in range(int(-h),1,32):
			for x in range(int(-w),int(w),32):
				draw_rect(Rect2(x,y-32,30,29),Color("737768"))
				draw_rect(Rect2(x+2,y-30,27,6),Color("979a82"))
			draw_rect(Rect2(w-6,y-26,6,24),Color("515b50"))
	elif kind == "crate":
		draw_rect(Rect2(-w,-h-18,footprint.x,h+18),Color("554731"))
		draw_rect(Rect2(-w+3,-h-18,footprint.x-6,h+12),Color("9b8054"))
		for x in [-w+8,w-14]: draw_rect(Rect2(x,-h-17,6,h+16),Color("c0a270"))
		draw_line(Vector2(-w+8,-h-12),Vector2(w-8,-8),Color("6d573b"),5)
	elif kind == "rock":
		poly([Vector2(-w,0),Vector2(-w-5,-h+22),Vector2(-w/2,-h-22),Vector2(w/2,-h-26),Vector2(w,-h/2),Vector2(w-8,0)],"515d57")
		poly([Vector2(-w+4,-h+22),Vector2(-w/2,-h-22),Vector2(w/2,-h-26),Vector2(w-6,-h/2),Vector2(0,-h/2+4)],"8b9080")
		draw_line(Vector2(-w/2,-h-22),Vector2(w/2,-h-26),Color("b1b49a"),5)
	elif kind == "pond":
		draw_rect(Rect2(-w-12,-h-12,footprint.x+24,h+24),Color("56634e"))
		draw_rect(Rect2(-w,-h,footprint.x,h),Color("38595b"))
		draw_rect(Rect2(-w+16,-h+16,footprint.x-32,h-32),Color("42696b"))
		for i in range(16):
			var x := -w + 25 + (i * 73) % int(footprint.x - 50)
			var y := -h + 25 + (i * 47) % int(h - 50)
			draw_rect(Rect2(x,y,26,3),Color("67908a"))
