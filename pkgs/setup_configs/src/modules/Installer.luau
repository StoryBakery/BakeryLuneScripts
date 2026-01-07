--[[
	옵션 기반 설정 파일을 설치하는 모듈입니다.
]]

local FileSystem = require("@lune/fs")

local function listOptionNames(optionsRoot: string, fileSystemUtils): { string }
	local optionNames: { string } = {}
	if not FileSystem.isDir(optionsRoot) then
		return optionNames
	end

	local ok, entries = pcall(FileSystem.readDir, optionsRoot)
	if not ok or entries == nil then
		return optionNames
	end

	for _, entry in entries do
		local path = fileSystemUtils.JoinPath(optionsRoot, entry)
		if FileSystem.isDir(path) then
			table.insert(optionNames, entry)
		end
	end

	table.sort(optionNames)
	return optionNames
end

local function resolveSourceRoot(
	candidates: { string },
	optionsRootName: string,
	defaultOptionName: string,
	fileSystemUtils
): string?
	for _, candidate in candidates do
		local optionsRoot = fileSystemUtils.JoinPath(candidate, optionsRootName)
		local baseRoot = fileSystemUtils.JoinPath(optionsRoot, defaultOptionName)
		if FileSystem.isDir(baseRoot) then
			return candidate
		end
	end
	return nil
end

local function applyRoot(root: string, fileSystemUtils): number
	local files = fileSystemUtils.CollectFiles(root)
	for _, item in files do
		fileSystemUtils.CopyFile(item.SourcePath, item.RelativePath)
	end
	return #files
end

local function install(config, fileSystemUtils, optionName: string)
	local srcRoot = resolveSourceRoot(
		config.SourceCandidates,
		config.OptionsRootName,
		config.DefaultOptionName,
		fileSystemUtils
	)
	if not srcRoot then
		return false, { Code = "MissingSourceRoot" }
	end

	local optionsRoot = fileSystemUtils.JoinPath(srcRoot, config.OptionsRootName)
	local baseRoot = fileSystemUtils.JoinPath(optionsRoot, config.DefaultOptionName)
	if not FileSystem.isDir(baseRoot) then
		return false, { Code = "MissingBaseOption", BaseRoot = baseRoot }
	end

	local optionRoot = nil
	if optionName ~= config.DefaultOptionName then
		optionRoot = fileSystemUtils.JoinPath(optionsRoot, optionName)
		if not FileSystem.isDir(optionRoot) then
			local availableOptions = listOptionNames(optionsRoot, fileSystemUtils)
			return false, {
				Code = "MissingOption",
				OptionName = optionName,
				AvailableOptions = availableOptions,
			}
		end
	end

	local baseCount = applyRoot(baseRoot, fileSystemUtils)
	local optionCount = 0
	if optionRoot ~= nil then
		optionCount = applyRoot(optionRoot, fileSystemUtils)
	end

	return true, {
		BaseCount = baseCount,
		OptionCount = optionCount,
		OptionName = optionName,
	}
end

local Installer = {
	Install = install,
}

return Installer
