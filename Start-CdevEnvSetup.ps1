using namespace System.IO
using namespace System.Collections.Generic
using namespace System.Management.Automation

# .SYNOPSIS
# BackJobs.psm1 Contains classes & functions to help with Background jobs


class cli {
    static hidden [ValidateNotNull()][string]$Preffix # .EXAMPLE Try this: # [cli]::Preffix = '@:'; [void][cli]::Write('animations and stuff', [ConsoleColor]::Magenta)
    static hidden [ValidateNotNull()][scriptblock]$textValidator # ex: if $text does not match a regex throw 'erro~ ..'
    static [string] write([string]$text) {
        return [cli]::Write($text, 20, 1200)
    }
    static [string] Write([string]$text, [bool]$AddPreffix) {
        return [cli]::Write($text, 20, 1200, $AddPreffix)
    }
    static [string] Write([string]$text, [int]$Speed, [int]$Duration) {
        return [cli]::Write($text, 20, 1200, $true)
    }
    static [string] write([string]$text, [ConsoleColor]$color) {
        return [cli]::Write($text, $color, $true)
    }
    static [string] write([string]$text, [ConsoleColor]$color, [bool]$Animate) {
        return [cli]::Write($text, [cli]::Preffix, 20, 1200, $color, $Animate, $true)
    }
    static [string] write([string]$text, [int]$Speed, [int]$Duration, [bool]$AddPreffix) {
        return [cli]::Write($text, [cli]::Preffix, $Speed, $Duration, [ConsoleColor]::White, $true, $AddPreffix)
    }
    static [string] write([string]$text, [ConsoleColor]$color, [bool]$Animate, [bool]$AddPreffix) {
        return [cli]::Write($text, [cli]::Preffix, 20, 1200, $color, $Animate, $AddPreffix)
    }
    static [string] write([string]$text, [string]$Preffix, [System.ConsoleColor]$color) {
        return [cli]::Write($text, $Preffix, $color, $true)
    }
    static [string] write([string]$text, [string]$Preffix, [System.ConsoleColor]$color, [bool]$Animate) {
        return [cli]::Write($text, $Preffix, 20, 1200, $color, $Animate, $true)
    }
    static [string] write([string]$text, [string]$Preffix, [int]$Speed, [int]$Duration, [bool]$AddPreffix) {
        return [cli]::Write($text, $Preffix, $Speed, $Duration, [ConsoleColor]::White, $true, $AddPreffix)
    }
    static [string] write([string]$text, [string]$Preffix, [int]$Speed, [int]$Duration, [ConsoleColor]$color, [bool]$Animate, [bool]$AddPreffix) {
        return [cli]::Write($text, $Preffix, $Speed, $Duration, $color, $Animate, $AddPreffix, [cli]::textValidator)
    }
    static [string] write([string]$text, [string]$Preffix, [int]$Speed, [int]$Duration, [ConsoleColor]$color, [bool]$Animate, [bool]$AddPreffix, [scriptblock]$textValidator) {
        if ($null -ne $textValidator) {
            $textValidator.Invoke($text)
        }
        if ([string]::IsNullOrWhiteSpace($text)) {
            return $text
        }
        [int]$length = $text.Length; $delay = 0
        # Check if delay time is required:
        $delayIsRequired = if ($length -lt 50) { $false } else { $delay = $Duration - $length * $Speed; $delay -gt 0 }
        if ($AddPreffix -and ![string]::IsNullOrEmpty($Preffix)) {
            [void][cli]::Write($Preffix, [string]::Empty, 1, 100, [ConsoleColor]::Green, $false, $false);
        }
        $FgColr = [Console]::ForegroundColor
        [Console]::ForegroundColor = $color
        if ($Animate) {
            for ($i = 0; $i -lt $length; $i++) {
                [void][Console]::Write($text[$i]);
                Start-Sleep -Milliseconds $Speed;
            }
        } else {
            [void][Console]::Write($text);
        }
        if ($delayIsRequired) {
            Start-Sleep -Milliseconds $delay
        }
        [Console]::ForegroundColor = $FgColr
        return $text
    }
}

# .SYNOPSIS
#     A class to convert dot ascii arts to b64string & vice versa
# .DESCRIPTION
#     Cli art created from sites like https://lachlanarthur.github.io/Braille-ASCII-Art/ can only be embeded as b64 string
#     So this class helps speed up the conversion process
# .EXAMPLE
#     $b64str = [cliart]::ToBase64String((Get-Item ./ascii))
#     [CliArt]::FromBase64String($b64str) | Write-Host -f Green
class CliArt {
    hidden [string]$Base64String
    CliArt([byte[]]$ArtBytes) {
        $this.Base64String = [CliArt]::ToBase64String($ArtBytes)
    }
    CliArt([IO.FileInfo]$Artfile) {
        $this.Base64String = [CliArt]::ToBase64String($Artfile)
    }
    CliArt([string]$Base64String) {
        $this.Base64String = $Base64String
    }
    static [string] ToBase64String([byte[]]$ArtBytes) {
        return [convert]::ToBase64String((xconvert)::ToCompressed([System.Text.Encoding]::UTF8.GetBytes((Base85)::Encode($ArtBytes))))
    }
    static [string] ToBase64String([IO.FileInfo]$Artfile) {
        return [CliArt]::ToBase64String([IO.File]::ReadAllBytes($Artfile.FullName))
    }
    static [string] FromBase64String([string]$B64String) {
        return [System.Text.Encoding]::UTF8.GetString((Base85)::Decode([System.Text.Encoding]::UTF8.GetString((xconvert)::ToDeCompressed([convert]::FromBase64String($B64String)))))
    }
    [string] ToString() {
        return [CliArt]::FromBase64String($this.Base64String)
    }
}

