#!/bin/bash

set -x

# Insert a random delay up to this value, to spread virus updates round
# the clock. 1800 seconds = 30 minutes.
# Set this to 0 to disable it.
#UPDATEMAXDELAY=600
UPDATEMAXDELAY=0
#if [ -f /etc/sysconfig/MailScanner ] ; then
#        . /etc/sysconfig/MailScanner
#fi
#export UPDATEMAXDELAY
URLSOURCE="http://www.pccc.com/downloads/SpamAssassin/contrib/KAM.cf"
BASE=/home/udienz/project/public-sa
if [ "x$UPDATEMAXDELAY" = "x0" ]; then
  :
else
  logger -p mail.info -t KAM.cf.sh Delaying cron job up to $UPDATEMAXDELAY seconds
  perl -e "sleep int(rand($UPDATEMAXDELAY));"
fi

# JKF Fetch KAM.cf
echo Fetching KAM.cf...
reload=1
cd $BASE
#rm -f KAM.cf
#/usr/bin/wget -O KAM.cf http://www.peregrinehw.com/downloads/SpamAssassin/contrib/KAM.cf
/usr/bin/wget -N $URLSOURCE

if [ "$?" = "0" ]; then
  echo It completed okay.
  if [ -r KAM.cf.backup ]; then
    if [ KAM.cf -nt KAM.cf.backup ]; then
      if ( tail -10 KAM.cf | grep -q '^#.*EOF' ); then
        echo It succeeded, so make a backup
        cp -f KAM.cf KAM.cf.backup
      else
        echo ERROR: Could not find EOF marker in KAM.cf
        cp -f KAM.cf.backup KAM.cf
      fi
    else
      echo Remote file not newer than local copy
      reload=0
    fi
  else
    # No backup file present, so delete file if it is bad
    if ( tail -10 KAM.cf | grep -q '^#.*EOF' ); then
      echo Success, make a backup
      cp -f KAM.cf KAM.cf.backup
    else
      echo ERROR: Could not find EOF marker in KAM.cf and no backup
      rm -f KAM.cf
      reload=0
    fi
  fi
else
  echo It failed to complete properly
  if [ -r KAM.cf.backup ]; then
    echo Restored backup of KAM.cf
    cp -f KAM.cf.backup KAM.cf
  else
    # No backup copy present, so delete bad KAM.cf
    echo ERROR: wget of KAM.cf failed and no backup
    rm -f KAM.cf
    reload=0
  fi
fi

# Reload MailScanner only if we need to.
if [ "$reload" = "1" ]; then
        git add $BASE/KAM.cf
        git commit -m "daily update KAM.cf at $(date -u)"
        git push origin master
  echo Reloading spamassassin and SpamAssassin configuration rules
  sudo /etc/init.d/spamassassin reload
fi

