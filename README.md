# DirColors

DirColors leverages Powershell's custom formatter support to provide an
implementation of GNU coreutils' `ls --color=always` anywhere
FileInfo/DirectoryInfo objects are left to self-format.

DirColors adds support for:

* Parsing dircolors-formatted files
* Colorizing filenames in default, table, wide and list-formatted renditions of file information.
* Displaying the targets of symbolic links and directory junction points

## Usage

Assuming you've installed the module somewhere in your module path, just import the module in your profile and load a dircolors file.

```powershell
Import-Module DirColors
Import-DirColors ~\dir_colors
```

## Screenshots

![DirColors table listing](assets/DirColors-Table.png)

![DirColors wide listing](assets/DirColors-Wide.png)

![DirColors list listing](assets/DirColors-List.png)