# .SYNOPSIS
# A simple progress utility class
# .EXAMPLE
# $OgForeground = (Get-Variable host).Value.UI.RawUI.ForegroundColor
# (Get-Variable host).Value.UI.RawUI.ForegroundColor = [ConsoleColor]::Green
# for ($i = 0; $i -le 100; $i++) {
#     [ProgressUtil]::WriteProgressBar($i)
#     [System.Threading.Thread]::Sleep(50)
# }
# (Get-Variable host).Value.UI.RawUI.ForegroundColor = $OgForeground
# Wait-Task "Waiting" { Start-Sleep -Seconds 3 }
#
class ProgressUtil {
    static hidden [string] $_block = '■';
    static hidden [string] $_back = "`b";
    static hidden [string[]] $_twirl = @(
        "-\\|/", "|/-\\", "+■0"
    );
    static [string] $AttemptMSg
    static [int] $_twirlIndex = 0
    static hidden [string]$frames
    static [void] WriteProgressBar([int]$percent) {
        [ProgressUtil]::WriteProgressBar($percent, $true)
    }
    static [void] WriteProgressBar([int]$percent, [bool]$update) {
        [ProgressUtil]::WriteProgressBar($percent, $update, [int]([Console]::WindowWidth * 0.7))
    }
    static [void] WriteProgressBar([int]$percent, [bool]$update, [int]$PBLength) {
        [ValidateNotNull()][int]$PBLength = $PBLength
        [ValidateNotNull()][int]$percent = $percent
        [ValidateNotNull()][bool]$update = $update
        [ProgressUtil]::_back = "`b" * [Console]::WindowWidth
        if ($update) { [Console]::Write([ProgressUtil]::_back) }
        [Console]::Write("["); $p = [int](($percent / 100.0) * $PBLength + 0.5)
        for ($i = 0; $i -lt $PBLength; $i++) {
            if ($i -ge $p) {
                [Console]::Write(' ');
            } else {
                [Console]::Write([ProgressUtil]::_block);
            }
        }
        [Console]::Write("] {0,3:##0}%", $percent);
    }
}

class StackTracer {
    static [System.Collections.Concurrent.ConcurrentStack[string]]$stack = [System.Collections.Concurrent.ConcurrentStack[string]]::new()
    static [System.Collections.Generic.List[hashtable]]$CallLog = @()
    static [void] Push([string]$class) {
        $str = "[{0}]" -f $class
        if ([StackTracer]::Peek() -ne "$class") {
            [StackTracer]::stack.Push($str)
            $LAST_ERROR = $(Get-Variable -Name Error -ValueOnly)[0]
            [StackTracer]::CallLog.Add(@{ ($str + ' @ ' + [datetime]::Now.ToShortTimeString()) = $(if ($null -ne $LAST_ERROR) { $LAST_ERROR.ScriptStackTrace } else { [System.Environment]::StackTrace }).Split("`n").Replace("at ", "# ").Trim() })
        }
    }
    static [type] Pop() {
        $result = $null
        if ([StackTracer]::stack.TryPop([ref]$result)) {
            return $result
        } else {
            throw [System.InvalidOperationException]::new("Stack is empty!")
        }
    }
    static [string] Peek() {
        $result = $null
        if ([StackTracer]::stack.TryPeek([ref]$result)) {
            return $result
        } else {
            return [string]::Empty
        }
    }
    static [int] GetSize() {
        return [StackTracer]::stack.Count
    }
    static [bool] IsEmpty() {
        return [StackTracer]::stack.IsEmpty
    }
}

#region    cboxclasses
enum HostOs {
    Windows
    Linux
    MacOS
    UNKNOWN
}

enum NeovimTemplate {
    AstroNvim  # A well-structured Neovim config: https://astronvim.com
    Kickstart  # A minimal Neovim config to get started quickly. https://github.com/nvim-lua/kickstart.nvim
    LunarVim   # An IDE layer for Neovim: https://github.com/LunarVim/LunarVim
    SpaceVim   # https://spacevim.org/
    LazyVim    # Neovim config for the lazy: https://github.com/LazyVim/LazyVim
    NvChad     # Blazing fast Neovim setup: https://github.com/NvChad/NvChad
    Basic      # Minimal Neovim Config: https://github.com/NvChad/basic-config.nvim
    Noot       # Modern Neovim Config: https://github.com/shortcuts/noot.nvim
}

enum CmdType {
    Script
    Cmdlet
    Function
    Application
}

class Runner {
    # Execute commands on host
    # Supports sync&asynchronous operation
    static [object[]]$Commands = (Get-Command -Type All)
    Runner() {}

