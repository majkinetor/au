# Development

The development requires Powershell 5+.

The following scripts are used during development and deployment:

- `setup.ps1`  
Install prerequisites.
- `build.ps1`  
Build the final module form.
- `install.ps1`  
Install the module in the system.
- `publish.ps1`  
Publish module to Powershell Gallery, Chocolatey and Github.
- `chocolatey\build-package.ps1`  
Build Chocolatey package.


## Build

The builded module will be available in the `_build\{version}` directory. Version is determined automatically based on the current time.

```
./build.ps1
```

## Publish

Before publishing, edit the `NEXT` header in the `CHANGELOG.md` file and build the module. The publish procedure edits this file to set the latest version and get the release notes.

There is a switch parameter for each publishing platform:

```
./publish.ps1 -Github -PowershellGallery -Chocolatey
```

## Clean

To clean build files run `git clean -Xdf`. **However, keep in mind that other unversioned files will be deleted.**


