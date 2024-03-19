## Created by Icewarden for Admins United: Myth of Empires Community ##
# If you got this script anywhere other than from me directly or Admins United Discord, do not use as it could be malicious

# This script will parse the INI and create all the startup lines needed to start your grid successfully

# This Script requires you to use the MatrixServerTool to generate the ServerParamConfig_All.ini
# This script requires you to copy the MatrixServerTool folder to your dedicated server to your server path
# This Script requires you to copy the ServerParamConfig_All.ini file to a folder called "configs" under your server path!
# This script now has the ability to send messages to discord. It will require a discord bot using Express to listen on localhost. Here is the code I used:
<# 
#### DISCORD EXPRESS LISTENER ####
// Define the HTTP endpoint for sending messages
app.post('/send-message', async (req, res) => {
    const { channelId, message, secret } = req.body;

    if (secret !== 'SECRET_SQUIRREL') { // Replace SECRET_SQUIRREL with your actual secret key
        return res.status(401).send('Unauthorized');
    }

    try {
        const channel = await client.channels.fetch(channelId);
        await channel.send(message);
        res.status(200).send('Message sent successfully');
    } catch (error) {
        console.error('Error sending message:', error);
        res.status(500).send('Failed to send message');
    }
});

app.listen(port, () => {
    console.log(`Bot web server running at http://localhost:${port}`);
});
#>


# Do not edit anything in this script unless you know what you are doing, any customizations will not be supported unless I like you or you buy me cookies

# EDIT THESE BELOW #
Param (
    $serverPath = "",           # Path to your server install (Whatever your used for SteamCMD) Ex. C:\servers\moe
    $steamCMDPath = "",         # Path to SteamCMD; Ex. C:\scripts\steamcmd
    $rconPath = "",             # This is for RCON automation. Ex C:\scripts\mcrcon\mcrcon.exe
    $scriptPath = "",           # This is where you plan to put your script. its a fallback incase something breaks. 
    $privateIP = "",            # This is your private ip. Use IPCONFIG to get
    $publicIP = "",             # This is your Public IP, Use IPCHICKEN.COM
    $clusterID = 8888,          # Leave this as default. Only change if you are running multiple clusters.
    $option = "",               # StartCluster, StopCluster,RestartCluster,UpdateCluster,Help
    $enableMySQL = "true",      # Turn on MYSQL Access -> Do this is you used MariaDB
    $enableDiscord = "false",   # Turn on Discord Functions. See Requirements at top
    $discordSecret = "",        # Required for Discord Functions
    $autoprocess = "true",      # Enables loop for auto-restarts and updates
    $restartTime = "8",         # Time in Hours to reboot the server.
    ## BANNING PARAMETERS
    $steamID = "",
    $timeSpan = "",
    $banreason = ""
)
## EDIT NOTHING FURTHER ##

# Function for sending message to discord
# this requires you to be hosting a discord bot 
# that uses express to listen on 3000 at /send-message
function messageDiscord {
    param($channelId,$message,$secret)

    if (!($channelId)) {
        # If you dont pass a channel ID
        # use the below as default
        $channelId = "1210025251996704809"
    }
    if (!($secret)) {
        # Unable to send message
        Write-Host "No Secret passed cannot send"
    } Else {
        $uri = 'http://localhost:3000/send-message'
        $body = @{
            channelId = $($channelId)
            message = $($message)
            secret = $($secret)
        } | ConvertTo-Json

        Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/json"
    }
}

## Function to parse INI Configs ##
function Parse-IniFile {
    param (
        [string]$FilePath
    )

    # Initialize an empty hashtable to store the parsed data
    $parsedData = @{}

    # Ensure the file exists
    if (-Not (Test-Path $FilePath)) {
        Write-Error "File not found: $FilePath"
        return $null
    }

    # Read the INI file line by line
    $iniContent = Get-Content -Path $FilePath

    # Current section being parsed
    $currentSection = ""

    foreach ($line in $iniContent) {
        # Check if the line is a section
        if ($line -match '^\[(.+)\]$') {
            $currentSection = $matches[1]
            $parsedData[$currentSection] = @{}
        }
        # Check if the line is a key-value pair
        elseif ($line -match '^(.+)=(.+)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            $parsedData[$currentSection][$key] = $value
        }
    }

    # Return the parsed data
    return $parsedData
}

## DO NOT TOUCH ##
# Path Configuration
$gamePath = Join-Path $serverPath "MOE\Binaries\Win64\MOEServer.exe"
$clusterTools = Join-Path $serverPath "MatrixServerTool"
$optPath = Join-Path $clusterTools "game-opt-sys.exe"
$chatPath = Join-Path $clusterTools "game-chat-service.exe"
$ServerIni = Join-path $serverPath "configs\ServerParamConfig_All.ini"
$pidPath = Join-path $serverPath "pids"
# Checking that they exist
if (!(Test-Path $pidPath)) {
    # Need this for tracking the server Process IDs
    mkdir $pidPath
}
if (!(Test-Path $gamePath)) {
    throw "Missing Game Files at $gamePath - Make Sure to install MoE Lol"
}
if (!(Test-Path $optPath)) {
    throw "Missing $optPath - Make sure to copy the MatrixServerTool Folder from your Game files to your root server folder"
}
if (!(Test-Path $chatPath)) {
    throw "Missing $chatPath - Make sure to copy the MatrixServerTool Folder from your Game files to your root server folder"
}
if (!(Test-Path $serverIni)) {
    throw "Missing $serverIni - Make sure to copy the ServerParamConfig_All.ini from your Client to the configs folder in server location"
}
if (Test-Path $rconPath) {
    # RCON Exists, good job!
    Set-Alias rcon $rconPath
} else {
    Write-Host "RCON IS MISSING FROM $rconPath -> Skipping RCON Setup!"
}

Try {
    $serverConfig = Parse-IniFile -FilePath $ServerIni
} Catch {
    Write-Error "Failed to Parse INI File $serverIni `r`n $($_.Server.Exception)"
    Exit 1
}

# Function to Start the server 
# this will save the process ID to a pid file so we can 
# rerun this script to fix any failures if something happens to crash
# we can also use the pids for quick checking of other features
function StartServer {
    param ($serverPath, $argumentLine, $pidPath)

    Try {
        $process = Start-Process $serverPath $argumentLIne -PassThru -ErrorAction Stop
        $process.Id | Out-File $pidPath
        Write-Host "Successfully Started $($serverPath) with PID: $($process.Id)"
    } Catch {
        Write-Error "Failed to Start the server: $_"
    }
}

# Function to shutdown the cluster
function ShutdownCluster {
    param($serverConfig, $pidPath)
    # We will use this option to completely restart the entire cluster, either for updates or just to reboot it
    # Save/Shutdown the Scenes
    Foreach ($key in $serverConfig.Keys) {
        if ($key -match "^SceneServerList_\d+$") {
            $sceneServer = $serverConfig[$key]
            # RCON Usage
            # -p Password
            # -P port
            # -H host
            # -c Command
            Write-Host "Saving World $($sceneServer["SceneID"])"
            rcon -p $sceneServer["SceneRemotePassword"] -P $sceneServer["SceneClosePort"] -H $sceneServer["SceneRemoteAddr"] -s "saveworld"
            Start-Sleep -s 30
            rcon -p $sceneServer["SceneRemotePassword"] -P $sceneServer["SceneClosePort"] -H $sceneServer["SceneRemoteAddr"] -s "ShutDownServer"
        }
    }
    # Save/Shutdown Battlefield Servers
    Foreach ($key in $serverConfig.Keys) {
        if ($key -match "^BattleServerList_\d+$") {
            $battleServer = $serverConfig[$key]
            # RCON Usage
            # -p Password
            # -P port
            # -H host
            # -c Command
            Write-Host "Saving World $($battleServer["BattleID"])"
            rcon -p $battleServer["BattleRemotePassword"] -P $battleServer["BattleClosePort"] -H $battleServer["BattleRemoteAddr"] -s "saveworld"
            Start-Sleep -s 30
            rcon -p $battleServer["BattleRemotePassword"] -P $battleServer["BattleClosePort"] -H $battleServer["BattleRemoteAddr"] -s "ShutDownServer"
        }
    }
    # Save/Shutdown Lobby and Pub
    rcon -p $serverConfig["LobbyServerInfo"]["LobbyRemotePassword"] -P $serverConfig["LobbyServerInfo"]["LobbyClosePort"] -H $serverConfig["LobbyServerInfo"]["LobbyRemoteAddr"] -s "saveworld"
    rcon -p $serverConfig["LobbyServerInfo"]["LobbyRemotePassword"] -P $serverConfig["LobbyServerInfo"]["LobbyClosePort"] -H $serverConfig["LobbyServerInfo"]["LobbyRemoteAddr"] -s "ShutDownServer"
    rcon -p $serverConfig["PubDataServerInfo"]["PubDataRemotePassword"] -P $serverConfig["PubDataServerInfo"]["PubDataClosePort"] -H $serverConfig["PubDataServerInfo"]["PubDataRemoteAddr"] -s "saveworld"
    rcon -p $serverConfig["PubDataServerInfo"]["PubDataRemotePassword"] -P $serverConfig["PubDataServerInfo"]["PubDataClosePort"] -H $serverConfig["PubDataServerInfo"]["PubDataRemoteAddr"] -s "ShutDownServer"
    # We will use the PIDs to shutdown everything else
    $pidFiles = Get-ChildItem $pidPath 
    Foreach ($item in $pidFiles) {
        $serverPID = Get-Content $item.FullName
        Get-Process -id $serverPID -ErrorAction SilentlyContinue | Stop-Process 
    }
}

