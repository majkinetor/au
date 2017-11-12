function global:au_SearchReplace() {
    @{}
}

function global:au_GetLatest() {
    @{ Streams = [ordered] @{
        '1.4' = @{ Version = '1.4-beta1' }
        '1.3' = @{ Version = '1.3.1' }
        '1.2' = @{ Version = '1.2.3' }
    } }
}

update
