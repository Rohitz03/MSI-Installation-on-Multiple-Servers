param (
    [string]$Username,      # Username for remote device
    [string]$Password,      # Password for remote device
    [string]$Port,          # Port number for remote connection
    [string]$Publickey,     # Public key for remote connection
    [string]$InstallDir,    # Installation directory on remote device
    [string]$PackagePath    # Path to the MSI package
)

# Function to write output messages
function Write-Log {
    param (
        [string]$Message   # Message to be logged
    )
    $outputMessage = "$Message"
    Write-Output $outputMessage
}

# Function to install an MSI package on the remote Windows device
function InstallMsiPackage {
    param (
        [string]$Username,      
        [string]$Password,      
        [string]$Port,          
        [string]$Publickey,    
        [string]$InstallDir,    
        [string]$PackagePath    
    )

    $timeoutInSeconds = 30   # Timeout value for installation process in seconds

    try {
        $process = Start-Process msiexec.exe -Wait -ArgumentList "/i `"$PackagePath`" TARGETDIR=`"$InstallDir`" SVCUSERNAME=`"$Username`" PASSWORD=`"$Password`" PORT=`"$Port`" RMMSSHKEY=`"$Publickey`" /quiet" -NoNewWindow -PassThru
        $process.WaitForExit($timeoutInSeconds * 1000)

        if ($process.HasExited) {
            if ($process.ExitCode -eq 0) {
                Write-Log "Successfully installed RWSSHD package"    # Output success message
            } else {
                Write-Log "Failed to install RWSSHD package. Exit code: $($process.ExitCode)"    # Output failure message with exit code
            }
        } else {
            Write-Log "Timeout reached. The installation process did not complete."    # Output timeout message
        }
    } catch {
        Write-Log "An error occurred during the RWSSHD installation: $_"    # Output error message
    }
}

# Install the MSI package using the provided parameters
InstallMsiPackage -Username $Username -Password $Password -Port $Port -Publickey $Publickey -InstallDir $InstallDir -PackagePath $PackagePath
