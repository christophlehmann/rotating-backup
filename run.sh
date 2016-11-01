#!/bin/bash

set -e

########################################################################################################################
# Configuration defaults | Adapt backup.conf to override them
########################################################################################################################
RUN_HOURLY=true
KEEP_HOURLY=24

RUN_DAILY=true
KEEP_DAILY=7

RUN_WEEKLY=true
KEEP_WEEKLY=4

RUN_MONTHLY=true
KEEP_MONTHLY=12

BACKUP_BASE_DIR=/var/backups/rotating-backup

########################################################################################################################
# Functions
########################################################################################################################
rotate() {
	BACKUP="$1"

	case "$BACKUP" in
		hourly)
			COUNT=$KEEP_HOURLY
			;;
		daily)
			COUNT=$KEEP_DAILY
			;;
		weekly)
			COUNT=$KEEP_WEEKLY
			;;
		monthly)
			COUNT=$KEEP_MONTHLY
			;;
		*)
			echo "No backup period given"
			exit 1
			;;
	esac

	rm -rf $BACKUP_BASE_DIR/$BACKUP/$COUNT
	for ((i=$COUNT;i>0;i-=1))
	do
		if test $i -lt $COUNT
		then
			let "NEXT=$i +1"
			mv $BACKUP_BASE_DIR/$BACKUP/$i $BACKUP_BASE_DIR/$BACKUP/$NEXT
		fi
	done
	mkdir -p $BACKUP_BASE_DIR/$BACKUP/1
}

backup() {
	BACKUP="$1"

	if test -z "$BACKUP"
	then
		echo "No backup period given"
		exit 1
	fi

	export BACKUP_DIR=$BACKUP_BASE_DIR/$BACKUP/1
	$DIR/backup.sh
}

make_directories() {
	mkdir -p $BACKUP_BASE_DIR
	chmod 750 $BACKUP_BASE_DIR

	if $RUN_HOURLY
	then
		for i in `seq $KEEP_HOURLY`
		do
			mkdir -p $BACKUP_BASE_DIR/hourly/$i
		done
	fi

	if $RUN_DAILY
	then
		for i in `seq $KEEP_DAILY`
		do
			mkdir -p $BACKUP_BASE_DIR/daily/$i
		done
	fi

	if $RUN_WEEKLY
	then
		for i in `seq $KEEP_WEEKLY`
		do
			mkdir -p $BACKUP_BASE_DIR/weekly/$i
		done
	fi

	if $RUN_MONTHLY
	then
		for i in `seq $KEEP_MONTHLY`
		do
			mkdir -p $BACKUP_BASE_DIR/monthly/$i
		done
	fi
}
########################################################################################################################
# Process
########################################################################################################################
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HOUR=$(date +%H)
DAY_OF_MONTH=$(date +%d)
DAY_OF_WEEK=$(date +%u)

source $DIR/backup.conf

MONTHLY_DIR=$BACKUP_BASE_DIR/monthly/1
WEEKLY_DIR=$BACKUP_BASE_DIR/weekly/1
DAILY_DIR=$BACKUP_BASE_DIR/daily/1
HOURLY_DIR=$BACKUP_BASE_DIR/hourly/1

make_directories

if $RUN_MONTHLY && test $DAY_OF_MONTH -eq 1 && test $HOUR -eq 0
then
	rotate monthly
	backup $MONTHLY_DIR

	rotate weekly
	cd $BACKUP_BASE_DIR/weekly
	ln -s $MONTHLY_DIR 1

	rotate daily
	cd $BACKUP_BASE_DIR/daily
	ln -s $MONTHLY_DIR 1

	rotate hourly
	cd $BACKUP_BASE_DIR/hourly
	ln -s $MONTHLY_DIR 1

elif $RUN_WEEKLY && test $DAY_OF_WEEK -eq 1 && test $HOUR -eq 0
then
	rotate weekly
	backup $WEEKLY_DIR

	rotate daily
	cd $BACKUP_BASE_DIR/daily
	ln -s $WEEKLY_DIR 1

	rotate hourly
	cd $BACKUP_BASE_DIR/hourly
	ln -s $WEEKLY_DIR 1

elif $RUN_DAILY && test $HOUR -eq 0
then
	rotate daily
	backup daily

	rotate hourly
	cd $BACKUP_BASE_DIR/hourly
	ln -s $DAILY_DIR 1

elif $RUN_HOURLY
then
	rotate hourly
	backup hourly
fi