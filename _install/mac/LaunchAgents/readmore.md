대상 스크립트 파일 권한 부여

```
chmod +x /Users/xx/script/py_script/clip_history/파일.py
```

```
launchctl load ~/Library/LaunchAgents/com.user.clip_history.plist
```

직접 등록한 데몬 만 확인

```
launchctl list | grep com.user
```

특정 데몬 확인

```
launchctl list | grep com.user.clip_history
```

특정 데몬 종료

```
sudo launchctl bootout gui/$(id -u)/com.user.clip_history
```

서비스 일괄 unload 후 load
아래 스크립트를 Terminal에서 실행한다.
`~/Library/LaunchAgents` 디렉토리에 있는 com.user.로 시작하는 .plist 파일을 대상으로 unload(비활성화) 후 다시 load(활성화)하여 변경사항을 적용합니다.

결과: ![](https://share.1tz.in/2024/01/240101_014731.png)

```
launchctl list | grep com.user
launchctl list | grep 'com\.user\..\*'

launchctl unload ~/Library/LaunchAgents/com.user.clip_history.plist
launchctl unload ~/Library/LaunchAgents/com.user.url_changer.plist


launchctl load ~/Library/LaunchAgents/com.user.url_changer.plist
launchctl load ~/Library/LaunchAgents/com.user.clip_history.plist

launchctl start com.user.url_changer
launchctl start com.user.clip_history
```
