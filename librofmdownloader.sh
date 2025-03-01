#!/bin/bash
#This script is to download libro.fm audiobooks in bulk.
#Author: Kevin Hartley
#Version: 2025-03-01 1422
#Future Features:
#-Command-line updates
#-Read session key from file
#-Request specific file formats only
#-Request certain pages only
#-Request certain books only
#-Overwrite or not options
#-Update file name with titles\authors\narrators

#Defaults:
verbosity=6 #Update once script has been tested thoroughly
exitcode=0
session="$(cat .sessionkey)"
isbn=9781508253631
filenum=0
baseurl="https://libro.fm/user/library/"
dlurl="/download?file_type=zip&file="
outputpath=.
fileext=zip

#Select and source library functions
librarydir=/usr/local/bin
. $librarydir/library.sh

#Start logging this script
startlog

#Log script usage in $logdir/ScriptUsage.log
logUsage "$*" || outerror "Unable to log script usage."

Main() {
  outdebug "Starting main function."
  getPages || outcrit "Unable to run getPages function."
  for page in $(seq 1 $maxpages); do
    processPage $page || outcrit "Unable to run processPage function for page $page."
  done
} #Main

Help() {
  echo "Script Name: librofmdownloader.sh"
  echo "Syntax: librofmdownloader.sh <options> <subset>"
  echo ""
  echo "Available Options:"
  echo "--Help\-h\-?     - Display this help information."
  echo "-v(vvvv)\v[0-6]  - Increase verbosity level for each v or set explicitly to level."
  echo ""
  echo "Available Subsets:"
  echo ""
  Exit
} #Help

#Parse script options:
shopt -s extglob
while [ $# -ge 0 ]; do
  if [[ "$1" == "" ]]; then
    break
  fi
  case $1 in
    "--help"|"-h"|"-?")
      Help
      ;;
    -+(v))
      vees=${1:1} #Remove the -
      for ((i=1; i<=${#vees}; i++ )); do #for each v, do
        verbup
      done
      ;;
    -v[0-9]) #Explicitly set verbosity level
      # shellcheck disable=SC2034
      verbosity=${1: -1}
      ;;
    *)
      outcrit "Unhandled commandline option. Please use \"Help\" option for detailed syntax and options."
      ;;
  esac
  shift
done
shopt -u extglob

getPages() {
  outdebug "Starting getPages..."
  wget "$baseurl" --header "Cookie: _store_session=$session" -O index.html || outcrit "Unable to wget index.html to find max pages."
  outdebug "Processing index.html to find max pages..."
  maxpages=$(grep "user/library?page=" index.html | tail -1 | sed 's/.*page=//' | sed 's/".*//')
  rm index.html || outwarn "Unable to remove index.html, please remove manually."
  outdebug "Exiting getPages function."
} #getPages

downloadBook() {
    wget "$baseurl$isbn/download?file_type=$fileext&file=$filenum" --header "Cookie: _store_session=$session" -O "$outputpath/$isbn-part-$filenum.$fileext"
} #downloadBook

processPage() {
  #one argument for page number
  outdebug "Starting processPage function for page number $1..."
  wget "$baseurl?page=$1" --header "Cookie: _store_session=$session" -O page.html || outcrit "Unable to wget page $1 from the user's library."
  grep "download?file" page.html > page.txt || outcrit "Unable to grep page.html for the download links."
  rm page.html || outwarn "Unable to remove page.html, please remove manually."
  sed -i 's/.*href="//g' page.txt || outcrit "Unable to perform sed commands to strip download link prefixes."
  sed -i 's/".*//' page.txt || outcrit "Unable to perform sed commands to strip download link suffixes."

  for line in $(cat page.txt); do
    wget "https://libro.fm$line" --header "Cookie: _store_session=$session" -O $outputpath/$(echo $line | sed 's@/user/library/@@g' | sed 's@/download?file=@-@g' | sed 's@&amp;file_type=@.@g') || outerror "Unable to download $line."
  done
  outdebug "Exiting processPage function for page $1."
} #processPage

Main

Exit
