$DefaultColors = @{
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

$DirColors = $DefaultColors

Function Parse-DirColors($filename) {
    $out = $DefaultColors.Clone();

    Get-Content $filename -Encoding UTF8 | % {
        If ($_ -Match '^\s*$' -Or $_ -Match '^\s*#.*$') {
            Return
        }
        $e = $_.Trim() -Split "\s+"
        $param = $e[0]
        $arg = $e[1]
        $canon = $null
        Switch ($param) {
            "NORMAL" { $canon = "Default" }
            "FILE" { $canon = "File" }
            "DIR" { $canon = "Directory" }
            "LINK" { $canon = "Link" }
            "BLK" { $canon = "Device" } # Not the best mapping
            "ORPHAN" { $canon = "Orphan" }
            "EXEC" { $canon = "Executable" }
            "MISSING" { $canon = "Missing" }
            default {
                If ($param -Match '^\*?\.[^.]+$') {
                    $i = $param.IndexOf('.')
                    $ext = $param.Substring($i)
                    $out.Extensions[$ext] = $arg
                } Else {
                    $out.Matches[$param] = $arg
                }
            }
        }

        If ($null -Ne $canon) {
            $out[$canon] = $arg
        }
    }

    Return $out
}

Function Import-DirColors($Path) {
    $script:DirColors = Parse-DirColors($Path)
}

Function Get-ColorCode($fi) {
    If ($fi.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)) {
        $cc = $script:DirColors.Device
        If ($fi.LinkType -Eq "SymbolicLink" -Or $fi.LinkType -Eq "Junction") {
            $cc = $script:DirColors.Link
            $tfn = [System.IO.Path]::Combine($fi.Directory.FullName, $fi.Target)
            $tfi = (Get-Item $tfn -EA Ignore)
            If ($null -Eq $tfi) {
                $cc = $script:DirColors.Orphan
            } ElseIf ($cc -Eq "target") {
                $cc = Get-ColorCode($tfi)
            }
        }
        Return $cc
    }

    If ($fi -Is [System.IO.DirectoryInfo]) {
        Return $script:DirColors.Directory
    } Else {
        $ext = $fi.Extension

        If (-Not [String]::IsNullOrEmpty($ext)) {
            If ($ext -In (".cmd", ".ps1", ".exe", ".dll", ".scr", ".ocx")) {
                return $script:DirColors.Executable
            }

            $cc = $script:DirColors.Extensions[$ext]
            If ($cc) {
                Return $cc
            }
        }

        ForEach($k in $script:DirColors.Matches.Keys) {
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
