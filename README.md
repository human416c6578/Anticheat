# AMX Mod X Anticheat Plugin

## Overview

This AMX Mod X plugin is designed to act as an anticheat solution, specifically targeting strafe hacks and other movement-related cheats in Counter-Strike 1.6 servers. The plugin monitors player movements, speed, and key presses to detect suspicious activities and logs them for server administrators to review.

The base code for this plugin is derived from a similar plugin created by Mistrick called "StrafeHack Blocker."

## Features

- **Strafe Hack Detection:** Monitors player strafing movements to identify and block strafe hacks.
- **Speed and Movement Detection:** Detects abnormal speed and movement patterns that may indicate cheating.
- **FPS Limit Enforcement:** Enforces a maximum frames-per-second (FPS) limit to prevent FPS manipulation cheats.
- **Logging:** Records detected suspicious activities in log files for server administrators to review.

## Configuration

The plugin includes some configurable parameters that can be adjusted in the plugin source code:

- `MAX_STRAFES`: Maximum allowed strafes before considering it suspicious.
- `MAX_WARNINGS`: Maximum number of warnings before kicking a player for suspicious movements.
- `szLogFile`: Path to the log file for general anticheat entries.
- `szLogEntriesFile`: Path to the log file for specific detected entries.

Adjust these parameters according to your server's needs.