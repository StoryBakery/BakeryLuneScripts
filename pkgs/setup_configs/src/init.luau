--> 설정 파일과 서브모듈을 워크스페이스 루트에 설치하는 Lune 스크립트입니다.
--[[
	SetupConfigs
	base 옵션 파일을 워크스페이스 루트에 설치합니다.
	--option 을 지정하면 base + options/<option> 을 순서대로 적용합니다.
	bakery-dev-handbook 서브모듈을 libs 경로에 유지합니다.
]]

local Process = require("@lune/process")

local function loadModule(name: string)
	local modulePath = "./src/modules/" .. name
	local ok, moduleOrErr = pcall(require, modulePath)
	if not ok then
		print(`[Error] Failed to load module "{name}".`)
		print(tostring(moduleOrErr))
		Process.exit(1)
	end
	return moduleOrErr
end

local Config = loadModule("Config")
local FileSystemUtils = loadModule("FileSystemUtils")
local ParseOption = loadModule("ParseOption")
local Installer = loadModule("Installer")
local Submodule = loadModule("Submodule")

local optionName = ParseOption(Config.DefaultOptionName)

local okInstall, installResult = Installer.Install(Config, FileSystemUtils, optionName)
if not okInstall then
	if installResult.Code == "MissingSourceRoot" then
		print("[Error] Failed to locate setup_configs source root.")
	elseif installResult.Code == "MissingBaseOption" then
		print(`[Error] Failed to find base option directory: {installResult.BaseRoot}`)
	elseif installResult.Code == "MissingOption" then
		print(`[Error] Failed to find option "{installResult.OptionName}".`)
		local availableOptions = installResult.AvailableOptions or {}
		if #availableOptions > 0 then
			print(`[Info] Available options: {table.concat(availableOptions, ", ")}`)
		end
	else
		print("[Error] Config install failed.")
	end
	Process.exit(1)
end

if installResult.OptionName ~= Config.DefaultOptionName then
	local installMessage = `[Install] Base + option "{installResult.OptionName}" applied \z
	(base {installResult.BaseCount}, option {installResult.OptionCount})`
	print(installMessage)
else
	print(`[Install] Base applied ({installResult.BaseCount})`)
end

local submoduleResult = Submodule.Ensure(Config.Submodule, FileSystemUtils)
local submodulePath = Config.Submodule.Path

if not submoduleResult.IsOk then
	if submoduleResult.Status == "PathConflict" then
		print(`[Error] Path "{submodulePath}" already exists and cannot be used for a submodule.`)
	elseif submoduleResult.Status == "NotGitRepo" then
		print(`[Error] Path "{submodulePath}" is not a Git repository.`)
	elseif submoduleResult.Status == "GitFailed" then
		local action = submoduleResult.Action or "Git"
		local detail = submoduleResult.Detail or ""
		print(`[Error] Git command failed ({action}): {detail}`)
	else
		print(`[Error] Failed to process submodule "{submodulePath}".`)
	end
	Process.exit(1)
end

if submoduleResult.Status == "Skipped" then
	if submoduleResult.Reason == "MissingGit" then
		print("[Info] Git is not available. Skipping submodule setup.")
	elseif submoduleResult.Reason == "NotGitRepo" then
		print("[Info] Not a Git repository. Skipping submodule setup.")
	else
		print("[Info] Skipping submodule setup.")
	end
elseif submoduleResult.Status == "Added" then
	print(`[Submodule] "{submodulePath}" added`)
elseif submoduleResult.Status == "Updated" then
	print(`[Submodule] "{submodulePath}" updated`)
elseif submoduleResult.Status == "Ok" then
	print(`[Submodule] "{submodulePath}" is up to date`)
end
