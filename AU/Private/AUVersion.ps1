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

    AUVersion($input) {
        if (!$input) { throw 'Input cannot be null.' }
        $v = [AUVersion]::Parse($input -as [string])
        $this.Version = $v.Version
        $this.Prerelease = $v.Prerelease
        $this.BuildMetadata = $v.BuildMetadata
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
        # for now, chocolatey does only support SemVer v1 (no dot separated identifiers in pre-release):
        $identifierPattern = "[0-9A-Za-z-]+"
        # here is the SemVer v2 equivalent:
        #$identifierPattern = "[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*"
        if ($strict) {
            return "^$versionPattern(?:-(?<prerelease>$identifierPattern))?(?:\+(?<buildMetadata>$identifierPattern))?`$"
        } else {
            return "$versionPattern(?:-?(?<prerelease>$identifierPattern))?(?:\+(?<buildMetadata>$identifierPattern))?"
        }
    }

    [AUVersion] WithVersion([version] $version) { return [AUVersion]::new($version, $this.Prerelease, $this.BuildMetadata) }

    [int] CompareTo($obj) {
        if ($obj -eq $null) { return 1 }
        if ($obj -isnot [AUVersion]) { throw "AUVersion expected: $($obj.GetType())" }
        $t = $this.GetParts()
        $o = $obj.GetParts()
        for ($i = 0; $i -lt $t.Length -and $i -lt $o.Length; $i++) {
            if ($t[$i].GetType() -ne $o[$i].GetType()) {
                $t[$i] = [string] $t[$i]
                $o[$i] = [string] $o[$i]
            }
            if ($t[$i] -gt $o[$i]) { return 1 }
            if ($t[$i] -lt $o[$i]) { return -1 }
        }
        if ($t.Length -eq 1 -and $o.Length -gt 1) { return 1 }
        if ($o.Length -eq 1 -and $t.Length -gt 1) { return -1 }
        if ($t.Length -gt $o.Length) { return 1 }
        if ($t.Length -lt $o.Length) { return -1 }
        return 0
    }

    [bool] Equals($obj) { return $this.CompareTo($obj) -eq 0 }

    [int] GetHashCode() { return $this.GetParts().GetHashCode() }

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

    hidden [object[]] GetParts() {
        $result = @($this.Version)
        if ($this.Prerelease) {
            $this.Prerelease -split '\.' | % {
                # if identifier is exclusively numeric, cast it to an int
                if ($_ -match '^[0-9]+$') {
                    $result += [int] $_
                } else {
                    $result += $_
                }
            }
        }
        return $result
    }
}

function ConvertTo-AUVersion($Version) {
    return [AUVersion] $Version
}
