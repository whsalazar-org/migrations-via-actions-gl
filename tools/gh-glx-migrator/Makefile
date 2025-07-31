# Variables
BINARY_NAME=gh-glx
DOCKER_IMAGE=gh-glx-migrator
VERSION?=0.1.0
BUILD_DIR=bin
GOARCH?=amd64
GOOS?=darwin

# Go build flags
LDFLAGS=-ldflags "-X main.Version=${VERSION}"
GO_BUILD=go build ${LDFLAGS}

# Default target
.DEFAULT_GOAL := help

.PHONY: help
help: ## Display this help screen
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: clean
clean: ## Clean build directory
	rm -rf ${BUILD_DIR}
	go clean

.PHONY: deps
deps: ## Download dependencies
	go mod download
	go mod tidy

.PHONY: test
test: ## Run tests
	go test -v ./...

.PHONY: lint
lint: ## Run linters
	@echo "Running linters..."
	@command -v golangci-lint >/dev/null 2>&1 || { \
		echo "Installing golangci-lint..."; \
		brew install golangci-lint; \
	}
	golangci-lint run
	go vet ./...

.PHONY: build
build: clean deps ## Build binary
	GOARCH=${GOARCH} GOOS=${GOOS} ${GO_BUILD} -o ${BUILD_DIR}/${BINARY_NAME} main.go

.PHONY: build-all
build-all: clean deps ## Build for all platforms
	# MacOS
	GOOS=darwin GOARCH=amd64 ${GO_BUILD} -o ${BUILD_DIR}/${BINARY_NAME}-darwin-amd64 main.go
	GOOS=darwin GOARCH=arm64 ${GO_BUILD} -o ${BUILD_DIR}/${BINARY_NAME}-darwin-arm64 main.go
	# Linux
	GOOS=linux GOARCH=amd64 ${GO_BUILD} -o ${BUILD_DIR}/${BINARY_NAME}-linux-amd64 main.go
	GOOS=linux GOARCH=arm64 ${GO_BUILD} -o ${BUILD_DIR}/${BINARY_NAME}-linux-arm64 main.go
	# Windows
	GOOS=windows GOARCH=amd64 ${GO_BUILD} -o ${BUILD_DIR}/${BINARY_NAME}-windows-amd64.exe main.go

.PHONY: run
run: build ## Run the application
	./${BUILD_DIR}/${BINARY_NAME}

.PHONY: install
install: build ## Install the binary
	cp ${BUILD_DIR}/${BINARY_NAME} ${HOME}/.local/bin/

.PHONY: docker-build
docker-build: ## Build Docker image
	docker build -t ${DOCKER_IMAGE}:${VERSION} .
	docker tag ${DOCKER_IMAGE}:${VERSION} ${DOCKER_IMAGE}:latest

.PHONY: docker-run
docker-run: ## Run Docker container
	docker run -it --rm \
		-e GITHUB_PAT \
		-e GITHUB_API_ENDPOINT \
		-e GITHUB_ORG \
		-e GITLAB_PAT \
		-e GITLAB_API_ENDPOINT \
		-e GITLAB_USERNAME \
		-e GITLAB_HOST \
		-e AWS_ACCESS_KEY_ID \
		-e AWS_SECRET_ACCESS_KEY \
		-e AWS_REGION \
		-e AWS_BUCKET \
		${DOCKER_IMAGE}:latest

.PHONY: docker-compose
docker-compose: ## Run with Docker Compose
	docker compose up

.PHONY: dev
dev: deps ## Set up development environment
	@if ! command -v golangci-lint >/dev/null 2>&1; then \
		echo "Installing golangci-lint..."; \
		brew install golangci-lint; \
	fi
	@if ! command -v gh >/dev/null 2>&1; then \
		echo "Installing GitHub CLI..."; \
		brew install gh; \
	fi

.PHONY: release
release: build-all ## Create a new release
	@if [ -z "$(TAG)" ]; then \
		echo "Please provide a tag version: make release TAG=v1.0.0"; \
		exit 1; \
	fi
	git tag $(TAG)
	git push origin $(TAG)

.PHONY: export-ghec
export-ghec:
	go run main.go export-ghec \
		--org mouismail-avocado \
		--repos gitlab-to-proxima-via-actions \
		--lock-repos=false \
		--exclude-git=false \
		--exclude-releases=false \
		--exclude-metadata=false \
		--output migration-archive.tar.gz


# To be replaced with the actual migration command values
.PHONY: run-migration
run-migration:
	go run main.go migrate \
	  --migration-source-id MS_kgDaACQ3OTkzMjVlMy00OTk0LTQ5MDUtODA4Yy1kMzYxNmYyZjVkMTg \
		--org-owner-id O_kgDOAAY63g \
		--source-repo https://gitlab.expert-services.io/gitlab-migration-test/extras \
		--archive-url "https://mouismail-migration.s3.amazonaws.com/02c1eec8-edeb-11ef-96ac-617af503125-extras.tar.gz?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIA54DSAGEZE5Z2SJHT%2F20250219%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20250219T102800Z&X-Amz-Expires=5400&X-Amz-SignedHeaders=host&X-Amz-Signature=678fab969ec797c0a41922a69b4a834a187eb5e8d8ec7fc459f7448fdc162eff" \
		--repo-name 02c1eec8-edeb-11ef-96ac-617af503125a-extras