    [void] Run([string]$Command, [Parameter[]]$Params, [object[]]$Data, [string]$ParameterSetName) {
        $Threads = @(); [int]$ThreadCount = 10; [int]$Count = 0
        $Length = $JobsLeft = $Data.Count
        if ($Length -lt $ThreadCount) { $ThreadCount = $Length }
        $timer = (1..$ThreadCount).ForEach({ $null })
        $Jobs = (1..$ThreadCount).ForEach({ $null })
        $CmdType = [Runner]::GetCommandType($Command)
        $t = $CmdType.ToString()
        if ($t -eq 'Cmdlet') {
            1..$ThreadCount | ForEach-Object { $Threads += [powershell]::Create().AddCommand($Cmdlet) }
        } else {
            $ScriptBlock = $(switch ($t) {
                    'Script' { $Command -as [ScriptBlock]; break }
                    'Function' { $(Get-Item Function:/$Command).ScriptBlock; break }
                    'Application' { [scriptblock]::Create("return &$Command"); break }
                    Default { throw 'Could Not resolve command type' }
                }
            )
            1..$ThreadCount | ForEach-Object { $Threads += [powershell]::Create().AddScript($ScriptBlock) }
        }
        if ($Params) { $Threads | ForEach-Object { $_.AddParameters($Params) | Out-Null } }
        while ($JobsLeft) {
            for ($idx = 0; $idx -le ($ThreadCount - 1) ; $idx++) {
                $SetParamObj = $Threads[$idx].Commands.Commands[0].Parameters | Where-Object { $_.Name -eq $ParameterSetName }
                If ($Jobs[$idx].IsCompleted) {
                    #job ran ok, clear it out
                    $result = $null
                    if ($threads[$idx].InvocationStateInfo.State -eq "Failed") {
                        $result = $Threads[$idx].InvocationStateInfo.Reason
                        Write-Error "Set Item: $($SetParamObj.Value) Exception: $result"
                    } else {
                        $result = $Threads[$idx].EndInvoke($Jobs[$idx])
                    }
                    $ts = New-TimeSpan -Start $timer[$idx] -End ([datetime]::Now)
                    [PSCustomObject]@{
                        Output   = $result
                        TimeSpan = $ts
                        SetItem  = $SetParamObj.Value
                    }
                    $Jobs[$idx] = $null
                    $JobsLeft--
                    Write-Verbose "Completed: $($SetParamObj.Value) in $ts"
                    Write-Progress -Activity "Processing Batch" -Status "$JobsLeft jobs left" -PercentComplete (($length - $jobsleft) / $length * 100) -Id 2 -ParentId 1
                }
                if (($Count -lt $Length) -and ($null -eq $Jobs[$idx])) {
                    # Add job if there is more to process
                    Write-Verbose "starting: $($Data[$Count])"
                    $timer[$idx] = Get-Date
                    $Threads[$idx].Commands.Commands[0].Parameters.Remove($SetParamObj) | Out-Null # Check for success?
                    $Threads[$idx].AddParameter('Param', $Data[$Count]) | Out-Null
                    $Jobs[$idx] = $Threads[$idx].BeginInvoke()
                    $Count++
                }
            }
        }
        $Threads | ForEach-Object { $_.runspace.close(); $_.Dispose() }
    }
    static [CmdType] GetCommandType([string]$Command) {
        if ($Command.StartsWith('{') -and $Command.EndsWith('}')) { return [CmdType]::Script }
        $t = [Runner]::_CommandTypes($Command)
        if ($t -in [enum]::GetNames([CmdType])) {
            return [CmdType]::"$t";
        } elseif ($t -in ('ExternalScript', 'Filter', 'Configuration', 'Alias', 'All')) {
            throw 'Operation Not supported ... (Yet)'
        } else {
            throw "Could not resolve commandType"
        }
    }
    static hidden [System.Management.Automation.CommandTypes] _CommandTypes([string]$Command) {
        $r = [Runner]::Commands.Where({ $_.Name -eq "$Command" })[0]
        if ($null -eq $r) { throw "Could not resolve CommandTypes" }
        if ($r.GetType().Name -eq 'AliasInfo') {
            return [Runner]::Commands.Where({ $_.Name -eq "$($r.ResolvedCommand)" })[0].CommandType
        } else {
            return $r.CommandType
        }
    }
}

class MinRequirements {
    [int]$FreeMemGB = 1
    [int]$MinDiskGB = 10
    [bool]$RunAsAdmin = $false
    [FileInfo[]]$RequiredFiles
    [DirectoryInfo[]]$RequiredDirectories
    hidden [string[]]$IgnoredProps = @()
    MinRequirements() {}
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
    [string]$MethodName
    [string]$Desscription
    [System.Array]$ArgumentList

    SetupStep([string]$Name) {
        $this.MethodName = $Name
    }
    SetupStep([string]$Name, [System.Array]$ArgumentList) {
        $this.MethodName = $Name; $this.ArgumentList = $ArgumentList
    }
    [SetupStep] SetDescription([string]$Desscription) {
        $this.Desscription = $Desscription
        return $this
    }
}

