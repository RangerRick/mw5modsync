$MW5_DIR="C:\Program Files\Epic Games\MW5Mercs"
$DOWNLOAD_PATH="${env:TEMP}\MW5Mercs_mod_downloads"
$MOD_DIRS = "Rise of Rasalhague", "MW2"

if (-not (Test-Path -Path $MW5_DIR)) {
    throw "${MW5_DIR} does not exist"
}

if (-not (Test-Path -Path $DOWNLOAD_PATH)) {
    New-Item -Path $DOWNLOAD_PATH -ItemType Directory
}

$_server_root="https://mw5.raccoonfink.com"

$_active_mods=@()

function Get-File {
    param(
        $_root,
        $_filename
    )

    $output_file = "${DOWNLOAD_PATH}\${_filename}"
    Write-Host -NoNewline "Downloading ${_filename} from ${_root}... "
    if (Test-Path -Path $output_file) {
        Write-Host "already exists: $output_file"
    } else {
        Invoke-WebRequest -Uri "${_root}/${_filename}" -OutFile "${DOWNLOAD_PATH}\${_filename}"
        Write-Host "done"
    }
}

function Get-Filelist {
    param(
        $_folder
    )

    foreach ($href in (Invoke-WebRequest -Uri "${_server_root}/${_folder}").Links.Href) {
        if ($href.EndsWith(".zip", "CurrentCultureIgnoreCase")) {
            Get-File "${_server_root}/${_folder}" $href
        }
    }
}

foreach ($mod_dir in $MOD_DIRS) {
    Get-Filelist $mod_dir
}