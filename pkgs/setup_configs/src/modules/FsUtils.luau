local fs = require("@lune/fs")

local function join(a: string, b: string): string
	if a == "" or a == "." then
		return b
	end
	if b == "" or b == "." then
		return a
	end
	if a:sub(-1) == "/" then
		return a .. b
	end
	return a .. "/" .. b
end

local function dirname(path: string): string
	return (path:match("^(.*)/[^/]+$")) or ""
end

local function mkdirp(dir: string)
	if dir == "" or dir == "." then
		return
	end
	if not fs.isDir(dir) then
		local parent = dirname(dir)
		if parent ~= "" and not fs.isDir(parent) then
			mkdirp(parent)
		end
		local ok = pcall(function()
			fs.writeDir(dir)
		end)
		if not ok and not fs.isDir(dir) then
			fs.writeDir(dir)
		end
	end
end

local function ensureParent(path: string)
	local parent = dirname(path)
	if parent ~= "" then
		mkdirp(parent)
	end
end

local function copyFile(src: string, dst: string)
	ensureParent(dst)
	local ok = pcall(function()
		fs.copy(src, dst, { overwrite = true })
	end)
	if not ok then
		fs.writeFile(dst, fs.readFile(src))
	end
end

local function collectFiles(root: string)
	local collected = {}

	local function walk(dir: string, relBase: string)
		local ok, entries = pcall(fs.readDir, dir)
		if not ok or entries == nil then
			return
		end

		for _, entry in ipairs(entries) do
			local abs = join(dir, entry)
			local rel = join(relBase, entry)

			if fs.isDir(abs) then
				walk(abs, rel)
			elseif fs.isFile(abs) then
				table.insert(collected, { src = abs, rel = rel })
			end
		end
	end

	walk(root, "")
	return collected
end

local function exists(path: string): boolean
	return fs.isDir(path) or fs.isFile(path)
end

return {
	join = join,
	dirname = dirname,
	mkdirp = mkdirp,
	ensureParent = ensureParent,
	copyFile = copyFile,
	collectFiles = collectFiles,
	exists = exists,
}