# Function to start the entire cluster
# super crazy
function StartCluster {
    param($gamePath,$chatPath,$optPath,$serverConfig,$pidPath,$scriptPath,$serverPath)

    # Lets clean up the log files, there's too many of them:
    # There's 2 logging directories. Until we can figure out what the logging argument is for chat server/opt server
    # Logging Directory #1 -> <Path_to_this_script>\chat_logs & logs
    # Logging Directory #2 -> <Path_to_server>\MOE\Saved\Logs
    # We are going to keep the last 2 log files on restart
    Write-Host "Cleaning Log files"
    If ($scriptPath) {
        $chatLogPath = Join-Path $scriptPath "chat_logs"
        $optLogPath = Join-Path $scriptPath "logs"
        # Delete chat logs except last 2
        if (Test-Path $chatLogPath) {
            $chatLogs = GCI -Path $chatLogPath -File | Sort-Object -Property LastWriteTime -Descending | Select-OBject -Skip 2
            Foreach ($log in $chatLogs) {
                Remove-Item -Path $log.FullName -Force
            }
        }
        
        # Delete OPT Logs except last 2
        if (Test-Path $optLogPath) {
            $optLogs = GCI -Path $optLogPath -File | Sort-Object -Property LastWriteTime -Descending | Select-OBject -Skip 2
            Foreach ($log in $optLogs) {
                Remove-Item -Path $log.FullName -Force
            }
        }
    }
    # Now we will clean up the server log directory
    $serverLogPath = Join-Path $serverPath "MOE\Saved\Logs"
    if (Test-Path $serverLogPath) {
        $allLogs = Get-ChildItem -Path $serverLogPath -File
        # regex to group logs based on their IDs.
        $groupedLogs = $allLogs | Group-Object -Property {
            if ($_.Name -match '^(.+?_\d+)') {
                return $matches[1]
            } else {
                # In case the log has no ID
                $_.Name -match '^(.*?)[_\.]' | Out-Null; $matches[1]
            }
        }
        Foreach ($group in $groupedLogs) {
            $sortedLogs = $group.Group | Sort-Object LastWriteTime -Descending
            $logsToDelete = $sortedLogs | Select-Object -Skip 2
            Foreach ($log in $logsToDelete) {
                Remove-Item -path $log.FullName -Force
            }
        }
    }
    
    # Step 1 - Launch Database Servers
    ## Public Data Server
    # Build Argument Line for PubServer
    ## DO NOT TOUCH UNLESS YOU KNOW WHAT YOU'RE DOING ##
    $pubServerArgumentLine = "Map_Public -game -server -ClusterId=$($clusterID) -DataStore -log -StartBattleService -StartPubData " + `
    "-BigPrivateServer -DistrictId=1 -LOCALLOGTIMES -NetServerMaxTickRate=1000 -HangDuration=300 -core " + `
    "-NotCheckServerSteamAuth -MultiHome=$($privateIP) -OutAddress=$($publicIP) -Port=$($serverConfig["PubDataServerInfo"]["PubDataGamePort"]) " + `
    "-QueryPort=$($serverConfig["PubDataServerInfo"]["PubDataQueryPort"]) -ShutDownServicePort=$($serverConfig["PubDataServerInfo"]["PubDataClosePort"]) " + `
    "-ShutDownServiceIP=$($serverConfig["PubDataServerInfo"]["PubDataRemoteAddr"]) -ShutDownServiceKey=$($serverConfig["PubDataServerInfo"]["PubDataRemotePassword"]) " + ` 
    "-SessionName=PubDataServer_90000 -ServerId=$($serverConfig["PubDataServerInfo"]["PubDataServerID"]) log=PubDataServer_90000.log " + `
    "-PubDataAddr=$($serverConfig["PubDataServerInfo"]["PubDataAddr"]) -PubDataPort=$($serverConfig["PubDataServerInfo"]["PubDataPort"]) " + ` 
    "-DBAddr=$($serverConfig["AroundServerInfo"]["DBStoreAddr"]) -DBPort=$($serverConfig["AroundServerInfo"]["DBStorePort"]) " + ` 
    "-BattleAddr=$($serverConfig["AroundServerInfo"]["BattleManagerAddr"]) -BattlePort=$($serverConfig["AroundServerInfo"]["BattleManagerPort"]) " + ` 
    "-ChatServerAddr=$($serverConfig["AroundServerInfo"]["ChatServerAddr"]) -ChatServerPort=$($serverConfig["AroundServerInfo"]["ChatServerPort"]) " + `
    "-ChatClientAddress=$($serverConfig["AroundServerInfo"]["ChatClientAddr"]) -ChatServerPort=$($serverConfig["AroundServerInfo"]["ChatClientAddr"]) -ChatClientPort=$($serverConfig["AroundServerInfo"]["ChatClientPort"]) " + `
    "-ChatServerPort=$($serverConfig["AroundServerInfo"]["ChatClientPort"]) " + ` 
    "-OptEnable=1 -OptAddr=$($serverConfig["AroundServerInfo"]["OptToolAddr"]) -OptPort=$($serverConfig["AroundServerInfo"]["GatewayPort"]) " + `
    "-MaxPlayers=100 " + ` 
    "-MapDifficultyRate=1 -UseACE -EnableVACBan=1"

    if ($($serverConfig["BaseServerConfig"]["NoticeSelfEnable"]) -eq "1") {
        # Notifications Enabled
        $pubServerArgumentLine += " -NoticeSelfEnable=true"
    }
    # Start the Pub Server Control
    $serverCheck = $null
    $pubAppID = $null
    $pubPIDPath = join-path $pidPath "pub.pid"
    if (Test-Path $pubPIDPath) {
        # Exists
        $pubAppID = Get-COntent $pubPIDPath
    }
    Try {
        $serverCheck = Get-Process -id $pubAppID -ErrorAction Stop
    } Catch {
        StartServer $gamePath $pubServerArgumentLine $pubPIDPath
    } 

    ## Chat Service Server
    # Build Argument Line for ChatService
    ## DO NOT TOUCH UNLESS YOU KNOW WHAT YOU'RE DOING ##
    $chatServiceArgumentLine = "-BigPrivateServer " + `
    "-ChatServerAddr=$($serverConfig["AroundServerInfo"]["ChatServerAddr"]) -ChatServerPort=$($serverConfig["AroundServerInfo"]["ChatServerPort"]) " + `
    "-ChatClientAddress=$($serverConfig["AroundServerInfo"]["ChatClientAddr"]) -ChatClientPort=$($serverConfig["AroundServerInfo"]["ChatClientPort"]) " + `
    "-RedisUrl=$($serverConfig["AroundServerInfo"]["RedisAddr"]):$($serverConfig["AroundServerInfo"]["RedisPort"])"
    if ($($serverConfig["AroundServerInfo"]["RedisPassword"])) {
        $chatServiceArgumentLine += " -RedisAuth=$($serverConfig["AroundServerInfo"]["RedisPassword"])"
    }
    # Start the Chat Service
    $serverCheck = $null
    $chatAppID = $null
    $chatPIDPath = Join-Path $pidPath "chat.pid"
    if (Test-Path $chatPIDPath) {
        $chatAppID = Get-Content $chatPIDPath
    }
    Try {
        $serverCheck = Get-Process -id $chatAppID -ErrorAction Stop
    } Catch {
        StartServer $chatPath $chatServiceArgumentLine $chatPIDPath
    }

    ## Opt Service Server
    # Build Argument Line for OptService
    ## DO NOT TOUCH UNLESS YOU KNOW WHAT YOU'RE DOING ##
    $optArgumentLine = "-b=true " + `
    "-LogLevel=1 " + `
    "-GatewayAddr=$($privateIP):$($serverConfig["AroundServerInfo"]["GatewayPort"]) " + `
    "-RankClientAddr=$($privateIP):$($serverConfig["AroundServerInfo"]["RankListPort"]) " + `
    "-GlobalRankClientAddr=$($privateIP):$($serverConfig["AroundServerInfo"]["GlobalRankListPort"]) " + `
    "-MarketClientAddr=$($privateIP):$($serverConfig["AroundServerInfo"]["MarketPort"]) " + `
    "-RedisURL=$($serverConfig["AroundServerInfo"]["RedisAddr"]):$($serverConfig["AroundServerInfo"]["RedisPort"])"

    if ($enableMySQL -like "true") {
        $optArgumentLIne += " -MysqlURL=$($serverConfig["DatabaseConfig"]["OptDatabaseAddr"]):$($serverConfig["DatabaseConfig"]["OptDatabasePort"]) " + `
        "-MysqlUser=$($serverConfig["DatabaseConfig"]["OptDatabaseUserName"]) " + `
        "-MysqlPwd=`"$($serverConfig["DatabaseConfig"]["OptDatabasePassword"])`" " + `
        "-MysqlDBName=$($serverConfig["DatabaseConfig"]["OptDatabaseCatalog"])"
    }

    if ($($serverConfig["AroundServerInfo"]["RedisPassword"])) {
        $optArgumentLine += " -RedisPass=$($serverConfig["AroundServerInfo"]["RedisPassword"])"
    }
    # Start the Opt Service with the game executable path
    $serverCheck = $null
    $optAppID = $null
    $optPIDPath = Join-Path $pidPath "opt.pid"
    if (Test-Path $optPIDPath) {
        $optAppID = Get-Content $optPIDPath
    }
    Try {
        $serverCheck = Get-Process -id $optAppID -ErrorAction Stop
    } Catch {
        StartServer $optPath $optArgumentLine $optPIDPath
    }

    ## Lobby Service Server
    # Build Argument Line for LobbyService
    ## DO NOT TOUCH UNLESS YOU KNOW WHAT YOU'RE DOING ##
    $lobbyArgumentLine = "Map_Lobby -game -server -ClusterId=$($clusterID) -DataStore -log -StartBattleService -StartPubData " + `
    "-BigPrivateServer -LaunchMMOServer -DistrictId=1 -LOCALLOGTIMES -core -NetServerMaxTickRate=100 -HangDuration=300 -NotCheckServerSteamAuth " + `
    "-LobbyPort=$($serverConfig["LobbyServerInfo"]["LobbyPort"]) -MultiHome=$($privateIP) " + `
    "-OutAddress=$($publicIP) -Port=$($serverConfig["LobbyServerInfo"]["LobbyGamePort"]) -QueryPort=$($serverConfig["LobbyServerInfo"]["LobbyQueryPort"]) " + `
    "-ShutDownServicePort=$($serverConfig["LobbyServerInfo"]["LobbyClosePort"]) -ShutDownServiceIP=$($serverConfig["LobbyServerInfo"]["LobbyRemoteAddr"]) " + `
    "-ShutDownServiceKey=$($serverConfig["LobbyServerInfo"]["LobbyRemotePassword"]) -MaxPlayers=$($serverConfig["LobbyServerInfo"]["LobbyMaxPlayers"]) " + `
    "-mmo_storeserver_addr=$($serverConfig["AroundServerInfo"]["DBStoreAddr"]) -mmo_storeserver_port=$($serverConfig["AroundServerInfo"]["DBStorePort"]) " + `
    "-mmo_battlemanagerserver_addr=$($serverConfig["AroundServerInfo"]["BattleManagerAddr"]) -mmo_battlemanagerserver_port=$($serverConfig["AroundServerInfo"]["BattleManagerPort"]) " + `
    "-SessionName=`"$($serverConfig["LobbyServerInfo"]["ServerListName"])`" -ServerId=$($serverConfig["LobbyServerInfo"]["LobbyServerID"]) log=LobbyServer_$($serverConfig["LobbyServerInfo"]["LobbyServerID"]).log " + `
    "-PubDataAddr=$($serverConfig["PubDataServerInfo"]["PubDataAddr"]) -PubDataPort=$($serverConfig["PubDataServerInfo"]["PubDataPort"]) " + ` 
    "-DBAddr=$($serverConfig["AroundServerInfo"]["DBStoreAddr"]) -DBPort=$($serverConfig["AroundServerInfo"]["DBStorePort"]) " + `
    "-BattleAddr=$($serverConfig["AroundServerInfo"]["BattleManagerAddr"]) -BattlePort=$($serverConfig["AroundServerInfo"]["BattleManagerPort"]) " + `
    "-ChatServerAddr=$($serverConfig["AroundServerInfo"]["ChatServerAddr"]) -ChatServerPort=$($serverConfig["AroundServerInfo"]["ChatServerPort"]) " + `
    "-ChatClientAddress=$($serverConfig["AroundServerInfo"]["ChatClientAddr"]) -ChatClientPort=$($serverConfig["AroundServerInfo"]["ChatClientPort"]) " + `
    "-OptEnable=1 -OptAddr=$($serverConfig["AroundServerInfo"]["OptToolAddr"]) -OptPort=$($serverConfig["AroundServerInfo"]["GatewayPort"]) " + `
    "-MaxPlayers=$($serverConfig["BaseServerConfig"]["MaxPlayers"]) " + `
    "-MapDifficultyRate=1 -UseACE -EnableVACBan=1"

    if ($($serverConfig["BaseServerConfig"]["NoticeSelfEnable"]) -eq "1") {
        # Notifications Enabled
        $lobbyArgumentLine += " -NoticeSelfEnable=true"
    }
    if ($($serverConfig["LobbyServerInfo"]["LobbyPassword"])) {
        $lobbyArgumentLine += " -PrivateServerPassword=$($serverConfig["LobbyServerInfo"]["LobbyPassword"])"
    }
    # Same thing for Description
    if ($($serverConfig["BaseServerConfig"]["Description"])) {
        $lobbyArgumentLine += " -Description=`"$($serverConfig["BaseServerConfig"]["Description"])`" "
    }

    if ($enableMySQL -like "true") {
        $lobbyArgumentLine += " -mmo_storeserver_type=Mysql " + ` 
        "-mmo_storeserver_role_connstr=`"Provider=MYSQLDB;SslMode=None;Password=$($serverConfig["DatabaseConfig"]["RoleDatabasePassword"]);User ID=$($serverConfig["DatabaseConfig"]["RoleDatabaseUserName"]);Initial Catalog=$($serverConfig["DatabaseConfig"]["RoleDatabaseCatalog"]);Data Source=$($serverConfig["DatabaseConfig"]["RoleDatabaseAddr"]):$($serverConfig["DatabaseConfig"]["RoleDatabasePort"])`" " + `
        "-mmo_storeserver_public_connstr=`"Provider=MYSQLDB;SslMode=None;Password=$($serverConfig["DatabaseConfig"]["PublicDatabasePassword"]);User ID=$($serverConfig["DatabaseConfig"]["PublicDatabaseUserName"]);Initial Catalog=$($serverConfig["DatabaseConfig"]["PublicDatabaseCatalog"]);Data Source=$($serverConfig["DatabaseConfig"]["PublicDatabaseAddr"]):$($serverConfig["DatabaseConfig"]["PublicDatabasePort"])`""
    }
    # Start the Lobby Service with the game executable path
    $serverCheck = $null
    $lobbyAppID = $null
    $lobbyPIDPath = Join-Path $pidPath "lobby.pid"
    if (Test-Path $lobbyPIDPath) {
        $lobbyAppID = Get-Content $lobbyPIDPath
    }
    Try {
        $serverCheck = Get-Process -id $lobbyAppID -ErrorAction Stop
    } Catch {
        StartServer $gamePath $lobbyArgumentLine $lobbyPIDPath
    }


    ## ARGUMENT LISTS FOR GRIDS ##
    # Complete construction of $generalizedArguments with all generalized settings
    $generalizedArguments = @"
    -WildAnimalLifeMultiplier=$($serverConfig["BaseServerConfig"]["WildAnimalLifeMultiplier"]) `
    -WildAnimalDamageMultiplier=$($serverConfig["BaseServerConfig"]["WildAnimalDamageMultiplier"]) `
    -WildAnimalBeInjuredMultiplier=$($serverConfig["BaseServerConfig"]["WildAnimalBeInjuredMultiplier"]) `
    -WildAnimalLifeRecoveryMultiplier=$($serverConfig["BaseServerConfig"]["WildAnimalLifeRecoveryMultiplier"]) `
    -HumanoidLifeMultiplier=$($serverConfig["BaseServerConfig"]["HumanoidLifeMultiplier"]) `
    -HumanoidDamageMultiplier=$($serverConfig["BaseServerConfig"]["HumanoidDamageMultiplier"]) `
    -HumanoidBeInjuredMultiplier=$($serverConfig["BaseServerConfig"]["HumanoidBeInjuredMultiplier"]) `
    -HumanoidLifeRecoveryMultiplier=$($serverConfig["BaseServerConfig"]["HumanoidLifeRecoveryMultiplier"]) `
    -TameAnimalLifeMultiplier=$($serverConfig["BaseServerConfig"]["TameAnimalLifeMultiplier"]) `
    -TameAnimalDamageMultiplier=$($serverConfig["BaseServerConfig"]["TameAnimalDamageMultiplier"]) `
    -TameAnimalBeInjuredMultiplier=$($serverConfig["BaseServerConfig"]["TameAnimalBeInjuredMultiplier"]) `
    -TameAnimalLifeRecoveryMultiplier=$($serverConfig["BaseServerConfig"]["TameAnimalLifeRecoveryMultiplier"]) `
    -GeneralLifeMultiplier=$($serverConfig["BaseServerConfig"]["GeneralLifeMultiplier"]) `
    -GeneralDamageMultiplier=$($serverConfig["BaseServerConfig"]["GeneralDamageMultiplier"]) `
    -GeneralBeInjuredMultiplier=$($serverConfig["BaseServerConfig"]["GeneralBeInjuredMultiplier"]) `
    -GeneralLifeRecoveryMultiplier=$($serverConfig["BaseServerConfig"]["GeneralLifeRecoveryMultiplier"]) `
    -GeneralLoadMultiplier=$($serverConfig["BaseServerConfig"]["GeneralLoadMultiplier"]) `
    -MoveSeatLoadMultiplier=$($serverConfig["BaseServerConfig"]["MoveSeatLoadMultiplier"]) `
    -TameAnimalSatietyMultiplier=$($serverConfig["BaseServerConfig"]["TameAnimalSatietyMultiplier"]) `
    -TameAnimalDeclineOfSatietyMultiplier=$($serverConfig["BaseServerConfig"]["TameAnimalDeclineOfSatietyMultiplier"]) `
    -TameAnimalLoadMultiplier=$($serverConfig["BaseServerConfig"]["TameAnimalLoadMultiplier"]) `
    -TameAnimalBodyStrengthMultiplier=$($serverConfig["BaseServerConfig"]["TameAnimalBodyStrengthMultiplier"]) `
    -TameAnimalLifeCountMultiplier=$($serverConfig["BaseServerConfig"]["TameAnimalLifeCountMultiplier"]) `
    -TameAnimalDeathReduceLifeCountMultiplier=$($serverConfig["BaseServerConfig"]["TameAnimalDeathReduceLifeCountMultiplier"]) `
    -TameGeneralDeathReduceLifeCountMultiplier=$($serverConfig["BaseServerConfig"]["TameGeneralDeathReduceLifeCountMultiplier"]) `
    -TameAnimalSpeedMultiplier=$($serverConfig["BaseServerConfig"]["TameAnimalSpeedMultiplier"]) `
    -TameAnimalHeatResistanceMultiplier=$($serverConfig["BaseServerConfig"]["TameAnimalHeatResistanceMultiplier"]) `
    -TameAnimalColdResistanceMultiplier=$($serverConfig["BaseServerConfig"]["TameAnimalColdResistanceMultiplier"]) `
    -TameAnimalPoisonResistanceMultiplier=$($serverConfig["BaseServerConfig"]["TameAnimalPoisonResistanceMultiplier"]) `
    -TameGeneralHeatResistanceMultiplier=$($serverConfig["BaseServerConfig"]["TameGeneralHeatResistanceMultiplier"]) `
    -TameGeneralColdResistanceMultiplier=$($serverConfig["BaseServerConfig"]["TameGeneralColdResistanceMultiplier"]) `
    -TameGeneralPoisonResistanceMultiplier=$($serverConfig["BaseServerConfig"]["TameGeneralPoisonResistanceMultiplier"]) `
    -GeneralHeatResistanceRecover=$($serverConfig["BaseServerConfig"]["GeneralHeatResistanceRecover"]) `
    -GeneralColdResistanceRecover=$($serverConfig["BaseServerConfig"]["GeneralColdResistanceRecover"]) `
    -GeneralPoisonResistanceRecover=$($serverConfig["BaseServerConfig"]["GeneralPoisonResistanceRecover"]) `
    -SaveGameIntervalMinute=$($serverConfig["BaseServerConfig"]["SaveGameIntervalMinute"]) `
    -bUseDurable=$($serverConfig["BaseServerConfig"]["bUseDurable"]) `
    -bRiderUseShooterMovingCheck=$($serverConfig["BaseServerConfig"]["bRiderUseShooterMovingCheck"]) `
    -NpcSpawnMultiplier=$($serverConfig["BaseServerConfig"]["NpcSpawnMultiplier"]) `
    -InitCapitalCopper=$($serverConfig["BaseServerConfig"]["InitCapitalCopper"]) `
    -bDeadCorpseCreateBag=$($serverConfig["BaseServerConfig"]["bDeadCorpseCreateBag"]) `
    -bOpenWillDead=$($serverConfig["BaseServerConfig"]["bOpenWillDead"]) `
    -bAllCanRescue=$($serverConfig["BaseServerConfig"]["bAllCanRescue"]) `
    -bCanDropItem=$($serverConfig["BaseServerConfig"]["bCanDropItem"]) `
    -bShowFleshPhysicialMaterialEffect=$($serverConfig["BaseServerConfig"]["bShowFleshPhysicialMaterialEffect"]) `
    -AITurretTraceProjectileRatio=$($serverConfig["BaseServerConfig"]["AITurretTraceProjectileRatio"]) `
    -MaxActiveCharacterCountConfig=$($serverConfig["BaseServerConfig"]["MaxActiveCharacterCountConfig"]) `
    -MaxActiveStructureCountConfig=$($serverConfig["BaseServerConfig"]["MaxActiveStructureCountConfig"]) `
    -NormalReduceDurableMultiplier=$($serverConfig["BaseServerConfig"]["NormalReduceDurableMultiplier"]) `
    -SleepPlayerCharacterDestroyDays=$($serverConfig["BaseServerConfig"]["SleepPlayerCharacterDestroyDays"]) `
    -ServerLevelAddMul=$($serverConfig["BaseServerConfig"]["ServerLevelAddMul"]) `
    -FoodBuffValueMulti=$($serverConfig["BaseServerConfig"]["FoodBuffValueMulti"]) `
    -MedicineBuffValueMulti=$($serverConfig["BaseServerConfig"]["MedicineBuffValueMulti"]) `
    -ItemCDMulti=$($serverConfig["BaseServerConfig"]["ItemCDMulti"]) `
    -FoodMedicineWineBuffTimeMulti=$($serverConfig["BaseServerConfig"]["FoodMedicineWineBuffTimeMulti"]) `
    -ButterflyDropMul=$($serverConfig["BaseServerConfig"]["ButterflyDropMul"]) `
    -UnLockSkillPriceMul=$($serverConfig["BaseServerConfig"]["UnLockSkillPriceMul"]) `
    -FubenCoolDownMultiplier=$($serverConfig["BaseServerConfig"]["FubenCoolDownMultiplier"]) `
    -KillNpcConflictValueMul=$($serverConfig["BaseServerConfig"]["KillNpcConflictValueMul"]) `
    -AddTameMulti=$($serverConfig["BaseServerConfig"]["AddTameMulti"]) `
    -CallHorseDistance=$($serverConfig["BaseServerConfig"]["CallHorseDistance"]) `
    -NUM_AllGeneralMax=$($serverConfig["BaseServerConfig"]["NUM_AllGeneralMax"]) `
    -NUM_WarGeneralMax=$($serverConfig["BaseServerConfig"]["NUM_WarGeneralMax"]) `
    -bLimitTameHorseNum=$($serverConfig["BaseServerConfig"]["bLimitTameHorseNum"]) `
    -NUM_AllHorseMax=$($serverConfig["BaseServerConfig"]["NUM_AllHorseMax"]) `
    -bLimitWarHorseNum=$($serverConfig["BaseServerConfig"]["bLimitWarHorseNum"]) `
    -NUM_WarHorseMax=$($serverConfig["BaseServerConfig"]["NUM_WarHorseMax"]) `
    -TameAnimalMatingSpeedMultiplier=$($serverConfig["BaseServerConfig"]["TameAnimalMatingSpeedMultiplier"]) `
    -TameAnimalMatingCDMultiplier=$($serverConfig["BaseServerConfig"]["TameAnimalMatingCDMultiplier"]) `
    -BabyAnimalGrowthRateMultiplier=$($serverConfig["BaseServerConfig"]["BabyAnimalGrowthRateMultiplier"]) `
    -BabyAnimalFoodConsumptionRateMultiplier=$($serverConfig["BaseServerConfig"]["BabyAnimalFoodConsumptionRateMultiplier"]) `
    -GeneralExpMultiplier=$($serverConfig["BaseServerConfig"]["GeneralExpMultiplier"]) `
    -GeneralTalentExpMultiplier=$($serverConfig["BaseServerConfig"]["GeneralTalentExpMultiplier"]) `
    -OneDayGeneralWagesMulti=$($serverConfig["BaseServerConfig"]["OneDayGeneralWagesMulti"]) `
    -GeneralSeatWorkAddHungerMulti=$($serverConfig["BaseServerConfig"]["GeneralSeatWorkAddHungerMulti"]) `
    -ServerGeneralCharAddExpMultiplier=$($serverConfig["BaseServerConfig"]["ServerGeneralCharAddExpMultiplier"]) `
    -ServerAnimalCharAddExpMultiplier=$($serverConfig["BaseServerConfig"]["ServerAnimalCharAddExpMultiplier"]) `
    -WorldGeneralRebornTimeMulti=$($serverConfig["BaseServerConfig"]["WorldGeneralRebornTimeMulti"]) `
    -AnimalVehicleRebornTimeMul=$($serverConfig["BaseServerConfig"]["AnimalVehicleRebornTimeMul"]) `
    -NpcStaticBossSpawnIntervalMultiplier=$($serverConfig["BaseServerConfig"]["NpcStaticBossSpawnIntervalMultiplier"]) `
    -ItemCraftRepairTimeMulti=$($serverConfig["BaseServerConfig"]["ItemCraftRepairTimeMulti"]) `
    -ItemReforgeTimeMulti=$($serverConfig["BaseServerConfig"]["ItemReforgeTimeMulti"]) `
    -CharacterCorpseLifespan=$($serverConfig["BaseServerConfig"]["CharacterCorpseLifespan"]) `
    -AnimalCorpseLifespan=$($serverConfig["BaseServerConfig"]["AnimalCorpseLifespan"]) `
    -DeathItemContainerLifeTime=$($serverConfig["BaseServerConfig"]["DeathItemContainerLifeTime"]) `
    -DropItemContainerLifeTime=$($serverConfig["BaseServerConfig"]["DropItemContainerLifeTime"]) `
    -PlayerRespawnCantBeDamageTime=$($serverConfig["BaseServerConfig"]["PlayerRespawnCantBeDamageTime"]) `
    -PlayerRespawnTime=$($serverConfig["BaseServerConfig"]["PlayerRespawnTime"]) `
    -MurderRespawnTime=$($serverConfig["BaseServerConfig"]["MurderRespawnTime"]) `
    -MaxMurderRespawnTime=$($serverConfig["BaseServerConfig"]["MaxMurderRespawnTime"]) `
    -RecordLastDamageTimeSpan=$($serverConfig["BaseServerConfig"]["RecordLastDamageTimeSpan"]) `
    -AccidentRespawnTime=$($serverConfig["BaseServerConfig"]["AccidentRespawnTime"]) `
    -MaxAccidentRespawnTime=$($serverConfig["BaseServerConfig"]["MaxAccidentRespawnTime"]) `
    -RecordDeatheCountTimeSpan=$($serverConfig["BaseServerConfig"]["RecordDeatheCountTimeSpan"]) `
    -CollectMaxMultiplier=$($serverConfig["BaseServerConfig"]["CollectMaxMultiplier"]) `
    -CollectPlantRecoverMultiplier=$($serverConfig["BaseServerConfig"]["CollectPlantRecoverMultiplier"]) `
    -CollectStoneRecoverMultiplier=$($serverConfig["BaseServerConfig"]["CollectStoneRecoverMultiplier"]) `
    -CropGrowthMultiplier=$($serverConfig["BaseServerConfig"]["CropGrowthMultiplier"]) `
    -CropCollectMultiplier=$($serverConfig["BaseServerConfig"]["CropCollectMultiplier"]) `
    -CropLandTickInterval=$($serverConfig["BaseServerConfig"]["CropLandTickInterval"]) `
    -CropWaterConsumeMultiplier=$($serverConfig["BaseServerConfig"]["CropWaterConsumeMultiplier"]) `
    -CollectDamageMultiplier=$($serverConfig["BaseServerConfig"]["CollectDamageMultiplier"]) `
    -PickStoneRefreshRate=$($serverConfig["BaseServerConfig"]["PickStoneRefreshRate"]) `
    -PickWoodRefreshRate=$($serverConfig["BaseServerConfig"]["PickWoodRefreshRate"]) `
    -StoneLv1RefreshRate=$($serverConfig["BaseServerConfig"]["StoneLv1RefreshRate"]) `
    -BigStoneLv1RefreshRate=$($serverConfig["BaseServerConfig"]["BigStoneLv1RefreshRate"]) `
    -SmallStoneLv1RefreshRate=$($serverConfig["BaseServerConfig"]["SmallStoneLv1RefreshRate"]) `
    -StoneLv2RefreshRate=$($serverConfig["BaseServerConfig"]["StoneLv2RefreshRate"]) `
    -StoneLv3RefreshRate=$($serverConfig["BaseServerConfig"]["StoneLv3RefreshRate"]) `
    -StoneLv4RefreshRate=$($serverConfig["BaseServerConfig"]["StoneLv4RefreshRate"]) `
    -TreeLv1RefreshRate=$($serverConfig["BaseServerConfig"]["TreeLv1RefreshRate"]) `
    -TreeLv2RefreshRate=$($serverConfig["BaseServerConfig"]["TreeLv2RefreshRate"]) `
    -Treelv3RefreshRate=$($serverConfig["BaseServerConfig"]["Treelv3RefreshRate"]) `
    -TreeLv4RefreshRate=$($serverConfig["BaseServerConfig"]["TreeLv4RefreshRate"]) `
    -BushRefreshRate=$($serverConfig["BaseServerConfig"]["BushRefreshRate"]) `
    -BigBushRefreshRate=$($serverConfig["BaseServerConfig"]["BigBushRefreshRate"]) `
    -RareBushRefreshRate=$($serverConfig["BaseServerConfig"]["RareBushRefreshRate"]) `
    -SulphurOreRefreshRate=$($serverConfig["BaseServerConfig"]["SulphurOreRefreshRate"]) `
    -CoalOreRefreshRate=$($serverConfig["BaseServerConfig"]["CoalOreRefreshRate"]) `
    -CopperOreRefreshRate=$($serverConfig["BaseServerConfig"]["CopperOreRefreshRate"]) `
    -IronOreRefreshRate=$($serverConfig["BaseServerConfig"]["IronOreRefreshRate"]) `
    -DarkSteelOreRefreshRate=$($serverConfig["BaseServerConfig"]["DarkSteelOreRefreshRate"]) `
    -AerosiderdliteOreRefreshRate=$($serverConfig["BaseServerConfig"]["AerosiderdliteOreRefreshRate"]) `
    -JadeOreRefreshRate=$($serverConfig["BaseServerConfig"]["JadeOreRefreshRate"]) `
    -KaolinOreRefreshRate=$($serverConfig["BaseServerConfig"]["KaolinOreRefreshRate"]) `
    -WetMoundOreRefreshRate=$($serverConfig["BaseServerConfig"]["WetMoundOreRefreshRate"]) `
    -RealgarOraRefreshRate=$($serverConfig["BaseServerConfig"]["RealgarOraRefreshRate"]) `
    -SaltOreRefreshRate=$($serverConfig["BaseServerConfig"]["SaltOreRefreshRate"]) `
    -SaltpeterOreRefreshRate=$($serverConfig["BaseServerConfig"]["SaltpeterOreRefreshRate"]) `
    -PeaRefreshRate=$($serverConfig["BaseServerConfig"]["PeaRefreshRate"]) `
    -GoldenCauliflowerRefreshRate=$($serverConfig["BaseServerConfig"]["GoldenCauliflowerRefreshRate"]) `
    -HoneysucklesRefreshRate=$($serverConfig["BaseServerConfig"]["HoneysucklesRefreshRate"]) `
    -NotoginsengRefreshRate=$($serverConfig["BaseServerConfig"]["NotoginsengRefreshRate"]) `
    -PolygonumhydropiperRefreshRate=$($serverConfig["BaseServerConfig"]["PolygonumhydropiperRefreshRate"]) `
    -SandonionRefreshRate=$($serverConfig["BaseServerConfig"]["SandonionRefreshRate"]) `
    -CodonopsisRefreshRate=$($serverConfig["BaseServerConfig"]["CodonopsisRefreshRate"]) `
    -DragonbloodRefreshRate=$($serverConfig["BaseServerConfig"]["DragonbloodRefreshRate"]) `
    -PersonalOreFactoryMul=$($serverConfig["BaseServerConfig"]["PersonalOreFactoryMul"]) `
    -PublicOreFactoryMul=$($serverConfig["BaseServerConfig"]["PublicOreFactoryMul"]) `
    -bCloseDamage=$($serverConfig["BaseServerConfig"]["bCloseDamage"]) `
    -ShooterHostileDamageMultiplier=$($serverConfig["BaseServerConfig"]["ShooterHostileDamageMultiplier"]) `
    -MeleeHostileDamageMultiplier=$($serverConfig["BaseServerConfig"]["MeleeHostileDamageMultiplier"]) `
    -ShooterFriendDamageMultiplier=$($serverConfig["BaseServerConfig"]["ShooterFriendDamageMultiplier"]) `
    -MeleeFriendDamageMultiplier=$($serverConfig["BaseServerConfig"]["MeleeFriendDamageMultiplier"]) `
    -StructureDamageMultiplier=$($serverConfig["BaseServerConfig"]["StructureDamageMultiplier"]) `
    -StructureReturnDamageMultiplier=$($serverConfig["BaseServerConfig"]["StructureReturnDamageMultiplier"]) `
    -FinalDamageMultiplier=$($serverConfig["BaseServerConfig"]["FinalDamageMultiplier"]) `
    -AddExpMultiplier=$($serverConfig["BaseServerConfig"]["AddExpMultiplier"]) `
    -ServerPlayerCharAddExpMultiplier=$($serverConfig["BaseServerConfig"]["ServerPlayerCharAddExpMultiplier"]) `
    -PlayerCollectionExpMultiplier=$($serverConfig["BaseServerConfig"]["PlayerCollectionExpMultiplier"]) `
    -PlayerKillMonstersExpMultiplier=$($serverConfig["BaseServerConfig"]["PlayerKillMonstersExpMultiplier"]) `
    -InitDefaultCraftPerkPoint=$($serverConfig["BaseServerConfig"]["InitDefaultCraftPerkPoint"]) `
    -InitDefaultPerkPoint=$($serverConfig["BaseServerConfig"]["InitDefaultPerkPoint"]) `
    -PlayerLifeMultiplier=$($serverConfig["BaseServerConfig"]["PlayerLifeMultiplier"]) `
    -PlayerBodyStrengthMultiplier=$($serverConfig["BaseServerConfig"]["PlayerBodyStrengthMultiplier"]) `
    -PlayerSatietyMultiplier=$($serverConfig["BaseServerConfig"]["PlayerSatietyMultiplier"]) `
    -PlayerLoadMultiplier=$($serverConfig["BaseServerConfig"]["PlayerLoadMultiplier"]) `
    -PlayerSpeedMultiplier=$($serverConfig["BaseServerConfig"]["PlayerSpeedMultiplier"]) `
    -HungryDecreaseMultiplier=$($serverConfig["BaseServerConfig"]["HungryDecreaseMultiplier"]) `
    -SPDecreaseMultiplier=$($serverConfig["BaseServerConfig"]["SPDecreaseMultiplier"]) `
    -SkillExpMultiplier=$($serverConfig["BaseServerConfig"]["SkillExpMultiplier"]) `
    -bDeathOnlyReduceDurable=$($serverConfig["BaseServerConfig"]["bDeathOnlyReduceDurable"]) `
    -BattleServerReduceShortCutDurablePercent=$($serverConfig["BaseServerConfig"]["BattleServerReduceShortCutDurablePercent"]) `
    -BattleServerReduceEquipDurablePercent=$($serverConfig["BaseServerConfig"]["BattleServerReduceEquipDurablePercent"]) `
    -BattleServerReduceInventoryDurablePercent=$($serverConfig["BaseServerConfig"]["BattleServerReduceInventoryDurablePercent"]) `
    -PlayerLifeRecoverySpeedMultiplier=$($serverConfig["BaseServerConfig"]["PlayerLifeRecoverySpeedMultiplier"]) `
    -PlayerStaminaRecoverySpeedMultiplier=$($serverConfig["BaseServerConfig"]["PlayerStaminaRecoverySpeedMultiplier"]) `
    -PlayerHeatResistanceMultiplier=$($serverConfig["BaseServerConfig"]["PlayerHeatResistanceMultiplier"]) `
    -PlayerColdResistanceMultiplier=$($serverConfig["BaseServerConfig"]["PlayerColdResistanceMultiplier"]) `
    -PlayerPoisonResistanceMultiplier=$($serverConfig["BaseServerConfig"]["PlayerPoisonResistanceMultiplier"]) `
    -PlayerHeatResistanceRecover=$($serverConfig["BaseServerConfig"]["PlayerHeatResistanceRecover"]) `
    -PlayerColdResistanceRecover=$($serverConfig["BaseServerConfig"]["PlayerColdResistanceRecover"]) `
    -PlayerPoisonResistanceRecover=$($serverConfig["BaseServerConfig"]["PlayerPoisonResistanceRecover"]) `
    -bShowLevelNameHUD=$($serverConfig["BaseServerConfig"]["bShowLevelNameHUD"]) `
    -OnlyShowLevelDistance=$($serverConfig["BaseServerConfig"]["OnlyShowLevelDistance"]) `
    -ShowLevelNameDistance=$($serverConfig["BaseServerConfig"]["ShowLevelNameDistance"]) `
    -bUseFightBillboard=$($serverConfig["BaseServerConfig"]["bUseFightBillboard"]) `
    -bShowDefaultBillboard=$($serverConfig["BaseServerConfig"]["bShowDefaultBillboard"]) `
    -bShowEnemyBillboard=$($serverConfig["BaseServerConfig"]["bShowEnemyBillboard"]) `
    -ShowBillboardDistance=$($serverConfig["BaseServerConfig"]["ShowBillboardDistance"]) `
    -bShowFriendlyBillboard=$($serverConfig["BaseServerConfig"]["bShowFriendlyBillboard"]) `
    -ShowEnemyBillboardDistance=$($serverConfig["BaseServerConfig"]["ShowEnemyBillboardDistance"]) `
    -StructureCreateHPMultiplier=$($serverConfig["BaseServerConfig"]["StructureCreateHPMultiplier"]) `
    -StructureRepairHPMultiplier=$($serverConfig["BaseServerConfig"]["StructureRepairHPMultiplier"]) `
    -AnimalFarmDropMul=$($serverConfig["BaseServerConfig"]["AnimalFarmDropMul"]) `
    -OccupyTiroMaxNum=$($serverConfig["BaseServerConfig"]["OccupyTiroMaxNum"]) `
    -OccupyTiroDestroyMultiplier=$($serverConfig["BaseServerConfig"]["OccupyTiroDestroyMultiplier"]) `
    -FishMaxNum=$($serverConfig["BaseServerConfig"]["FishMaxNum"]) `
    -FishDropIntervalMultiplier=$($serverConfig["BaseServerConfig"]["FishDropIntervalMultiplier"]) `
    -MaxStructureMul=$($serverConfig["BaseServerConfig"]["MaxStructureMul"]) `
    -OccupyUpdateCoolTimeMultiplier=$($serverConfig["BaseServerConfig"]["OccupyUpdateCoolTimeMultiplier"]) `
    -ExpToGuildActivityPointMul=$($serverConfig["BaseServerConfig"]["ExpToGuildActivityPointMul"]) `
    -MaxGuildActivityPointMul=$($serverConfig["BaseServerConfig"]["MaxGuildActivityPointMul"]) `
    -GuildRenameCDHour=$($serverConfig["BaseServerConfig"]["GuildRenameCDHour"]) `
    -GuildSetImageCDHour=$($serverConfig["BaseServerConfig"]["GuildSetImageCDHour"]) `
    -OccupyMaxProtectHour=$($serverConfig["BaseServerConfig"]["OccupyMaxProtectHour"]) `
    -DisablePCE=$($serverConfig["BaseServerConfig"]["DisablePCE"]) `
    -GuildMaxMember=$($serverConfig["BaseServerConfig"]["GuildMaxMember"]) `
    -OccupyStructureLimitNum=$($serverConfig["BaseServerConfig"]["OccupyStructureLimitNum"]) `
    -PVEOnlySelfGuildPickUpDeathPackage=$($serverConfig["BaseServerConfig"]["PVEOnlySelfGuildPickUpDeathPackage"]) `
    -OccupySellTotalMultiplier=$($serverConfig["BaseServerConfig"]["OccupySellTotalMultiplier"]) `
    -OccupySellNumMultiplier=$($serverConfig["BaseServerConfig"]["OccupySellNumMultiplier"]) "
"@


    $pveArguments = @"
    -GeneralQualityMultiPVEGreen=$($serverConfig["BaseServerConfig"]["GeneralQualityMultiPVEGreen"]) `
    -GeneralQualityMultiPVEBlue=$($serverConfig["BaseServerConfig"]["GeneralQualityMultiPVEBlue"]) `
    -GeneralQualityMultiPVEPurse=$($serverConfig["BaseServerConfig"]["GeneralQualityMultiPVEPurse"]) `
    -GeneralQualityMultiPVEOrange=$($serverConfig["BaseServerConfig"]["GeneralQualityMultiPVEOrange"]) `
    -GeneralQualityMultiPVERed=$($serverConfig["BaseServerConfig"]["GeneralQualityMultiPVERed"]) `
    -HorseMaxQualityCorrectionPVE=$($serverConfig["BaseServerConfig"]["HorseMaxQualityCorrectionPVE"]) `
    -CollectPlantMultiplierPVE=$($serverConfig["BaseServerConfig"]["CollectPlantMultiplierPVE"]) `
    -CollectHunterMultiplierPVE=$($serverConfig["BaseServerConfig"]["CollectHunterMultiplierPVE"]) `
    -CollectStoneMultiplierPVE=$($serverConfig["BaseServerConfig"]["CollectStoneMultiplierPVE"]) `
    -CapitalDropRatioPVE=$($serverConfig["BaseServerConfig"]["CapitalDropRatioPVE"]) `
    -OccupyDecayHPMultiplierPVE=$($serverConfig["BaseServerConfig"]["OccupyDecayHPMultiplierPVE"]) `
    -OccupyDecayHPInOtherAreaMultiplierPVE=$($serverConfig["BaseServerConfig"]["OccupyDecayHPInOtherAreaMultiplierPVE"]) `
    -OccupyBaseStructureNumPVE=$($serverConfig["BaseServerConfig"]["OccupyBaseStructureNumPVE"])
"@

    $pvpArguments = @"
    -GeneralQualityMultiPVPGreen=$($serverConfig["BaseServerConfig"]["GeneralQualityMultiPVPGreen"]) `
    -GeneralQualityMultiPVPBlue=$($serverConfig["BaseServerConfig"]["GeneralQualityMultiPVPBlue"]) `
    -GeneralQualityMultiPVPPurse=$($serverConfig["BaseServerConfig"]["GeneralQualityMultiPVPPurse"]) `
    -GeneralQualityMultiPVPOrange=$($serverConfig["BaseServerConfig"]["GeneralQualityMultiPVPOrange"]) `
    -GeneralQualityMultiPVPRed=$($serverConfig["BaseServerConfig"]["GeneralQualityMultiPVPRed"]) `
    -HorseMaxQualityCorrection=$($serverConfig["BaseServerConfig"]["HorseMaxQualityCorrection"]) `
    -CollectPlantMultiplier=$($serverConfig["BaseServerConfig"]["CollectPlantMultiplier"]) `
    -CollectHunterMultiplier=$($serverConfig["BaseServerConfig"]["CollectHunterMultiplier"]) `
    -CollectStoneMultiplier=$($serverConfig["BaseServerConfig"]["CollectStoneMultiplier"]) `
    -CapitalDropRatioPVP=$($serverConfig["BaseServerConfig"]["CapitalDropRatioPVP"]) `
    -OccupyDecayHPMultiplier=$($serverConfig["BaseServerConfig"]["OccupyDecayHPMultiplier"]) `
    -OccupyDecayHPInOtherAreaMultiplier=$($serverConfig["BaseServerConfig"]["OccupyDecayHPInOtherAreaMultiplier"]) `
    -OccupyBaseStructureNum=$($serverConfig["BaseServerConfig"]["OccupyBaseStructureNum"])
"@

    # Loop through SCENE Servers
    Foreach ($key in $serverConfig.Keys) {
        if ($key -match "^SceneServerList_\d+$") {
            $sceneServer = $serverConfig[$key]
            # Construct the base argument line for each grid
            $gridArgumentLine = "$($sceneServer["SceneMap"]) -game -server -ClusterId=$clusterID -DataStore " + `
            "-log -StartBattleService -StartPubData -BigPrivateServer -DistrictId=1 -EnableParallelTickFunction -DisablePhysXSimulation -LOCALLOGTIMES " + `
            "-corelimit=5 -core -HangDuration=300 -NotCheckServerSteamAuth -ServerAdminAccounts=$($serverConfig["BaseServerConfig"]["ServerAdminAccounts"]) " + `
            "-CityId=$($sceneServer["SceneCityID"]) -XianchengId=$($sceneServer["SceneXianchengID"]) " + ` 
            "-GameServerPVPType=$($sceneServer["ScenePVPType"]) -MultiHome=$($privateIP) -OutAddress=$($publicIP) " + `
            "-Port=$($sceneServer["SceneGamePort"]) -QueryPort=$($sceneServer["SceneQueryPort"]) -ShutDownServicePort=$($sceneServer["SceneClosePort"]) " + `
            "-ShutDownServiceIP=$($sceneServer["SceneRemoteAddr"]) -ShutDownServiceKey=$($sceneServer["SceneRemotePassword"]) " + `
            "-MaxPlayers=$($serverConfig["BaseServerConfig"]["MaxPlayers"]) -SessionName=SceneServer_$($sceneServer["SceneID"]) -ServerId=$($sceneServer["SceneID"]) log=SceneServer_$($sceneServer["SceneID"]).log " + `
            "-PubDataAddr=$($serverConfig["PubDataServerInfo"]["PubDataAddr"]) -PubDataPort=$($serverConfig["PubDataServerInfo"]["PubDataPort"]) " + `
            "-DBAddr=$($serverConfig["AroundServerInfo"]["DBStoreAddr"]) -DBPort=$($serverConfig["AroundServerInfo"]["DBStorePort"]) " + `
            "-BattleAddr=$($serverConfig["AroundServerInfo"]["BattleManagerAddr"]) -BattlePort=$($serverConfig["AroundServerInfo"]["BattleManagerPort"]) " + `
            "-ChatServerAddr=$($serverConfig["AroundServerInfo"]["ChatServerAddr"]) -ChatServerPort=$($serverConfig["AroundServerInfo"]["ChatServerPort"]) " + `
            "-ChatClientAddress=$($serverConfig["AroundServerInfo"]["ChatClientAddr"]) -ChatClientPort=$($serverConfig["AroundServerInfo"]["ChatClientPort"]) " + `
            "-OptEnable=1 -OptAddr=$($serverConfig["AroundServerInfo"]["OptToolAddr"]) -OptPort=$($serverConfig["AroundServerInfo"]["GatewayPort"]) " + `
            "-MaxPlayers=$($sceneServer["SceneMaxPlayers"]) " + `
            "-MapDifficultyRate=$($serverConfig["BaseServerConfig"]["MapDifficultyRate"]) -UseACE -EnableVACBan=1 "
            
            if ($($serverConfig["BaseServerConfig"]["bEnableServerLevel"]) -eq "0") {
                # Disable bEnableServerLevel
                $gridArgumentLine += " -bEnableServerLevel=false"
            }
            if ($($serverConfig["BaseServerConfig"]["NoticeSelfEnable"]) -eq "1") {
                # Notifications Enabled
                $gridArgumentLine += " -NoticeSelfEnable=true"
            }
            # Enter/Exit Server notifications:
            if ($($serverConfig["BaseServerConfig"]["NoticeAllEnable"]) -eq "1") {
                $gridArgumentLine += " -NoticeAllEnable=true"
            }
            # Something weird happened here. if NoticeSelfEnterServer is blank in the config, for some reason it just feeds the next argument
            # as the Enter Server notice. So we are just going to do a fun check now. 
            if ($($serverConfig["BaseServerConfig"]["NoticeSelfEnterServer"])) {
                $gridArgumentLine += " -NoticeSelfEnterServer=`"$($serverConfig["BaseServerConfig"]["NoticeSelfEnterServer"])`" "
            }
            # Same thing for Description
            if ($($serverConfig["BaseServerConfig"]["Description"])) {
                $gridArgumentLine += " -Description=`"$($serverConfig["BaseServerConfig"]["Description"])`" "
            }
            # Append generalized arguments
            $gridArgumentLine += $generalizedArguments

            # Determine if the server is PVP or PVE and append the appropriate arguments
            if ($($sceneServer["ScenePVPType"]) -eq "1") { # PVE
                $gridArgumentLine += $pveArguments
            } else { # PVP
                $gridArgumentLine += $pvpArguments
            }
            $serverCheck = $null
            $sceneAppID = $null
            $scenePIDPath = Join-Path $pidPath "$($sceneServer["SceneID"]).pid"
            if (Test-Path $scenePIDPath) {
                $sceneAppID = Get-Content $scenePIDPath
            }
            Try {
                $serverCheck = Get-Process -id $sceneAppID -ErrorAction Stop
            } Catch {
                StartServer $gamePath $gridArgumentLine $scenePIDPath
            }
            Start-Sleep -s 10
        }
    }
    # Loop through Battlefield Servers
    Foreach ($key in $serverConfig.Keys) {
        if ($key -match "^BattleServerList_\d+$") {
            # BAttlefield Argument List
            $battleServer = $serverConfig[$key]
            $battleMap = $($battleServer["BattleMap"] -replace '^\d+_', '')
            $battlefieldArgumentLine = "$($battlemap) -game -server -ClusterId=$($clusterID) -DataStore " + `
            "-log -StartBattleService -StartPubData -BigPrivateServer -DistrictId=1 -EnableParallelTickFunction -DisablePhysXSimulation " + `
            "-LOCALLOGTIMES -corelimit=5 -core -HangDuration=300 -NotCheckServerSteamAuth " + `
            "-MultiHome=$($battleServer["BattleInnerAddr"]) -OutAddress=$($battleServer["BattleOuterAddr"]) -Port=$($battleServer["BattleGamePort"]) " + `
            "-QueryPort=$($battleServer["BattleQueryPort"]) -ShutDownServicePort=$($battleServer["BattleClosePort"]) -ShutDownServiceIP=$($battleServer["BattleRemoteAddr"]) -ShutDownServiceKey=$($battleServer["BattleRemotePassword"]) " + `
            "-MaxPlayers=$($battleServer["BattleMaxPlayers"]) -SessionName=battlefield_$($battleServer["BattleID"]) -ServerId=$($battleServer["BattleID"]) log=BattleServer_$($battleServer["BattleID"]).log " + `
            "-PubDataAddr=$($serverConfig["PubDataServerInfo"]["PubDataAddr"]) -PubDataPort=$($serverConfig["PubDataServerInfo"]["PubDataPort"]) -DBAddr=$($serverConfig["AroundServerInfo"]["DBStoreAddr"]) -DBPort=$($serverConfig["AroundServerInfo"]["DBStorePort"]) " + `
            "-BattleAddr=$($serverConfig["AroundServerInfo"]["BattleManagerAddr"]) -BattlePort=$($serverConfig["AroundServerInfo"]["BattleManagerPort"]) " + `
            "-ChatServerAddr=$($serverConfig["AroundServerInfo"]["ChatServerAddr"]) -ChatServerPort=$($serverConfig["AroundServerInfo"]["ChatServerPort"]) " + `
            "-ChatClientAddress=$($serverConfig["AroundServerInfo"]["ChatClientAddr"]) -ChatClientPort=$($serverConfig["AroundServerInfo"]["ChatClientPort"]) " + `
            "-OptEnable=1 -OptAddr=$($serverConfig["AroundServerInfo"]["OptToolAddr"]) -OptPort=$($serverConfig["AroundServerInfo"]["GatewayPort"]) " + `
            "-Description=`"$($serverConfig["BaseServerConfig"]["Description"])`" -NoticeSelfEnable=$($serverConfig["BaseServerConfig"]["NoticeSelfEnable"]) " + `
            "-NoticeSelfEnterServer=`"$($serverConfig["BaseServerConfig"]["NoticeSelfEnterServer"])`" -MapDifficultyRate=$($serverConfig["BaseServerConfig"]["MapDifficultyRate"]) " + `
            "-UseACE=$($serverConfig["BaseServerConfig"]["UseACE"]) -EnableVACBan=$($serverConfig["BaseServerConfig"]["EnableVACBan"]) " + `
            "-bUseServerAdmin=$($serverConfig["BaseServerConfig"]["bUseServerAdmin"]) -ServerAdminAccounts=$($serverConfig["BaseServerConfig"]["ServerAdminAccounts"]) " + ` 
            "-NoticeAllEnable=$($serverConfig["BaseServerConfig"]["NoticeAllEnable"]) -MoveSeatLoadMultiplier=$($serverConfig["BaseServerConfig"]["MoveSeatLoadMultiplier"]) " + `
            "-TameAnimalLoadMultiplier=$($serverConfig["BaseServerConfig"]["TameAnimalLoadMultiplier"]) -NUM_AllHorseMax=$($serverConfig["BaseServerConfig"]["NUM_AllHorseMax"]) " + `
            "-ServerGeneralCharAddExpMultiplier=$($serverConfig["BaseServerConfig"]["ServerGeneralCharAddExpMultiplier"]) " + `
            "-ServerAnimalCharAddExpMultiplier=$($serverConfig["BaseServerConfig"]["ServerAnimalCharAddExpMultiplier"]) " + `
            "-CharacterCorpseLifespan=$($serverConfig["BaseServerConfig"]["CharacterCorpseLifespan"]) -PlayerRespawnCantBeDamageTime=$($serverConfig["BaseServerConfig"]["PlayerRespawnCantBeDamageTime"]) " + `
            "-CropCollectMultiplier=$($serverConfig["BaseServerConfig"]["CropCollectMultiplier"]) -CapitalDropRatioPVP=$($serverConfig["BaseServerConfig"]["CapitalDropRatioPVP"]) " + `
            "-CapitalDropRatioPVE=$($serverConfig["BaseServerConfig"]["CapitalDropRatioPVE"]) -PersonalOreFactoryMul=$($serverConfig["BaseServerConfig"]["PersonalOreFactoryMul"]) " + `
            "-ServerPlayerCharAddExpMultiplier=$($serverConfig["BaseServerConfig"]["ServerPlayerCharAddExpMultiplier"]) " + ` 
            "-PlayerLoadMultiplier=$($serverConfig["BaseServerConfig"]["PlayerLoadMultiplier"]) -AnimalFarmDropMul=$($serverConfig["BaseServerConfig"]["AnimalFarmDropMul"]) " + `
            "-ExpToGuildActivityPointMul=$($serverConfig["BaseServerConfig"]["ExpToGuildActivityPointMul"]) -MaxGuildActivityPointMul=$($serverConfig["BaseServerConfig"]["MaxGuildActivityPointMul"]) " + `
            "-GuildRenameCDHour=$($serverConfig["BaseServerConfig"]["GuildRenameCDHour"]) -PVEOnlySelfGuildPickUpDeathPackage=$($serverConfig["BaseServerConfig"]["PVEOnlySelfGuildPickUpDeathPackage"])"
            # Something weird happened here. if NoticeSelfEnterServer is blank in the config, for some reason it just feeds the next argument
            # as the Enter Server notice. So we are just going to do a fun check now. 
            if ($($serverConfig["BaseServerConfig"]["NoticeSelfEnterServer"])) {
                $battlefieldArgumentLine += "-NoticeSelfEnterServer=`"$($serverConfig["BaseServerConfig"]["NoticeSelfEnterServer"])`" "
            }
            # Same thing for Description
            if ($($serverConfig["BaseServerConfig"]["Description"])) {
                $battlefieldArgumentLine += "-Description=`"$($serverConfig["BaseServerConfig"]["Description"])`" "
            }
            
            $serverCheck = $null
            $battlefieldPIDPath = Join-Path $pidPath "bf-$($battleServer["BattleID"]).pid"
            if (Test-Path $battlefieldPIDPath) {
                $battlefieldAppID = Get-Content $battlefieldPIDPath
                Try {
                    Write-Host "Checking $($battlefieldPIDPath)"
                    $serverCheck = Get-Process -id $battlefieldAppID -ErrorAction Stop
                } Catch {
                    StartServer $gamePath $battlefieldArgumentLIne $battlefieldPIDPath
                }
            } Else {
                # PID Doesn't exist so just start it
                StartServer $gamePath $battlefieldArgumentLIne $battlefieldPIDPath
            }
        }
    }
} # End Start Cluster -> What a doozy whew

