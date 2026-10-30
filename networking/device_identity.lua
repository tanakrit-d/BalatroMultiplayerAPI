-- A Community login credential, stored outside the mod so updates preserve it.
-- Never use the gameplay RNG: it may be seeded identically on every device.
local identity = {}
local directory = 'mpapi'
local filename = directory .. '/mobile-device-id.txt'

function identity.get()
	local fs = love.filesystem
	if fs.getInfo(filename) then
		local value, err = fs.read(filename)
		if not value then return nil, err or 'Could not read the saved device identity' end
		if #value ~= 71 or not value:match('^mobile%-%x+$') then
			return nil, 'Invalid saved device identity; restore it from backup'
		end
		return value
	end

	-- iOS and Android expose OS randomness through /dev/urandom. Fail rather
	-- than creating a predictable credential if that source is unavailable.
	local source = io.open('/dev/urandom', 'rb')
	if not source then return nil, 'OS random source is unavailable' end
	local bytes = source:read(32)
	source:close()
	if not bytes or #bytes ~= 32 then return nil, 'Could not read OS randomness' end
	local value = 'mobile-' .. bytes:gsub('.', function(byte) return ('%02x'):format(byte:byte()) end)
	local ok, err = fs.createDirectory(directory)
	if not ok then return nil, err or 'Could not create the identity directory' end
	ok, err = fs.write(filename, value)
	if not ok then return nil, err or 'Could not save the device identity' end
	-- Only authenticate with a credential that was successfully persisted.
	return value
end

MPAPI.networking.device_identity = identity
return identity
