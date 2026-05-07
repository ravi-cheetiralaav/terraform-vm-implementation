# RDP / NLA Troubleshooting Guide

## Overview

This guide covers RDP login issues when connecting to the VM via a **D365 jumpbox**, specifically around NLA (Network Level Authentication) configuration.

---

## What the Script Does

`script1.ps1` configures RDP on the target VM by:

- Enabling RDP connections (`fDenyTSConnections=0`)
- Enforcing NLA (`UserAuthentication=1`)
- Setting TLS security layer (`SecurityLayer=1`)
- Opening Windows Firewall rules for Remote Desktop
- Starting the Remote Desktop Services (`TermService`)
- Adding the specified local user to the `Remote Desktop Users` group

---

## Common Issue: "NLA is disabled / Login failed"

### Cause

When connecting via a **D365 jumpbox**, NLA pre-authentication passes the **jumpbox credentials** to the target VM, not the original user credentials. The target VM receives the jumpbox machine/user identity, which doesn't match the local `azureadmin` account — causing authentication to fail.

### Solutions

#### Option 1: Disable NLA on the Target VM (Recommended for jumpbox scenarios)

Change `UserAuthentication` to `0` so credentials are entered at the VM's own login screen instead of being pre-authenticated:

```powershell
Set-RegistryDword -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "UserAuthentication" -Value 0
```

> **Note:** This is acceptable when the VM is already protected behind a jumpbox and NSG rules. The jumpbox layer provides the primary security boundary.

#### Option 2: Use "Different Credentials" in the RDP Client

On the jumpbox, when opening the RDP client:

1. Uncheck **"Use my Windows user account"**
2. Manually enter `.\azureadmin` (or `VMHOSTNAME\azureadmin`) and the password

#### Option 3: Use RDP Restricted Admin Mode

If the jumpbox supports it, connect using RDP Restricted Admin mode (`/restrictedAdmin`), which avoids credential delegation entirely.

---

## Verify Current NLA Setting

Run this via **Azure Portal → VM → Run Command**:

```powershell
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name UserAuthentication
```

| Value | Meaning         |
|-------|-----------------|
| `0`   | NLA disabled    |
| `1`   | NLA enabled     |

If the value is `0`, `script1.ps1` has not applied yet or was not executed.

---

## NLA Values Reference

| `UserAuthentication` | Behavior |
|----------------------|----------|
| `1` (NLA enabled)    | Credentials verified **before** RDP session is created. More secure. Can cause issues through jumpboxes. |
| `0` (NLA disabled)   | Credentials entered at the VM login screen **after** session starts. Compatible with jumpbox scenarios. |

---

## Username Format

When prompted for credentials, use one of these formats:

```
.\azureadmin
VMHOSTNAME\azureadmin
```

Entering just `azureadmin` without a domain/machine prefix can cause NLA to attempt domain authentication and fail.
