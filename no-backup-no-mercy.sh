#!/bin/bash
# Simple backup - written in bash - using rsync
# local-mode, tossh-mode, fromssh-mode

SOURCES=(/root /etc /home /boot)

MOUNTPOINT="/mnt/data"       # check local mountpoint
LOCALHOSTNAME=$(hostname)
TARGET="$MOUNTPOINT/backup/$LOCALHOSTNAME"

# edit or comment with "#"
LISTPACKAGES=listrpms             # local-mode and tossh-mode
MONTHROTATE=monthrotate           # use DD instead of YYMMDD

RSYNCCONF=(--delete --exclude "/home/*/.cache")
#MAILREC="user@domain"

#SSHUSER="sshuser"
#FROMSSH="fromssh-server"
#TOSSH="tossh-server"
#SSHPORT=22

MOUNT="/bin/mount"
FGREP="/bin/fgrep"
SSH="/usr/bin/ssh"
LN="/bin/ln"
ECHO="/bin/echo"
DATE="/bin/date"
DNF="/usr/bin/dnf"
MAIL="/usr/bin/mail"
RSYNC="/usr/bin/rsync"
LAST="last"
INC="--link-dest=$TARGET/$LAST"

LOG=$0.log
$DATE > "$LOG"

if [ "${TARGET:${#TARGET}-1:1}" != "/" ]; then
  TARGET=$TARGET/
fi

if [ "$LISTPACKAGES" ] && [ -z "$FROMSSH" ]; then
  $ECHO "$DNF list installed" >> "$LOG"
  $DNF list installed >> "$LOG" 2>&1
fi

if [ "$MOUNTPOINT" ]; then
  MOUNTED=$($MOUNT | $FGREP "$MOUNTPOINT");
fi

if [ -z "$MOUNTPOINT" ] || [ "$MOUNTED" ]; then
  if [ -z "$MONTHROTATE" ]; then
    TODAY=$($DATE +%y%m%d)
  else
    TODAY=$($DATE +%d)
  fi

  if [ "$SSHUSER" ] && [ "$SSHPORT" ]; then
    S="$SSH -p $SSHPORT -l $SSHUSER";
  fi

  for SOURCE in "${SOURCES[@]}"
    do
      if [ "$S" ] && [ "$FROMSSH" ] && [ -z "$TOSSH" ]; then
        $ECHO "$RSYNC -e \"$S\" -avR \"$FROMSSH:$SOURCE\" ${RSYNCCONF[*]} $TARGET$TODAY $INC" >> "$LOG"
        if $RSYNC -e "$S" -avR "$FROMSSH:\"$SOURCE\"" "${RSYNCCONF[@]}" "$TARGET""$TODAY" "$INC" >> "$LOG" 2>&1; then
          ERROR=1
        fi
      fi
      if [ "$S" ]  && [ "$TOSSH" ] && [ -z "$FROMSSH" ]; then
        $ECHO "$RSYNC -e \"$S\" -avR \"$SOURCE\" ${RSYNCCONF[*]} \"$TOSSH:$TARGET$TODAY\" $INC " >> "$LOG"
        if $RSYNC -e "$S" -avR "$SOURCE" "${RSYNCCONF[@]}" "$TOSSH:\"$TARGET\"$TODAY" "$INC" >> "$LOG" 2>&1; then
          ERROR=1
        fi
      fi
      if [ -z "$S" ]; then
        $ECHO "$RSYNC -avR \"$SOURCE\" ${RSYNCCONF[*]} $TARGET$TODAY $INC"  >> "$LOG"
        if $RSYNC -avR "$SOURCE" "${RSYNCCONF[@]}" "$TARGET""$TODAY" "$INC"  >> "$LOG" 2>&1; then
          ERROR=1
        fi
      fi
  done

  if [ "$S" ] && [ "$TOSSH" ] && [ -z "$FROMSSH" ]; then
    $ECHO "$SSH -p $SSHPORT -l $SSHUSER $TOSSH $LN -nsf $TARGET$TODAY $TARGET$LAST" >> "$LOG"
    if $SSH -p "$SSHPORT" -l "$SSHUSER" "$TOSSH" "$LN -nsf \"$TARGET\"$TODAY \"$TARGET\"$LAST" >> "$LOG" 2>&1; then
      ERROR=1
    fi
  fi
  if [ "$S" ] && [ "$FROMSSH" ] && [ -z "$TOSSH" ] || [ -z "$S" ];  then
    $ECHO "$LN -nsf $TARGET$TODAY $TARGET$LAST" >> "$LOG"
    if $LN -nsf "$TARGET""$TODAY" "$TARGET"$LAST  >> "$LOG" 2>&1; then
      ERROR=1
    fi
  fi
else
  $ECHO "$MOUNTPOINT not mounted" >> "$LOG"
  ERROR=1
fi
$DATE >> "$LOG"
if [ -n "$MAILREC" ]; then
  if [ $ERROR ];then
    $MAIL -s "Error Backup $LOG" "$MAILREC" < "$LOG"
  else
    $MAIL -s "Backup $LOG" "$MAILREC" < "$LOG"
  fi
fi
