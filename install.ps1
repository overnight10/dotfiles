#Requires -RunAsAdministrator

$user = "overnight10"
$repository = "dotfiles"
$branch = "windows"

$symlinkRecords = @(
    @{ Source = "~\.config"; Target = "$repository\.config" }, 
    @{ Source = "~\AppData\Roaming\nushell"; Target = "~\.config\nushell" }, 
    @{ Source = "~\AppData\Roaming\helix"; Target = "~\.config\helix" },
    @{ Source = "~\scoop\persist\windows-terminal-preview\settings"; Target = "~\.config\terminal" },
    @{ Source = "~\scoop\persist\btop-lhm\themes"; Target = "~\.config\btop\themes" },
    @{ Source = "~\scoop\apps\btop-lhm\current\btop.conf"; Target = "~\.config\btop\btop.conf" }
)

# Enhanced linking function
function Linking {
    param (
        [Parameter(Mandatory = $true)]
        [array]$records
    )

    foreach ($record in $records) {
        $exists = Test-Path -Path $record.Source
        if (!$exists) {
            continue
        }
        # Cleanup: Automatically handle existing items at the source path
        try {
            if ((Get-Item -Path $record.Source).LinkType -eq 'SymbolicLink') {
                # Remove existing symbolic link
                Remove-Item -Force -Path $record.Source
                Write-Host "[INFO] Existing symlink $record.Source removed." -ForegroundColor Yellow
            }
            else {
                # Remove existing file or folder
                Remove-Item -Force -Recurse -Path $record.Source
                Write-Host "[INFO] Existing file/folder $record.Source removed." -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "[ERROR] Failed to remove $record.Source. Error: $_" -ForegroundColor Red
            continue
        }

        # Create the symbolic link
        try {
            New-Item -ItemType SymbolicLink -Path $record.Source -Target $record.Target
            Write-Host "[INFO] Symlink created: $record.Source -> $record.Target" -ForegroundColor Green
        }
        catch {
            Write-Host "[ERROR] Failed to create symlink: $_" -ForegroundColor Red
        }
    }
}

function which($command) {
    Get-Command $command -ErrorAction SilentlyContinue
}

function main {
    Set-Location ~  # Go to the user's home directory

    # Create temporary directory for scoop.json
    mkdir -Force .temp | Out-Null
    Set-Location .temp

    # Check if Scoop is installed
    $scoop = which scoop
    if (!$scoop) {
        Write-Host "[INFO] Scoop not found. Installing..."
        Invoke-Expression "& {$(Invoke-RestMethod get.scoop.sh)} -RunAsAdmin"
        $scoop = which scoop
        if (!$scoop) {
            Write-Error "[ERROR] Scoop installation failed!"
            Set-Location ~
            exit 1
        }
        else {
            Write-Host "[INFO] Scoop installed successfully!"
        }
    }

    # Path for scoop.json
    $outputFile = Join-Path -Path $pwd -ChildPath "scoop.json"
    Write-Host "[INFO] Fetching scoop.json from repository"

    try {
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$user/$repository/$branch/assets/scoop.json" -OutFile $outputFile
        scoop import $outputFile
        Write-Host "[INFO] Scoop packages installed!"
    }
    catch {
        Write-Host "[ERROR] Unable to fetch scoop.json."
        $continue = Read-Host "Do you want to continue without scoop.json? (y/n)"
        if ($continue -ne "y") {
            Write-Host "[INFO] Installation cancelled."
            Set-Location ~
            exit 1
        }
        else {
            Write-Host "[INFO] Continuing without scoop.json."
        }
    }

    # Cleanup: Remove temporary directory
    Set-Location ~
    Remove-Item -Force -Recurse -Path .temp
    Write-Host "[INFO] Temp directory deleted."

    # Check if Git is installed
    $git = which git
    if (!$git) {
        Write-Error "[ERROR] Git is not installed!"
        scoop install git
        $git = which git
        if (!$git) {
            Write-Error "[ERROR] Unable to install Git via Scoop."
        }
        else {
            git config --global --add safe.directory $home\\scoop\\buckets\\versions
        }
        $continue = Read-Host "Do you want to continue with a blank template? (y/n)"
        if ($continue -ne "y") {
            Write-Host "[INFO] Installation cancelled."
            Set-Location ~
            exit 1
        }
        else {
            Write-Host "[INFO] Creating dotfiles directory"
            # Create necessary directories
            New-Item -Force -ItemType Directory -Path $repository | Out-Null
            New-Item -Force -ItemType Directory -Path "$repository\.config" | Out-Null
        }
    }
    else {
        # Check if the dotfiles directory exists
        if (Test-Path -Path $repository) {
            Write-Host "[INFO] Dotfiles directory found."
            $overwrite = Read-Host "Do you want to overwrite the existing dotfiles? (y/n)"
            if ($overwrite -ne "y") {
                Write-Host "[INFO] Continuing with local dotfiles."
                $createSymlinks = Read-Host "Do you want to create symlinks? (y/n)"
                if ($createSymlinks -eq "y") {
                    Write-Host "[INFO] Creating symlinks..."
                    linking -records $symlinkRecords
                    Write-Host "[INFO] Symlinks created!"
                }
                Set-Location ~
                exit 0
            }
            else {
                # User chose to overwrite
                Remove-Item -Force -Recurse -Path $repository
                Write-Host "[INFO] Existing dotfiles directory deleted."
            }
        }

        Write-Host "[INFO] Cloning dotfiles repository..."
        git clone "https://github.com/$user/$repository.git" -b $branch
    }

    # Call the function to create symlinks
    linking -records $symlinkRecords

    Write-Host "[INFO] Dotfiles installed!"
    Set-Location ~
}

# Call the main function and wrap it in a try/catch block
try {
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Error "[ERROR] PowerShell 5 or higher is required to run this script."
        Set-Location ~
        exit 1
    }
    
    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
    if ($currentPolicy -ne 'RemoteSigned') {
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Write-Host "[INFO] Execution policy set to RemoteSigned."
    }
    main
}
catch {
    # Handle errors and clean up
    Set-Location ~
    Write-Error "[ERROR] An error occurred: $_"
    Write-Host "[INFO] Returning to home directory."
}
