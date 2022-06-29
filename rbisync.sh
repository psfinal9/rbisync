#!/bin/bash

PATH1=$1
PATH2=$2

#echo "Bisync $PATH1 and $PATH2 ..."
BISYNC_LOG="bisync.log"

EXCLUDE_FILE="exclude.list"
# store bisync status log with --dry-run into bisync.log
# for debugging
# rclone bisync $PATH1 $PATH2 --dry-run --verbose --exclude _backup/** --log-format="" 2>&1 | $tee BISYNC_LOG

if [ -e $BISYNC_LOG ]; then
  rm $BISYNC_LOG
fi

rclone bisync $PATH1 $PATH2 --dry-run --verbose --exclude _backup/** --log-format="" --log-file=$BISYNC_LOG


#
# 0.check if bisync failed or not
# "Failed to bisync: all files were changed"
#
DRY_RUN=$(cat $BISYNC_LOG | sed -s 's/:/ /'|grep -E 'Failed to bisync')
RES=(${DRY_RUN})

if [ ${#RES[@]} -gt 0 ]; then 
    echo "## failed bisync...report to Joplin & exit ##"
    cat $BISYNC_LOG
    python -u ~/_NASSYNC/GitHub/python/Log2Joplin.py --path ~/ --notebook 데일리업뎃 2>&1 | tee -a checkMailDaily.log
    exit 0
fi


#
# 1. capture "copy to" action from bisync.log
DRY_RUN=$(cat $BISYNC_LOG | sed -s 's/:/ /'|grep -E 'INFO\s*-\s*Path[1|2]\s*Queue copy to'|awk '{\
if ($7 == "Path2") {sub(".*/","",$9); filename=substr($0, index($0, $9)); gsub(/ /,"\\",filename); print "Path2 " filename;} \
else if ($7 == "Path1") {sub(".*/","",$9); filename=substr($0, index($0, $9)); gsub(/ /,"\\",filename); print "Path1 " filename;} \
else {print("wrong")}}' \
)

#cat bisync.log | sed -s 's/:/ /'|grep -E 'INFO\s*-\s*Path[1|2]\s*Queue copy to'|awk '{if ($7 ~ 'Path2') print "backup Path2 files to _backup"; sub(".*/","",$9); print $9 else print "wrong"}'

RES=(${DRY_RUN})

# backup the copying files into path[1 or 2]/_backup/YYYY-MM-DDTHH-MM-SS/ if there are "copy to" or "delete" jobs
# 
BACKUP_DIR_NAME="_backup/$(date '+%Y-%m-%dT%H%M%S')"

# report to joplin or email 
REPORT=false

# do actual bisync or not
RUN_BISYNC=false

create_backup_folder() {

	if [[ "$1" =~ ':' ]] ; then
	#echo "$1 IS REMOTE"
		rclone mkdir "$1/$2"
	else
		if [ ! -d $1/$2 ]; then
			   mkdir "$1/$2"
		fi
	fi
}

echo "---------------------------------------------------------------------------------"
echo "Path1:$PATH1"
echo "Path2:$PATH2"
echo ""

