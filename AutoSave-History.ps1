###MELE auto save history
#
# This script is intended to monitor MELE save folders for changes to the autosave file,
# then copy it to a new save that should be selectable in game.

# basic concept taken from https://dotnet-helpers.com/powershell/how-to-monitor-a-folder-changes-using-powershell/
# mostly just adjusting variables/providing context and changing the writeaction

# other sources:
# formatting for 4 digits: https://stackoverflow.com/questions/51912486/format-variable-as-4-digits-with-leading-zeroes

# WinForm (mostly) generated via POSHGUI.com

# baseline variables
$refreshrate = 2 # how often to loop thru script in seconds. Basically, how frequently to check for changes.
$script:SavesStartPoint = "$env:USERPROFILE\Documents\BioWare\Mass Effect Legendary Edition\Save"
$script:SaveNameNum = "\d+(?=\.\w+)" # regex that will be used to find the highest save file number. Identifies digits before the file extension.

#region GUI
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

$Form                            = New-Object system.Windows.Forms.Form
$Form.ClientSize                 = New-Object System.Drawing.Point(400,400)
$Form.text                       = "MELE AutoSave History"
$Form.TopMost                    = $false

$GameSelectorLabel               = New-Object system.Windows.Forms.Label
$GameSelectorLabel.text          = "Game Selector:"
$GameSelectorLabel.AutoSize      = $true
$GameSelectorLabel.width         = 25
$GameSelectorLabel.height        = 10
$GameSelectorLabel.location      = New-Object System.Drawing.Point(10,12)
$GameSelectorLabel.Font          = New-Object System.Drawing.Font('Microsoft Sans Serif',10)

$GameSelectorList                = New-Object system.Windows.Forms.ComboBox
$GameSelectorList.text           = ""
#@("ME1","ME2","ME3") | ForEach-Object {[void] $GameSelectorList.Items.Add($_)}
@("ME2","ME3") | ForEach-Object {[void] $GameSelectorList.Items.Add($_)} # until I do more research into why ME1 saves don't work, only supporting ME2 & 3 for now. The other code is left behind as a fall back if I can figure out how to get ME1 to recognize the copies.
$GameSelectorList.width          = 60
$GameSelectorList.height         = 30
$GameSelectorList.location       = New-Object System.Drawing.Point(110,12)


$GameSelectorReader              = New-Object system.Windows.Forms.Button
$GameSelectorReader.text         = "Read Saves"
$GameSelectorReader.width        = 90
$GameSelectorReader.height       = 30
$GameSelectorReader.location     = New-Object System.Drawing.Point(180,10)
$GameSelectorReader.Font         = New-Object System.Drawing.Font('Microsoft Sans Serif',10)

$SaveLocationLabel               = New-Object system.Windows.Forms.Label
$SaveLocationLabel.text          = "Saves Available:"
$SaveLocationLabel.AutoSize      = $true
$SaveLocationLabel.width         = 25
$SaveLocationLabel.height        = 10
$SaveLocationLabel.location      = New-Object System.Drawing.Point(10,45)
$SaveLocationLabel.Font          = New-Object System.Drawing.Font('Microsoft Sans Serif',10)

$SaveLocationList                = New-Object system.Windows.Forms.ComboBox
$SaveLocationList.text           = ""
$SaveLocationList.width          = 250
$SaveLocationList.height         = 30
$SaveLocationList.location       = New-Object System.Drawing.Point(120,45)

$KeepCountLabel                  = New-Object system.Windows.Forms.Label
$KeepCountLabel.text             = "Save Count to Keep:"
$KeepCountLabel.AutoSize         = $true
$KeepCountLabel.width            = 25
$KeepCountLabel.height           = 10
$KeepCountLabel.location         = New-Object System.Drawing.Point(10,75)
$KeepCountLabel.Font             = New-Object System.Drawing.Font('Microsoft Sans Serif',10)

$KeepCountEntry                  = New-Object system.Windows.Forms.TextBox
$KeepCountEntry.multiline        = $false
$KeepCountEntry.text             = "50"
$KeepCountEntry.width            = 30
$KeepCountEntry.height           = 20
$KeepCountEntry.location         = New-Object System.Drawing.Point(145,77)
$KeepCountEntry.Font             = New-Object System.Drawing.Font('Microsoft Sans Serif',10)

$StartRunButton                  = New-Object system.Windows.Forms.Button
$StartRunButton.text             = "Start Running"
$StartRunButton.width            = 380
$StartRunButton.height           = 30
$StartRunButton.location         = New-Object System.Drawing.Point(10,105)
$StartRunButton.Font             = New-Object System.Drawing.Font('Microsoft Sans Serif',10)

