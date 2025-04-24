FROM ghcr.io/linuxserver/baseimage-kasmvnc:ubuntunoble-version-bb17071a@sha256:3b192c896ca11b914300f78472cb830ff358a64301399301b1e3c4916dd1490b

# set version label
ARG BUILD_DATE
ARG VERSION
LABEL build_version="Metatrader Docker:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="gmartin"

ENV TITLE=Metatrader5
ENV WINEPREFIX="/config/.wine"

# Update package lists and upgrade packages
USER root
RUN apt-get update && apt-get upgrade -y

# Install required packages
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3-venv python3-full python3-pip python3-xdg \
    wine64 xvfb x11-utils \
    wget \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Add WineHQ repository key and APT source
RUN wget -q https://dl.winehq.org/wine-builds/winehq.key \
    && apt-key add winehq.key \
    && add-apt-repository 'deb https://dl.winehq.org/wine-builds/debian/ bullseye main' \
    && rm winehq.key

# Add i386 architecture and update package lists
RUN dpkg --add-architecture i386 \
    && apt-get update

# Install WineHQ stable package and dependencies
RUN apt-get install --install-recommends -y \
    winehq-stable \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create & chown /config cache so Openbox can write
RUN mkdir -p /config/.cache/openbox/sessions \
    && chown -R 1000:1000 /config

# Build & install Python app into a venv
WORKDIR /opt/app
RUN python3 -m venv .venv \
    && . .venv/bin/activate \
    && pip install --upgrade pip \
    && deactivate

COPY /Metatrader /Metatrader
RUN chmod +x /Metatrader/start.sh
COPY /root /
COPY --chown=1000:1000 . /opt/app

# Switch to the unprivileged user
USER 1000
ENV PATH="/opt/app/.venv/bin:${PATH}"

EXPOSE 3000 8001
VOLUME /config

CMD ["mt5linux", "--host", "0.0.0.0", "--port", "8001"]