function CheckUpdate {
    param ($serverPath,$steamcmdFolder,$pidPath,$serverConfig)
    $steamAppID="1794810"
    # Without clearing cache app_info_update may return old informations!
    $clearCache=1
    $dataPath = Join-Path $serverPath "updatedata"
    $steamcmdExec = $steamcmdFolder+"\steamcmd.exe"
    $steamcmdCache = $steamcmdFolder+"\appcache"
    $latestAppInfo = $dataPath+"\latestappinfo.json"
    $updateinprogress = $serverPath+"\updateinprogress.dat"
    $latestAvailableUpdate = $dataPath+"\latestavailableupdate.txt"
    $latestInstalledUpdate = $dataPath+"\latestinstalledupdate.txt"

    If (Test-Path $updateinprogress) {
    Write-Host Update is already in progress could be broke
    } Else {
        Get-Date | Out-File $updateinprogress
        Write-Host "Creating data Directory"
        New-Item -Force -ItemType directory -Path $dataPath
        If ($clearCache) {
        Write-Host "Removing Cache Folder"
        Remove-Item $steamcmdCache -Force -Recurse
        }
        # Check for Update here by getting versions from SteamDB vs SteamCMD
        Write-Host "Checking for an update for $($serverPath)"
        & $steamcmdExec +login anonymous +app_info_update 1 +app_info_print $steamAppID +app_info_print $steamAppID +logoff +quit | Out-File $latestAppInfo
        Get-Content $latestAppInfo -RAW | Select-String -pattern '(?m)"public"\s*\{\s*"buildid"\s*"\d{6,}"' -AllMatches | %{$_.matches[0].value} | Select-String -pattern '\d{6,}' -AllMatches | %{$_.matches} | %{$_.value} | Out-File $latestAvailableUpdate

        # Read current installed version file
        If (Test-Path $latestInstalledUpdate) {
            $installedVersion = Get-Content $latestInstalledUpdate
        } Else {
            $installedVersion = 0
        }
        # Read Latest Version in SteamDB
        $availableVersion = Get-Content $latestAvailableUpdate
        # If Versions don't match, lets update!
        if ($installedVersion -ne $availableVersion) {
            Write-Host "Update Available"
            Write-Host "Installed build: $installedVersion - available build: $availableVersion"
            if ($enableDiscord -eq "true") {
                messageDiscord -message "MoE Cluster rebooting for update in 5 minutes." -secret $discordSecret
                Start-Sleep -s 500
            }
            # Grab the PID Files
            $pidFiles = Get-ChildItem $pidPath
            if (!($pidFiles.Count -le 1)) {
                # Lets check to see if servers are running
                $serverCheck = $false
                Foreach ($item in $pidFiles) {
                    $appPID = Get-Content $item.FullName
                    Try {
                        Get-Process -id $appPID -ErrorAction Stop
                        $serverCheck = $true
                    } Catch {
                        # Server not running
                        Continue
                    }
                }
            }
            
            # Shutdown the servers! This Section is custom to MythOfEmpires
            # we have no known way to send broadcast AFAIK so RIP
            if ($serverCheck) {
                ShutDownCluster -serverConfig $serverConfig -pidPath $pidPath
            }
			# Lets give it enough time to finish everything properly
            Start-Sleep -s 15
            # Make sure everything is offline.
            # Kinda redundant since we are blowing up the PIDs 
            if (!($pidFiles.Count -le 1)) {
                Foreach ($item in $pidFiles) {
                    $serverPID = Get-Content $item.FullName
                    While (Get-Process -id $serverPID -ErrorAction SilentlyContinue) {
                        Write-Host "Waiting for $serverPID to shutdown...."
                        Start-Sleep -s 3
                    }
                    Get-Process -id $serverPID -ErrorAction SilentlyContinue | Stop-Process 
                }
            }
			# Lets Boogie! 
            Write-host "Starting Update....This could take a few minutes..."
            & $steamcmdExec +force_install_dir $serverPath +login anonymous +app_update $steamAppID validate +quit | Out-File $latestAppInfo
            $availableVersion | Out-File $latestInstalledUpdate
            Write-Host "Update Done!"
            Remove-Item $updateinprogress -Force
            $updated = $true
            return $updated
        } Else {
            Write-Host 'No Update Available!'
			if (Test-Path $updateinprogress) {
                $updated = $false
				Remove-Item $updateinprogress -Force
                return $updated
			}
        }
    } 
} # End Check Update Function

