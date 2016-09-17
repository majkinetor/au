param(
    $Path = 'update_info.xml',

    #Match options with those words to erase
    $Exclude = @('password', 'api_key')
)

#$i = $Info.Clone()
#"Saving run info"
#foreach ($w in $Exclude) {
    #foreach ($key in $i.Options.Keys) {
        #if ($key -is [HashTable]) {
            #foreach ($subkey in $key) {
                #if ($key -like "*$w*") { $i.Options.$key.$subkey = $null }
            #}
        #}
    #}
#}

$info | Export-CliXML $Path
