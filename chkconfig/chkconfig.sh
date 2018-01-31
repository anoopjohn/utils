#!/bin/bash

DEBUG=0

LOG_FILE="log.txt"
email_to_address="email1@example.com"
email_cc_address="email2@example.com"

 # Debug function
function db {
  if [ $DEBUG -eq 1 ];
  then
    echo "$1"
  fi
}

# Log function
function log {
  # If there are parameters read from parameters
  if [ $# -gt 0 ]; then
    echo "[$(date +"%D %T")] $@" >> $LOG_FILE
    db "$@"
  else
    # If there are no parameters read from stdin
    while read data
    do
      echo "[$(date +"%D %T")] $data" >> $LOG_FILE
      db "$data"
    done
  fi
}

# Change to the dir this script resides in
script_path=`readlink -f $0`
script_dir=`dirname "$script_path"`
cd "$script_dir"
 # Run copy operations if run as root
if [ $(id -u) -eq 0 ]; then
  db "Running copy operations"
  # Copy files to the conf folder
  while read path
  do
    # Ignore comments and empty lines
    echo "$path" | egrep '(^\s*#)|(^\s*$)' >/dev/null 2>&1 && continue
    db "$path read from the file"
    source="$path"
    destination="./conf/`hostname`$path"
    if [ -f "$source" ]; then
      # If file then copy
      param='-f'
    elif [ -d $source ]; then
      # If folder then deep copy
      param='-fR'
      destination="`dirname \"$destination\"`"
      # Create the destination folder if it does not exist
      if [ ! -d "$destination" ]; then
        log "$destination does not exist. Creating dir"
        mkdir -p "$destination"
      fi
    else
      log "$path: Illegal path found."
      # Continue on to the next path
      continue
    fi
    db "Copying $source to $destination"
    (nice cp $param "$source" "$destination" 2>&1) | log
  done  /dev/null
  if [ $? -eq 0 ]; then
    has_untracked=1
    git_status=`git status`
  fi
  # If there is a difference
  if [[ $diff_lines -gt 0 || $has_untracked -eq 1 ]]; then
    log "$diff_lines line(s) of difference found"
    log "Has untracked = $has_untracked"
    # Get latest changes from other servers
    log "Pulling changes (if any) from server"
    (git pull 2>&1) | log
    # Commit the difference on the machine
    (git add -A 2>&1) | log
    (git commit -m "Adding changes from $(hostname)" 2>&1) | log
    (git push 2>&1) | log
    db $file_diff
    subject="[CONFIG-TRACK] `hostname` - Status Report - $(date)"
    git_differences="`echo -e "$file_diff\n$git_status"`"
    log "Sending differences via email"
    log "$git_differences"
    echo -e "$git_differences" | mail -s "$subject" -c $email_cc_address $email_to_address 2>&1 | log
  else
    db "No differences found"
  fi
fi
