# Signal Protocol over Nostr | NIP DRAFT

```
  NIP: undefined
  Title: Signal Protocol over Nostr
  Author: Keychat Developer
  Status: Draft
  Type: TBD
  Created: 2025-11-06
  License: CC0-1.0
```



## Introduction

### Abstract

This NIP proposes an implementation scheme standard for the double ratchet algorithm (Signal Protocol) over Nostr clients.

### Motivation

This proposal aims to introduce Signal Protocol into the Nostr network, which allows Nostr clients to have end-to-end encryption for private communications with forward secrecy and post-compromise security. Specifically, the address-refreshing technique is used to minimize tracking and avoid social engineering.

### Dependencies

This spec needs NIP-17 implementation in advance.

## Description

### Signal Protocol Introduction

The Signal Protocol is a set of cryptographic specifications that provides end-to-end encryption for private communications. 

#### Algorithms

- X3DH
- Double Ratchet

### Design 

#### Architecture

The private conversation is between Sender (Alice) and Recipient (Bob), while all communications are routed through the Nostr relays, so there is no direct connection between them. 

#### Work Flow

1. Create identity

   Both Alice and Bob need to create a nostr account before starting a conversation, namely nsec & npub based on Secp256k1 elliptic curve using Schnnor algorithm.

2. Add contact(create a session)

   Alice SHALL add Bob as a contact before messaging, i.e., they SHALL join the same session.  It's recommended that Alice and Bob ONLY share one live session at the same time. 

   1. Pubkey retrieval

      To begin with, Alice SHOULD know Bob's npub by public information or any alternative way. Instead of publishing the npub, Bob can share the one-time key with Alice which reduce tracking.

   2. Generate corresponding identity

      Alice randomly generates the key pairs for Bob. The key is independent of the nostr keys. 

   3. Add contact request

      Alice's identity info, along with the **ratchet algorithm initialization vector**, is encrypted by Bob's npub under NIP-17 spec. After that, Bob gets the complete info for the key exchange.

   4. Prekey message

      Before Bob confirms the request, Alice can send messages to Bob continuously based on NIP-17 protocol, e.g., the prekey message.

   5. Add contact confirmation

      When receiving the request, Bob replied with a certain fixed message to accept the request.  A session between Alice and Bob is established.

