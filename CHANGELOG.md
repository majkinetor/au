
# AU Project Changelog

## TODO

- `Support for Semantic Versioning`.

### Bugfixes

- `$Latest.Version` is still set to remote version when forcing update.

## NEXT

- `Get-AuPackages` considers global variable `$au_root` when looking for AU packages.
- `Get-AuPackages` has new alias `lsau`.
- All packages now support `Verbose` parameter.
- `NuspecVersion` added to the `$Latest` Hashtable by the framework.
- Make `README.md` available via `man about_au`. 

### CD

- Build module script.
- Build chocolatey package script.
- Publish to Github, Chocolatey and PSGallery.
- `install.ps1` script to install/remove Powershell module in the current system.


## 2016.8.15

- Use Chocoloatey fix notation with `Force` parameter.
- Checksum verification using `ChecksumType32` and `ChecksumType64` when `Checksum32` or `Checksum64` are present in the `$Latest` HashTable.
- `PackageName` added to the $Latest HashTable by the framework.
- Use chocolatey cached nuget API key when all other methods fail.

### Bugfixes

- Multiple updates happening at the same time lead to issues with the fix-choco method.
- Copy fails if 'extensions' directory doesn't exist.


## 2016.8.13

### Bugfixes

- Fixed `cpack` name collision with that of CMake.

## 2016.8.12

- Support for Chocoloatey version 0.10.0.


## 2016.8.7

- Automatic checksum.
- Raise errors on search pattern not found.
- Bugfixes and small improvements.



