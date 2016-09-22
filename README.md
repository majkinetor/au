[![build](https://ci.appveyor.com/api/projects/status/github/majkinetor/au?svg=true)](https://ci.appveyor.com/project/majkinetor/au)   [![chat](https://img.shields.io/badge/gitter-join_chat-1dce73.svg?logo=data%3Aimage%2Fsvg%2Bxml%3Bbase64%2CPD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiPz4NCjxzdmcgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB4PSIwIiB5PSI1IiBmaWxsPSIjZmZmIiB3aWR0aD0iMSIgaGVpZ2h0PSI1Ii8%2BPHJlY3QgeD0iMiIgeT0iNiIgZmlsbD0iI2ZmZiIgd2lkdGg9IjEiIGhlaWdodD0iNyIvPjxyZWN0IHg9IjQiIHk9IjYiIGZpbGw9IiNmZmYiIHdpZHRoPSIxIiBoZWlnaHQ9IjciLz48cmVjdCB4PSI2IiB5PSI2IiBmaWxsPSIjZmZmIiB3aWR0aD0iMSIgaGVpZ2h0PSI0Ii8%2BPC9zdmc%2B&logoWidth=8)](https://gitter.im/chocolatey_au/Lobby)   [![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/majkinetor/au/master/license.txt)

---

# Chocolatey Automatic Package Updater Module

This PowerShell module implements functions that can be used to automate [Chocolatey](https://chocolatey.org) package updates.

To learn more about Chocolatey automatic packages, please refer to the relevant [documentation](https://github.com/chocolatey/choco/wiki/AutomaticPackages).

## Features

- Use only PowerShell to create automatic update script for given package.
- Automatically downloads installers and provides/validates checksums for x32 and x64 versions.
- Verifies URLs, nuspec versions, remote Chocolatey existence etc.
- Can use global variables to change functionality.
- Sugar functions for Chocolatey package maintainers.
- Update single package or any subset of previously created AU packages with a single command.
- Multithread support when updating multiple packages.
- Plugin system when updating everything, with the few integrated plugins to send email notifications, save results to gist and push updated packages to git repository.


## Installation

Use one of the following methods:
- PowerShell 5+: [`Install-Module au`](https://www.powershellgallery.com/packages/AU).  
- Chocolatey:  [`cinst au`](https://chocolatey.org/packages/au).  
- [Download](https://github.com/majkinetor/au/releases/latest) latest 7z package or latest build [artifact](https://ci.appveyor.com/project/majkinetor/au/build/artifacts).

AU module requires minimally PowerShell version 4: `$host.Version -ge '4.0'`

**NOTE**: All module functions work from within specific root folder. The folder contains all of your Chocolatey packages.

## Creating the package updater script

The AU uses `update.ps1` script that package maintainers should create in the package directory. No templates are used, just plain PowerShell.

To write the package update script, it is generally required to implement 2 functions: `au_GetLatest` and `au_SearchReplace`.

### `au_GetLatest`  

This function is used to get the latest package information.

Function returns [HashTable] with the latest remote version along with other arbitrary user data which you can use elsewhere. The returned version is then compared to the one in the nuspec file and if remote version is higher, the files will be updated. The returned keys of this HashTable are available via global variable `$Latest`.


### `au_SearchReplace`  

Function returns [HashTable] containing search and replace data for any package file in the form:  

~~~powershell
    @{
        file_path1 = @{
            search1 = replace1
            ...
            searchN = replaceN
        }
        file_path2 = @{ ... }
        ...
    }
~~~

The function can use `$Latest` variable to get any type of information obtained when `au_GetLatest` was executed along with some AU generated data such as `PackageName`, `NuspecVersion` etc.

**NOTE**: The search and replace works on lines, multiple lines can not be matched with single regular expression.

### Update 

With above functions implemented calling the `Update-Package` (alias `update`) function from the AU module will update the package when needed.

You can then update the individual package by running the appropriate `update.ps1` script from within the package directory:

```
PS C:\chocolatey\dngrep> .\update.ps1
dngrep - checking updates using au version 2016.9.14
nuspec version: 2.8.15.0
remote version: 2.8.16.0
New version found
Automatic checksum started
Downloading dngrep 32 bit
  from 'https://github.com/dnGrep/dnGrep/releases/download/v2.8.16.0/dnGREP.2.8.16.x86.msi'

Download of dnGREP.2.8.16.x86.msi (3.36 MB) completed.
Package downloaded and hash calculated for 32 bit version
Downloading dngrep 64 bit
  from 'https://github.com/dnGrep/dnGrep/releases/download/v2.8.16.0/dnGREP.2.8.16.x64.msi'

Download of dnGREP.2.8.16.x64.msi (3.39 MB) completed.
Package downloaded and hash calculated for 64 bit version
Updating files
  dngrep.nuspec
    updating version:  2.8.15.0 -> 2.8.16.0
  tools\chocolateyInstall.ps1
    (^[$]url32\s*=\s*)('.*') = $1'https://github.com/dnGrep/dnGrep/releases/download/v2.8.16.0/dnGREP.2.8.16.x86.msi'
    (^[$]url64\s*=\s*)('.*') = $1'https://github.com/dnGrep/dnGrep/releases/download/v2.8.16.0/dnGREP.2.8.16.x64.msi'
    (^[$]checksum32\s*=\s*)('.*') = $1'CE4753735148E1F48FE0E1CD9AA4DFD019082F4F43C38C4FF4157F08D346700C'
    (^[$]checksumType32\s*=\s*)('.*') = $1'sha256'
    (^[$]checksum64\s*=\s*)('.*') = $1'025BD4101826932E954AACD3FE6AEE9927A7198FEEFFB24F82FBE5D578502D18'
    (^[$]checksumType64\s*=\s*)('.*') = $1'sha256'
Attempting to build package from 'dngrep.nuspec'.
Successfully created package 'dngrep.2.8.16.0.nupkg'
Package updated
```

This is best understood via the example - take a look at the real life package [installer script](https://github.com/majkinetor/chocolatey/blob/master/dngrep/tools/chocolateyInstall.ps1) and its [AU updater](https://github.com/majkinetor/chocolatey/blob/master/dngrep/update.ps1).

### Checks

The `update` function does the following checks:

- The `$Latest.Version` will be checked to match a valid nuspec pattern.
- Any hash key that starts with the word `Url`, will be checked for existence and MIME textual type, since binary is expected here.
- If the remote version is higher then the nuspec version, the Chocolatey site will be checked for existence of this package version (this works for unpublished packages too). This allows multiple users to update packages without a conflict. Besides this, this feature makes it possible not to persist state between the updates as once the package is updated and pushed, the next update will not push the package again. To persist the state of updated packages you can use for instance `Git` plugin which saves the updated packages to the git repository. 
- The regex patterns in `au_SearchReplace` will be checked for existence.

If any of the checks fails, package will not get updated. This feature releases you from the worries about how precise is your pattern match in the `au_GetLatest` function and how often original site changes as if something like that happens package wont get updated or pushed with incorrect data.

For some packages, you may want to disable some of the checks by specifying additional parameters of the `update` function (not all can be disabled):

| Parameter             | Description                       |
| ---------             | ------------                      |
| `NoCheckUrl`          | Disable URL checks                |
| `NoCheckChocoVersion` | Disable the Chocolatey site check |
| `ChecksumFor none`    | Disable automatic checksum        |

### Automatic checksums

When new version is available, the `update` function will by default download both x32 and x64 versions of the installer and calculate the desired checksum. It will inject this info in the `$global:Latest` HashTable variable so you can use it via `au_SearchReplace` function to update hashes. The parameter `ChecksumFor` can contain words `all`, `none`, `32` or `64` to further control the behavior.

You can disable this feature by calling update like this:

    update -ChecksumFor none

You can define the hash algorithm by returning corresponding `ChecksumTypeXX` hash keys in the `au_GetLatest` function:

    return @{ ... ChecksumType32 = 'sha512'; ... }

If the checksum is actually obtained from the vendor's site, you can provide it along with its type (SHA256 by default) by returning corresponding `ChecksumXX` hash keys in the `au_GetLatest` function:

    return @{ ... Checksum32 = 'xxxxxxxx'; ChecksumType32 = 'md5'; ... }

If the `ChecksumXX` hash key is present, the AU will change to checksum verification mode - it will download the installer and verify that its checksum matches the one provided. If the key is not present, the AU will calculate hash with the given `ChecksumTypeXX` algorithm.

**NOTE**: This feature works by monkey patching the `Get-ChocolateyWebFile` helper function and invoking the `chocolateyInstall.ps1` afterwards for the package in question. This means that it downloads the files using whatever method is specified in the package installation script.

### Force update

You can force the update even if no new version is found by using the parameter `Force` (or global variable `$au_Force`). This can be useful for troubleshooting, bug fixing, recalculating the checksum after the package was created and already pushed to Chocolatey or if URLs to installer changed without adequate version change.

The version of the package will be changed so that it follows _chocolatey fix standard_ where current date is added in the _revision_ component of the package version in the format `yyyyMMdd`. More precisely, 

- choco "fix version" always goes in to the _Revision_ part of the package version.
- existing "fixed versions" are changed to contain the current date if the revision does not exist or if it already contains choco fix.
- if _Revision_ part is present in the package version and it is not in the "choco fix format", AU will keep the existing version but notify about it.

**Example**:

```
PS C:\chocolatey\cpu-z.install> $au_Force = $true; .\update.ps1
cpu-z.install - checking updates
nuspec version: 1.77
remote version: 1.77
No new version found, but update is forced
Automatic checksum started
...
Updating files
  cpu-z.install.nuspec
    updating version using Chocolatey fix notation: 1.77 -> 1.77.0.20160814
...
```

### Global variables

To avoid changing the `./update.ps1` when troubleshooting or experimenting you can set up any `update` parameter via global variables. The names of global variables are the same as the names of parameters with the prefix `au_`. As an example, the following code will change the update behavior so that URL is not checked for existence and MIME type and update is forced: 

    $au_NoCheckUrl = $au_Force = $true
    ./update.ps1

This is the same as if you added the parameters to `update` function inside the `./update.ps1` script:

    update -NoCheckUrl -Force

however, its way easier to setup global variable with manual intervention on multiple packages.

**NOTE**: Only if parameters are not set on function call, the global variables will take over if they are set.


### Reusing the AU updater with metapackages

Metapackages can reuse an AU updater of its dependency by the following way:

- In the dependent updater, instead of calling the `update` directly, use construct:

  ```
    if ($MyInvocation.InvocationName -ne '.') { update ... }
  ```

- In the metapackage updater dot source the dependent updater and override `au_SearchReplace`.

This is best understood via example - take a look at the [cpu-z](https://github.com/majkinetor/chocolatey/blob/master/cpu-z/update.ps1) AU updater which uses the updater from the [cpu-z.install](https://github.com/majkinetor/chocolatey/blob/master/cpu-z.install/update.ps1) package on which it depends. It overrides the `au_SearchReplace` function and the `update` call but keeps the `au_GetLatest`.

## Updating all packages

You can update all packages and optionally push them to the Chocolatey repository with a single command. Function `Update-AUPackages` (alias `updateall`) will iterate over `update.ps1` scripts and execute each in a separate thread. If it detects that a package is updated it will optionally try to push it to the Chocolatey repository and may also run configured plugins.

For the push to work, specify your Choocolatey API key in the file `api_key` in the script's directory (or its parent directory) or set the environment variable `$Env:api_key`. If none provided cached nuget key will be used.

The function will search for packages in the current directory. To override that, use global variable `$au_Root`:

    PS> $au_root = 'c:\chocolatey_packages`
    PS> $Options = @{
        Timeout = 10
        Threads = 15
        Push    = $false
    }
    PS> updateall -Options $Options

    Updating 6 automatic packages at 2016-09-16 22:03:33
       copyq is updated to 2.6.1 and pushed 
       dngrep had errors during update
           Can't validate URL 'https://github.com/dnGrep/dnGrep/releases/download/v2.8.16.0/dnGREP.2.8.16.x64.msi'
           Exception calling "GetResponse" with "0" argument(s): "The operation has timed out"
       eac has no updates
       pandoc has no updates
       plantuml has no updates
       yed had errors during update
           Can't validate URL 'https://www.yworks.com'
           Invalid content type: text/html

    Finished 6 packages after .32 minutes.
    1 packages updated and 1 pushed.
    2 total errors - 2 update, 0 push.


Use `updateall` parameter `Name` to specify package names via glob, for instance `updateall [a-d]*` would update only packages which names start with the letter 'a' trough 'd'. Add `Push` among options to push successfully built packages to the chocolatey repository.

Take a look at the [real life example](http://tiny.cc/v1u1ey) of the update script.

### Plugins

It is possible to specify a custom user logic in `Options` parameter - every key that is of type `[HashTable]` will be considered plugin with the PowerShell script that is named the same as the key. The following code shows how to use 5 integrated plugins:

```powershell
    $Options = [ordered]@{
        Timeout = 100
        Threads = 15
        Push    = $true

        Report = @{
            Type = 'text'
            Path = "$PSScriptRoot\report.txt"
        }
        
        Gist = @{
            ApiKey = $Env:github_api_key
            Id     = $Env:github_gist_id
            Path   = "$PSScriptRoot\report.txt"
        }

        Git = @{
            User = ''
            Password = $Env:github_api_key
        }

        RunInfo = @{
            Path = "$PSScriptRoot\update_info.xml"
        }

        Mail = if ($Env:mail_user) {
                @{
                   To         = $Env:mail_user
                   Server     = 'smtp.gmail.com'
                   UserName   = $Env:mail_user
                   Password   = $Env:mail_pass
                   Port       = 587
                   EnableSsl  = $true
                   Attachment = "$PSScriptRoot\$update_info.xml"
                }
        } else {}
    }
```

The plugins above - `Report`, `Git`, `Gist`, `RunInfo` and `Mail` -  are executed in the given order (hence the `[ordered]` flag) and AU passes them given options and saves the run results. If PowerShell script by the name of the given key is not found, the plugin is ignored. 

To add custom plugins, specify additional plugin search path via `$Options.PluginPath`. Plugin is a normal PowerShell script and apart from parameters given in its `[HashTable]` the AU will send it one more parameter `$Info` that contains current run info.

To temporary disable plugins use `updateall` option `NoPlugins` or global variable `$au_NoPlugins`.

### Make a script

Its desirable to put everything in a single script `update_all.ps1` so it can be scheduled and called with the given options. Rename `update_all_default.ps1` and uncomment and set the options you need. 

To make a local scheduled task, use the following code in the directory where your `update_all.ps1` script is found to install it:

    $At = '03:00'
    schtasks /create /tn "Update-AUPackages" /tr "powershell -File '$pwd\update_all.ps1'" /sc daily /st $At

## Other functions

Apart from the functions used in the updating process, there are few suggars for regular maintenance of the package:

- Test-Package  
Quickly `cpack` and install the package from the current directory.

- Push-Package (alias `pp`)  
Push the latest package using your API key.

- Get-AuPackages (alias `gau` or `lsau`)  
Returns the list of the packages which have `update.ps1` script in its directory and which name doesn't start with '_'.
