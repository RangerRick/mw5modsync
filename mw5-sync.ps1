# SET THIS TO YOUR MECHWARRIOR 5 DIRECTORY!
$MW5_DIR="C:\Program Files\Epic Games\MW5Mercs"

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

Add-Type -Assembly System.IO.Compression.FileSystem

if (-not ${env:TEMP}) {
    ${env:TEMP} = "/tmp"
}

${env:PATH} += ";."

$UNPACK_DIR = Join-Path -Path (Join-Path -Path $MW5_DIR -ChildPath "MW5Mercs") -ChildPath "mods"
$DOWNLOAD_PATH = Join-Path -Path ${env:TEMP} -ChildPath "MW5Mercs_mod_downloads"
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

    Write-Host -NoNewline "🌎 Downloading ${_folder}/${_filename}... "
    $escaped = [uri]::EscapeUriString($_filename)
    $response = Invoke-WebRequest -Uri "${root}/${escaped}" -Method Head
    if (Test-Path -Path $output_file) {
        $file = Get-Item $output_file
        $content_length_string = $response.Headers.'Content-Length'
        $content_length = [convert]::ToInt64($content_length_string, 10)
        if ($file.Length -eq $content_length) {
            Write-Host "already exists ✅"
            return
        }
        Remove-Item -Force $output_file
    }
    Invoke-WebRequest -Uri "${root}/${_filename}" -OutFile $output_file
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
    foreach ($href in (Invoke-WebRequest -Uri ("${_server_root}/${escaped}/")).Links.Href) {
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
    return ,$ret
}

function Get-Mod-Info-From-File {
    param( $_file )

    $contents = Get-Content -Path $_file -Raw
    $json = ConvertFrom-Json -InputObject $contents
    return @{
        file = $_file.ToString()
        internalPath = $_file.ToString().Split("/")[0]
        displayName = $json.displayName
        version = $json.version
        buildNumber = $json.buildNumber
    }
}

function Get-Mod-Info-From-Archive {
    param( $_file )

    $json = $null
    $modfile = $null
    if (is_zip($_file)) {
        $zip = [IO.Compression.ZipFile]::OpenRead($_file)
        $modfile = $zip.Entries | Where-Object { $_.FullName -like '*/mod.json' }
        # Write-Host "modfile in ${_file}: ${modfile}"
        $tempFile = New-TemporaryFile
        [IO.Compression.ZipFileExtensions]::ExtractToFile($modfile, $tempFile, $true)
        $zip.Dispose()
        $contents = Get-Content -Path $tempFile -Raw
        $json = ConvertFrom-Json -InputObject $contents
        Remove-Item -Path $tempFile -Force
    } elseif (is_rar($_file)) {
        $modfile = unrar lb "${_file}" | Where-Object {$_ -like '*/mod.json' } | Out-String
        if ($LASTEXITCODE -gt 0) {
            throw "failed to determine mod.json path in ${_file}"
        }
        $modfile = $modfile.replace("`r`n", "").replace("`n", "").replace('Path = ', '')
        $contents = unrar p "${_file}" $modfile | Out-String
        if ($LASTEXITCODE -gt 0) {
            throw "failed to get contents of mod.json from ${_file}"
        }
        $json = ConvertFrom-Json -InputObject $contents
    } elseif (is_7zip($_file)) {
        $modfile = 7z l -slt "${_file}" | Where-Object {$_ -like '*/mod.json' } | Out-String
        if ($LASTEXITCODE -gt 0) {
            throw "failed to determine mod.json path in ${_file}"
        }
        $modfile = $modfile.replace("`r`n", "").replace("`n", "").replace('Path = ', '')
        $contents = 7z e -so "${_file}" $modfile | Out-String
        if ($LASTEXITCODE -gt 0) {
            throw "failed to get contents of mod.json from ${_file}"
        }
        $json = ConvertFrom-Json -InputObject $contents
    } else {
        throw "Unknown file type: ${_file}"
    }

    return @{
        file = $_file.ToString()
        internalPath = $modfile.ToString().Split("/")[0]
        displayName = $json.displayName
        version = $json.version
        buildNumber = $json.buildNumber
    }
}

