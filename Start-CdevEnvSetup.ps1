using namespace System.IO
using namespace System.Management.Automation
enum HostOs {
    Windows
    Linux
    MacOS
    UNKNOWN
}
#region    classes
class MinRequirements {
    [int]$FreeMemGB = 1
    [int]$MinDiskGB = 10
    [bool]$RunAsAdmin = $false
    [string[]]$RequiredFiles
    [string[]]$RequiredDirectories
    hidden [string[]]$IgnoredProps = @()
    MinRequirements() {}

    [Ordered] Validate() {
        [string]$OsName = [Setup]::GetHostOs()
        $freeDiskGB = [math]::Round((Get-PSDrive -Name ([IO.Directory]::GetDirectoryRoot((Get-Location)))).Free / 1GB)
        $freRAMsize = $(switch ($OsName) {
                "Windows" {
                    [math]::Round((Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
                    break
                }
                "Linux" {
                    [math]::Round([int64](((& free -b) -split "`n")[1] -split "\s+")[1] / 1GB, 2)
                    break;
                }
                "MacOs" {
                    [math]::Round(((& sysctl hw.memsize) -split ' ')[1] / 1GB, 2)
                    break;
                }
                Default { throw "Unable to read memory size for OS: $OsName" }
            }
        )
        $h = @{
            HasEnoughRAM          = $freRAMsize -ge $this.FreeMemGB
            HasEnoughDiskSpace    = $freeDiskGB -ge $this.MinDiskGB
            HasAdminPrivileges    = $this.RunAsAdmin -and [Setup]::IsAdmin()
            HasAllRequiredFiles   = ($this.RequiredFiles -as [IO.FileInfo[]]).Where({ ![IO.File]::Exists($_.FullName) }).count -eq 0
            HasAllRequiredFolders = ($this.RequiredDirectories -as [IO.DirectoryInfo[]]).Where({ ![IO.Directory]::Exists($_.FullName) }).count -eq 0
        }
        Write-Verbose -Message $("Checking install requirements ...`n{0}" -f (New-Object PsObject -Property $h | Out-String).TrimEnd())
        $r = [Ordered]::new(); $h.Keys.Where({ $_ -notin $this.IgnoredProps }).ForEach({ $r.Add($_, $h[$_]) })
        return $r
    }
}
class InstallReport {
    hidden [string]$Title
    InstallReport ([string]$Title, [hashtable]$table) {
        $this.Title = $Title; $this.SetObjects($table)
    }
    hidden [void] SetObjects([hashtable]$table) {
        $dict = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $table.Keys.ForEach({ [void]$dict.Add($_, $table[$_]) }); $this.SetObjects($dict)
    }
    [void] SetObjects([System.Collections.Generic.Dictionary[string, string]]$dict) {
        $dict.Keys.ForEach({ $this.psobject.Properties.Add([PSScriptProperty]::new($_, [scriptblock]::Create("return '$($dict[$_])'"), { throw "$_ is a readonly property" })) })
    }
    [string] ToString() {
        return (" " + $this.Title + "`n" + ($this | Format-List | Out-String))
    }
}

class SetupStep {
    [string]$Name
    [scriptBlock]$Command
    SetupStep([string]$Name) {
        $this.Name = $Name
    }
    SetupStep([string]$Name, [scriptBlock]$Command) {
        $this.Name = $Name
        $this.Command = $Command
    }
    [BackgroundTask] Run([bool]$Async) {
        if ($Async) {
            $msg = "[Bug] Asyncronous job for $($this.Name) is not yet implemented"
            Write-Warning $msg
            return [BackgroundTask]::new($msg)
        } else {
            return [BackgroundTask]::new($(Start-Job -Name $this.Name -ScriptBlock { param([scriptBlock]$Command) return $Command.Invoke() } -ArgumentList $this.Command))
        }
    }
}

class Setup {
    [bool] $RunAsAdmin = $true
    static [HostOs] $HostOs = [Setup]::GetHostOs()
    static [ActionPreference] $OnError = (Get-Variable -Name ErrorActionPreference -ValueOnly)
    [System.Collections.Generic.Queue[SetupStep]]$Steps = @()

    static [BackgroundTask] Invoke([Setup]$setup) {
        return [Setup]::Invoke($setup, $true)
    }
    static [BackgroundTask] Invoke([Setup]$setup, [bool]$RunAsAdmin) {
        $result = [BackgroundTask]::new()
        if (!$setup.CheckRequirements()) { throw "Some minimum Install requirements were not met" }
        foreach ($step in $setup.Steps) {
            [void]$result.Output.Add($step.Run($true))
        }
        return $result
    }
    static [HostOs] GetHostOs() {
        return $(
            if ($(Get-Variable IsWindows -Value)) {
                "Windows"
            } elseif ($(Get-Variable IsLinux -Value)) {
                "Linux"
            } elseif ($(Get-Variable IsMacOS -Value)) {
                "MacOS"
            } else {
                "UNKNOWN"
            }
        )
    }
    static [bool] IsAdmin() {
        [string]$_Host_OS = [Setup]::getHostOs()
        [bool]$Isadmin = $(switch ($true) {
                $($_Host_OS -eq "Windows") {
                    $(New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator);
                    break;
                }
                $($_Host_OS -in ("MacOS", "Linux")) {
                    $(whoami) -eq "root";
                    break;
                }
                Default {
                    Write-Warning "Unknown OS: $_Host_OS";
                    $false
                }
            }
        )
        if (!$Isadmin) { Write-Warning "[USER is not ADMIN]. This script requires administrative privileges." }
        return $Isadmin
    }
    [void] SetSteps([string[]]$methods) {
        $methods.ForEach({ $this.steps.Enqueue([SetupStep]::New($_, [scriptblock]::Create("return [$($this.GetType().Name)]::$_()"))) })
    }
    [InstallReport] GetInstallReport() {
        return [InstallReport]::new("C/C++ development environment setup completed successfully.")
    }
    [bool] CheckRequirements() {
        $InstallReqs = [MinRequirements]::new(); if (!$this.RunAsAdmin) { $InstallReqs.IgnoredProps += "HasAdminPrivileges" }
        return !$InstallReqs.Validate().Values.Contains($false)
    }
}

class BackgroundTask {
    # .EXAMPLE
    #     New-Object BackgroundTask((Start-Job -ScriptBlock { start-sleep -seconds 2; return 100 }))
    [bool]$IsSuccess = $false
    [string]$JobName = [string]::Empty
    [System.Array]$ErrorRecord = @()
    hidden [System.Collections.Generic.List[String]]$Commands = @()
    [PSDataCollection[psobject]]$Output = [PSDataCollection[psobject]]::new()
    BackgroundTask() { $this.SetJobState() }
    BackgroundTask($InputObject) {
        $t = [BackgroundTask]::Create($InputObject)
        $this.PSObject.Properties.Name.ForEach({ $this."$_" = $t."$_" }); $this.SetJobState()
    }
    BackgroundTask($InputObject, [ErrorRecord]$ErrorRecord) {
        $t = [BackgroundTask]::Create($InputObject, $ErrorRecord)
        $this.PSObject.Properties.Name.ForEach({ $this."$_" = $t."$_" }); $this.SetJobState()
    }
    BackgroundTask($InputObject, [bool]$IsSuccess, [ErrorRecord]$ErrorRecord) {
        $t = [BackgroundTask]::Create($InputObject, $IsSuccess, $ErrorRecord)
        $this.PSObject.Properties.Name.ForEach({ $this."$_" = $t."$_" }); $this.SetJobState()
    }
    static [BackgroundTask] Create($InputObject) {
        if ($InputObject -is [array]) {
            Write-Verbose "InputObject is an array"
            $_Params = [hashtable]::new()
            $_Params.IsSuccess = $InputObject.Where({ $_ -is [bool] });
            $_Params.ErrorRecord = $InputObject.Where({ $_ -is [ErrorRecord] });
            $_Params.InputObject = $InputObject[0];
            return [BackgroundTask]::Create($_Params.InputObject, $_Params.IsSuccess, $_Params.ErrorRecord)
        }
        return [BackgroundTask]::Create($InputObject, $false, $null)
    }
    static [BackgroundTask] Create($InputObject, [ErrorRecord]$ErrorRecord) {
        return [BackgroundTask]::Create($InputObject, $false, $ErrorRecord)
    }
    static [BackgroundTask] Create($InputObject, [bool]$IsSuccess, [ErrorRecord]$ErrorRecord) {
        $tresult = [BackgroundTask]::new(); $err = $null; if ($null -eq $InputObject) { $InputObject = [PSObject]::new() }
        if ($null -ne $ErrorRecord) { $tresult.ErrorRecord += $ErrorRecord };
        if ($InputObject -is [job]) {
            $tresult.JobName = $InputObject.Name;
            $tresult.Commands.Add($InputObject.Command) | Out-Null
            $InputObject = $InputObject.ChildJobs | Receive-Job -Wait -ErrorAction SilentlyContinue -ErrorVariable Err
            $tresult.IsSuccess = $null -eq $Err; if (!$tresult.IsSuccess) { $tresult.ErrorRecord += $err }
            if ($InputObject -is [bool]) { $tresult.IsSuccess = $InputObject }
        }
        $tresult.Output.Add($InputObject) | Out-Null
        $tresult.SetJobState()
        $tresult.IsSuccess = $tresult.ErrorRecord.Count -eq 0 -and $($tresult.State -ne "Failed")
        return $tresult
    }
    [void] SetJobState() {
        $this.PsObject.Properties.Add([psscriptproperty]::new('State', { return $(switch ($true) { $(![string]::IsNullOrWhiteSpace($this.JobName)) { $(Get-Job -Name $this.JobName).State.ToString(); break } $($this.IsSuccess) { "Completed"; break } Default { "Failed" } }) }, { throw [System.InvalidOperationException]::new("Cannot set State") }))
    }
}

class CboxSetup : Setup {
    [bool]$UseCloudVps = $false
    CboxSetup() {
        $this.SetSteps(@(
                "CheckRequirements",
                "InstallChoco",
                "InstallMSYS2",
                "InstallGcc",
                "InstallClang",
                "InstallCMake",
                "PrepareVisualStudioCode",
                "InstallGoogleTestPackage",
                "InstallDoxygen",
                "InstallGit"
            )
        )
    }
    [BackgroundTask] Invoke() {
        if ($this.UseCloudVps -and $this.RunAsAdmin) {
            throw [System.InvalidOperationException]::new("Cannot run as admin on a cloud VPS")
        }
        return [CboxSetup]::Invoke($this, $this.RunAsAdmin)
    }
    static [void] InstallChoco() {
        # Install Chocolatey package manager
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    }
    static [void] InstallMSYS2() {
        # Install MSYS2
        choco install msys2 --params = "/NoUpdate" -y

        # Add MSYS2 binaries to system PATH
        $msys2BinPath = Join-Path $env:ChocolateyInstall "lib\msys2\mingw64\bin"
        $env:Path += ";$msys2BinPath"
        [Environment]::SetEnvironmentVariable("Path", $env:Path, [System.EnvironmentVariableTarget]::Machine)
    }
    static [void] InstallGcc() {
        # Install GCC and related tools
        & "$env:ChocolateyInstall\lib\msys2\tools\msys2.exe" -c "/usr/bin/bash -lc 'pacman -Syu --noconfirm'" | Out-Null
        & "$env:ChocolateyInstall\lib\msys2\tools\msys2.exe" -c "/usr/bin/bash -lc 'pacman -S --needed --noconfirm mingw-w64-x86_64-gcc mingw-w64-x86_64-make mingw-w64-x86_64-gdb'" | Out-Null
    }
    static [void] InstallClang() {
        # Install Clang
        & "$env:ChocolateyInstall\lib\msys2\tools\msys2.exe" -c "/usr/bin/bash -lc 'pacman -S --needed --noconfirm mingw-w64-x86_64-clang mingw-w64-x86_64-clang-tools-extra'" | Out-Null
    }
    static [void] InstallCMake() {
        # Install CMake
        choco install cmake --install-arguments = 'ADD_CMAKE_TO_PATH=System' -y
    }
    static [void] PrepareVisualStudioCode() {
        choco install vscode -y
        # Install C/C++ extension for VSCode
        code --install-extension ms-vscode.cpptools

        # Install CMake Tools extension for VSCode
        code --install-extension ms-vscode.cmake-tools
    }
    static [void] InstallGoogleTestPackage() {
        # Install Google Test package
        choco install vcpkg -y
        & "$env:ChocolateyInstall\lib\vcpkg\tools\vcpkg.exe" integrate install
        & "$env:ChocolateyInstall\lib\vcpkg\tools\vcpkg.exe" install gtest:x64-windows
    }
    static [void] InstallDoxygen() {
        choco install doxygen.install -y
    }
    static [void] InstallGit() {
        choco install git -y
    }
    static [bool] CheckRequirements() {
        # Checking if certain software or tools are installed by checking their install file paths:
        $FilesTocheck = @()
        $FilesTocheck += [FileInfo]::new("$env:ChocolateyInstall\bin\choco.exe")
        $FilesTocheck += [FileInfo]::new("$env:ChocolateyInstall\lib\msys2\tools\msys2.exe")

        $DirectoriesTocheck = @()
        $DirectoriesTocheck += [DirectoryInfo]::new("$env:ChocolateyInstall\bin")
        $DirectoriesTocheck += [DirectoryInfo]::new("$env:ChocolateyInstall\lib\msys2\tools")
        return [CboxSetup]::CheckRequirements($FilesTocheck, $DirectoriesTocheck)
    }
}
#endregion classes

function Start-CdevEnvSetup {
    # .SYNOPSIS
    #     Initializes the C/C++ development environment.
    # .EXAMPLE
    #     Start-CdevEnvSetup
    # .NOTES
    #     Make sure to run this function with administrative privileges if required by your setup.
    [CmdletBinding()]
    param ()
    begin {
        $outpt = $null
        $setup = [CboxSetup]::new()
        [CboxSetup]::OnError = [ActionPreference]::Stop
    }
    process {
        $outpt = $setup.Invoke()
    }
    end {
        return $outpt
    }
}

# Export-ModuleMember -Function 'Start-CdevEnvSetup' -Variable '*' -Cmdlet '*' -Alias '*' -Verbose:$false