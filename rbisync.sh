#!/bin/bash

PATH1=$1
PATH2=$2

echo "Bisync $PATH1 and $PATH2 ..."
BISYNC_LOG="bisync.log"

EXCLUDE_FILE="exclude.list"
# store bisync status log with --dry-run into bisync.log
rclone bisync $PATH1 $PATH2 --dry-run --verbose --exclude _backup/** --log-format="" 2>&1 | tee $BISYNC_LOG

# 1. capture "copy to" action from bisync.log
DRY_RUN=$(cat $BISYNC_LOG | sed -s 's/:/ /'|grep -E 'INFO\s*-\s*Path[1|2]\s*Queue copy to'|awk '{\
if ($7 == "Path2") {sub(".*/","",$9); filename=substr($0, index($0, $9)); gsub(/ /,"\\",filename); print "Path2 " filename;} \
else if ($7 == "Path1") {sub(".*/","",$9); filename=substr($0, index($0, $9)); gsub(/ /,"\\",filename); print "Path1 " filename;} \
else {print("wrong")}}' \
)

#cat bisync.log | sed -s 's/:/ /'|grep -E 'INFO\s*-\s*Path[1|2]\s*Queue copy to'|awk '{if ($7 ~ 'Path2') print "backup Path2 files to _backup"; sub(".*/","",$9); print $9 else print "wrong"}'

RES=(${DRY_RUN})

# backup the copying files into path[1 or 2]/_backup if there are "copy to" jobs
REPORT=false

if [ ${#RES[@]} -gt 0 ]; then 
	echo "[$((${#RES[@]}/2))]  file changed...backup files..."
	REPORT=true
else
	echo "No newer file in both $PATH1/$PATH2 ..."
fi

for ((i=0;i<${#RES[@]};i+=2))
do
  if [ "${RES[i]}" = "Path1" ]; then
	# replace '\' with space
	RES[$i+1]=${RES[$i+1]/\\/ }  
	
	echo "[$(($i+1))/$((${#RES[@]}/2))] cp $PATH1/${RES[$i+1]} $PATH1/_backup/"
	cp $PATH1/"${RES[$i+1]}" $PATH1/_backup/
	#path1/_backup/${RES[$i+1]}"
  elif [ "${RES[i]}" = "Path2" ]; then
	# replace '\' with space
	RES[$i+1]=${RES[$i+1]/\\/ }  

	echo "[$(($i+1))/$((${#RES[@]}/2))] cp $PATH2/${RES[$i+1]} $PATH2/_backup/"
	cp $PATH2/"${RES[$i+1]}" $PATH2/_backup/
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
	echo "[$((${#RES[@]}/2))] files deleted...backup files..."
	REPORT=true
else
	echo "No file deletion in both $PATH1/$PATH2 ..."
fi

# backup the deleting files into path[1 or 2]/_backup if there are "delete" jobs
for ((i=0;i<${#RES[@]};i+=2))
do
  if [ "${RES[$i]}" = "Path1" ]; then
	# replace '\' with space
	RES[$i+1]=${RES[$i+1]/\\/ }  

    echo "[$(($i+1))/$((${#RES[@]}/2))]  cp $PATH1/${RES[$i+1]} $PATH1/_backup/"
    cp $PATH1/"${RES[$i+1]}" $PATH1/_backup/
	#path1/_backup/${RES[$i+1]}"
  elif [ "${RES[i]}" = "Path2" ]; then
	# replace '\' with space
	RES[$i+1]=${RES[$i+1]/\\/ }  

	echo "[$(($i+1))/$((${#RES[@]}/2))]  cp $PATH2/${RES[$i+1]} $PATH2/_backup/"
	cp path2/"${RES[$i+1]}" $PATH2/_backup/
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
if [ ${#RES[@]} -gt 0 ]; then
	echo "[${#RES[@]}] files conflict...Create&Update exclude.list to exclude file update..."
	
	if [ -e $EXCLUDE_FILE ]; then
	  rm $EXCLUDE_FILE
  	  touch $EXCLUDE_FILE
	fi
	
	for ((i=0;i<${#RES[@]};i++))
	do
		# replace '\' with space
		RES[$i]=${RES[$i]/\\/ }  
		#EXCLUDE_FILE="--exclude \"${RES[$i]}\""
		#EXCLUDE_FILE=${RES[$i]}
		echo "[$(($i+1))/${#RES[@]}] Exclude conflict file: ${RES[$i]}"
		echo ${RES[$i]} >> $EXCLUDE_FILE
	done
else
	echo "No file conflict in both $PATH1/$PATH2 ..."
fi
echo ""
echo "Start actual bisync................"

#cat $EXCLUDE_FILE
if $REPORT ; then
	echo "Start actual bisync................"
	rclone bisync $PATH1 $PATH2 --verbose --log-format="" --exclude _backup/** --exclude-from $EXCLUDE_FILE 2>&1 | tee $BISYNC_LOG
else
	echo "No update..................."
fi