function Expand-Mod {
    param($_mod)

    if (is_zip($_mod["file"])) {
        Expand-Archive -LiteralPath $_mod["file"] -DestinationPath $UNPACK_DIR -Force
    } elseif (is_rar($_mod["file"])) {
        unrar -y x -idq $_mod["file"] -op $UNPACK_DIR
    } elseif (is_7zip($_mod["file"])) {
        7z -y x $_mod["file"] "-o${UNPACK_DIR}" | Select-String "Error" -Context 10
    }
    if ($LASTEXITCODE -gt 0) {
        throw "failed to unpack file"
    }
}

function Write-Mod-Name {
    param($mod)

    Write-Host -NoNewline -ForegroundColor Green $mod.displayName
}

function Write-Mod-Version {
    param($mod)

    Write-Host -NoNewline "version "
    Write-Host -NoNewline -ForegroundColor Yellow $mod.version
    Write-Host -NoNewline ", build "
    Write-Host -NoNewline -ForegroundColor Yellow $mod.buildNumber
}

$active_mods = @{}

foreach ($mod_dir in $MOD_DIRS) {
    $remote = Get-Remote-Filelist $mod_dir
    $local = Get-Local-Filelist $mod_dir

    foreach ($localfile in $local) {
        $relative_path = Join-Path -Path $mod_dir -ChildPath $localfile
        $full_path = Join-Path -Path $DOWNLOAD_PATH -ChildPath $relative_path
        if (-not $remote.Contains($localfile)) {
            Write-Host "deleting file removed from remote: ${relative_path}"
            Remove-Item -Path $full_path -Force
        } else {
            $modinfo = Get-Mod-Info-From-Archive($full_path)
            $active_mods.Add($modinfo["internalPath"], $modinfo)
        }
    }

    foreach ($remotefile in $remote) {
        if (-not $local.Contains($remotefile)) {
            $relative_path = Join-Path -Path $mod_dir -ChildPath $remotefile
            Write-Host "found remotely, missing locally: ${relative_path}"
            throw "this should not happen"
        }
    }
}

$existing_modfiles = Get-ChildItem -Path $MW5_DIR -Filter mod.json -Recurse

$existing_mods = @{}

foreach ($existing in $existing_modfiles) {
    $modfile = $existing.ToString().replace($UNPACK_DIR + [IO.Path]::DirectorySeparatorChar, '')
    $contents = Get-Content -Path $existing -Raw
    $json = ConvertFrom-Json -InputObject $contents

    $modinfo = @{
        file = $existing
        internalPath = $modfile.ToString().Split("/")[0]
        displayName = $json.displayName
        version = $json.version
        buildNumber = $json.buildNumber
    }
    $existing_mods.Add($modinfo["internalPath"], $modinfo)
}

foreach ($key in $active_mods.Keys) {
    $active = $active_mods[$key]
    $existing = $existing_mods[$key]

    if ($existing -and ($existing.version -eq $active.version) -and ($existing.buildNumber -eq $active.buildNumber)) {
        Write-Host -NoNewline "✅ "
        Write-Mod-Name $existing
        Write-Host -NoNewline " already installed: ";
        Write-Mod-Version $existing
        Write-Host ""
    } else {
        if ($existing -and $existing.version) {
            Write-Host -NoNewline "❌ Deleting existing "
            Write-Mod-Name $existing
            Write-Mod-Version $existing
            Write-Host ""

            Remove-Item (Join-Path -Path $UNPACK_DIR -ChildPath $existing.internalPath) -Recurse -Force
        }
        Write-Host -NoNewline "🔥 "
        Write-Mod-Name $active
        Write-Host -NoNewline " new or changed: "
        if ($existing) {
            Write-Mod-Version $existing
            Write-Host -NoNewline " → "
        }
        Write-Mod-Version $active
        Write-Host ""

        Write-Host "  📦 Unpacking" (Split-Path $active.file -Leaf -Resolve)
        Expand-Mod $active
    }
}

foreach ($key in $existing_mods.Keys) {
    $active = $active_mods[$key]
    $existing = $existing_mods[$key]

    if (-not $active) {
        Write-Host -NoNewline "❌ Deleting removed ("
        Write-Mod-Version $existing
        Write-Host ") mod from $($existing.internalPath)"
        Remove-Item (Join-Path -Path $UNPACK_DIR -ChildPath $existing.internalPath) -Recurse -Force
    }
}
