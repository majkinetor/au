# AU template: https://raw.githubusercontent.com/majkinetor/au/master/update_all_default.ps1
#    env vars: https://raw.githubusercontent.com/majkinetor/au/master/update_vars_default.ps1

param($Name = $null)

if (Test-Path $PSScriptRoot/update_vars.ps1) { . $PSScriptRoot/update_vars.ps1 }

$Options = [ordered]@{
    #Timeout    = 100
    #Threads    = 10
    #Push       = $Env:au_Push -eq 'true'
    #Force      = $Env:au_Force -eq 'true'
    #PluginPath = ''
    #Script     = @{}

#=== PLUGINS ===============================

    #Report = @{
        #Type = 'markdown'
        #Path = "$PSScriptRoot\Update-AUPacakges.md"
        #Params= @{
            #Github_UserRepo = '' # used by markdown report
        }
    #}

    #Gist = @{
        #Id          = $Env:gist_id
        #ApiKey      = $Env:github_api_key
        #Path        = "$PSScriptRoot\Update-AUPacakges.md"
        #Description = ''
    #}

    #Git = @{
        #User     = ''
        #Password = $Env:github_api_key
    #}

    #RunInfo = @{
        #Exlcude = 'password', 'apikey'
        #Path    = "$PSScriptRoot\update_info.xml"
    #}

    #Mail = if ($Env:mail_user) {
            #@{
                #To          = $Env:mail_user
                #Server      = 'smtp.gmail.com'
                #UserName    = $Env:mail_user
                #Password    = $Env:mail_pass
                #Port        = 587
                #EnableSsl   = $true
                #Attachments = "$PSScriptRoot\update_info.xml"
                #SendAlways  = $false
             #}
           #} else {}
}

$au_Root = $PSScriptRoot
$info = updateall -Name $Name -Options $Options

#Uncomment to fail the build on AppVeyor on any package error
#if ($info.error_count.total) { throw 'Errors during update' }