function TaskResult {
    # .EXAMPLE
    #     Start-Job -ScriptBlock { start-sleep -seconds 2; return 100 } | TaskResult
    #     Explanation of the function or its result. You can include multiple examples with additional .EXAMPLE lines
    # .OUTPUTS
    #     TaskResult.Result
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [AllowNull()][Alias('o')]
        $InputObject,

        [Parameter(Mandatory = $false, Position = 1)]
        [Alias('s')][ValidateNotNullOrEmpty()]
        [bool]$IsSuccess = 0,

        [Parameter(Mandatory = $false, Position = 2)]
        [Alias('e')][ValidateNotNullOrEmpty()]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,

        [switch]$Async
    )

    begin {
        class Result {
            # .EXAMPLE
            #     New-Object Result((Start-Job -ScriptBlock { start-sleep -seconds 2; return 100 }))
            [bool]$IsSuccess = $false
            [string]$JobName = [string]::Empty
            [System.Array]$ErrorRecord = @()
            hidden [System.Collections.Generic.List[String]]$Commands = @()
            [PSDataCollection[psobject]]$Output = [PSDataCollection[psobject]]::new()
            Result() { $this.SetJobState() }
            Result($InputObject) {
                $t = [Result]::Create($InputObject)
                $this.PSObject.Properties.Name.ForEach({ $this."$_" = $t."$_" }); $this.SetJobState()
            }
            Result($InputObject, [ErrorRecord]$ErrorRecord) {
                $t = [Result]::Create($InputObject, $ErrorRecord)
                $this.PSObject.Properties.Name.ForEach({ $this."$_" = $t."$_" }); $this.SetJobState()
            }
            Result($InputObject, [bool]$IsSuccess, [ErrorRecord]$ErrorRecord) {
                $t = [Result]::Create($InputObject, $IsSuccess, $ErrorRecord)
                $this.PSObject.Properties.Name.ForEach({ $this."$_" = $t."$_" }); $this.SetJobState()
            }
            static [Result] Create($InputObject) {
                if ($InputObject -is [array]) {
                    Write-Verbose "InputObject is an array"
                    $_Params = [hashtable]::new()
                    $_Params.IsSuccess = $InputObject.Where({ $_ -is [bool] });
                    $_Params.ErrorRecord = $InputObject.Where({ $_ -is [ErrorRecord] });
                    $_Params.InputObject = $InputObject[0];
                    return [Result]::Create($_Params.InputObject, $_Params.IsSuccess, $_Params.ErrorRecord)
                }
                return [Result]::Create($InputObject, $false, $null)
            }
            static [Result] Create($InputObject, [ErrorRecord]$ErrorRecord) {
                return [Result]::Create($InputObject, $false, $ErrorRecord)
            }
            static [Result] Create($InputObject, [bool]$IsSuccess, [ErrorRecord]$ErrorRecord) {
                $tresult = [Result]::new(); $err = $null; if ($null -eq $InputObject) { $InputObject = [PSObject]::new() }
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
        $_BoundParams = [hashtable]$PSCmdlet.MyInvocation.BoundParameters
        if ($InputObject -is [array] -and (!$IsSuccess.IsPresent -and !$ErrorRecord)) {
            $_BoundParams.IsSuccess = $InputObject.Where({ $_ -is [bool] });
            $_BoundParams.ErrorRecord = $InputObject.Where({ $_ -is [System.Management.Automation.ErrorRecord] });
            $_BoundParams.InputObject = $InputObject[0]
        }
        $tresult = [Result]::new()
    }

    process {
        if ($null -eq $InputObject) { $InputObject = New-Object PSObject }
        if ($InputObject -is [job]) {
            $tresult.JobName = $InputObject.Name
            $tresult.Commands.Add($InputObject.Command) | Out-Null
            $_output = $InputObject.ChildJobs | Receive-Job -Wait -ErrorAction SilentlyContinue -ErrorVariable Err
            $_BoundParams.ErrorRecord = $Err; $tresult.IsSuccess = $null -eq $Err
            if ($_output -is [bool]) { $tresult.IsSuccess = $_output }
            $tresult.Output.Add($_output) | Out-Null
        } else {
            [void]$tresult.Output.Add($InputObject);
        }
        $_HasErrors = $null -ne $_BoundParams.ErrorRecord -or $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('ErrorRecord')
        if ($_HasErrors) { $tresult.ErrorRecord = $_BoundParams.ErrorRecord }; $tresult.SetJobState()
        $tresult.IsSuccess = !$_HasErrors -and $($tresult.State -ne "Failed")
    }

    end {
        return $tresult
    }
}


class Setup {
    [string] $Name
    [bool] $RunAsAdmin = $true
    static [HostOs] $HostOs = [Setup]::GetHostOs()
    static [ActionPreference] $OnError = (Get-Variable -Name ErrorActionPreference -ValueOnly)
    [System.Collections.Generic.Queue[SetupStep]]$Steps = @()
    Setup() {}
    [psobject] Run([Setup]$setup) {
        return $this.Run($setup, $true)
    }
    [psobject] Run([SetupStep]$step) {
        return $this.Run($step, $false)
    }
    [psobject] Run([Setup]$setup, [bool]$Async) {
        $result = TaskResult($null)
        $c = 1; $setup.Steps.ForEach({
                Write-Host "STEP   : [$c/$($setup.Steps.Count)] $($_.MethodName) ..." -f Green
                [void]$result.Output.Add($setup.Run($_, $Async))
                $c++
            }
        )
        return $result
    }
    [psobject] Run([SetupStep]$step, [bool]$Async) {
        if ($Async) {
            return $(Start-Job -Name $step.MethodName -ScriptBlock {
                    param($setup, $stp)
                    if (0 -eq $stp.ArgumentList.Count) { return $setup."$($stp.MethodName)"() }
                    return $setup."$($stp.MethodName)"($stp.ArgumentList)
                } -ArgumentList $this, $step
            ) | TaskResult -Async
        } else {
            if (0 -eq $step.ArgumentList.Count) { return $this."$($step.MethodName)"(@()) | TaskResult }
            return $this."$($step.MethodName)"($step.ArgumentList) | TaskResult
        }
    }
    static [Ordered] CheckRequirements([MinRequirements]$InstallReqs) {
        if (!$InstallReqs.RunAsAdmin) { $InstallReqs.IgnoredProps += "HasAdminPrivileges" }
        $o = [PSCustomObject]@{
            HasEnoughRAM          = $InstallReqs.FreeMemGB -le [Setup]::GetfreRAMsize()
            HasEnoughDiskSpace    = $InstallReqs.MinDiskGB -le [math]::Round((Get-PSDrive -Name ([IO.Directory]::GetDirectoryRoot((Get-Location)))).Free / 1GB)
            HasAdminPrivileges    = $InstallReqs.RunAsAdmin -and [Setup]::IsAdmin()
            HasAllRequiredFiles   = $InstallReqs.RequiredFiles.Where({ ![IO.File]::Exists($_.FullName) }).count -eq 0
            HasAllRequiredFolders = $InstallReqs.RequiredDirectories.Where({ ![IO.Directory]::Exists($_.FullName) }).count -eq 0
        }
        $o | Out-String | Write-Host
        $r = [Ordered]::new(); $o.Psobject.Properties.Name.Where({ $_ -notin $InstallReqs.IgnoredProps }).ForEach({ $r.Add($_, $o.$_) })
        return $r
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
        [string]$_Host_OS = [Setup]::GetHostOs()
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
        if (!$Isadmin) { Write-Warning "[USER is not ADMIN]. This step requires administrative privileges." }
        return $Isadmin
    }
    static [int] GetfreRAMsize() {
        [string]$OsName = [Setup]::GetHostOs();
        return $(switch ($OsName) {
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
    }
    hidden [void] SetSteps([PSCustomObject]$InputObj) {
        $InputObj.Psobject.Properties.Name.ForEach({ $this.steps.Enqueue([SetupStep]::New($_, $InputObj.$_)) })
    }
    [InstallReport] GetInstallReport() {
        return [InstallReport]::new("$($this.Name) setup completed successfully.")
    }
}

class CboxSetup : Setup {
    [bool]$UseCloudVps = $false
    [bool]$ThrowOnFailure = $false
    CboxSetup() {
        $this.Name = "C/C++ development environment"
        $this.SetSteps([PSCustomObject]@{
                # Edit the bellow method sequence to change order of execution
                CheckRequirements        = $this.ThrowOnFailure
                InstallChoco             = @()
                InstallMSYS2             = @()
                InstallGcc               = @()
                InstallClang             = @()
                InstallCMake             = @()
                PrepareVisualStudioCode  = @()
                InstallGoogleTestPackage = @()
                InstallDoxygen           = @()
                InstallGit               = @()
            }
        )
    }
    [array] Run() {
        if ($this.UseCloudVps -and $this.RunAsAdmin) {
            throw [System.InvalidOperationException]::new("Cannot run as admin on a cloud VPS")
        }
        Write-Host "SETUP  : [CboxSetup] Starting $($this.Name) ..." -f Blue
        return $this.Run($this, $false)
    }
    [bool] InstallChoco($nptargs) {
        if ([Setup]::GetHostOs() -eq "Windows") {
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        }
        return $?
    }
    [bool] InstallMSYS2($nptargs) {
        if ([Setup]::GetHostOs() -eq "Windows") {
            if (!(Get-Command choco -ErrorAction SilentlyContinue)) { $this.InstallChoco(@()) }
            choco install msys2 --params = "/NoUpdate" -y
            # Add MSYS2 binaries to system PATH
            $msys2BinPath = Join-Path $env:ChocolateyInstall "lib\msys2\mingw64\bin"
            $env:Path += ";$msys2BinPath"
            [Environment]::SetEnvironmentVariable("Path", $env:Path, [System.EnvironmentVariableTarget]::Machine)
        } else {
            Write-Host "         Not implemented yet. SKIPPING..." -f DarkYellow
        }
        return $?
    }
    [bool] InstallGcc($nptargs) {
        # Install GCC and related tools
        if (!(Get-Command gcc -ErrorAction SilentlyContinue)) {
            if ([Setup]::GetHostOs() -eq "Windows") {
                if (!(Get-Command msys2 -ErrorAction SilentlyContinue)) { $this.InstallMSYS2(@()) }
                & "$env:ChocolateyInstall\lib\msys2\tools\msys2.exe" -c "/usr/bin/bash -lc 'pacman -Syu --noconfirm'" | Out-Null
                & "$env:ChocolateyInstall\lib\msys2\tools\msys2.exe" -c "/usr/bin/bash -lc 'pacman -S --needed --noconfirm mingw-w64-x86_64-gcc mingw-w64-x86_64-make mingw-w64-x86_64-gdb'" | Out-Null
            }
        } else {
            Write-Host "         gcc is alredy installed. SKIPPING..." -f DarkYellow
        }
        return $?
    }
    [bool] InstallClang($nptargs) {
        # Install Clang and related tools
        if (!(Get-Command clang -ErrorAction SilentlyContinue)) {
            if ([Setup]::GetHostOs() -eq "Windows") {
                if (!(Get-Command msys2 -ErrorAction SilentlyContinue)) { $this.InstallMSYS2(@()) }
                & "$env:ChocolateyInstall\lib\msys2\tools\msys2.exe" -c "/usr/bin/bash -lc 'pacman -S --needed --noconfirm mingw-w64-x86_64-clang mingw-w64-x86_64-clang-tools-extra'" | Out-Null
            }
        } else {
            Write-Host "         clang is alredy installed. SKIPPING..." -f DarkYellow
        }
        return $?
    }
    [bool] InstallCMake($nptargs) {
        if (!(Get-Command CMake -ErrorAction SilentlyContinue)) {
            if ([Setup]::GetHostOs() -eq "Windows") {
                if (!(Get-Command choco -ErrorAction SilentlyContinue)) { $this.InstallChoco(@()) }
                choco install cmake --install-arguments = 'ADD_CMAKE_TO_PATH=System' -y
            } else {
                Write-Host "         Not implemented yet. SKIPPING..." -f DarkYellow
            }
        } else {
            Write-Host "         CMake is alredy installed. SKIPPING..." -f DarkYellow
        }
        return $?
    }
    [bool] InstallNeovimConfig([psobject[]]$nptargs) {
        $_Params = [PSObject]::new() | Select-Object -Property PLugins, TemplateName
        [psobject]::new() | Select-Object @{l = 'a'; e = { 1222 } }, @{l = ''; e = { 111 } }
        $_Params.PLugins = [string[]]$nptargs.Where({ $_ -like "*.lua" });
        $_Params.TemplateName = [NeovimTemplate[]]$nptargs.Where({ $_ -is [NeovimTemplate] -or $_ -is [string] -and $_ -notin $_Params.PLugins });
        $_Params.TemplateName = $_Params.TemplateName[0]
        return $this.InstallNeovimConfig($_Params.TemplateName, $_Params.PLugins)
    }
    [bool] InstallNeovimConfig([NeovimTemplate]$Template, [string[]]$PLugins) {
        # $requirements = [PSCustomObject]@{
        #     Neovim     = https://wiki.archlinux.org/title/Neovim
        #     Git        = https://git-scm.com/book/en/v2/Getting-Started-Installing-Git
        #     Nerd_Fonts = https://www.nerdfonts.com/
        # }
        "Templates: $Template" | Write-Host -f Yellow
        $PLugins | Out-String | Write-Host -f Yellow
        return $?
    }
    [bool] PrepareVisualStudioCode($nptargs) {
        if (!(Get-Command code -ErrorAction SilentlyContinue)) {
            if ([Setup]::GetHostOs() -eq "Windows") {
                if (!(Get-Command choco -ErrorAction SilentlyContinue)) { $this.InstallChoco(@()) }
                choco install vscode -y
            } else {
                Write-Host "         Not implemented yet. SKIPPING..." -f DarkYellow
            }
        }
        # Install C/C++ extension for VSCode
        # code --install-extension ms-vscode.cpptools
        # Install CMake Tools extension for VSCode
        # code --install-extension ms-vscode.cmake-tools
        return $?
    }
    [bool] InstallGoogleTestPackage($nptargs) {
        # Install Google Test package
        if (!(Get-Command vcpkg -ErrorAction SilentlyContinue)) {
            if ([Setup]::GetHostOs() -eq "Windows") {
                if (!(Get-Command choco -ErrorAction SilentlyContinue)) { $this.InstallChoco(@()) }
                choco install vcpkg -y
                & "$env:ChocolateyInstall\lib\vcpkg\tools\vcpkg.exe" integrate install
                & "$env:ChocolateyInstall\lib\vcpkg\tools\vcpkg.exe" install gtest:x64-windows
            } else {
                Write-Host "         Not implemented yet. SKIPPING..." -f DarkYellow
            }
        }
        return $?
    }
    [bool] InstallDoxygen($nptargs) {
        if ([Setup]::GetHostOs() -eq "Windows") {
            if (!(Get-Command choco -ErrorAction SilentlyContinue)) { $this.InstallChoco(@()) }
            choco install doxygen.install -y
        } else {
            Write-Host "         Not implemented yet. SKIPPING..." -f DarkYellow
        }
        return $?
    }
    [bool] InstallGit($nptargs) {
        if (!(Get-Command git -ErrorAction SilentlyContinue)) {
            if ([Setup]::GetHostOs() -eq "Windows") {
                if (!(Get-Command choco -ErrorAction SilentlyContinue)) { $this.InstallChoco(@()) }
                choco install git -y
            } else {
                Write-Host "         Not implemented yet. SKIPPING..." -f DarkYellow
            }
        }
        return $?
    }
    [bool] CheckRequirements() {
        return $this.CheckRequirements($false)
    }
    [bool] CheckRequirements([bool]$ThrowOnFailure) {
        $InstallReqs = [MinRequirements]::new();
        $InstallReqs.RunAsAdmin = $this.RunAsAdmin;
        $InstallReqs.RequiredFiles += "$env:ChocolateyInstall\bin\choco.exe"
        $InstallReqs.RequiredFiles += "$env:ChocolateyInstall\lib\msys2\tools\msys2.exe"
        $InstallReqs.RequiredDirectories += "$env:ChocolateyInstall\bin"
        $InstallReqs.RequiredDirectories += "$env:ChocolateyInstall\lib\msys2\tools"
        $Has_AllReqs = [CboxSetup]::CheckRequirements($InstallReqs).Values -notcontains $false
        if ($ThrowOnFailure -and !$Has_AllReqs) { throw "Minimum requirements were not met" }
        return $Has_AllReqs
    }
}
#endregion cboxclasses

function Pop-Stack {
    [CmdletBinding()]
    param ()
    process {
        return [StackTracer]::Pop()
    }
}

function Push-Stack {
    [CmdletBinding()]
    param (
        [string]$class
    )
    process {
        [StackTracer]::Push($class)
    }
}

function Show-Stack {
    [CmdletBinding()]
    param ()
    process {
        [StackTracer]::Peek()
    }
}

function New-CliArt {
    [CmdletBinding()]
    [OutputType([CliArt])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Base64String
    )
    process {
        return [CliArt]::new($Base64String)
    }
}

function Write-AnimatedHost {
    [CmdletBinding()]
    [OutputType([void])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('t')][AllowEmptyString()]
        [string]$text,

        [Parameter(Mandatory = $true, Position = 1)]
        [Alias('f')]
        [System.ConsoleColor]$foregroundColor
    )
    process {
        [void][cli]::Write($text, $foregroundColor)
    }
}

function Write-ProgressBar {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('p')]
        [int]$percent,

        [Parameter(Mandatory = $true, Position = 1)]
        [Alias('l')]
        [int]$PBLength,

        [Parameter(Mandatory = $false)]
        [switch]$update
    )

    end {
        [ProgressUtil]::WriteProgressBar($percent, $update.IsPresent, $PBLength);
    }
}

