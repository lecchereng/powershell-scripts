param(
	[string]$Function,
	[string]$Version,
	[string]$Name
)
# Questo script funziona solo per versioni powershell naggiori di 7.0
# Verifica se la versione di PowerShell è maggiore o uguale a 7
$_PSVersion=$PSVersionTable.PSVersion
if ($_PSVersion -ge [Version]"7.0") {
    Write-Debug "PowerShell version is major o equal 7 ($_PSVersion)."
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
			Write-Output $expandedPath
			if($path -ne '') {
				$path=$path+";"
			}
			$path=$path+$expandedPath
		}
	}
	$env:PATH=$path
}

function setPythonVersion{
	param (
		[Parameter(Mandatory=$true)]
		[string]$Version
	)

	# Mappa le versioni ai percorsi delle variabili di ambiente
	$pythonEnvPaths = @{
		"3.7" = $env:PYTHON_3_7_HOME
		"3.10" = $env:PYTHON_3_10_HOME
		"3.11" = $env:PYTHON_3_11_HOME
		"3.13" = $env:PYTHON_3_13_HOME
	}

	# Controlla se la versione fornita è supportata
	if ($pythonPaths.ContainsKey($Version)) {
		# Imposta PYTHON_HOME alla variabile corrispondente
		$env:PYTHON_HOME = $pythonPaths[$Version]
		# Salva il valore ESPANSO per la prossima sessione
		[System.Environment]::SetEnvironmentVariable("PYTHON_HOME", [Environment]::ExpandEnvironmentVariables($pythonPaths[$Version]), [System.EnvironmentVariableTarget]::User)
		
		$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
		# Vado a rendere espanse e quindi subito disponibili le folder definite in PATH
		fixPath
		Write-Output "PYTHON_HOME setted to: $env:PYTHON_HOME"
	} else {
		Write-Output "Error: Version $Version usupported."
		# Mostra le versioni disponibili
		Write-Output "Avaliable versions:"
		$pythonPaths.Keys | ForEach-Object { Write-Output " - $_" }
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
		exit -2
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
	Write-Host "Version=$Version, Name=$Name"
	$venvFolderName = ".venv_$Version_$Name"
	Write-Host "venvFolderName=$venvFolderName"
	#exit 0
	Write-Host "Going to set python version if exists:"
	$result = setPythonVersion

	# Controlla il codice di uscita
	if ($result -ne 0) {
		Write-Host "Exit with value $result"
		exit $result
	}
	Write-Host "Python version setted up!"
	if($Name -eq $null){
		$return = choosePythonVenv
		if(($return -as [int]) -and ($return -eq 0)){
			# Chiedi all'utente il nomde dalal venv per questa versione
			$Name=$userinput = Read-Host "Give me the name of venv for ${Version}:(Empty kill script)"
			if($Name -eq $null){
				return -3
			}else{
				$venvFolderName = ".venv_$Version_$Name"
			}
		}else{
			$venvFolderName=$return
		}
	}else{
		$venvFolderName = ".venv_$Version_$Name"
	}

	# Verifica se la cartella esiste
	if (Test-Path $venvFolderName) {
		Write-Host "The venv $venvFolderName folder exists, I use it..."
	} else {
		Write-Host "The venv $venvFolderName does not exist, I will create it (waiting venv is created) ..."
		& python -m venv "$venvFolderName"
		Write-Host "Created $venvFolderName!"
	}
	return $venvFolderName
}

function enablePythonVenv{
	param(
		[string]$venvFolderName
	)
	if($venvFolderName -eq ""){
		$venvFolderName = choosePythonVenv
	}
	if($venvFolderName -eq 0){
		$venvFolderName =  createPythonVenv
	}
	Write-Output "Enabling $venvFolderName!"
	# Attivo la venv
	& "$venvFolderName\Scripts\activate.ps1"
	Write-Output "Enabled!!!"
}



$available_functions=@{
	"setvenv" = "enablePythonVenv"
	"newvenv" = "createPythonVenv"
	"setversion" = "setPythonVersion"
}
$help_functions = @{
	"setvenv" = "Enable available python venv in this folder (.venv* folders)"
	"newvenv" = "-Version python_version -Name venv_name : to create python venv (.venv_Version_Name)"
	"setversion" = "-Version python_version: to set python version (if installed and configured in env as PYTHON_Version_HOME) "
}

# Crea una lista (hashtable) con la parte dopo "PYTHON_HOME_" come chiave e il nome della variabile come valore
$pythonEnvPaths = @{}
Get-ChildItem Env: | Where-Object { $_.Name -like "PYTHON_HOME_*" } | ForEach-Object {
    $key = $_.Name.Substring("PYTHON_HOME_".Length).Replace("_",".")   # Rimuove "PYTHON_HOME_" dalla parte iniziale
	$pythonEnvPaths[$key] = $_.Name
}

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
	& $available_functions[$Function] $Version $Name
}else{
	usageThisScript
}
