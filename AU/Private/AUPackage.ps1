class AUPackage {
    [string]   $Path
    [string]   $Name
    [bool]     $Updated
    [bool]     $Pushed
    [string]   $RemoteVersion
    [string]   $NuspecVersion
    [string[]] $Result
    [string]   $Error
    [string]   $NuspecPath
    [xml]      $NuspecXml
    [bool]     $Ignored
    [string]   $IgnoreMessage
    [string]   $StreamsPath
    [System.Collections.Specialized.OrderedDictionary] $Streams

    AUPackage([string] $Path ){
        if ([String]::IsNullOrWhiteSpace( $Path )) { throw 'Package path can not be empty' }

        $this.Path = $Path
        $this.Name = Split-Path -Leaf $Path

        $this.NuspecPath = '{0}\{1}.nuspec' -f $this.Path, $this.Name
        if (!(gi $this.NuspecPath -ea ignore)) { throw 'No nuspec file found in the package directory' }

        $this.NuspecXml     = [AUPackage]::LoadNuspecFile( $this.NuspecPath )
        $this.NuspecVersion = $this.NuspecXml.package.metadata.version

        $this.StreamsPath = '{0}\{1}.json' -f $this.Path, $this.Name
        $this.Streams     = [AUPackage]::LoadStreams( $this.StreamsPath )
    }

    [hashtable] GetStreamDetails() {
        return @{
            Path          = $this.Path
            Name          = $this.Name
            Updated       = $this.Updated
            RemoteVersion = $this.RemoteVersion
        }
    }

    static [xml] LoadNuspecFile( $NuspecPath ) {
        $nu = New-Object xml
        $nu.PSBase.PreserveWhitespace = $true
        $nu.Load($NuspecPath)
        return $nu
    }

    SaveNuspec(){
        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($False)
        [System.IO.File]::WriteAllText($this.NuspecPath, $this.NuspecXml.InnerXml, $Utf8NoBomEncoding)
    }

    static [System.Collections.Specialized.OrderedDictionary] LoadStreams( $streamsPath ) {
        if (!(Test-Path $streamsPath)) { return $null }
        $res = [System.Collections.Specialized.OrderedDictionary] @{}
        $versions = Get-Content $streamsPath | ConvertFrom-Json
        $versions.psobject.Properties | % {
            $stream = $_.Name
            $res.Add($stream, @{ NuspecVersion = $versions.$stream })
        }
        return $res
    }

    UpdateStream( $stream, $version ){
        $s = $stream.ToString()
        $v = $version.ToString()
        if (!$this.Streams) { $this.Streams = [System.Collections.Specialized.OrderedDictionary] @{} }
        if (!$this.Streams.Contains($s)) { $this.Streams.$s = @{} }
        if ($this.Streams.$s -ne 'ignore') { $this.Streams.$s.NuspecVersion = $v }
        $versions = [System.Collections.Specialized.OrderedDictionary] @{}
        $this.Streams.Keys | % {
            $versions.Add($_, $this.Streams.$_.NuspecVersion)
        }
        $versions | ConvertTo-Json | Set-Content $this.StreamsPath -Encoding UTF8
    }

    Backup()  { 
        $d = "$Env:TEMP\au\" + $this.Name

        rm $d\* -Recurse -ea 0
        cp . $d\_backup -Recurse 
    }

    [string] SaveAndRestore() { 
        $d = "$Env:TEMP\au\" + $this.Name

        cp . $d\_output -Recurse 
        rm .\* -Recurse
        cp $d\_backup\* . -Recurse 
        
        return "$d\_output"
    }

    AUPackage( [hashtable] $obj ) {
        if (!$obj) { throw 'Obj can not be empty' }
        $obj.Keys | ? { $_ -ne 'Streams' } | % {
            $this.$_ = $obj.$_
        }
        if ($obj.Streams) {
            $this.Streams = [System.Collections.Specialized.OrderedDictionary] @{}
            $obj.Streams.psobject.Properties | % {
                $this.Streams.Add($_.Name, $_.Value)
            }
        }
    }

    [hashtable] Serialize() {
        $res = @{}
        $this | Get-Member -Type Properties | ? { $_.Name -ne 'Streams' } | % {
            $property = $_.Name
            $res.Add($property, $this.$property)
        }
        if ($this.Streams) {
            $res.Add('Streams', [PSCustomObject] $this.Streams)
        }
        return $res
    }
}