function Invoke-RetriableCommand {
    # .SYNOPSIS
    #     Retries a Command
    # .DESCRIPTION
    #     A longer description of the function, its purpose, common use cases, etc.
    # .LINK
    #     https://github.com/alainQtec/argoncage/blob/main/Private/TaskMan/TaskMan.psm1
    # .EXAMPLE
    #     Invoke-RetriableCommand { (CheckConnection -host "github.com" -msg "Testing Connection" -IsOnline).Output }
    #     Tries to connect to github 3 times
    [CmdletBinding()]
    [OutputType([psobject])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('s')]
        [ScriptBlock]$ScriptBlock,

        [Parameter(Mandatory = $false, Position = 1)]
        [Alias('args')]
        [Object[]]$ArgumentList,

        [Parameter(Mandatory = $false, Position = 2)]
        [Alias('m')]
        [string]$Message,

        [Parameter(Mandatory = $false, Position = 3)]
        [Alias('cs')][ValidateNotNullOrEmpty()]
        [scriptblock]$CleanupScript,

        [Parameter(Mandatory = $false, Position = 4)]
        [Alias('o')]
        [PSCustomObject]$Options
    )

    begin {
        function WriteLog {
            [CmdletBinding()]
            param (
                [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true)]
                [string]$m = '',
                [Parameter(Mandatory = $false, Position = 1)]
                [switch]$s
            )
            process {
                $args.GetType().Name | Write-Host -f Green
                $re = @{ true = @{ m = "Complete "; c = "Cyan" }; false = @{ m = "Errored "; c = "Red" } }
                if (![string]::IsNullOrWhiteSpace($m)) { $re["$s"].m = $m }
                $re = $re["$s"]
                Write-Host $re.m -f $re.c -NoNewline:$s
            }
        }
    }

    process {
        $cmdOptions = $(if (!$PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Options')) {
                [PSCustomObject]@{
                    MaxAttempts       = 3
                    Timeout           = 1000
                    CancellationToken = [System.Threading.CancellationToken]::None
                    CleanupScript     = $null
                }
            } else { $Options }
        )
        if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('CleanupScript')) { $cmdOptions.CleanupScript = $CleanupScript }
        [System.Threading.CancellationToken]$CancellationToken = $cmdOptions.CancellationToken
        [Int]$MaxAttempts = $cmdOptions.MaxAttempts
        [String]$Message = "$Message"; if ([string]::IsNullOrWhiteSpace($Message)) { $Message = "Invoke Command" }
        [Int]$Timeout = $cmdOptions.Timeout
        [ScriptBlock]$CleanupScript = $cmdOptions.CleanupScript
        [string]$Output = [string]::Empty; $bgTask = TaskResult($Output); $bgTask.IsSuccess = $IsSuccess
        [ValidateNotNullOrEmpty()][scriptblock]$ScriptBlock = $ScriptBlock
        if ([string]::IsNullOrWhiteSpace((Show-Stack))) { Push-Stack 'TaskMan' }
        $IsSuccess = $false; $fxn = Show-Stack; $AttemptStartTime = $null;
        $ErrorRecord = $null;
        [int]$Attempts = 1
        $CommandStartTime = Get-Date
        while (($Attempts -le $MaxAttempts) -and !$bgTask.IsSuccess) {
            $Retries = $MaxAttempts - $Attempts
            if ($cancellationToken.IsCancellationRequested) {
                WriteLog "$fxn CancellationRequested when $Retries retries were left."
                throw
            }
            try {
                " Attempt # $Attempts/$MaxAttempts" | Set-AttemptMSg
                Write-Debug "$fxn $Message$([ProgressUtil]::AttemptMSg) "
                $AttemptStartTime = Get-Date
                if ($null -ne $ArgumentList) {
                    $Output = Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
                    $IsSuccess = [bool]$?
                } else {
                    $Output = Invoke-Command -ScriptBlock $ScriptBlock
                    $IsSuccess = [bool]$?
                }
            } catch {
                $IsSuccess = $false; $ErrorRecord = $_
                " Errored after $([math]::Round(($(Get-Date) - $AttemptStartTime).TotalSeconds, 2)) seconds" | Set-AttemptMSg
                Write-Debug "$fxn $([ProgressUtil]::AttemptMSg)"
            } finally {
                $bgTask.Output = $Output
                $bgTask.IsSuccess = $IsSuccess
                $bgTask.ErrorRecord = $ErrorRecord
                if ($null -ne $CleanupScript) { $bgTask = $CleanupScript.Invoke($bgTask) }
                $job_state = $(if ($bgTask.IsSuccess) { "Completed" } else { "Failed" })
                $bgTask.SetJobState([scriptblock]::Create("return '$job_state'"))
                if ($Retries -eq 0 -or $bgTask.IsSuccess) {
                    Write-Debug " E.T = $([math]::Round(($(Get-Date) - $CommandStartTime).TotalSeconds, 2)) seconds"
                } elseif (!$cancellationToken.IsCancellationRequested -and $Retries -ne 0) {
                    Start-Sleep -Milliseconds $Timeout
                }
                $Attempts++
            }
        }
        return $bgTask
    }
}

