cd %~dp0

tasklist /FI "IMAGENAME eq redis-server.exe" 2>NUL | find /I /N "redis-server.exe">NUL
if "%ERRORLEVEL%"=="0" goto end

start redis-server.exe ./redis.conf

:end
exit