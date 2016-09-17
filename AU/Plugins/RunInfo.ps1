param(
    $Path = 'update_info.xml',

    #Match options with those words to erase
    $Exclude = @('password', 'api_key')
)

function deep_clone {
    param($DeepCopyObject)

    $memStream = new-object IO.MemoryStream
    $formatter = new-object Runtime.Serialization.Formatters.Binary.BinaryFormatter
    $formatter.Serialize($memStream,$DeepCopyObject)
    $memStream.Position=0
    $formatter.Deserialize($memStream)
}

$orig_opts = $Info.Options
$opts      = deep_clone $orig_opts
$excluded  = ''
foreach ($w in $Exclude) {
    foreach ($key in $Info.Options.Keys) {
        if ($Info.Options.$key -is [HashTable]) {
            foreach ($subkey in $Info.Options.$key.Keys) {
                if ($subkey -like "*$w*") {
                    $excluded += "$key.$subkey "
                    $opts.$key.$subkey = '******'
                }
            }
        }
    }
}

if ($excluded) { Write-Host "  excluded: $excluded" }
Write-Host "  saving to: $Path"
$Info.Options = $opts
$Info | Export-CliXML $Path
$Info.Options = $orig_opts
