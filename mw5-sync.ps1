# SET THIS TO YOUR MECHWARRIOR 5 DIRECTORY!
$MW5_DIR="C:\Program Files\Epic Games\MW5Mercs"

# don't uncomment this, Ben just uses this for testing on his Mac
#$MW5_DIR="/tmp/mercs"

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

if (-not ${env:TEMP}) {
    ${env:TEMP} = "/tmp"
}

$env:PATH = '{0}{1}{2}' -f $env:PATH,[IO.Path]::PathSeparator,'.'

$UNPACK_DIR = Join-Path -Path (Join-Path -Path $MW5_DIR -ChildPath "MW5Mercs") -ChildPath "mods"
$DOWNLOAD_PATH = Join-Path -Path (Join-Path -Path $MW5_DIR -ChildPath "MW5Mercs") -ChildPath "mw5modsync-cache"

if (-not (Test-Path -Path $UNPACK_DIR)) {
    throw "mod directory ${UNPACK_DIR} does not exist"
}

if (-not (Test-Path -Path $DOWNLOAD_PATH)) {
    New-Item -Path $DOWNLOAD_PATH -ItemType Directory
}


function is_7zip {
    param($_file)
    return $_file.EndsWith(".7z", "CurrentCultureIgnoreCase");
}

function is_rar {
    param($_file)
    return $_file.EndsWith(".rar", "CurrentCultureIgnoreCase");
}

function is_zip {
    param($_file)
    return $_file.EndsWith(".zip", "CurrentCultureIgnoreCase");
}

function Get-Cygpath {
    param($_path)

    if ([IO.Path]::DirectorySeparatorChar -eq '/') {
        return $_path
    }
    $_cygwin_path = cygpath --unix "${_path}" | Out-String
    $_cygwin_path = $_cygwin_path.replace("`r`n", "").replace("`n", "")
    return $_cygwin_path
}

function Get-Local-Filelist {
    param( $_folder )

    $localdir = Join-Path $DOWNLOAD_PATH -ChildPath $_folder
    if (-not (Test-Path -Path $localdir)) {
        return @()
    }

    return [array](Get-ChildItem -Path $localdir -File -Name)
}

function Get-Json-From-File {
    param( $_filename )

    $contents = Get-Content -Path $_filename -Raw
    $json = ConvertFrom-Json -InputObject $contents
    return $json
}

function Get-Mod-Info-From-File {
    param( $_file )

    $json = Get-Json-From-File $_file.FullName

    # Write-Host "Full Name: $($_file.FullName)"
    $_relativeName = $_file.FullName.ToString()
    $_relativeName = $_relativeName.replace(($UNPACK_DIR + [IO.Path]::DirectorySeparatorChar), '')

    $_internalPath = $_relativeName.Split([IO.Path]::DirectorySeparatorChar)[0]

    return @{
        id = $_internalPath.ToLower()
        file = $_file.FullName.ToString()
        internalPath = $_internalPath
        displayName = $json.displayName
        version = $json.version
        buildNumber = $json.buildNumber
    }
}

function Get-Mod-Info-Files-From-List {
    param(
        [Parameter(ValueFromPipeline=$true)]
        $_archive_output
    )

    return $_archive_output -split '\r?\n' | Where-Object { $_ -match "^[^\\/]+[\\/]mod.json" } | ForEach-Object { $_.replace("Path = ", "") };
}

