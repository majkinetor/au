function Install-AUScheduledTask($At="03:00:00")
{
    schtasks /create /tn "Update-AUPackages" /tr "powershell -NoProfile -File '$pwd\update_all.ps1'" /sc daily /st $At
}
