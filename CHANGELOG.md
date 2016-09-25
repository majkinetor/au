# AU Project Changelog

## TODO

## 2016.9.25

**NOTE**: This update breaks compatibility with existing `update_all.ps1` scripts - parameter `Options`
is now of the type ordered HashTable ( `[ordered]@{...}` ).  This is the only required change for the script
to continue working and behave the same as before, however, other things are required in order to fully use AU features:

- Remove the user scripts `Save-XXX.ps1` as improved versions now come with AU (plugins).
- Take a look at the [update_all.ps1](https://github.com/majkinetor/au-packages-template/blob/master/update_all.ps1) 
  to see how plugins are used and setup. Migrate current custom options to the new style. 
  See [plugins section](https://github.com/majkinetor/au#plugins) for details. 

Take a look at the [working example](https://github.com/majkinetor/au-packages/blob/master/update_all.ps1) and [plugin wiki page](https://github.com/majkinetor/au/wiki/Plugins).

### Changes

- `Update-Package`
    - Support for Semantic Versioning [#21](https://github.com/majkinetor/au/issues/21).
- `Test-Package` 
  - Optional parameter Nu to test package from the .nupkg, .nuspec or directory.
  - Test chocolatey uninstaller. 
  - Refactoring.
- Installer improvements.
- `Update-AUPackages`
  - Plugin system with the following default plugins included:
    - `RunInfo` - Save run info to the CliXml file and exclude sensitive information.
    - `Report`  - Saves run info as a report file via included templates (currently markdown and text).
    - `Gist`    - Save files as anonymous or user gists.
    - `Git`     - Commits package changes to the git repository.
    - `Mail`    - Send mail with attachments.
  - New parameter `NoPlugins` (by default `$Env:au_NoPlugins` to disable all plugins.
  - New option parameter `PluginPath` to specify additional path where plugins are located.
  - Output now shows if Push and Force options are used.
- Created [au-packages-template](https://github.com/majkinetor/au-packages-template) to quick start AU.
- Documentation is rewritten and [wiki](https://github.com/majkinetor/au/wiki) created.

### Bugfixes

- Fixed bug due to the typo when pushing and sorting packages when executing `Update-AUPackages`.

### CD

- New `./test.ps1` script that run some or all of the tests.


## 2016.9.21

### Bugfixes

- Push was not working when package was updated.

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





