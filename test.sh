#!/bin/bash

devices_file="./devices.txt"
msi_file="./RWSSHDService_x64.msi"
winexe_binary="./winexe"
filename='RWSSHDService_x64.msi'

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
if [ ! -f "$msi_file" ]; then
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
done <"$devices_file"

# Loop through the devices array
for ((i = 0; i < ${#devices[@]}; i += 4)); do

    remote_device="${devices[$i]}"
    username="${devices[$i + 1]}"
    password="${devices[$i + 2]}"
    shared_folder="${devices[$i + 3]}"

    echo "Connecting to $remote_device"
    echo "Username: $username"
    echo "IP: $remote_device"
    echo "Password: $password"
    echo "Shared Folder Name: $shared_folder"
    echo "RMM SSH KEY: $ssh_key"

    echo "------------------------"

    # check port 445
    nc -w 10 -z $remote_device 445
    if [ $? -eq 0 ]; then
        echo "Success: Device $ip is reachable on Port 445"
    else
        echo "Error: Device $ip is not reachable on Port 445"
        continue
    fi

    # Copy MSI file to the remote device
    if ! smbclient -U "$username%$password" "//$remote_device/$shared_folder" -c "put \"$msi_file\" \"RWSSHDService_X64.msi\""; then
        echo "Failed to copy $msi_file to $remote_device"
        continue
    fi
    echo " "

    netshare_output=$(./winexe -U "$username%$password" //"$remote_device" "net share \"$shared_folder\"")
    # Run the command and assign its output to local_path
    local_path=$(echo "$netshare_output" | sed -n 's/^Path\s*\(.*\)/\1/p')
    # Remove carriage return character
    local_path=$(echo "$local_path" | tr -d '\r')
    # Concatenate the path and filename
    file_path="${local_path}\\${filename}"
    echo "File path: $file_path"
    echo " "

    #Install the SSH package
    if ! ./winexe -U "$username%$password" //"$remote_device" "msiexec /passive /i \"$file_path\" TARGETDIR=\"C:\Program Files (x86)\" SVCUSERNAME=\"$username\" PASSWORD=\"$password\" PORT=\"22\" RMMSSHKEY=\"$ssh_key\""; then
        echo "Failed to install SSH package on $remote_device"
        continue
    fi

    echo "Successfully installed SSH package on $remote_device"
    echo " "

    #Post-installation check for SSH reachability
    echo "Performing post-installation check for SSH reachability on $remote_device"
    if ssh -n -o StrictHostKeyChecking=no "$username@$remote_device" exit 2>/dev/null; then
        echo "SSH connection successful"
    else
        echo "SSH connection failed"
    fi
    echo "------------------------"

done
