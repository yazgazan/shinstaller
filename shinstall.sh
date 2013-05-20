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
  echo "Usage : $0 [conf file] (default "'`shinstallconf`'")" > $STDERR
}

function help()  {
  usage
  (
    echo $'\t'"$0 help"
    echo
    echo $'conf file directives : '
    echo $'\toutput         <script file>                         - Set the installer file that will be generated'
    echo $'\tfile           <file path>   <file name> [path to]   - Add a file to the installer. (`path to` must not include the prefix)'
    echo $'\ttextfile       <file path>   <file name> [path to]   - Add a text file to the installer. Text files can be used in the pre/postinstall scripts'
    echo $'\tnoinstall                                            - Dont install the files, just run the scripts'
    echo $'\tpreinit        <script file>                         - A script executed before the installer initialisation (just bellow the #!)'
    echo $'\tpreinstall     <script file>                         - A script executed just before the installation'
    echo $'\tpostinstall    <script file>                         - A script executed just after the installation'
    echo $'\tdefaultprefix  <prefix>                              - The default prefix to be used'
    echo $'\texec           <file>                                - A script to be executed during the installer generation'
    echo $'\tsource         <script file>                         - A script to be sourced during the installer generation'
    echo $'\teval           <bash>                                - A command to be evaluated during the installer generation'
    echo $'\tdebug                                                - Drop a bash REPL in the generator context'
    echo
  ) > $STDERR
}

function init_tmp_file()  {
  FILE="$1"
  rm -f $FILE
  touch $FILE
}

function cmd_output()  {
  touch "$1" >& /dev/null
  if [[ ! -w "$1" ]]; then
    fail_open_write "$1"
  fi
  OUTFILE="$1"
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
  echo '  if [[ ! $(echo "$__PATHTO" | grep "/") = "" ]]; then'
  echo '    __PATHTODIR=$(echo "$__PATHTO" | sed -E "s/\/[^/]+$/\//")'
  echo '  else'
  echo '    __PATHTODIR="."'
  echo '  fi'
  echo '  let START=$_EMBED_TOTAL_SIZE-'$TOTAL_SIZE
  echo '  mkdir -p "$_EMBED_PREFIX"/"$__PATHTODIR"'
  echo '  cat "$0" | tail -c $START | head -c '$SIZE' > "$_EMBED_PREFIX"/"$__PATHTO"'
  echo '  chmod $_EMBED_FILE_'$NAME'_RIGHT "$_EMBED_PREFIX"/"$__PATHTO"'
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
  echo '  if [[ ! $(echo "$__PATHTO" | grep "/") = "" ]]; then'
  echo '    __PATHTODIR=$(echo "$__PATHTO" | sed -E "s/\/[^/]+$/\//")'
  echo '  else'
  echo '    __PATHTODIR="."'
  echo '  fi'
  echo '  echo -e "'$FILECONTENT'" > "$_EMBED_PREFIX"/"$__PATHTO"'
  echo '  mkdir -p "$_EMBED_PREFIX"/"$__PATHTODIR"'
  echo '  chmod $_EMBED_FILE_'$NAME'_RIGHT "$_EMBED_PREFIX"/"$__PATHTO"'
  echo '}'
  echo 'function _embed_'$NAME'_cat()  {'
  echo '  echo -e "'$FILECONTENT'"'
  echo '}'

  EXTRACT_ALL=$EXTRACT_ALL'_embed_'$NAME'_extract; '
  return
}

function cmd_noinstall()  {
  AUTOEXTRACT="false"
}

function cmd_pre_init()  {
  SCRIPTNAME="$1"

  if [[ $SCRIPTNAME = "" ]]; then
    error "script name required (line $NLINE)"
  fi
  if [[ ! -r $SCRIPTNAME ]]; then
    fail_open_read "$SCRIPTNAME"
  fi
  PREINIT="$SCRIPTNAME"
}

function cmd_pre_install()  {
  SCRIPTNAME="$1"

  if [[ $SCRIPTNAME = "" ]]; then
    error "script name required (line $NLINE)"
  fi
  if [[ ! -r $SCRIPTNAME ]]; then
    fail_open_read "$SCRIPTNAME"
  fi
  PREINSTALL="$SCRIPTNAME"
}

function cmd_post_install()  {
  SCRIPTNAME="$1"

  if [[ $SCRIPTNAME = "" ]]; then
    error "script name required (line $NLINE)"
  fi
  if [[ ! -r $SCRIPTNAME ]]; then
    fail_open_read "$SCRIPTNAME"
  fi
  POSTINSTALL="$SCRIPTNAME"
}

function cmd_default_prefix()  {
  PREFIX="$1"

  if [[ $PREFIX = "" ]]; then
    error "prefix required (line $NLINE)"
  fi
  DEFAULTPREFIX="$PREFIX"
}

