# Plugins

[AU plugins](https://github.com/majkinetor/au/blob/master/AU/Plugins) are [configured](https://github.com/majkinetor/au#plugins) using parameters passed in the HashTable contained in the Options under the key that is named by the plugin. So,`$Options.xyz=@{...}` is a plugin if `xyz.ps1` exists in a directory pointed to by the `PluginPath` updateall option. The AU will then run this script and pass it `$Options.xyz` HashTable as plugin specific options. AU comes with several integrated plugins that are described bellow.

Default [update_all.ps1](https://github.com/majkinetor/au-packages-template/blob/master/update_all.ps1) uses environment variables to configure some options. If you use [AppVeyor](https://github.com/majkinetor/au/wiki/AppVeyor) set those variables in the [.appveyor.yml](https://github.com/majkinetor/au-packages-template/blob/master/.appveyor.yml) and to run it locally use [update_vars.ps1](https://github.com/majkinetor/au-packages-template/blob/master/update_vars_default.ps1).

## [Gist](https://github.com/majkinetor/au/blob/master/AU/Plugins/Gist.ps1)

**Upload one or more files to gist**.

To set up plugin to create gist under your user name you need to give it your gist id and authentication:

* Log into https://gist.github.com with the user you want to use.
* Create an empty gist (secret or not). Grab the id at the end of it - `https://gist.github.com/name/{id}`. Set it as `$Env:gist_id` environment variable.
* Create [Github personal access token](https://help.github.com/articles/creating-an-access-token-for-command-line-use/) and **make sure token has _gist_ scope selected**. Authenticating with username and password isn't supported for security reasons. Set it as `$Env:github_api_key` environment variable.


## [Git](https://github.com/majkinetor/au/blob/master/AU/Plugins/Git.ps1)

**Persist modified files**.

* To use it locally, just ensure `git push` doesn't require credentials and dont set any environment variables. 
* To use on build server such as [[AppVeyor]], specify `$Env:username` and `$Env:password`. If you host git repository on Github its preferable to use personal access token. You can use the same token as with gist as long as _**public repo**_ scope is activated.

## [GitReleases](https://github.com/majkinetor/au/blob/master/AU/Plugins/GitReleases.ps1)

**Creates Github release for updated packages**.

* It is recommended to add the following line `skip_tags: true` in the `appveyor.yml` file to prevent tags from being built. While it may not be necessary, this is used to prevent packages from being submitted again when `[AU]` or `[PUSH]` is being used in the commit header message.

## [History](https://github.com/majkinetor/au/blob/master/AU/Plugins/History.ps1)

**Create update history as markdown report using git log**. 

Shows one date per line and all of the packages pushed to the Chocolatey community repository during that day. First letter of the package name links to report (produced by Report plugin), the rest links to actuall commit (produced by the Git plugin).

This plugin requires Git plugin and that clone is done with adequate depth.

## [Mail](https://github.com/majkinetor/au/blob/master/AU/Plugins/Mail.ps1)

**Send mail notifications on errors or always**.

* If you use Google mail for error notifications on a build server such as AppVeyor, Google may block authentication from unknown device. To receive those emails enable less secure apps - see [Allowing less secure apps to access your account](https://support.google.com/accounts/answer/6010255?hl=en). 
* If you do not want to use your private email for this, create a new Google account and redirect its messages to your private one. This wont affect you if you run the scripts from your own machine from which you usually access the email.

## [Report](https://github.com/majkinetor/au/blob/master/AU/Plugins/Report.ps1)

**Create different types of reports about the current run**.

The plugin saves state of all packages in a file that can be used locally or uploaded via other plugins to remote (such as Gist or Mail).

## [RunInfo](https://github.com/majkinetor/au/blob/master/AU/Plugins/RunInfo.ps1)

**Save run info to the file and exclude sensitive information**.

Run this plugin as the last one to save all other info produced during the run in such way that it can be recreated as object.
To load it for inspection use `$info = Import-CliXml update_info.xml`.