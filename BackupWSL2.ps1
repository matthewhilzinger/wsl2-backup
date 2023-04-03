<#
.SYNOPSIS
Performs a backup of all WSL2 distros to named & dated .tar files in a specified directory.

.DESCRIPTION
The process consists of a single PowerShell script (BackupWSL2.ps1), that reads configuration variables from an associated JSON file (WSL2Backup-Configuration.json), and is triggered on a recurring schedule by Windows Task Scheduler. It queries WSL2 for all Linux instances, and performs a backup (to a separate .tar file) of each discovered instance.

The default schedule is to run the task every Monday morning at 7:00am - but this should be modified to suit your personal working style and requirements. If a scheduled start is missed (e.g. the computer is not powered on), then it will try to run as soon as possible.

The task only runs when the user is logged on, and runs as the logged-on user. It should appear as a standard PowerShell window, which closes once finished. The process needs to stop WSL services whilst taking the backup - so you won't be able to start a shell until it's finished, and the window is closed.

Modules required:
    - None

Permissions required:
    - None

.INPUTS
None. You cannot pipe objects to this script.

.OUTPUTS
None. This script does not generate any output objects.

.LINK
https://github.com/matthewhilzinger/wsl2-backup

.NOTES
Author: Matthew Hilzinger

#>

#region Parameters
# ===============================================================================================
# Script Input Parameters
# ===============================================================================================
[CmdletBinding(SupportsShouldProcess=$true)]
Param( )

# ------------------------------------------------
# Script Variables
# ------------------------------------------------
$strConfigurationFilePath = '.'
$strConfigurationFileName = 'WSL2Backup-Configuration.json'

# ===============================================================================================
#endregion


#region Functions
# ===============================================================================================
# Functions
# ===============================================================================================

Function Get-ScriptConfiguration
{
    Param (
        [String]$ConfigurationFileName
    )

    If (Test-Path $ConfigurationFileName) {
        Write-Output "Reading configuration file '$ConfigurationFileName'"
        $strConfigFileContent = Get-Content $ConfigurationFileName
        If ($?) {
            $objConfiguration = $strConfigFileContent | ConvertFrom-Json
            If ($null -ne $objConfiguration) {
                $arrConfigurationProperties = $objConfiguration | Get-Member -MemberType NoteProperty
                ForEach ($objConfigurationProperty in $arrConfigurationProperties) {
                    If ($objConfiguration.($objConfigurationProperty.Name) -is [Array]) {
                        $strVariableType = "arr"
                    } Else {
                        $strVariableType = $objConfiguration.($objConfigurationProperty.Name).GetTypeCode().ToString().SubString(0,3).ToLower()
                    }
                    $strVariableName = "{0}{1}" -f $strVariableType, $objConfigurationProperty.Name

                    If ($null -eq (Get-Variable $strVariableName -ErrorAction Ignore)) {
                        New-Variable -Name $strVariableName -Value $objConfiguration.($objConfigurationProperty.Name) -Scope Global
                    } Else {
                        Set-Variable -Name $strVariableName -Value $objConfiguration.($objConfigurationProperty.Name) -Scope Global
                    }
                    Write-Verbose ("[$strVariableName] = $($objConfiguration.($objConfigurationProperty.Name))")
                }
            }
        } Else {
            Write-Output "ERROR: Could not locate configuration file '$ConfigurationFileName'"
            break
        }
    } Else {
        Write-Output "ERROR: Could not locate configuration file '$ConfigurationFileName'"
        break
    }
}

