local Config = {
	DefaultOption = "base",
	BaseDirName = "base",
	CustomDirName = "custom",
	SourceCandidates = {
		"pkgs/setup_configs/src",
		".pesde/setup_configs/src",
		"src",
	},
	Submodule = {
		Path = "libs/bakery-dev-handbook",
		Url = "https://github.com/StoryBakery/bakery-dev-handbook",
	},
}

return Config
