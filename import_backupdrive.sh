#!/bin/bash
#
# Version: 0.1
# Datum: 04.01.2025

# Überprüfen, ob ein Pool-Name als Argument übergeben wurde
if [ -z "$1" ]; then
  echo "Fehler: Bitte geben Sie den Namen eines ZFS-Pools als Argument an."
  echo "Nutzung: $0 <pool_name>"
  exit 1
fi

POOL_NAME="$1"

# Name und Pfad der LUKS-Partition und des Mappings
LUKS_DEVICE="/dev/disk/by-partlabel/$POOL_NAME" # Pfad zur LUKS-Partition (anpassen)
LUKS_MAPPING_NAME="${POOL_NAME}_LUKS"

# Funktion zur Überprüfung, ob der Pool verfügbar ist
check_pool_available() {
  zpool import | grep -q "$POOL_NAME"
  return $?
}

# Pool importieren
import_pool() {
  zpool import -N -R "/mnt/$POOL_NAME" "$POOL_NAME"
  return $?
}

# LUKS-Container entsperren
unlock_luks() {
  echo "Bitte geben Sie die LUKS-Passphrase für $LUKS_DEVICE ein:"
  cryptsetup luksOpen "$LUKS_DEVICE" "$LUKS_MAPPING_NAME"
  return $?
}

# LUKS-Container sperren
lock_luks() {
  echo "Sperre den LUKS-Container..."
  cryptsetup close "$LUKS_MAPPING_NAME"
  return $?
}

# Hauptablauf
if unlock_luks; then
  echo "Der LUKS-Container wurde erfolgreich entsperrt."

  # Überprüfen, ob der Pool verfügbar ist
  if check_pool_available; then
    echo "Der Pool '$POOL_NAME' ist verfügbar. Versuche, ihn zu importieren..."
    if import_pool; then
      echo "Der Pool '$POOL_NAME' wurde erfolgreich importiert."
    else
      echo "Fehler: Der Pool '$POOL_NAME' konnte nicht importiert werden."
      lock_luks
      exit 1
    fi
  else
    echo "Fehler: Der Pool '$POOL_NAME' ist nicht verfügbar."
    lock_luks
    exit 1
  fi

  # Pool erfolgreich importiert, LUKS-Container nicht schließen, falls aktiv benötigt
  echo "Das Skript hat erfolgreich abgeschlossen. Wenn der Pool nicht mehr benötigt wird, schließen Sie den LUKS-Container manuell:"
  echo "cryptsetup close $LUKS_MAPPING_NAME"

else
  echo "Fehler: Der LUKS-Container konnte nicht entsperrt werden."
  exit 1
fi