function Get-AttemptMSg {
    return [ProgressUtil]::AttemptMSg
}

function Set-AttemptMSg {
    [CmdletBinding()]
    [OutputType([void])]
    param (
        [Parameter(Mandatory = $true , Position = 0, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message
    )
    [ProgressUtil]::AttemptMSg = $Message
}

function Wait-Task {
    # .SYNOPSIS
    #     Waits for a scriptblock or job to complete
    # .OUTPUTS
    #     TaskResult.Result
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    [OutputType([psobject])][Alias('await')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = '__AllparameterSets')]
        [Alias('m')]
        [string]$progressMsg,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'scriptBlock')]
        [Alias('s')]
        [scriptblock]$scriptBlock,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'job')]
        [System.Management.Automation.Job]$Job,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 1, ParameterSetName = 'task')]
        [System.Threading.Tasks.Task[]]$Task
    )
    begin {
        $Result = TaskResult($null);
        # $Tasks = @()
    }
    process {
        if ($PSCmdlet.ParameterSetName -eq 'scriptBlock') {
            [int]$JobId = $(Start-Job -ScriptBlock $scriptBlock).Id
        } else {
            throw [System.NotSupportedException]::new("Sorry, ParameterSetName is not yet supported")
        }
        # $Tasks += $Task
        # While (![System.Threading.Tasks.Task]::WaitAll($Tasks, 200)) {}
        # $Tasks.ForEach( { $_.GetAwaiter().GetResult() })

        [System.Management.Automation.Job]$Job = Get-Job -Id $JobId
        [Console]::CursorVisible = $false;
        [ProgressUtil]::frames = [ProgressUtil]::_twirl[0]
        [int]$length = [ProgressUtil]::frames.Length;
        $originalY = [Console]::CursorTop
        while ($Job.JobStateInfo.State -notin ('Completed', 'failed')) {
            for ($i = 0; $i -lt $length; $i++) {
                [ProgressUtil]::frames | ForEach-Object { [Console]::Write("$progressMsg $($_[$i])") }
                [System.Threading.Thread]::Sleep(50)
                [Console]::Write(("`b" * ($length + $progressMsg.Length)))
                [Console]::CursorTop = $originalY
            }
        }
        # i.e: Gives an illusion of loading animation.
        [void][cli]::Write("`b$progressMsg", [ConsoleColor]::Blue)
        [System.Management.Automation.Runspaces.RemotingErrorRecord[]]$Errors = $Job.ChildJobs.Where({
                $null -ne $_.Error
            }
        ).Error;
        $LogMsg = ''; $_Success = ($null -eq $Errors); $attMSg = Get-AttemptMSg;
        if (![string]::IsNullOrWhiteSpace($attMSg)) { $LogMsg += $attMSg } else { $LogMsg += "... " }
        if ($Job.JobStateInfo.State -eq "Failed" -or $Errors.Count -gt 0) {
            $errormessages = ""; $errStackTrace = ""
            if ($null -ne $Errors) {
                $errormessages = $Errors.Exception.Message -join "`n"
                $errStackTrace = $Errors.ScriptStackTrace
                if ($null -ne $Errors.Exception.InnerException) {
                    $errStackTrace += "`n`t"
                    $errStackTrace += $Errors.Exception.InnerException.StackTrace
                }
            }
            $Result = TaskResult($Job, $Errors);
            $_Success = $false; $LogMsg += " Completed with errors.`n`t$errormessages`n`t$errStackTrace"
        } else {
            $Result = TaskResult($Job)
        }
        WriteLog $LogMsg -s:$_Success
        [Console]::CursorVisible = $true; Set-AttemptMSg ' '
    }
    end {
        return $Result
    }
}

