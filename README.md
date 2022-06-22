# rbisync.sh

## simple shell script to bisync like below with rclone
1. No rename & copy (rclone bisync default action) if the files in both location changed. instead, give a warning to user  
3. whatever file changed/deleted, these files will be copied under path1/path2 _backup
   (_backup will not be synced)

## usage
bash rbisync.sh <path1> <path2>
