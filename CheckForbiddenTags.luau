local fs = require("@lune/fs")
local process = require("@lune/process")

local ROOTS = {
	"src",
	"docs",
}

local SKIP_DIRECTORIES = {
	[".git"] = true,
	["node_modules"] = true,
	["build"] = true,
	["dist"] = true,
	["Packages"] = true,
	["roblox_packages"] = true,
	[".pesde"] = true,
	["darklua_build"] = true,
}

local CHECK_EXTENSIONS = {
	".lua",
	".luau",
}

local FORBIDDEN_TAGS = {
	{
		token = {
			"@module",
			"@constructor",
		},
		reason = "document-based-comment.md 에 정의되지 않은 moonwave 태그",
	},
}

local function joinPath(a: string, b: string): string
	if a == "" or a == "." then
		return b
	end
	return a .. "/" .. b
end

local function shouldCheckFile(path: string): boolean
	for _, ext in ipairs(CHECK_EXTENSIONS) do
		if path:sub(-#ext) == ext then
			return true
		end
	end
	return false
end

local function inspectFile(path: string, violations)
	local ok, contents = pcall(fs.readFile, path)
	if not ok or not contents then
		return
	end

	local lines = string.split(contents, "\n")
	for lineNumber, line in ipairs(lines) do
		for _, forbidden in ipairs(FORBIDDEN_TAGS) do
			local rawTokens = forbidden.token
			if rawTokens == nil then
				continue
			end

			local tokens = rawTokens
			if typeof(rawTokens) ~= "table" then
				tokens = { rawTokens }
			end

			for _, token in ipairs(tokens) do
				if token ~= nil and line:find(token, 1, true) then
					table.insert(violations, {
						path = path,
						line = lineNumber,
						token = token,
						reason = forbidden.reason,
						snippet = line,
					})
					break
				end
			end
		end
	end
end

local function traverse(dir: string, violations)
	local ok, entries = pcall(fs.readDir, dir)
	if not ok or not entries then
		return
	end

	for _, entry in ipairs(entries) do
		if entry == "." or entry == ".." then
			continue
		end

		local path = joinPath(dir, entry)

		if fs.isDir(path) then
			if not SKIP_DIRECTORIES[entry] then
				traverse(path, violations)
			end
		elseif fs.isFile(path) and shouldCheckFile(path) then
			inspectFile(path, violations)
		end
	end
end

local function main()
	local violations = {}

	for _, root in ipairs(ROOTS) do
		if fs.isDir(root) then
			traverse(root, violations)
		elseif fs.isFile(root) and shouldCheckFile(root) then
			inspectFile(root, violations)
		end
	end

	if #violations > 0 then
		print("금지된 moonwave 태그가 발견되었습니다:")
		for _, violation in ipairs(violations) do
			print(string.format(
				"%s:%d: %s (%s)",
				violation.path,
				violation.line,
				violation.snippet,
				violation.reason
			))
		end
		process.exit(1)
	else
		print("금지된 moonwave 태그가 없습니다.")
	end
end

local ok, err = pcall(main)
if not ok then
	print(tostring(err))
	process.exit(1)
end

return true
