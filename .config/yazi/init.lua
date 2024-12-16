function Linemode:size_and_mtime()
	local time = math.floor(self._file.cha.mtime or 0)
	local display_time
	if time == 0 then
		display_time = "never"
	elseif os.date("%Y", time) == os.date("%Y") then
		display_time = os.date("%b %d %H:%M", time)
	else
		display_time = os.date("%b %d  %Y", time)
	end

	local size = self._file:size()
---@diagnostic disable-next-line: undefined-global
	return string.format("%s %s", size and ya.readable_size(size) or "-", display_time)
end

require("starship"):setup()