#!/bin/bash

#variables
port=22
devices_file="./devices.txt"
#add path of ps_script and msi pacakage
local_ps_script="./ps_script.ps1"
local_msi_64bit="./RWSSHDService_x64.msi"
local_msi_32bit="./RWSSHDService.msi"
winexe_binary="./winexe"


#Names of files on remote device
remote_msi_64bit='RWSSHDService_x64.msi'
remote_msi_32bit='RWSSHDService.msi'
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
if [ ! -f "$local_msi_64bit" ]; then
    echo "The file $local_msi_64bit does not exist in the specified directory."
    exit 1
fi

# if [ ! -f "$local_msi_32bit" ]; then
#     echo "The file $local_msi_32bit does not exist in the specified directory."
#     continue
# fi

#Check if the Powershell script exists
if [ ! -f "$local_ps_script" ]; then
    echo "The file $local_ps_script does not exist in the specified directory."
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
        echo "Success: Device $remote_device is reachable on Port 445"
    else
        echo "Error: Device $remote_device is not reachable on Port 445"
        continue
    fi
    echo "------------------------"

    netshare_output=$(./winexe -U "$username%$password" //"$remote_device" "net share \"$shared_folder\"")
    # Run the command and assign its output to local_path
    local_path=$(echo "$netshare_output" | sed -n 's/^Path\s*\(.*\)/\1/p')
    # Remove carriage return character
    local_path=$(echo "$local_path" | tr -d '\r')


    # Copy PowerShell Script to the remote device
    echo "Copying $local_ps_script ......"
    echo " "
    timeout 2m smbclient -U "$username%$password" "//$remote_device/$shared_folder" -c "put \"$local_ps_script\" \"$remote_ps_file\""
    if [ $? -eq 0 ]; then
        echo "Successfully copied $local_ps_script to $remote_device"
    else
        echo "Failed to copy $local_ps_script to $remote_device"
        continue
    fi
    echo "------------------------"

    #Check the architecture of the remote Windows device using winexe
    server_arch=$(./winexe -U "$username%$password" //"$remote_device" "wmic os get osarchitecture"  | awk 'NR==2')
    if [ $? -ne 0 ]; then
        echo "Error executing winexe command for device"
        echo "$server_arch"
        continue
    fi
    
    # Set Installation Directory according architecture of the remote Windows device
    if [[ $server_arch == *"64-bit"* ]]; then
        installation_path='"C:\Program Files (x86)"'
        
        # Copy MSI file to the remote device
        echo "Copying $local_msi_64bit ......"
        echo " "
        timeout 25m smbclient -U "$username%$password" "//$remote_device/$shared_folder" -c "put \"$local_msi_64bit\" \"$remote_msi_64bit\""
        if [ $? -eq 0 ]; then
            echo "Successfully copied $local_msi_64bit to $remote_device"
        else
            echo "Failed to copy $local_msi_64bit to $remote_device"
            continue
        fi
        echo "------------------------"

        # Concatenate the path and filename
        echo "File Paths ......"
        echo " "
        msi_file_path="${local_path}\\${remote_msi_64bit}"
        echo "RWSSHD File path on $remote_device : $msi_file_path"

        ps_script_path="${local_path}\\${remote_ps_file}"
        echo "Powershell Script path on $remote_device : $ps_script_path"
        echo "------------------------"

        echo "Installating $local_msi_64bit in the $installation_path on $remote_device "
        echo " "
        installation_output=$(./winexe -U "$username%$password" //"$remote_device" "powershell -ExecutionPolicy Bypass -File \"$ps_script_path\" -Username \"$username\" -Password \"$password\" -Port \"$port\" -Publickey \"$ssh_key\" -InstallDir \"$installation_path\" -PackagePath \"$msi_file_path\"")
        if [ $? -ne 0 ]; then
            echo "Failed to install SSH package on $remote_device"
            continue
        fi
        echo "$installation_output"
        echo "------------------------"

    else
        installation_path='"C:\Program Files"'

        # Copy MSI file to the remote device
        echo "Copying $local_msi_32bit ......"
        echo " "
        timeout 25m smbclient -U "$username%$password" "//$remote_device/$shared_folder" -c "put \"$local_msi_32bit\" \"$remote_msi_32bit\""
        if [ $? -eq 0 ]; then
            echo "Successfully copied $local_msi_32bit to $remote_device"
        else
            echo "Failed to copy $local_msi_32bit to $remote_device"
            continue
        fi
        echo "------------------------"

        # Concatenate the path and filename
        echo "File Paths ......"
        echo " "
        msi_file_path="${local_path}\\${remote_msi_32bit}"
        echo "RWSSHD File path on $remote_device : $msi_file_path"

        ps_script_path="${local_path}\\${remote_ps_file}"
        echo "Powershell Script path on $remote_device : $ps_script_path"
        echo "------------------------"

        echo "Installating $local_msi_32bit in the $installation_path on $remote_device"
        echo " "
        installation_output=$(./winexe -U "$username%$password" //"$remote_device" "powershell -ExecutionPolicy Bypass -File \"$ps_script_path\" -Username \"$username\" -Password \"$password\" -Port \"$port\" -Publickey \"$ssh_key\" -InstallDir \"$installation_path\" -PackagePath \"$msi_file_path\"")
        if [ $? -ne 0 ]; then
            echo "Failed to execute powershell script through winexe on $remote_device"
            continue
        fi
        echo "$installation_output"
        echo "------------------------"
    fi
    

    #Post-installation check for SSH reachability
    echo "Performing post-installation check for SSH reachability on $remote_device"
    echo " "
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

