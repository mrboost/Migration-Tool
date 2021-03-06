begin {

    # Hide PowerShell Console
    Add-Type -Name Window -Namespace Console -MemberDefinition '
    [DllImport("Kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
    '
    $consolePtr = [Console.Window]::GetConsoleWindow()
    [Console.Window]::ShowWindow($consolePtr, 0)

    # Define the script version
    $ScriptVersion = "1.1.0"

    # Set ScripRoot variable to the path which the script is executed from
    $ScriptRoot = if ($PSVersionTable.PSVersion.Major -lt 3) {
        Split-Path -Path $MyInvocation.MyCommand.Path
    }
    else {
        $PSScriptRoot
    }

    $DefaultIncludeAppData = $true
    $DefaultIncludeLocalAppData = $false
    $DefaultIncludePrinters = $true
    $DefaultIncludeRecycleBin = $false
    $DefaultIncludeMyDocuments = $true
    $DefaultIncludeWallpapers = $true
    $DefaultIncludeDesktop = $true
    $DefaultIncludeDownloads = $true
    $DefaultIncludeFavorites = $true
    $DefaultIncludeMyMusic = $true
    $DefaultIncludeMyPictures = $true
    $DefaultIncludeMyVideo = $true
    $DefaultIncludeNewDesktop = $false
    $DefaultIncludeNewLaptop = $false

    # Set a value for the wscript comobject
    $WScriptShell = New-Object -ComObject wscript.shell

    function Update-Log {
        param(
            [string] $Message,

            [string] $Color = 'White',

            [switch] $NoNewLine
        )

        $LogTextBox.SelectionColor = $Color
        $LogTextBox.AppendText("$Message")
        if (-not $NoNewLine) { $LogTextBox.AppendText("`n") }
        $LogTextBox.Update()
        $LogTextBox.ScrollToCaret()
    }

    function installPlanet {
        # Show input box popup and return the value entered by the user.
        function Read-InputBoxDialog([string]$Message, [string]$WindowTitle, [string]$DefaultText)
        {
            Add-Type -AssemblyName Microsoft.VisualBasic
            return [Microsoft.VisualBasic.Interaction]::InputBox($Message, $WindowTitle, $DefaultText)
        }
        $textEntered = Read-InputBoxDialog -Message "Copy the below address and press 'OK'`n`nInstaller will launch after pressing 'OK'" -WindowTitle "Plant Application Install" -DefaultText "CHPRDSQL1701\INPRDPROF"
        Push-Location '\\chprdfs01\dist\swd\CLT\Plant Application 7\Proficy Admin and client installer'
        Start-Process -FilePath "PlantApplicationsClientSetup.exe" -wait
        Pop-Location
        Update-Log -message "Plant Applications Installed is complete!"

    }

    function installPi {
        Push-Location \\SGPRDFS01\Groups\PI-Install\Install_CH
        Start-Process -FilePath "Install_CH-SemiSilent-PB.bat" -wait
        (Get-WmiObject win32_product | Where-Object Name -Match "PI AF Client*").Uninstall()
        Start-Process -FilePath "Install_CH-SemiSilent-DL.bat" -wait
        Pop-Location
        Update-Log -message "PI Installed is complete!"
    }

    function installLenovo {
        Push-Location \\sgprdfs01\installs$\Lenovo
        Start-Process -FilePath "system_update_5.07.0136.exe" -wait
        Pop-Location
        Update-Log -message "Lenovo System Update install is complete!"
    }

    function installLenovoDrivers {
        Push-Location '\\sgprdfs01\installs$\Lenovo\USB-C Dock Gen2 Drivers'
        Start-Process -FilePath "thinkpad_usb-c_dock_gen2_drivers_v1.0.2.06121.exe" -wait
        Pop-Location
        Update-Log -message "Dock drivers install is complete!"
    }

    function remoteCdrive {
		$remoteMachine = $OldComputerNameTextBox_OldPage.Text
		Update-Log "$remoteMachine - Open C$ Drive"
		$PathToCDrive = "\\$remoteMachine\c$"
		Explorer.exe $PathToCDrive
	}

    function remotenewCdrive {
		$destination = $NewComputerNameTextBox_OldPage.Text
		Update-Log "$destination - Open C$ Drive"
		$PathToCDrive = "\\$destination\c$"
		Explorer.exe $PathToCDrive
	}
    function Save-UserState {
        param(
            [switch] $Debug
        )
		
		Update-Log "`nBeginning migration..."
		
		$remoteUser = $OldComputerIPTextBox_OldPage.Text
		$remoteMachine = $OldComputerNameTextBox_OldPage.Text
		$destination = $NewComputerNameTextBox_OldPage.Text
		$ErrorActionPreference = 'silentlycontinue'
		
		$folder = @($IncludeDesktopCheckBox,
			$IncludeDownloadsCheckBox,
			$IncludeFavoritesCheckBox,
			$IncludeMyDocumentsCheckBox,
			$IncludeMyMusicCheckBox,
			$IncludeMyPicturesCheckBox,
			$IncludeMyVideoCheckBox)

		###############################################################################################################
		
		$username = $remoteUser
		$userprofile = "\\" + "$remoteMachine" + "\c$\Users\" + "$remoteUser"
		$appData = "\\" + "$remoteMachine" + "\c$\Users\" + "$remoteUser" + "\AppData\Local"
		
        $remoteComputer = $remoteMachine
            IF  ((!$destination -eq "") -and (!$remoteMachine -eq "") -and (Test-Connection -BufferSize 32 -Count 1 -ComputerName $remoteMachine -Quiet) -and (Test-Connection -BufferSize 32 -Count 1 -ComputerName $destination -Quiet)-and (Test-Path -Path $userprofile)) {
                Update-Log -Message ""
                Update-Log -Message "The remote machine is Online" -Color 'Green'
                Update-Log -Message ""
                Update-Log -Message "Backing up data from local machine for $username"
                foreach ($f in $folder)
		{
			if ($f.Checked -eq $true)
			{

				$currentLocalFolder = $userprofile + "\" + $f.Text
				$currentRemoteFolder = "\\" + "$destination" + "\" + "C$" + "\LocalBackup\" + $username + "\" + $f.Text
				$currentFolderSize = (Get-ChildItem -ErrorAction silentlyContinue $currentLocalFolder -Recurse -Force | Measure-Object -ErrorAction silentlyContinue -Property Length -Sum).Sum / 1MB
				$currentFolderSizeRounded = [System.Math]::Round($currentFolderSize)
                $currentFolder = $f.Text
                Update-Log -Message "  $currentFolder ... ($currentFolderSizeRounded MB)"
                robocopy "$currentLocalFolder" "$currentRemoteFolder" /S /E /R:1
				#Copy-Item -ErrorAction silentlyContinue -recurse $currentLocalFolder $currentRemoteFolder
			}
			
		}
		Update-Log -Message "Backup complete!"
            } Else {
                Update-Log -Message ""
                Update-Log -Message "The remote/destination machine is Down or Username is incorrect" -Color 'Red'
            }
	}
	
	function Set-Logo
	{

        Update-Log "             __  __ _                 _   _             " -Color 'LightBlue'
        Update-Log "            |  \/  (_) __ _ _ __ __ _| |_(_) ___  _ __  " -Color 'LightBlue'
        Update-Log "            | |\/| | |/ _`` | '__/ _`` | __| |/ _ \| '_ \ " -Color 'LightBlue'
        Update-Log "            | |  | | | (_| | | | (_| | |_| | (_) | | | |" -Color 'LightBlue'
        Update-Log "            |_|  |_|_|\__, |_|  \__,_|\__|_|\___/|_| |_|" -Color 'LightBlue'
        Update-Log "                _     |___/  _     _              _     " -Color 'LightBlue'
        Update-Log "               / \   ___ ___(_)___| |_ __ _ _ __ | |_   " -Color 'LightBlue'
        Update-Log "              / _ \ / __/ __| / __| __/ _`` | '_ \| __|  " -Color 'LightBlue'
        Update-Log "             / ___ \\__ \__ \ \__ \ || (_| | | | | |_   " -Color 'LightBlue'
        Update-Log "            /_/   \_\___/___/_|___/\__\__,_|_| |_|\__| $ScriptVersion" -Color 'LightBlue'
        Update-Log
        Update-Log '                        by Aaron Daily' -Color 'Gold'
		Update-Log 
    }

    function Test-IsISE { if ($psISE) { $true } else { $false } }

    function Test-PSVersion {
        if ($PSVersionTable.PSVersion.Major -lt 3) {
            Update-Log "You are running a version of PowerShell less than 3.0 - some features have been disabled."
            $ChangeSaveDestinationButton.Enabled = $false
            $ChangeSaveSourceButton.Enabled = $false
            $AddExtraDirectoryButton.Enabled = $false
            $SelectProfileButton.Enabled = $false
            $IncludeCustomXMLButton.Enabled = $false
        }
    }


    # Hide parent PowerShell window unless run from ISE or set $HidePowershellWindow to false
    if ((-not $(Test-IsISE)) -and ($HidePowershellWindow) ) {
        $ShowWindowAsync = Add-Type -MemberDefinition @"
    [DllImport("user32.dll")]
public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
"@ -Name "Win32ShowWindowAsync" -Namespace Win32Functions -PassThru
        $ShowWindowAsync::ShowWindowAsync((Get-Process -Id $PID).MainWindowHandle, 0) | Out-Null
    }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $Script:Destination = ''
}

process {
    # Create form
    $Form = New-Object System.Windows.Forms.Form
    $Form.Text = 'Migration Assistant by Aaron Daily'
    $Form.Size = New-Object System.Drawing.Size(1000, 550)
    $Form.SizeGripStyle = 'Hide'
    $Form.FormBorderStyle = 'FixedSingle'
    $Form.MaximizeBox = $false
    $Form.StartPosition = "CenterScreen"
    $iconBase64      = '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'
    $iconBytes       = [Convert]::FromBase64String($iconBase64)
    # initialize a Memory stream holding the bytes
    $stream          = [System.IO.MemoryStream]::new($iconBytes, 0, $iconBytes.Length)
    $Form.Icon       = [System.Drawing.Icon]::FromHandle(([System.Drawing.Bitmap]::new($stream).GetHIcon()))

    # Create tab controls
    $TabControl = New-object System.Windows.Forms.TabControl
    $TabControl.DataBindings.DefaultDataSourceUpdateMode = 0
    $TabControl.Location = New-Object System.Drawing.Size(10, 10)
    $TabControl.Size = New-Object System.Drawing.Size(480, 490)

    $Form.Controls.Add($TabControl)

    # Log output text box
    $LogTextBox = New-Object System.Windows.Forms.RichTextBox
    $LogTextBox.Location = New-Object System.Drawing.Size(500, 30)
    $LogTextBox.Size = New-Object System.Drawing.Size(475, 472)
    $LogTextBox.ReadOnly = 'True'
    $LogTextBox.BackColor = 'Black'
    $LogTextBox.ForeColor = 'White'
    $LogTextBox.Font = 'Consolas, 10'
	$LogTextBox.DetectUrls = $false
    Set-Logo
    $Form.Controls.Add($LogTextBox)
	
	# Clear log button
    $ClearLogButton = New-Object System.Windows.Forms.Button
    $ClearLogButton.Location = New-Object System.Drawing.Size(370, 505)
    $ClearLogButton.Size = New-Object System.Drawing.Size(80, 20)
    $ClearLogButton.FlatStyle = 1
    $ClearLogButton.BackColor = 'White'
    $ClearLogButton.ForeColor = 'Black'
    $ClearLogButton.Text = 'Clear'
    $ClearLogButton.Add_Click({ $LogTextBox.Clear() })
    $LogTextBox.Controls.Add($ClearLogButton)

    # Create old computer tab
    $OldComputerTabPage = New-Object System.Windows.Forms.TabPage
    $OldComputerTabPage.DataBindings.DefaultDataSourceUpdateMode = 0
    $OldComputerTabPage.UseVisualStyleBackColor = $true
    $OldComputerTabPage.Text = 'Information'
    $TabControl.Controls.Add($OldComputerTabPage)

    # Computer info group
    $OldComputerInfoGroupBox = New-Object System.Windows.Forms.GroupBox
    $OldComputerInfoGroupBox.Location = New-Object System.Drawing.Size(10, 10)
    $OldComputerInfoGroupBox.Size = New-Object System.Drawing.Size(450, 87)
    $OldComputerInfoGroupBox.Text = 'Computer Info'
    $OldComputerTabPage.Controls.Add($OldComputerInfoGroupBox)

    # Name label
    $ComputerNameLabel_OldPage = New-Object System.Windows.Forms.Label
    $ComputerNameLabel_OldPage.Location = New-Object System.Drawing.Size(100, 12)
    $ComputerNameLabel_OldPage.Size = New-Object System.Drawing.Size(100, 22)
    $ComputerNameLabel_OldPage.Text = 'Computer Name'
    $OldComputerInfoGroupBox.Controls.Add($ComputerNameLabel_OldPage)

    # IP label
    $ComputerIPLabel_OldPage = New-Object System.Windows.Forms.Label
    $ComputerIPLabel_OldPage.Location = New-Object System.Drawing.Size(230, 12)
    $ComputerIPLabel_OldPage.Size = New-Object System.Drawing.Size(80, 22)
    $ComputerIPLabel_OldPage.Text = 'User Name'
    $OldComputerInfoGroupBox.Controls.Add($ComputerIPLabel_OldPage)

    # Old Computer name label
    $OldComputerNameLabel_OldPage = New-Object System.Windows.Forms.Label
    $OldComputerNameLabel_OldPage.Location = New-Object System.Drawing.Size(12, 35)
    $OldComputerNameLabel_OldPage.Size = New-Object System.Drawing.Size(80, 22)
    $OldComputerNameLabel_OldPage.Text = 'Old Computer'
    $OldComputerInfoGroupBox.Controls.Add($OldComputerNameLabel_OldPage)
	
	# Old Computer name text box
    $OldComputerNameTextBox_OldPage = New-Object System.Windows.Forms.TextBox
    #$OldComputerNameTextBox_OldPage.ReadOnly = $true
    $OldComputerNameTextBox_OldPage.Location = New-Object System.Drawing.Size(100, 34)
    $OldComputerNameTextBox_OldPage.Size = New-Object System.Drawing.Size(120, 20)
    $OldComputerNameTextBox_OldPage.Text = ''
    $OldComputerInfoGroupBox.Controls.Add($OldComputerNameTextBox_OldPage)

    # Old Computer IP text box
    $OldComputerIPTextBox_OldPage = New-Object System.Windows.Forms.TextBox
    #$OldComputerIPTextBox_OldPage.ReadOnly = $true
    $OldComputerIPTextBox_OldPage.Location = New-Object System.Drawing.Size(230, 34)
    $OldComputerIPTextBox_OldPage.Size = New-Object System.Drawing.Size(90, 20)
    $OldComputerIPTextBox_OldPage.Text = ''
    $OldComputerInfoGroupBox.Controls.Add($OldComputerIPTextBox_OldPage)

    # New Computer name label
    $NewComputerNameLabel_OldPage = New-Object System.Windows.Forms.Label
    $NewComputerNameLabel_OldPage.Location = New-Object System.Drawing.Size(12, 57)
    $NewComputerNameLabel_OldPage.Size = New-Object System.Drawing.Size(80, 22)
    $NewComputerNameLabel_OldPage.Text = 'New Computer'
    $OldComputerInfoGroupBox.Controls.Add($NewComputerNameLabel_OldPage)

    # New Computer name text box
    $NewComputerNameTextBox_OldPage = New-Object System.Windows.Forms.TextBox
    $NewComputerNameTextBox_OldPage.Location = New-Object System.Drawing.Size(100, 56)
    $NewComputerNameTextBox_OldPage.Size = New-Object System.Drawing.Size(120, 20)
    $NewComputerNameTextBox_OldPage.Add_TextChanged({
            if ($ConnectionCheckBox_OldPage.Checked) {
                Update-Log 'Computer name changed, connection status unverified.' -Color 'Yellow'
                $ConnectionCheckBox_OldPage.Checked = $false
            }
        })
	$OldComputerInfoGroupBox.Controls.Add($NewComputerNameTextBox_OldPage)

    # Inclusions group box
    $InclusionsGroupBox = New-Object System.Windows.Forms.GroupBox
    $InclusionsGroupBox.Location = New-Object System.Drawing.Size(10, 110)
    $InclusionsGroupBox.Size = New-Object System.Drawing.Size(220, 140)
    $InclusionsGroupBox.Text = 'Data to Include'
    $OldComputerTabPage.Controls.Add($InclusionsGroupBox)

    # My Documents check box CSIDL_MYDOCUMENTS and CSIDL_PERSONAL
    $IncludeMyDocumentsCheckBox = New-Object System.Windows.Forms.CheckBox
    $IncludeMyDocumentsCheckBox.Checked = $DefaultIncludeMyDocuments
    $IncludeMyDocumentsCheckBox.Text = 'Documents'
    $IncludeMyDocumentsCheckBox.Location = New-Object System.Drawing.Size(10, 95)
	$IncludeMyDocumentsCheckBox.Size = New-Object System.Drawing.Size(100, 20)
    $InclusionsGroupBox.Controls.Add($IncludeMyDocumentsCheckBox)

	
	# Desktop check box CSIDL_DESKTOP and CSIDL_DESKTOPDIRECTORY
    $IncludeDesktopCheckBox = New-Object System.Windows.Forms.CheckBox
    $IncludeDesktopCheckBox.Checked = $DefaultIncludeDesktop
    $IncludeDesktopCheckBox.Text = 'Desktop'
    $IncludeDesktopCheckBox.Location = New-Object System.Drawing.Size(10, 15)
	$IncludeDesktopCheckBox.Size = New-Object System.Drawing.Size(100, 20)
	$InclusionsGroupBox.Controls.Add($IncludeDesktopCheckBox)

	
	# Downloads check box CSIDL_DOWNLOADS
    $IncludeDownloadsCheckBox = New-Object System.Windows.Forms.CheckBox
    $IncludeDownloadsCheckBox.Checked = $DefaultIncludeDownloads
    $IncludeDownloadsCheckBox.Text = 'Downloads'
    $IncludeDownloadsCheckBox.Location = New-Object System.Drawing.Size(110, 15)
	$IncludeDownloadsCheckBox.Size = New-Object System.Drawing.Size(100, 20)
    $InclusionsGroupBox.Controls.Add($IncludeDownloadsCheckBox)

	# Favorites check box CSIDL_FAVORITES
    $IncludeFavoritesCheckBox = New-Object System.Windows.Forms.CheckBox
    $IncludeFavoritesCheckBox.Checked = $DefaultIncludeFavorites
    $IncludeFavoritesCheckBox.Text = 'Favorites'
    $IncludeFavoritesCheckBox.Location = New-Object System.Drawing.Size(10, 35)
	$IncludeFavoritesCheckBox.Size = New-Object System.Drawing.Size(100, 20)
    $InclusionsGroupBox.Controls.Add($IncludeFavoritesCheckBox)

	
	# My Music check box CSIDL_MYMUSIC
    $IncludeMyMusicCheckBox = New-Object System.Windows.Forms.CheckBox
    $IncludeMyMusicCheckBox.Checked = $DefaultIncludeMyMusic
    $IncludeMyMusicCheckBox.Text = 'Music'
    $IncludeMyMusicCheckBox.Location = New-Object System.Drawing.Size(10, 55)
	$IncludeMyMusicCheckBox.Size = New-Object System.Drawing.Size(100, 20)
    $InclusionsGroupBox.Controls.Add($IncludeMyMusicCheckBox)

	
	# My Pictures check box CSIDL_MYPICTURES
    $IncludeMyPicturesCheckBox = New-Object System.Windows.Forms.CheckBox
    $IncludeMyPicturesCheckBox.Checked = $DefaultIncludeMyPictures
    $IncludeMyPicturesCheckBox.Text = 'Pictures'
    $IncludeMyPicturesCheckBox.Location = New-Object System.Drawing.Size(10, 75)
	$IncludeMyPicturesCheckBox.Size = New-Object System.Drawing.Size(100, 20)
    $InclusionsGroupBox.Controls.Add($IncludeMyPicturesCheckBox)

	
	# My Video check box CSIDL_MYVIDEO
    $IncludeMyVideoCheckBox = New-Object System.Windows.Forms.CheckBox
    $IncludeMyVideoCheckBox.Checked = $DefaultIncludeMyVideo
    $IncludeMyVideoCheckBox.Text = 'Videos'
    $IncludeMyVideoCheckBox.Location = New-Object System.Drawing.Size(110, 35)
	$IncludeMyVideoCheckBox.Size = New-Object System.Drawing.Size(100, 20)
    $InclusionsGroupBox.Controls.Add($IncludeMyVideoCheckBox)

	
	# Extra directories selection group box
    $ExtraDirectoriesGroupBox = New-Object System.Windows.Forms.GroupBox
    $ExtraDirectoriesGroupBox.Location = New-Object System.Drawing.Size(10, 260)
    $ExtraDirectoriesGroupBox.Size = New-Object System.Drawing.Size(220, 200)
    #$ExtraDirectoriesGroupBox.Text = 'Extra Directories to Include'
    $OldComputerTabPage.Controls.Add($ExtraDirectoriesGroupBox)
	# None, Tile, Center, Stretch, Zoom
	
	[reflection.assembly]::LoadWithPartialName("System.Windows.Forms")
	$base64ImageString = "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"
    $imageBytes = [Convert]::FromBase64String($base64ImageString)
    $ms = New-Object IO.MemoryStream($imageBytes, 0, $imageBytes.Length)
    $ms.Write($imageBytes, 0, $imageBytes.Length);
    $img = [System.Drawing.Image]::FromStream($ms, $true)
	
	[System.Windows.Forms.Application]::EnableVisualStyles();
	
	$pictureBox = new-object Windows.Forms.PictureBox
	$pictureBox.Location = New-Object System.Drawing.Size(0, 1)
	$pictureBox.Size = New-Object System.Drawing.Size($img.Width, $img.Height)
	$pictureBox.Image = $img
	$ExtraDirectoriesGroupBox.controls.add($pictureBox)
	
    #Old Machine C:\
    $remoteCdrive_OldPage = New-Object System.Windows.Forms.Button
    $remoteCdrive_OldPage.Location = New-Object System.Drawing.Size(290, 100)
    $remoteCdrive_OldPage.Size = New-Object System.Drawing.Size(120, 40)
    $remoteCdrive_OldPage.Font = New-Object System.Drawing.Font('Calibri', 12, [System.Drawing.FontStyle]::Bold)
    $remoteCdrive_OldPage.Text = 'Old PC C:'
    $remoteCdrive_OldPage.Add_Click({ remoteCdrive })
    $OldComputerTabPage.Controls.Add($remoteCdrive_OldPage)

    #New Machine C:\
    $remotenewCdrive_OldPage = New-Object System.Windows.Forms.Button
    $remotenewCdrive_OldPage.Location = New-Object System.Drawing.Size(290, 150)
    $remotenewCdrive_OldPage.Size = New-Object System.Drawing.Size(120, 40)
    $remotenewCdrive_OldPage.Font = New-Object System.Drawing.Font('Calibri', 12, [System.Drawing.FontStyle]::Bold)
    $remotenewCdrive_OldPage.Text = 'New PC C:'
    $remotenewCdrive_OldPage.Add_Click({ remotenewCdrive })
    $OldComputerTabPage.Controls.Add($remotenewCdrive_OldPage)

    # Migrate button
    $MigrateButton_OldPage = New-Object System.Windows.Forms.Button
    $MigrateButton_OldPage.Location = New-Object System.Drawing.Size(300, 300)
    $MigrateButton_OldPage.Size = New-Object System.Drawing.Size(150, 40)
    $MigrateButton_OldPage.Font = New-Object System.Drawing.Font('Calibri', 14, [System.Drawing.FontStyle]::Bold)
    $MigrateButton_OldPage.Text = 'Migrate'
    $MigrateButton_OldPage.Add_Click({ Save-UserState })
    $OldComputerTabPage.Controls.Add($MigrateButton_OldPage)

    # Create email settings tab
    $InstallAppsTabPage = New-Object System.Windows.Forms.TabPage
    $InstallAppsTabPage.DataBindings.DefaultDataSourceUpdateMode = 0
    $InstallAppsTabPage.UseVisualStyleBackColor = $true
    $InstallAppsTabPage.Text = 'Install Apps'
    $TabControl.Controls.Add($InstallAppsTabPage)

    # Install Plant Apps
    $installPlanetButton = New-Object System.Windows.Forms.Button
    $installPlanetButton.Location = New-Object System.Drawing.Size(10, 10)
    $installPlanetButton.Size = New-Object System.Drawing.Size(150, 60)
    $installPlanetButton.Font = New-Object System.Drawing.Font('Calibri', 10, [System.Drawing.FontStyle]::Bold)
    $installPlanetButton.Text = 'Install Plant Applications'
    $installPlanetButton.Add_Click({ installPlanet })
    $InstallAppsTabPage.Controls.Add($installPlanetButton)  
    
    # Install PI
    $installPiButton = New-Object System.Windows.Forms.Button
    $installPiButton.Location = New-Object System.Drawing.Size(10, 80)
    $installPiButton.Size = New-Object System.Drawing.Size(150, 30)
    $installPiButton.Font = New-Object System.Drawing.Font('Calibri', 10, [System.Drawing.FontStyle]::Bold)
    $installPiButton.Text = 'Install Pi'
    $installPiButton.Add_Click({ installPi })
    $InstallAppsTabPage.Controls.Add($installPiButton)     

    # Install Lenovo System Update
    $installLenovoButton = New-Object System.Windows.Forms.Button
    $installLenovoButton.Location = New-Object System.Drawing.Size(10, 120)
    $installLenovoButton.Size = New-Object System.Drawing.Size(150, 50)
    $installLenovoButton.Font = New-Object System.Drawing.Font('Calibri', 10, [System.Drawing.FontStyle]::Bold)
    $installLenovoButton.Text = 'Install Lenovo System Update'
    $installLenovoButton.Add_Click({ installLenovo })
    $InstallAppsTabPage.Controls.Add($installLenovoButton)

    # Install Lenovo Dock Drivers
    $installLenovoDriversButton = New-Object System.Windows.Forms.Button
    $installLenovoDriversButton.Location = New-Object System.Drawing.Size(10, 180)
    $installLenovoDriversButton.Size = New-Object System.Drawing.Size(150, 50)
    $installLenovoDriversButton.Font = New-Object System.Drawing.Font('Calibri', 10, [System.Drawing.FontStyle]::Bold)
    $installLenovoDriversButton.Text = 'Install Lenovo Dock Drivers'
    $installLenovoDriversButton.Add_Click({ installLenovoDrivers })
    $InstallAppsTabPage.Controls.Add($installLenovoDriversButton)

    # Create new computer tab
    $NewComputerTabPage = New-Object System.Windows.Forms.TabPage
    $NewComputerTabPage.DataBindings.DefaultDataSourceUpdateMode = 0
    $NewComputerTabPage.UseVisualStyleBackColor = $true
    $NewComputerTabPage.Text = 'New Computer'
    #$TabControl.Controls.Add($NewComputerTabPage)

    # Computer info group
    $NewComputerInfoGroupBox = New-Object System.Windows.Forms.GroupBox
    $NewComputerInfoGroupBox.Location = New-Object System.Drawing.Size(10, 10)
    $NewComputerInfoGroupBox.Size = New-Object System.Drawing.Size(450, 87)
    $NewComputerInfoGroupBox.Text = 'Computer Info'
    $NewComputerTabPage.Controls.Add($NewComputerInfoGroupBox)

    # Alternative save location group box
    $SaveSourceGroupBox = New-Object System.Windows.Forms.GroupBox
    $SaveSourceGroupBox.Location = New-Object System.Drawing.Size(240, 110)
    $SaveSourceGroupBox.Size = New-Object System.Drawing.Size(220, 87)
    $SaveSourceGroupBox.Text = 'Save State Source'
    $NewComputerTabPage.Controls.Add($SaveSourceGroupBox)

    # Save path
    $SaveSourceTextBox = New-Object System.Windows.Forms.TextBox
    $SaveSourceTextBox.Text = $MigrationStorePath
    $SaveSourceTextBox.Location = New-Object System.Drawing.Size(5, 20)
    $SaveSourceTextBox.Size = New-Object System.Drawing.Size(210, 20)
    $SaveSourceGroupBox.Controls.Add($SaveSourceTextBox)

    # Change save destination button
    $ChangeSaveSourceButton = New-Object System.Windows.Forms.Button
    $ChangeSaveSourceButton.Location = New-Object System.Drawing.Size(5, 50)
    $ChangeSaveSourceButton.Size = New-Object System.Drawing.Size(60, 20)
    $ChangeSaveSourceButton.Text = 'Change'
    $ChangeSaveSourceButton.Add_Click({
            Set-SaveDirectory -Type Source
            $OldComputerNameTextBox_NewPage.Text = Get-SaveState
            Show-DomainInfo
        })
    $SaveSourceGroupBox.Controls.Add($ChangeSaveSourceButton)

    # Reset save destination button
    $ResetSaveSourceButton = New-Object System.Windows.Forms.Button
    $ResetSaveSourceButton.Location = New-Object System.Drawing.Size(75, 50)
    $ResetSaveSourceButton.Size = New-Object System.Drawing.Size(65, 20)
    $ResetSaveSourceButton.Text = 'Reset'
    $ResetSaveSourceButton.Add_Click({
            Update-Log "Resetting save state directory to [$MigrationStorePath]."
            $SaveSourceTextBox.Text = $MigrationStorePath
            $OldComputerNameTextBox_NewPage.Text = Get-SaveState
            Show-DomainInfo
        })
    $SaveSourceGroupBox.Controls.Add($ResetSaveSourceButton)

    # Search for save state in given SaveSourceTextBox path
    $ResetSaveSourceButton = New-Object System.Windows.Forms.Button
    $ResetSaveSourceButton.Location = New-Object System.Drawing.Size(150, 50)
    $ResetSaveSourceButton.Size = New-Object System.Drawing.Size(65, 20)
    $ResetSaveSourceButton.Text = 'Search'
    $ResetSaveSourceButton.Add_Click({
            $OldComputerNameTextBox_NewPage.Text = Get-SaveState
            Show-DomainInfo
        })
    $SaveSourceGroupBox.Controls.Add($ResetSaveSourceButton)

    # Name label
    $ComputerNameLabel_NewPage = New-Object System.Windows.Forms.Label
    $ComputerNameLabel_NewPage.Location = New-Object System.Drawing.Size(100, 12)
    $ComputerNameLabel_NewPage.Size = New-Object System.Drawing.Size(100, 22)
    $ComputerNameLabel_NewPage.Text = 'Computer Name'
    $NewComputerInfoGroupBox.Controls.Add($ComputerNameLabel_NewPage)

    # IP label
    $ComputerIPLabel_NewPage = New-Object System.Windows.Forms.Label
    $ComputerIPLabel_NewPage.Location = New-Object System.Drawing.Size(230, 12)
    $ComputerIPLabel_NewPage.Size = New-Object System.Drawing.Size(80, 22)
    $ComputerIPLabel_NewPage.Text = 'IP Address'
    $NewComputerInfoGroupBox.Controls.Add($ComputerIPLabel_NewPage)

    # Old Computer name label
    $OldComputerNameLabel_NewPage = New-Object System.Windows.Forms.Label
    $OldComputerNameLabel_NewPage.Location = New-Object System.Drawing.Size(12, 35)
    $OldComputerNameLabel_NewPage.Size = New-Object System.Drawing.Size(80, 22)
    $OldComputerNameLabel_NewPage.Text = 'Old Computer'
    $NewComputerInfoGroupBox.Controls.Add($OldComputerNameLabel_NewPage)

    # Old Computer name text box
    $OldComputerNameTextBox_NewPage = New-Object System.Windows.Forms.TextBox
    $OldComputerNameTextBox_NewPage.ReadOnly = $true
    $OldComputerNameTextBox_NewPage.Location = New-Object System.Drawing.Size(100, 34)
    $OldComputerNameTextBox_NewPage.Size = New-Object System.Drawing.Size(120, 20)
    #$OldComputerNameTextBox_NewPage.Text = Get-SaveState
    $NewComputerInfoGroupBox.Controls.Add($OldComputerNameTextBox_NewPage)

    # Old Computer IP text box
    $OldComputerIPTextBox_NewPage = New-Object System.Windows.Forms.TextBox
    $OldComputerIPTextBox_NewPage.Location = New-Object System.Drawing.Size(230, 34)
    $OldComputerIPTextBox_NewPage.Size = New-Object System.Drawing.Size(90, 20)
    $OldComputerIPTextBox_NewPage.Add_TextChanged({
            if ($ConnectionCheckBox_NewPage.Checked) {
                Update-Log 'Computer IP address changed, connection status unverified.' -Color 'Yellow'
                $ConnectionCheckBox_NewPage.Checked = $false
            }
        })
    $NewComputerInfoGroupBox.Controls.Add($OldComputerIPTextBox_NewPage)

    # New Computer name label
    $NewComputerNameLabel_NewPage = New-Object System.Windows.Forms.Label
    $NewComputerNameLabel_NewPage.Location = New-Object System.Drawing.Size(12, 57)
    $NewComputerNameLabel_NewPage.Size = New-Object System.Drawing.Size(80, 22)
    $NewComputerNameLabel_NewPage.Text = 'New Computer'
    $NewComputerInfoGroupBox.Controls.Add($NewComputerNameLabel_NewPage)

    # New Computer name text box
    $NewComputerNameTextBox_NewPage = New-Object System.Windows.Forms.TextBox
    $NewComputerNameTextBox_NewPage.ReadOnly = $true
    $NewComputerNameTextBox_NewPage.Location = New-Object System.Drawing.Size(100, 56)
    $NewComputerNameTextBox_NewPage.Size = New-Object System.Drawing.Size(120, 20)
    $NewComputerNameTextBox_NewPage.Text = $env:COMPUTERNAME
    $NewComputerInfoGroupBox.Controls.Add($NewComputerNameTextBox_NewPage)

    # New Computer IP text box
    $NewComputerIPTextBox_NewPage = New-Object System.Windows.Forms.TextBox
    $NewComputerIPTextBox_NewPage.ReadOnly = $true
    $NewComputerIPTextBox_NewPage.Location = New-Object System.Drawing.Size(230, 56)
    $NewComputerIPTextBox_NewPage.Size = New-Object System.Drawing.Size(90, 20)
    #$NewComputerIPTextBox_NewPage.Text = Get-IPAddress
    $NewComputerInfoGroupBox.Controls.Add($NewComputerIPTextBox_NewPage)

    # Button to test connection to new computer
    $TestConnectionButton_NewPage = New-Object System.Windows.Forms.Button
    $TestConnectionButton_NewPage.Location = New-Object System.Drawing.Size(335, 33)
    $TestConnectionButton_NewPage.Size = New-Object System.Drawing.Size(100, 22)
    $TestConnectionButton_NewPage.Text = 'Test Connection'
    $TestConnectionButton_NewPage.Add_Click({
            $TestComputerConnectionParams = @{
                ComputerNameTextBox = $OldComputerNameTextBox_NewPage
                ComputerIPTextBox   = $OldComputerIPTextBox_NewPage
                ConnectionCheckBox  = $ConnectionCheckBox_NewPage
            }
            Test-ComputerConnection @TestComputerConnectionParams
        })
    $NewComputerInfoGroupBox.Controls.Add($TestConnectionButton_NewPage)

    # Connected check box
    $ConnectionCheckBox_NewPage = New-Object System.Windows.Forms.CheckBox
    $ConnectionCheckBox_NewPage.Enabled = $false
    $ConnectionCheckBox_NewPage.Text = 'Connected'
    $ConnectionCheckBox_NewPage.Location = New-Object System.Drawing.Size(336, 58)
    $ConnectionCheckBox_NewPage.Size = New-Object System.Drawing.Size(100, 20)
    $NewComputerInfoGroupBox.Controls.Add($ConnectionCheckBox_NewPage)

    # Cross-domain migration group box
    $CrossDomainMigrationGroupBox = New-Object System.Windows.Forms.GroupBox
    $CrossDomainMigrationGroupBox.Location = New-Object System.Drawing.Size(10, 110)
    $CrossDomainMigrationGroupBox.Size = New-Object System.Drawing.Size(220, 87)
    $CrossDomainMigrationGroupBox.Text = 'Cross-Domain Migration'
    $NewComputerTabPage.Controls.Add($CrossDomainMigrationGroupBox)

    # Domain label
    $DomainLabel = New-Object System.Windows.Forms.Label
    $DomainLabel.Location = New-Object System.Drawing.Size(70, 12)
    $DomainLabel.Size = New-Object System.Drawing.Size(50, 22)
    $DomainLabel.Text = 'Domain'
    $CrossDomainMigrationGroupBox.Controls.Add($DomainLabel)

    # User name label
    $UserNameLabel = New-Object System.Windows.Forms.Label
    $UserNameLabel.Location = New-Object System.Drawing.Size(125, 12)
    $UserNameLabel.Size = New-Object System.Drawing.Size(80, 22)
    $UserNameLabel.Text = 'User Name'
    $CrossDomainMigrationGroupBox.Controls.Add($UserNameLabel)

    # Old user label
    $OldUserLabel = New-Object System.Windows.Forms.Label
    $OldUserLabel.Location = New-Object System.Drawing.Size(12, 35)
    $OldUserLabel.Size = New-Object System.Drawing.Size(50, 22)
    $OldUserLabel.Text = 'Old User'
    $CrossDomainMigrationGroupBox.Controls.Add($OldUserLabel)

    # Old domain text box
    $OldDomainTextBox = New-Object System.Windows.Forms.TextBox
    $OldDomainTextBox.ReadOnly = $true
    $OldDomainTextBox.Location = New-Object System.Drawing.Size(70, 34)
    $OldDomainTextBox.Size = New-Object System.Drawing.Size(40, 20)
    $OldDomainTextBox.Text = $OldComputerNameTextBox_NewPage.Text
    $CrossDomainMigrationGroupBox.Controls.Add($OldDomainTextBox)

    # Old user slash label
    $OldUserSlashLabel = New-Object System.Windows.Forms.Label
    $OldUserSlashLabel.Location = New-Object System.Drawing.Size(110, 33)
    $OldUserSlashLabel.Size = New-Object System.Drawing.Size(10, 20)
    $OldUserSlashLabel.Text = '\'
    $OldUserSlashLabel.Font = New-Object System.Drawing.Font('Calibri', 12)
    $CrossDomainMigrationGroupBox.Controls.Add($OldUserSlashLabel)

    # Old user name text box
    $OldUserNameTextBox = New-Object System.Windows.Forms.TextBox
    $OldUserNameTextBox.ReadOnly = $true
    $OldUserNameTextBox.Location = New-Object System.Drawing.Size(125, 34)
    $OldUserNameTextBox.Size = New-Object System.Drawing.Size(80, 20)
    $CrossDomainMigrationGroupBox.Controls.Add($OldUserNameTextBox)

    # New user label
    $NewUserLabel = New-Object System.Windows.Forms.Label
    $NewUserLabel.Location = New-Object System.Drawing.Size(12, 57)
    $NewUserLabel.Size = New-Object System.Drawing.Size(55, 22)
    $NewUserLabel.Text = 'New User'
    $CrossDomainMigrationGroupBox.Controls.Add($NewUserLabel)

    # New domain text box
    $NewDomainTextBox = New-Object System.Windows.Forms.TextBox
    $NewDomainTextBox.ReadOnly = $true
    $NewDomainTextBox.Location = New-Object System.Drawing.Size(70, 56)
    $NewDomainTextBox.Size = New-Object System.Drawing.Size(40, 20)
    $NewDomainTextBox.Text = $DefaultDomain
    $CrossDomainMigrationGroupBox.Controls.Add($NewDomainTextBox)

    # New user slash label
    $NewUserSlashLabel = New-Object System.Windows.Forms.Label
    $NewUserSlashLabel.Location = New-Object System.Drawing.Size(110, 56)
    $NewUserSlashLabel.Size = New-Object System.Drawing.Size(10, 20)
    $NewUserSlashLabel.Text = '\'
    $NewUserSlashLabel.Font = New-Object System.Drawing.Font('Calibri', 12)
    $CrossDomainMigrationGroupBox.Controls.Add($NewUserSlashLabel)

    # New user name text box
    $NewUserNameTextBox = New-Object System.Windows.Forms.TextBox
    $NewUserNameTextBox.Location = New-Object System.Drawing.Size(125, 56)
    $NewUserNameTextBox.Size = New-Object System.Drawing.Size(80, 20)
    $NewUserNameTextBox.Text = $env:USERNAME
    $CrossDomainMigrationGroupBox.Controls.Add($NewUserNameTextBox)

    # Show our form
    $Form.Add_Shown( {$Form.Activate()})
    $Form.ShowDialog() | Out-Null
}
