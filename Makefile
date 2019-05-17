all: test

run:
	@go run main.go

test:
	@go test ./... -timeout 1s
