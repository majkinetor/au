# Scripts

# Overview

This directory contains automation scripts required to build and publish module.

Main scripts are:

- `setup.ps1`  
Installs build prerequisites.
- `publish.ps1`  
Orchestration script that invokes all steps needed for the module deployment.

# Requirements

- PowerShell version 5+.

## Process

**Deployment is triggered by the new Git commit which contains the keyword `[publish]`**.

Before publishing, manually update the release notes for new version in the file `CHANGELOG.md` under the header `NEXT`.  
