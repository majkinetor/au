# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 16-Aug-2016.

<#
.SYNOPSIS
    Update all automatic package in the current directory

.DESCRIPTION
    Function Update-AUPackages will iterate over update.ps1 scripts and execute each. If it detects
    that package is updated it will cpack it and push it. For push to work, specify your API key in the
    file 'api_key' in the script's directory.

.EXAMPLE
    Update-AUPackages p* @{ Threads = 5; Timeout = 10 }

    Update all automatic packages in the current directory that start with letter 'p' using 5 threads
    and web timeout of 10 seconds.
#>
function Update-AUPackages {
    [CmdletBinding()]
    param(
        # Filter package names. Supports globs.
        [string] $Name,

        <#
        Hashtable with options:
          Threads     - Number of background jobs to use, by default 10
          Timeout     - WebRequest timeout in seconds, by default 100
          Force       - Force package update even if no new version is found
          Push        - Set to true to push updated packages to chocolatey repository
          Mail        - Hashtable with mail notification options: To, Server, UserName, Password, Port, EnableSsl
          Script      - Specify script to be executed at the start and after the update. Script accepts two arguments:
                          $PHASE  - can be 'start' or 'end'
                          $ARG    - in start phase it is the list of packages to be updated;
                                    in end phase it is the info object that contains information about the previous run;
        #>
        [HashTable] $Options=@{}
    )

    function Load-NuspecFile() {
        $nu = New-Object xml
        $nu.psbase.PreserveWhitespace = $true
        $nu.Load($nuspecFile)
        $nu
    }

    # Copy choco powershell functions to TEMP dir and monkey patch the Get-ChocolateyWebFile function
    $cd = $pwd
    $startTime = Get-Date

    if (!$Options.Threads) { $Options.Threads = 10}
    if (!$Options.Timeout) { $Options.Timeout = 100 }
    if (!$Options.Force)   { $Options.Force = $false }
    if (!$Options.Push)    { $Options.Push = $false}

    Remove-Job * -force #remove any previously run jobs

    $tmp_dir = "$ENV:Temp\chocolatey\au"
    mkdir -ea 0 $tmp_dir | out-null
    Get-ChildItem $tmp_dir | Where-Object PSIsContainer -eq $false | Remove-Item   #clear tmp dir files

    $threads    = New-Object object[] $Options.Threads
    $result     = @()
    $script_err = 0

    $aup = Get-AUPackages $Name
    $j = 0

    Write-Host 'Updating' $aup.Length  'automatic packages at' $startTime

    if ($Options.Script) { try { & $Options.Script 'START' $aup | Write-Host } catch { Write-Error $_; $script_err += 1 } }
    while( $true ) {

        # Check for completed jobs
        Get-Job | Where-Object state -ne 'Running' | ForEach-Object {
            $job = $_

            if ( 'Failed', 'Completed' -notcontains $job.State) { 
                Write-Host "Invalid job state for $($job.Name): " + $job.State
            }
            else {
                Write-Verbose ($job.State + ' ' + $job.Name)
                $i = [ordered]@{PackageName=''; Updated=''; Pushed=''; RemoteVersion=''; NuspecVersion=''; Message=''; Result=''; Error=@()}
                $i.PackageName = $job.Name

                $i.Result  = Receive-Job $_ -ErrorAction SilentlyContinue -ErrorVariable err
                $i.Error   = $err
                $i.Updated = $i.Pushed = $false
                if ($i.Result)
                {
                    $i.Updated       = $i.Result -contains 'Package updated'
                    $i.RemoteVersion = ($i.Result -match '^remote version: .+$').Substring(16)
                    $i.NuspecVersion = ($i.Result -match '^nuspec version: .+$').Substring(16)
                    $i.Message       = $i.PackageName + ' '

                    $forced_version = ($i.Result -match 'using Chocolatey fix notation.+ -> (.+)') -split '-> ' | Select-Object -last 1
                    if ($forced_version) { $i.NuspecVersion = $version = $forced_version } else { $version = $i.RemoteVersion }

                    $i.Message      += if ($i.Updated) { 'is updated to ' + $version } else { 'has no updates' }

                    if ($i.Updated -and $Options.Push) {
                        $i.Pushed = ($i.Result -like 'Failed to process request*').Length -eq 0
                        if (!$i.Pushed) {
                            $i.Message += ' but push failed!'
                            $i.Error += ($i.Result | Select-String "Attempting to push" -Context 0,10).ToString()
                        } else { $i.Message += ' and pushed' }
                    }

                    Write-Host '  ' $i.Message
                }

                if ($i.Error) {
                    #When packages ./update.ps1 fails no nuspec version is available in the output
                    $nuspecFile = "$pwd\{0}\{0}.nuspec" -f $i.PackageName
                    $i.NuspecVersion = (Load-NuspecFile($nuspecFile)).package.metadata.version

                    Write-Host "   $($i.PackageName) ERROR:"
                    $i.Error[0].ToString() -split "`n" | ForEach-Object { Write-Host (' '*5 + $_) }
                }

                $result += [pscustomobject]$i
            }
            Remove-Job $job
        }

        # Check if all packages are done
        $job_count = Get-Job | Measure-Object | ForEach-Object count
        if ($result.length -eq $aup.length) { break }

        # Just sleep a bit and repeat if all threads are busy
        if (($job_count -eq $Options.Threads) -or ($j -eq $aup.length)) { sleep 1; continue }

        # Start a new thread
        $package_path = $aup[$j++]
        $package_name = Split-Path $package_path -Leaf
        Write-Verbose "Starting $package_name"
        Start-Job -Name $package_name {
            cd $using:package_path

            $global:au_Timeout = $using:Options.Timeout
            $global:au_Force = $using:Options.Force
             ./update.ps1 *> "$using:tmp_dir\$using:package_name"
             $res = Get-Content $using:tmp_dir\$using:package_name

            $updated = ![string]::IsNullOrEmpty($res) -and ($res[-1] -eq 'Package updated')
            if ($updated -and $using:Options.Push) {
                import-module au
                $res += Push-Package
            }

            $res
        } | out-null
    }
    $result = $result | Sort-Object PackageName

    $info = get-info
    if ($Options.Script) { try { & $Options.Script 'END' $info | Write-Host } catch { Write-Error $_; $script_err += 1 } }

    @('') + $info.stats + '' | Write-Host
    send-notification

    $result
}

