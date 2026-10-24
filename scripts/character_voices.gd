extends RefCounted
## Offline character voices. This bank has no scene, timer or game-state coupling.
## Caller controls cadence, visibility, pause, gain and the effects preference.

const DIRECTORY := "res://assets/audio/voices/"
const CIVILIAN_VARIANTS := 0
const ZOMBIE_VARIANTS := 3
const ZOMBIE_KINDS := ["walker", "runner", "brute"]
static var _cache: Dictionary = {}

static func zombie(kind: String, variant: int) -> AudioStream:
	if not ZOMBIE_KINDS.has(kind):
		return null
	return _cached("zombie_%s_%02d.wav" % [kind, posmod(variant, ZOMBIE_VARIANTS) + 1])

static func civilian(_look: int, _variant: int) -> AudioStream:
	# Survivor voices are deliberately disabled until their next audio pass.
	return null

static func zombie_count(kind: String) -> int:
	return ZOMBIE_VARIANTS if ZOMBIE_KINDS.has(kind) else 0

static func civilian_count(_look: int) -> int:
	return CIVILIAN_VARIANTS

static func _cached(filename: String) -> AudioStream:
	var path := DIRECTORY + filename
	if not _cache.has(path):
		_cache[path] = load(path) as AudioStream
	return _cache[path] as AudioStream
