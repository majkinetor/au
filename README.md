# Automatic Chocolatey Package Update Module

This Powershell module implements functions that can be used to automate [Chocolatey](https://chocolatey.org) package updates.

To learn more about automatic packages for Chocolatey please refer to the relevant [documentation](https://github.com/chocolatey/choco/wiki/AutomaticPackages).

## Installation

On Powershell 5+: `Install-Module au`.

Otherwise, copy Powershell module to any of the directories in the `$Env:PSModulePath`.

AU module requires minimally Powershell version 4.

**NOTE**: All module functions work from within specific root folder. The folder contains all of your chocolatey packages.

## Creating the package updater script

- In the package directory, create the script `update.ps1`.
- Import the module: `import-module au`.
- Implement two global functions:
  - `global:au_GetLatest`   
  Function returns HashTable with the latest remote version along with other arbitrary user data which you can use elsewhere (for instance in search and replace). The returned version is then compared to the one in the nuspec file and if remote version is higher, the files will be updated. This hashtable is available via global variable `$Latest`.
  - `global:au_SearchReplace`  
  Function returns HashTable containing search and replace data for any package file in the form: 
  ~~~
    @{ 
        file_path1 = @{ 
            search1 = replace1
            ...
            searchN = replaceN 
        }
        file_path2 = @{ ... }
    }
  ~~~
  The function can use `$Latest` hashtable to get any type of information obtained when `au_GetLatest` was executed. Besides this info, the script can access `$global:nuspec_version`.

- Call the `Update-Package` (alias `update`) function from the `au` module to update the package.

This is best understood via the [example](https://github.com/majkinetor/chocolatey/blob/master/dngrep/update.ps1).

With this set, you can update individual packages by calling appropriate `update.ps1` from within package directory:

```
PS c:\chocolatey\dbeaver> ./update.ps1

dbeaver - checking updates
nuspec version: 3.6.1
remote version: 3.7.1
New version is available
Updating files
  dbeaver.nuspec
    updating version:  3.6.1 -> 3.7.1
  .\tools\chocolateyInstall.ps1
    (^[$]url32\s*=\s*)('.*') = $1'http://dbeaver.jkiss.org/files/3.7.1/dbeaver-ee-3.7.1-x86-setup.exe'
    (^[$]url64\s*=\s*)('.*') = $1'http://dbeaver.jkiss.org/files/3.7.1/dbeaver-ee-3.7.1-x86_64-setup.exe'
Attempting to build package from 'dbeaver.nuspec'.
Successfully created package 'dbeaver.3.7.1.nupkg'
Package updated
```

### Checks

The function does some rudimentary verifications of URLs and version strings:
- Version will be checked to match a valid nuspec pattern
- Any hash key that contains word `url`, will be checked for existence and MIME textual type (since binary is expected here)

If check fails, package will not be updated. To skip URL checks you can specify `-NoCheckUrl` argument to the `update` function.


### Automatic checksums

When new version is available, the `update` function will by default download both x32 and x64 versions of the installer and calculate the SHA256 checksum. It will inject this info in the `$global:Latest` variable so you can use it in `au_SearchReplace` to update hashes. The parameter `ChecksumFor` can contain words 'all', 'none', '32' and '64' to further control this behavior. 

You can disable this feature by calling update like this:

    update -ChecksumFor none

**NOTE**: For this feature to work chocolatey must download the package in `"$Env:TMP\chocolatey\$packageName\$Env:chocolateyPackageVersion"`


### Force update

You can force the update even if no new version is found by using the parameter `Force`. This can be useful for recalculating the checksum after the package is created and already pushed to Chocolatey or if URLs to installer changed without version.


### Global variables

To avoid changing the `./update.ps1` when troubleshooting or experimenting you can set up `update` parameters via global variables. As an example, the following code will change the update behavior so that the new package version is not searched on the Chocolatey site and update is forced: 

    $au_NoCheckChocoVersion = $au_Force = $true
    ./update.ps1

This is the same as if you added the parameters to `update` function inside the `./update.ps1` script:

    update -NoCheckChocoVersion -Force

## Updating all packages

You can update all packages and optionally push them to the Chocolatey repository with a single command. Function `Update-AUPackages` (alias `updateall`) will iterate over `update.ps1` scripts and execute each. If it detects that package is updated it will try to push it. 

For push to work, specify your Choocolatey API key in the file `api_key` in the script's directory (or its parent directory) or set environment variable `$Env:api_key`.

This function is designed for scheduling. You can pass it a number of options, save a script and call it via task scheduler. For example, you can get notified about possible errors during packages update procedure - if the update procedure fails for any reasons there is an option to send an email with results as an attachment in order to investigate the problem. 

You can use the following script as a prototype - `update_all.ps1`:

    param($Name = $null)
    cd $PSScriptRoot

    $options = @{
        Timeout = 10
        Threads = 10
        Push    = $false
        Mail = @{
            To       = 'meh@gmail.com'
            Server   = 'smtp.gmail.com'
            UserName = 'meh@gmail.com'
            Password = '**************'
            Port     = 587
            EnableSsl= $true
        }
    }

    Update-AUPackages -Name $Name -Options $options | Export-CliXML update_info.xml

Use function parameter `Name` to specify package names via glob, for instance "d*" would update only packages which names start with the letter 'd'. Add `Push` among options to push sucesifully built packages to the chocolatey repository. The result may look like this:

    PS C:\chocolatey> .\update_all.ps1

    Updating all automatic packages
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

    Finished 6 packages after .3 minutes.
    1 packages updated and 1 pushed.
    2 total errors; 2 update, 0 push.

    Mail with errors sent to meh@gmail.com

The email attachment is a `$info` object that keeps all the information about that particular run, such as what happened to each package during update, how long the operation took etc. It can be loaded with `Import-CliXml result_info.xml` and inspected.

Take a look at [real life example](https://gist.github.com/majkinetor/181b18886fdd363158064baf817fa2ff) of the update_all.ps1 script.

To make a local scheduled task, use the following code in the directory where your `update_all.ps1` script is found to install it:

    $At = '03:00'
    schtasks /create /tn "Update-AUPackages" /tr "powershell -File '$pwd\update_all.ps1'" /sc daily /st $At

<img src="update.gif" width="50%" />


### Custom script

It is possible to specify custom user script in Update-AUPackages `Options` parameter (key `Options.Script`) that will be called before and after the update. The script receives two arguments: `$Phase` and `$Arg`. Currently phase can be one of the words `start` or `end`. Arg contains list of packages to be checked in the start phase and `info` object in the 'end' phase which contains all the details about that run. Use `$Arg | Get-Members` to see what kind of information is available.

The purpose of this script is to attach custom logic at the end of the process (save results to gist, push to git or svn etc.).

## Other functions

Apart from the functions used in the updating process, there are few suggars for regular maintenance of the package:

- Test-Package  
Quickly cpack and install the package from the current directory.

- Push-Package (alias `pp`)  
Push the latest package using your API key.

- Get-AuPackages (alias `gau`)  
Returns the list of the packages which have `update.ps1` script in its directory and which name doesn't start with '_'.

---

**License**: [MIT](https://opensource.org/licenses/MIT)