function New-Task {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    [Alias('Create-Task')]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [scriptblock][ValidateNotNullOrEmpty()]
        $ScriptBlock,

        [Parameter(Mandatory = $false, Position = 1)]
        [Object[]]
        $ArgumentList,

        [Parameter(Mandatory = $false, Position = 2)]
        [ValidateNotNullOrEmpty()][System.Management.Automation.Runspaces.Runspace]
        $Runspace = (Get-Variable ExecutionContext -ValueOnly).Host.Runspace
    )
    begin {
        $_result = $null
        $powershell = [System.Management.Automation.PowerShell]::Create()
    }
    process {
        $_Action = $(if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('ArgumentList')) {
                { Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList } -as [System.Action]
            } else {
                { Invoke-Command -ScriptBlock $ScriptBlock } -as [System.Action]
            }
        )
        $powershell = $powershell.AddScript({
                param (
                    [Parameter(Mandatory = $true)]
                    [ValidateNotNull()]
                    [System.Action]$Action
                )
                return [System.Threading.Tasks.Task]::Factory.StartNew($Action)
            }
        ).AddArgument($_Action)
        if (!$PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Runspace')) {
            $Runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
        } else {
            Write-Debug "[New-Task] Using LocalRunspace ..."
            $Runspace = [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace
        }
        if ($Runspace.RunspaceStateInfo.State -ne 'Opened') { $Runspace.Open() }
        $powershell.Runspace = $Runspace
        [ValidateNotNull()][System.Action]$_Action = $_Action;
        Write-Host "[New-Task] Runing in background ..." -ForegroundColor DarkBlue
        $threads = New-Object System.Collections.ArrayList;
        $result = [PSCustomObject]@{
            Task   = $null
            Shell  = $PowerShell
            Result = $PowerShell.BeginInvoke()
        }
        $threads.Add($result) | Out-Null;
        $completed = $false; $_r = @{ true = 'Completed'; false = 'Still open' }
        while ($completed -eq $false) {
            $completed = $true;
            foreach ($thread in $threads) {
                $result.Task = $thread.Shell.EndInvoke($thread.Result);
                $threadHandle = $thread.Result.AsyncWaitHandle.Handle;
                $threadIsCompleted = $thread.Result.IsCompleted;
                ("[New-Task] ThreadHandle {0} is {1}" -f $threadHandle, $_r["$threadIsCompleted"]) | Write-Host -f Blue
                if ($threadIsCompleted -eq $false) {
                    $completed = $false;
                }
            }
            Write-Host "";
            Start-Sleep -Milliseconds 500;
        }
        foreach ($thread in $threads) {
            $thread.Shell.Dispose();
        }
        $_result = $result
    }
    end {
        return $_result
    }
}


