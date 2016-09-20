param($Name = $null)

if (Test-Path $PSScriptRoot/update_vars.ps1) { . $PSScriptRoot/update_vars.ps1 }

$Options = [ordered]@{
    #Timeout    = 100
    #Threads    = 10
    #Push       = $true
    #Force      = $false
    #PluginPath = ''
    #Script     = @{}

#=== PLUGINS ===============================

    #Report = @{
        #Type = 'markdown'
        #Path = "$PSScriptRoot\report.md"
    #}

    #Gist = @{
        #Id      = $Env:gist_id
        #ApiKey  = $Env:github_api_key
        #Path    = "$PSScriptRoot\report.md"
        #Description = ''
    #}

    #Git = @{
        #UserRepo = $Env:github_user_repo
        #User     = ''
        #Password = $Env:github_api_key
    #}

    #RunInfo = @{
        #Exlcude = 'password', 'api_key'
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
updateall -Name $Name -Options $Options | ft

#Uncomment to fail the build on AppVeyor on any package error
#$info = Import-CliXml $PSScriptRoot\update_info.xml
#if ($info.error_count.total) { throw 'Errors during update' }
