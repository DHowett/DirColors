### Version 1.1.2

* Fix a bug where we treated `*x.x` as an extension (not a wildcard)
* Fix `LINK target`

### Version 1.1.1

* Fixed an oversight that resulted in the miscoloration of relative symlinks.

### Version 1.1.0

* Added support for RESET
* Added support for passing through MULTIHARDLINK and CAPABILITY.
  * These directives are currently unsupported, as they don't have
    a Windows or PowerShell Core analog.

### Version 1.0.1

* Added documentation! Run "Get-Help about_DirColors" to learn more.
* On Windows, we now trust $Env:PATHEXT to determine what files are "executable".
* Symbolic link targets are now resolved properly.

### Version 1.0.0

Initial release.
