#Requires -RunAsAdministrator

$user = "overnight10"
$repository = "dotfiles"
$branch = "windows"
$backupDir = "~\.backup"
$tempDir = Join-Path -Path $pwd -ChildPath ".temp-dotfiles"

$receipts = @(
    $backupDir
    $tempDir
    '~\.config'
    '~\.config\scoop'
    '~\AppData'
    '~\AppData\Roaming'
    '~\AppData\Roaming\nushell'
    '~\AppData\Roaming\helix'
    '~\scoop'
)

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

function which {
    param (
        [Parameter(Mandatory = $true)] [string] $program
    )
    $path = Get-Command -Name $program -CommandType Application -ErrorAction SilentlyContinue
    return $null -ne $path
}

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
    if (!(Test-Path -Path $source) -or !(Test-Path -Path $target)) {
        return
    }
    
    if ((Get-Item -Path $source).LinkType -eq 'SymbolicLink') {
        if ((Get-Item -Path $source).Target -eq $target) {
            return
        }  
        Remove-Item -Force -Path $source
        Write-Host "`u{1F5D1}`u{FE0F} Symlink removed: $source -> $target"
    }

    try {
        New-Item -ItemType SymbolicLink -Path $source -Target $target -Force -Confirm:$false | Out-Null
        Write-Host "`u{1F517} Symlink created: $source -> $target"
    }
    catch {
        Write-Output "`u{1F4DB} Failed to create symlink: $source -> $target"
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
    Copy-Item -Path $file -Destination $backupDir -Force -Confirm:$false
    Write-Host "`u{1F4C4} File preserved: $($file) -> $($backupDir)"
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
    Copy-Item -Path $backupDir -Destination $file -Force -Confirm:$false
    Write-Host "`u{1F4C4} File restored: $($file) -> $($backupDir)"
}

function try_clone_repo {
    if (!(which git)) {
        $decision = yes_or_no -title "Git not installed" -question "Do you want to install git via scoop?"
        if ($decision) {
            scoop install git
        }
        Write-Host "`u{1F408} Hey, I can't do that for you. Exiting..."
        Set-Location ~
        return $false
    }

    # remove the repository directory if it exists
    if (Test-Path -Path $repository) {
        Remove-Item -Force -Path $repository -Recurse
        Write-Host "`u{1F5D1}`u{FE0F} Removed existing repository: $repository"
    }

    Write-Host "`u{1F431} Cloning repository..."
    git clone "https://github.com/$user/$repository.git" -b $branch $repository
    if (!(Test-Path -Path $repository)) {
        Write-Host "`u{1F4DB} Failed to clone repository: $repository"
        return $false
    }

    return $true
}

function handle_local_dotfiles {
    Write-Host "`u{1F4E6} Backing up local dotfiles..."
    foreach ($link in $links) {
        preserve_file -file $link.Source -backupDir $backupDir
    }

    $relink = yes_or_no -title "Update symlinks" -question "Do you want it?"
    if (!($relink)) {
        Write-Host "`u{1F408} Ok, I'll pass."
        return
    }

    Write-Host "`u{1F517} Creating symlinks..."
    foreach ($link in $links) {
        create_symlink -source $link.Source -target $link.Target
    }
    Write-Host "`u{1F4E6} Restoring local dotfiles..."
    foreach ($link in $links) {
        restore_file -file $link.Source -backupDir $backupDir
    }
}

function handle_remote_dotfiles {
    Write-Host "`u{1F4E6} Backing up local files..."
    foreach ($file in $preserve) {
        preserve_file -file $file -backupDir $backupDir
    }

    $clonned = try_clone_repo
    if (!$clonned) {
        Set-Location ~
        return
    }

    Write-Host "`u{1F517} Creating symlinks..."
    foreach ($link in $links) {
        create_symlink -source $link.Source -target $link.Target
    }
    Write-Host "`u{1F4E6} Restoring local files..."
    foreach ($file in $preserve) {
        restore_file -file $file -backupDir $backupDir
    }
}

function try_install_scoop {
    if (!(which scoop)) {
        $decision = yes_or_no -title "Scoop not installed" -question "Do you want to install scoop?"
        if ($decision) {
            Invoke-RestMethod 'get.scoop.sh' | Invoke-Expression
        }
        Write-Host "`u{1F408} Hey, I can't do that for you. Exiting..."
        Set-Location ~
        return $false
    }
    Write-Host "`u{1F431} Scoop is installed!"
    $continue = yes_or_no -title "Apps and buckets" -question "Do you want to use remote scoop.json?"
    if (!($continue)) {
        Write-Host "`u{1F408} Ok, I'll pass."
        return $true
    }
    $outputFile = Join-Path -Path $pwd -ChildPath "scoop.json"
    Write-Host "`u{1F4E6} Fetching scoop.json from repository"
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$user/$repository/$branch/assets/scoop.json" -OutFile $outputFile
    $buckets = Get-Content -Path $outputFile | ConvertFrom-Json | Select-Object -ExpandProperty buckets | Select-Object -ExpandProperty Name
    foreach ($bucket in $buckets) {
        scoop bucket add $bucket
    }
    scoop import $outputFile
    Write-Host "`u{1F4E6} Scoop packages installed!"
    return $true
}

function create_receipt {
    param (
        [Parameter(Mandatory = $true)]
        [string] $receip
    )
    if ((Test-Path -Path $receip)) {
        Write-Host "`u{1F4C1} Directory already exists: $receip"
        return
    }
    New-Item -ItemType Directory -Path $receip -Force | Out-Null
    Write-Host "`u{1F4C1} Created directory: $receip"
}

function main {
    Set-Location ~
    foreach ($receipt in $receipts) {
        create_receipt $receipt
    }

    $scoopInstalled = try_install_scoop
    if (!$scoopInstalled) {
        Set-Location ~
        Write-Host "`u{1F408} I cannot proceed without Scoop. Exiting..."
        return
    }
    
    if (Test-Path -Path $repository) {
        $overwrite = yes_or_no -title "Local dotfiles exist" -question "Do you want to overwrite the existing dotfiles?"
        if (!($overwrite)) {
            handle_local_dotfiles
            return
        }
    }

    handle_remote_dotfiles
}

try {
    main
}
catch {
    Write-Output "`u{1F4DB} Failed to install dotfiles: $($_.Exception.Message)"
} finally {
    Write-Host "`u{1F9F9} Cleaning up..."
    Remove-Item -Force -Path $tempDir
    Remove-Item -Force -Path $backupDir
    Set-Location ~
    Write-Host "Done"
}
