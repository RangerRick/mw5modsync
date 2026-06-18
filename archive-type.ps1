# Archive type detection for mw5-sync.
#
# ponytail: parenthesize each predicate when combining with -or. The form
# `is_7zip($f) -or is_zip($f)` mis-parses in PowerShell as a single command
# `is_7zip` taking `($f) -or is_zip ($f)` as arguments, so -or never runs as a
# boolean operator and .zip files fall through as "unknown" (issue #32). Always
# wrap each call: `(is_7zip $f) -or (is_zip $f)`.

function is_7zip { param([string]$_file) return $_file.EndsWith(".7z", "CurrentCultureIgnoreCase") }
function is_rar  { param([string]$_file) return $_file.EndsWith(".rar", "CurrentCultureIgnoreCase") }
function is_zip  { param([string]$_file) return $_file.EndsWith(".zip", "CurrentCultureIgnoreCase") }

# True for archives unpacked with the 7z tool (.7z and .zip).
function is_7z_compatible { param([string]$_file) return (is_7zip $_file) -or (is_zip $_file) }
