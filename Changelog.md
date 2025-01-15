# Changelog

https://keepachangelog.com/zh-CN/1.1.0

git log -n 5 --pretty=format:"%h - %s (%ci)"


## 1.26.1+6313
1. Redesign the Browser section, focusing on user bookmarks, and change the recommendation to an AppStore section.
2. The login page supports Recover operations, and supports importing from configuration files, mnemonic phrases, and private keys.
3. Optimize the display of group avatar names.
4. When choosing to log in to a third-party website with an account, you can choose to create a new account.
5. Optimize the Android packaging process.
6. Fix: the back button moving when the keyboard is invoked in browser page.
7. Fix other bugs.

## 1.25.2+6304
1. Feat: support inapp browser, login an nostr website
2. Browser: If the user has logged into a website, the more menu will support the disConnect operation
3. Browser: After entering a sub-link, iOS users will see a floating button that, when clicked, executes goBack
4. Browser: fix unexpectedly pops up the select user function
5. Video: fixed the issue where video preview images were not displayed
6. Video: compressed videos
7. Refactored the "me" page
8. Added enableChat and enableBrowser switches to Identity
9. Checked the latest version number from the cloud and prompted users to update with a red dot
10. Local notification: When the user is not in the room or on the home page, if a new message is received, a message notification will be displayed, and clicking it will enter the room.
11. Image: remove EXIF info