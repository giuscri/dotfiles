GROUP := $(shell id -gn $(USER))
DEST_BIN := /usr/local/bin
LOG_DIR := /var/log/com.github.giuscri.dotfiles
CONFIG_DIR := ~/Library/Application\ Support/com.github.giuscri.dotfiles
SERVICE_DIR := ~/Library/LaunchAgents

.PHONY: install directories services script config clean

install: directories services script config

directories:
	@if [ "$$(id -u)" = "0" ]; then \
		echo "Do not run as root!"; \
		exit 1; \
	fi
	mkdir -p $(CONFIG_DIR)
	sudo mkdir -p $(LOG_DIR)
	sudo chown -R $(USER):$(GROUP) $(LOG_DIR)
	touch $(LOG_DIR)/stdout.log
	touch $(LOG_DIR)/stderr.log

services:
	install -m 644 ./service.plist $(SERVICE_DIR)/com.github.giuscri.dotfiles.plist
	launchctl load $(SERVICE_DIR)/com.github.giuscri.dotfiles.plist

script:
	sudo install -m 755 ./sync.sh $(DEST_BIN)/sync.sh
	sudo chown -R $(USER):$(GROUP) $(DEST_BIN)/sync.sh
	sudo install -m 755 ./Dotfiles $(DEST_BIN)/Dotfiles
	sudo chown -R $(USER):$(GROUP) $(DEST_BIN)/Dotfiles

config:
	install -m 644 ./config.yaml $(CONFIG_DIR)/config.yaml

clean:
	launchctl unload $(SERVICE_DIR)/com.github.giuscri.dotfiles.plist
	sudo rm -rf $(LOG_DIR)
	rm -rf $(CONFIG_DIR)
	sudo rm -f $(DEST_BIN)/sync.sh $(DEST_BIN)/Dotfiles