function moe-readBans {
    param($serverConfig) 

    $dllPath = "C:\scripts\ExternalUtilities\MySql.Data.dll"
    if (!(test-path $dllPath)) {
        # DLL missing
        Write-HOst "MySQL.Data.DLL Missing, cant connect to database.."
        return
    }

    # Import the DLL
    Add-Type -Path $dllPath

    # Setup the MySQL Connection
    $ConnectionString = "server=localhost;" +
                        "port=3306;" + # Specify the port number here
                        "user=$($serverConfig["DatabaseConfig"]["PublicDatabaseUserName"]);" +
                        "password=$($serverConfig["DatabaseConfig"]["PublicDatabasePassword"]);" +
                        "database=moe_banlist"

    $Connection = New-Object MySql.Data.MySqlClient.MySqlConnection
    $Connection.ConnectionString = $ConnectionString
    $Connection.Open()

    try {
        $sqlCheckTable = @"
SELECT COUNT(*)
FROM information_schema.tables 
WHERE table_schema = 'moe_banlist' 
AND table_name = 'moe_banlist';
"@
        $cmdCheckTable = New-Object MySql.Data.MySqlClient.MySqlCommand($sqlCheckTable, $Connection)
        $tableExists = $cmdCheckTable.ExecuteScalar()
        if ($tableExists -eq 0) {
            Write-Host "Table moe_banlist does not exist. Skipping BanList Check. Please re-read documentation!"
            return
        }
        # Select all from the moe_banlist table
        $sql = "SELECT steamid, UnbanTime FROM moe_banlist"
        $cmd = New-Object MySql.Data.MySqlClient.MySqlCommand($sql, $Connection)
        $reader = $cmd.ExecuteReader()
        while ($reader.Read()) {
            $steamID = $reader["steamid"]
            $unbanTimeStr = $reader["UnbanTime"]
            $currentTime = Get-Date

            if ($currentTime -gt $unbanTime) {
                # Unban time has passed, delete the entry and run the unban command
                $reader.Close()
                $sqlDelete = "DELETE FROM moe_banlist WHERE steamid = '$steamID'"
                $cmdDelete = New-Object MySql.Data.MySqlClient.MySqlCommand($sqlDelete, $Connection)
                $cmdDelete.ExecuteNonQuery()

                # Run the unban command
                Write-Host "Unbanning $steamID"
                rcon -p $($serverConfig["LobbyServerInfo"]["LobbyRemotePassword"]) -P $($serverConfig["LobbyServerInfo"]["LobbyClosePort"]) -H $($serverConfig["LobbyServerInfo"]["LobbyRemoteAddr"]) -s "PrivateServerRemoveBlockList $steamID"
                # Now run it across all scene servers
                Foreach ($key in $serverConfig.Keys) {
                    if ($key -match "^SceneServerList_\d+$") {
                        $sceneServer = $serverConfig[$key]
                        rcon -p $($sceneServer["SceneRemotePassword"]) -P $($sceneServer["SceneClosePort"]) -H $($sceneServer["SceneRemoteAddr"]) -s "PrivateServerRemoveBlockList $steamID"
                    }
                }
                $reader = $cmd.ExecuteReader() # Re-open reader for remaining rows
            } else {
                # Unban time has not passed, execute the ban command
                Write-Host "Banning $steamID"
                rcon -p $($serverConfig["LobbyServerInfo"]["LobbyRemotePassword"]) -P $($serverConfig["LobbyServerInfo"]["LobbyClosePort"]) -H $($serverConfig["LobbyServerInfo"]["LobbyRemoteAddr"]) -s "PrivateServerAddBlockList $steamID"
                # Now run it across all scene servers
                Foreach ($key in $serverConfig.Keys) {
                    if ($key -match "^SceneServerList_\d+$") {
                        $sceneServer = $serverConfig[$key]
                        rcon -p $($sceneServer["SceneRemotePassword"]) -P $($sceneServer["SceneClosePort"]) -H $($sceneServer["SceneRemoteAddr"]) -s "PrivateServerAddBlockList $steamID"
                    }
                }
            }
        }
    } finally {
        $Connection.Close()
    }
}

