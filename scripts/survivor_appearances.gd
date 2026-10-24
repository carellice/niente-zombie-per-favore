extends RefCounted
## New identities start at 8; saved looks 4..7 keep their original aliases.
## Bounds and rig UV coordinates refer to the same unmodified painted atlas.

const PATH: String = "res://assets/art/survivors-expanded.png"
const LABELS: Array[String] = ["Corriera", "Magliaia", "Cuoco", "Guardaboschi", "Elettricista", "Studente", "Falegname", "Pittrice"]
const BOUNDS: Array[Rect2i] = [
	Rect2i(50,45,303,468), Rect2i(467,52,251,460), Rect2i(823,25,264,486), Rect2i(1198,38,288,475),
	Rect2i(67,530,271,470), Rect2i(454,533,247,468), Rect2i(833,530,255,471), Rect2i(1198,535,295,466)
]
const HIP_HEIGHTS: Array[float] = [0.231,0.213,0.208,0.253,0.285,0.282,0.268,0.285]
const PARTS: Array[Dictionary] = [
	{"cut":420.0,"sole":513.0,"sole_left":513.0,"sole_right":508.0,
	 "left":[Vector4(187,405,148,225),Vector4(178,439,140,216),Vector4(166,467,136,199)],
	 "right":[Vector4(260,405,223,297),Vector4(262,439,227,297),Vector4(265,467,234,296)],
	 "boot_left":Rect2(126,466,80,47),"boot_right":Rect2(231,466,88,42)},
	{"cut":427.0,"sole":512.0,"sole_left":512.0,"sole_right":507.0,
	 "left":[Vector4(557,414,518,592),Vector4(549,446,510,590),Vector4(544,470,508,579)],
	 "right":[Vector4(630,414,592,666),Vector4(630,446,597,665),Vector4(638,470,606,668)],
	 "boot_left":Rect2(498,469,86,43),"boot_right":Rect2(600,469,96,38)},
	{"cut":442.0,"sole":511.0,"sole_left":511.0,"sole_right":507.0,
	 "left":[Vector4(899,410,861,943),Vector4(893,444,853,935),Vector4(887,468,854,924)],
	 "right":[Vector4(986,410,943,1028),Vector4(992,444,954,1029),Vector4(1001,468,964,1040)],
	 "boot_left":Rect2(844,464,87,47),"boot_right":Rect2(959,464,100,43)},
	{"cut":414.0,"sole":513.0,"sole_left":513.0,"sole_right":509.0,
	 "left":[Vector4(1310,393,1270,1345),Vector4(1298,438,1258,1341),Vector4(1287,470,1255,1317)],
	 "right":[Vector4(1379,393,1345,1415),Vector4(1383,438,1347,1421),Vector4(1386,470,1355,1420)],
	 "boot_left":Rect2(1243,466,87,47),"boot_right":Rect2(1350,466,101,43)},
	{"cut":889.0,"sole":1000.0,"sole_left":1000.0,"sole_right":995.0,
	 "left":[Vector4(175,866,132,211),Vector4(158,915,119,201),Vector4(151,947,116,184)],
	 "right":[Vector4(246,866,211,282),Vector4(252,915,214,291),Vector4(254,947,221,291)],
	 "boot_left":Rect2(105,944,88,56),"boot_right":Rect2(215,944,109,51)},
	{"cut":889.0,"sole":1001.0,"sole_left":1001.0,"sole_right":995.0,
	 "left":[Vector4(558,869,518,587),Vector4(541,919,500,578),Vector4(531,948,495,567)],
	 "right":[Vector4(621,869,587,654),Vector4(628,919,593,664),Vector4(632,948,597,669)],
	 "boot_left":Rect2(484,945,95,56),"boot_right":Rect2(593,945,108,50)},
	{"cut":894.0,"sole":1001.0,"sole_left":1001.0,"sole_right":995.0,
	 "left":[Vector4(922,875,883,960),Vector4(906,918,866,949),Vector4(898,947,865,936)],
	 "right":[Vector4(996,875,960,1039),Vector4(1006,918,968,1042),Vector4(1017,947,972,1050)],
	 "boot_left":Rect2(851,944,101,57),"boot_right":Rect2(967,944,116,51)},
	{"cut":891.0,"sole":1001.0,"sole_left":1001.0,"sole_right":994.0,
	 "left":[Vector4(1317,868,1280,1353),Vector4(1306,917,1268,1342),Vector4(1295,946,1268,1327)],
	 "right":[Vector4(1389,868,1353,1423),Vector4(1395,917,1360,1431),Vector4(1397,946,1369,1431)],
	 "boot_left":Rect2(1254,944,90,57),"boot_right":Rect2(1364,944,103,50)}
]
