param (
    [string]$Username,
    [string]$Password,
    [string]$Port,
    [string]$Publickey,
    [string]$InstallDir,
    [string]$PackagePath
)

# Function to write output messages
function Write-Log {
    param (
        [string]$Message
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

    $timeoutInSeconds = 30

    try {
        $process = Start-Process msiexec.exe -Wait -ArgumentList "/i `"$PackagePath`" TARGETDIR=`"$InstallDir`" SVCUSERNAME=`"$Username`" PASSWORD=`"$Password`" PORT=`"$Port`" RMMSSHKEY=`"$Publickey`" /quiet" -NoNewWindow -PassThru
        $process.WaitForExit($timeoutInSeconds * 1000)

        if ($process.HasExited) {
            if ($process.ExitCode -eq 0) {
                Write-Log "Successfully installed RWSSHD package"
            } else {
                Write-Log "Failed to install RWSSHD package. Exit code: $($process.ExitCode)"
            }
        } else {
            Write-Log "Timeout reached. The installation process did not complete."
        }
    } catch {
        Write-Log "An error occurred during the RWSSHD installation: $_"
    }
}

# Install the MSI package
InstallMsiPackage -Username $Username -Password $Password -Port $Port -Publickey $Publickey -InstallDir $InstallDir -PackagePath $PackagePath
