#!/usr/bin/env pwsh
# Regression test for mod path resolution (issue #34: empty internalPath when
# $UNPACK_DIR casing differs from the on-disk directory). Run:
#   pwsh test-mod-path.ps1

. (Join-Path -Path $PSScriptRoot -ChildPath 'mod-path.ps1')

$script:fail = 0
function check($label, $actual, $expected) {
    if ($actual -ne $expected) {
        Write-Host "FAIL: $label (got '$actual', want '$expected')"
        $script:fail++
    } else {
        Write-Host "ok:   $label"
    }
}

$sep = [IO.Path]::DirectorySeparatorChar
$base = "${sep}base${sep}mods"

check "simple"         (Get-Mod-Internal-Path $base "${base}${sep}Foo${sep}mod.json")          "Foo"
check "nested deeper"  (Get-Mod-Internal-Path $base "${base}${sep}Foo${sep}sub${sep}mod.json") "Foo"
check "trailing sep"   (Get-Mod-Internal-Path "${base}${sep}" "${base}${sep}Foo${sep}mod.json") "Foo"

# The actual regression: $unpackDir lowercase, on-disk path capitalized. Only
# meaningful where the runtime treats paths case-insensitively (macOS/Windows),
# which is exactly where the bug occurred.
$caseInsensitive = ([IO.Path]::GetRelativePath("${sep}b${sep}mods", "${sep}b${sep}Mods${sep}x${sep}mod.json") -eq "x${sep}mod.json")
if ($caseInsensitive) {
    check "case mismatch (issue #34)" (Get-Mod-Internal-Path $base "${sep}base${sep}Mods${sep}Foo${sep}mod.json") "Foo"
} else {
    Write-Host "skip: case-mismatch check (case-sensitive runtime)"
}

if ($script:fail -gt 0) {
    Write-Host "`n$script:fail check(s) failed"
    exit 1
}
Write-Host "`nall checks passed"
