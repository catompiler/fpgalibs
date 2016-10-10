#!/bin/bash

sources=$(ls *.v);

for file in $sources
do
    name=$(expr $file : '\(.*\)\.' \| $file);
    mkdir $name;
    mv "$name.v" $name
done
