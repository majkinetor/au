# AU Project Changelog

## Next

- `au_BeforeUpdate` and `au_AfterUpdate` now provide parameter `Package` of type `[AUPackage]` which you can use to modify Nuspec data.
- Added new function `Set-DescriptionFromReadme` that is called automatically when README.md is present in the package folder ([#85](https://github.com/majkinetor/au/issues/85)). See [documentation](README.md#automatic-package-description-from-readmemd).
- Plugins:
  - New plugin: [GitReleases](https://github.com/majkinetor/au/blob/master/AU/Plugins/GitReleases.ps1)
  - Git: new parameter `Strategy` with options on how to commit repository changes

## 2017.8.30

- `Update-AUPackages` 
  - New options to handle update.ps1 errors: `IgnoreOn`, `RepeatOn`,`RepeatCount`,`RepeatSleep`. See [documentation](https://github.com/majkinetor/au#handling-update-errors). ([#76](https://github.com/majkinetor/au/issues/76)).
  - New option `WhatIf` option that will trigger WhatIf on all packages.
  - New AUPackage properties: `Ignored` (boolean) and `IgnoreMessage`.
  - Report plugin: `IgnoreMessage` is added in the ignore section.
- `Update-AuPackage`
  - Added parameter `WhatIf` that will save and restore the package. See [documentation](https://github.com/majkinetor/au#whatif). ([#30](https://github.com/majkinetor/au/issues/30))
  - `au_GetLatest` can now return `ignore` to make package ignored in the `updateall` context.

### Bugfixes

- Git plugin: package that changed `$Latest.PackageName` was not pushed when updated ([#66](https://github.com/majkinetor/au/issues/66)).

## 2017.3.29

- `Get-RemoteFiles`
  - `NoSuffix` switch to not add `_x32` and/or `_x64` suffix at the end of the file names.
  -  Now also sets `ChecksumTypeXX` and `FileNameXX` and accepts `Algorithm` parameter. 
  
### Bugfixes

- Fix ps1 files encoded in UTF8 without BOM being treated as ANSI. 
- Fix chocolatey.org package check using wrong package name when overridden in update.ps1.

## 2017.1.14

**NOTE**: License changed from MIT to GPL2.

- New function `Get-RemoteFiles`. See [documentation](https://github.com/majkinetor/au#embedding-binaries).
- `Update-Package`
  - Support newer TLS version support by setting the `SecurityProtocol` property of `ServicePointManager`.
- Posh 5 dependency removed for chocolatey package because it is not practical.

### Bugfixes

- Fix encoding of nuspec (UTF-8 NO BOM) and ps1 (UTF-8 BOM) files.

## 2016.12.17

**NOTE**: Minimal PowerShell version required to run AU is now 5.0 instead of 4.0. This wont affect AppVeyor builds, but might affect local runs. Please update your local PowerShell version (`cinst powershell`) if you run it locally.

- New function `Get-RemoteChecksum` that can be used instead of automatic checksum.
- `Get-AuPackages` now accepts array of globs, for example `lsau 'cpu-z*','p*','copyq'`.
- `Update-AUPackages`
  - New plugin `History` that creates markdown report of package updates grouped by dates.
  - Report plugin
    - Added link to `packageSourceUrl` and `projectUrl`.
    - New parameter `Title` to change report title.
    - New parameters for markdown report - `IconSize` and `NoIcons`. Icons are now shown by default.
  - Plugins documentation updated.
  - `Test-Package`: new parameter `VagrantNoClear` that will not delete existing packages from the vagrant package directory.
  - `update.ps1` script can now return keyword [ignore](https://github.com/majkinetor/au#ignoring-specific-errors) to cause `udpateall` to not report it as an error in output.
- `Update-Package`
    - `au_GetLatest` can now force update by setting `$global:au_Force = $true`.
- Refactoring code to use PowerShell 5 classes, functions now return `[AUPackage]` object.

### Bugfixes

- `Git` plugin bugfixes.
- Small fixes and tweaks all around.
- Packages shouldn't drop from the results now no matter what happens with the `updateall` thread.
- `$Latest.FileType` is not overwritten when its set in the `au_GetLatest`.

### CD

Changes in [au-packages-template](https://github.com/majkinetor/au-packages-template):
- Added new script `test_all.ps1` to force test all desired packages and randomly test package groups. See wiki page [setting up the force test](https://github.com/majkinetor/au/wiki/AppVeyor#setting-up-the-force-test-project-optional) for how to set this up on AppVeyor.

## 2016.11.5

- `Update-Package`
  - It now automatically adds `$Latest.Filetype` based on the extension of the first URL it finds. 

### CD

- Added script `scripts\Install-AU.ps1` to install any AU version or branch using git tags.

Changes in [au-packages-template](https://github.com/majkinetor/au-packages-template):
- Added new AppVeyor commit command `[PUSH pkg1 ... pkgN]` to push any package to the community repository.

### Bugfixes

- Fixed missing temporary directory for package download [ref](https://github.com/chocolatey/chocolatey-coreteampackages/pull/350).

## 2016.10.30

- `Update-Package`
  - Show 'URL check' in output.
  - `$global:au_Version` can now be used when update is forced to explicitly provide version.
  - Invalid version in the nuspec file doesn't throw error any more but uses version 0.0 with warning.
- `Update-AUPackages`
  - Added `BeforeEach` and `AfterEach` scripts to Options.
  - New Option `UpdateTimeout` to limit update total execution time ([#38](https://github.com/majkinetor/au/issues/38)).
  - `Git` plugin: only push files that are changed, not entire package content.
- `Test-Package`
  - New string parameter `Vagrant` and global variable `$au_Vagrant` that contain path to the [chocolatey test environment](https://github.com/majkinetor/chocolatey-test-environment) so you can test the package using the Vagrant system.
- PowerShell documentation improved.

### Bugfixes

- Fixed frequent URL check timeout [#35](https://github.com/majkinetor/au/issues/35).
- AU updated nuspec file to UTF-8 with BOM [#39](https://github.com/majkinetor/au/issues/39).
- Checksum verification mode didn't work with updateall [#36](https://github.com/majkinetor/au/issues/36).
- Small fixes.

### CD

Changes in [au-packages-template](https://github.com/majkinetor/au-packages-template):
- `update_all.ps1` now accepts `ForcedPackages` and `Root` parameters.
- AppVeyor commit message parsing for AU options.


## 2016.10.9

- `Update-Package` uses last returned value of `au_GetLatest` instead of everything ([#28](https://github.com/majkinetor/au/issues/28)).
- `Test-Package` new option `Parameters` to support testing packages with custom parameters.

### Bugfixes

- `Test-Package` - Uninstall test fixed.
- `Git` plugin error - _A positional parameter cannot be found_ error fixed ([#31](https://github.com/majkinetor/au/issues/31)).
- Small fixes.

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
- AU version environment variable added to `appveyor.yml`.


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

## 2016.6.6

- First PowerShell Gallery version.

## 2016.2.19

- First PoC version.
