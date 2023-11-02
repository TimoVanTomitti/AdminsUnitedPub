## Written by @IceWarden for the Front Dedicated Server Community. ##
## This script is to be used to assist in starting up and managing a "The Front"
## dedicated server. This script will not be supported. 

## SUPER IMPORTANT NOTE ##
## SCRIPTS CAN BE VERY DANGEROUS. IF YOU DID NOT RECIEVE THIS FROM @ICEWARDEN
## THEN CONSIDER IT DANGEROUS AND DO NOT USE IT. THIS IS YOUR ONLY WARNING

# HOW TO USE #
# Put this script into your Server Directory Root (The place you download from steamDB!)
# Use the Front Manager to configure your server. When you save it, will produce a config file (.ini)
# stick the config file into your server root (same place you put this script) and rename it to config.ini
# Change the below parameters. You can either hardcode them here in the script
# or you can pass them as argument when executing the script. 
## I.E. .\Start-Server.ps1 -maxPlayers 100 -isDedi true -trunkServerName MyServer
param (
    [int]$maxPlayers = "100",               # Max Players
    [string]$multiHome = "" ,               # Only use if you need to specify your private server IP
    $wipeFrequency = "",                    # Frequency to wipe in days (IE 30 for 30-day wipe period)
    $enableWipe = "",                       # Pass this to turn on auto wiping
	$isDedi = "true",			            # Set this to true if it is a dedi server like ovh. 
	$trunkServerName = "",  	            # Truncated Server name for save directory. Keep it simple
    $steamcmdFolder = "C:\scripts\steamcmd" # SteamCMD Folder, used for updating!
)

# Write Function to get public IP and PrimevalTest
# Get your Public IP
$publicIP = Invoke-RestMethod -Uri "https://api.ipify.org?format=text"
# Get your Private IP
# NOTE - IF YOU HAVE MULTIPLE NETWORKS SETUP ON YOUR SERVER YOU MAY JUST NEED
# TO SET $MULTIHOME MANUALLY!
If ((-not $multiHome) -and (!($isDedi))) {
    $networkAdapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
    $multihome = $networkAdapter | Get-NetIPAddress | Where-Object { $_.AddressFamily -eq 'IPv4' } | Select-Object -ExpandProperty IPAddress
}

#### DO NOT TOUCH! ####
## None of the functions or code below is worth touching
## Unless you absolutely know what you are doing
## I (@Icewarden) will not be supporting this script beyond
## basic updates or feature updates. 
## If you follow the instructions in the comments at the top
## this will run itself perfectly.
function Parse-IniFile {
    param (
        [string]$filePath
    )

    try {
        $iniContent = Get-Content -Path $filePath -ErrorAction Stop
        $config = @{}

        foreach ($line in $iniContent) {
            if ($line -match '^(?<Key>[^\=]+)\=(?<Value>.+)$') {
                $key = $matches['Key'].Trim()
                $value = $matches['Value'].Trim()
                $config[$key] = $value
            }
        }

        return $config
    } catch {
        Write-Error "An error occurred while parsing the INI file: $_"
		exit 1
        return $null
    }
}

# Function to grab the telnet port (ShutDownServicePort) from
# the config.ini
function GetTelnetPort {
    $iniPath = Join-Path $PSScriptRoot "config.ini"
    $config = Parse-IniFile -filePath $iniPath
    $telnetPort = $config['ShutDownServicePort']

    return $telnetPort
    
}

# Function to execute telnet commands
function TelnetCommand {
    param (
        [string]$command
    )

    # Setup the connection
    $telnetAddr = "127.0.0.1"
    $telnetPort = GetTelnetPort
    $tcpConnection = New-Object System.Net.Sockets.TcpClient($telnetAddr, $telnetPort)
    $tcpStream = $tcpConnection.GetStream()
    $reader = New-Object System.IO.StreamReader($tcpStream)
    $writer = New-Object System.IO.StreamWriter($tcpStream)
    $writer.AutoFlush = $true
    # has to add a sleep here because telnet
	Start-Sleep -s 2
    # Execute the command
    $writer.WriteLine($command)
    # has to add a sleep here because telnet
	Start-Sleep -s 2
    # Close the connections
    $reader.Close()
    $writer.Close()
    $tcpConnection.Close()
    # typically there is no response. 
    return $response
}

# Function to start the server
function StartServer {
    param (
        $serverPath,
        $argumentLine
    )
    
    try {
        Start-Process $serverPath $argumentLine -ErrorAction Stop
        Write-Host "Server started successfully."
    } catch {
        Write-Error "Failed to start the server: $_"
    }
}

