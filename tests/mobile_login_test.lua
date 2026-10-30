-- Run from the API checkout: lua tests/mobile_login_test.lua
local checks = 0
local function check(value, message)
	checks = checks + 1
	assert(value, message)
end

MPAPI = { networking = {}, config = {}, sendDebugMessage = function() end }
dofile('domain/connection_state.lua')
dofile('domain/offline_reason.lua')
local identity = dofile('networking/device_identity.lua')
local filename = 'mpapi/mobile-device-id.txt'
local files, fail_write, fail_read, fail_directory = {}, false, false, false
local entropy_available, short_entropy = true, false
love = { filesystem = {
	getInfo = function(name) return files[name] and { type = 'file' } end,
	read = function(name) if fail_read then return nil, 'read failed' end return files[name] end,
	createDirectory = function() return not fail_directory end,
	write = function(name, value)
		if fail_write then return false, 'write failed' end
		files[name] = value
		return true
	end,
} }
local real_open = io.open
io.open = function(name, mode)
	check(name == '/dev/urandom' and mode == 'rb', 'identity uses the OS random source')
	if not entropy_available then return nil end
	return { read = function() return short_entropy and 'short' or string.rep('\0\n', 16) end, close = function() end }
end
local id = assert(identity.get())
check(#id == 71 and id:match('^mobile%-%x+$'), 'credential encodes all 32 random bytes, including newline and NUL')
check(files[filename] == id, 'credential is saved before login')
entropy_available = false
check(identity.get() == id, 'saved credential survives module reload without fresh entropy')
identity = dofile('networking/device_identity.lua')
check(identity.get() == id, 'saved credential survives a new module instance')
files[filename] = 'damaged'
check(identity.get() == nil and files[filename] == 'damaged', 'corrupt identity is never silently replaced')
files[filename] = id
fail_read = true
check(identity.get() == nil, 'unreadable identity blocks login')
fail_read = false
files = {}
check(identity.get() == nil, 'missing entropy blocks credential creation')
entropy_available, short_entropy = true, true
check(identity.get() == nil, 'short entropy blocks credential creation')
short_entropy, fail_directory = false, true
check(identity.get() == nil, 'directory creation failure blocks login')
fail_directory, fail_write = false, true
check(identity.get() == nil, 'write failure blocks login')
fail_write = false
io.open = real_open
local actual_id = assert(identity.get())
files = {}
check(identity.get() ~= actual_id, 'real OS entropy gives different installations different credentials')
files[filename] = id

dofile('networking/connection.lua')
local Connection = MPAPI.networking.connection
local unavailable = { available = function() return false end }
local available = {
	available = function() return true end,
	get_steam_id = function() return '76561198000000000' end,
	get_persona_name = function() return 'Desktop player' end,
	get_auth_ticket = function() return { ticket = 'proof', handle = 1 } end,
}
local function connect(official, steam, impersonate)
	local calls = {}
	local client = {
		authenticate_device = function(device, vars, create, username)
			calls.device, calls.username, calls.create = device, username, create
		end,
		authenticate_custom = function(device, vars)
			calls.custom, calls.ticket = device, vars.steam_ticket
		end,
	}
	local conn = Connection.new({ official = official, steam = steam, nakama_client = client, impersonate = impersonate })
	conn.on_state_change = function(_, context) calls.reason = context.offline_reason end
	conn:connect()
	return conn, calls
end
local conn, calls = connect(false, unavailable)
check(calls.device == id and calls.create and calls.username == nil, 'Steam-free Community login uses persisted id with server-assigned username')
check(conn.steam_name == 'Mobile-' .. id:sub(-8), 'mobile login has a stable default display name')
MPAPI.config.mobile_display_name = 'Mobile Alice'
conn, calls = connect(false, nil)
check(calls.device == id and conn.steam_name == 'Mobile Alice', 'missing Steam module and configured display name work')
conn, calls = connect(true, unavailable)
check(calls.reason == MPAPI.OfflineReason.STEAM_NOT_RUNNING and not calls.device, 'Official login still requires Steam')
conn, calls = connect(false, available)
check(calls.device == '76561198000000000' and conn.steam_name == 'Desktop player', 'desktop Community identity is preserved')
conn, calls = connect(true, available)
check(calls.custom == 'steam-ticket' and calls.ticket == 'proof' and not calls.device, 'Official login still uses Steam tickets')
conn, calls = connect(false, unavailable, { steamName = 'TestPlayer1' })
check(calls.device == 'bmp-dev-TestPlayer1', 'Dev impersonation keeps its existing identity')
files[filename] = 'damaged'
conn, calls = connect(false, unavailable)
check(not calls.device and calls.reason == MPAPI.OfflineReason.OTHER, 'invalid saved credential cannot trigger account creation')

-- Exercise the actual core startup event without loading the rest of the game.
local events, started, ready, callbacks = {}, 0, false, 0
SMODS = { current_mod = { path = '.', id = 'MultiplayerAPI' }, load_file = function()
	return function() return { stage_if_needed = function() end } end
end }
NFS = { getDirectoryItemsInfo = function() return {} end }
sendDebugMessage, sendWarnMessage = function() end, function() end
Event = function(event) return event end
G = { E_MANAGER = { add_event = function(_, event) events[#events + 1] = event end } }
dofile('core.lua')
local official = true
MPAPI._internal.conn = { is_official_server = function() return official end }
MPAPI._internal.set_ready = function(value) ready = value end
MPAPI._internal.run_ready_callbacks = function() callbacks = callbacks + 1 end
MPAPI.connect = function() started = started + 1 end
local startup = events[#events].func
check(startup() == false and started == 0, 'Official startup still waits for Steam')
official = false
MPAPI._internal.conn.force_steam_login = true
check(startup() == false and started == 0, 'forced Steam login still waits for Steam')
MPAPI._internal.conn.force_steam_login = false
check(startup() == true and ready and started == 1 and callbacks == 1, 'Community startup connects and registers gamemodes without Steam')
print(('ok   %d mobile login checks'):format(checks))
