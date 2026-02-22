---
title: SSH Keys and Passkey Login
---

This page explains how login works on this site, in plain language.

## Quick Summary

- This site signs you in with a **passkey** (WebAuthn).
- For first-time setup, you also register your **SSH public key**.
- You should **never** paste or upload your SSH private key.

## What Is an SSH Key Pair?

An SSH key pair has two parts:

- **Private key**: Secret. Stays on your device.
- **Public key**: Safe to share. Usually ends in `.pub`.

When this site asks for an SSH key, it only wants the **public key**.

## Why This Site Uses SSH Public Keys

Your SSH public key is used as your identity anchor.  
It helps connect your account to your MUD/player identity model without requiring passwords.

## What Is a Passkey (WebAuthn)?

A passkey is a modern login credential stored in your device/browser ecosystem (often protected by Face ID, Touch ID, PIN, or hardware key support).

- It is phishing-resistant.
- It avoids password reuse.
- It can work with security key hardware and platform authenticators.

## How Login Works Here

1. New user: register SSH **public** key.
2. Create/bind passkey in the browser.
3. Next sign-ins: use passkey directly.

## Safety Notes

- Do not drop files like `id_rsa`, `id_ed25519`, or any private key file.
- If you accidentally drop a private key into the form, the browser checks locally and rejects it.
- Use your `.pub` file (for example, `id_ed25519.pub`).

## How to Create an SSH Key Pair (If Needed)

```sh
ssh-keygen -t ed25519 -C "your-name@your-device"
```

Your public key is then typically at:

```sh
~/.ssh/id_ed25519.pub
```

Use that `.pub` content for registration.
