# Development

The development requires Powershell 5+.

The following scripts are used during development and deployment:

- `setup.ps1`  
Install prerequisites.
- `build.ps1`  
Build the module and packages.
- `install.ps1`  
Install the module in the system.
- `publish.ps1`  
Publish module to Powershell Gallery, Chocolatey and Github.
- `chocolatey\build-package.ps1`  
Build Chocolatey package.


## Build and publish

The builded module will be available in the `_build\{version}` directory. Version is determined automatically based on the current time.

```
./build.ps1
```

To override default versions use `Version` parameter: `./build -Version 0.0.1`.

Before publishing, edit the `NEXT` header in the `CHANGELOG.md` file to set the release notes and build the module. The publish procedure edits this file to change header name to the latest version.

There is a switch parameter for each publishing platform:

```
./publish.ps1 -Github -PSGallery -Chocolatey
```

Publishing procedure depends on number of environment variables. Rename `vars_default.ps1` to `vars.ps1` and set variables there to get them included.

## Clean

To clean build files run `git clean -Xdf`.  **However, keep in mind that other unversioned files will be deleted.**