function moe-addBan {
    param($steamID,$timeSpan,$reason,$serverConfig) 

    $dllPath = "C:\scripts\ExternalUtilities\MySql.Data.dll"
    if (-not (Test-Path $dllPath)) {
        Write-Host "MySql.Data.dll is missing!! Please review the instructions at the top of this script!"
        Exit 1
    }
    # Import the MySql.Data.dll
    Add-Type -Path $dllPath
    $ConnectionString = "server=$($serverConfig["DatabaseConfig"]["PublicDatabaseAddr"]);" +
                        "port=$($serverConfig["DatabaseConfig"]["PublicDatabasePort"]);" +
                        "user=$($serverConfig["DatabaseConfig"]["PublicDatabaseUserName"]);" +
                        "password=$($serverConfig["DatabaseConfig"]["PublicDatabasePassword"]);" +
                        "database=moe_banlist"
    $Connection = New-Object MySql.Data.MySqlClient.MySqlConnection
    $Connection.ConnectionString = $ConnectionString
    $Connection.Open()

    try {
        # Check if the moe_banlist table exists, if not, create it
        $sql = "CREATE TABLE IF NOT EXISTS moe_banlist (
                    steamid VARCHAR(128), 
                    TimeOfBan DATETIME, 
                    UnbanTime DATETIME, 
                    Reason VARCHAR(256), 
                    IsBanned BOOL
                )"
        $cmd = New-Object MySql.Data.MySqlClient.MySqlCommand($sql, $Connection)
        $cmd.ExecuteNonQuery()

        # Check if the $steamID already exists in the table
        $sql = "SELECT UnbanTime FROM moe_banlist WHERE steamid = '$steamID'"
        $cmd = New-Object MySql.Data.MySqlClient.MySqlCommand($sql, $Connection)
        $reader = $cmd.ExecuteReader()

        if ($reader.Read()) {
            $unbanTime = $reader["UnbanTime"]
            Write-Host "SteamID $steamID already exists in the table. Auto-unban time: $unbanTime"
        } else {
            $reader.Close()
            # $steamID does not exist, add it to the table
            $currentTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            $unbanTime = (Get-Date).AddMinutes($timeSpan).ToString("yyyy-MM-dd HH:mm:ss")
            Write-Host $unbanTime
            $sql = "INSERT INTO moe_banlist (steamid, TimeOfBan, UnbanTime, Reason, IsBanned) VALUES ('$steamID', '$currentTime', '$unbanTime', '$reason', 1)"
            $cmd = New-Object MySql.Data.MySqlClient.MySqlCommand($sql, $Connection)
            $cmd.ExecuteNonQuery()
            Write-Host "SteamID $steamID added to the ban list with auto-unban time: $unbanTime"
        }
    } finally {
        $Connection.Close()
    }
    moe-readBans -serverConfig $serverConfig
}



