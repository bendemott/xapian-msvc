# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 Ben DeMott
# xapian-msvc build helper for Windows. The Linux/macOS twin is build.sh.
#
#   .\build.ps1                    help
#   .\build.ps1 build test         commands chain and always run in a fixed order
#   .\build.ps1 test --help        help for one command
#
# Works in Windows PowerShell 5.1 and PowerShell 7. No param() block is
# intentional: every argument lands in $args, so "--release", "-release" and
# "release" are treated the same. Keep this file ASCII: 5.1 reads a BOM-less
# script in the ANSI code page.

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
Set-StrictMode -Version 3

$ScriptArgs = @($args)
$Root = $PSScriptRoot
$Self = '.\build.ps1'
$XapianVersion = '2.1.0'

# Commands run in this order, regardless of the order they were typed in.
$Order = @('doctor', 'clean', 'import', 'build', 'test')

# ---------------------------------------------------------------------------
# colors and messages

$script:Color = -not $env:NO_COLOR
$Argv = @()
foreach ($x in $ScriptArgs) {
    $s = [string]$x
    if ($s -eq '--no-color') { $script:Color = $false; continue }
    if ($s -eq '--color') { $script:Color = $true; continue }
    $Argv += $s
}

function Write-Colored([string]$Text, [string]$Color, [switch]$NoNewline) {
    if ($script:Color -and $Color) { Write-Host $Text -ForegroundColor $Color -NoNewline:$NoNewline }
    else { Write-Host $Text -NoNewline:$NoNewline }
}

function Say([string]$m)  { Write-Colored '==> ' Cyan -NoNewline; Write-Host $m }
function Ok([string]$m)   { Write-Colored '==> ' Green -NoNewline; Write-Host $m }
function Warn([string]$m) { Write-Colored 'warning: ' Yellow -NoNewline; Write-Host $m }
function Die([string]$m) {
    Write-Colored 'error: ' Red -NoNewline
    Write-Host $m
    foreach ($more in $args) {
        foreach ($line in ([string]$more -split "`r?`n")) { Write-Host "       $line" }
    }
    exit 1
}
function Usage-Die([string]$m, [string]$Command = '') {
    $hint = "$Self help"
    if ($Command) { $hint = "$Self $Command --help" }
    Die $m "see: $hint"
}

# ---------------------------------------------------------------------------
# help text
#
# Lines use a small markup, colored by Paint:
#   {h:heading} {c:command} {o:option} {g:example} {d:dim}

$MarkupRe = '\{([a-z]):([^}]*)\}'
$MarkupColors = @{ h = 'Green'; c = 'Cyan'; o = 'Yellow'; g = 'Magenta'; d = 'DarkGray' }

function Strip-Markup([string]$s) { return [regex]::Replace($s, $MarkupRe, '$2') }

function Paint([string]$s) {
    $pos = 0
    foreach ($m in [regex]::Matches($s, $MarkupRe)) {
        if ($m.Index -gt $pos) { Write-Host $s.Substring($pos, $m.Index - $pos) -NoNewline }
        Write-Colored $m.Groups[2].Value $MarkupColors[$m.Groups[1].Value] -NoNewline
        $pos = $m.Index + $m.Length
    }
    Write-Host $s.Substring($pos)
}

function HL([string]$Line = '') { Paint $Line }

function HRow([string]$Left, [string]$Desc) {
    $pad = 36 - (Strip-Markup $Left).Length
    if ($pad -lt 2) {
        HL "  $Left"
        HL ((' ' * 38) + $Desc)
    } else {
        HL ("  $Left" + (' ' * $pad) + $Desc)
    }
}

