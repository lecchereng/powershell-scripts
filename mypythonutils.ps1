param(
	[Parameter(Position=0)]
	[string]$Function,
	
	[Parameter(Position=1)]
	[string]$Version,
	
	[Parameter(Position=2)]
	[string]$Name
)
# Questo script funziona solo per versioni powershell naggiori di 7.0
# Verifica se la versione di PowerShell è maggiore o uguale a 7
$_PSVersion=$PSVersionTable.PSVersion
if ($_PSVersion.Major -ge 7) {
    Write-Debug "PowerShell version is 7 or above ($_PSVersion)."
} else {
    Write-Host "PowerShell version is below 7.0 ($_PSVersion): I can't go on!"
	exit -10
}
function fixPath{
	## Vado a ricreare la variabile PATH con i valori espansi (non %VARIABILE%)
	# Ottieni il contenuto della variabile PATH
	$path = $env:PATH

	# Dividi i percorsi separati da ";"
	$paths = $path -split ';'
	$path=""
	# Espandi eventuali riferimenti a variabili di ambiente
	foreach ($p in $paths) {
		if ($p -ne '') { # Ignora voci vuote
			$expandedPath = [Environment]::ExpandEnvironmentVariables($p)
			#Write-Host $expandedPath
			if($path -ne '') {
				$path=$path+";"
			}
			$path=$path+$expandedPath
		}
	}
	$env:PATH=$path
}

function getCurrentPythonVersion{
	$pythonVersion = python --version 2>&1
	Write-Host "Current python version is ${pythonVersion}"
	return $pythonVersion
}

function setPythonVersion{
	param (
		[Parameter(Mandatory=$true,Position=0)]
		[string]$Version
	)
	$cv=getCurrentPythonVersion
	if ($Version -eq $cv){
		Write-Host "$Version is already the current one"
		return 0
	}
	# Mappa le versioni ai percorsi delle variabili di ambiente
	#$pythonEnvPaths = @{
	#	"3.7" = $env:PYTHON_HOME_3_7
	#	"3.10" = $env:PYTHON_HOME_3_10
	#	"3.11" = $env:PYTHON_HOME_3_11
	#	"3.13" = $env:PYTHON_HOME_3_13
	#}
	$versions = Get-ChildItem Env: |
    Where-Object { $_.Name -like 'PYTHON_HOME*' } |
    ForEach-Object {
        $_.Name.Substring(11).TrimStart('_').Replace("_",".")
    } | Where-Object { $_ -ne '' }
	#$versions = @("3.7", "3.10", "3.11", "3.13")
	$pythonEnvPaths = @{}
	foreach ($v in $versions) {
		#Write-Host $v
		$varName = "PYTHON_HOME_" + $v.Replace(".", "_")#+"%"
		#Write-Host $varName
		# Accesso dinamico corretto alla variabile di ambiente
		$value = [Environment]::ExpandEnvironmentVariables($varName)#$env:${varName}  # oppure: $value = $env[$varName]

		if ($value) {
			$pythonEnvPaths[$v] = $value
		}
	}
	# Controlla se la versione fornita è supportata
	if ($pythonEnvPaths.ContainsKey($Version)) {
		# Imposta PYTHON_HOME alla variabile corrispondente
		$env:PYTHON_HOME = [System.Environment]::GetEnvironmentVariable($pythonEnvPaths[$Version],"User")
		
		# Salva il valore ESPANSO per la prossima sessione
		[System.Environment]::SetEnvironmentVariable("PYTHON_HOME", [Environment]::ExpandEnvironmentVariables($pythonEnvPaths[$Version]), [System.EnvironmentVariableTarget]::User)
		
		$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
		# Vado a rendere espanse e quindi subito disponibili le folder definite in PATH
		fixPath
		Write-Host "PYTHON_HOME setted to: $env:PYTHON_HOME"
	} else {
		Write-Host "Error: Version $Version usupported."
		# Mostra le versioni disponibili
		Write-Host "Avaliable versions:"
		$pythonEnvPaths.Keys | ForEach-Object { Write-Host " - $_" }
		return -1
	}
	return 0
}

