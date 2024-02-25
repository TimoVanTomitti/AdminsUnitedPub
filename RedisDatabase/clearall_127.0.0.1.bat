@echo off
cd %~dp0

tasklist /FI "IMAGENAME eq redis-server.exe" 2>NUL | find /I /N "redis-server.exe">NUL
if "%ERRORLEVEL%"=="0" goto running

echo Deleting redis_atlasdb.rdb
del redis_atlasdb.rdb >nul 2>&1
goto end

:running
echo Connecting to Redis and clearing "*"
redis-cli.exe -h 127.0.0.1 -a foobared --eval clearall.lua 0 , "*"

:end 
exit
