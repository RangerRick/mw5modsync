SET MW5_PATH=C:\Program Files\Epic Games\MW5Mercs
SET DOWNLOAD_PATH=%TEMP%\MW5Mercs_mod_downloads

docker build -t mw5modsync .
docker run -v%MW5_PATH%:/opt/mw5 -v%DOWNLOAD_PATH%:/opt/downloads mw5modsync:latest
