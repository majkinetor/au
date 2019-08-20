# Edit variable values and then save this file as 'vars.ps1' to get it included into the publish procedure.

$Env:Github_UserRepo   = ''   # Publish to Github; commit git changes
$Env:Github_ApiKey     = ''   # Publish to Github token
$Env:NuGet_ApiKey      = ''   # Publish to PSGallery token
$Env:Chocolatey_ApiKey = ''   # Publish to Chocolatey token

$Env:gitlab_user            = ''   # GitLab username to use for the push
$Env:gitlab_api_key         = ''   # GitLab API key associated with gitlab_user
$Env:gitlab_push_url        = ''   # GitLab URL to push to. Must be HTTP or HTTPS. e.g. https://jekotia:MyPassword@git.example.org/jekotia/au.git
$Env:gitlab_commit_strategy = ''   # Same values as the Git plugin; single, atomic, or atomictag
