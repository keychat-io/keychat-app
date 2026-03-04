# File Encryption/Decryption Architecture

## Overview

Keychat uses an **encrypt-before-upload** approach for all file sharing. Files are encrypted locally using **AES-256-CTR** (no padding) before being uploaded to a media server. The encryption key, IV, and file hash are embedded in the shared URL as query parameters, so the recipient can download and decrypt the file without the server ever seeing plaintext content.

## Data Structures

### `FileEncryptInfo`

Runtime-only object returned by the encryption process. It holds the encrypted bytes and all metadata needed for upload and URL construction.

**Source**: `packages/app/lib/service/file.service.dart`

| Field        | Type         | Description                                        |
| ------------ | ------------ | -------------------------------------------------- |
| `key`        | `String`     | Base64-encoded AES-256 key                         |
| `iv`         | `String`     | Base64-encoded 16-byte IV                          |
| `output`     | `Uint8List`  | Encrypted file bytes (in memory)                   |
| `suffix`     | `String`     | Original file extension (e.g. `png`, `mp4`)        |
| `hash`       | `String`     | SHA-256 hash of the encrypted bytes                |
| `sourceName` | `String`     | Original filename                                  |
| `ecashToken` | `String?`    | Cashu ecash token used to pay for relay upload      |
| `url`        | `String?`    | Remote URL after successful upload                 |
| `size`       | `int`        | Size of encrypted bytes (in bytes)                 |

### `MsgFileInfo`

Persistent file metadata stored in the database as an Isar `@embedded` object. Serialized to JSON and saved in `Message.realMessage`. This is what the UI reads to display file messages and to drive download/decrypt.

**Source**: `packages/app/lib/models/embedded/msg_file_info.dart`

| Field        | Type          | Description                                                |
| ------------ | ------------- | ---------------------------------------------------------- |
| `localPath`  | `String?`     | Relative path in app folder (prefix stripped for portability) |
| `url`        | `String?`     | Remote file URL                                            |
| `status`     | `FileStatus`  | Current lifecycle state                                    |
| `type`       | `String?`     | MIME type hint                                             |
| `suffix`     | `String?`     | File extension                                             |
| `size`       | `int`         | File size in bytes                                         |
| `updateAt`   | `DateTime?`   | Last status update timestamp                               |
| `iv`         | `String?`     | Base64-encoded IV for decryption                           |
| `key`        | `String?`     | Base64-encoded AES key for decryption                      |
| `ecashToken` | `String?`     | Cashu ecash token (relay upload path only)                 |
| `hash`       | `String?`     | SHA-256 hash of encrypted bytes for integrity verification |
| `sourceName` | `String?`     | Original filename                                          |
| `fileInfo`   | `FileEncryptInfo?` | Transient; not persisted (`@ignore`)                  |

### `FileStatus` Enum

Lifecycle states for a file message:

```
init ──► downloading ──► decryptSuccess
                    └──► failed
```

| Value            | Description                                      |
| ---------------- | ------------------------------------------------ |
| `init`           | File metadata parsed, download not started        |
| `downloading`    | Download in progress                             |
| `decryptSuccess` | File downloaded, hash verified, and decrypted     |
| `failed`         | Download or decryption failed                    |

> `downloaded` is deprecated in favor of `decryptSuccess`.

### `MessageMediaType` (File-Related Values)

| Value   | Description         |
| ------- | ------------------- |
| `image` | Image files         |
| `video` | Video files         |
| `file`  | Generic files       |

> `pdf` is deprecated in favor of `file`.

## Encryption Parameters

| Parameter    | Value / Method                                              |
| ------------ | ----------------------------------------------------------- |
| Algorithm    | AES-256                                                     |
| Mode         | CTR (Counter mode)                                          |
| Padding      | None (`padding: null`)                                      |
| Key          | `Key.fromUtf8(Random(16).nextInt(10).toString()).stretch(32, salt: salt)` — PBKDF2 stretch of a single random digit to 32 bytes |
| Salt         | 16 random bytes from `SecureRandom(16)`                     |
| IV           | 16 random bytes from `IV.fromSecureRandom(16)`              |
| Hash         | SHA-256 of the **encrypted** bytes, computed via Rust FFI (`rust_nostr.sha256HashBytes`) |

