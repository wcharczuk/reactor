all: test

init:
	@go get ./...

run:
	@go run main.go

profanity:
	@profanity --rules PROFANITY_RULES.yml --include="*.go"

test:
	@go test ./... -timeout 1s
