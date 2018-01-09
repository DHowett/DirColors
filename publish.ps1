[CmdletBinding()]
Param(
	[string]$Version = $null,
	[string]$NuGetApiKey,
	[switch]$Confirm = $false,
	[switch]$WhatIf = $false
)

$manifest = Import-PowerShellDataFile "$PSScriptRoot/src/DirColors.psd1"

If ([String]::IsNullOrEmpty($Version)) {
	$Version = $manifest.ModuleVersion
} Else {
	If ($Version[0] -Eq 'v') {
		$Version = $Version.Substring(1)
	}
}

$outputDirectory = "$PSScriptRoot/out/$Version"
$null = Remove-Item -Force -Recurse $outputDirectory -ErrorAction Ignore
$null = New-Item -Type Directory $outputDirectory
$null = Copy-Item -Recurse "$PSScriptRoot/src" "$outputDirectory/DirColors"

If ($manifest.ModuleVersion -ne $Version) {
	Write-Warning "Version $Version specified on commandline, but manifest contains $($manifest.ModuleVersion)."
	Write-Warning "Preferring $Version from commandline."
	Update-ModuleManifest -Path "$outputDirectory/DirColors/DirColors.psd1" -ModuleVersion "$Version"
}

$publishParameters = @{
	Path = "$outputDirectory/DirColors"
	NuGetApiKey = $NugetAPIKey
	Repository = "PSGallery"
	ReleaseNotes = (Get-Content -Raw CHANGELOG.md)
}

Publish-Module -Confirm:$Confirm -WhatIf:$WhatIf @publishParameters -ErrorAction:Stop
