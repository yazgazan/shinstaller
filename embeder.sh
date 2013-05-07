#!/usr/bin/env bash

STDERR="/dev/stderr"
STDOUT="/dev/stdout"
STDIN="/dev/stdin"

function error()  {
  echo "$0 : Error : $@" > $STDERR
  exit 1
}

function unknown_cmd()  {
  error "Unknown cmd '$@'"
}

function fail_open_read()  {
  error "can't open file '$1' for reading (line $NLINE)"
}

function fail_open_write()  {
  error "can't open file '$1' for writing (line $NLINE)"
}

function fail_open_execute()  {
  error "can't open file '$1' for execution (line $NLINE)"
}

function usage()  {
  echo "Usage : $0 <conf file>" > $STDERR
}

function help()  {
  usage
  (
    echo
    echo -e "conf file directives : "
    echo -e "\tinfile   <script file>"
    echo -e "\toutfile  <script file>"
    echo -e "\tfile     <file path> <file name> [path to]"
    echo -e "\ttextfile <file path> <file name> [path to]"
    echo
  ) > $STDERR
}

function init_tmp_file()  {
  FILE="$1"
  rm -f $FILE
  touch $FILE
}

function cmd_skip()  {
  return
}

function cmd_infile()  {
  if [[ ! -r "$1" ]]; then
    fail_open_read "$1"
  fi
  INFILE="$1"
}

function cmd_outfile()  {
  touch "$1" >& /dev/null
  if [[ ! -w "$1" ]]; then
    fail_open_write "$1"
  fi
  OUTFILE="$1"
}

function cmd_autoextract()  {
  AUTOEXTRACT="true"
}

function cmd_file()  {
  _PATH="$1"
  NAME="$2"
  PATHTO="$3"

  if [[ ! -r $_PATH ]]; then
    fail_open_read "$_PATH"
  fi
  if [[ $NAME = "" ]]; then
    error "name required (line $NLINE)"
  fi
  if [[ $PATHTO = "" ]]; then
    PATHTO="$_PATH"
  fi

  SIZE=$(stat -c%s "$_PATH")
  RIGHT=$(stat -c%a "$_PATH")

  cat $_PATH >> $TMPFILEEMBEDED

  echo '_EMBED_FILES['$NFILE']="'$NAME'"'
  echo '_EMBED_FILE_'$NAME'_PATH="'$PATHTO'"'
  echo '_EMBED_FILE_'$NAME'_SIZE='$SIZE
  echo '_EMBED_FILE_'$NAME'_RIGHT='$RIGHT
  echo 'function _embed_'$NAME'_extract()  {'
  echo '  __PATHTO=$1'
  echo '  if [[ $__PATHTO = "" ]]; then'
  echo '    __PATHTO="'$PATHTO'"'
  echo '  fi'
  echo '  let START=$_EMBED_TOTAL_SIZE-'$TOTAL_SIZE
  echo '  cat "$0" | tail -c $START | head -c '$SIZE' > $__PATHTO'
  echo '  chmod $_EMBED_FILE_'$NAME'_RIGHT $__PATHTO'
  echo '}'

  EXTRACT_ALL=$EXTRACT_ALL'_embed_'$NAME'_extract; '

  let TOTAL_SIZE+=$SIZE
  let NFILE+=1
  return
}