function cmd_exec()  {
  SCRIPTNAME="$1"

  if [[ $SCRIPTNAME = "" ]]; then
    error "script name required (line $NLINE)"
  fi
  if [[ ! -x $SCRIPTNAME ]]; then
    fail_open_execute "$SCRIPTNAME"
  fi
  ./$SCRIPTNAME
}

function cmd_source()  {
  SCRIPTNAME="$1"

  if [[ $SCRIPTNAME = "" ]]; then
    error "script name required (line $NLINE)"
  fi
  if [[ ! -r $SCRIPTNAME ]]; then
    fail_open_read "$SCRIPTNAME"
  fi

  . $SCRIPTNAME
  echo $BLABLA
}

function cmd_eval()  {
  SCRIPTSTR="$1"

  SCRIPTSTR=$(echo $SCRIPTSTR | cut -d' ' -f2-)
  if [[ $SCRIPTSTR = "" ]]; then
    error "script required (line $NLINE)"
  fi
  eval "$SCRIPTSTR"
}

function cmd_debug()  {
  while read -p "> " -u 1 DEBUG_CMD; do
    eval $DEBUG_CMD
  done
}

function cmd_skip()  {
  return
}

if [[ $# < 1 ]]; then
  if [[ -r "shinstallconf" ]]; then
    CONFFILE="shinstallconf"
  else
    usage
    exit 1
  fi
else
  CONFFILE=$1
fi

if [[ $# > 1 ]]; then
  usage
  exit 1
fi

if [[ $CONFFILE = "help" ]] || [[ $CONFFILE = "--help" ]] || [[ $CONFFILE = "-h" ]]; then
  help
  exit 0
fi

if [[ ! -r $CONFFILE ]]; then
  fail_open_read "$CONFFILE"
fi

TMPFILEEMBEDED="/tmp/embeded"
TMPFILE="/tmp/embeder"
PREINIT=""
PREINSTALL=""
POSTINSTALL=""
DEFAULTPREFIX=""
OUTFILE=""
AUTOEXTRACT="true"
EXTRACT_ALL=""

init_tmp_file $TMPFILE
init_tmp_file $TMPFILEEMBEDED

NLINE=0
TOTAL_SIZE=0
NFILE=0
while read LINE; do
  let NLINE+=1
  WHOLELINE=$LINE
  if [[ "$(expr index "$WHOLELINE" "#")" = "1" ]]; then
    continue
  fi
  LINE=( $LINE )
  CMD=${LINE[0]}
  if [[ $CMD = "output" ]]; then
    cmd_output "${LINE[1]}"
  elif [[ $CMD = "file" ]]; then
    cmd_file "${LINE[1]}" "${LINE[2]}" "${LINE[3]}" >> $TMPFILE
  elif [[ $CMD = "textfile" ]]; then
    cmd_textfile "${LINE[1]}" "${LINE[2]}" "${LINE[3]}" >> $TMPFILE
  elif [[ $CMD = "noinstall" ]]; then
    cmd_noinstall
  elif [[ $CMD = "preinit" ]]; then
    cmd_pre_init "${LINE[1]}"
  elif [[ $CMD = "preinstall" ]]; then
    cmd_pre_install "${LINE[1]}"
  elif [[ $CMD = "postinstall" ]]; then
    cmd_post_install "${LINE[1]}"
  elif [[ $CMD = "defaultprefix" ]] || [[ $CMD = "prefix" ]]; then
    cmd_default_prefix "${LINE[1]}" >> $TMPFILE
  elif [[ $CMD = "exec" ]]; then
    cmd_exec "${LINE[1]}"
  elif [[ $CMD = "source" ]]; then
    cmd_source "${LINE[1]}"
  elif [[ $CMD = "eval" ]]; then
    cmd_eval "$WHOLELINE"
  elif [[ $CMD = "debug" ]]; then
    cmd_debug
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

rm -f "$OUTFILE"
touch "$OUTFILE"
chmod +x "$OUTFILE"

echo '#!/usr/bin/env bash' >> "$OUTFILE"
echo 'env | grep -E "^_=" | grep "/usr/bin/env" > /dev/null || exit 0 `/usr/bin/env bash $0 $@`' >> $OUTFILE
if [[ ! $PREINIT = "" ]]; then
  cat "$PREINIT" >> "$OUTFILE"
fi
echo '_EMBED_PREFIX="'$DEFAULTPREFIX'"' >> "$OUTFILE"
cat "$TMPFILE" >> "$OUTFILE"

if [[ ! $PREINSTALL = "" ]]; then
  cat "$PREINSTALL" >> "$OUTFILE"
fi

if [[ $AUTOEXTRACT = "true" ]]; then
  echo "_embed_extract_all" >> "$OUTFILE"
fi

if [[ ! $POSTINSTALL = "" ]]; then
  cat "$POSTINSTALL" >> "$OUTFILE"
fi

echo "exit" >> "$OUTFILE"

cat "$TMPFILEEMBEDED" >> "$OUTFILE"

