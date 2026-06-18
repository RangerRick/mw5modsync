#!/usr/bin/env pwsh
# Regression test for archive type detection (issue #32: .zip reported as
# "Unknown file type"). Run: pwsh test-archive-detection.ps1

. (Join-Path -Path $PSScriptRoot -ChildPath 'archive-type.ps1')

$script:fail = 0
function check($label, $actual, $expected) {
    if ($actual -ne $expected) {
        Write-Host "FAIL: $label (got $actual, want $expected)"
        $script:fail++
    } else {
        Write-Host "ok:   $label"
    }
}

check "is_zip .zip"  (is_zip "mod.zip")  $true
check "is_zip .7z"   (is_zip "mod.7z")   $false
check "is_7zip .7z"  (is_7zip "mod.7z")  $true
check "is_rar .rar"  (is_rar "mod.rar")  $true

# The actual regression: a .zip must be 7z-compatible. This was false when the
# dispatch used the mis-parsing `is_7zip($f) -or is_zip($f)` form (issue #32).
check "is_7z_compatible .zip" (is_7z_compatible "Advanced Zoom-412-1-2-7.zip") $true
check "is_7z_compatible .7z"  (is_7z_compatible "YetAnotherMechlab.7z")        $true
check "is_7z_compatible .rar" (is_7z_compatible "mod.rar")                     $false
check "is_7z_compatible .txt" (is_7z_compatible "readme.txt")                  $false

if ($script:fail -gt 0) {
    Write-Host "`n$script:fail check(s) failed"
    exit 1
}
Write-Host "`nall checks passed"
