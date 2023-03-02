if not defined in_subprocess (cmd /k set in_subprocess=y ^& %0 %*) & exit )

cd "%~dp0"
%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy RemoteSigned .\mw5-sync.ps1