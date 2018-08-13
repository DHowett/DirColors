If ($PSEdition -Eq "Desktop" -Or $IsWindows -Eq $True) {
    $ExecutableSuffixes = $Env:PATHEXT -Split ";"
}

$script:IgnoredDirColorsTokens = ("COLOR", "TERM", "EIGHTBIT")

$script:ESC = [char]27
$script:ws = [char[]]" `t`r"

$script:LSColorsTokensToSchemeProperties = @{
    "no" = "Default";
    "rs" = "Reset";
    "fi" = "File";
    "di" = "Directory";
    "ln" = "Link";
    "mh" = "MultiHardLink";
    "pi" = "Pipe";
    "so" = "Socket";
    "do" = "Door";
    "bd" = "BlockDevice";
    "cd" = "CharacterDevice";
    "or" = "Orphan";
    "mi" = "Missing";
    "su" = "SetUid";
    "sg" = "SetGid";
    "ca" = "Capability";
    "tw" = "StickyOtherWritable";
    "ow" = "OtherWritable";
    "st" = "Sticky";
    "ex" = "Executable";
}

$script:SchemePropertiesToLSColors =  @{
    "Default"             = "no";
    "Reset"               = "rs";
    "File"                = "fi";
    "Directory"           = "di";
    "Link"                = "ln";
    "MultiHardLink"       = "mh";
    "Pipe"                = "pi";
    "Socket"              = "so";
    "Door"                = "do";
    "BlockDevice"         = "bd";
    "CharacterDevice"     = "cd";
    "Orphan"              = "or";
    "Missing"             = "mi";
    "SetUid"              = "su";
    "SetGid"              = "sg";
    "Capability"          = "ca";
    "StickyOtherWritable" = "tw";
    "OtherWritable"       = "ow";
    "Sticky"              = "st";
    "Executable"          = "ex";
}

$script:DirColorsTokensToSchemeProperties = @{
    "NORMAL"                = "Default";
    "RESET"                 = "Reset";
    "FILE"                  = "File";
    "DIR"                   = "Directory";
    "LINK"                  = "Link";
    "MULTIHARDLINK"         = "MultiHardLink";
    "FIFO"                  = "Pipe";
    "SOCK"                  = "Socket";
    "DOOR"                  = "Door";
    "BLK"                   = "BlockDevice";
    "CHR"                   = "CharacterDevice";
    "ORPHAN"                = "Orphan";
    "MISSING"               = "Missing";
    "SETUID"                = "SetUid";
    "SETGID"                = "SetGid";
    "CAPABILITY"            = "Capability";
    "STICKY_OTHER_WRITABLE" = "StickyOtherWritable";
    "OTHER_WRITABLE"        = "OtherWritable";
    "STICKY"                = "Sticky";
    "EXEC"                  = "Executable";
}

Function New-ColorScheme {
    Return [PSCustomObject]@{
        PSTypeName = "ColorScheme";

        Default = "0";
        Reset = "0";
        File = "0";
        Directory = "01;34";
        Link = "01;36";
        MultiHardLink = "0";
        Pipe = "00;33";
        Socket = "01;35";
        Door = "01;35";
        BlockDevice = "01;33";
        CharacterDevice = "01;33";
        Orphan = "01;36";
        Missing = "0";
        SetUid = "37;41";
        SetGid = "30;43";
        Capability = "30;41";
        StickyOtherWritable = "30;42";
        OtherWritable = "34;42";
        Sticky = "37;44";
        Executable = "01;32";

        Extensions = @{};
        Matches = @{};
    }
}

$DefaultColors = New-ColorScheme
$DirColors = $DefaultColors

Function Import-DirColors() {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string[]]$Path
    )

    $out = New-ColorScheme

    ForEach ($_ In (Get-Content -Path:$Path -ReadCount 0) -Split "`n") {
        If ([string]::IsNullOrWhitespace($_)) {
            Continue
        }
        $param, $arg = $_.Split($script:ws, 3, [System.StringSplitOptions]::RemoveEmptyEntries)[0, 1]

        If ($param -In $script:IgnoredDirColorsTokens) {
            Continue
        }

        $canon = $script:DirColorsTokensToSchemeProperties[$param.ToUpper()]
        If ($null -Eq $canon) {
            $i = $param.IndexOf('.')
            If ($i -Le 1 -And $i -Eq $param.LastIndexOf('.')) {
                # *.x with no other periods: fast path
                If ($param[0] -Eq '*') {
                    $param = $param.Substring(1)
                }
                $out.Extensions[$param] = $arg
            } Else {
                If (!$param.Contains('*')) {
                    # dircolors enforces a leading * when generating LS_COLORS
                    $param = '*' + $param
                }
                $out.Matches[$param] = $arg
            }
        } Else {
            $out.$canon = $arg
        }
    }

    Return $out
}

Function ConvertFrom-LSColors {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$LSColors
    )

    $out = New-ColorScheme

    ForEach ($_ In $LSColors -Split ":") {
        $param, $arg = $_ -Split "="
        $canon = $script:LSColorsTokensToSchemeProperties[$param.ToLower()]
        If ($null -Eq $canon) {
            $i = $param.IndexOf('.')
            If ($i -Gt -1 -And $i -Eq $param.LastIndexOf('.')) {
                # *.x with no other periods: fast path
                If ($param[0] -Eq '*') {
                    $param = $param.Substring(1)
                }
                $out.Extensions[$param] = $arg
            } Else {
                # dircolors enforces a leading * when generating LS_COLORS
                $out.Matches[$param] = $arg
            }
        } Else {
            $out.$canon = $arg
        }
    } # $_

    Return $out
}