function Get-Mod-Info-From-Archive {
    param( $_archive_file )

    $json = @{}

    if (is_zip($_archive_file)) {
        $_cyg_zip_file = Get-Cygpath $_archive_file
        $modfiles = unzip -Z1 "${_cyg_zip_file}" | Out-String | Get-Mod-Info-Files-From-List
        $modfiles | ForEach-Object {
            $modfile = $_
            $contents = unzip -p "${_cyg_zip_file}" $modfile | Out-String
            $json[$modfile] = ConvertFrom-Json -InputObject $contents
        }
    } elseif (is_rar($_archive_file)) {
        $modfiles = unrar lb "${_archive_file}" | Out-String | Get-Mod-Info-Files-From-List
        if ($LASTEXITCODE -gt 0) {
            throw "failed to determine mod.json path inside archive ${_archive_file}"
        }
        $modfiles | ForEach-Object {
            $modfile = $_
            $contents = unrar p "${_archive_file}" $modfile | Out-String
            if ($LASTEXITCODE -gt 0) {
                throw "failed to get contents of mod.json inside archive ${_archive_file}"
            }
            $json[$modfile] = ConvertFrom-Json -InputObject $contents
        }
    } elseif (is_7zip($_archive_file)) {
        $cyg_archive_file = Get-Cygpath "${_archive_file}"
        $modfiles = 7z l -slt "${cyg_archive_file}" | Out-String | Get-Mod-Info-Files-From-List
        if ($LASTEXITCODE -gt 0) {
            throw "failed to determine mod.json path inside archive ${_archive_file}"
        }
        $modfiles | ForEach-Object {
            $modfile = $_
            $contents = 7z e -so "${cyg_archive_file}" "${modfile}" | Out-String
            if ($LASTEXITCODE -gt 0) {
                throw "failed to get contents of mod.json inside archive ${_archive_file}"
            }
            $json[$modfile] = ConvertFrom-Json -InputObject $contents
        }
    } else {
        Write-Host -ForegroundColor Yellow "Unknown file type: ${_archive_file}"
        return @{}
    }

    $ret = @{}
    foreach ($modfile in $json.Keys) {
        $_archiveInternalPath = ($modfile.ToString() -split "[/\\]")[0]

        $ret += @{
            id = $_archiveInternalPath.ToLower()
            file = $_archive_file.ToString()
            internalPath = $_archiveInternalPath
            displayName = $json[$modfile].displayName
            version = $json[$modfile].version
            buildNumber = $json[$modfile].buildNumber
        }
    }
    return $ret;
}

function Expand-Mod {
    param($_mod)

    if (is_zip($_mod.file)) {
        $_cyg_unpack_dir = Get-Cygpath $UNPACK_DIR
        $_cyg_zip_file = Get-Cygpath $_mod.file
        unzip -q -o -d "${_cyg_unpack_dir}" "${_cyg_zip_file}"
    } elseif (is_rar($_mod.file)) {
        unrar -y x -idq $_mod.file -op $UNPACK_DIR
    } elseif (is_7zip($_mod.file)) {
        $cyg_archive_file = Get-Cygpath $_mod.file
        $output_dir = Get-Cygpath $UNPACK_DIR
        7z -y x "${cyg_archive_file}" "-o${output_dir}" | Select-String "Error" -Context 10
    }
    if ($LASTEXITCODE -gt 0) {
        throw "failed to unpack file"
    }
}

function Write-Mod-Name {
    param($_mod)

    Write-Host -NoNewline -ForegroundColor Green $_mod.displayName
}

function Write-Mod-Version {
    param($_mod)

    Write-Host -NoNewline "version "
    Write-Host -NoNewline -ForegroundColor Yellow $_mod.version
    Write-Host -NoNewline ", build "
    Write-Host -NoNewline -ForegroundColor Yellow $_mod.buildNumber
}

$active_mods = @{}

Write-Host "### DOWNLOADING NEW FILES ###" -ForegroundColor Cyan

$_local_download_path = Get-Cygpath "${DOWNLOAD_PATH}"
rsync -avr --partial --progress --no-perms --delete --exclude='*.filepart' --include='Required/***' --include='Optional/***' --exclude='*' "ln1.raccoonfink.com::mw5/" "${_local_download_path}/"

foreach ($mod_dir in (Get-ChildItem -Recurse -Directory $DOWNLOAD_PATH | Select-Object -ExpandProperty Name)) {
    $local_filelist = Get-Local-Filelist $mod_dir

    foreach ($localfile in $local_filelist) {
        $relative_path = Join-Path -Path $mod_dir -ChildPath $localfile
        $full_path = Join-Path -Path $DOWNLOAD_PATH -ChildPath $relative_path
        Get-Mod-Info-From-Archive($full_path) | ForEach-Object {
            $archive_modinfo = $_
            if ($archive_modinfo.ContainsKey('id')) {
                $active_mods[$archive_modinfo.id] = $archive_modinfo
            }
        }
    }
}

Write-Host ""
Write-Host "### SCANNING INSTALLED MODS ###" -ForegroundColor Cyan

$existing_modfiles = Get-ChildItem -Path $UNPACK_DIR -Filter 'mod.json' -Recurse | Sort-Object

$existing_mods = @{}
$unpacked_mods = @{}

foreach ($json_file in $existing_modfiles) {
    # Write-Host "existing: $($jsonfile.FullName)"
    $json_modinfo = Get-Mod-Info-From-File $json_file

    Write-Host -NoNewline "* Found installed mod "
    Write-Mod-Name $json_modinfo
    Write-Host -NoNewline " ("
    Write-Mod-Version $json_modinfo
    Write-Host -NoNewline ") at "
    Write-Host $json_modinfo.internalPath -ForegroundColor Magenta

    $existing_mods[$json_modinfo.id] = $json_modinfo;
}