function Show-Help {
    HL "{h:xapian-msvc build helper} {d:(build.ps1: Windows, build.sh: Linux and macOS)}"
    HL
    HL "{h:usage:} $Self {c:<command>} [{o:options}] [{c:<command>} [{o:options}] ...]"
    HL
    HL "Commands can be combined. They always run in this order, whatever order"
    HL "you type them in:"
    HL
    HL "    {c:doctor} > {c:clean} > {c:import} > {c:build} > {c:test}"
    HL
    HL "so {g:$Self test build} builds, then tests. Options belong to the command"
    HL "before them and can be written {o:--debug} or {o:debug}. A word that names"
    HL "a command always starts that command: {o:build release} is build, then an"
    HL "unknown command. Use {o:--release} for the build type."
    HL
    HL "{h:commands:}"
    HRow "{c:help}" "this text; {c:<command> help} for one command"
    HRow "{c:doctor}" "show the compiler, SDK, cmake and ninja used"
    HRow "{c:clean}" "delete build\"
    HRow "{c:import} [{o:X.Y.Z}]" "download core+omega+bindings into third_party\ (default $XapianVersion)"
    HRow "{c:build} [{o:--release}|{o:--debug}] [{o:--python3}]" "configure + build with MSVC (default --release)"
    HRow "{c:test}" "smoke tests via ctest (builds first)"
    HL
    HL "{h:examples:}"
    HRow "{g:$Self build test}" "configure, build, run smoke tests"
    HRow "{g:$Self build --python3 test}" "also build Python 3 bindings"
    HRow "{g:$Self clean build --debug test}" "fresh debug build, then test"
    HRow "{g:$Self import build}" "import sources, then build"
    HL
    HL "{h:global options:}"
    HRow "{o:--no-color}, {o:--color}" "turn colored output off / on (NO_COLOR=1 also turns it off)"
    HL
    HL "{h:needs:} Visual Studio 2022 or newer (or Build Tools) with `"Desktop development with C++`","
    HL "cmake, and preferably ninja (falls back to the Visual Studio generator without it)."
    HL "If third_party\ sources are missing, CMake downloads $XapianVersion automatically"
    HL "(or run {c:import} first). Python 3 + headers needed only for {o:--python3}."
}

function Show-CommandHelp([string]$Name) {
    switch ($Name) {
        'help' { Show-Help }
        'doctor' {
            HL "{h:usage:} $Self {c:doctor}"
            HL
            HL "Shows which cl, link, rc, mt, cmake and ninja the build uses, and the"
            HL "Windows SDK it found. Run it when a build can't find its tools."
        }
        'clean' {
            HL "{h:usage:} $Self {c:clean}"
            HL
            HL "Deletes build\. Chain it to start fresh: {g:$Self clean build}."
        }
        'import' {
            HL "{h:usage:} $Self {c:import} [{o:X.Y.Z}]"
            HL
            HL "Runs scripts\import-xapian.py to download official release tarballs for"
            HL "xapian-core, xapian-omega, and xapian-bindings into third_party\."
            HL "Default version: $XapianVersion. Needs Python 3. CMake can also FetchContent"
            HL "each tarball on configure if this step is skipped."
        }
        'build' {
            HL "{h:usage:} $Self {c:build} [{o:--release}|{o:--debug}] [{o:--python3}]"
            HL
            HL "Loads the MSVC environment, then configures and builds libxapian, core CLI"
            HL "tools, omega, and the smoke test into build\release\ or build\debug\."
            HL "Uses Ninja when available, otherwise the Visual Studio 2022 generator."
            HL
            HL "{h:options:}"
            HRow "{o:--release}" "optimized build (default)"
            HRow "{o:--debug}" "debug build"
            HRow "{o:--python3}" "also build Python 3 bindings (_xapian.pyd)"
        }
        'test' {
            HL "{h:usage:} $Self {c:test}"
            HL
            HL "Builds (release, or the type {c:build} picked on the same command line), then"
            HL "runs ctest smoke tests (library, tools, omega; Python if {o:--python3})."
        }
        default { Usage-Die "no help for '$Name'" }
    }
}

# ---------------------------------------------------------------------------
# helpers

# Run a native command and stop on a non-zero exit code.
# Pass the argument list as one array (do not splat into Exec — leading
# dashes would be parsed as Exec's own parameters).
function Exec([string]$Exe, [string[]]$CmdArgs = @()) {
    $ErrorActionPreference = 'Continue'
    & $Exe @CmdArgs
    if ($LASTEXITCODE -ne 0) { Die "$Exe $($CmdArgs -join ' ') failed (exit $LASTEXITCODE)" }
}

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding $false))
}

function Find-WindowsSdk {
    $kits = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10'
    if (-not (Test-Path (Join-Path $kits 'bin'))) { return $null }
    $versions = Get-ChildItem (Join-Path $kits 'bin') -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^10\.0\.\d+\.\d+$' } |
        Sort-Object { [version]$_.Name } -Descending
    foreach ($v in $versions) {
        $ver = $v.Name
        $ok = (Test-Path (Join-Path $kits "bin\$ver\x64\rc.exe")) -and
              (Test-Path (Join-Path $kits "bin\$ver\x64\mt.exe")) -and
              (Test-Path (Join-Path $kits "Include\$ver\um\Windows.h")) -and
              (Test-Path (Join-Path $kits "Include\$ver\ucrt\stdio.h")) -and
              (Test-Path (Join-Path $kits "Lib\$ver\um\x64\kernel32.lib")) -and
              (Test-Path (Join-Path $kits "Lib\$ver\ucrt\x64\ucrt.lib"))
        if ($ok) { return [pscustomobject]@{ Version = $ver; Root = $kits } }
    }
    return $null
}

function Test-MsvcEnv {
    foreach ($tool in @('cl.exe', 'link.exe', 'rc.exe', 'mt.exe')) {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { return $false }
    }
    return [bool]$env:INCLUDE -and [bool]$env:LIB
}

function Add-WindowsSdkToEnv($Sdk) {
    $r = $Sdk.Root.TrimEnd('\')
    $v = $Sdk.Version
    $env:WindowsSdkDir = "$r\"
    $env:WindowsSDKVersion = "$v\"
    $env:WindowsSdkBinPath = "$r\bin\"
    $env:WindowsSdkVerBinPath = "$r\bin\$v\"
    $env:UniversalCRTSdkDir = "$r\"
    $env:UCRTVersion = $v
    $env:PATH = "$r\bin\$v\x64;$r\bin\x64;$env:PATH"
    $inc = @("$r\Include\$v\ucrt", "$r\Include\$v\um", "$r\Include\$v\shared", "$r\Include\$v\winrt", "$r\Include\$v\cppwinrt")
    $env:INCLUDE = (@($inc) + @($env:INCLUDE -split ';') | Where-Object { $_ }) -join ';'
    $lib = @("$r\Lib\$v\ucrt\x64", "$r\Lib\$v\um\x64")
    $env:LIB = (@($lib) + @($env:LIB -split ';') | Where-Object { $_ }) -join ';'
}

function Repair-SystemPath {
    $root = $env:SystemRoot
    if (-not $root) { $root = 'C:\Windows' }
    $want = @("$root\System32", $root, "$root\System32\Wbem", "$root\System32\WindowsPowerShell\v1.0")
    $have = @(([string]$env:PATH) -split ';' | ForEach-Object { $_.TrimEnd('\') })
    $missing = @($want | Where-Object { $have -notcontains $_ })
    if ($missing.Count -gt 0) {
        Warn "PATH is missing $($missing -join ', '); adding them for this build. Fix PATH in System Properties > Environment Variables."
        $env:PATH = (@($missing) + @($env:PATH)) -join ';'
    }
}

function Import-VcVars([string]$VsPath) {
    $bat = Join-Path $VsPath 'VC\Auxiliary\Build\vcvars64.bat'
    if (-not (Test-Path $bat)) { Die "missing $bat (install the MSVC x64 build tools)" }
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "xapian-vcvars-$PID.cmd"
    Write-Utf8NoBom $tmp "@call `"$bat`" >nul 2>&1`r`n@set`r`n"
    try {
        $old = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $cmdExe = $env:ComSpec
        if (-not $cmdExe) { $cmdExe = Join-Path $env:SystemRoot 'System32\cmd.exe' }
        $lines = & $cmdExe /d /c $tmp
        $ErrorActionPreference = $old
    } finally {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
    if (-not $lines) { Warn 'vcvars64.bat produced no environment'; return }
    foreach ($line in $lines) {
        if ($line -match '^([^=]+)=(.*)$') {
            [System.Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process')
        }
    }
}

function Test-SdkInEnv {
    if (-not (Get-Command rc.exe -ErrorAction SilentlyContinue)) { return $false }
    if (-not (Get-Command mt.exe -ErrorAction SilentlyContinue)) { return $false }
    return ([string]$env:INCLUDE) -match '\\um(;|$)'
}

function Enter-DevShell([switch]$NoCheck) {
    Repair-SystemPath
    if ((Test-MsvcEnv) -and (Test-SdkInEnv)) { return }
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path $vswhere)) { Die 'Visual Studio not found (install Build Tools or VS 2022+ with the "Desktop development with C++" workload)' }
    $vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not $vs) { Die 'no Visual Studio install with the MSVC x64 tools' }

    Say "loading MSVC environment: $vs"
    Import-VcVars $vs

    if (-not (Test-SdkInEnv)) {
        $sdk = Find-WindowsSdk
        if ($sdk) {
            Warn ("vcvars did not set up a Windows SDK (usually its registry entry is missing); " +
                  "adding SDK $($sdk.Version) from $($sdk.Root) by hand")
            Add-WindowsSdkToEnv $sdk
        }
    }

    if (-not $NoCheck -and -not ((Test-MsvcEnv) -and (Test-SdkInEnv))) {
        $missing = @('cl.exe', 'link.exe', 'rc.exe', 'mt.exe') | Where-Object { -not (Get-Command $_ -ErrorAction SilentlyContinue) }
        if ($missing -contains 'cl.exe' -or $missing -contains 'link.exe') {
            Die "MSVC tools not found after entering the dev shell (missing: $($missing -join ', ')). Run $Self doctor for details."
        }
        Die ("no usable Windows SDK (missing: $($missing -join ', ')). Open Visual Studio Installer, Modify your Build Tools, " +
             "Individual components, tick the newest 'Windows 11 SDK', then run $Self clean and build again.")
    }
}