3. Private messaging

   Alice can send private messages to Bob if they share a live session, which indicates that they use the same ratchet algorithm initialization vector and each other's public keys.

   1. Key Derivation Function (KDF)

      According to Signal Protocol, the Key Derivation Function (KDF) provides the ratcheting mechanism. The first "ratchet" is applied to the symmetric root key, the second ratchet to the asymmetric Diffie Hellman (DH) key. 

      - When a message is sent or received, a symmetric-key ratchet step is applied to the sending or receiving chain to derive the message key.
      - When a new ratchet public key is received, a DH ratchet step is performed prior to the symmetric-key ratchet to replace the chain keys.

   2. Address refresh

      The original Signal protocol operates over a private network; when applied to Nostr, a public network, the privacy issue becomes more pronounced. Although the eavesdropper cannot decrypt the message's content, if the sender's (or recipient's) address remains unchanged, the eavesdropper can still analyze the identity and other information from the communication frequency, timing, etc.  Address refresh means Alice updates the receiving address when sending a new message. The new address is the DH ratchet's new pubkey. When the new address receives a message from Bob, Alice can ensure Bob receives the new address. Alice should listen to the old addresses for some time to avoid missing messages or delays. The address refresh strategy can be flexible, depending on the software operator.

   3. Encrypt message

      Alice encrypts the message using the chain key along with the signature. AES-256 is recommended as the encryption algorithm. CBC mode is the default setting but must be used with the HMAC to avoid bit flipping. 

   4. Decrypt message

      Bob checks the signature, if valid, decrypts the message using the corresponding chain key. When Bob needs to respond , the process is shown as "Encrypt message".

#### Concerns in public networks

Private communication in public networks operates in a more complex environment, including issues such as relay reliability, network analysis, eavesdropping, and sustainable incentive compatibility.

1. Relay reliability

   Although the relay nodes of the Nostr network have risks such as censorship and message discarding, as long as there is an honest node, confidential communication between Alice and Bob can be achieved.

2. Network analysis

   The random root address and address refresh mechanisms make network traffic analysis between the sending and receiving addresses as difficult as possible. However, network analysis based on behavioral patterns or IP addresses still exists.

3. Eavesdropping

   The double ratchet algorithm ensures the confidentiality of a single message and also ensures forward secrecy and post-compromise security.

4. Sustainable incentive compatibility

   Relays can collect fees for forwarding messages, ensuring the network's sustainability and preventing spam. In addition to paying fees outside the network, participants can also pay fees using Ecash, as detailed in the specification section.



## Specification

The following implementations are based on libsignal.rs.

### Database Design

The basic database includes IDENTITY, RATCHET_STATUS, SESSION_STATUS, OPPONENT_SIGNED_KEY, PRE_KEY.

`identity (`
        `id integer primary key AUTOINCREMENT,`
        `nextPrekeyId integer,`
        `registrationId integer,`
        `address text,`
        `privateKey text,`
        `publicKey text,`
`);`

`ratchet_status (`
    `id integer primary key AUTOINCREMENT,`
    `aliceRatchetKeyPublic text,`
    `address text,`
    `roomId integer,`
    `bobRatchetKeyPrivate text,`
    `ratcheKeyHash text,`
`);`

`session_status (`
    `id integer primary key AUTOINCREMENT,`
    `aliceSenderRatchetKey text,`
    `address text,`
    `record text,`
    `bobSenderRatchetKey text,`
    `bobAddress text,`
    `aliceAddresses text,`
`);`

`opponent_signed_key (`
    `id integer primary key AUTOINCREMENT,`
    `keyId integer,`
    `record text,`
    `used bool Not NULL DEFAULT false,`
`);`

`pre_key (`
    `id integer primary key AUTOINCREMENT,`
    `keyId integer,`
    `record text,`
    `used bool Not NULL DEFAULT false,`
`);`

### Create Identity

Signal identity is a key pair generated by a *pseudorandom number generator*. It's recommended to use a reliable PRNG; do not use any self-implementations. Alice's public key is the signal identity that will be shared with Bob, and the private key is used to sign the initial message.

### Add Contact

Alice's request, wrapped in NIP-17:

```
`ID: Hash`  
`Kind: 1059`
`From: Random Address`
`To: Bob's npub OR One-time address`
`Content: Request to start an encrypted chat...`
`Signature: Alice's signature`
```

Bob's response(if accepted), wrapped in Signal protocol:

```
`ID: Hash`  
`Kind: 4`
`From: Address of current chainkey`
`To: Alice's one-time address`
`Content: Hi, I'm Bob. Let's start an encrypted chat...`
`Signature: Bob's signature`
```

After that, Alice and Bob joined the same session and can start a private conversation.

```
`pub struct SignalSession {`
    `pub alice_sender_ratchet_key: Option<String>,`
    `pub address: String,`
    `pub bob_sender_ratchet_key: Option<String>,`
    `pub record: String,`
    `pub bob_address: Option<String>,`
    `pub alice_addresses: Option<String>,`
`}`
```

Before Bob responds, Alice can still send pre-key messages to Bob. The message encryption process is the same as the add contact request process, and will not be described in detail here. 

### Send Encrypted Messages

Alice sends messages to Bob's Signal address. The plain text is encrypted as shown:

```
cipher_text = message_encrypt(
            ptext.as_bytes(),
            &remote_address,
            &mut store.session_store,
            &mut store.identity_store,
            SystemTime::now(),
            is_prekey,
        )
```

The session key and the identity key are updated with every message. Bob's address is updated when Bob responds.

### Decrypt Received Messages

Bob listens to the addresses corresponding to the current session's pubkey shared with Alice and pulls the message from a relay (relays). 

    plain_text = message_decrypt_signal(
                &ciphertext,
                &remote_address,
                &mut store.session_store,
                &mut store.identity_store,
                &mut store.ratchet_key_store,
                room_id,
                &mut csprng,
            )

## Security Consideration

The secure communication system is designed to meet specific security goals under certain assumptions. Moreover, the complexity of Nostr systems introduces different threats and affects the security design philosophy.

### Security Assumption

The security of the entire system is based on the following assumptions: 

1. The primary security assumption is based on the **computational difficulty** of AES-256, which means that an adversary cannot break the encryption in any time frame relevant to real-world applications. 
2. The second security assumption is that at least one relay is honest and will deliver all messages between the commuters. However, the relays can analyze or even try to break down the encrypted information in the meantime.
3. The RNG provides enough randomness, thus no one can infer the session key.

### Security Goals

1. Confidentiality

   Confidentiality means the enemy can't obtain any information from the ciphertext. In practice, the key space needs to be large enough and should resist cryptoanalysis. At the same time, confidentiality is not only for the present moment, but also needs to provide maximum forward secrecy and backward security even if the key is leaked. In this spec, AES-256 is a reliable algorithm, and the double ratchet algorithm as a key update mechanism helps minimize the consequences of key leakage.

2. Integrity

   Integrity means the information should not be modified without authorization. This is usually implemented with HMAC, which can detect any data changes.

3. Authentication

   It is essential to verify the identity of the users you are talking to. Signature is a tool for authentication when Alice and Bob start a session. After that, all authentication is based on the KDF algorithm, which uses the double ratchet.

4. Non-repudiation

   It's hard to provide non-repudiation unless one participant retains all the messages since the session began. However, this is not the primary goal.

### Threat Model

It's important to identify the potential threats and vulnerabilities in the public network. Some are active attacks by the hacker; the rest are passive attacks carried out by relays.

1. Phishing Client
    Attackers can forge apps or inject malicious code into the source code. After a user downloads the app, the attacker can monitor the user's communications. To address this, app providers should strengthen verification of app installation package fingerprints and enhance user security education.
2. Message Forgery
    Relay can truncate messages. Furthermore, when using certain AES operating modes (such as CBC), based on the bit-flipping property of ciphertext, Relay can modify the ciphertext, thereby tampering with the plaintext. Therefore, all information must be verified for integrity using HMAC.
3. Denial of Service
    Relay can refuse service to certain users, failing to forward corresponding information and causing message congestion. The key refresh function ensures that communicators frequently change their addresses, avoiding targeted denial-of-service attacks.
4. Traffic Identification
    Despite address refresh, relays can still track one's communication habits based on IP addresses and message sending patterns, and combine this with social engineering techniques to increase the risk to them. In addition to using tools like TOR or VPNs for self-protection, communicators can also employ strategies such as switching relays to prevent a single relay from possessing complete information, or fetching non-personal encrypted messages locally to increase traffic obfuscation and reduce tracking.

## Reference

[1] The X3DH Key Agreement Protocol, https://signal.org/docs/specifications/x3dh/

[2] The Double Ratchet Algorithm, https://signal.org/docs/specifications/doubleratchet/

[3] Not in The Prophecies: Practical Attacks on Nostr, https://crypto-sec-n.github.io/

[4] libsignal in Rust, https://github.com/signalapp/libsignal

