# Mass Effect Legendary Edition Autosave History

This Powershell script is a basic Powershell script with a WinForms GUI to automatically identify new Autosaves and copy them to regular saves so you can roll back if you made a mistake but don't want to replay large stretches of the game.

> Please note, like any random script you may download from the internet, I **highly** recommend you read it and have a basic understanding of how it works. Part of the issue with Powershell scripts like this is you need to flip a setting in Powershell to even allow it to run. I've tried to provide comments throughout the script to explain it's functionality, and I certainly believe my code should be perfectly safe to run, but you need to come to that conclusion yourself as well.

# **Currently not working with ME1**

I've done what testing I can, and ME1 is essentially non-functional. The save copying mechanism does work, but ME1 thinks the saves we're creating and the auto save are corrupted. It looks like ME1's saves aren't just named differently but also possibly encoded in a way that the game thinks that they're wrong due to what is essentially renaming an autosave to a regular save.

While the code for ME1 copying exists in the script, I've changed the WinForm so it only offers ME2 & ME3 options.

## Screenshot Examples

These examples are from my ME3 testing of the script, but works similarly if not identically in ME2.

**The Script Running**
![MELE AutoSave History](https://github.com/jp-powers/MELE-AutoSave-History/blob/master/Example1.png)

The script utilizes an infinite loop to constantly monitor the autosave file, so the WinForm console window shows certain items, but the write action (the actual copying) will write a history to the parent Powershell window.

![Example of copied saves](https://github.com/jp-powers/MELE-AutoSave-History/blob/master/Example2.png)

This was a brand new ME3 save, and the Save_0001.pcsav and beyond files were created by the script, the game autosaved 4 times just in the opening before you can even hit Escape to bring up the menu.

![Example of in game saves showing](https://github.com/jp-powers/MELE-AutoSave-History/blob/master/Example3.png)

This is an example from in-game, showing the saves as available to select and play. Since the script was monitoring during launch I think the numbering got a little goofy because the autosave was happening before you can actually create saves normally in game.

## TL;DR how it works

The user selects a Mass Effect Legendary Edition save/"career" and sets a number of Autosaves they want to keep (default is 50, should be plenty without being too ridiculous).

The script works by searching the current career's folder for the auto saves, identifying when they are created or changed, and copying it to a new location with similar file naming to the default regular saves. This allows the user to select the saves from the load menu. Due to how the games work, we can't have them be "different" to create a true history of autosaves, thus the relatively high keep count value.

The script will also scan for saves "older" than our set keep count.

## Basic setup/use

First, you'll want to get a save created for your games. If you already have a save you'll be continuing you can skip this. If not, run the game like normal, and get to a place where you can create a save and do so. If you go to "C:\Users\<username>\Documents\BioWare\Mass Effect Legendary Edition\Save" you should see a folder for the game (ME1, ME2, and/or or ME3), and inside that a folder for the "career." If that's there (for the specific new career you're playing) then you're good to go.

Once you have a career folder created you probably want to run the script before launching the game so it's actively monitoring the auto save at all times. It should be generally safe to Alt+Tab out of the game and start it, though. This is how the ME3 testing in the screenshots was done, it looks like an auto save happens on career creation.

Second, due to how Windows works, you need to enable an Unrestricted execution policy so the script can run. While using the script, enable it. If you'd like to ensure you're OS is as secure as Microsoft intended, run the disable command to return it to default.

Open Powershell (Win+R then enter "powershell" or search Powershell in the start menu), and copy/paste the below commands as needed. When running it will ask you to confirm the changes, enter **Y** to do so.

**Enable Powershell execution**

`Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser`

**Disable Powershell execution**

`Set-ExecutionPolicy -ExecutionPolicy Undefined -Scope CurrentUser`

Once completed, right click the AutoSave-History.ps1 file and select **Run with Powershell**.

A Powershell window will open as well as the WinForms window. This script is pretty simple, so keep that Powershell window open.

There are 5 total interactions.

1. In the first dropdown, select the game you're currently playing. ME2 or ME3.
1. Click **Read Saves** to populate the second dropdown.
1. In the second dropdown, select the save/"career" you are actively playing. These are based on the folder names that the game creates, so the naming convention is dictated by that.
1. Set how many auto saves you want to keep a history of. The default is 50. Due to how the game(s) work, in order for the saves to be loadable, we need to use the same naming convention. For the autoremoval to work, I suggest a high value here, so you have a good history of saves without being ridiculous. Refer below to the "Notes about the Save Count to Keep feature" section if you'd like to permanent change the default or disable the auto delete all together.
1. Click **Start Running** and the script will enter an infinite loop to monitor the auto save file and start copying it only if it changes.

Once you are done playing and close the game, Ctrl+C in the Powershell window to cancel the task. Again, due to how simple the script is, the infinite loop it creates means the WinForm window goes into a "Not Responding" state and can't be interacted with or closed, but Ctrl+C in the Powershell window will stop the infinite loop. The script should also catch this action and dispose of the filewatchers so they're not still open when complete.

As we will be semi-regularly deleting our auto save history *and* regular saves, you may also want to use a tool like [GameSave Manager](https://www.gamesave-manager.com/) to regularly back up your saves during a play through.

## Notes about the Save Count to Keep feature

This setting defaults to 50, but both ME2 & ME3 auto save quite frequently. In my opinion 50 allows for plenty of fall back room without being too excessive. In most play throughs this could cover a couple hours of play time, and I think most people's hope for a tool like this is simply not having to redo a couple hours of play. However, if you'd like to increase the default counter permanently, look for the following line in the code (line 76 at time of writing) and change the 50 to your preferred value:

`$KeepCountEntry.text             = "50"`

If, however, you'd like to disable this feature entirely, you can simply comment out the following lines (lines 179 thru 182 at time of writing) by putting a # at the beginning of each line:

```
			$saves_created_list = Get-ChildItem -Path $ReadPath -Recurse -Include $FileIncluder # create a list of all regular saves
			if ($saves_created_list.Count -gt $KeepCount) { # check if there are more saves than the keep count
				$saves_created_list | Sort-Object | Select-Object -First ($saves_created_list.Count - $KeepCount) | Remove-Item # sort the list by name (numbering should be consistent due to above), select the first objects up to the keep count, remove them.
			}
```

## Final Notes

This script works well enough for my needs, and is pretty simple. I have no intention of adding features beyond maybe trying to figure out how to make it work with ME1 as well. Beyond "whoa that's a glaring bug I didn't catch" bugfixes I don't forsee any future changes. If you like this but would like to build it out more, I highly encourage forking it. The script doesn't do anything wildly advanced in Powershell, but could work as a decent footing for building out something more useful for you.