function Show-Tool([string]$Name) {
    $c = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c) { Write-Host ("  {0,-12} {1}" -f $Name, $c.Source) }
    else { Write-Host ("  {0,-12} MISSING" -f $Name) -ForegroundColor Red }
}

function Test-HasNinja {
    return [bool](Get-Command ninja.exe -ErrorAction SilentlyContinue)
}

function Build-Dir([string]$Config) {
    return (Join-Path $Root "build\$Config")
}

# Build each type at most once per invocation (test reuses it).
$script:Built = @{}
$script:UseVsGenerator = $false

function Ensure-Built([string]$Config) {
    if ($script:Built[$Config]) { return }
    Enter-DevShell
    if (-not (Get-Command cmake.exe -ErrorAction SilentlyContinue)) {
        Die 'cmake not found. Install CMake 3.20+ and ensure it is on PATH.'
    }
    $dir = Build-Dir $Config
    $cmakeBuildType = if ($Config -eq 'debug') { 'Debug' } else { 'Release' }

    $extra = @()
    if ($Opt.Python3) { $extra += '-DXAPIAN_BUILD_PYTHON3=ON' }
    else { $extra += '-DXAPIAN_BUILD_PYTHON3=OFF' }

    if (Test-HasNinja) {
        $script:UseVsGenerator = $false
        Say "configure ($Config, Ninja)"
        Exec cmake (@('-S', $Root, '-B', $dir, '-G', 'Ninja', "-DCMAKE_BUILD_TYPE=$cmakeBuildType") + $extra)
        Say "build ($Config)"
        Exec cmake ('--build', $dir, '--parallel')
    } else {
        $script:UseVsGenerator = $true
        Warn 'ninja not found; using Visual Studio 17 2022 generator (install ninja for faster rebuilds)'
        Say "configure ($Config, VS 2022)"
        Exec cmake (@('-S', $Root, '-B', $dir, '-G', 'Visual Studio 17 2022', '-A', 'x64') + $extra)
        Say "build ($Config / $cmakeBuildType)"
        Exec cmake ('--build', $dir, '--config', $cmakeBuildType, '--parallel')
    }
    $script:Built[$Config] = $true
}

