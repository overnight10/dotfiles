#Requires -RunAsAdministrator

$user = "overnight10"
$repository = "dotfiles"
$branch = "windows"
$backupDir = "~\.backup"

$links = @(
    @{ Source = "~\.config"; Target = "$repository\.config" },
    @{ Source = "~\AppData\Roaming\nushell"; Target = "~\.config\nushell" },
    @{ Source = "~\AppData\Roaming\helix"; Target = "~\.config\helix" },
    @{ Source = "~\scoop\persist\windows-terminal-preview\settings"; Target = "~\.config\terminal" },
    @{ Source = "~\scoop\persist\btop-lhm\themes"; Target = "~\.config\btop\themes" },
    @{ Source = "~\scoop\apps\btop-lhm\current\btop.conf"; Target = "~\.config\btop\btop.conf" }
)

$preserve = @(
    "~\.config\nushell\history.txt"
)

function yes_or_no {
    param (
        [Parameter(Mandatory = $true)] [string] $title,
        [Parameter(Mandatory = $true)] [string] $question
    )
    $choices = @(
        [System.Management.Automation.Host.ChoiceDescription]::new("&Yes", "Answer yes to $question."),
        [System.Management.Automation.Host.ChoiceDescription]::new("&No", "Answer no to $question.")
    )
    $decision = $Host.UI.PromptForChoice($title, $question, $choices, 0)
    return $decision -eq 0
}

function create_symlink (
    [Parameter(Mandatory = $true)]
    [string] $source,
    [Parameter(Mandatory = $true)]
    [string] $target
) {
    # if source doesn't exist or target doesn't exist, skip
    if (!(Test-Path -Path $source) -or !(Test-Path -Path $target)) {
        return
    }
    # check if it has a symlink
    if ((Get-Item -Path $link.Source).LinkType -eq 'SymbolicLink') {
        # if it is the same, skip
        if ((Get-Item -Path $link.Source).Target -eq $link.Target) {
            return
        }  
        # if it is different, remove it
        Remove-Item -Force -Path $link.Source
        Write-Host "🗑️ Symlink removed: $($link.Source) -> $($link.Target)"
    }

    try {
        # create the symlink
        New-Item -ItemType SymbolicLink -Path $link.Source -Target $link.Target -Force -Confirm:$false | Out-Null
        Write-Host "🔗 Symlink created: $($link.Source) -> $($link.Target)"
    }
    catch {
        Write-Host "📛 Failed to create symlink: $($link.Source) -> $($link.Target)" -ForegroundColor Red
    }
}

function preserve_file {
    param (
        [Parameter(Mandatory = $true)]
        [string] $file,
        [Parameter(Mandatory = $true)]
        [string] $backupDir
    )
    if (!(Test-Path -Path $file)) {
        return
    }
    # I assume that the backup directory exists
    # copy the file to the backup directory
    Copy-Item -Path $file -Destination $backupDir -Force -Confirm:$false
    Write-Host "📄 File preserved: $($file) -> $($backupDir)"
}

function restore_file {
    param (
        [Parameter(Mandatory = $true)]
        [string] $file,
        [Parameter(Mandatory = $true)]
        [string] $backupDir
    )
    if (!(Test-Path -Path $file)) {
        return
    }
    # I assume that the backup directory exists
    # copy the file to the backup directory
    Copy-Item -Path $backupDir -Destination $file -Force -Confirm:$false
    Write-Host "📄 File restored: $($file) -> $($backupDir)"
}

function handle_local_dotfiles {
    # backup the local dotfiles
    Write-Host "📦 Backing up local dotfiles..."
    foreach ($link in $links) {
        preserve_file -file $link.Source -backupDir $backupDir
    }

    $relink = yes_or_no -title "Update symlinks" -question "Do you want it?"
    if (!($relink)) {
        Write-Host "🐈 Ok, I'll pass."
        return
    }

    # create symlinks
    Write-Host "🔗 Creating symlinks..."
    foreach ($link in $links) {
        create_symlink -source $link.Source -target $link.Target
    }
    # restore the local dotfiles
    Write-Host "📦 Restoring local dotfiles..."
    foreach ($link in $links) {
        restore_file -file $link.Source -backupDir $backupDir
    }
    # remove the backup directory
    Write-Host "🗑️ Removing backup directory..."
    Remove-Item -Force -Path $backupDir

    # done
    Write-Host "🎉 Done!"
}

