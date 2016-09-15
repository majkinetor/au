
# AU Project Changelog

## TODO

- Support for Semantic Versioning [#21](https://github.com/majkinetor/au/issues/21).

## NEXT

- `Test-Package` 
  - Optional parameter Nu to test package from the .nupkg, .nuspec or directory.
  - Test choco uninstaller. 
  - Refactoring.


## 2016.9.14.233253

- `Update-Package`
  - New alias `lsau`.
  - Return an object of type `AUPackage` instead of text.
  - New parameters
    - `NoHostOutput` to not show any `Write-Host` output.
    - `Result` to hold the name of the global output variable.
    - Verbose parameter.
  - `NuspecVersion` added to the `$Latest` HashTable.
  - Pester tests.
  - run standalone, `update` in the package directory calls `./update.ps1`.
- `README.md` made available via `man about_au`. 
- Consider global variable `$au_root` when looking for AU packages.
- Optimization and refactoring.
- Bugfixes
  - `Update-Packages` exception when `au_GetLatests` returned nothing.
  - `$Latest.Version` remains set to remote version when forcing update [#24](https://github.com/majkinetor/au/issues/24).
  - Chocolatey installation fixed [#15](https://github.com/majkinetor/au/issues/15)

### CD

- Build module script.
- Build chocolatey package script.
- Publish to Github, Chocolatey and PSGallery.
- `install.ps1` script to install/remove Powershell module in the current system.
- AppVeyor automatic build.


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





