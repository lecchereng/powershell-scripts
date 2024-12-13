# Definisci il percorso della cartella di lavoro (modifica questo percorso in base alla tua configurazione)
$jupyterHome = "C:\Users\LECCHER\Lavoro\jupyter-notebook"#$Env:JUPYTER_HOME

# Vai nella cartella di lavoro
Set-Location -Path $jupyterHome

# Trova tutte le cartelle che iniziano con .venv
$venvFolders = Get-ChildItem -Directory | Where-Object { $_.Name -like ".venv*" }

# Se non ci sono cartelle .venv, mostra un messaggio e termina lo script
if ($venvFolders.Count -eq 0) {
    Write-Host "None virtual environment found (.venv*)."
    exit
}

# Mostra la lista delle cartelle e chiedi all'utente di scegliere quale usare
Write-Host "Select which virtual environment to activate:"
$counter = 1
foreach ($folder in $venvFolders) {
    Write-Host "$counter. $($folder.Name)"
    $counter++
}

# Chiedi all'utente di fare una scelta
$selection = Read-Host "Insert virtual environment number you want activate (0 exit)"
$selectionInt = $selection -as [int]
if ($selectionInt -eq $null){
	Write-Host "Invalid selection."
    exit 1
}
if ($selectionInt -eq 0){
	Write-Host "Exiting."
	exit 0
}
# Controlla che la selezione sia valida
if ($selectionInt -lt 1 -or $selectionInt -gt $venvFolders.Count) {
    Write-Host "Invalid selection."
    exit 2
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
	Write-Host "Activated venv!"
    # Avvia Jupyter Lab
    Write-Host "Starting Jupyter Lab..."
    & jupyter lab
} else {
    Write-Host "None virtual environment found in the choise."
}
