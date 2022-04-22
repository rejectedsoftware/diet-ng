#!/bin/bash

set -xe

DC=${DC%-*}
if [ "$DC" == "ldc" ]; then DC="ldc2"; fi

echo "Running unit tests..."
dub test

echo "Checing makepot for successful compilation..."
dub build :makepot

if [ "$DC" == "ldc2" ]; then
	echo "Testing for DIP 1000 compatibility..."
	DFLAGS="--preview=dip1000 --preview=dip25" dub build 
fi
