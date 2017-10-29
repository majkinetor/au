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

    [string]         $StreamsPath
    [pscustomobject] $Streams

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

    static [pscustomobject] LoadStreams( $StreamsPath ) {
        if (!(Test-Path $StreamsPath)) { return $null }
        return Get-Content $StreamsPath | ConvertFrom-Json
    }

    UpdateStream( $stream, $version ){
        if (!$this.Streams) { $this.Streams = [pscustomobject] @{} }
        $s = $stream.ToString()
        $v = $version.ToString()
        if ($this.Streams | Get-Member $s) {
            if ($this.Streams.$s -ne 'ignore') { $this.Streams.$s = $v }
        } else {
            $this.Streams | Add-Member $s $v
        }
        $this.Streams | ConvertTo-Json | Set-Content $this.StreamsPath -Encoding UTF8
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

}
