# Sentinel - Go/Dart Bridge for Robotics Automation
# Get version from .git.
date=$(shell git log -1 --format="%cd" --date=short 2>/dev/null | sed s/-//g)
count=$(shell git rev-list --count HEAD 2>/dev/null || echo 0)
commit=$(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")

ifeq ($(wildcard .git/.),)
	VERSION ?= v1.0.0
else
	VERSION ?= $(date).$(count).$(commit)
endif

CGO_ENABLED := 1
NAME := sentinel
OUTDIR := build
NDK_BIN := $(ANDROID_NDK)/toolchains/llvm/prebuilt/linux-x86_64/bin

# Common build flags
LDFLAGS := -s -w -X main.Version=$(VERSION)
BUILDFLAGS := -trimpath -ldflags="$(LDFLAGS)"

# Default target
all: linux-amd64

# Build shared library for Linux AMD64
linux-amd64:
	@mkdir -p $(OUTDIR)
	CGO_ENABLED=$(CGO_ENABLED) GOOS=linux GOARCH=amd64 \
		go build -buildmode=c-shared -o $(OUTDIR)/$(NAME).so $(BUILDFLAGS) .

# Build shared library for Windows AMD64
windows-amd64:
	@mkdir -p $(OUTDIR)
	CGO_ENABLED=$(CGO_ENABLED) GOOS=windows GOARCH=amd64 \
		go build -buildmode=c-shared -o $(OUTDIR)/$(NAME).dll $(BUILDFLAGS) .

# Build shared library for Android ARM64
android-arm64:
	@mkdir -p $(OUTDIR)
	CGO_ENABLED=$(CGO_ENABLED) GOOS=android GOARCH=arm64 \
		CC=$(NDK_BIN)/aarch64-linux-android21-clang \
		go build -buildmode=c-shared -o $(OUTDIR)/lib$(NAME).so $(BUILDFLAGS) .

# Build all platforms
build-all: linux-amd64 windows-amd64 android-arm64

# Clean build artifacts
clean:
	rm -rf $(OUTDIR)
	rm -f $(NAME).so $(NAME).dll $(NAME).h lib$(NAME).so

# Test the code
test:
	go test -v ./...

# Install dependencies
deps:
	go mod download
	go mod verify

# Format code
fmt:
	go fmt ./...

# Run linter (requires golangci-lint)
lint:
	golangci-lint run || go vet ./...

.PHONY: all linux-amd64 windows-amd64 android-arm64 build-all clean test deps fmt lint
