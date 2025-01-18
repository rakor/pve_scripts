#!/bin/bash

# Das Script beendet eine VM, wartet bis diese komplett
# gestoppt ist und startet dann eine andere VM.
#
# Hilfreich für VMs die exklusiv auf Ressourcen zugreifen
# (z.B. PCI-Passthrough)
#

# ID der VMs
VM1=100
VM2=101

# Beende die erste VM
echo "Beende VM mit ID $VM1..."
qm shutdown $VM1

# Warte darauf, dass die VM vollständig heruntergefahren ist
echo "Warte auf das Herunterfahren der VM $VM1..."
while qm status $VM1 | grep -q "status: running"; do
  sleep 1
done

# Wenn die VM gestoppt wurde, starte die zweite VM
echo "VM $VM1 wurde gestoppt. Starte VM mit ID $VM2..."
qm start $VM2

echo "Skript abgeschlossen."
