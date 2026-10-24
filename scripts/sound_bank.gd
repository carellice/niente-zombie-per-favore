extends RefCounted
## Shared, cached audio assets. Weapon signal names are explicit: an unknown
## event is silent, so a missing gun alias can never become an interface click.

const PATHS: Dictionary = {
	"pistol": "res://assets/audio/user/shot_pistol.wav",
	"shotgun": "res://assets/audio/user/shot_shotgun.wav",
	"sniper": "res://assets/audio/user/shot_sniper.wav",
	"smg": "res://assets/audio/user/shot_smg.wav",
	"reload_sniper": "res://assets/audio/user/reload_sniper.wav",
	"reload_shotgun": "res://assets/audio/user/reload_shotgun.wav",
	"reload_smg": "res://assets/audio/user/reload_smg.wav",
	"ui": "res://assets/audio/ui_click.wav",
	"cash": "res://assets/audio/cash.wav",
	"build": "res://assets/audio/build.wav",
	"ready": "res://assets/audio/ready.wav",
	"reward": "res://assets/audio/reward.wav",
	"visitor": "res://assets/audio/visitor.wav",
	"alarm": "res://assets/audio/alarm.wav",
	"breach": "res://assets/audio/breach.wav",
	"kill": "res://assets/audio/impact.wav",
	"reject": "res://assets/audio/reject.wav",
	"expedition": "res://assets/audio/expedition.wav"
}

const ALIASES: Dictionary = {
	"shot_pistol": "pistol", "shoot": "pistol", "shot": "pistol",
	"shot_shotgun": "shotgun", "shot_sniper": "sniper", "shot_smg": "smg",
	"click": "ui", "tap": "ui", "coin": "cash",
	"accept": "ready", "quest": "reward", "repair": "build",
	"hurt": "kill", "wave": "alarm", "menu": "ui"
}

static var _cache: Dictionary = {}

static func sound(kind: String) -> AudioStream:
	var key: String = str(ALIASES.get(kind, kind))
	if not PATHS.has(key):
		return null
	return _cached(str(PATHS[key]))

static func ambient() -> AudioStream:
	var stream: AudioStreamOggVorbis = _cached("res://assets/audio/shelter_ambience.ogg") as AudioStreamOggVorbis
	if stream != null:
		stream.loop = true
	return stream

static func music() -> AudioStream:
	return ambient()

static func _cached(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path) as AudioStream
	return _cache[path] as AudioStream