function handle_remote_dotfiles {
    # backup the local dotfiles
    Write-Host "📦 Backing up local files..."
    foreach ($file in $preserve) {
        preserve_file -file $file -backupDir $backupDir
    }

    $clonned = try_clone_repo
    if (!$clonned) {
        Set-Location ~
        return
    }

    # create symlinks
    Write-Host "🔗 Creating symlinks..."
    foreach ($link in $links) {
        create_symlink -source $link.Source -target $link.Target
    }
    # restore the local dotfiles
    Write-Host "📦 Restoring local files..."
    foreach ($file in $preserve) {
        restore_file -file $file -backupDir $backupDir
    }

    # remove the backup directory
    Write-Host "🗑️ Removing backup directory..."
    Remove-Item -Force -Path $backupDir
    # done
    Set-Location ~
    Write-Host "🎉 Done!"
}

funtion try_clone_repo {
    # check if git is installed
    if (!(which git)) {
        $decision = yes_or_no -title "Git not installed" -question "Do you want to install git via scoop?"
        if ($decision -eq $true) {
            scoop install git
        }
        Write-Host "🐈 Hey, I can't do that for you. Exiting..."
        Set-Location ~
        return false
    }

    # at this point, I will asume that you want to clone the repository
    # check if the repository exists
    Write-Host "🐱 Cloning repository..."
    git clone "https://github.com/$user/$repository.git" -b $branch $repository
    if ($LASTEXITCODE -ne 0) {
        Write-Host "📛 Failed to clone repository: $($repository)" -ForegroundColor Red
        return false
    }

    return true
}

function try_install_scoop {
    # check if git is installed
    if (!(which scoop)) {
        $decision = yes_or_no -title "Scoop not installed" -question "Do you want to install scoop?"
        if ($decision -eq $true) {
            Invoke-Expression "& {$(Invoke-RestMethod get.scoop.sh)} -RunAsAdmin"
        }
        Write-Host "🐈 Hey, I can't do that for you. Exiting..."
        Set-Location ~
        return 
    }
    Write-Host "🐱 Scoop is installed!"
    # So we can use remote scoop.json (contains apps and buckets)
    # Or we can use local scoop.json (contains apps and buckets)
    $continue = yes_or_no -title "Apps and buckets" -question "Do you want to use remote scoop.json?"
    if (!($continue)) {
        Write-Host "🐈 Ok, I'll pass."
        return
    }
    $outputFile = Join-Path -Path $pwd -ChildPath "scoop.json"
    # use remote scoop.json, overwrite local scoop.json
    Write-Host "📦 Fetching scoop.json from repository"
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$user/$repository/$branch/assets/scoop.json" -OutFile $outputFile
    # before to import, we need to add all buckets
    # otherwise, scoop will fail to import
    $buckets = Get-Content -Path $outputFile | ConvertFrom-Json | Select-Object -ExpandProperty buckets | Select-Object -ExpandProperty Name
    foreach ($bucket in $buckets) {
        scoop bucket add $bucket
    }
    scoop import $outputFile
    Write-Host "📦 Scoop packages installed!"
}

function main {
    Set-Location ~  # Go to the user's home directory

    # Create temporary directory for scoop.json
    $tempDir = Join-Path -Path $pwd -ChildPath ".temp-dotfiles"
    mkdir -Force $tempDir | Out-Null
    Set-Location $tempDir

    # Check if Scoop is installed
    try_install_scoop
    
    # check if local dotfiles exist
    if (Test-Path -Path $repository) {
        $overwrite = yes_or_no -title "Local dotfiles exist" -question "Do you want to overwrite the existing dotfiles?"
        if (!($overwrite)) {
            handle_local_dotfiles
        }
        Set-Location ~
        Write-Host "🐈 Ok, nothing to do."
        return
    }

    handle_remote_dotfiles
}

try {
    main
}
catch {
    Write-Host "📛 Failed to install dotfiles: $($_.Exception.Message)" -ForegroundColor Red
    Set-Location ~
    exit 1
}