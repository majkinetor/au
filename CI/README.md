# Continuous Integration

# Overview

This directory contains automation scripts required for continuous integration and deployment.

The two main scripts are:

- `setup.ps1`  
Installs build prerequisites.
- `publish.ps1`  
Orchestration script that invokes all steps needed for the module deployment.

# Requirements

- PowerShell version 5+.

## Process

**Deployment is triggered by the new Git commit which contains the keyword `[publish]`**.

Before publishing, manually update the release notes for new version in the file `CHANGELOG.md` under the header `NEXT`.  
