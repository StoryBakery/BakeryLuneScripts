local fs = require("@lune/fs")

local function listOptions(customRoot: string, fsUtils): { string }
	local options: { string } = {}
	if not fs.isDir(customRoot) then
		return options
	end

	local ok, entries = pcall(fs.readDir, customRoot)
	if not ok or entries == nil then
		return options
	end

	for _, entry in ipairs(entries) do
		local path = fsUtils.join(customRoot, entry)
		if fs.isDir(path) then
			table.insert(options, entry)
		end
	end

	table.sort(options)
	return options
end

local function resolveSourceRoot(candidates: { string }, baseDirName: string, fsUtils): string?
	for _, candidate in ipairs(candidates) do
		local basePath = fsUtils.join(candidate, baseDirName)
		if fs.isDir(basePath) then
			return candidate
		end
	end
	return nil
end

local function applyRoot(root: string, fsUtils): number
	local files = fsUtils.collectFiles(root)
	for _, item in ipairs(files) do
		fsUtils.copyFile(item.src, item.rel)
	end
	return #files
end

local function install(config, fsUtils, optionName: string)
	local srcRoot = resolveSourceRoot(config.SourceCandidates, config.BaseDirName, fsUtils)
	if not srcRoot then
		return false, { code = "missing_source_root" }
	end

	local baseRoot = fsUtils.join(srcRoot, config.BaseDirName)
	if not fs.isDir(baseRoot) then
		return false, { code = "missing_base_dir", baseRoot = baseRoot }
	end

	local customRoot = fsUtils.join(srcRoot, config.CustomDirName)
	local optionRoot = nil

	if optionName ~= config.DefaultOption then
		optionRoot = fsUtils.join(customRoot, optionName)
		if not fs.isDir(optionRoot) then
			local available = listOptions(customRoot, fsUtils)
			return false, {
				code = "missing_option",
				optionName = optionName,
				available = available,
			}
		end
	end

	local baseCount = applyRoot(baseRoot, fsUtils)
	local optionCount = 0

	if optionRoot ~= nil then
		optionCount = applyRoot(optionRoot, fsUtils)
	end

	return true, {
		baseCount = baseCount,
		optionCount = optionCount,
		optionName = optionName,
	}
end

return {
	install = install,
}