function choosePythonVenv{
	# Ottieni le cartelle che iniziano con ".venv" nella directory corrente
	$folders = Get-ChildItem -Directory | Where-Object { $_.Name -like ".venv*" }
	# Verifica se ci sono cartelle disponibili
	if ($folders.Count -eq 0) {
		Write-Host "No '.venv' folder found!"
		return 0
	}

	# Mostra la lista delle cartelle con un indice
	Write-Host "Choose a venv to enable from list:"
	for ($i = 0; $i -lt $folders.Count; $i++) {
		Write-Host "$($i + 1): $($folders[$i].Name)"
	}

	# Chiedi all'utente di selezionare un numero
	do {
		$selection = Read-Host "Choose number of '.venv':(0 to exit)"
		# Converti la selezione in numero
		$selectionInt=$selection -as [int]
		# verifica che sia valida
		if ($selectionInt -eq $null){
			Write-Host "Invalid input($selection)! ..."
		}else{
			if($selectionInt -eq 0){
				exit 1
			}else{
				# verifica che sia valida
				$isValid = ($selection -gt 0) -and ($selection -le $folders.Count)
				if (-not $isValid) {
					Write-Host "No valid choise, choose beetween 0 yo $($folders.Count)."
				}
			}
		}
	} until ($isValid)

	# Ottieni la cartella selezionata
	$selectedFolder = $folders[$selection - 1]

	# Mostra la cartella selezionata
	Write-Host "You choose: $($selectedFolder.FullName)"
	return $selectedFolder.Name
}

function createPythonVenv{
	param (
		[Parameter(Mandatory=$false,Position=0)]
		[string]$version,
		
		[Parameter(Mandatory=$false,Position=0)]
		[string]$name
	)
	# Write-Host "Version: $Version, Name: $Name"
	if(-not $Version){
		$Version=getCurrentPythonVersion
	}else{
		Write-Host "Going to set python version to ${Version} if exists:"
		$result = setPythonVersion -Version $Version
		# Controlla il codice di uscita
		if ($result -ne 0) {
			Write-Host "Exit with value $result"
			exit $result
		}
		Write-Host "Python version setted up!"		
	}
	if(-not $Name){
		# Chiedi all'utente il nome della venv per questa versione
		$Name=$userinput = Read-Host "Give me the name of venv for ${Version}"
		if($Name -eq ""){
			Write-Host "U gave me null"
			$venvFolderName = ".venv_$Version"
		}else{
			Write-Host "U gave me ${Name}"
			$venvFolderName = ".venv_${Version}_${Name}"
		}
	}else{
		$venvFolderName = ".venv_${Version}_${Name}"
	}

	# Verifica se la cartella esiste
	if (Test-Path $venvFolderName) {
		Write-Host "The venv $venvFolderName folder exists, I use it..."
	} else {
		Write-Host "The venv $venvFolderName does not exist, I will create it (waiting untill venv is created) ..."
		& python -m venv "$venvFolderName"
		Write-Host "Created $venvFolderName!"
	}
	return $venvFolderName
}

function enablePythonVenv{
	param(
		[Parameter(Mandatory=$false,Position=0)]
		[string]$venvFolderName
	)
	if($venvFolderName -eq ""){
		$venvFolderName = choosePythonVenv
	}
	if($venvFolderName -eq 0){
		$venvFolderName =  createPythonVenv
	}
	Write-Host "Enabling $venvFolderName!"
	# Attivo la venv
	& "$venvFolderName\Scripts\activate.ps1"
	Write-Host "Enabled!!!"
}



$available_functions=@{
	"setvenv" = "enablePythonVenv"
	"newvenv" = "createPythonVenv"
	"setversion" = "setPythonVersion"
}
$help_functions = @{
	"setvenv" = "Enable available python venv in this folder (.venv* folders)"
	"newvenv" = "-Version python_version -Name venv_name : to create python venv (.venv_Version_Name)"
	"setversion" = "-Version python_version: to set python version (if installed and configured in env as PYTHON_HOME_version) "
}

# Crea una lista (hashtable) con la parte dopo "PYTHON_HOME_" come chiave e il nome della variabile come valore
#$pythonEnvPaths = @{}
#Get-ChildItem Env: | Where-Object { $_.Name -like "PYTHON_HOME_*" } | ForEach-Object {
#    $key = $_.Name.Substring("PYTHON_HOME_".Length).Replace("_",".")   # Rimuove "PYTHON_HOME_" dalla parte iniziale
#	$pythonEnvPaths[$key] = $_.Name
#}
#Write-Host $pythonEnvPaths

# Ottieni il nome del comando corrente
$thisCommandName = $MyInvocation.MyCommand
function usageThisScript{
	Write-Host "Usage $thisCommandName -Function function [-Version version [-Name name]]"
	Write-Host "`tWhere function is:"
	foreach ($key in $help_functions.Keys) {
		$value = $help_functions[$key]
		Write-Host "`t${key}: $value"
	}
}
if(($available_functions.ContainsKey($Function))){
	switch ($Function) {
		"setversion" {
			& setPythonVersion -Version $Version
		}
		"newvenv" {
			& createPythonVenv -Version $Version -Name $Name
		}
		"setvenv" {
			& setPythonVenv -Version $Version -Name $Name
		}
		default {
			Write-Host "Unknown function: $Function"
			usageThisScript
		}
	}
}else{
	usageThisScript
}
