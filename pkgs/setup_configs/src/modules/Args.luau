local process = require("@lune/process")

local function parseOption(defaultOption: string): string
	local optionName = defaultOption
	local i = 1
	while i <= #process.args do
		local arg = process.args[i]
		if arg == "--option" or arg == "-o" then
			i += 1
			if process.args[i] and process.args[i] ~= "" then
				optionName = process.args[i]
			end
		end
		i += 1
	end
	return optionName
end

return parseOption
