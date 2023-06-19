# SSH Package Installation Script

## Overview
This script allows for the installation of the SSH package on multiple Windows servers using either the Group Policy install method or the CLI install method. It also includes post-installation checks for SSH reachability over Admin or System User.

## Script Descriptions

### Bash Script (mainScript.sh)
This script performs the following tasks:
- Checks if the required dependencies (smbclient, nc, winexe) and files (devices.txt, ps_script, RWSSHD package) are present on the local device.
- Reads device information from the devices.txt file and stores it in an array.
- Loops through each remote device and checks its reachability on port 445.
- Copies the RWSSHD package and PowerShell script to the remote device using the smbclient command.
- Extracts the local path of the copied files on the remote device using the winexe command.
- Executes the ps_script.ps1 on the remote device using winexe, passing the necessary parameters.
- Checks for SSH passwordless reachability post-installation.

### PowerShell Script (ps_script.ps1)
The script performs the installation of the RWSSHD package using the provided parameters. It uses the "msiexec.exe" command with appropriate arguments and includes a timeout value for the installation process.

## Prerequisites
- Administrative privileges for the user running the script.
- Shared folder with full control given to the specified user.
- Disabled User Account Control (UAC) remote restrictions (required to run winexe).


