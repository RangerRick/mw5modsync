# SET THIS TO YOUR MECHWARRIOR 5 DIRECTORY!
$MW5_DIR="C:\Program Files\Epic Games\MW5Mercs"

# don't uncomment this, Ben just uses this for testing on his Mac
#$MW5_DIR="/tmp/MW5Mercs"

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

if (-not ${env:TEMP}) {
    ${env:TEMP} = "/tmp"
}

$env:PATH = '{0}{1}{2}' -f $env:PATH,[IO.Path]::PathSeparator,'.'

$UNPACK_DIR = Join-Path -Path (Join-Path -Path $MW5_DIR -ChildPath "MW5Mercs") -ChildPath "mods"
$DOWNLOAD_PATH = Join-Path -Path (Join-Path -Path $MW5_DIR -ChildPath "MW5Mercs") -ChildPath "mw5modsync-cache"
# $DOWNLOAD_PATH = Join-Path -Path ${env:TEMP} -ChildPath "MW5Mercs_mod_downloads"
$MOD_DIRS = "Rise of Rasalhague", "MW2"

if (-not (Test-Path -Path $UNPACK_DIR)) {
    throw "mod directory ${UNPACK_DIR} does not exist"
}

if (-not (Test-Path -Path $DOWNLOAD_PATH)) {
    New-Item -Path $DOWNLOAD_PATH -ItemType Directory
}


$_server_root="https://mw5.raccoonfink.com"

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

    $_cygwin_path = cygpath --unix "${_path}" | Out-String
    $_cygwin_path = $_cygwin_path.replace("`r`n", "").replace("`n", "")
    return $_cygwin_path
}

function Get-File {
    param(
        $_url,
        $_folder,
        $_filename
    )

    $root = "${_url}/${_folder}"

    $output_dir = Join-Path -Path $DOWNLOAD_PATH -ChildPath $_folder
    if (-not (Test-Path -Path $output_dir)) {
        New-Item -Path $output_dir -ItemType Directory
    }
    $output_file = Join-Path -Path $output_dir -ChildPath $_filename

    Write-Host -NoNewline "* Downloading ${_folder}/"
    Write-Host -NoNewline -ForegroundColor Blue ${_filename}
    Write-Host -NoNewline "... "
    $escaped = [uri]::EscapeUriString($_filename)
    $global:ProgressPreference = 'SilentlyContinue'
    $response = Invoke-WebRequest -UseBasicParsing -Uri "${root}/${escaped}" -Method Head
    $global:ProgressPreference = 'Continue'
    if (Test-Path -Path $output_file) {
        $file = Get-Item $output_file
        $content_length_string = $response.Headers.'Content-Length'
        $content_length = [convert]::ToInt64($content_length_string, 10)
        if ($file.Length -eq $content_length) {
            Write-Host "already exists"
            return
        }
        Remove-Item -Force $output_file
    }
    $global:ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -UseBasicParsing -Uri "${root}/${_filename}" -OutFile $output_file
    $global:ProgressPreference = 'Continue'
    Write-Host "done"
}

function Get-Local-Filelist {
    param( $_folder )

    $localdir = Join-Path $DOWNLOAD_PATH -ChildPath $_folder
    if (-not (Test-Path -Path $localdir)) {
        return @()
    }

    return [array](Get-ChildItem -Path $localdir -File -Name)
}

function Get-Remote-Filelist {
    param( $_folder )

    $ret = @()
    $escaped = [uri]::EscapeUriString($_folder)
    $global:ProgressPreference = 'SilentlyContinue'
    foreach ($href in (Invoke-WebRequest -UseBasicParsing -Uri ("${_server_root}/${escaped}/")).Links.Href) {
        $unescaped = [uri]::UnescapeDataString($href)
        if (is_7zip($unescaped)) {
            Get-File $_server_root $_folder $unescaped
            $ret += $unescaped
        } elseif (is_rar($unescaped)) {
            Get-File $_server_root $_folder $unescaped
            $ret += $unescaped
        } elseif (is_zip($unescaped)) {
            Get-File $_server_root $_folder $unescaped
            $ret += $unescaped
        } elseif ($unescaped.StartsWith("?") -or ($unescaped -eq "/")) {
            # ignore sorting stuff
        } else {
            Write-Warning "Get-Remote-Filelist: unknown file type: ${unescaped}"
        }
    }
    $global:ProgressPreference = 'Continue'
    return ,$ret
}