# ---------------------------------------------------------------------------
# command line

$Want = @{}
$Opt = @{
    Build         = 'release'   # release | debug
    ImportVersion = $XapianVersion
    Python3       = $false
}
$script:BuildType = 'release'

function Get-CommandName([string]$a) {
    switch ($a) {
        { $_ -in @('help', 'doctor', 'clean', 'import', 'build', 'test') } { return $_.ToLowerInvariant() }
    }
    return $null
}

function Test-HelpWord([string]$a) { return $a -in @('help', '--help', '-help', '-h', '-?', '/?') }

function Show-HelpIfAsked([string[]]$a) {
    $asked = $false
    $names = @()
    foreach ($x in $a) {
        if (Test-HelpWord $x) { $asked = $true; continue }
        $c = Get-CommandName $x
        if ($c -and ($names -notcontains $c)) { $names += $c }
    }
    if (-not $asked) { return }
    if ($names.Count -eq 1) { Show-CommandHelp $names[0] } else { Show-Help }
    exit 0
}

function Stop-BadOption([string]$Command, [string]$x) {
    Usage-Die "${Command}: unknown option '$x'" $Command
}

function Parse-Args([string[]]$a) {
    $cur = ''
    $i = 0
    while ($i -lt $a.Count) {
        $x = $a[$i]
        $i++
        $c = Get-CommandName $x
        if ($c) {
            if ($Want[$c]) { Usage-Die "'$c' appears twice" }
            $Want[$c] = $true
            $cur = $c
            continue
        }
        if (-not $cur) { Usage-Die "unknown command '$x'" }
        $n = ($x -replace '^-{1,2}', '').ToLowerInvariant()
        switch ($cur) {
            { $_ -in @('doctor', 'clean', 'test') } { Stop-BadOption $cur $x }
            'build' {
                if ($n -in @('release', 'debug')) { $Opt.Build = $n }
                elseif ($n -eq 'python3') { $Opt.Python3 = $true }
                else { Stop-BadOption 'build' $x }
            }
            'import' {
                if ($n -match '^\d+\.\d+\.\d+$') { $Opt.ImportVersion = $n }
                else { Stop-BadOption 'import' $x }
            }
        }
    }
}

