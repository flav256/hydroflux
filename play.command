#!/bin/bash
# Double-click this file in Finder. Terminal keeps Godot alive until you close the game.
cd "$(dirname "$0")"
exec /opt/homebrew/bin/godot --path "$PWD"
