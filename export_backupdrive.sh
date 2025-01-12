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
LUKS_MAPPING_NAME="${POOL_NAME}_LUKS"

# Funktion zur Überprüfung, ob der Pool vorhanden ist
check_pool_available() {
  zpool list -H -o name | grep -q "$POOL_NAME"
  return $?
}

# Pool exportieren
export_pool() {
  zpool export "$POOL_NAME"
  return $?
}


# LUKS-Container sperren
lock_luks() {
  echo "Sperre den LUKS-Container..."
  cryptsetup close "$LUKS_MAPPING_NAME"
  return $?
}

# Hauptablauf
  # Überprüfen, ob der Pool verfügbar ist
  if check_pool_available; then
    echo "Der Pool '$POOL_NAME' ist verfügbar. Versuche, ihn zu exportieren..."
    if export_pool; then
      echo "Der Pool '$POOL_NAME' wurde erfolgreich exportiert."
      echo "Versuche den LUKS-Container '$LUKS_MAPPING_NAME' zu schliessen..."
      if lock_luks; then
              echo "Der Container '$LUKS_MAPPING_NAME' wurde erfolgreich geschlossen"
              echo "Das Gerät kann entfernt werden"
      else
              echo "Fehler beim Schliessen des LUKS-Containers '$LUKS_MAPPING_NAME'"
              exit 1
      fi
    else
      echo "Fehler: Der Pool '$POOL_NAME' konnte nicht exportiert werden."
      echo "ZPOOL und LUKS-Device sind noch geöffnet"
      exit 1
    fi
  else
    echo "Fehler: Der Pool '$POOL_NAME' ist nicht verfügbar."
    echo "Folgende Pools sind aktuell verfügbar:"
    echo 
    zpool list -H -o name
    exit 1
  fi
