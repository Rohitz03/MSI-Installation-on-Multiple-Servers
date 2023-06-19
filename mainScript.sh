#!/bin/bash

#variables
port=22
devices_file="./devices.txt"
local_ps_script="./ps_script.ps1"
local_msi_file="./RWSSHDService_x64.msi"
winexe_binary="./winexe"
installation_path='"C:\Program Files (x86)"'


#Names of files on remote device
remote_msi_file='RWSSHDService_x64.msi'
remote_ps_file='ps_script.ps1'

# Check if the id_rsa.pub file exists
if [ ! -f ~/.ssh/id_rsa.pub ]; then
    echo "Generating SSH key pair..."
    # Generate a new SSH key pair
    ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
    echo "SSH key pair generated."
fi

# Read the contents of the SSH public key file
ssh_key=$(cat ~/.ssh/id_rsa.pub)

# Check if required commands and utilities are installed
if ! command -v nc &>/dev/null; then
    echo "Error: nc is not installed. Please install it and try again."
    exit 1
fi

#Check if smbclient is installed
if ! command -v smbclient &>/dev/null; then
    echo "smbclient is not installed on this system. Please install the samba client package."
    exit 1
fi

#Check if the MSI file exists
if [ ! -f "$local_msi_file" ]; then
    echo "The file $msi_file does not exist in the current directory."
    exit 1
fi

#Check if the Powershell script exists
if [ ! -f "$local_ps_script" ]; then
    echo "The file $msi_file does not exist in the current directory."
    exit 1
fi

#Check if the winexe binary exists
if [ ! -f "$winexe_binary" ]; then
    echo "The winexe binary does not exist in the current directory."
    exit 1
fi

# Check if the devices file exists and is readable
if [ ! -f "$devices_file" ] || [ ! -r "$devices_file" ]; then
    echo "The devices file $devices_file is either missing or not readable."
    exit 1
fi


# Declare an array to store device information
declare -a devices

# Read the devices file into the array
while IFS=',' read -r remote_device username password shared_folder; do
    devices+=("$remote_device" "$username" "$password" "$shared_folder")
done < "$devices_file"

# Loop through the devices array
for ((i = 0; i < ${#devices[@]}; i += 4)); do
    remote_device="${devices[$i]}"
    username="${devices[$i + 1]}"
    password="${devices[$i + 2]}"
    shared_folder="${devices[$i + 3]}"
    
    echo " "
    echo "Connecting to $remote_device"
    echo "Username: $username"
    echo "Password: $password"
    echo "Shared Folder Name: $shared_folder"
    echo "RMM SSH KEY: $ssh_key"
    echo " "
    echo "------------------------"

    # check port 445
    nc -w 10 -z $remote_device 445
    if [ $? -eq 0 ]; then
        echo "Success: Device $ip is reachable on Port 445"
    else
        echo "Error: Device $ip is not reachable on Port 445"
        continue
    fi
    echo " "
    echo "------------------------"

    # Copy MSI file to the remote device
    smbclient -U "$username%$password" "//$remote_device/$shared_folder" -c "put \"$local_msi_file\" \"$remote_msi_file\""
    if [ $? -eq 0 ]; then
        echo "Successfully copied $local_msi_file to $remote_device"
    else
        echo "Failed to copy $local_msi_file to $remote_device"
        continue
    fi
    echo " "
    echo "------------------------"

    # Copy PowerShell Script to the remote device
    smbclient -U "$username%$password" "//$remote_device/$shared_folder" -c "put \"$local_ps_script\" \"$remote_ps_file\""
    if [ $? -eq 0 ]; then
        echo "Successfully copied $local_ps_script to $remote_device"
    else
        echo "Failed to copy $local_ps_script to $remote_device"
        continue
    fi
    echo " "
    echo "------------------------"

    netshare_output=$(./winexe -U "$username%$password" //"$remote_device" "net share \"$shared_folder\"")
    # Run the command and assign its output to local_path
    local_path=$(echo "$netshare_output" | sed -n 's/^Path\s*\(.*\)/\1/p')
    # Remove carriage return character
    local_path=$(echo "$local_path" | tr -d '\r')


    # Concatenate the path and filename
    msi_file_path="${local_path}\\${remote_msi_file}"
    echo "RWSSHD File path on $remote_device : $msi_file_path"

    ps_script_path="${local_path}\\${remote_ps_file}"
    echo "Powershell Script path on $remote_device : $ps_script_path"
    echo " "
    echo "------------------------"

    installation_output=$(./winexe -U "$username%$password" //"$remote_device" "powershell -ExecutionPolicy Bypass -File \"$ps_script_path\" -Username \"$username\" -Password \"$password\" -Port \"$port\" -Publickey \"$ssh_key\" -InstallDir \"$installation_path\" -PackagePath \"$msi_file_path\"")
    if [ $? -ne 0 ]; then
        echo "Failed to install SSH package on $remote_device"
        continue
    fi
    echo "$installation_output"
    echo " "
    echo "------------------------"
    

    #Post-installation check for SSH reachability
    echo "Performing post-installation check for SSH reachability on $remote_device"
    ssh -n -o StrictHostKeyChecking=no -o ConnectTimeout=30 -o BatchMode=yes "$username@$remote_device" exit 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "SSH connection successful"
    else
        echo "SSH connection failed"
    fi
    echo " "

    echo "------------------------"
    echo "************************"
    echo "------------------------"

done