Write-Host ""
Write-Host "### SYNCING DOWNLOADS TO MOD DIRECTORY ###" -ForegroundColor Cyan

$active_mods.GetEnumerator() | Sort-Object { $_.Value.displayName } | ForEach-Object {
    $id = $_.Key.ToString().ToLower()
    $active = $_.Value
    $existing = $existing_mods[$id]

    # Write-Host "id: $($id)"
    # Write-Host "existing: " + ($existing | Out-String)
    # Write-Host "active: " + ($active | Out-String)

    if ($existing.id -and ($existing.version -eq $active.version) -and ($existing.buildNumber -eq $active.buildNumber)) {
        Write-Host -ForegroundColor DarkGray "* $($existing.displayName) already installed: version $($existing.version), build $($existing.buildNumber)"
    } else {
        Write-Host -NoNewline "+ "
        Write-Mod-Name $active
        Write-Host -NoNewline " new or changed: "
        if ($existing.id) {
            Write-Mod-Version $existing
            Write-Host -NoNewline " => "
        }
        Write-Mod-Version $active
        Write-Host ""

        if ($existing.id -and $existing.version) {
            Write-Host -NoNewline "  ! Deleting existing "
            Write-Host -NoNewline -ForegroundColor Magenta $existing.internalPath
            Write-Host -NoNewline " mod directory... "

            Remove-Item (Join-Path -Path $UNPACK_DIR -ChildPath $existing.internalPath) -Recurse -Force

            Write-Host "done"
        }
        $archive_file_name = Split-Path $active.file -Leaf -Resolve
        Write-Host -NoNewline "  * Unpacking archive: "
        Write-Host -NoNewline -ForegroundColor Blue $archive_file_name
        Write-Host -NoNewline "... "
        if ($unpacked_mods.ContainsKey($archive_file_name)) {
            Write-Host "already unpacked"
        } else {
            Expand-Mod $active
            Write-Host "done"
            $unpacked_mods[$archive_file_name] = $true
        }
    }
}

Write-Host ""
Write-Host "### REMOVING OBSOLETE MODS ###" -ForegroundColor Cyan

$existing_mods.GetEnumerator() | Sort-Object { $_.Value.displayName } | ForEach-Object {
    $id = $_.Key.ToString()
    $existing = $_.Value
    $active = $active_mods[$id]

    if (-not $active) {
        Write-Host -NoNewline "! Deleting removed "
        Write-Mod-Name $existing
        Write-Host -NoNewline " ("
        Write-Mod-Version $existing
        Write-Host -NoNewline ") mod from the "
        Write-Host -NoNewline -ForegroundColor Magenta $existing.internalPath
        Write-Host " directory..."
        Remove-Item (Join-Path -Path $UNPACK_DIR -ChildPath $existing.internalPath) -Recurse -Force
        Write-Host "done"
    }
}

Write-Host ""
Write-Host "### Updating modlist.json ###" -ForegroundColor Cyan

$modlist_filename = Join-Path -Path $UNPACK_DIR -ChildPath "modlist.json"
$modlist = @{ modStatus = @{} };
if (Test-Path -Path $modlist_filename) {
    $modlist = Get-Json-From-File $modlist_filename
} else {
    Write-Host -ForegroundColor Yellow "! ${modlist_filename} does not already exist... creating"
}

$active_mods.GetEnumerator() | Sort-Object { $_.Value.displayName } | ForEach-Object {
    $mod_info = $_.Value

    if ($mod_info.file -imatch "\boptional\b") {
        Write-Host -ForegroundColor DarkGray "* Skipping optional mod $($mod_info.displayName)"
    } else {
        $modlist.modStatus | Add-Member -Force -NotePropertyName $mod_info.internalPath -NotePropertyValue @{ bEnabled = $true }
        Write-Host -NoNewline "* Enabling required mod "
        Write-Mod-Name $mod_info
        Write-Host ""
    }
}

if (Test-Path -Path "${modlist_filename}.bak") {
    Remove-Item "${modlist_filename}.bak"
}

if (Test-Path -Path $modlist_filename) {
    Rename-Item -Path $modlist_filename -NewName "${modlist_filename}.bak"
}

$modlist | ConvertTo-Json | Out-File -FilePath $modlist_filename

Write-Host ""
pause
