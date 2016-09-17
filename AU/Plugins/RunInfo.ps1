# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 17-Sep-2016.

<#
.SYNOPSIS
    Save run info to the file and exclude sensitive information.

.DESCRIPTION
    Run this plugin as the last one to save all other info produced during the run.
#>
param(
    $Info,

    #Path to XML file to save
    [string] $Path = 'update_info.xml',

    #Match options with those words to erase
    [string[]] $Exclude = @('password', 'api_key')
)

function deep_clone {
    param($DeepCopyObject)

    $memStream = new-object IO.MemoryStream
    $formatter = new-object Runtime.Serialization.Formatters.Binary.BinaryFormatter
    $formatter.Serialize($memStream,$DeepCopyObject)
    $memStream.Position=0
    $formatter.Deserialize($memStream)
}

# Runinfo must save its own run results directly in Info
function result($msg) { $Info.plugin_results.RunInfo += $msg; Write-Host $msg }

$Info.plugin_results.RunInfo = @()

$orig_opts = $Info.Options
$opts      = deep_clone $orig_opts
$excluded  = ''
foreach ($w in $Exclude) {
    foreach ($key in $Info.Options.Keys) {
        if ($Info.Options.$key -is [HashTable]) {
            foreach ($subkey in $Info.Options.$key.Keys) {
                if ($subkey -like "*$w*") {
                    $excluded += "$key.$subkey "
                    $opts.$key.$subkey = '*****'
                }
            }
        }
    }
}

if ($excluded) { result "Excluded: $excluded" }
result "File: $Path"
$Info.Options = $opts
$Info | Export-CliXML $Path
$Info.Options = $orig_opts