# Function to save the server
function SaveWorld {
    try {
        TelnetCommand -command "save" -ErrorAction Stop
        Write-Host "World saved successfully."
    } catch {
        Write-Error "Failed to save the world: $_"
    }
}

# Function to grab server info
# this doesn't currently work-ish. 
function ServerInfo {
    try {
        $output = TelnetCommand -command "queue" -ErrorAction Stop
        Write-Host $output
    } catch {
        Write-Error "Failed to retrieve server information: $_"
    }
}

# Function for restarting the server
# this function will save the server, shut it down
# rebuild the argumentline and then start the server back up
# you can use this function if you make configuration changes on the fly!
function RestartServer {
    param (
        $serverPath,
        $isUpdate
    )

    try {
        # If the command is ran and the server wasn't updated
        # then we need to save and shut it down
        if (!($isUpdate)) {
            SaveWorld
            Start-Sleep -Seconds 10 # wait 2 minutes
            TelnetCommand -command "shutdown"
            Start-Sleep -Seconds 10 # wait 2 minutes
        }
        
        # Rebuild the argument line after reading the config.ini again
        $argumentLine = BuildArgumentLine

        StartServer $serverPath $argumentLine

        Write-Host "Server restarted successfully."
    } catch {
        Write-Error "Failed to restart the server: $_"
    }
}

# Does what it says it does :-)
function ShutdownServer {
    try {
        SaveWorld
        Start-Sleep -Seconds 30
        TelnetCommand -command "shutdown"
        exit
    } catch {
        Write-Error "Failed to gracefully shutdown the server: $_"
        exit 1
    }
}

#### DO NOT TOUCH UNLESS YOU KNOW WHAT YOU'RE DOING! ####
## Seriously ##
function BuildArgumentLine {
    try {
        # Variable Setup
        $iniPath = Join-Path $PSScriptRoot "config.ini"
        $config = Parse-IniFile -filePath $iniPath
        $keysInQuotes = @('ShutDownServicePort','QueryPort','BeaconPort','Port','ClearseverTime','ServerAdminAccounts','ServerPassword')
        $binaryFlags = @('IsCanSelfDamage', 'IsCanFriendDamage', 'IsCanChat', 'IsShowBlood', 'IsUnLockAllTalentAndRecipe', 
                     'IsShowGmTitle', 'GreenHand', 'GMCanDropItem', 'GMCanDiscardItem', 'SensitiveWords', 
                     'ConstructEnableRot', 'OpenAllHouseFlag', 'HealthDyingState', 'UseACE')
        # Begin with settings that don't follow the -Key pattern
        $argumentLine = "ProjectWar_Start?DedicatedServer?MaxPlayers=$($maxPlayers) -server -game -log " + `
        "-EnableParallelCharacterMovementTickFunction -EnableParallelCharacterTickFunction " + `
        "-UseDynamicPhysicsScene -fullcrashdumpalways -Game.PhysicsVehicle=true " + `
        "-ansimalloc -Game.MaxFrameRate=35 -MaxQueueSize=50 -QueueValidTime=120 " + `
        "-OutIPAddress=$publicIP -MultiHome=$multihome -UserDir=`"$userDir`" "

        # Iterate through each key-value pair in $config and append to the argument line
        foreach ($key in $config.Keys) {
            # Handling special cases
            switch ($key) {
                'MaxPlayers' { continue } # Already added
                'UseSteamSocket' { continue }
                { $_ -in $keysInQuotes } {
                    $argumentLine += "-$key=`"$($config[$key])`" "
                    continue
                }
                { $_ -in $binaryFlags } {
                    if ($config[$key] -eq '1') {
                        $argumentLine += "-$key=true "
                    } else {
                        $argumentLine += "-$key=false "
                    }
                    continue
                }
                'ServerName' {
                    $argumentLine += "-ConfigServerName=`"$($config[$key])`" -ServerName=`"$($config[$key])`" "
                    continue
                }
                Default {
                    $argumentLine += "-$key=$($config[$key]) "
                }
            }    
        }

        return $argumentLine
    } catch {
        Write-Error "Failed to build argument line: $_"
        return $null
    }
}

