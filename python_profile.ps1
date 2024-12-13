# Funzione per eseguire controlli quando si cambia directory
function Monitor-DirectoryChange {
    # Recupera il percorso corrente
    $currentDir = Get-Location

    # verifica se nella cartella corrente sono presenti delle cartelle .venv
	$venvFolders = Get-ChildItem -Directory | Where-Object { $_.Name -like ".venv*" }
	# Se non ci sono cartelle .venv, esce
	if ($venvFolders.Count -eq 0) {
		return 0
	}
	# Mostra la lista delle cartelle e chiedi all'utente di scegliere quale usare
	Write-Host "Select which virtual environment to activate:"
	$counter = 1
	foreach ($folder in $venvFolders) {
		Write-Host "$counter. $($folder.Name)"
		$counter++
	}
	# Chiede all'utente di fare una scelta
	$selection = Read-Host "Insert virtual environment number you want activate (0 exit)"
	$selectionInt = $selection -as [int]
	if ($selectionInt -eq $null){
		Write-Host "Invalid selection."
		return 1
	}
	if ($selectionInt -eq 0){
		return 0
	}
	# Controlla che la selezione sia valida
	if ($selectionInt -lt 1 -or $selectionInt -gt $venvFolders.Count) {
		Write-Host "Invalid selection."
		return 2
	}
	# Ottieni la cartella scelta
	$selectedVenvName = $venvFolders[$selectionInt - 1].Name
	Write-Debug $selectedVenvName
	# Attiva il virtual environment
	$venvActivateScript = "${selectedVenvName}\Scripts\Activate.ps1"
	Write-Debug $venvActivateScript
	if (Test-Path $venvActivateScript) {
		Write-Host "Activating venv..."
		# Attiva il virtual environment
		& $venvActivateScript
		Write-Host "Activated!"
	}
}

# Sovrascrive la funzione 'cd' (o 'Set-Location') per monitorare i cambiamenti di directory
function Set-Location {
    param (
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
        [Alias("Path")]
        [string]$LiteralPath
    )
    
    # Usa il comando originale per cambiare directory
    Microsoft.PowerShell.Management\Set-Location -LiteralPath $LiteralPath

    # Chiama la funzione per monitorare il cambiamento
    Monitor-DirectoryChange
}