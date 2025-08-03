# Script Parameters
# --- Dichiarazione dei Parametri dello Script ---
param(
    # Questi parametri sono obbligatori in entrambi i set di metadati
    [Parameter(Mandatory=$true, Position=0, ParameterSetName="ByString")]
    [Parameter(Mandatory=$true, Position=0, ParameterSetName="ByFile")]
    [string]$InputFile,

    [Parameter(Mandatory=$true, Position=1, ParameterSetName="ByString")]
    [Parameter(Mandatory=$true, Position=1, ParameterSetName="ByFile")]
    [string]$OutputFile,

    # Parametri mutualmente esclusivi per i metadati
    [Parameter(Mandatory=$true, ParameterSetName="ByString", HelpMessage="String containing FFmpeg metadata parameters (e.g., '-metadata title=`"My Title`"').")]
    [string]$MetadataParameters,

    [Parameter(Mandatory=$true, ParameterSetName="ByFile", HelpMessage="Path to a text file containing FFmpeg metadata parameters.")]
    [string]$MetadataFile,

    # Set di parametri per mostrare solo l'aiuto
    [Parameter(Mandatory=$true, ParameterSetName="ShowHelp", HelpMessage="Displays this help message.")]
    [switch]$Help
)

function Show-Help {
    <#
    .SYNOPSIS
    Explains how to use the script to add metadata to an MP4 file with FFmpeg.

    .DESCRIPTION
    This function provides instructions on how to run the script,
    illustrating the necessary and optional parameters. It also includes a
    list of common metadata that can be added or modified.

    .EXAMPLE
    Show-Help

    .NOTES
    To add metadata, use FFmpeg flags like -metadata title="My Title".
    Be sure to enclose values with spaces in double quotes.
    #>
    Write-Host "--- Script Usage Guide ---"
    Write-Host ""
    Write-Host "This script allows you to add or modify metadata in an MP4 file using FFmpeg."
    Write-Host ""
    Write-Host "Syntax:"
    Write-Host "    metadd.ps1 -InputFile <Mp4FilePath> -OutputFile <Mp4FilePath> -MetadataParameters <FFmpegParameters>"
    Write-Host ""
    Write-Host "Parameters:"
    Write-Host "    -InputFile: (Mandatory) The full path to the source MP4 file."
    Write-Host "    -OutputFile: (Mandatory) The full path to the destination MP4 file (can be the same as the input file to overwrite)."
    Write-Host "    -MetadataParameters: (Mandatory) A string containing FFmpeg metadata parameters."
    Write-Host "                         Each metadata field must be specified with '-metadata metadata_name=`"Metadata Value`"'."
    Write-Host "                         For example: '-metadata title=`"My Song`" -metadata artist=`"My Name`"'"
    Write-Host "    -MetadataFile: (Optional) The path to a text file containing FFmpeg metadata parameters."
    Write-Host "                   Each line in the file should contain one or more metadata parameters."
    Write-Host "                   Example file content:"
    Write-Host "                   -------------------------------------"
    Write-Host "                   -metadata title=`"My Video Title`" -metadata artist=`"Video Creator`""
    Write-Host "                   -metadata genre=`"Documentary`" -metadata date=`"2023`""
    Write-Host "                   -------------------------------------"
    Write-Host "                   Note: You must use either -MetadataParameters OR -MetadataFile, not both."
    Write-Host "    -Help: (Optional) Displays this help message."
    Write-Host ""
    Write-Host "List of common metadata fields supported by FFmpeg:"
    Write-Host "    - **title**: Title of the song/video."
    Write-Host "    - **artist**: Artist/Author."
    Write-Host "    - **album**: Album the track belongs to."
    Write-Host "    - **genre**: Music/video genre."
    Write-Host "    - **date**: Year or publication date."
    Write-Host "    - **comment**: Additional comments."
    Write-Host "    - **composer**: Composer."
    Write-Host "    - **publisher**: Publisher."
    Write-Host "    - **track**: Track number in the album (e.g., 1/10)."
    Write-Host "    - **disc**: Disc number (e.g., 1/2)."
    Write-Host "    - **encoder**: Software used for encoding."
    Write-Host "    - **copyright**: Copyright information."
    Write-Host "    - **description**: Description of the content."
    Write-Host "    - And many more! For a complete and detailed list, refer to the official FFmpeg documentation on metadata: https://ffmpeg.org/ffmpeg-formats.html#Metadata"
    Write-Host ""
    Write-Host "Remember to use double quotes for metadata values that contain spaces."
    Write-Host "--- End of Guide ---"
}


# Function to check FFmpeg installation
function Test-FFmpegInstallation {
    Write-Host "Checking FFmpeg installation..."
    try {
        # Attempt to run ffmpeg with a command that doesn't modify anything but verifies execution
        $null = & ffmpeg -version 2>&1
        Write-Host "FFmpeg is installed and working."
        return $true
    } catch {
        Write-Host "FFmpeg was not found in the PATH or is not installed."
        Write-Host "Please download FFmpeg from one of the following links and add it to your system PATH:"
        Write-Host "  - Official FFmpeg website: https://ffmpeg.org/download.html"
        Write-Host "  - gyan.dev builds (Windows): https://www.gyan.dev/ffmpeg/builds/"
        Write-Host "  - chocolatey (to install via package manager): choco install ffmpeg"
        Write-Host "After installation, please restart your PowerShell session."
        return $false
    }
}

# 1. First of all check -Help parameter
# This is first block checked afte parameters declaration
if ($PSCmdlet.ParameterSetName -eq "ShowHelp") {
    Show-Help
    exit
}

# 2. CHeck that mandatory parameters are peovided
# This block is executed JUST IF -Help parameter IS NOT provided
if (-not $PSBoundParameters.ContainsKey("InputFile") -or
    -not $PSBoundParameters.ContainsKey("OutputFile") -or
    (-not $PSBoundParameters.ContainsKey("MetadataParameters") -and -not $PSBoundParameters.ContainsKey("MetadataFile"))) {
    
    Write-Error "Missing mandatory parameters for the operation. Please provide -InputFile, -OutputFile, and either -MetadataParameters or -MetadataFile."
    Show-Help # Mostra l'aiuto se i parametri essenziali non sono forniti
    exit 1
}

# Verify that input and output files have .mp4 extension
if ((Split-Path $InputFile -Extension) -ne ".mp4") {
    Write-Error "The input file '$InputFile' is not an MP4 file. Please ensure it has a .mp4 extension."
    exit 1
}

if ((Split-Path $OutputFile -Extension) -ne ".mp4") {
    Write-Error "The output file '$OutputFile' is not an MP4 file. Please ensure it has a .mp4 extension."
    exit 1
}

# Check if the input file exists
if (-not (Test-Path $InputFile)) {
    Write-Error "The input file '$InputFile' does not exist. Please check the path."
    exit 1
}

# Run FFmpeg installation check
if (-not (Test-FFmpegInstallation)) {
    exit 1 # Exits if FFmpeg is not installed
}

# Check if output file exists
if (Test-Path $OutputFile) {
    Write-Warning "The output file '$OutputFile' already exists."
    $confirm = Read-Host "Do you want to overwrite it? (Y/N)"

    if ($confirm -notmatch "^[Yy]$") {
        Write-Host "Operation cancelled by user."
        exit 0 # Esci con codice 0 per indicare un'uscita "pulita"
    } else {
        Write-Host "Overwriting existing file '$OutputFile'..."
        Remove-Item $OutputFile -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "Preparing to add metadata..."

# --- Management of parameters of metadata from file or from stirng ---
$finalMetadataParams = ""
if ($PSCmdlet.ParameterSetName -eq "ByFile") {
    if (-not (Test-Path $MetadataFile)) {
        Write-Error "The metadata file '$MetadataFile' does not exist. Please check the path."
        exit 1
    }
    Write-Host "Reading metadata parameters from '$MetadataFile'..."
	# Read each line from file and add to the useful string
	# Ensure that each line is a valid ffmpeg parameter, eg: -metadata title="My Title"
    $finalMetadataParams = (Get-Content $MetadataFile | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim() }) -join " "
    if ([string]::IsNullOrWhiteSpace($finalMetadataParams)) {
        Write-Warning "The metadata file '$MetadataFile' is empty or contains no valid parameters."
    }
} elseif ($PSCmdlet.ParameterSetName -eq "ByString") {
    $finalMetadataParams = $MetadataParameters
}
# Construct the FFmpeg command
# -i "$InputFile": specifies the input file
# -map_metadata 0: copies all existing metadata from input stream 0 (the input file)
# -c copy: copies video and audio streams without re-encoding (much faster)
# $MetadataParameters: the metadata parameters passed by the user
# "$OutputFile": specifies the output file
$ffmpegCommand = "ffmpeg -i `"$InputFile`" -map 0 -map_metadata 0 -c copy $finalMetadataParams `"$OutputFile`""

Write-Host "FFmpeg command to be executed: $ffmpegCommand"
Write-Host "Starting metadata addition. This may take a moment..."

try {
    # Execute the FFmpeg command
    # 2>&1 | Write-Host redirects error and standard output to the console
    Invoke-Expression $ffmpegCommand 2>&1 | Write-Host

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Metadata successfully added to file '$OutputFile'."
    } else {
        Write-Error "An error occurred while adding metadata. FFmpeg exit code: $LASTEXITCODE"
    }
} catch {
    Write-Error "An error occurred during FFmpeg execution: $($_.Exception.Message)"
}