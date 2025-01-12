#!/bin/bash
#
# Version 0.1
# Datum: 04.01.2025

# Zieldatei, in die die Liste der manuell installierten Pakete geschrieben wird
OUTPUT_FILE="/root/manually_installed_packages.txt"

# Überprüfen, ob der Benutzer Root-Rechte hat
if [ "$EUID" -ne 0 ]; then
  echo "Bitte führen Sie dieses Skript mit Root-Rechten aus (sudo)."
  exit 1
fi

# Liste der manuell installierten Pakete abrufen
echo "Erstelle eine Liste aller manuell installierten Pakete..."
apt-mark showmanual > "$OUTPUT_FILE"

if [ $? -eq 0 ]; then
  echo "Die Liste wurde erfolgreich in '$OUTPUT_FILE' gespeichert."
else
  echo "Fehler beim Abrufen der Liste der manuell installierten Pakete."
  exit 1
fi
