$ExecutableSuffixes = (".cmd", ".ps1", ".exe", ".dll", ".scr", ".ocx")

Function New-ColorScheme {
    Return [PSCustomObject]@{
        PSTypeName = "ColorScheme";
        Default = "0";
        File = "0";
        Directory = "01;34";
        Link = "01;36";
        Pipe = "00;33";
        Socket = "01;35";
        Door = "01;35";
        BlockDevice = "01;33";
        CharacterDevice = "01;33";
        Orphan = "01;36";
        Missing = "0";
        SetUid = "37;41";
        SetGid = "30;43";
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

Function script:Canonize-LSColorToken($token) {
    Switch ($token) {
        "no" { "Default" }
        "fi" { "File" }
        "di" { "Directory" }
        "ln" { "Link" }
        "pi" { "Pipe" }
        "so" { "Socket" }
        "do" { "Door" }
        "bd" { "BlockDevice" }
        "cd" { "CharacterDevice" }
        "or" { "Orphan" }
        "mi" { "Missing" }
        "su" { "SetUid" }
        "sg" { "SetGid" }
        "tw" { "StickyOtherWritable" }
        "ow" { "OtherWritable" }
        "st" { "Sticky" }
        "ex" { "Executable" }
        default { $null }
    }
}

Function script:Canonize-DirColorsTOken($token) {
    Switch ($token) {
        "NORMAL" { "Default" }
        "FILE" { "File" }
        "DIR" { "Directory" }
        "LINK" { "Link" }
        "FIFO" { "Pipe" }
        "SOCK" { "Socket" }
        "DOOR" { "Door" }
        "BLK" { "BlockDevice" }
        "CHR" { "CharacterDevice" }
        "ORPHAN" { "Orphan" }
        "MISSING" { "Missing" }
        "SETUID" { "SetUid" }
        "SETGID" { "SetGid" }
        "STICKY_OTHER_WRITABLE" { "StickyOtherWritable" }
        "OTHER_WRITABLE" { "OtherWritable" }
        "STICKY" { "Sticky" }
        "EXEC" { "Executable" }
        default { $null }
    }
}

Function script:Convert-PropertyToLSColorsToken($scheme, $property) {
    $c = Switch ($property) {
        "Default" { "no" }
        "File" { "fi" }
        "Directory" { "di" }
        "Link" { "ln" }
        "Pipe" { "pi" }
        "Socket" { "so" }
        "Door" { "do" }
        "BlockDevice" { "bd" }
        "CharacterDevice" { "cd" }
        "Orphan" { "or" }
        "Missing" { "mi" }
        "SetUid" { "su" }
        "SetGid" { "sg" }
        "StickyOtherWritable" { "tw" }
        "OtherWritable" { "ow" }
        "Sticky" { "st" }
        "Executable" { "ex" }
        default { Return $null }
    }

    $c + "=" + $scheme.$property
}

Function Import-DirColors() {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string[]]$Path,

        [Parameter()]
        [Microsoft.PowerShell.Commands.FileSystemCmdletProviderEncoding]$Encoding = [Microsoft.PowerShell.Commands.FileSystemCmdletProviderEncoding]::UTF8
    )

    $out = New-ColorScheme

    Get-Content -Path:$Path -Encoding:$Encoding | % {
        If ($_ -Match '^\s*$' -Or $_ -Match '^\s*#.*$') {
            Return
        }
        $param, $arg, $rest = $_.Trim() -Split "\s+"

        If ($param -In ("COLOR", "TERM", "EIGHTBIT")) {
            Return
        }

        $canon = Canonize-DirColorsToken $param
        If ($null -Eq $canon) {
            If ($param -Match '^\*?\.[^.]+$') {
                # *.x with no other periods: fast path
                $i = $param.IndexOf('.')
                $ext = $param.Substring($i)
                $out.Extensions[$ext] = $arg
            } Else {
                If ($param -NotMatch '\*') {
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
        $canon = Canonize-LSColorToken $param
        If ($null -Eq $canon) {
            If ($param -Match '^\*\.[^.]+$') {
                # *.x with no other periods: fast path
                $ext = $param.Substring(1)
                $out.Extensions[$ext] = $arg
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
        [PSTypeName("ColorScheme")]$ColorScheme
    )

    return "<PLACEHOLDER>"
}

Function Update-DirColors {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string[]]$Path
    )

    $script:DirColors = Import-DirColors -Path:$Path
}

Function Get-ColorCode($fi) {
    If ($fi.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)) {
        If ($fi.LinkType -Eq "SymbolicLink" -Or $fi.LinkType -Eq "Junction") {
            $tfn = [System.IO.Path]::Combine($fi.Directory.FullName, $fi.Target)
            $tfi = (Get-Item $tfn -EA Ignore)
            If ($null -Eq $tfi) {
                Return $script:DirColors.Orphan
            } ElseIf ($cc -Eq "target") {
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
    Return "$([char]27)[$($cc)m$($FileInfo.Name)$([char]27)[0m"
}

Function Format-ColorizedLinkTarget() {
    Param (
        [Parameter(ValueFromPipeline=$true)]
        [System.IO.FileSystemInfo]$FileInfo
    )
    # Looking up LinkType requires opening the file; this is expensive.
    If ($FileInfo.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)) {
        If ($FileInfo.LinkType -Eq "SymbolicLink" -Or $FileInfo.LinkType -Eq "Junction") {
            $tfn = [System.IO.Path]::Combine($FileInfo.Directory.FullName, $FileInfo.Target)
            $tfi = (Get-Item $tfn -EA Ignore)
            If ($null -Eq $tfi) {
                Return "$([char]27)[$($script:DirColors.Missing)m$($FileInfo.Target)$([char]27)[0m"
            } Else {
                $tcc = Get-ColorCode($tfi)
                Return "$([char]27)[$($tcc)m$($FileInfo.Target)$([char]27)[0m"
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

# vim: ts=4 sw=4 et
