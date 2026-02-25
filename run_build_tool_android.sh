export PATH=$PATH:/usr/local/go/bin
export PATH=$PATH:~/go/bin
gomobile init || go install golang.org/x/mobile/cmd/gomobile@latest
gomobile init

echo "Binding Bitbox to Android"
gomobile bind -o $1 -target=android -androidapi 24 .
