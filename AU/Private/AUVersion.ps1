class AUVersion : System.IComparable {
    [version] $Version
    [string] $Prerelease
    [string] $BuildMetadata

    AUVersion([version] $version, [string] $prerelease, [string] $buildMetadata) {
        if (!$version) { throw 'Version cannot be null.' }
        $this.Version = $version
        $this.Prerelease = $prerelease
        $this.BuildMetadata = $buildMetadata
    }

    static [AUVersion] Parse([string] $input) { return [AUVersion]::Parse($input, $true) }

    static [AUVersion] Parse([string] $input, [bool] $strict) {
        if (!$input) { throw 'Version cannot be null.' }
        $reference = [ref] $null
        if (![AUVersion]::TryParse($input, $reference, $strict)) { throw "Invalid version: $input." }
        return $reference.Value
    }

    static [bool] TryParse([string] $input, [ref] $result) { return [AUVersion]::TryParse($input, $result, $true) }

    static [bool] TryParse([string] $input, [ref] $result, [bool] $strict) {
        $result.Value = [AUVersion] $null
        if (!$input) { return $false }
        $pattern = [AUVersion]::GetPattern($strict)
        if ($input -notmatch $pattern) { return $false }
        $reference = [ref] $null
        if (![version]::TryParse($Matches['version'], $reference)) { return $false }
        $result.Value = [AUVersion]::new($reference.Value, $Matches['prerelease'], $Matches['buildMetadata'])
        return $true
    }

    hidden static [string] GetPattern([bool] $strict) {
        $versionPattern = '(?<version>\d+(?:\.\d+){0,3})'
        $identifierPattern = "[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*"
        if ($strict) {
            return "^$versionPattern(?:-(?<prerelease>$identifierPattern))?(?:\+(?<buildMetadata>$identifierPattern))?`$"
        } else {
            return "$versionPattern(?:-?(?<prerelease>$identifierPattern))?(?:\+(?<buildMetadata>$identifierPattern))?"
        }
    }

    [int] CompareTo($obj) {
        if ($obj -eq $null) { return 1 }
        if ($obj -isnot [AUVersion]) { throw "AUVersion expected: $($obj.GetType())" }
        if ($obj.Version -ne $this.Version) { return $this.Version.CompareTo($obj.Version) }
        if ($obj.Prerelease -and $this.Prerelease) { return $this.Prerelease.CompareTo($obj.Prerelease) }
        if (!$obj.Prerelease -and !$this.Prerelease) { return 0 }
        if ($obj.Prerelease) { return 1 }
        return -1
    }

    [bool] Equals($obj) { return $obj -is [AUVersion] -and $obj -and $this.ToString().Equals($obj.ToString()) }

    [int] GetHashCode() { return $this.ToString().GetHashCode() }

    [string] ToString() {
        $result = $this.Version.ToString()
        if ($this.Prerelease) { $result += "-$($this.Prerelease)" }
        if ($this.BuildMetadata) { $result += "+$($this.BuildMetadata)" }
        return $result
    }

    [string] ToString([int] $fieldCount) {
        if ($fieldCount -eq -1) { return $this.Version.ToString() }
        return $this.Version.ToString($fieldCount)
    }
}

function ConvertTo-AUVersion($Version) {
    return [AUVersion] $Version
}