# Function for checking update
# the first time you execute this function it will think there is
# an update. Moving forward however, you can use this to easily update your server
# it will consider the path that your script is in to be the install path
# since you should be sticking this script into the root of your game server anyway
function CheckUpdate {
    param (
        $scriptPath
    )
    $steamAppID="2612550"
    # Without clearing cache app_info_update may return old informations!
    $clearCache=1
    $dataPath = $scriptPath+"\data"
    $steamcmdExec = $steamcmdFolder+"\steamcmd.exe"
    $steamcmdCache = $steamcmdFolder+"\appcache"
    $latestAppInfo = $dataPath+"\latestappinfo.json"
    $updateinprogress = $scriptPath+"\updateinprogress.dat"
    $latestAvailableUpdate = $dataPath+"\latestavailableupdate.txt"
    $latestInstalledUpdate = $dataPath+"\latestinstalledupdate.txt"

    If (Test-Path $updateinprogress) {
    Write-Host Update is already in progress
    } Else {
        Get-Date | Out-File $updateinprogress
        Write-Host "Creating data Directory"
        New-Item -Force -ItemType directory -Path $dataPath
        If ($clearCache) {
        Write-Host "Removing Cache Folder"
        Remove-Item $steamcmdCache -Force -Recurse
        }

        Write-Host "Checking for an update"
        & $steamcmdExec +login anonymous +app_info_update 1 +app_info_print $steamAppID +app_info_print $steamAppID +quit | Out-File $latestAppInfo
        Get-Content $latestAppInfo -RAW | Select-String -pattern ‘(?m)"public"\s*\{\s*"buildid"\s*"\d{6,}"’ -AllMatches | %{$_.matches[0].value} | Select-String -pattern ‘\d{6,}’ -AllMatches | %{$_.matches} | %{$_.value} | Out-File $latestAvailableUpdate

        If (Test-Path $latestInstalledUpdate) {
            $installedVersion = Get-Content $latestInstalledUpdate
        } Else {
            $installedVersion = 0
        }

        $availableVersion = Get-Content $latestAvailableUpdate
        if ($installedVersion -ne $availableVersion) {
            Write-Host "Update Available"
            Write-Host "Installed build: $installedVersion – available build: $availableVersion"
            # Save
            SaveWorld
            # Shutdown
            TelnetCommand -command "shutdown"
            Write-host "Starting Update....This could take a few minutes..."
            & $steamcmdExec +login anonymous +force_install_dir $scriptPath +app_update $steamAppID validate +quit | Out-File $latestAppInfo
            $availableVersion | Out-File $latestInstalledUpdate
            Write-Host "Update Done!"
            Remove-Item $updateinprogress -Force
            RestartServer -serverPath $serverPath -isUpdate $true
        } Else {
            Write-Host 'No Update Available!'
            break
        }
        
    } 
} # End Check Update

# Function to wipe the server
# the way this works is we have to setup
# $wipeFrequency and $enableWipe
# this will then check the current config for 
# ClearSeverTime (Thanks Devs for Typo!)
# it will then clear out the files/folders required for a fresh wipe
# while retaining the Admins and Ban lists (thanks Scarecrow!)
# It will then update your config.ini with a new wipe date based on
# the frequency passed!
function WipeServer {
    param($wipeFrequency)

    $iniPath = Join-Path $PSScriptRoot "config.ini"
    $config = Parse-IniFile -filePath $iniPath
    $clearServerDate = $config['ClearSeverTime']
    $currentDate = Get-Date -Format 'yyyy-MM-dd'
    $nextWipeDate = (Get-Date).AddDays($wipeFrequency).ToString('yyyy-MM-dd')
    if ($clearServerDate -le $currentDate) {
        # Paths to delete. Info was obtained from TheFront Discord
        # thanks to scarecr0w12
        Write-Host "Wipe Day!"
        $pathsToDelete = @(
            "$userDir/Saved/ListenServer/",
            "$userDir/Saved/Logs/",
            "$userDir/Saved/GameStates/Accounts/Accounts.csv",
            "$userDir/Saved/GameStates/Accounts/Accounts.csv.back",
            "$userDir/Saved/GameStates/Accounts/NickNames.csv",
            "$userDir/Saved/GameStates/DeletedPlayers/",
            "$userDir/Saved/GameStates/Worlds/",
            "$userDir/Saved/GameStates/Players/",
            "$userDir/Saved/GameStates/ConstructData.sav",
            "$userDir/Saved/GameStates/GuildData.sav"
        )

        # Delete each path
        foreach ($path in $pathsToDelete) {
            if (Test-Path $path) {
                Remove-Item -Path $path -Recurse -Force
            }
        }

        # Update ClearServerTime in config keys
        # We will set this to X days in the future
        $config['ClearSeverTime'] = $nextWipeDate

        # write it back to the config.ini
        $updatedConfig = Get-Content $iniPath | ForEach-Object {
            if ($_ -match "^ClearSeverTime=") {
                "ClearSeverTime=$nextWipeDate"
            } else {
                $_
            }
        }

        # Save the updated config back to the file
        Set-Content -Path $iniPath -Value $updatedConfig
    }
}

# Player Control Function to easily allow admins to
# kick/ban/unban without having to be logged into the game directly
# they will need access to the dedi though. 
# I suppose if you know what you're doing you could just copy this into 
# your own little script to connect to the server remotely and execute these commands
function PlayerControl {
    Clear-Host
    Write-Host "Player Control Menu"
    Write-Host "Loading player list..."

    # Read the CSV file and skip the first line (header)
    $players = Import-Csv -Path "$userDir/Saved/GameStates/Accounts/Accounts.csv" -Header 'SteamID', 'UID', 'Name', 'AnotherID', 'Date', 'UPDATE', 'UnknownField'
    
    # Display the list of players with numbers
    $index = 1
    $playerDict = @{}
    foreach ($player in $players) {
        Write-Host "$index - $($player.Name)"
        $playerDict.Add($index, $player.SteamID)
        $index++
    }

    # Sub-menu for Kick/Ban/Unban options
    Write-Host "`nPlayer Actions:"
    Write-Host "To kick a player, type 'kick [number]' (e.g., kick 1)"
    Write-Host "To ban a player, type 'ban [number]' (e.g., ban 1)"
    Write-Host "To unban a player, type 'unban [number]' (e.g., unban 1)"
    Write-Host "Type 'back' to return to the main menu"
    
    while ($true) {
        $input = Read-Host "`nEnter your command"
        $action, $number = $input.Split(" ")

        switch ($action.ToLower()) {
            "kick" {
                if ($playerDict.ContainsKey($number)) {
                    $steamID = $playerDict[$number]
                    TelnetCommand -command "acct kick $steamID"
                    Write-Host "Player $($players[$number - 1].Name) kicked."
                } else {
                    Write-Host "Invalid player number."
                }
            }
            "ban" {
                if ($playerDict.ContainsKey($number)) {
                    $steamID = $playerDict[$number]
                    TelnetCommand -command "acct ban $steamID"
                    Write-Host "Player $($players[$number - 1].Name) banned."
                } else {
                    Write-Host "Invalid player number."
                }
            }
            "unban" {
                if ($playerDict.ContainsKey($number)) {
                    $steamID = $playerDict[$number]
                    TelnetCommand -command "acct PermitPlayer $steamID login"
                    Write-Host "Player $($players[$number - 1].Name) unbanned."
                } else {
                    Write-Host "Invalid player number."
                }
            }
            "back" {
                return
            }
            default {
                Write-Host "Invalid command, please try again."
            }
        }
    }
} # End PLayerControl

#### DO NOT TOUCH UNLESS YOU KNOW WHAT YOU'RE DOING! ####
## Main Script Logic ##
$serverPath = Join-Path $PSScriptRoot "/ProjectWar/Binaries/Win64/TheFrontServer.exe"
$userDir = Join-Path $PSScriptRoot "/saves/$($trunkServerName)"
# Build the initial argument line
$argumentLine = BuildArgumentLine

# Should we wipe?
if ($enableWipe) {
    WipeServer -wipeFrequency $wipeFrequency
}

# Start the Server
StartServer -serverPath $serverPath -ArgumentLIne $argumentLine


# Server Management Menu
$host.ui.RawUI.WindowTitle = "The Front - Dedicated Server Menu"
do {
    Clear-Host
    Write-Host "Server Manager"
    Write-Host "1. Restart Server"
    Write-Host "2. Shutdown Server"
    Write-Host "3. Save World"
    Write-Host "4. Display Server Info"
    Write-Host "5. Check for Update"
    Write-Host "6. Player Control"
    Write-Host "7. Exit"

    $choice = Read-Host "Enter your choice"

    switch ($choice) {
        '1' { RestartServer -serverPath $serverPath }
        '2' { ShutdownServer }
        '3' { SaveWorld }
        '4' { ServerInfo }
        '5' { CheckUpdate -scriptPath $PSScriptRoot }
        '6' { PlayerControl }
        '7' { exit }
        default { Write-Host "Invalid choice, please try again." }
    }
} while ($true)