function Install-LazyVim {
    # .SYNOPSIS
    #     Install LazyVim Starter
    # .DESCRIPTION
    #     Installs a starter template for LazyVim does the same steps as in the docs: https://lazyvim.github.io/installation
    # .LINK
    #     https://github.com/LazyVim/starter
    [CmdletBinding()]
    param (
    )
    begin {
        $HostoS
        # make sure history is not persisted
        fish --private
    }
    process {
        if ($HostoS -in ('Linux', 'MacOSx')) {
            # required
            Move-Item -Path $HOME/.config/nvim -Destination "$HOME/.config/nvim.bak" -Force

            # optional but recommended
            Move-Item -Path $HOME/.local/share/nvim -Destination "$HOME/.local/share/nvim.bak" -Force
            Move-Item -Path $HOME/.local/state/nvim -Destination "$HOME/.local/state/nvim.bak" -Force
            Move-Item -Path $HOME/.cache/nvim -Destination "$HOME/.cache/nvim.bak" -Force

            Write-Verbose 'Clone the starter'
            git clone https://github.com/LazyVim/starter ~/.config/nvim

            Write-Verbose 'Remove the .git folder, so you can add it to your own repo later'
            rm -rf ~/.config/nvim/.git

            Write-Verbose 'Start Neovim!'
            nvim
        } elseif ($HostoS -eq 'Windows') {
            # required
            Move-Item $env:LOCALAPPDATA/nvim $env:LOCALAPPDATA/nvim.bak
            # optional but recommended
            Move-Item $env:LOCALAPPDATA/nvim-data $env:LOCALAPPDATA/nvim-data.bak
        } else {

        }
        Write-Host "[TIP] : It is recommended to run :LazyHealth after installation. This will load all plugins and check if everything is working correctly."
    }
}
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
        $outpt = $setup.Run()
    }
    end {
        return $outpt
    }
}

# function New-DynamicParam {
#     param ([string]$Name, [int]$position, [type]$type)
#     process {
#         $_params = [System.Management.Automation.RuntimeDefinedParameterDictionary]::New()
#         $_params.Add($Name, [System.Management.Automation.RuntimeDefinedParameter]::new(
#                 $Name, $type, @((
#                         New-Object System.Management.Automation.ParameterAttribute -Property @{
#                             Position          = $position
#                             Mandatory         = $false
#                             ValueFromPipeline = $false
#                             ParameterSetName  = $PSCmdlet.ParameterSetName
#                             HelpMessage       = "hlp msg"
#                         }
#                     ),
#                     [System.Management.Automation.ValidateNotNullOrEmptyAttribute]::new()
#                 )
#             )
#         )
#         return $_params
#     }
# }

# Export-ModuleMember -Function 'Start-CdevEnvSetup' -Variable '*' -Cmdlet '*' -Alias '*' -Verbose:$false