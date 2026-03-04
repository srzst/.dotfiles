#!/bin/bash

# chmod +x launch_agents_reload.sh
# LaunchAgents 언로드
launchctl unload ~/Library/LaunchAgents/com.user.clip_history.plist
launchctl unload ~/Library/LaunchAgents/com.user.url_changer.plist

# LaunchAgents 로드
launchctl load ~/Library/LaunchAgents/com.user.url_changer.plist
launchctl load ~/Library/LaunchAgents/com.user.clip_history.plist