If (!($PSScriptRoot)) {
    # If for some reason the environment variable PSSCriptROot is not working
    
}

Switch ($option) {
    "StartCluster" {
        If (!($PSScriptRoot)) {
            StartCluster -gamePath $gamePath -chatPath $chatPath -optPath $optPath -serverConfig $serverConfig -pidPath $pidPath -scriptPath $scriptPath -serverPath $serverPath
        } Else {
            StartCluster -gamePath $gamePath -chatPath $chatPath -optPath $optPath -serverConfig $serverConfig -pidPath $pidPath -scriptPath $PSScriptRoot -serverPath $serverPath
        }
        
        break # Lol
    }
    "ShutdownCluster" {
        ShutdownCluster -serverConfig $serverConfig -pidPath $pidPath
        break
    }
    "RestartCluster" {
        ShutdownCluster -serverConfig $serverConfig -pidPath $pidPath
        If (!($PSScriptRoot)) {
            StartCluster -gamePath $gamePath -chatPath $chatPath -optPath $optPath -serverConfig $serverConfig -pidPath $pidPath -scriptPath $scriptPath -serverPath $serverPath
        } Else {
            StartCluster -gamePath $gamePath -chatPath $chatPath -optPath $optPath -serverConfig $serverConfig -pidPath $pidPath -scriptPath $PSScriptRoot -serverPath $serverPath
        }
        break
    }
    "UpdateCluster" {
        $updated = CheckUpdate -serverPath $serverPath -steamcmdFolder $steamCMDPath -pidPath $pidPath -serverConfig $serverConfig
        Start-Sleep -s 5
        # We should be ok to start the cluster, since we are saving and checking PIDs, if there's no update
        # then the servers will still be running therefore the PIDs will be true and not execute!
        if ($updated -like "*True*") {
            If (!($PSScriptRoot)) {
                StartCluster -gamePath $gamePath -chatPath $chatPath -optPath $optPath -serverConfig $serverConfig -pidPath $pidPath -scriptPath $scriptPath -serverPath $serverPath
            } Else {
                StartCluster -gamePath $gamePath -chatPath $chatPath -optPath $optPath -serverConfig $serverConfig -pidPath $pidPath -scriptPath $PSScriptRoot -serverPath $serverPath
            }
            break
        }
    }
    "AddBan" {
        if (!($steamID)) {
            Write-host "Missing SteamID, Who to ban?!"
            Exit 1
        } Else {
            moe-addBan -steamID $steamID -timespan $timeSpan -reason $banreason -serverConfig $serverConfig
        }
        Exit 0
    }
    "Help" {
        $helpText = @"
        -----HELP MENU----
        The following arguments can be used:
        -option StartCluster -> This function will start the cluster
        -option ShutdownCluster -> This function will save and shutdown the cluster
        -option RestartCluster -> Use this to restart cluster/recover from crashes
        -option UpdateCluster -> Use this to check and update the cluster if needed
"@
        Write-Host $helpText
    }
    Default {
        Write-Host "Invalid Option: $($option)"
        Write-Host "Valid Options are: StartCluster, ShutdownCluster, RestartCluster, UpdateCluster or Help"
    }
} # End Switch Statement

