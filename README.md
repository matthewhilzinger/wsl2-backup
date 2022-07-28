# wsl2-backup

**Performs a backup of all WSL2 distros to named & dated .tar files in a specified directory.**

1. Pull all files from this repo to a local directory.

2. Edit the contents of `WSL2Backup-Configuration.json` as per your requirements *(see below for details)*.

3. Start Task Scheduler, navigate to *Task Scheduler Library*, and select **Import Task...**

4. Navigate to the path you downloaded the files to, and select `Backup WSL2.xml`. Click **Open**.

5. Select **Triggers**, double-click on the *Weekly* trigger, and change it to meet your requirements.

6. Select **Actions**, double-click on the **Start a program** action, and edit the *Start in* path to point to the local directory that holds the .PS1 script file.

7. Click **OK** to save and activate the schedule.

##
### Contents of *WSL2Backup-Configuration.json*

- **BackupPath:** Path to store the backups in. *(Default: `C:\Store\WSL-Backup`)*

- **AgeOfBackupsToDelete:** How many days' worth of backups to keep. *(Default: 30 days)*

- **MinNumOfBackupsToKeep:** Will always keep this many backups, regardless of age. *(Default: 1 backup)*

- **LogPath:** Path to store Transcript logs into. *(Default: `C:\Store\WSL-Backup\Logs`)*

- **AgeOfOldLogFilesToDelete:** How many days' worth of Transcript logs to keep. *(Default: 90 days)*
