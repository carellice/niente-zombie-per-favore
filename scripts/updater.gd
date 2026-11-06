extends Node
## Checks GitHub Releases and installs the newest build for this platform.
## Windows downloads and runs the setup silently; Android hands the APK to the
## system browser, then the package installer replaces the app (same signature).

signal changed

const API_URL = "https://api.github.com/repos/carellice/niente-zombie-per-favore/releases/latest"
const RELEASES_URL = "https://github.com/carellice/niente-zombie-per-favore/releases/latest"
enum State { IDLE, CHECKING, CURRENT, AVAILABLE, DOWNLOADING, FAILED }

var state: State = State.IDLE
var latest_version: String = ""
var asset_url: String = ""
var asset_size: int = 0
var asset_digest: String = ""
var _http: HTTPRequest

func _ready() -> void:
	# Tests, editor runs and capture previews never touch the network.
	if DisplayServer.get_name()=="headless" or OS.has_feature("editor") or OS.get_cmdline_user_args().size()>0: return
	check()

static func current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version","0"))

static func is_newer(candidate: String, current: String) -> bool:
	var a: PackedStringArray = candidate.strip_edges().trim_prefix("v").split(".")
	var b: PackedStringArray = current.strip_edges().trim_prefix("v").split(".")
	for i: int in range(maxi(a.size(),b.size())):
		var x: int = int(a[i]) if i<a.size() else 0
		var y: int = int(b[i]) if i<b.size() else 0
		if x!=y: return x>y
	return false

func progress() -> float:
	if state!=State.DOWNLOADING or not is_instance_valid(_http) or asset_size<=0: return 0.0
	return clampf(float(_http.get_downloaded_bytes())/asset_size,0.0,1.0)

func check() -> void:
	if state==State.CHECKING or state==State.DOWNLOADING: return
	_set_state(State.CHECKING)
	_request(API_URL,_on_release,"",20.0)

func install() -> void:
	if state!=State.AVAILABLE: return
	if OS.has_feature("android"):
		# The browser keeps the download visible; tapping it opens Android's installer.
		if OS.shell_open(asset_url)!=OK: OS.shell_open(RELEASES_URL)
		return
	var path: String = OS.get_user_data_dir().path_join("updates/Niente-Zombie-Per-Favore-Setup-%s.exe" % latest_version)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_set_state(State.DOWNLOADING)
	_request(asset_url,_on_downloaded.bind(path),path,0.0)

func _request(url: String, callback: Callable, file: String, timeout: float) -> void:
	if is_instance_valid(_http): _http.queue_free()
	_http = HTTPRequest.new()
	_http.timeout = timeout
	_http.download_file = file
	add_child(_http)
	_http.request_completed.connect(callback)
	var headers: PackedStringArray = ["User-Agent: NienteZombiePerFavore/"+current_version(),"Accept: application/vnd.github+json"]
	if _http.request(url,headers)!=OK: _set_state(State.FAILED)

func _on_release(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200:
		_set_state(State.FAILED)
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data)!=TYPE_DICTIONARY:
		_set_state(State.FAILED)
		return
	latest_version = str(data.get("tag_name","")).trim_prefix("v")
	asset_url = ""
	var wanted: String = ".apk" if OS.has_feature("android") else "-Setup-"
	for asset: Variant in data.get("assets",[]):
		if typeof(asset)!=TYPE_DICTIONARY: continue
		var name: String = str(asset.get("name",""))
		if name.contains(wanted) and (name.ends_with(".apk") or name.ends_with(".exe")):
			asset_url = str(asset.get("browser_download_url",""))
			asset_size = int(asset.get("size",0))
			asset_digest = str(asset.get("digest","")).trim_prefix("sha256:")
	var available: bool = asset_url.begins_with("https://") and is_newer(latest_version,current_version())
	_set_state(State.AVAILABLE if available else State.CURRENT)

func _on_downloaded(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray, path: String) -> void:
	var valid: bool = result==HTTPRequest.RESULT_SUCCESS and code==200 and FileAccess.file_exists(path)
	if valid and asset_size>0:
		var file: FileAccess = FileAccess.open(path,FileAccess.READ)
		valid = file!=null and file.get_length()==asset_size
		file = null
	# A corrupted or tampered setup is never executed.
	if valid and asset_digest.length()==64: valid = FileAccess.get_sha256(path)==asset_digest
	if not valid:
		DirAccess.remove_absolute(path)
		_set_state(State.AVAILABLE)
		get_node("/root/Game").toast.emit("Download non riuscito. Controlla la connessione e riprova.")
		return
	# Inno relaunches the game after a silent upgrade; saves live in AppData.
	get_node("/root/Game").save_game()
	if OS.create_process(path,["/SILENT","/SUPPRESSMSGBOXES","/NORESTART"])<=0:
		_set_state(State.FAILED)
		return
	get_tree().quit()

func _set_state(value: State) -> void:
	state = value
	changed.emit()
