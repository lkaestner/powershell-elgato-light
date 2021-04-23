# Name:         ElgatoLight
# Description:  Control Elgato KeyLight, RingLight and LightStrip from PowerShell.
# Compatiblity: PowerShell Core 7+
# License:      MIT License
# Developer:    lkaestner

Set-StrictMode -Version 3

# Configuration
$NetworkTimeoutSec = 2
$RestHeaders = @{
    'Content-Type' = 'application/json'
    'Accept' = 'application/json'
}

# Set the brightness and/or temperature of the provided device(s).
function Set-ElgatoLight {
    param (
		[parameter(mandatory)][string[]]                  $Hostname,
		[parameter(mandatory)][int][ValidateRange(0,100)] $Brightness,
		[parameter()][int][ValidateRange(2900,7000)]      $Temperature
	)
	
    $Body = [ordered]@{}
	$Body.NumberOfLights = 1
	$Body.Lights = @(@{})
	$Body.Lights[0].On = ($Brightness -lt 3) ? 0 : 1
	
	if ($Brightness -ge 3) {
		$Body.Lights[0].Brightness = $Brightness
	}
	if ($PSBoundParameters.ContainsKey('Temperature')) {
		if ($Hostname -like "*Light-Strip*") {
			$Saturation = (100 / (2900 - 3850)) * ($Temperature - 3850) -as [int]
			$Body.Lights[0].Saturation = $Saturation
			$Body.Lights[0].Hue        = 30
		} else {
			$Body.Lights[0].Temperature = 1000000 / $Temperature -as [int]
		}
	}
	$BodyJson = $Body | ConvertTo-Json
	
	foreach ($SingleHost in $Hostname) {
		Write-Output "[*] Setting ${SingleHost} to ${Brightness}% at ${Temperature}K"
		try {
			$RestResponse = Invoke-RestMethod -Method "Put" -Uri "http://${SingleHost}:9123/elgato/lights" -Headers $RestHeaders -Body $BodyJson -TimeoutSec $NetworkTimeoutSec
		} catch {
			Write-Warning "REST-Call failed."
			Probe-ElgatoLight $SingleHost
		}
	}
}

# Get and print the Settings of the provided device.
function Get-ElgatoLight {
    param (
        [parameter(mandatory)][string] $Hostname
    )
	try {
		Invoke-RestMethod -Method "Get" -Uri "http://${Hostname}:9123/elgato/lights" -Headers $RestHeaders -TimeoutSec $NetworkTimeoutSec
	} catch {
		Write-Warning "REST-Call failed."
		Probe-ElgatoLight $SingleHost
	}
}

# Attempt to communicate with the provided device - and provide basic diagnostics.
function Probe-ElgatoLight {
	param (
        [parameter(mandatory)][string] $Hostname
    )
	if (Test-Connection -Quiet -Ping -Count 1 -TimeoutSeconds $NetworkTimeoutSec -TargetName $Hostname) {
		Write-Output "Device responds to ping: $Hostname"
	} else {
		Write-Warning "Could not name-resolve or ping the device: $Hostname"
	}
}