function send-notification() {
    if (!($info.error_count.total -and $Options.Mail)) { return }

    $body = "$($info.error_count.total) errors during update`n"
    $body += "Attachment contains complete output of the run, you can load it using Import-CliXML cmdlet.`n`n"
    $body += $info.error_info

    try {
        send-mail $Options.Mail $body -ea Stop
        Write-Host ("Mail with errors sent to " + $Options.Mail.To)
    } catch { Write-Error $_ }
}

function get-info {
    $errors = $result | Where-Object { $_.Error.Length }
    $info = [PSCustomObject]@{
        result = [PSCustomObject]@{
            all     = $result
            errors  = $errors
            ok      = $result | Where-Object { !$_.Error.Length }
            pushed  = $result | Where-Object Pushed
            updated = $result | Where-Object Updated
        }

        error_count = [PSCustomObject]@{
            update  = $errors | Where-Object {!$_.Updated} | Measure-Object | ForEach-Object count
            push    = $errors | Where-Object {$_.Updated -and !$_.Pushed} | Measure-Object | ForEach-Object count
            total   = $errors | Measure-Object | ForEach-Object count
        }
        error_info  = ''

        packages  = $aup
        startTime = $startTime
        minutes   = ((Get-Date) - $startTime).TotalMinutes.ToString('#.##')
        pushed    = $result | Where-Object Pushed  | Measure-Object | ForEach-Object count
        updated   = $result | Where-Object Updated | Measure-Object | ForEach-Object count
        stats     = ''
        options   = $Options
    }
    $info.stats = get-stats
    $info.error_info = $errors | ForEach-Object {
        $s = "`nPackage: " + $_.PackageName + "`n"
        $_.Error | out-string
    }

    $info
}

function get-stats {
    "Finished {0} packages after {1} minutes." -f $info.packages.length, $info.minutes
    "{0} packages updated and {1} pushed." -f $info.updated, $info.pushed
    "{0} total errors - {1} update, {2} push." -f $info.error_count.total, $info.error_count.update, $info.error_count.push
    if ($Options.Script) { "$script_err user script errors." }
}

function send-mail($Mail, $Body) {
    $from = "Update-AUPackages@{0}.{1}" -f $Env:UserName, $Env:ComputerName
    $msg  = New-Object System.Net.Mail.MailMessage $from, $Mail.To
    $msg.Subject    = "$($info.error_count.total) errors during update"
    $msg.IsBodyHTML = $true
    $msg.Body       = "<body><pre>$Body</pre></body>"

    $info | Export-CliXML "$Env:TEMP\au_info.xml"
    $attachment = new-object Net.Mail.Attachment( "$Env:TEMP\au_info.xml" )
    $msg.Attachments.Add($attachment)

    $smtp = new-object Net.Mail.SmtpClient($Mail.Server)
    if ($Mail.UserName) {
        $smtp.Credentials = new-object System.Net.NetworkCredential($Mail.UserName, $Mail.Password)
    }
    if ($Mail.Port) { $smtp.port = $Mail.Port }
    $smtp.EnableSsl = $Mail.EnableSsl
    $smtp.Send($msg)
}

Set-Alias updateall Update-AuPackages
