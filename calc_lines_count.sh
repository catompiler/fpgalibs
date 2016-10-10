#!/bin/bash

find -type f -name "*.v" | xargs cat | wc -l