Function Clear-OldFiles
{
<#
.SYNOPSIS
Deletes files from a specified directory that are older than a particular age (in days).

.PARAMETER Path
String. The file path to delete files from.

.PARAMETER Age
Integer. How many days' worth of files to keep. All older files are deleted, but will preserve a minimum number of matching files, if MinFilesToKeep is specified. Can not be less than 1.

.PARAMETER MinFilesToKeep
Integer. How many matching files to keep, regardless of their age. Default is 0.

.PARAMETER FileMask
String. File names to delete (including standard wildcards). Default is all files (i.e. and wildcard of *).

.INPUTS
None. You cannot pipe objects to this function.

.OUTPUTS
None. This function does not generate any output objects.

.NOTES
Author: Matthew Hilzinger

#>
    Param (
        [String]$Path,
        [Int]$Age,
        [Int]$MinFilesToKeep = 0,
        [String]$FileMask = '*'
    )
    If ($Age -gt 0) {
        $dteAgeForDeletion = (Get-Date).AddDays($Age * -1)
        If (Test-Path -Path $Path -PathType Container) {
            If ($MinFilesToKeep -gt 0) {
                $arrMatchingFilesThatMustBeKept = [Array](Get-ChildItem -Path $Path -Include @($FileMask) -Recurse -Depth 0 | Sort-Object LastWriteTime | Select-Object -last $MinFilesToKeep | Select-Object -expand FullName)
                $arrOldFilesForDeletion = [Array](Get-ChildItem -Path $Path -Include @($FileMask) -Recurse -Depth 0 | Where-Object { $_.LastWriteTime -lt $dteAgeForDeletion } | Where-Object { $_.FullName -notin $arrMatchingFilesThatMustBeKept })
            } Else {
                $arrOldFilesForDeletion = [Array](Get-ChildItem -Path $Path -Include @($FileMask) -Recurse -Depth 0 | Where-Object { $_.LastWriteTime -lt $dteAgeForDeletion })
            }
            If ($arrOldFilesForDeletion -is [Array]) {
                Write-Output "Clearing files older than $Age days from directory '$Path'"
                ForEach ($objFile in $arrOldFilesForDeletion) {
                    Write-Output "Deleting old log file '$($objFile.FullName)'."
                    # $objFile.Delete()
                }
            }
        } Else {
            Write-Output "ERROR: Clear-OldFiles: Path '$Path' not found."
        }
    } Else {
        Write-Output "ERROR: Clear-OldFiles: Minimum age for clearing files is 1 day."
    }
}


# ===============================================================================================
#endregion


#region Prologue
# ===============================================================================================
# Internal Variables and Parameter Validation
# ===============================================================================================

# --- Retrieve the contents of the configuration file
$strConfigurationFile = Join-path $strConfigurationFilePath $strConfigurationFileName
Get-ScriptConfiguration -ConfigurationFileName $strConfigurationFile

# --- Set the base logging configuration
$strTranscriptFileName = Join-Path $strLogPath ("Transcript-{0}.txt" -f ((Get-Date).ToString('yyyy-MM-dd')))
Start-Transcript -Path $strTranscriptFileName -Append

# ===============================================================================================
#endregion


#region MainRoutine
# ===============================================================================================
# Main Routine
# ===============================================================================================
$arrWslImages = @()
$objEncoding = [Text.Encoding]::GetEncoding('utf-8')

$arrWslListOutput = (wsl --list)
ForEach ($strWslListItem in $arrWslListOutput) {
    $arrBytes = ([Int[]]($strWslListItem.ToCharArray())) | Where-Object { $_ -ne 0 }
    If ($null -ne $arrBytes) {
        $strImageName = $objEncoding.GetString($arrBytes)
        If ($strImageName -notmatch "Windows Subsystem for Linux") {
            If ($strImageName.EndsWith('(Default)') -eq $true) {
                $arrWslImages += $strImageName.SubString(0, ($strImageName.Length -9)).Trim()
            } Else {
                $arrWslImages += $strImageName.Trim()
            }
        }
    }
}

If ($arrWslImages.Count -gt 1) {
    Write-Host "Identified $($arrWslImages.Count) WSL2 instances:" -f Cyan
} ElseIf ($arrWslImages.Count -gt 0) {
    Write-Host "Identified 1 WSL2 instance:" -f Cyan
} Else {
    Write-Host "ERROR: Failed to identify any WSL2 instances. Exiting." -f Red
    break
}

ForEach ($strWslImage in $arrWslImages) {
    Write-Host " - $strWslImage" -f Cyan
}

Write-Host "Stopping WSL2..." -f White
If ($?) {
    ForEach ($strWslImage in $arrWslImages) {
        $strDateStamp = (Get-Date).ToString("yyyy-MM-dd-HH-mm")
        $strExportFileName = Join-Path $strBackupPath ("WSL2 Backup - {0} {1}.tar" -f $strWslImage, $strDateStamp)
        Write-Host "Creating backup '$strExportFileName'" -f Cyan
        wsl --export $strWslImage  "$strExportFileName"
    }
} Else {
    Write-Host "ERROR: Failed to shutdown WSL2. Exiting." -f Red
    break
}


#region Epilogue
# ===============================================================================================
# ---------------------------------------------
# --- Delete old data files (input, processed, log, etc.)
# ---------------------------------------------

# --- Delete old backups
Clear-OldFiles -Path $strBackupPath -Age $intAgeOfBackupsToDelete -MinFilesToKeep $intMinNumOfBackupsToKeep -FileMask 'WSL2 Backup - *.tar'

# --- Delete old Transcript log files
Clear-OldFiles -Path $strLogPath -Age $intAgeOfOldLogFilesToDelete -FileMask 'Transcript-*.txt'

Stop-Transcript
# ===============================================================================================
#endregion

