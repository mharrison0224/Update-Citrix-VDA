<## 

This Script will update the VDA on MCS Master Images & Designed to be ran via Startup GPO

1. Extract Citrix_Virtual_Apps_and_Desktops_7_1912_1000.iso install to a file share of your choice

2. Update the variable $FileShare with the share name that points to the root folder of the extracted Citrix_Virtual_Apps_and_Desktops_7_1912_1000.iso

3. Download the citrix VDACleanupUtility.exe to the root of $FileShare

4. Ensure the VDAWorkstationSetup_1912.exe & VDAServerSetup_1912.exe are in the root of the share

5. Update the $InstallArgs with your delivery controllers & any other arguments you want from the installer

6. Create a GPO startup script that runs this script (note: I put this script in the root of $FileShare and then set the GPO to run off that fileshare)

##> 

function Write-Log 
{ 
    [CmdletBinding()] 
    Param 
    ( 
        [Parameter(Mandatory=$true, 
                   ValueFromPipelineByPropertyName=$true)] 
        [ValidateNotNullOrEmpty()] 
        [Alias("LogContent")] 
        [string]$Message, 
 
        [Parameter(Mandatory=$false)] 
        [Alias('LogPath')] 
        [string]$Path='C:\Logs\PowerShellLog.log', 
         
        [Parameter(Mandatory=$false)] 
        [ValidateSet("Error","Warn","Info")] 
        [string]$Level="Info", 
         
        [Parameter(Mandatory=$false)] 
        [switch]$NoClobber 
    ) 
 
    Begin 
    { 
        # Set VerbosePreference to Continue so that verbose messages are displayed. 
        $VerbosePreference = 'Continue' 
    } 
    Process 
    { 
         
        # If the file already exists and NoClobber was specified, do not write to the log. 
        if ((Test-Path $Path) -AND $NoClobber) { 
            Write-Error "Log file $Path already exists, and you specified NoClobber. Either delete the file or specify a different name." 
            Return 
            } 
 
        # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path. 
        elseif (!(Test-Path $Path)) { 
            Write-Verbose "Creating $Path." 
            $NewLogFile = New-Item $Path -Force -ItemType File 
            } 
 
        else { 
            # Nothing to see here yet. 
            } 
 
        # Format Date for our Log File 
        $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss" 
 
        # Write message to error, warning, or verbose pipeline and specify $LevelText 
        switch ($Level) { 
            'Error' { 
                Write-Error $Message 
                $LevelText = 'ERROR:' 
                } 
            'Warn' { 
                Write-Warning $Message 
                $LevelText = 'WARNING:' 
                } 
            'Info' { 
                Write-Verbose $Message 
                $LevelText = 'INFO:' 
                } 
            } 
         
        # Write log entry to $Path 
        "$FormattedDate $LevelText $Message" | Out-File -FilePath $Path -Append 
    } 
    End 
    { 
    } 
}

# SET THIS TO THE FILE SHARE THAT HAS THE INSTALL ISO EXTRACTED TO
# MAKE SURE THIS FILE SHARE HAD READ PERMISSIONS TO EVERYONE
$FileShare = "\\ServerName\VDADeploymentShare$"

# Must Be Set before running Write-Log Function or it will not work
# Verify Share permissions for this to allow for logs to be written to network location
# Alternatvely, change this to a local machine location such as C:\Program Files (x86)\VDAUpdater if you would prefer no network logs
$LogFile = "\\ServerName\VDALogs$\$ENV:COMPUTERNAME-VDAInstall.log"

# Set ENV: Vars
Write-Log "Setting env variables for the script" -Path $LogFile
$OS = (Get-WmiObject Win32_OperatingSystem).Name
$VDACleaner = "$FileShare\VDACleanupUtility.exe"
$SouceISO = "$FileShare\VDAWorkstationSetup_1912.exe"
$ServerISO = "$FileShare\VDAServerSetup_1912.exe"
$IntendedVer = "1912.0.1000.24525"
$InstallArgs = "/QUIET /NOREBOOT /NORESUME /CONTROLLERS 'deliverycontroller1.corp.com deliverycontroller2.corp.com' /VERBOSELOG /COMPONENTS VDA /ENABLE_HDX_PORTS /ENABLE_REAL_TIME_TRANSPORT"

# Compare Current Version w/ Intended Version
# Create local VDAUpdater folder which is needed for .exe files
Write-Log "Creating Folder C:\Program Files (x86)\VDAUpdater for VDA install" -Path $LogFile
New-Item -Path 'C:\Program Files (x86)\VDAUpdater' -ItemType Directory -ErrorAction SilentlyContinue

