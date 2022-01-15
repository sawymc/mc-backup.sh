#!/bin/bash
: '
MC-BACKUP script based on:
https://github.com/J-Bentley/mc-backup.sh'

serverDir="/home/user/minecraft-server"
serverName="mcserver"
startScript="bash start.sh"
gracePeriod="1m"
githubRepo="git@github.com:account/repository.git"
# Don't change anything past this line unless you know what you're doing.

currentDay=$(date +"%Y-%m-%d-%H:%M")
screens=$(ls /var/run/screen/S-$USER -1 | wc -l || 0)
serverRunning=true
restartOnly=false
githubSetup=false
githubDone=false
pluginconfigOnly=false

log () {
    # Echos text passed to function and appends to file at same time
    builtin echo -e "$@" | tee -a mc-backup_log.txt
}
stopHandling () {
    # injects commands into console via stuff to warn chat of backup, sleeps for graceperiod, restarts, sleeps for hdd spin times
    log "[$currentDay] Warning players & stopping $serverName...\n"
    screen -p 0 -X stuff "say &l&2$serverName is restarting in $gracePeriod!$(printf \\r)"
    sleep $gracePeriod
    screen -p 0 -X stuff "say &l&2$serverName is restarting now!$(printf \\r)"
    screen -p 0 -X stuff "save-all$(printf \\r)"
    sleep 5
    screen -p 0 -X stuff "stop$(printf \\r)"
    sleep 5
}

# USER INPUT
while [ $# -gt 0 ];
do
    case "$1" in
      -h|--help)
        echo -e "MC-BACKUP by Jordan B (adapted by Sawy7 for Github)\n---------------------------\nA backup script of\n[$serverDir] to Github for $serverName!\n"
        echo -e "Usage:\nNo args | Backup $serverName root dir.\n-h | Help (this).\n-r | Restart with warnings, no backups made.\n-s | Setup backup repository (on first run)."
        exit 0
        ;;
      -s|--setupgithub)
        githubSetup=true
        ;;
      -r|--restart)
        restartOnly=true
        ;;
      *)
      log -e "[$currentDay] Error: Invalid argument: ${1}\n" 
      ;;
    esac
    shift
done

# Logs error and cancels script if too many args given to script
if [ $# -gt 1 ]; then
    log -e "[$currentDay] Error: Too many arguments! Backup has been cancelled.\n"
    exit 1
fi
# Logs error and cancels script if serverDir isn't found
if [ ! -d $serverDir ]; then
    log "[$currentDay] Error: Server folder not found! Backup has been cancelled. ($serverDir)\n"
    exit 1
fi
# Logs error if JAVA process isn't detected but will continue anyways!!
if ! ps -e | grep -q "java"; then
    log "[$currentDay] Warning: $serverName is not running! Continuing without in-game warnings...\n"
    serverRunning=false
fi

if [ $screens -eq 0 ]; then
    log "[$currentDay] Error: No screen sessions running! Backup has been cancelled.\n"
    exit 1
elif [ $screens -gt 1 ]; then
    log "\n[$currentDay] Error: More than 1 screen session is running! Backup has been cancelled.\n"
    exit 1
fi

if test -f "$serverDir/.gitsetupdone"; then
    githubDone=true
fi

if ! $githubDone && ! $githubSetup; then
    log "\n[$currentDay] Error: Github was not setup! Backup has been cancelled.\n"
    exit 1
elif $githubSetup && $githubDone; then
    log "\n[$currentDay] Error: Github has already been setup. You can run without arguments now.\n"
    exit 1
fi

# Wont execute stopHandling if server is offline upon script start
if $serverRunning; then
    stopHandling
fi

# Grabs date in seconds BEFORE compression begins
elapsedTimeStart="$(date -u +%s)"

# LOGIC HANDLING
if $restartOnly; then
    log "[$currentDay] Restart only started ...\n"
elif $githubSetup; then
    log "[$currentDay] Setting up Github repo ...\n"
    cd $serverDir
    git init
    git add -A
    git commit -m "backup setup"
    git branch -M master
    git remote add origin $githubRepo
    git push -u origin master
    log "[$currentDay] Github repo setup is done.\n"
    touch .gitsetupdone
else
    log "[$currentDay] Github backup started ...\n"
    cd $serverDir
    git add -A
    git commit -m "$serverName - $currentDay"
    git push -u origin master
fi

# Grabs date in seconds AFTER compression completes then does math to find time it took to compress
elapsedTimeEnd="$(date -u +%s)"
elapsed="$(($elapsedTimeEnd-$elapsedTimeStart))"

# Will restart server if it was online upon script start OR if in restartOnly mode regardless of server state at script launch -- therefore WONT ever restart server if offline upon script launch unless restartOnly
if $serverRunning || $restartOnly; then
    screen -p 0 -X stuff "$startScript $(printf \\r)"
    log "[$currentDay] $startScript run! Restarting $serverName...\n"
fi

if $restartOnly; then
    log "[$currentDay] $serverName restarted in $((elapsed/60)) min(s)!\n"
else
    log "[$currentDay] github backup was completed in $((elapsed/60)) min(s)!\n"
fi
exit 0
