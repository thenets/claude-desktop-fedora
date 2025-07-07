# Claude Desktop Fedora Builder
# Makefile for containerized build process

# Variables
CONTAINER_NAME = claude-desktop-fedora-builder
IMAGE_NAME = claude-builder
OUTPUT_DIR = $(PWD)/output
BUILD_DIR = $(PWD)/build

# Default target
.PHONY: help
help: ## Show this help message
	@echo "Claude Desktop Fedora Builder"
	@echo "============================="
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Output will be in: $(OUTPUT_DIR)"

.PHONY: container-image
container-image: ## Build the container image
	@echo "🐳 Building container image..."
	podman build -t $(IMAGE_NAME) -f Containerfile .
	@echo "✅ Container image built successfully"

.PHONY: build
build: container-image build setup-dirs ## Build Claude Desktop RPM package
	@echo "🚀 Starting Claude Desktop build process..."
	@# Ensure proper permissions on directories
	@chmod 755 $(BUILD_DIR) 2>/dev/null || true
	@chmod 755 $(OUTPUT_DIR) 2>/dev/null || true
	podman run --rm -it --replace \
		--name $(CONTAINER_NAME) \
		-v $(OUTPUT_DIR):/output:Z \
		-v $(BUILD_DIR):/workspace/build:Z \
		--userns=keep-id \
		$(IMAGE_NAME)
	@echo "📦 Build complete! Check $(OUTPUT_DIR) for RPM files"
	@echo "🔍 Checking the last created rpm file..."
	rpm -qip $(shell ls -t output/*.rpm | head -1)
	ls -hlas output/

.PHONY: build-interactive
build-interactive: build setup-dirs ## Run container interactively for debugging
	@echo "🔧 Starting interactive container session..."
	podman run --rm -it --replace \
		--name $(CONTAINER_NAME)-debug \
		-v $(OUTPUT_DIR):/output:Z \
		-v $(BUILD_DIR):/workspace/build:Z \
		--userns=keep-id \
		--entrypoint /bin/bash \
		$(IMAGE_NAME)

.PHONY: setup-dirs
setup-dirs: ## Create necessary output directories
	@mkdir -p $(OUTPUT_DIR)
	@mkdir -p $(BUILD_DIR)
	@echo "📁 Created output directories"

.PHONY: clean
clean: ## Clean up containers and build artifacts
	@echo "🧹 Cleaning up..."
	-podman stop $(CONTAINER_NAME) 2>/dev/null || true
	-podman rm $(CONTAINER_NAME) 2>/dev/null || true
	-podman stop $(CONTAINER_NAME)-debug 2>/dev/null || true
	-podman rm $(CONTAINER_NAME)-debug 2>/dev/null || true
	@echo "✅ Cleanup complete"

.PHONY: clean-all
clean-all: clean ## Clean everything including images and build output
	@echo "🗑️  Removing container image and build output..."
	-podman rmi $(IMAGE_NAME) 2>/dev/null || true
	-rm -rf $(BUILD_DIR) 2>/dev/null || true
	@echo "✅ Deep cleanup complete"

.PHONY: logs
logs: ## Show logs from the last container run
	podman logs $(CONTAINER_NAME) 2>/dev/null || echo "No container logs found"

.PHONY: status
status: ## Show container and image status
	@echo "📊 Container Status:"
	@echo "==================="
	@echo "Images:"
	@podman images | grep -E "(REPOSITORY|$(IMAGE_NAME))" || echo "No images found"
	@echo ""
	@echo "Running containers:"
	@podman ps | grep -E "(CONTAINER|$(CONTAINER_NAME))" || echo "No running containers"
	@echo ""
	@echo "Build output:"
	@ls -la $(OUTPUT_DIR) 2>/dev/null || echo "Output directory not found: $(OUTPUT_DIR)"

.PHONY: install-rpm
install-rpm: ## Install the built RPM package (requires sudo)
	@if [ ! -d "$(OUTPUT_DIR)" ]; then \
		echo "❌ Output directory not found. Run 'make run' first."; \
		exit 1; \
	fi
	@RPM_FILE=$$(find $(OUTPUT_DIR) -name "claude-desktop-*.rpm" | head -1); \
	if [ -z "$$RPM_FILE" ]; then \
		echo "❌ No RPM file found in $(OUTPUT_DIR)"; \
		echo "Run 'make run' to build the package first"; \
		exit 1; \
	fi; \
	echo "📦 Installing RPM: $$RPM_FILE"; \
	sudo dnf install -y "$$RPM_FILE"

.PHONY: install-distrobox
install-distrobox: DISTROBOX=claude
install-distrobox: ## Install RPM in distrobox container (use: make install-distrobox DISTROBOX=container-name)
	@if [ ! -d "$(OUTPUT_DIR)" ]; then \
		echo "❌ Output directory not found. Run 'make build' first."; \
		exit 1; \
	fi
	@if [ -z "$(DISTROBOX)" ]; then \
		echo "❌ DISTROBOX variable not set. Usage: make install-distrobox DISTROBOX=container-name"; \
		echo ""; \
		echo "Available distroboxes:"; \
		distrobox list 2>/dev/null || echo "No distroboxes found or distrobox not installed"; \
		exit 1; \
	fi
	@which distrobox > /dev/null || (echo "❌ Distrobox not found. Please install distrobox first." && exit 1)
	@RPM_FILE=$$(find $(OUTPUT_DIR) -name "claude-desktop-*.rpm" | head -1); \
	if [ -z "$$RPM_FILE" ]; then \
		echo "❌ No RPM file found in $(OUTPUT_DIR)"; \
		echo "Run 'make build' to build the package first"; \
		exit 1; \
	fi; \
	echo "📦 Installing RPM in distrobox '$(DISTROBOX)': $$RPM_FILE"; \
	distrobox enter $(DISTROBOX) -- sudo dnf reinstall -y "$$RPM_FILE" || distrobox enter $(DISTROBOX) -- sudo dnf install -y "$$RPM_FILE"

# Development targets
.PHONY: dev-build
dev-build: ## Quick development build (no cache)
	@echo "🛠️  Development build (no cache)..."
	podman build --no-cache -t $(IMAGE_NAME) -f Containerfile .

.PHONY: shell
shell: build setup-dirs ## Get a shell in the container for debugging
	@echo "🐚 Opening shell in container..."
	podman run --rm -it \
		--name $(CONTAINER_NAME)-shell \
		-v $(OUTPUT_DIR):/output:Z \
		-v $(BUILD_DIR):/workspace/build:Z \
		--userns=keep-id \
		--entrypoint /bin/bash \
		$(IMAGE_NAME)

# Check if podman is available
.PHONY: check-podman
check-podman:
	@which podman > /dev/null || (echo "❌ Podman not found. Please install podman first." && exit 1)
