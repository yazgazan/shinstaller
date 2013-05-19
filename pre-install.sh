#!/usr/bin/env bash

while [[ ! $# = 0 ]]; do
  if [[ $1 =~ '--prefix=' ]]; then
    _EMBED_PREFIX=$(echo $1 | sed 's/--prefix=//g')
  fi
  shift
done