Key derivation detail (from `encryptFile`):

```dart
final iv = IV.fromSecureRandom(16);
final salt = SecureRandom(16).bytes;
final key = Key.fromUtf8(
  Random(16).nextInt(10).toString(),
).stretch(32, salt: salt);
final encrypter = Encrypter(AES(key, mode: AESMode.ctr, padding: null));
```

Decryption uses the stored Base64 key and IV directly:

```dart
final encrypter = Encrypter(AES(Key.fromBase64(key), mode: AESMode.ctr, padding: null));
final decryptedBytes = encrypter.decryptBytes(encryptedBytes, iv: IV.fromBase64(iv));
```

## Workflows

### Send File Flow

```
User picks file (FilePicker / ImagePicker / Camera)
        │
        ▼
Optional: compress image (JPEG quality 70, strip EXIF)
         or compress video (VideoCompress)
        │
        ▼
Save working copy to room folder
        │
        ▼
encryptFile()
  ├── Generate random key (PBKDF2-stretched to 32 bytes)
  ├── Generate random IV (16 bytes)
  ├── AES-256-CTR encrypt file bytes
  └── SHA-256 hash encrypted bytes (via Rust FFI)
        │
        ▼
Upload encrypted bytes to media server
  ├── Relay path: pay with ecash → get S3 presigned URL → PUT to AWS S3
  └── Blossom path: sign NIP kind-24242 auth event → PUT to blossom server
        │
        ▼
Build sharing URL with query params (key, iv, hash, suffix, size, sourceName)
        │
        ▼
MsgFileInfo created with status = decryptSuccess
        │
        ▼
Send URL as message content via Nostr (Signal/MLS encrypted)
```

**Entry points**:
- `handleFileUpload()` — generic file picker
- `handleSendMediaFile()` — orchestrates encrypt + upload + send
- `encryptToSendFile()` — encrypt + upload, returns `MsgFileInfo`
- `encryptAndUploadImage()` — avatar/image upload variant

### Receive File Flow

```
Receive Nostr message containing file URL
        │
        ▼
Parse URL → extract query params into MsgFileInfo
  (key, iv, suffix, hash, size, sourceName, kctype)
        │
        ▼
MsgFileInfo.status = init (stored in Message.realMessage)
        │
        ▼
User taps to download → downloadForMessage()
        │
        ▼
MsgFileInfo.status = downloading
        │
        ▼
Download encrypted file to temp directory (Dio)
        │
        ▼
If file already exists locally:
  ├── Compare SHA-256 hash
  ├── Match → skip download, use existing file
  └── Mismatch → re-download with new filename
        │
        ▼
Decrypt file → save to room folder
        │
        ▼
MsgFileInfo.status = decryptSuccess
MsgFileInfo.localPath = relative path
        │
        ▼
If video: generate thumbnail (VideoCompress)
        │
        ▼
Update message in DB and refresh UI
```

**On failure**: `MsgFileInfo.status = failed`, error logged.

## URL Format

File URLs carry all decryption parameters as query strings. The URL itself is sent as the message content (encrypted end-to-end via Signal/MLS protocol).

**Structure**:

```
https://{server_host}/{file_path}?kctype={type}&suffix={ext}&key={base64_key}&iv={base64_iv}&size={bytes}&hash={sha256}&sourceName={original_filename}
```

**Example**:

```
https://s3.keychat.io/s3.keychat.io/cS49k27IJoAyw3z0yXILIW_eI6_aYU7sbWbSn0PCYw8?kctype=image&suffix=png&key=vGUmQ0jnct7j%2BKgM2XXnvRyWOzBG0PsDlMo%2FbAiaWvM%3D&iv=diVdEf3QX4akMfRsqVeQBQ%3D%3D&size=6048&hash=cS49k27IJoAyw3z0yXILIW%2FeI6%2FaYU7sbWbSn0PCYw8%3D&sourceName=1758092675587_i4z8ci5q3yhb2o47.png
```

