local fs = require("@lune/fs")
local process = require("@lune/process")

local function trim(value: string): string
	return value:gsub("%s+$", "")
end

local function runGit(args: { string }): (boolean, string, string)
	local okExec, resultOrErr = pcall(process.exec, "git", args, { capture = true })
	if not okExec then
		return false, "", tostring(resultOrErr)
	end

	local result = resultOrErr
	return result.ok, result.stdout or "", result.stderr or ""
end

local function isGitRepoRoot(): boolean
	return fs.isDir(".git") or fs.isFile(".git")
end

local function isGitRepo(path: string): boolean
	local ok, stdout = runGit({ "-C", path, "rev-parse", "--is-inside-work-tree" })
	if not ok then
		return false
	end
	return trim(stdout) == "true"
end

local function findSubmoduleNameByPath(path: string): string?
	local ok, stdout = runGit({ "config", "-f", ".gitmodules", "--get-regexp", "^submodule\\..*\\.path$" })
	if not ok then
		return nil
	end

	for line in stdout:gmatch("[^\r\n]+") do
		local key, value = line:match("^(%S+)%s+(.+)$")
		if key and value == path then
			local name = key:match("^submodule%.(.+)%.path$")
			if name then
				return name
			end
		end
	end

	return nil
end

local function getSubmoduleUrl(name: string): string?
	local ok, stdout = runGit({
		"config",
		"-f",
		".gitmodules",
		("submodule.%s.url"):format(name),
	})
	if not ok then
		return nil
	end
	return trim(stdout)
end

local function ensureSubmodule(info, fsUtils)
	if not isGitRepoRoot() then
		return { ok = true, status = "skipped", reason = "not_git" }
	end

	local parentDir = fsUtils.dirname(info.Path)
	if parentDir ~= "" then
		fsUtils.mkdirp(parentDir)
	end

	local name = findSubmoduleNameByPath(info.Path)
	local added = false

	if not name then
		if fs.isDir(info.Path) or fs.isFile(info.Path) then
			if isGitRepo(info.Path) then
				local okAdd, _, err = runGit({ "submodule", "add", "-f", info.Url, info.Path })
				if not okAdd then
					return { ok = false, status = "git_failed", action = "submodule add", detail = err }
				end
				added = true
				name = findSubmoduleNameByPath(info.Path)
			else
				return { ok = false, status = "path_conflict" }
			end
		else
			local okAdd, _, err = runGit({ "submodule", "add", info.Url, info.Path })
			if not okAdd then
				return { ok = false, status = "git_failed", action = "submodule add", detail = err }
			end
			added = true
			name = findSubmoduleNameByPath(info.Path)
		end
	end

	if name then
		local currentUrl = getSubmoduleUrl(name)
		if currentUrl ~= nil and currentUrl ~= info.Url then
			local okSet, _, err = runGit({
				"config",
				"-f",
				".gitmodules",
				("submodule.%s.url"):format(name),
				info.Url,
			})
			if not okSet then
				return { ok = false, status = "git_failed", action = "update url", detail = err }
			end
			runGit({ "submodule", "sync", "--", info.Path })
		end
	end

	if not fs.isDir(info.Path) and not fs.isFile(info.Path) then
		local okInit, _, err = runGit({ "submodule", "update", "--init", "--", info.Path })
		if not okInit then
			return { ok = false, status = "git_failed", action = "submodule init", detail = err }
		end
	end

	if not isGitRepo(info.Path) then
		return { ok = false, status = "not_git_repo" }
	end

	local okRemote, remoteUrl = runGit({ "-C", info.Path, "remote", "get-url", "origin" })
	if okRemote then
		remoteUrl = trim(remoteUrl)
		if remoteUrl ~= info.Url then
			local okSet, _, err = runGit({ "-C", info.Path, "remote", "set-url", "origin", info.Url })
			if not okSet then
				return { ok = false, status = "git_failed", action = "set origin", detail = err }
			end
		end
	end

	local okFetch, _, fetchErr = runGit({ "-C", info.Path, "fetch", "origin", "--prune" })
	if not okFetch then
		return { ok = false, status = "git_failed", action = "fetch", detail = fetchErr }
	end

	local okHead, head = runGit({ "-C", info.Path, "rev-parse", "HEAD" })
	local okRemoteHead, remoteHead = runGit({ "-C", info.Path, "rev-parse", "origin/HEAD" })
	if okHead and okRemoteHead then
		head = trim(head)
		remoteHead = trim(remoteHead)
		if head ~= remoteHead then
			local okCheckout, _, checkoutErr = runGit({ "-C", info.Path, "checkout", remoteHead })
			if not okCheckout then
				return { ok = false, status = "git_failed", action = "checkout", detail = checkoutErr }
			end
			return { ok = true, status = "updated", added = added }
		end
	end

	if added then
		return { ok = true, status = "added" }
	end

	return { ok = true, status = "ok" }
end

return {
	ensure = ensureSubmodule,
}
