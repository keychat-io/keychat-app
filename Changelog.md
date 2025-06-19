# Changelog
https://keepachangelog.com/zh-CN/1.1.0
git log -n 5 --pretty=format:"%h - %s (%ci)"

## 1.33.1+6390
1. Add blossom servers to upload encrypted meida
2. Remove aws lib
3. Update flutter_rust_bridge to 2.10.0

## 1.32.10+6388
1. [Browser]Add config for auto_sign_event
2. Fix other bugs

## 1.32.9+6387
1. Fix: set fee field for 1 sat
2. Add `ignoreSafeArea: false` for bottomSheet
3. Fix other bugs


## 1.32.8+6386
1. Fix: mint 32 sat for chat
2. Fix: pull to load more data in chat page
3. Implement nip44 encrypt and decrypt in browser
4. Init the notify service when created account
5. Remove refresh() when load room list. Solution to Stroboscopic Issues
6. Update flutter version to 3.32.2
7. Cache a copy of the remote configuration to prevent HTTP request failures.

## 1.32.6+6383
- [Ecash] Updated Keychat_rust_ffi library.
- [Ecash] Added mint information page.
- [Ecash] Added fee for Ecash billing.
- [Browser] Enabled viewing of image URLs in WebView.
- [Browser] Enabled PDF viewing on desktop.
- Redesign the login page.

## 1.32.5+6382
[Ecash] Supports paid mint servers

## 1.32.4+6380
- [Browser] Optimize keepAlive; update desktop version styling; Zoom text;
- [Desktop] Opening folders in Finder.
- [Media] Ensure uploaded and downloaded files retain their original filenames.
- [Ecash] Fix: Restore ecash from mint server.
- [Ecash] Fix: Double click to receive token.
- [Ecash] Style of red pocket
- [App Settings] Add `Startup Tab` setting Options
- Update the app description text.
- Cache MLS PK event data to reduce the number of signature requests.
- Update NDK version to 29.0.13113456
- Update flutter verstion to 3.29.3

## 1.31.12+6368
- [browser] Save the status of the tab unless it is closed manually
- [browser] Remove btcnav.org from mini app
- [message] Automatically refresh the homepage when a new message is added
- [desktop] Support packaging exe for windows platform. Optimize cmd+shift line break operation
- other bugs fix

## 1.31.1+6353
1. Fix bugs in MLS Group
2. Support desktop layout
3. Desktop: Support pasting images and files into input fields

## 1.30.3+6339
1. Upgrade mls group, compatible with NIP104.
2. Change websocket lib to `web_socket_client`
3. Code Style

## 1.29.1+6331
1. Delete the kdf and shared-key group rooms.
2. Integrated with NIP-47(Nostr wallet connect).
3. Optimize app startup speed.
4. Upgrade `rust-nostr` library to version 0.39.

## 1.27.2+6328
1. Add a SafeArea to the browser page to prevent the bottom input area from being hidden.
2. Display a dialog showing the relay status when a message fails to send.
3. Change the color of Cashu's buttons.


## 1.27.2+6326
1. change lib flutter_markdown to markdown_widget
2. forward message page: switch identiy to show rooms
3. add query logic then upload mls keys

## 1.27.1+6325
1. Support for logging in or importing accounts using amberapp
2. Support for amber's signMessage, signEvent, nip04, and nip44
3. Refactored routing for the room settings page
4. Browser support for sharing URLs to rooms

## 1.26.8+6322
1. Fix: receive cashuB failed when amount is not (1,2,4,8...)
2. Add scan button for cashuPage
3. Remove pubkeys from listening when disable chat identity
4. Fix typo error

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