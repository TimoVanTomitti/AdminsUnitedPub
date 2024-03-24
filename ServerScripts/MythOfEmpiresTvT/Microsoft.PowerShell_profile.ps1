function MoEServerControl{ 
    param(
        [string]$Command
    )
	$documentsPath = [System.IO.Path]::Combine([System.Environment]::GetFolderPath('MyDocuments'))
    Set-Location -Path "$($documentsPath)\WindowsPowerShell\scripts" 
    if ($Command -eq "stop") {
	.\Moe_v1.ps1  -option ShutdownCluster
        Write-Host ""
        Write-Host ""
        Write-Host "#############################################################"   
	    Write-Host "### ggf. Musste du Noch ein PowerShellfenster schliessen ####"
        Write-Host "#############################################################"     
    } elseif ($Command -eq "restart") {
        Write-Host ""
        Write-Host ""
        Write-Host "#############################################################"   
	    Write-Host "###    strg + c zum Abbrechen                            ####"
        Write-Host "#############################################################" 
        Write-Host ""
        Write-Host ""
	   .\Moe_v1.ps1  -option RestartCluster
    }  elseif ($Command -eq "start") {
        Write-Host ""
        Write-Host ""
        Write-Host "#############################################################"   
	    Write-Host "###    strg + c zum Abbrechen                            ####"
        Write-Host "#############################################################" 
        Write-Host ""
        Write-Host ""
	   .\Moe_v1.ps1  -option StartCluster
    }  elseif ($Command -eq "update") {
        Write-Host ""
        Write-Host ""
        Write-Host "#############################################################"   
	Write-Host "###    strg + c zum Abbrechen                            ####"
        Write-Host "#############################################################" 
        Write-Host ""
        Write-Host ""
	    .\Moe_v1.ps1  -option UpdateCluster
    } else {
    	Write-Host "Du kannst folgendes tun:"  
    	Write-Host "MoEServer start" 
    	Write-Host "MoEServer stop"
    	Write-Host "MoEServer restart"
    	Write-Host "MoEServer update"
    	Write-Host "Strg + C zum Abbrechen"
    }

}


New-Alias -Name MoEServer -Value MoEServerControl