$ConsoleTextbox                  = New-Object system.Windows.Forms.TextBox
$ConsoleTextbox.multiline        = $true
$ConsoleTextbox.Scrollbars	     = "Vertical" 
$ConsoleTextbox.BackColor        = "#131212"
$ConsoleTextbox.width            = 380
$ConsoleTextbox.height           = 240
$ConsoleTextbox.location         = New-Object System.Drawing.Point(10,150)
$ConsoleTextbox.Font             = 'Microsoft Sans Serif,10'
$ConsoleTextbox.ForeColor        = "#08e008"

$Form.controls.AddRange(@($FormTitle,$GameSelectorLabel,$GameSelectorList,$GameSelectorReader,$SaveLocationLabel,$SaveLocationList,$KeepCountLabel,$KeepCountEntry,$StartRunButton,$StopRunButton,$ConsoleTextbox))
#endregion

# Write instructions of use to the console output area. Similar commands later are used for 'logging'
$ConsoleTextbox.AppendText("Instructions:`r`n")
$ConsoleTextbox.AppendText("1. Select Game`r`n")
$ConsoleTextbox.AppendText("2. Click Read Saves`r`n")
$ConsoleTextbox.AppendText("3. Select Career you're playing`r`n")
$ConsoleTextbox.AppendText("4. Click Start Running`r`n")
$ConsoleTextbox.AppendText("`r`n")
$ConsoleTextbox.AppendText("When done, Ctrl+C in the Powershell window to end the run.`r`n")
$ConsoleTextbox.AppendText("Closing in another way could leave the filewatchers open.`r`n")
$ConsoleTextbox.AppendText("`r`n")

# We create EventObjects to monitor the files. We want to clear any open ones on launch to make sure we don't have past watchers running.
Get-EventSubscriber | Unregister-Event

#region Actions
function ReadSavesAction {
	param ($Game)
	# this function runs when the "Read Saves" button is clicked.
	$saveList = Get-ChildItem -Path "$SavesStartPoint\$Game" -Name -Directory -Exclude "Char","PROFILE" # creates a list of careers in the select game's save folder. Exclude is for unnecessary ME1 items.
	$SaveLocationList.Items.Clear() # clears the dropdown list of previous items in the event you selected the wrong game at first.
	$saveList | ForEach-Object {[void] $SaveLocationList.Items.Add($_)} # itterates through the list to add each item to the dropdown.
	$ConsoleTextbox.AppendText("Saves Available Updated`r`n")
}

