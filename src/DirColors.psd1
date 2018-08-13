@{
	RootModule = 'DirColors.psm1'
	ModuleVersion = '1.1.2'
	GUID = 'd0f72b30-1220-4ee8-9f13-93ff69e6f061'
	Author = 'Dustin L. Howett'
	CompanyName = 'HowettNET'
	Copyright = '(c) 2017 Dustin L. Howett. All rights reserved.'
	Description = 'Provides dircolors-like functionality to all System.IO.FilesystemInfo formatters'
	FunctionsToExport = @(
        "Format-ColorizedFilename",
        "Format-ColorizedLinkTarget",
        "Format-ColorizedFilenameAndLinkTarget",
        "Import-DirColors",
        "Update-DirColors",

        "ConvertTo-LSColors",
        "ConvertFrom-LSColors"
    )
	CmdletsToExport = @()
	VariablesToExport = '*'
	AliasesToExport = @()
	PrivateData = @{
		PSData = @{
			Tags = @("color", "ansi", "gci", "get-childitem", "dircolors")
			LicenseUri = 'https://gitlab.howett.net/powershell/DirColors/blob/master/LICENSE'
			ProjectUri = 'https://gitlab.howett.net/powershell/DirColors'
		}
	}
}

# vim: ts=4 sw=4 et
