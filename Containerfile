FROM fedora:latest

# Set metadata
LABEL name="claude-desktop-fedora-builder" \
      version="1.0" \
      description="Container for building Claude Desktop RPM packages for Fedora"

# Install system dependencies
RUN dnf update -y && \
    dnf install -y \
        sqlite3 \
        p7zip-plugins \
        wget \
        curl \
        icoutils \
        ImageMagick \
        nodejs \
        npm \
        rpm \
        rpm-build \
        rpmdevtools \
        git \
        which \
        findutils \
        grep \
        sed \
        tar \
        gzip \
        make \
    && dnf clean all

# Install global npm packages
RUN npm install -g electron asar

# Create working directory
WORKDIR /workspace

# Create output directory
RUN mkdir -p /output

# Set environment variable to indicate container environment
ENV CONTAINER=podman

# Add the build script
ADD build-fedora.sh /workspace/
RUN chmod +x /workspace/build-fedora.sh

# Create a non-root user for building
RUN useradd -m -u 1000 builder && \
    chown -R builder:builder /workspace /output

# Switch to non-root user
USER builder

# Set the default command
CMD ["./build-fedora.sh"] 