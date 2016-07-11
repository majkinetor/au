Automatic Chocolatey Package Update Module
==========================================

This Powershell module implements functions that can be used to automate [Chocolatey](https://chocolatey.org) package updates.

It can be used instead of the [official method](https://github.com/chocolatey/choco/wiki/AutomaticPackages).

Installation
------------

On Powershell 5+: `Install-Module au`.
Otherwise, copy Powershell module to any of the directories in the `$Env:PSModulePath`.

**NOTE**: All module functions work from within specific root folder. The folder contains all of your chocolatey packages.

Creating the package updater script
-----------------------------------

- In the package directory, create the script `update.ps1`.
- Import the module: `import-module au`
- Implement two global functions:
  - `global:au_GetLatest`   
  Function returns HashTable with the latest remote version along with other arbitrary user data which you can use elsewhere (for instance in search and replace). The returned version is then compared to the one in the nuspec file and if they are different, the files will be updated. This hashtable is available via global variable `$Latest`.
  - `global:au_SearchReplace`  
  Function returns HashTable containing search and replace data for any file in the form: 
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

- Call the `Update-Package` (alias `update`) function from the `au` module to update the package.

This is best understood via the [example](https://github.com/majkinetor/chocolatey/blob/master/dngrep/update.ps1).

With this set, you can call individual `update.ps1` from within its directory to update that specific package.

### Checks

The function does some rudimentary verifications of URLs and version strings:
- Version will be checked to match a valid nuspec pattern
- Any hash key that contains word `url`, will be checked for existence and MIME textual type (since binary is expected here)

If check fails, package will not be updated. To skip URL checks you can specify `-NoUrlCheck` argument to the `update` function.

Updating all packages
---------------------

You can update all packages and optionally push them to the chocolatey repository with a single command. For push to work, specify your API key in the file `api_key` in the script's directory (or its parent directory) or set environment variable `$Env:api_key`.

Function `Update-AUPackages` will iterate over `update.ps1` scripts and execute each. If it detects that package is updated it will `cpack` it and push it. 

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

    Update-AUPackages -Name $Name -Options $options | Export-CliXML update_results.xml

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

The email attachment is a `$result` object that keeps all the information about each package which happened during update. It can be loaded with `Import-CliXml` and inspected.

Take a look at [real life example](https://gist.github.com/majkinetor/44c248fc1e58059e09a4f760928425f0).

Use the following code in the directory where your `update_all.ps1` script is found to install scheduled task:

    $At = '03:00'
    schtasks /create /tn "Update-AUPackages" /tr "powershell -File '$pwd\update_all.ps1'" /sc daily /st $At

<img src="update.gif" width="50%" />

Other functions
---------------

Apart from the functions used in the updating process, there are few suggars for regular maintenance of the package:

- Test-Package
Quickly cpack and install the package from the current directory.

- Push-Package (alias `pp`)  
Push the latest package using API key in the api_key file.

- Get-AuPackages (alias `gau`)  
Returns the list of the packages which have `update.ps1` script in its directory and which name doesn't start with '_'.
