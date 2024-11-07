#!/bin/bash

set -xe

COMPILER=$DC

DC=${DC%-*}
if [ "$DC" == "ldc" ]; then DC="ldc2"; fi

echo "Running unit tests..."
dub test

echo "Checing makepot for successful compilation..."
dub build :makepot

if [ "$COMPILER" == "ldc-latest" ] || [ "$COMPILER" == "dmd-latest" ] ; then
	echo "Testing for DIP 1000/1021/in compatibility..."
	DFLAGS="-preview=dip1000 -preview=dip1021" dub build
	DFLAGS="-preview=in" dub build
	DFLAGS="-preview=dip1000 -preview=dip1021 -preview=in" dub build
fi
