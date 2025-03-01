#!/bin/bash
#This script is to download libro.fm audiobooks in bulk.
#Author: Kevin Hartley
#Version: 2025-03-01 1534

#Defaults:
verbosity=6 #Update once script has been tested thoroughly
exitcode=0
session="$(cat .sessionkey)"
isbn=9781508253631
filenum=0
baseurl="https://libro.fm/user/library/"
outputpath=.
fileext=zip
overwrite=false
minpage=1
maxpages=1

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
  for page in $(seq $minpage $maxpages); do
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
  echo "--format\-f      - Specify format to download (e.g., zip)."
  echo "--isbn\-i        - Specify specific ISBN of book to download."
  echo "--page\-p        - Specify specific page of user library to download."
  echo "--nooverwrite\-n - Specify that books should not be redownloaded and overwrite existing files."
  echo "--overwrite\-o   - Specify that books  should be redownloaded and overwrite existing files."
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
    "--format"|"--Format"|"-f")
      fileext=$1
      shift
      ;;
    "--isbn"|"--ISBN"|"-i")
      isbn=$1
      downloadBook
      shift
      ;;
    "--nooverwrite"|"-n")
      overwrite=false
      ;;
    "--overwrite"|"-o")
      overwrite=true
      ;;
    "--page"|"-p")
      minpage=$1
      maxpages=$1
      shift
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
  add_to_cleanup index.html || outwarn "Unable to add index.html to the files to clean array."
  outdebug "Processing index.html to find max pages..."
  maxpages=$(grep "user/library?page=" index.html | tail -1 | sed 's/.*page=//' | sed 's/".*//')
  outdebug "Exiting getPages function."
} #getPages

downloadBook() {
  for filenum in $(seq 0 4); do
    wget "$baseurl$isbn/download?file_type=$fileext&file=$filenum" --header "Cookie: _store_session=$session" -O "$outputpath/$isbn-part-$filenum.$fileext"
  done
} #downloadBook

processPage() {
  #one argument for page number
  outdebug "Starting processPage function for page number $1..."
  wget "$baseurl?page=$1" --header "Cookie: _store_session=$session" -O page.html || outcrit "Unable to wget page $1 from the user's library."
  add_to_cleanup page.html || outwarn "Unable to add page.html to the files to clean array."
  grep "download?file" page.html > page.txt || outcrit "Unable to grep page.html for the download links."
  add_to_cleanup page.txt || outwarn "Unable to add page.txt to the files to clean array."
  sed -i 's/.*href="//g' page.txt || outcrit "Unable to perform sed commands to strip download link prefixes."
  sed -i 's/".*//' page.txt || outcrit "Unable to perform sed commands to strip download link suffixes."

  for line in $(cat page.txt); do
    wget "https://libro.fm$line" --header "Cookie: _store_session=$session" -O $outputpath/$(echo $line | sed 's@/user/library/@@g' | sed 's@/download?file=@-@g' | sed 's@&amp;file_type=@.@g') || outerror "Unable to download $line."
  done
  outdebug "Exiting processPage function for page $1."
} #processPage

Main

Exit