function Get-Mod-Info-From-File {
    param( $_file )

    $contents = Get-Content -Path $_file.FullName -Raw
    $json = ConvertFrom-Json -InputObject $contents

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

function Get-Mod-Info-From-Archive {
    param( $_archive_file )

    $json = $null
    $modfile = $null
    $modfilter = '*' + [IO.Path]::DirectorySeparatorChar + 'mod.json'

    if (is_zip($_archive_file)) {
        $_cyg_zip_file = Get-Cygpath $_archive_file
        $modfile = unzip -Z1 "${_cyg_zip_file}" | Where-Object {$_ -like "*/mod.json"} | Out-String
        $modfile = $modfile.replace("`r`n", "").replace("`n", "").replace('Path = ', '')
        $contents = unzip -p "${_cyg_zip_file}" $modfile | Out-String
        $json = ConvertFrom-Json -InputObject $contents
    } elseif (is_rar($_archive_file)) {
        $modfile = unrar lb "${_archive_file}" | Where-Object {$_ -like $modfilter } | Out-String
        if ($LASTEXITCODE -gt 0) {
            throw "failed to determine mod.json path inside archive ${_archive_file}"
        }
        $modfile = $modfile.replace("`r`n", "").replace("`n", "").replace('Path = ', '')
        $contents = unrar p "${_archive_file}" $modfile | Out-String
        if ($LASTEXITCODE -gt 0) {
            throw "failed to get contents of mod.json inside archive ${_archive_file}"
        }
        $json = ConvertFrom-Json -InputObject $contents
    } elseif (is_7zip($_archive_file)) {
        $modfilter = '*/mod.json'
        $cyg_archive_file = Get-Cygpath "${_archive_file}"
        $modfile = 7z l -slt "${cyg_archive_file}" | Where-Object {$_ -like $modfilter } | Out-String
        if ($LASTEXITCODE -gt 0) {
            throw "failed to determine mod.json path inside archive ${_archive_file}"
        }
        $modfile = $modfile.replace("`r`n", "").replace("`n", "").replace('Path = ', '')
        $contents = 7z e -so "${cyg_archive_file}" "${modfile}" | Out-String
        if ($LASTEXITCODE -gt 0) {
            throw "failed to get contents of mod.json inside archive ${_archive_file}"
        }
        $json = ConvertFrom-Json -InputObject $contents
    } else {
        throw "Unknown file type: ${_archive_file}"
    }

    $_archiveInternalPath = ($modfile.ToString() -split "[/\\]")[0]

    return @{
        id = $_archiveInternalPath.ToLower()
        file = $_archive_file.ToString()
        internalPath = $_archiveInternalPath
        displayName = $json.displayName
        version = $json.version
        buildNumber = $json.buildNumber
    }
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
rsync -avr --partial --progress --no-perms --delete --exclude='*.filepart' --exclude=Depricated --exclude=Deprecated --exclude="Virtual Reality" "ln1.raccoonfink.com::mw5/" "${_local_download_path}/"

foreach ($mod_dir in $MOD_DIRS) {
    $local_filelist = Get-Local-Filelist $mod_dir

    foreach ($localfile in $local_filelist) {
        $relative_path = Join-Path -Path $mod_dir -ChildPath $localfile
        $full_path = Join-Path -Path $DOWNLOAD_PATH -ChildPath $relative_path
            $archive_modinfo = Get-Mod-Info-From-Archive($full_path)
            $active_mods[$archive_modinfo.id] = $archive_modinfo
    }
}

Write-Host ""
Write-Host "### SCANNING INSTALLED MODS ###" -ForegroundColor Cyan

$existing_modfiles = Get-ChildItem -Path $UNPACK_DIR -Filter 'mod.json' -Recurse | Sort-Object

$existing_mods = @{}

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
        Expand-Mod $active
        Write-Host "done"
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
Write-Host "Press the 'any' key to quit..."
$null = $Host.UI.RawUI.ReadKey()