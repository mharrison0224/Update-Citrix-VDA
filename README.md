# Update-Citrix-VDA

<## 

This Script will update the VDA on MCS Master Images & Designed to be ran via Startup GPO

1. Extract Citrix_Virtual_Apps_and_Desktops_7_1912_1000.iso install to a file share of your choice

2. Update the variable $FileShare with the share name that points to the root folder of the extracted Citrix_Virtual_Apps_and_Desktops_7_1912_1000.iso

3. Download the citrix VDACleanupUtility.exe to the root of $FileShare

4. Ensure the VDAWorkstationSetup_1912.exe & VDAServerSetup_1912.exe are in the root of the share

5. Update the $InstallArgs with your delivery controllers & any other arguments you want from the installer

6. Create a GPO startup script that runs this script (note: I put this script in the root of $FileShare and then set the GPO to run off that fileshare)

##> 
