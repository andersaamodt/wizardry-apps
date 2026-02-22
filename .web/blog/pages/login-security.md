---
title: Nostr, Passkeys, and SSH Linking
---

This page explains how login works on this site, in plain language.

## Quick Summary

- Primary identity is your **Nostr key**.
- You can sign in every time with Nostr, or bind a **passkey** (WebAuthn) for convenience.
- You can optionally link an **SSH public key** for MUD/terminal compatibility.
- You should **never** upload your SSH private key.

## What Is an SSH Key Pair?

An SSH key pair has two parts:

- **Private key**: Secret. Stays on your device.
- **Public key**: Safe to share. Usually ends in `.pub`.

When this site asks for an SSH key, it only wants the **public key**.

## Why SSH Is Optional Here

SSH linking is optional and exists for MUD/player workflows that still rely on SSH key auth.

## What Is a Passkey (WebAuthn)?

A passkey is a modern login credential stored in your device/browser ecosystem (often protected by Face ID, Touch ID, PIN, or hardware key support).

- It is phishing-resistant.
- It avoids password reuse.
- It can work with security key hardware and platform authenticators.

## How Login Works Here

1. New user: sign a Nostr login challenge.
2. Optionally bind a passkey in Account settings.
3. Next sign-ins: use Nostr or passkey.
4. Optional: link an SSH public key for MUD flows.

## Safety Notes

- Never paste private key material into web forms.
- If you generate an SSH key in Account settings, keep the downloaded private key safe.
- Only submit your `.pub` key string when linking SSH.

## How to Create an SSH Key Pair (If Needed)

```sh
ssh-keygen -t ed25519 -C "your-name@your-device"
```

Your public key is then typically at:

```sh
~/.ssh/id_ed25519.pub
```

Use that `.pub` content when linking SSH in Account settings.
