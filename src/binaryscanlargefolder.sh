#!/bin/bash
#


function calculate_size()
{
	cat $1 | \
	awk '{printf "%s+", $1}' | \
	awk '{print $0 "0"}'  | \
	bc -l
}

function file_size_or_zero()
{ 
	if [ -f "$1" ]
	then
		stat -c%s $1
	else
		echo 0
	fi
}

SOURCEFOLDER=$1
PROJECT=$2
VERSION=$3
NOSCAN=$4

TEMPFOLDER=~/temp
mkdir -p $TEMPFOLDER
# Print info on available space
TEMPSPACE=$(df -h $TEMPFOLDER | grep -vi size | awk '{print $4}')
echo Available space in TEMPFOLDER $TEMPSPACE
FILELIST=$TEMPFOLDER/filelist
TMPLIST=$TEMPFOLDER/tmplist
rm -f $TEMPFOLDER/TEMP*
rm -f $FILELIST
rm -f $TMPLIST

SIZELIMIT=4000000000

# Environment and other sanity checks 
# check if we have GNU find
find --version >/dev/null 2>&1
if [ "$?" == "0" ]
then 
	echo Found GNU find
else
	echo Need GNU find
	exit 1
fi

# Check if we have BD_URL
if [ -n "$BD_URL" ]
then
	echo Blackduck is at $BD_URL
else
	echo need BD_URL
	exit 1
fi

# Check if we have API TOKEN
if [ -n "$BD_API_TOKEN" ]
then
	echo Found BD_API_TOKEN
else
	echo need BD_API_TOKEN
	exit 1
fi
#
#check if there are files larger that the limit
FILESOVERLIMIT=$(find $SOURCEFOLDER -type f -size +${SIZELIMIT})

if [ "$FILESOVERLIMIT" == "" ]
then
	echo No files larger that $SIZELIMIT detected. Proceeding
	echo
else
	echo 
	echo The following files are larger that $SIZELIMIT
	echo $FILESOVERLIMIT
	echo 
	echo Deal with them first.
	exit 1
fi

# Generate filelist
find $SOURCEFOLDER -type f -printf "%s %p \n" >$FILELIST

if [ ! -s $FILELIST ]
then
	echo "No files found in the tatget folder"
	exit 1
fi

#Basic stats
TOTALSIZE=$(calculate_size $FILELIST)
NUMFILES=$(cat $FILELIST | wc -l)

echo $NUMFILES files totaling $TOTALSIZE bytes
echo
echo Processing filelist

TOTAL=0
LINENUM=0
cat $FILELIST | while read LINE
do
	LINENUM=$(( $LINENUM + 1 ))
	DATA=($LINE)
	SIZE=${DATA[0]}
	FPATH=${LINE/$SIZE /}
	PRETALLY=$(( $TOTAL + $SIZE ))
	if [ $PRETALLY -gt $SIZELIMIT ]
	then
		echo $TOTAL
		TOTAL=0
		tar cf $TEMPFOLDER/TEMP-${LINENUM}.tar -T $TMPLIST
		bash scan-binary.sh $TEMPFOLDER/TEMP-${LINENUM}.tar $PROJECT $VERSION ${LINENUM}
		TOTAL=$SIZE
		echo $FPATH >$TMPLIST
	else
		TOTAL=$(( $TOTAL + $SIZE ))
		echo $FPATH >>$TMPLIST
	fi
done
echo $TOTAL
tar cf $TEMPFOLDER/TEMP-${LINENUM}.tar -T $TMPLIST
bash scan-binary.sh $TEMPFOLDER/TEMP-${LINENUM}.tar $PROJECT $VERSION ${LINENUM}

exit 0 #This is the most important line