function StartRunningAction {
	param ($Game, $Career)
	#  ME1 has different naming convention, so we need to look at it differently
	# To reduce repeating otherwise identical code we'll set some variables for ME1 and ME2&3
	try {
		if ($Game -eq "ME1") {
			$FileFilter = "$Career`_AutoSave.pcsav" # what we'll use to identify the autosave
			$FileIncluder = "$Career`_??.pcsav" # what's used to identify previously created saves
			$Counter_Formatter = "{0:d2}" # used to format newly made autosave history files
			$SavePrefix = $Career # used to match regular saves prefix when doing the copy
		}
		else { # if the game is not ME1 (aka: ME2 or ME3), do this instead
			$FileFilter = "AutoSave.pcsav"
			$FileIncluder = "Save_????.pcsav"
			$Counter_Formatter = "{0:d4}"
			$SavePrefix = "Save"
		}
		
		$writeaction = {
			# accept a bunch of variables from the object event registration and recast them to cleaner variable names
			$SavesStartPoint = $Event.MessageData.SavesStartPoint
			$Game = $Event.MessageData.Game
			$Career = $Event.MessageData.Career
			$FileIncluder = $Event.MessageData.FileIncluder
			$SavePrefix = $Event.MessageData.SavePrefix
			$Counter_Formatter = $Event.MessageData.Counter_Formatter
			$SaveNameNum = $Event.MessageData.SaveNameNum
			$KeepCount = $Event.MessageData.KeepCount
			Write-Host "Copy action triggered"
			# create a counter for creating autosave history files
			# this next bit is to avoid confusing numbers.
			# Basically, we know the counter and iteration will be increasing while the script is running,
			# but we want to also ensure it's not "resetting" when we close and reopen the script & game.
			# This makes it so each new autosave copy will keep going up in count, even while saves older than our keep count are removed.
			$ReadPath = ($SavesStartPoint+"\"+$Game+"\"+$Career)
			$fileList = Get-ChildItem -Path $ReadPath -Recurse -Include $FileIncluder # reads file names of saves
			$counter = 0
			$LastSaveFile = $fileList | Select-Object -Last 1 # selects the last file in the list created above
			if ($LastSaveFile.count -ge 1) { # if there aren't more than 1 save, this value is null and script doesn't work, so check if we have some already
				$LastSaveFileName = Split-Path $LastSaveFile -leaf # we only want the save file name, not the full path
				$LastSaveFileNum = ([regex]$SaveNameNum).Match($LastSaveFileName).Value # find the number in the save file
				$counter = [int]$LastSaveFileNum # sets counter to above number, ensuring it's an integer
			}
			$counter++ # increases the counter
			$counter_f = $Counter_Formatter -f $counter # formats counter for to match regular saves
			
			# actually do the copy
			$CopyFromPath = $Event.SourceEventArgs.FullPath # captures the file watcher's trigger fullpath
			$CopyToPath = ($SavesStartPoint+"\"+$Game+"\"+$Career+"\"+$SavePrefix+"_"+$counter_f+".pcsav")
			Write-Host "Copying From: $CopyFromPath"
			Write-Host "Copying to: $CopyToPath"
			Copy-Item $CopyFromPath -Destination $CopyToPath
			# identify saves to remove outside of our keep count scope
			$saves_created_list = Get-ChildItem -Path $ReadPath -Recurse -Include $FileIncluder # create a list of all regular saves
			if ($saves_created_list.Count -gt $KeepCount) { # check if there are more saves than the keep count
				$saves_created_list | Sort-Object | Select-Object -First ($saves_created_list.Count - $KeepCount) | Remove-Item # sort the list by name (numbering should be consistent due to above), select the first objects up to the keep count, remove them.
			}
		}

		#create a file watcher, which monitors the autosave file for creation or changes
		$filewatcher = New-Object System.IO.FileSystemWatcher
		$filewatcher.Path = "$SavesStartPoint\$Game\$Career"
		$filewatcher.Filter = $FileFilter
		$filewatcher.IncludeSubdirectories = $true
		$filewatcher.EnableRaisingEvents = $true
		
		# write some of the data out to console log
		$ConsoleTextbox.AppendText("Career Location: `r`n")
		$ConsoleTextbox.AppendText($filewatcher.Path+"`r`n")
		$ConsoleTextbox.AppendText("`r`n")
		$ConsoleTextbox.AppendText("Autosave being monitored: `r`n")
		$ConsoleTextbox.AppendText($filewatcher.Filter+"`r`n")
		$ConsoleTextbox.AppendText("`r`n")

		#register the watch object to monitor changed or created for the Autosave.
		# We need to pass a few variables into the scriptblock $writeaction, so we'll make an array of them and pass it to the object event registration with Message Data.
		$ObjectEventData = @{
			SavesStartPoint = $SavesStartPoint;
			Game = $Game;
			Career = $Career;
			FileIncluder = $FileIncluder;
			SavePrefix = $SavePrefix;
			Counter_Formatter = $Counter_Formatter;
			SaveNameNum = $SaveNameNum;
			KeepCount = $KeepCountEntry.text
		}
		Register-ObjectEvent $filewatcher "Created" -Action $writeaction -MessageData $ObjectEventData
		Register-ObjectEvent $filewatcher "Changed" -Action $writeaction -MessageData $ObjectEventData
		$ConsoleTextbox.AppendText("Filewatcher registered`r`n")
		$ConsoleTextbox.AppendText("###########`r`n")
		$ConsoleTextbox.AppendText("# WARNING #`r`n")
		$ConsoleTextbox.AppendText("###########`r`n")
		$ConsoleTextbox.AppendText("This window will now appear frozen. This is normal.`r`n")
		$ConsoleTextbox.AppendText("Use Ctrl+C in the Powershell window to stop the action.`r`n")
		
		while ($true) { Start-Sleep $refreshrate} 
	}
	finally {
		$Filewatcher.Dispose()
		Get-EventSubscriber | Unregister-Event
		Write-Host "Filewatcher disposed"
		$ConsoleTextbox.AppendText("Filewatcher disposed`r`n")
	}
}
#endregion

#region ButtonClicks
$GameSelectorReader.Add_Click({ ReadSavesAction $GameSelectorList.text }) # ties ReadSavesAction function to the Read Saves button
$StartRunButton.Add_Click({ StartRunningAction $GameSelectorList.text $SaveLocationList.text }) # ties StartRunningAction function to the Start Running button
#endregion


[void]$Form.ShowDialog() # actually shows the WinForm