Function ConvertTo-LSColors {
    [CmdletBinding()]
    Param (
        [PSTypeName("ColorScheme")]
        [Parameter(ValueFromPipeline=$true)]
        $ColorScheme
    )

    $tokens = ForEach($_ In $script:SchemePropertiesToLSColors.GetEnumerator()) {
        "{0}={1}" -F $_.Value, $ColorScheme.($_.Name)
    }

    $tokens += ForEach($_ in $ColorScheme.Extensions.GetEnumerator()) {
        "*{0}={1}" -F $_.Name, $_.Value
    }

    $tokens += ForEach($_ in $ColorScheme.Matches.GetEnumerator()) {
        "{0}={1}" -F $_.Name, $_.Value
    }

    Return $tokens -Join ":"
}

Function Update-DirColors {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string[]]$Path
    )

    $script:DirColors = Import-DirColors -Path:$Path
    $Env:LS_COLORS = ConvertTo-LSColors $script:DirColors
}

Function Get-ContainingDirectoryInfo($fi) {
    If ($fi -Is [System.IO.DirectoryInfo]) {
        Return $fi.Parent
    }

    Return $fi.Directory
}

Function Get-ColorCode($fi) {
    If ($fi.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)) {
        If ($fi.LinkType -Eq "SymbolicLink" -Or $fi.LinkType -Eq "Junction") {
            $tfn = [System.IO.Path]::Combine((Get-ContainingDirectoryInfo($fi)).FullName, $fi.Target)
            $tfi = (Get-Item $tfn -EA Ignore)
            If ($null -Eq $tfi) {
                Return $script:DirColors.Orphan
            } ElseIf ($script:DirColors.Link -Eq "target") {
                Return Get-ColorCode($tfi)
            }

            Return $script:DirColors.Link
        }
        Return $script:DirColors.BlockDevice
    }

    If ($fi -Is [System.IO.DirectoryInfo]) {
        Return $script:DirColors.Directory
    } Else {
        $ext = $fi.Extension

        # This is likely to be wrong: Extensions are quicker since we've mapped
        # them all to colors, but ls probably matches wildcards more strongly
        # than extensions (since they're more expressive, and therefore more
        # specific)
        If (-Not [String]::IsNullOrEmpty($ext)) {
            # Fast path: extension matching (pre-hashed)
            If ($ext -In $script:ExecutableSuffixes) {
                return $script:DirColors.Executable
            }

            $cc = $script:DirColors.Extensions[$ext]
            If ($cc) {
                Return $cc
            }
        }

        ForEach($k in $script:DirColors.Matches.Keys) {
            # Slow path: wildcard matching
            If ($fi.Name -Like $k) {
                Return $script:DirColors.Matches.Item($k)
            }
        }

    }

    Return $script:DirColors.Default
}

Function Format-ColorizedFilename() {
    Param (
        [Parameter(ValueFromPipeline=$true)]
        [System.IO.FileSystemInfo]$FileInfo
    )
    $cc = Get-ColorCode($FileInfo)
    Return "$ESC[${cc}m$($FileInfo.Name)$ESC[$($script:DirColors.Reset)m"
}

Function Format-ColorizedLinkTarget() {
    Param (
        [Parameter(ValueFromPipeline=$true)]
        [System.IO.FileSystemInfo]$FileInfo
    )
    # Looking up LinkType requires opening the file; this is expensive.
    If ($FileInfo.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)) {
        If ($FileInfo.LinkType -Eq "SymbolicLink" -Or $FileInfo.LinkType -Eq "Junction") {
            $tfn = [System.IO.Path]::Combine((Get-ContainingDirectoryInfo($FileInfo)).FullName, $FileInfo.Target)
            $tfi = (Get-Item $tfn -EA Ignore)
            If ($null -Eq $tfi) {
                Return "$ESC[$($script:DirColors.Missing)m$($FileInfo.Target)$ESC[$($script:DirColors.Reset)m"
            } Else {
                $tcc = Get-ColorCode($tfi)
                Return "$ESC[${tcc}m$($FileInfo.Target)$ESC[$($script:DirColors.Reset)m"
            }
        }
    }
    Return $null
}

function Format-ColorizedFilenameAndLinkTarget() {
    Param (
        [Parameter(ValueFromPipeline=$true)]
        [System.IO.FileSystemInfo]$FileInfo
    )

    $lt = Format-ColorizedLinkTarget $FileInfo
    If ($null -Ne $lt) {
        Return (Format-ColorizedFilename $FileInfo) + " -> " + $lt
    }

    Return (Format-ColorizedFilename $FileInfo)
}

Update-FormatData -Prepend (Join-Path $PSScriptRoot "DirColors.format.ps1xml")

If (-Not [String]::IsNullOrEmpty($Env:LS_COLORS)) {
    $script:DirColors = ConvertFrom-LSColors $Env:LS_COLORS
}

# vim: ts=4 sw=4 et