| Param        | Description                                         |
| ------------ | --------------------------------------------------- |
| `kctype`     | Media type: `image`, `video`, or `file`             |
| `suffix`     | File extension without dot (e.g. `png`, `mp4`)      |
| `key`        | URL-encoded Base64 AES-256 key                      |
| `iv`         | URL-encoded Base64 16-byte IV                       |
| `size`       | Encrypted file size in bytes                        |
| `hash`       | URL-encoded SHA-256 hash of encrypted bytes         |
| `sourceName` | Original filename for display                       |

Built by `MsgFileInfo.getUriString(type)` using `Uri.https()`.

## Upload Backends

### Relay/S3 Path (default)

Used when the selected media server host is `relay.keychat.io`.

1. Encrypt file locally (`encryptFile` with `base64Hash: true`)
2. Obtain a Cashu ecash token for the upload fee (`getFileUploadEcashToken`)
3. Request upload parameters from the relay API: `POST {defaultFileServer}/api/v1/object` with `{cashu, length, sha256}`
4. Relay returns a presigned S3 URL and headers
5. `PUT` encrypted bytes to the presigned URL
6. Relay returns the public access URL

**Source**: `packages/app/lib/service/s3.dart` (`AwsS3.encryptAndUploadByRelay`)

### Blossom Server Path

Used when a custom blossom media server is configured.

1. Encrypt file locally (`encryptFile`)
2. Generate a throwaway secp256k1 key pair (via Rust FFI)
3. Sign a NIP kind-24242 event with tags: `["t", "upload"]`, `["x", hash]`, `["expiration", ...]`
4. `PUT` encrypted bytes to `{server}/upload` with `Authorization: Nostr {base64_event}`
5. Server returns `{url, size}` in the response body

**Source**: `packages/app/lib/service/file.service.dart` (`uploadToBlossom`)

## File Storage

### Local Path Structure

```
{appFolder}/file/{identityId}/{roomId}/{mediaType}/
```

- `{appFolder}` — platform app documents directory (`Utils.appFolder`)
- `file` — constant base path (`KeychatGlobal.baseFilePath`)
- `{identityId}` — numeric identity ID
- `{roomId}` — numeric room/chat ID
- `{mediaType}` — `image/`, `video/`, or `file/`

Example:

```
/data/user/0/com.keychat.io/app_flutter/file/1/42/image/photo_2025.png
```

The `localPath` stored in `MsgFileInfo` is a **relative path** with the `appFolder` prefix stripped, so the app can reconstruct the absolute path after reinstall or migration:

```dart
// Store:
mfi.localPath = newFile.path.replaceFirst(Utils.appFolder.path, '');

// Restore:
absolutePath = Utils.appFolder.path + mfi.localPath;
```

### Other Storage Locations

| Path                         | Purpose                         |
| ---------------------------- | ------------------------------- |
| `{appFolder}/avatars/`       | Contact and identity avatars    |
| `{appFolder}/browserCache/`  | Web browser cache               |
| `{appFolder}/errors/`        | Error logs                      |
| System temp directory        | Temporary encrypted downloads   |

## Key Source Files

| File | Purpose |
| ---- | ------- |
| `packages/app/lib/service/file.service.dart` | Core encryption, decryption, upload, download logic |
| `packages/app/lib/models/embedded/msg_file_info.dart` | `MsgFileInfo` model and `FileStatus` enum |
| `packages/app/lib/service/s3.dart` | AWS S3 upload via relay with ecash payment |
| `packages/app/lib/global.dart` | Constants: `baseFilePath`, `defaultFileServer` |
| `packages/app/lib/utils.dart` | `Utils.appFolder`, `Utils.avatarsFolder` |
| `packages/app/lib/models/message.dart` | `MessageMediaType` enum |
