## Created by Icewarden for Admins United: Myth of Empires Community ##
# If you got this script anywhere other than from me directly or Admins United Discord, do not use as it could be malicious

# This script will parse the INI and create all the startup lines needed to start your grid successfully

# This Script requires you to use the MatrixServerTool to generate the ServerParamConfig_All.ini
# This script requires you to copy the MatrixServerTool folder to your dedicated server to your server path
# This Script requires you to copy the ServerParamConfig_All.ini file to a folder called "configs" under your server path!
# Do not edit anything in this script unless you know what you are doing, any customizations will not be supported unless I like you or you buy me cookies

# EDIT THESE BELOW #
Param (
    $serverPath = "C:\servers\moe", # Path to your server install (Whatever your used for SteamCMD) Ex. C:\servers\moe
    $steamCMDPath = "C:\scripts\steamcmd", # Path to SteamCMD; Ex. C:\scripts\steamcmd
    $rconPath = "C:\scripts\mcrcon\mcrcon.exe", # This is for RCON automation
    $privateIP = "192.168.0.15", # This is your private ip. Use IPCONFIG to get
    $publicIP = "47.197.87.62", # This is your Public IP, Use IPCHICKEN.COM
    $clusterID = 8888, # Not sure where this is being set so we will set it here
    $rconPass = "", # RCON Password
    $enableMySQL = "false" # Turn on MYSQL Access -> Do this is you used MariaDB
)
## EDIT NOTHING FURTHER ##

# Section to update MoE (or install)
#& (Join-Path $steamCMDPath "steamcmd.exe") +force_install_dir $serverPath +login anonymous +app_update 1794810 validate +quit


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
# Checking that they exist
$pathsToCheck = @($gamePath, $optPath, $chatPath, $ServerIni)
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

Try {
    $serverConfig = Parse-IniFile -FilePath $ServerIni
} Catch {
    Write-Error "Failed to Parse INI File $serverIni `r`n $($_.Server.Exception)"
    Exit 1
}


# Step 1 - Launch Database Servers
## Public Data Server
# Build Argument Line for PubServer
## DO NOT TOUCH UNLESS YOU KNOW WHAT YOU'RE DOING ##
$pubServerArgumentLine = "Map_Public -game -server -ClusterId=$($clusterID) -DataStore -log -StartBattleService -StartPubData " + `
"-BigPrivateServer -DistrictId=1 -LOCALLOGTIMES -NetServerMaxTickRate=1000 -HangDuration=300 -core " + `
"-NotCheckServerSteamAuth -MultiHome=$($privateIP) -OutAddress=$($publicIP) -Port=$($serverConfig["PubDataServerInfo"]["PubDataGamePort"]) " + `
"-QueryPort=$($serverConfig["PubDataServerInfo"]["PubDataQueryPort"]) -ShutDownServicePort=$($serverConfig["PubDataServerInfo"]["PubDataClosePort"]) " + `
"-ShutDownServiceIP=$($serverConfig["PubDataServerInfo"]["PubDataRemoteAddr"]) -ShutDownServiceKey=$($rconPass) " + ` 
"-SessionName=PubDataServer_90000 -ServerId=$($serverConfig["PubDataServerInfo"]["PubDataServerID"]) log=PubDataServer_90000.log " + `
"-PubDataAddr=$($serverConfig["PubDataServerInfo"]["PubDataAddr"]) -PubDataPort=$($serverConfig["PubDataServerInfo"]["PubDataPort"]) " + ` 
"-DBAddr=$($serverConfig["AroundServerInfo"]["DBStoreAddr"]) -DBPort=$($serverConfig["AroundServerInfo"]["DBStorePort"]) " + ` 
"-BattleAddr=$($serverConfig["AroundServerInfo"]["BattleManagerAddr"]) -BattlePort=$($serverConfig["AroundServerInfo"]["BattleManagerPort"]) " + ` 
"-ChatServerAddr=$($serverConfig["AroundServerInfo"]["ChatServerAddr"]) -ChatServerPort=$($serverConfig["AroundServerInfo"]["ChatServerPort"]) " + `
"-ChatClientAddress=$($serverConfig["AroundServerInfo"]["ChatClientAddr"]) -ChatServerPort=$($serverConfig["AroundServerInfo"]["ChatClientAddr"]) -ChatClientPort=$($serverConfig["AroundServerInfo"]["ChatClientPort"]) " + `
"-ChatServerPort=$($serverConfig["AroundServerInfo"]["ChatClientPort"]) " + ` 
"-OptEnable=1 -OptAddr=$($serverConfig["AroundServerInfo"]["OptToolAddr"]) -OptPort=$($serverConfig["AroundServerInfo"]["GatewayPort"]) " + `
"-Description=`"$($serverConfig["BaseServerConfig"]["Description"])`" -MaxPlayers=100 -NoticeSelfEnable=true " + ` 
"-NoticeSelfEnterServer=`"$($serverConfig["BaseServerConfig"]["NoticeSelfEnterServer"])`" " + `
"-MapDifficultyRate=1 -UseACE -EnableVACBan=1"
# Start the Pub Server Control
Start-Process $gamePath $pubServerArgumentLine

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
Start-Process $chatPath $chatServiceArgumentLine

