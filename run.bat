@echo off
title FireTV Remapper - Smart Manager
color 0C

set IP_ADDRESS=192.168.1.7:5555

set /a COUNTER=0

adb connect %IP_ADDRESS% >nul 2>&1

echo Closing Apps...
adb -s %IP_ADDRESS% shell "am force-stop com.amazon.firebat" >nul 2>&1
adb -s %IP_ADDRESS% shell "am force-stop com.netflix.ninja" >nul 2>&1
adb -s %IP_ADDRESS% shell "am force-stop com.instantbits.cast.receiver" >nul 2>&1
adb -s %IP_ADDRESS% shell "am force-stop de.belu.appstarter" >nul 2>&1

echo Configuring permissions and script format on Fire TV...
adb -s %IP_ADDRESS% shell "chmod +x /sdcard/firetv-remapper.sh && sed -i 's/\r//g' /sdcard/firetv-remapper.sh" >nul 2>&1

adb -s %IP_ADDRESS% shell "touch /sdcard/firetv-remapper.log; pkill -f firetv-remapper; pkill -f getevent" >nul 2>&1

adb -s %IP_ADDRESS% shell "nohup sh /sdcard/firetv-remapper.sh > /sdcard/firetv-remapper.log 2>&1 &"

start "FireTV - Real-Time Log" cmd /k "for /L %%i in (1,0,2) do (adb connect 192.168.1.7:5555 & adb -s 192.168.1.7:5555 shell tail -f /sdcard/firetv-remapper.log & timeout /t 2)"

:loop
echo [%TIME%] Checking connection and status on Fire TV...

adb connect %IP_ADDRESS% >nul 2>&1

set STATUS=OK

adb -s %IP_ADDRESS% shell "pgrep -f firetv-remapper.sh" >nul 2>&1
if errorlevel 1 set STATUS=ERROR

adb -s %IP_ADDRESS% shell "pgrep -f getevent" >nul 2>&1
if errorlevel 1 set STATUS=ERROR

set /a COUNTER+=1
if %COUNTER% lss 10 goto proceed

adb -s %IP_ADDRESS% shell "if [ -f /sdcard/firetv-remapper.lock ]; then exit 0; else exit 1; fi" >nul 2>&1

if not errorlevel 1 (
    echo [%TIME%] Script busy opening an app. Postponing preventive restart...
    set /a COUNTER=9 
    goto proceed
)

echo [%TIME%] Performing periodic preventive restart (5 min)...
set STATUS=RESTART
set /a COUNTER=0

:proceed

if "%STATUS%"=="ERROR" (
    echo [%TIME%] Script or getevent stopped. Restarting...
    adb -s %IP_ADDRESS% shell "pkill -f firetv-remapper; pkill -f getevent; rm -f /sdcard/firetv-remapper.lock" >nul 2>&1
    adb -s %IP_ADDRESS% shell "nohup sh /sdcard/firetv-remapper.sh > /sdcard/firetv-remapper.log 2>&1 &"
) else if "%STATUS%"=="RESTART" (
    echo [%TIME%] Restarting the script preventively...
    adb -s %IP_ADDRESS% shell "pkill -f firetv-remapper; pkill -f getevent; rm -f /sdcard/firetv-remapper.lock" >nul 2>&1
    adb -s %IP_ADDRESS% shell "nohup sh /sdcard/firetv-remapper.sh > /sdcard/firetv-remapper.log 2>&1 &"
) else (
    echo [%TIME%] Script and getevent are running perfectly. (Cycle %COUNTER%/10)
)

timeout /t 30 /nobreak >nul
goto loop