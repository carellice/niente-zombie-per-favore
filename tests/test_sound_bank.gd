extends SceneTree
## Prevents the former shot_pistol -> generic UI click regression.
const SoundBank = preload("res://scripts/sound_bank.gd")
var checks: int = 0
var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for name: String in ["shot_pistol", "shot_shotgun", "shot_sniper", "shot_smg", "reload_sniper", "reload_shotgun", "reload_smg", "ui", "click", "kill", "ready", "build", "reward", "cash", "visitor", "breach", "alarm", "expedition", "accept", "repair", "reject", "hurt", "coin", "quest"]:
		expect(SoundBank.sound(name) is AudioStreamWAV, "Missing audio event: " + name)
	var pistol: AudioStream = SoundBank.sound("shot_pistol")
	var shotgun: AudioStream = SoundBank.sound("shot_shotgun")
	var sniper: AudioStream = SoundBank.sound("shot_sniper")
	for key: String in ["pistol", "shotgun", "sniper", "smg", "reload_shotgun", "reload_sniper", "reload_smg"]:
		expect(SoundBank.sound(key).resource_path.begins_with("res://assets/audio/user/"), "Active audio comes from supplied recordings: " + key)
	expect(pistol == SoundBank.sound("pistol"), "Pistol alias must share the cached recording")
	expect(shotgun == SoundBank.sound("shotgun"), "Shotgun alias must share the cached recording")
	expect(sniper == SoundBank.sound("sniper"), "Sniper alias must share the cached recording")
	expect(SoundBank.sound("shot_smg") == SoundBank.sound("smg"), "SMG alias shares its real recording")
	expect(SoundBank.sound("shot_smg").get_length() <= 0.16, "SMG report supports rapid fire")
	for weapon: String in ["sniper", "shotgun", "smg"]:
		var reload_clip: AudioStream = SoundBank.sound("reload_" + weapon)
		expect(reload_clip != SoundBank.sound("shot_" + weapon) and reload_clip != SoundBank.sound("click"), "Reload is a distinct mechanical recording: " + weapon)
		expect(reload_clip == SoundBank.sound("reload_" + weapon), "Reload resources are cached: " + weapon)
	expect(SoundBank.sound("reload_smg").get_length() < 0.08, "Automatic action fits inside the 120ms firing interval")
	expect(SoundBank.sound("reload_sniper").get_length() >= 0.55, "Precision rifle has an audible loading sequence")
	expect(pistol != shotgun and shotgun != sniper and pistol != sniper, "Weapons need distinct real recordings")
	expect(pistol != SoundBank.sound("click"), "A gunshot must never resolve to the interface click")
	expect(SoundBank.sound("ui").resource_path == "res://assets/audio/ui_click.wav", "Interface uses the new soft click")
	expect(SoundBank.sound("ui").get_length() >= 0.06 and SoundBank.sound("ui").get_length() <= 0.18, "Interface feedback stays short")
	expect(SoundBank.sound("shot_unknown") == null, "Unknown gun signal must be silent")
	expect(SoundBank.sound("unknown_event") == null, "Unknown event must be silent")
	expect(pistol.get_length() > 0.45 and pistol.get_length() < 0.7, "Pistol retains its recorded tail")
	expect(shotgun.get_length() > 0.9 and sniper.get_length() > 1.1, "Rifle and shotgun recorded tails")
	var bed: AudioStream = SoundBank.ambient()
	expect(bed is AudioStreamOggVorbis, "Ambient file must be a compressed stereo stream")
	expect(absf(bed.get_length() - 40.0) < 0.1, "Continuous ambient loop lasts forty seconds")
	expect((bed as AudioStreamOggVorbis).loop, "Ambient must loop without clocked note events")
	expect(bed == SoundBank.music(), "Music and ambient APIs must reuse one cached resource")
	print("Sound bank: ", checks, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