function cmd_textfile()  {
  _PATH="$1"
  NAME="$2"
  PATHTO="$3"

  if [[ ! -r $_PATH ]]; then
    fail_open_read "$_PATH"
  fi
  if [[ $NAME = "" ]]; then
    error "name required (line $NLINE)"
  fi
  if [[ $PATHTO = "" ]]; then
    PATHTO="$_PATH"
  fi

  SIZE=$(stat -c%s "$_PATH")
  RIGHT=$(stat -c%a "$_PATH")

  FILECONTENT=""
  while read LINE2; do
    LINE2=$(echo "$LINE2" | sed -E 's/\!/\\\!/g' | sed -E 's/\$/\\\$/g')
    FILECONTENT=$FILECONTENT$LINE2"\\\n"
  done < "$_PATH"

  echo '_EMBED_FILES['$NFILE']="'$NAME'"'
  echo '_EMBED_FILE_'$NAME'_PATH="'$PATHTO'"'
  echo '_EMBED_FILE_'$NAME'_SIZE='$SIZE
  echo '_EMBED_FILE_'$NAME'_RIGHT='$RIGHT
  echo '_EMBED_FILE_'$NAME'_CONTENT="'$FILECONTENT'"'
  echo 'function _embed_'$NAME'_extract()  {'
  echo '  __PATHTO=$1'
  echo '  if [[ $__PATHTO = "" ]]; then'
  echo '    __PATHTO="'$PATHTO'"'
  echo '  fi'
  echo '  echo -e "'$FILECONTENT'" > $__PATHTO'
  echo '  chmod $_EMBED_FILE_'$NAME'_RIGHT $__PATHTO'
  echo '}'
  echo 'function _embed_'$NAME'_cat()  {'
  echo '  echo -e "'$FILECONTENT'"'
  echo '}'

  EXTRACT_ALL=$EXTRACT_ALL'_embed_'$NAME'_extract; '
  return
}

if [[ $# != 1 ]]; then
  if [[ -r "embederconf" ]]; then
    CONFFILE="embederconf"
  else
    usage
    exit 1
  fi
else
  CONFFILE=$1
fi

if [[ $CONFFILE = "help" ]]; then
  help
  exit 0
fi

if [[ ! -r $CONFFILE ]]; then
  fail_open_read "$CONFFILE"
fi

TMPFILEEMBEDED="/tmp/embeded"
TMPFILE="/tmp/embeder"
INFILE=''
OUTFILE=''
AUTOEXTRACT=''
EXTRACT_ALL=''

init_tmp_file $TMPFILE
echo 'env | grep -E "^_=" | grep "/usr/bin/env" > /dev/null || exit 0 `/usr/bin/env bash $0 $@`' >> $TMPFILE
init_tmp_file $TMPFILEEMBEDED

NLINE=0
TOTAL_SIZE='0'
NFILE=0
while read LINE; do
  let NLINE+=1
  LINE=( $LINE )
  CMD=${LINE[0]}
  if [[ $CMD = "infile" ]]; then
    cmd_infile "${LINE[1]}"
  elif [[ $CMD = "outfile" ]]; then
    cmd_outfile "${LINE[1]}"
  elif [[ $CMD = "file" ]]; then
    cmd_file "${LINE[1]}" "${LINE[2]}" "${LINE[3]}" >> $TMPFILE
  elif [[ $CMD = "textfile" ]]; then
    cmd_textfile "${LINE[1]}" "${LINE[2]}" "${LINE[3]}" >> $TMPFILE
  elif [[ $CMD = "autoextract" ]]; then
    cmd_autoextract
  elif [[ $CMD = "" ]]; then
    cmd_skip
  else
    unknown_cmd $CMD
  fi
done < $CONFFILE

(
  echo "function _embed_extract_all()  {"
  echo $EXTRACT_ALL
  echo "}"
  echo "_EMBED_TOTAL_SIZE=$TOTAL_SIZE"
) >> $TMPFILE

if [[ $AUTOEXTRACT = "true" ]]; then
  echo "_embed_extract_all" >> "$TMPFILE"
fi

rm -f "$OUTFILE"
touch "$OUTFILE"
chmod +x "$OUTFILE"

let NLINES=$(cat "$INFILE" | wc -l)-1

cat "$INFILE" | head -n 1 > "$OUTFILE"
cat "$TMPFILE" >> "$OUTFILE"

tail -n $NLINES "$INFILE" >> "$OUTFILE"

echo "exit" >> "$OUTFILE"

cat "$TMPFILEEMBEDED" >> "$OUTFILE"