## Opt Service Server
# Build Argument Line for OptService
## DO NOT TOUCH UNLESS YOU KNOW WHAT YOU'RE DOING ##
$optArgumentLine = "-b=true " + `
"-LogLevel=1 " + `
"-GatewayAddr=$($privateIP):$($serverConfig["AroundServerInfo"]["GatewayPort"]) " + `
"-RankClientAddr=$($publicIP):$($serverConfig["AroundServerInfo"]["RankListPort"]) " + `
"-GlobalRankClientAddr=$($publicIP):$($serverConfig["AroundServerInfo"]["GlobalRankListPort"]) " + `
"-MarketClientAddr=$($publicIP):$($serverConfig["AroundServerInfo"]["MarketPort"]) " + `
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
Start-Process $optPath $optArgumentLine

## Lobby Service Server
# Build Argument Line for LobbyService
## DO NOT TOUCH UNLESS YOU KNOW WHAT YOU'RE DOING ##
$lobbyArgumentLine = "Map_Lobby -game -server -ClusterId=$($clusterID) -DataStore -log -StartBattleService -StartPubData " + `
"-BigPrivateServer -LaunchMMOServer -DistrictId=1 -LOCALLOGTIMES -core -NetServerMaxTickRate=100 -HangDuration=300 -NotCheckServerSteamAuth " + `
"-LobbyPort=$($serverConfig["LobbyServerInfo"]["LobbyPort"]) -MultiHome=$($privateIP) " + `
"-OutAddress=$($publicIP) -Port=$($serverConfig["LobbyServerInfo"]["LobbyGamePort"]) -QueryPort=$($serverConfig["LobbyServerInfo"]["LobbyQueryPort"]) " + `
"-ShutDownServicePort=$($serverConfig["LobbyServerInfo"]["LobbyClosePort"]) -ShutDownServiceIP=$($serverConfig["LobbyServerInfo"]["LobbyRemoteAddr"]) " + `
"-ShutDownServiceKey=$($rconPass) -MaxPlayers=$($serverConfig["LobbyServerInfo"]["LobbyMaxPlayers"]) " + `
"-mmo_storeserver_addr=$($serverConfig["AroundServerInfo"]["DBStoreAddr"]) -mmo_storeserver_port=$($serverConfig["AroundServerInfo"]["DBStorePort"]) " + `
"-mmo_battlemanagerserver_addr=$($serverConfig["AroundServerInfo"]["BattleManagerAddr"]) -mmo_battlemanagerserver_port=$($serverConfig["AroundServerInfo"]["BattleManagerPort"]) " + `
"-SessionName=`"$($serverConfig["LobbyServerInfo"]["ServerListName"])`" -ServerId=$($serverConfig["LobbyServerInfo"]["LobbyServerID"]) log=LobbyServer_$($serverConfig["LobbyServerInfo"]["LobbyServerID"]).log " + `
"-PubDataAddr=$($serverConfig["PubDataServerInfo"]["PubDataAddr"]) -PubDataPort=$($serverConfig["PubDataServerInfo"]["PubDataPort"]) " + ` 
"-DBAddr=$($serverConfig["AroundServerInfo"]["DBStoreAddr"]) -DBPort=$($serverConfig["AroundServerInfo"]["DBStorePort"]) " + `
"-BattleAddr=$($serverConfig["AroundServerInfo"]["BattleManagerAddr"]) -BattlePort=$($serverConfig["AroundServerInfo"]["BattleManagerPort"]) " + `
"-ChatServerAddr=$($serverConfig["AroundServerInfo"]["ChatServerAddr"]) -ChatServerPort=$($serverConfig["AroundServerInfo"]["ChatServerPort"]) " + `
"-ChatClientAddress=$($serverConfig["AroundServerInfo"]["ChatClientAddr"]) -ChatClientPort=$($serverConfig["AroundServerInfo"]["ChatClientPort"]) " + `
"-OptEnable=1 -OptAddr=$($serverConfig["AroundServerInfo"]["OptToolAddr"]) -OptPort=$($serverConfig["AroundServerInfo"]["GatewayPort"]) " + `
"-Description=`"$($serverConfig["BaseServerConfig"]["Description"])`" -MaxPlayers=$($serverConfig["BaseServerConfig"]["MaxPlayers"]) -NoticeSelfEnable=true " + `
"-NoticeSelfEnterServer=`"$($serverConfig["BaseServerConfig"]["NoticeSelfEnterServer"])`" -MapDifficultyRate=1 -UseACE -EnableVACBan=1"

if ($($serverConfig["LobbyServerInfo"]["LobbyPassword"])) {
    $lobbyArgumentLine += " -PrivateServerPassword=$($serverConfig["LobbyServerInfo"]["LobbyPassword"])"
}

if ($enableMySQL -like "true") {
    $lobbyArgumentLine += " -mmo_storeserver_type=Mysql " + ` 
    "-mmo_storeserver_role_connstr=`"Provider=MYSQLDB;SslMode=None;Password=$($serverConfig["DatabaseConfig"]["RoleDatabasePassword"]);User ID=$($serverConfig["DatabaseConfig"]["RoleDatabaseUserName"]);Initial Catalog=$($serverConfig["DatabaseConfig"]["RoleDatabaseCatalog"]);Data Source=$($serverConfig["DatabaseConfig"]["RoleDatabaseAddr"]):$($serverConfig["DatabaseConfig"]["RoleDatabasePort"])`" " + `
    "-mmo_storeserver_public_connstr=`"Provider=MYSQLDB;SslMode=None;Password=$($serverConfig["DatabaseConfig"]["PublicDatabasePassword"]);User ID=$($serverConfig["DatabaseConfig"]["PublicDatabaseUserName"]);Initial Catalog=$($serverConfig["DatabaseConfig"]["PublicDatabaseCatalog"]);Data Source=$($serverConfig["DatabaseConfig"]["PublicDatabaseAddr"]):$($serverConfig["DatabaseConfig"]["PublicDatabasePort"])`""
}
# Start the Lobby Service with the game executable path
Start-Process $gamePath $lobbyArgumentLine


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
-bEnableServerLevel=$($serverConfig["BaseServerConfig"]["bEnableServerLevel"]) `
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
        "-Description=`"$($serverConfig["BaseServerConfig"]["Description"])`" -MaxPlayers=$($sceneServer["SceneMaxPlayers"]) -NoticeSelfEnable=true " + `
        "-NoticeSelfEnterServer=`"$($serverConfig["BaseServerConfig"]["NoticeSelfEnterServer"])`" -MapDifficultyRate=$($serverConfig["BaseServerConfig"]["MapDifficultyRate"]) -UseACE -EnableVACBan=1 "

        # Append generalized arguments
        $gridArgumentLine += $generalizedArguments

        # Determine if the server is PVP or PVE and append the appropriate arguments
        if ($($sceneServer["ScenePVPType"]) -eq "1") { # PVE
            $gridArgumentLine += $pveArguments
        } else { # PVP
            $gridArgumentLine += $pvpArguments
        }

        Start-Process $gamePath $gridArgumentLine
        Start-Sleep -s 10
    }
}