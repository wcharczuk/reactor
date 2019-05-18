all: test

init:
	@go get ./...
	@go get github.com/blend/go-sdk/cmd/profanity

run:
	@go run main.go

profanity:
	@profanity --rules PROFANITY_RULES.yml --include="*.go" -v

test:
	@go test ./... -timeout 1s
