$ExecutableSuffixes = (".cmd", ".ps1", ".exe", ".dll", ".scr", ".ocx")

Function New-ColorScheme {
    Return [PSCustomObject]@{
        PSTypeName = "ColorScheme";
        Default = "0";
        File = "0";
        Directory = "01;34";
        Link = "01;36";
        Device = "01;33";
        Orphan = "0";
        Missing = "0";
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
        [string[]]$Path,

        [Parameter()]
        [Microsoft.PowerShell.Commands.FileSystemCmdletProviderEncoding]$Encoding = [Microsoft.PowerShell.Commands.FileSystemCmdletProviderEncoding]::UTF8
    )
    $out = New-ColorScheme

    Get-Content -Path:$Path -Encoding:$Encoding | % {
        If ($_ -Match '^\s*$' -Or $_ -Match '^\s*#.*$') {
            Return
        }
        $e = $_.Trim() -Split "\s+"
        $param = $e[0]
        $arg = $e[1]
        $canon = $null
        Switch ($param) {
            "COLOR" { Return }
            "TERM" { Return }
            "EIGHTBIT" { Return }

            "NORMAL" { $canon = "Default" }
            "FILE" { $canon = "File" }
            "DIR" { $canon = "Directory" }
            "LINK" { $canon = "Link" }
            "FIFO" { Return }
            "SOCK" { Return }
            "DOOR" { Return }
            "BLK" { $canon = "Device" } # Not the best mapping
            "CHR" { Return }
            "ORPHAN" { $canon = "Orphan" }
            "MISSING" { $canon = "Missing" }
            "SETUID" { Return }
            "SETGID" { Return }
            "STICKY_OTHER_WRITABLE" { Return }
            "OTHER_WRITABLE" { Return }
            "STICKY" { Return }
            "EXEC" { $canon = "Executable" }
            default {
                If ($param -Match '^\*?\.[^.]+$') {
                    $i = $param.IndexOf('.')
                    $ext = $param.Substring($i)
                    $out.Extensions[$ext] = $arg
                } Else {
                    If ($param -NotMatch '\*') {
                        $param = '*' + $param
                    }
                    $out.Matches[$param] = $arg
                }
            }
        }

        If ($null -Ne $canon) {
            $out.$canon = $arg
        }
    }

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
        Return $script:DirColors.Device
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
