# Myth of Empires Server Management Script

This PowerShell script, created by Icewarden for the Admins United: Myth of Empires Community, offers a robust set of features for managing Myth of Empires game servers. It facilitates easy server startup, maintenance, and communication through Discord integration. 

PLEASE READ AND FOLLOW THE INSTRUCTIONS ON THE CLUSTER SETUP GUIDE CLOSELY BEFORE ATTEMPTING TO RUN THIS SCRIPT
[ClusterSetupGuide](https://steamcommunity.com/sharedfiles/filedetails/?id=3165697002)

If there is an argument missing, its most likely not included in the Server Tool. You'll need to add a new section in the ServerParamConfig_All.ini called ```[CustomServerConfig]```
For example here are some known custom configs (Thanks to Loumie [@taychason](https://github.com/taychason) from the Admins United community for these!)

```
[CustomServerConfig]
NpcSpawnIntervalMultiplier=1.0          ; mob refresh rate. Lower number = faster respawn
NpcStaticSpawnIntervalMultiplier=1.0    ; NPC refresh rate
TameAnimalPregnancySpeedMultiplier=1.0  ; pregnancy speed. higher number = faster pregnancy
XCJinPaiMemberCountLimit=1              ; guild member requirement for county/prefecture battle
FubenCoolDownMultiplier=1.0             ; treasure map cooldown. Lower number = faster cooldown.
bEnableConfigVariationChance=true       ; enables horse mutations
SeasonHonorPoint=1                      ; Has something to do with seasonal points we think
; All have something to do with Server transfering
TransportCDAddMulDiff=1
TransportCDAddMul=1
CrossServerCDTimeTaiShouDecDiff=1
CrossServerNewPlayerCDTimeDiff=1
CrossServerNewPlayerCDTime=1
CrossServerCDTime=1
CrossServerCDTimeDiff=1
```

## Features

- **Server Management**: Start, stop, restart, and update your Myth of Empires server with simple commands.
- **Discord Notifications**: Send automatic updates about server status changes directly to a Discord channel through a bot.
- **Ban Management**: Interface with a MySQL database to manage player bans, including timed bans and automatic unbanning.
- **Log Management**: Automatically cleans old log files to keep your server tidy.
- **Dynamic Server Updates**: Check and apply game updates with minimal downtime.
- **Configuration Parsing**: Parses server configuration files for dynamic management without hardcoding values.

## Prerequisites

- **PowerShell 5.1 or higher**: The script is developed for Windows environments using PowerShell.
- **MySQL Database**: For the ban management feature, a MariaDB database is required.
- **Discord Bot**: To send notifications to Discord, a Discord bot with a configured webhook is necessary.
- **MatrixServerTool**: This tool is required for initial server setup and must be placed in a specific directory as outlined in the script comments.

## Setup

1. **MatrixServerTool Configuration**: Ensure the MatrixServerTool is correctly set up as per the game server's documentation.
2. **Discord Bot Setup**: Create a Discord bot and set it up to listen on localhost for messages from the script.
3. **MySQL Database**: Set up a MySQL database named `moe_banlist` for managing bans.
4. **MySQL.Data.Dll**: Copy the DLL from the ExternalUtilities folder into `"C:\scripts\ExternalUtilities"`

## Usage

To use the script, you'll need to configure it with your server's specific details. Adjust the parameters at the beginning of the script to match your setup:

- `$serverPath`: The path to your server installation (e.g., `"C:\servers\moe"`).
- `$steamCMDPath`: The path to SteamCMD (e.g., `"C:\scripts\steamcmd"`).
- `$rconPath`: The path for RCON automation, useful for remote server management (e.g., `"C:\scripts\mcrcon\mcrcon.exe"`).
- `$scriptPath`: The location where you plan to keep this script. It's a fallback in case something breaks (e.g., `"C:\scripts"`).
- `$privateIP`: Your server's private IP address. Use `ipconfig` to find this.
- `$publicIP`: Your server's public IP address. Can be found using web services like IP Chicken ([ipchicken.com](https://ipchicken.com)).
- `$clusterID`: The cluster ID for your server. Default is `8888`. Only change this if you are running multiple clusters.
- `$option`: The operation you wish to perform with the script (`StartCluster`, `StopCluster`, `RestartCluster`, `UpdateCluster`, `Help`).
- `$enableMySQL`: Enables MySQL access for ban management. Set to `"true"` if you are using MariaDB or another MySQL-compatible database.
- `$enableDiscord`: Enables Discord functions for sending notifications. Requires a Discord bot setup (`"true"` or `"false"`).
- `$discordSecret`: The secret token for your Discord bot, required if `$enableDiscord` is `"true"`.
- `$autoprocess`: Enables the script to automatically perform restarts and updates based on a schedule (`"true"` or `"false"`).
- `$restartTime`: The time in hours when the server should automatically reboot (e.g., `"8"` for every 8 hours).
- `$steamID`: The SteamID to ban when using the script for ban management.
- `$timeSpan`: The duration in minutes for a temporary ban. For permanent bans, you may need to set this to a very high value.
- `$banreason`: The reason for the ban, which will be logged in the ban management system.

### Commands

### Starting the ServerCluster

```powershell
.\move_v1.ps1 -option StartCluster
```

### Stopping the Server Cluster
```powershell
.\move_v1.ps1 -option ShutdownCluster
```

### Restarting the Cluster
```powershell
.\move_v1.ps1 -option RestartCluster
```

### Updating the Cluster Manually
```powershell
.\move_v1.ps1 -option UpdateCluster
```

### Ban a user
```powershell
.\move_v1.ps1 -option AddBan -SteamID <STEAMID> -timeSpan <MINUTES> -banReason <REASON>
```