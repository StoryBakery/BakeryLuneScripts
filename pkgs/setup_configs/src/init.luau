--> 설정 파일과 서브모듈을 워크스페이스 루트에 설치하는 Lune 스크립트입니다.
--[[
	SetupConfigs
	base 설정 파일을 워크스페이스 루트에 설치합니다.
	--option 을 지정하면 base + custom/<option> 을 순서대로 적용합니다.
	bakery-dev-handbook 서브모듈을 libs 경로에 유지합니다.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local MODULE_ROOT_CANDIDATES = {
	"pkgs/setup_configs/src",
	".pesde/setup_configs/src",
	"src",
}

local function resolveModuleRoot(): string?
	for _, candidate in ipairs(MODULE_ROOT_CANDIDATES) do
		if fs.isDir(candidate .. "/modules") then
			return candidate
		end
	end
	return nil
end

local function loadModule(root: string, name: string)
	local ok, moduleOrErr = pcall(require, root .. "/modules/" .. name)
	if not ok then
		print(`[오류] 모듈 "{name}" 를 불러오지 못했습니다.`)
		print(tostring(moduleOrErr))
		process.exit(1)
	end
	return moduleOrErr
end

local moduleRoot = resolveModuleRoot()
if not moduleRoot then
	print("[오류] setup_configs 모듈 경로를 찾지 못했습니다.")
	process.exit(1)
end

local Config = loadModule(moduleRoot, "Config")
local FsUtils = loadModule(moduleRoot, "FsUtils")
local parseOption = loadModule(moduleRoot, "Args")
local Installer = loadModule(moduleRoot, "Installer")
local Submodule = loadModule(moduleRoot, "Submodule")

local optionName = parseOption(Config.DefaultOption)

local okInstall, installResult = Installer.install(Config, FsUtils, optionName)
if not okInstall then
	if installResult.code == "missing_source_root" then
		print("[오류] setup_configs 소스 경로를 찾지 못했습니다.")
	elseif installResult.code == "missing_base_dir" then
		print(`[오류] base 디렉터리를 찾지 못했습니다: {installResult.baseRoot}`)
	elseif installResult.code == "missing_option" then
		print(`[오류] 옵션 "{installResult.optionName}" 디렉터리를 찾지 못했습니다.`)
		local available = installResult.available or {}
		if #available > 0 then
			print("사용 가능한 옵션: " .. table.concat(available, ", "))
		end
	else
		print("[오류] 설정 파일 설치에 실패했습니다.")
	end
	process.exit(1)
end

if installResult.optionName ~= Config.DefaultOption then
	print(
		`[설치] base + 옵션 "{installResult.optionName}" 적용 완료 (base {installResult.baseCount}개, 옵션 {installResult.optionCount}개)`
	)
else
	print(`[설치] base 적용 완료 ({installResult.baseCount}개)`)
end

local submoduleResult = Submodule.ensure(Config.Submodule, FsUtils)
local submodulePath = Config.Submodule.Path

if not submoduleResult.ok then
	if submoduleResult.status == "path_conflict" then
		print(`[오류] "{submodulePath}" 경로에 기존 폴더가 있어 서브모듈을 추가하지 못했습니다.`)
	elseif submoduleResult.status == "not_git_repo" then
		print(`[오류] "{submodulePath}" 경로가 Git 저장소가 아닙니다.`)
	elseif submoduleResult.status == "git_failed" then
		local action = submoduleResult.action or "git"
		local detail = submoduleResult.detail or ""
		print(`[오류] git 명령 실패 ({action}): {detail}`)
	else
		print(`[오류] "{submodulePath}" 서브모듈 처리에 실패했습니다.`)
	end
	process.exit(1)
end

if submoduleResult.status == "skipped" then
	print("[정보] Git 저장소가 아니어서 서브모듈 설치를 건너뜁니다.")
elseif submoduleResult.status == "added" then
	print(`[서브모듈] "{submodulePath}" 추가 완료`)
elseif submoduleResult.status == "updated" then
	print(`[서브모듈] "{submodulePath}" 업데이트 완료`)
elseif submoduleResult.status == "ok" then
	print(`[서브모듈] "{submodulePath}" 최신 상태입니다.`)
end
