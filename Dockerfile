FROM ubuntu:latest

COPY mw5-mods.sh /usr/local/bin/mw5-mods.sh

RUN apt-get update && \
	apt-get -y install \
		jq \
		p7zip \
		rsync \
		shellcheck \
		unrar \
		unzip \
	&& \
	apt-get -y autoclean && \
	apt-get -y clean && \
	rm -rf /var/cache/apt

VOLUME [ "/opt/mw5", "/opt/downloads" ]

ENTRYPOINT [ "/usr/local/bin/mw5-mods.sh", "/opt/mw5", "/opt/downloads" ]
