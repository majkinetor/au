# Continuous Integration

# Overview

This directory contains automation scripts required for continuous integration and deployment.

The two main scripts are:

- `setup.ps1`  
Installs build prerequisites.
- `publish.ps1`  
Orchestration script that invokes all steps needed for the module deployment.

## Process

**Deployment is triggered by the new Git tag which contains the new module version in specific format**.

The following things needs to be done manually:

- Update the `CHANGELOG.md` under the header `NEXT`.  
Deployment procedure will use the content of this header as release notes for the new version and replace the header text with the new version.
- Create a new Git tag: `$version = (Get-Date).ToString("yyyy.M.d"); git tag $version; git push --tags`

