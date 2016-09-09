[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [String] $ModulePath,

    [Parameter(Mandatory = $true)]
    [Version] $Version
)

$module_name = Split-Path -Leaf $ModulePath

Write-Verbose "Getting public module functions"
$functions = ls $ModulePath\Public\*.ps1 | % { $_.Name -replace '\.ps1$' }
if ($functions.Count -eq 0) { throw 'No public functions to export' }

Write-Verbose "Getting public module aliases"
Import-Module $ModulePath -force
$aliases = Get-Alias | ? { $_.Source -eq $module_name -and ($functions -contains $_.Definition) }

Write-Verbose "Generating module manifest"
$params = @{
    Guid              = 'b2cb6770-ecc4-4a51-a57a-3a34654a0938'
    Author            = 'Miodrag Milic'
    PowerShellVersion = '3.0'
    Description       = 'Chocolatey Automatic Package Updater Module'
    HelpInfoURI       = 'https://github.com/majkinetor/au/blob/master/README.md'
    Tags              = 'chocolatey', 'update'
    LicenseUri        = 'https://opensource.org/licenses/MIT'
    ProjectUri        = 'https://github.com/majkinetor/au'
    ReleaseNotes      = 'https://github.com/majkinetor/au/blob/master/Changelog.md'

    ModuleVersion     = $Version
    FunctionsToExport = $functions
    AliasesToExport   = $aliases        #better then * as each alias is shown in PowerShell Galery
    Path              = "$ModulePath\$module_name.psd1"
    RootModule        = "$module_name.psm1"

}
New-ModuleManifest @params
