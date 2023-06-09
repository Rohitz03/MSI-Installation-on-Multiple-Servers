#!/bin/bash

# Variables for remote Windows device details
ssh_key="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDb6oKOEDl+sFT+spyBd/RhnNNraTUWSR0SXNfgdKhSgSHUv+AyMGFZaU/xv0u5YSGacDobYHQOEq5vTypHIPi+vqgMHB2jzKKsn0EsWCcX6e2kerbLCMLTC/h5bdXIfgRHbB19S+GCctIiyvNOX9JmDiyW0LwKWqKzAC7uyWTeU+RJoemT95P+NNfYSXUV58NgFjbMuKHX95dREjDfK0QzSkUHf8aQ7IGDVGNlaW9Mz4YFr1McrgPqJSOQWy9oGlPfn1r5r5IBqBgttMZ8kHMSOiyf14YN0EJezfZNMa9tn+IKoCsfLSym4O7VqnK83lTZ5Dw5PQocrLvz+aWdPZFz root@ps-centos75x64-01"

devices_file="./devices.txt"
msi_file="./RWSSHDService_x64.msi"
winexe_binary="./winexe"

#Check if smbclient is installed
if ! command -v smbclient &>/dev/null; then
    echo "smbclient is not installed on this system. Please install the samba client package."
    exit 1
fi

#Check if SSH is installed
if ! command -v ssh &>/dev/null; then
    echo "SSH is not installed on this system. Please install the SSH package."
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
while IFS=',' read -r remote_device username password; do
    devices+=("$remote_device" "$username" "$password")
done < "$devices_file"

# Loop through the devices array
for ((i=0; i<${#devices[@]}; i+=3)); do
    remote_device="${devices[$i]}"
    username="${devices[$i+1]}"
    password="${devices[$i+2]}"

    echo "Connecting to $remote_device"
    echo "Username: $username"
    echo "IP: $remote_device"
    echo "Password: $password"
    echo "------------------------"

    # Copy MSI file to the remote device
    if ! smbclient -U "$username%$password" "//$remote_device/C$" -c "put \"$msi_file\" \"RWSSHDService_X64.msi\""; then
        echo "Failed to copy $msi_file to $remote_device"
        continue
    fi

    # Execute the PowerShell script remotely on the remote Windows device to install the SSH package
    if ! ./winexe -U "$username%$password" //"$remote_device" "msiexec /passive /i C:\RWSSHDService_X64.msi TARGETDIR=\"C:\Program Files (x86)\" SVCUSERNAME=\"$username\" PASSWORD=\"$password\" PORT=\"22\" RMMSSHKEY=\"$ssh_key\""; then
        echo "Failed to install SSH package on $remote_device"
        continue
    fi
    echo "Successfully installed SSH package on $remote_device"

    #Post-installation check for SSH reachability
    echo "Performing post-installation check for SSH reachability on $remote_device"
    if ssh -n -o StrictHostKeyChecking=no "$username@$remote_device" exit 2>/dev/null; then
        echo "SSH connection successful"
    else
        echo "SSH connection failed"
    fi
    echo "------------------------"

done
