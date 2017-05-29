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

    AUPackage([string] $Path ){
        if ([String]::IsNullOrWhiteSpace( $Path )) { throw 'Package path can not be empty' }

        $this.Path = $Path

        $nuspecFile = gi "$Path\*.nuspec" -ea ignore
        if (!($nuspecFile)) { throw 'No nuspec file found in the package directory' }

        $this.Name          = $nuspecFile.BaseName
        $this.NuspecPath    = $nuspecFile.FullName
        $this.NuspecXml     = [AUPackage]::LoadNuspecFile( $this.NuspecPath )
        $this.NuspecVersion = $this.NuspecXml.package.metadata.version
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
