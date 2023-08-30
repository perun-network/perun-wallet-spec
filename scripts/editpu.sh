#!/bin/bash

# Expects an input file as its argument.
if [ $# -eq 0 ]; then
    echo "No arguments provided. Please provide a file to watch."
    exit 1
fi

cat $1 | plantuml -p > tmp.png && feh -r --auto-reload tmp.png &

find $1 | entr sh -c "cat $1 | plantuml -p > tmp.png"