# ---------------------------------------------------------------------------
# commands

function Cmd-Doctor {
    $sdk = Find-WindowsSdk
    if ($sdk) { Say "Windows SDK: $($sdk.Version) in $($sdk.Root)" } else { Warn 'no complete Windows 10/11 SDK found under Windows Kits\10' }
    Enter-DevShell -NoCheck
    Say 'toolchain'
    foreach ($t in @('cl.exe', 'link.exe', 'rc.exe', 'mt.exe', 'cmake.exe', 'ninja.exe', 'curl.exe', 'tar.exe')) { Show-Tool $t }
    Write-Host "  VS           $env:VisualStudioVersion   SDK $env:WindowsSDKVersion"
    foreach ($pkg in @('xapian-core', 'xapian-omega', 'xapian-bindings')) {
        $marker = switch ($pkg) {
            'xapian-core' { 'include\xapian.h' }
            'xapian-omega' { 'omega.cc' }
            'xapian-bindings' { 'python3\xapian_wrap.cc' }
        }
        if (Test-Path (Join-Path $Root "third_party\$pkg\$marker")) {
            Say "${pkg}: third_party\$pkg"
        } else {
            Warn "third_party\$pkg missing (CMake may download $XapianVersion, or run $Self import)"
        }
    }
    Show-Tool 'python.exe'
    if ((Test-MsvcEnv) -and (Test-SdkInEnv)) { Say 'toolchain looks complete' } else { Warn 'toolchain incomplete: see MISSING above' }
}

function Cmd-Clean {
    $d = Join-Path $Root 'build'
    Say "removing $d"
    if (Test-Path $d) { Remove-Item $d -Recurse -Force }
}

function Cmd-Import {
    $ver = $Opt.ImportVersion
    $py = $null
    foreach ($name in @('python.exe', 'py.exe')) {
        $c = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($c) { $py = $c.Source; break }
    }
    if (-not $py) { Die 'Python 3 not found (needed to run scripts\import-xapian.py)' }
    $script = Join-Path $Root 'scripts\import-xapian.py'
    Say "import xapian-core + omega + bindings $ver"
    if ($py -like '*\py.exe') {
        Exec $py (@('-3', $script, '--version', $ver))
    } else {
        Exec $py (@($script, '--version', $ver))
    }
    Ok "imported third_party\xapian-{core,omega,bindings} $ver"
}

function Cmd-Build {
    Ensure-Built $Opt.Build
    $bits = @('libxapian', 'tools', 'omega')
    if ($Opt.Python3) { $bits += 'python3' }
    Ok "built build\$($Opt.Build)\ ($($bits -join ' + '))"
}

function Cmd-Test {
    $cfg = $script:BuildType
    $dir = Build-Dir $cfg
    Ensure-Built $cfg
    $ctestArgs = @('--test-dir', $dir, '--output-on-failure')
    # VS multi-config needs -C; Ninja single-config does not, but -C is harmless if unused.
    if ($script:UseVsGenerator -or (Test-Path (Join-Path $dir 'xapian.sln'))) {
        $cmakeBuildType = if ($cfg -eq 'debug') { 'Debug' } else { 'Release' }
        $ctestArgs += @('-C', $cmakeBuildType)
    }
    Say "smoke test ($cfg)"
    Exec ctest $ctestArgs
    Ok 'tests passed'
}

# ---------------------------------------------------------------------------

if ($Argv.Count -eq 0) { Show-Help; exit 0 }
Show-HelpIfAsked $Argv
Parse-Args $Argv

if ($Want['build']) { $script:BuildType = $Opt.Build }

$plan = @($Order | Where-Object { $Want[$_] })
if ($plan.Count -gt 1) { Say "plan: $($plan -join ' > ')" }

$i = 0
foreach ($c in $plan) {
    $i++
    if ($plan.Count -gt 1) { Write-Host ''; Write-Colored "==> [$i/$($plan.Count)] $c" Cyan }
    switch ($c) {
        'doctor' { Cmd-Doctor }
        'clean'  { Cmd-Clean }
        'import' { Cmd-Import }
        'build'  { Cmd-Build }
        'test'   { Cmd-Test }
    }
}
exit 0