$CurrentVer = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Citrix Virtual Desktop Agent" -Name "DisplayVersion" -ErrorAction SilentlyContinue
$RunMe = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Citrix Virtual Desktop Agent" -Name "RunMe" -ErrorAction SilentlyContinue

if (($CurrentVer.DisplayVersion -ne $IntendedVer) -and ($CurrentVer.DisplayVersion -ne $null)) 
{ 
    Write-Log "** Starting VDA Cleanup **" -Path $LogFile
    $CleanUpTest = Test-Path 'C:\Program Files (x86)\VDAUpdater\VDACleanupUtility.exe'
    if (!$CleanUpTest){Copy-Item -Path $VDACleaner -Destination 'C:\Program Files (x86)\VDAUpdater'}

    ## Start the exe process ##
    $ProcessOutput = Start-Process -FilePath 'C:\Program Files (x86)\VDAUpdater\VDACleanupUtility.exe' -ArgumentList "/unattended"  -Wait
    Restart-Computer -Force

}

if ($OS -like "*Windows 10*")
{
    
    if ( ($CurrentVer -eq $null) -or ($CurrentVer.DisplayVersion -lt $IntendedVer) -or ($RunMe.RunMe -eq 1) ) 
    {

        ## Copy Installation Media to VDAUpdater Folder ##
        Write-Log "** Installing the VDA **" -Path $LogFile
        Write-Log 'Machine type: Workstation' -Path $LogFile
        $TestPath = Test-Path 'C:\Program Files (x86)\VDAUpdater\VDAWorkstationSetup_1912.exe'
        if (!$TestPath){Copy-Item -Path $SouceISO -Destination 'C:\Program Files (x86)\VDAUpdater'}
    
        $Var = Start-Process -FilePath 'C:\Program Files (x86)\VDAUpdater\VDAWorkstationSetup_1912.exe' -ArgumentList $InstallArgs -Wait -PassThru

        if ($Var.ExitCode -eq 3) 
        {
            Write-Log "VDA installer Exit Code: $($Var.ExitCode)" -Path $LogFile
            if (!$RunMe) {New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Citrix Virtual Desktop Agent" -Name "RunMe" -Value 1}
            if ($RunMe) {Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Citrix Virtual Desktop Agent" -Name "RunMe" -Value 1}
            Restart-Computer -Force
        }

        if ($Var.ExitCode -eq 0)
        {
            Write-Log "VDA installer Exit Code: $($Var.ExitCode)" -Path $LogFile
            if (!$RunMe) {New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Citrix Virtual Desktop Agent" -Name "RunMe" -Value 0}
            if ($RunMe) {Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Citrix Virtual Desktop Agent" -Name "RunMe" -Value 0}
            Restart-Computer -Force

        }

    }
}

if ($OS -like "*Server*"){

    if ( ($CurrentVer -eq $null) -or ($CurrentVer.DisplayVersion -lt $IntendedVer) -or ($RunMe.RunMe -eq 1) ) 
    {

        ## Copy Installation Media to VDAUpdater Folder ##
        Write-Log "** Installing the VDA **" -Path $LogFile
        Write-Log "Machine Type: Server" -Path $LogFile
        $TestPath = Test-Path 'C:\Program Files (x86)\VDAUpdater\VDAServerSetup_1912.exe'
        if (!$TestPath){Copy-Item -Path $ServerISO -Destination 'C:\Program Files (x86)\VDAUpdater'}
    
        $Var = Start-Process -FilePath 'C:\Program Files (x86)\VDAUpdater\VDAServerSetup_1912.exe' -ArgumentList $InstallArgs -Wait -PassThru

        if ($Var.ExitCode -eq 3) 
        {
            Write-Log "VDA installer Exit Code: $($Var.ExitCode)" -Path $LogFile
            if (!$RunMe) {New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Citrix Virtual Desktop Agent" -Name "RunMe" -Value 1}
            if ($RunMe) {Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Citrix Virtual Desktop Agent" -Name "RunMe" -Value 1}
            Restart-Computer -Force
        }

        if ($Var.ExitCode -eq 0)
        {
            Write-Log "VDA installer Exit Code: $($Var.ExitCode)" -Path $LogFile
            if (!$RunMe) {New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Citrix Virtual Desktop Agent" -Name "RunMe" -Value 0}
            if ($RunMe) {Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Citrix Virtual Desktop Agent" -Name "RunMe" -Value 0}
            Restart-Computer -Force

        }

    }

}
