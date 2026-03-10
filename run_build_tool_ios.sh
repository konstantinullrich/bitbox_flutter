#!/bin/bash

export PATH=$PATH:/usr/local/go/bin
export PATH=$PATH:~/go/bin
gomobile init || go install golang.org/x/mobile/cmd/gomobile@latest
gomobile init

cd ./go/api

echo "Binding Bitbox to iOS"
gomobile bind -o ../../ios/Api.xcframework -x -a -tags="timetzdata" -trimpath -target ios,iossimulator .