if [ ${#RES[@]} -gt 0 ]; then 
	echo "## $((${#RES[@]}/2))  file changed...backup files... ##"
	REPORT=true
	RUN_BISYNC=true
else
	echo "## No newer file in both Path1/Path2 ... ##"
fi

for ((i=0;i<${#RES[@]};i+=2))
do  
  if [ "${RES[i]}" = "Path1" ]; then
		
	# replace '\' with space
	RES[$i+1]=${RES[$i+1]/\\/ }  
	create_backup_folder $PATH1 $BACKUP_DIR_NAME
	
	echo "[$((($i+1)/2))/$((${#RES[@]}/2))] backup **Path1/${RES[$i+1]}** Path1/$BACKUP_DIR_NAME/"
	if [[ "$PATH1" =~ ':' ]] ; then
	    rclone copy $PATH1/"${RES[$i+1]}" $PATH1/$BACKUP_DIR_NAME/ 2>&1
	else
	    cp $PATH1/"${RES[$i+1]}" $PATH1/$BACKUP_DIR_NAME/ 2>&1
	fi
	#path1/_backup/${RES[$i+1]}"
  elif [ "${RES[i]}" = "Path2" ]; then
	# replace '\' with space
	RES[$i+1]=${RES[$i+1]/\\/ }
	create_backup_folder $PATH2 $BACKUP_DIR_NAME
	
	echo "[$((($i+1)/2))/$((${#RES[@]}/2))] backup **Path2/${RES[$i+1]}** Path2/$BACKUP_DIR_NAME/"
	if [[ "$PATH2" =~ ':' ]] ; then
	    rclone copy $PATH2/"${RES[$i+1]}" $PATH2/$BACKUP_DIR_NAME/ 2>&1
	else
      cp $PATH2/"${RES[$i+1]}" $PATH2/$BACKUP_DIR_NAME/ 2>&1
	fi

	#TEST="2016#10 worksheet.xlsx"
	#cp path2/"$TEST" path2/_backup/
  
  else
	echo "something wrong...need to check..."
	exit 127
	#path2/_backup/${RES[$i+1]}"
  fi
done


echo ""
# 
# check delete files
#
DRY_RUN=$(cat $BISYNC_LOG | sed -s 's/:/ /'|grep -E 'INFO\s*-\s*Path[1|2]\s*Queue delete'|awk '{\
if ($3 == "Path2") {sub(".*/","",$7); filename=substr($0, index($0, $7)); gsub(/ /,"\\",filename); print "Path2 " filename;} \
else if ($3 == "Path1") {sub(".*/","",$7); filename=substr($0, index($0, $7)); gsub(/ /,"\\",filename); print "Path1 " filename;} \
else {print("wrong")}}' \
)
RES=(${DRY_RUN})

if [ ${#RES[@]} -gt 0 ]; then 

	echo "## $((${#RES[@]}/2)) files deleted...backup files... ##"
	REPORT=true
	RUN_BISYNC=true
else
	echo "## No file deletion in both Path1/Path2 ... ##"
fi

# backup the deleting files into path[1 or 2]/_backup if there are "delete" jobs
for ((i=0;i<${#RES[@]};i+=2))
do
  if [ "${RES[$i]}" = "Path1" ]; then

	# replace '\' with space
	RES[$i+1]=${RES[$i+1]/\\/ }  
	create_backup_folder $PATH1 $BACKUP_DIR_NAME

    echo "[$((($i+1)/2))/$((${#RES[@]}/2))]  backup **Path1/${RES[$i+1]}** Path1/$BACKUP_DIR_NAME"
	if [[ "$PATH1" =~ ':' ]] ; then
	   rclone copy $PATH1/"${RES[$i+1]}" $PATH1/$BACKUP_DIR_NAME/ 2>&1
	else
       cp $PATH1/"${RES[$i+1]}" $PATH1/$BACKUP_DIR_NAME/ 2>&1
	fi
	#path1/_backup/${RES[$i+1]}"
  elif [ "${RES[i]}" = "Path2" ]; then
		
	# replace '\' with space
	RES[$i+1]=${RES[$i+1]/\\/ }  
	create_backup_folder $PATH2 $BACKUP_DIR_NAME

	echo "[$((($i+1)/2))/$((${#RES[@]}/2))]  backup **Path2/${RES[$i+1]}** Path2/$BACKUP_DIR_NAME/"
    if [[ "$PATH2" =~ ':' ]] ; then
       rclone copy $PATH2/"${RES[$i+1]}" $PATH2/$BACKUP_DIR_NAME/ 2>&1
    else
       cp $PATH2/"${RES[$i+1]}" $PATH2/$BACKUP_DIR_NAME/ 2>&1
    fi
  else
	echo "something wrong...need to check..."
	exit 127
	#path2/_backup/${RES[$i+1]}"
  fi
done
echo ""
# 
# check conflict files
#
DRY_RUN=$(cat $BISYNC_LOG | sed -s 's/:/ /'|grep -E 'NOTICE\s*-\s*WARNING\s*New or changed in both paths'|awk '{filename=substr($0, index($0, $11)); gsub(/ /,"\\",filename); print filename}')

RES=(${DRY_RUN})

# backup the copying files into path[1 or 2]/_backup if there are "copy to" jobs
if [ -e $EXCLUDE_FILE ]; then
  rm $EXCLUDE_FILE
  touch $EXCLUDE_FILE
fi
	
if [ ${#RES[@]} -gt 0 ]; then
	echo "## ${#RES[@]} files conflict...will be excluded when bisyncing... ##"
	
	REPORT=true
	
	for ((i=0;i<${#RES[@]};i++))
	do
		# replace '\' with space
		RES[$i]=${RES[$i]/\\/ }  
		#EXCLUDE_FILE="--exclude \"${RES[$i]}\""
		#EXCLUDE_FILE=${RES[$i]}
		echo "[$((($i+1)/2))/${#RES[@]}] Exclude conflict file: **${RES[$i]}**"
		echo ${RES[$i]} >> $EXCLUDE_FILE
	done
else
	echo "***No file conflict in both Path1/Path2 ...***"
fi
echo ""

#cat $EXCLUDE_FILE
if $RUN_BISYNC ; then
	echo "## Start actual bisync................ ##"
	rclone bisync $PATH1 $PATH2 --verbose --exclude _backup/** --exclude-from $EXCLUDE_FILE 2>&1 | tee $BISYNC_LOG
else
	echo "## No actual bisync................... ##"
fi


if $REPORT ; then
   echo "Report to Joplin..."
   python -u ~/_NASSYNC/GitHub/python/Log2Joplin.py --path ~/ --notebook 데일리업뎃 2>&1 | tee -a checkMailDaily.log
fi
