FROM debian:trixie
RUN apt-get update -qq && apt-get upgrade -qq && apt-get install -qq build-essential mmdebstrap bubblewrap devscripts squashfs-tools-ng zstd git sbuild
RUN useradd --create-home belenios
COPY --chown=belenios:belenios . /tmp/belenios
WORKDIR /tmp/belenios
RUN contrib/fedora/install-deps.sh
USER belenios
RUN contrib/fedora/setup-build-dir.sh /tmp/build
WORKDIR /tmp/build
RUN git config --global user.name "Belenios Builder"
RUN git config --global user.email "belenios.builder@example.org"
RUN git config --global --add safe.directory /tmp/belenios