function ReportTime {
    param (
        [DateTime]$rebootTime,
        [DateTime]$updateCheckTime,
        [DateTime]$banCheckTime
    )
    Write-Host "Next Reboot Time: $($rebootTime)"
    Write-Host "Next Update Check Time: $($updateCheckTime)"
    Write-Host "Next Ban Check Time: $($banCheckTime)"
}

# We Don't want the auto process starting if you are using the script to add or remove a ban
if (!($option -eq "*ban*")) {
    # This is the auto-process loop. 
    # This loop will continue to run until you close it
    # it will automatically reboot the server on a set schedule based on
    # the value in $restartTime in hours
    # This loop will also automatically check for updates every 30 minutes
    if ($autoprocess -eq "true") {
        # Initial setup
        $rebootTimeString = (Get-Date).AddHours($restartTime).ToString('MM/dd/yyyy HH:mm:ss')
        $updateCheckTimeString = (Get-Date).AddMinutes(30).ToString('MM/dd/yyyy HH:mm:ss')
        $banCheckTimeString = (Get-Date).AddMinutes(10).ToString('MM/dd/yyyy HH:mm:ss')
        $rebootTime = [DateTime]::ParseExact($rebootTimeString, 'MM/dd/yyyy HH:mm:ss', $null)
        $updateCheckTime = [DateTime]::ParseExact($updateCheckTimeString, 'MM/dd/yyyy HH:mm:ss', $null)
        $banCheckTime = [DateTime]::ParseExact($banCheckTimeString, 'MM/dd/yyyy HH:mm:ss', $null)
        ReportTime -rebootTime $rebootTime -updateCheckTime $updateCheckTime -banChecktime $banCheckTime
        $warningSent = $false

        do {
            $currentDate = Get-Date
            $warningTime = $rebootTime.AddMinutes(-5)

            # Check if it's time to send the pre-reboot warning
            if ($currentDate -ge $warningTime -and $currentDate -lt $rebootTime -and -not $warningSent) {
                if ($enableDiscord -eq "true") {
                    # Send a pre-reboot warning to Discord
                    messageDiscord -message "MoE Cluster rebooting in 5 minutes." -secret $discordSecret
                    $warningSent = $true
                }
                
            }

            # Check for reboot time
            if ($currentDate -gt $rebootTime) {
                if ($enabledDiscord -eq "true") { 
                    messageDiscord -message "MoE Cluster is rebooting now!" -secret $discordSecret
                }
                # Time to Reboot the cluster!
                ShutdownCluster -serverConfig $serverConfig -pidPath $pidPath
                # Reload the Server Config
                Try {
                    $serverConfig = Parse-IniFile -FilePath $ServerIni
                } Catch {
                    Write-Error "Failed to Parse INI File $serverIni `r`n $($_.Server.Exception)"
                    Exit 1
                }
                # Running the startCluster function twice because lobby server keeps crashing
                # this is temporary till i have time to find a solution
                if (-not $PSScriptRoot) {
                    StartCluster -gamePath $gamePath -chatPath $chatPath -optPath $optPath -serverConfig $serverConfig -pidPath $pidPath -scriptPath $scriptPath -serverPath $serverPath
                    Start-Sleep -s 30
                    StartCluster -gamePath $gamePath -chatPath $chatPath -optPath $optPath -serverConfig $serverConfig -pidPath $pidPath -scriptPath $scriptPath -serverPath $serverPath
                } else {
                    StartCluster -gamePath $gamePath -chatPath $chatPath -optPath $optPath -serverConfig $serverConfig -pidPath $pidPath -scriptPath $PSScriptRoot -serverPath $serverPath
                    Start-Sleep -s 30
                    StartCluster -gamePath $gamePath -chatPath $chatPath -optPath $optPath -serverConfig $serverConfig -pidPath $pidPath -scriptPath $PSScriptRoot -serverPath $serverPath
                }

                # Reset the reboot timer
                $rebootTimeString = (Get-Date).AddHours($restartTime).ToString('MM/dd/yyyy HH:mm:ss')
                $rebootTime = [DateTime]::ParseExact($rebootTimeString, 'MM/dd/yyyy HH:mm:ss', $null)
                ReportTime -rebootTime $rebootTime -updateCheckTime $updateCheckTime
                $warningSent = $false
            }

            # Check for update time
            if ($currentDate -gt $updateCheckTime) {
                $updated = CheckUpdate -serverPath $serverPath -steamcmdFolder $steamCMDPath -pidPath $pidPath -serverConfig $serverConfig

                Start-Sleep -Seconds 5

                if ($updated -like "*True*") {
                    # Reload the Server Config
                    Try {
                        $serverConfig = Parse-IniFile -FilePath $ServerIni
                    } Catch {
                        Write-Error "Failed to Parse INI File $serverIni `r`n $($_.Server.Exception)"
                        Exit 1
                    }
                    if (-not $PSScriptRoot) {
                        StartCluster -gamePath $gamePath -chatPath $chatPath -optPath $optPath -serverConfig $serverConfig -pidPath $pidPath -scriptPath $scriptPath -serverPath $serverPath
                        Start-Sleep -s 30
                        StartCluster -gamePath $gamePath -chatPath $chatPath -optPath $optPath -serverConfig $serverConfig -pidPath $pidPath -scriptPath $scriptPath -serverPath $serverPath
                    } else {
                        StartCluster -gamePath $gamePath -chatPath $chatPath -optPath $optPath -serverConfig $serverConfig -pidPath $pidPath -scriptPath $PSScriptRoot -serverPath $serverPath
                        Start-Sleep -s 30
                        StartCluster -gamePath $gamePath -chatPath $chatPath -optPath $optPath -serverConfig $serverConfig -pidPath $pidPath -scriptPath $PSScriptRoot -serverPath $serverPath
                    }
                }
                # Reset update check time
                $updateCheckTimeString = (Get-Date).AddMinutes(30).ToString('MM/dd/yyyy HH:mm:ss')
                $updateCheckTime = [DateTime]::ParseExact($updateCheckTimeString, 'MM/dd/yyyy HH:mm:ss', $null)
                ReportTime -rebootTime $rebootTime -updateCheckTime $updateCheckTime
            }
            # Check for Bans
            if ($currentDate -gt $banCheckTime) {
                # Execute ban/unban process
                moe-readBans -serverConfig $serverConfig
                # Reset ban check time
                $banCheckTimeString = (Get-Date).AddMinutes(10).ToString('MM/dd/yyyy HH:mm:ss')
                $banCheckTime = [DateTime]::ParseExact($banCheckTimeString, 'MM/dd/yyyy HH:mm:ss', $null)
                ReportTime -rebootTime $rebootTime -updateCheckTime $updateCheckTime -banChecktime $banCheckTime
            }        
        } while ($true)
    }
}