.PHONY: all linux windows
GODOT := godot
PIP := pip
TMP_DIR := build
VERSION := 0.1

all: linux windows

linux:
	mkdir -p $(TMP_DIR)/linux/mod_editor; \
	$(GODOT) --headless --export-debug "Linux" $(TMP_DIR)/linux/mod_editor/mod_editor; \
	cp -r mod_editor/mod_editor_data  mod_editor/mod_editor_data.module mod_editor/user_config.module $(TMP_DIR)/linux/mod_editor; \
	cp -r mod_editor/mod_editor_linux.ini $(TMP_DIR)/$(TMP_DIR)/linux/mod_editor/mod_editor.ini; \
	rm -rf $(TMP_DIR)/linux/mod_editor/mod_editor_data/_SHADOW; \
	cd $(TMP_DIR)/linux; \
	zip -r mod_editor_$(VERSION)_linux.zip mod_editor

windows:
	mkdir -p $(TMP_DIR)/windows/mod_editor; \
	$(GODOT) --headless --export-debug "Windows Desktop" $(TMP_DIR)/windows/mod_editor/mod_editor.exe; \
	cp -r mod_editor/mod_editor_data  mod_editor/mod_editor_data.module mod_editor/user_config.module $(TMP_DIR)/windows/mod_editor; \
	cp -r mod_editor/mod_editor_windows.ini $(TMP_DIR)/windows/mod_editor/mod_editor.ini; \
	rm -rf $(TMP_DIR)/windows/mod_editor/mod_editor_data/_SHADOW; \
	cd $(TMP_DIR)/windows; \
	zip -r mod_editor_$(VERSION)_windows.zip mod_editor

