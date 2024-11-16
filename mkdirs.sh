#!/bin/sh

if [ -e ~/.tpkg  ]
then
  if [ -d ~/.tpkg ]
  then
		exit 0
	fi
fi

rm -rf ~/.tpkg
mkdir ~/.tpkg
