# Path helpers for mw5-sync.

# Returns the name of the top-level directory under $unpackDir that contains the
# given mod.json.
#
# Uses GetRelativePath rather than a literal string replace because $unpackDir
# (built as ".../mods") and the on-disk path Get-ChildItem returns (".../Mods"
# on case-insensitive, case-preserving filesystems like macOS/Windows) can
# differ only in case. A case-sensitive replace would strip nothing, leave an
# absolute path, and Split('/')[0] would be "" (issue #34). GetRelativePath is
# case-insensitive on those filesystems and normalizes the path.
function Get-Mod-Internal-Path {
    param([string]$unpackDir, [string]$modJsonPath)
    $rel = [IO.Path]::GetRelativePath($unpackDir, $modJsonPath)
    return $rel.Split([IO.Path]::DirectorySeparatorChar)[0]
}
