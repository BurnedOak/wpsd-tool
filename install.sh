#!/bin/bash
# ==============================================================================
# dmr-chk One-Click Installer für WPSD
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Fehler: Der Installer muss mit root-Rechten laufen!${NC}"
  exit 1
fi

echo -e "${BLUE}====================================================================${NC}"
echo -e "${BLUE}        Installiere WPSD DMRGateway Schutz-Skript (dmr-chk)         ${NC}"
echo -e "${BLUE}====================================================================${NC}"

# WPSD-Dateisystem schreibbar machen (SD-Karten Schreibschutz temporär aufheben)
mount -o remount,rw / || true

# 1. Das eigentliche Skript schreiben
cat << 'EOF' > /usr/sbin/dmr-chk
#!/bin/bash
# ==============================================================================
# dmr-chk - WPSD DMRGateway Config Protector & Interactive Updater
# ==============================================================================

# ------------------------------------------------------------------------------
# WPSD FS-Schutz: Dateisystem schreibbar machen und am Ende IMMER wieder sperren
mount -o remount,rw / || true
trap 'mount -o remount,ro / || true' EXIT
# ------------------------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

FILE_CUR="/etc/dmrgateway"
FILE_MST="/etc/dmrgateway.master"
FILE_TMP="/tmp/dmrgateway.new"
FILE_BAK="/tmp/dmrgateway.undo"
LOG_FILE="/home/pi-star/dmr-chk_log.txt"

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Fehler: Dieses Skript muss mit sudo ausgeführt werden!${NC}"
  exit 1
fi

echo -e "${BLUE}====================================================================${NC}"
echo -e "${BLUE}            WPSD DMRGateway Schutz-Skript (dmr-chk)                 ${NC}"
echo -e "${BLUE}====================================================================${NC}"
echo -e "Dieses Skript schützt deine eigenen DMR-Regeln davor, vom WPSD-"
echo -e "Dashboard heimlich überschrieben zu werden."
echo -e "Es vergleicht die aktuelle Konfiguration Block für Block mit deiner"
echo -e "gespeicherten Master-Vorlage und lässt DICH entscheiden.${NC}\n"

if [ ! -f "$FILE_MST" ]; then
    echo -e "${YELLOW}HINWEIS: Es wurde noch keine geschützte Master-Datei gefunden.${NC}"
    echo -e "Ist die aktuelle Konfiguration ($FILE_CUR) fehlerfrei und soll"
    echo -e "als zukünftige Master-Vorlage gespeichert werden?"
    read -p "Master jetzt anlegen? [j/N]: " init_ans < /dev/tty
    if [[ "$init_ans" =~ ^[jJ] ]]; then
        cp "$FILE_CUR" "$FILE_MST"
        chmod 444 "$FILE_MST"
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
        
        echo -e "\n${YELLOW}=== ZUSAMMENFASSUNG & SPEICHERORTE ===${NC}"
        echo -e "${CYAN}Ausgeführte Aktionen:${NC}"
        echo -e "- INITIALISIERUNG : Master-Datei aus aktueller Config erstellt"
        echo -e "${CYAN}Zustand der Dateien:${NC}"
        echo -e "- Aktive Konfiguration : ${GREEN}$FILE_CUR${NC}"
        echo -e "- Master-Vorlage       : ${BLUE}$FILE_MST${NC}"
        echo -e "- Historien-Log        : ${CYAN}$LOG_FILE${NC}"
        echo -e "${YELLOW}======================================${NC}"
        echo -e "${GREEN}Erfolg: Skript beendet.${NC}"

        {
            echo "[$TIMESTAMP] dmr-chk INITIALISIERUNG"
            echo "- Master-Datei erfolgreich erstellt."
            echo "--------------------------------------------------------"
        } >> "$LOG_FILE"
        chown pi-star:pi-star "$LOG_FILE"
    else
        echo -e "Abbruch. Es wurde nichts verändert."
    fi
    exit 0
fi

cp "$FILE_CUR" "$FILE_BAK"
> "$FILE_TMP"
MASTER_CHANGED=0
ACTION_LOG=""
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

get_block() {
    awk -v b="$1" '
        $0 == b { found=1; print; next }
        /^\[/ { if(found) exit }
        found { print }
    ' "$2" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
}

echo -e "${CYAN}Prüfe auf Unterschiede...${NC}\n"
DIFF_FOUND=0

while IFS= read -r block; do
    get_block "$block" "$FILE_CUR" > /tmp/cur_block.tmp
    get_block "$block" "$FILE_MST" > /tmp/mast_block.tmp

    if ! cmp -s /tmp/cur_block.tmp /tmp/mast_block.tmp; then
        DIFF_FOUND=1
        echo -e "${YELLOW}====================================================================${NC}"
        echo -e "${RED}ACHTUNG: Änderung im Bereich ${YELLOW}${block}${RED} gefunden!${NC}"
        echo -e "(${RED}- = So sah es im Master aus${NC} | ${GREEN}+ = Das ist neu von WPSD${NC})"
        echo -e "${YELLOW}--------------------------------------------------------------------${NC}"
        
        diff -u /tmp/mast_block.tmp /tmp/cur_block.tmp | grep -v -E "^(---|\+\+\+|@@)" | while IFS= read -r line; do
            if [[ "$line" == -* ]]; then
                echo -e "${RED}${line}${NC}"
            elif [[ "$line" == +* ]]; then
                echo -e "${GREEN}${line}${NC}"
            else
                echo -e "${line}"
            fi
        done
        
        echo -e "${YELLOW}--------------------------------------------------------------------${NC}"
        echo -e "Wie möchtest du mit diesem Block verfahren?"
        echo -e "  ${GREEN}[R] RESTORE${NC} : WPSD-Fehler verwerfen. Meine Master-Regeln wiederherstellen!"
        echo -e "  ${RED}[U] UPDATE${NC}  : Das war meine bewusste Änderung (z.B. YSF). Master damit updaten!"
        echo -e "  ${CYAN}[I] IGNORE${NC}  : Diesmal WPSD gewinnen lassen, aber Master NICHT verändern."
        
        valid_input=0
        while [ $valid_input -eq 0 ]; do
            read -p "Deine Wahl [R/U/I]: " choice < /dev/tty
            case "$choice" in
                r|R ) 
                    cat /tmp/mast_block.tmp >> "$FILE_TMP"
                    echo -e "${GREEN}=> Block aus Master wiederhergestellt.${NC}\n"
                    ACTION_LOG+="- Block ${block} : RESTORED (Aus Master repariert)\n"
                    valid_input=1
                    ;;
                u|U ) 
                    cat /tmp/cur_block.tmp >> "$FILE_TMP"
                    MASTER_CHANGED=1
                    echo -e "${RED}=> Neue Werte akzeptiert (Master wird am Ende geupdatet).${NC}\n"
                    ACTION_LOG+="- Block ${block} : UPDATED (Master mit WPSD-Werten überschrieben)\n"
                    valid_input=1
                    ;;
                i|I )
                    cat /tmp/cur_block.tmp >> "$FILE_TMP"
                    echo -e "${CYAN}=> Neue Werte temporär akzeptiert (Master bleibt unverändert).${NC}\n"
                    ACTION_LOG+="- Block ${block} : IGNORED (WPSD-Werte temporär aktiv gelassen)\n"
                    valid_input=1
                    ;;
                * ) echo "Bitte R, U oder I eingeben.";;
            esac
        done
    else
        cat /tmp/cur_block.tmp >> "$FILE_TMP"
    fi
    echo "" >> "$FILE_TMP"
done < <(grep -E '^\[.*\]' "$FILE_CUR" | tr -d '\r')

if [ $DIFF_FOUND -eq 0 ]; then
    echo -e "${GREEN}Keine Änderungen gefunden. Deine Konfiguration ist absolut synchron mit dem Master!${NC}"
    echo "[$TIMESTAMP] dmr-chk CHECK" >> "$LOG_FILE"
    echo "- Keine Änderungen gefunden. Master und Config sind synchron." >> "$LOG_FILE"
    echo "--------------------------------------------------------" >> "$LOG_FILE"
    chown pi-star:pi-star "$LOG_FILE"
    rm -f /tmp/*.tmp "$FILE_BAK" "$FILE_TMP"
    exit 0
fi

echo -e "${CYAN}Schreibe Konfiguration und starte Dienste neu...${NC}"
mv "$FILE_TMP" "$FILE_CUR"

if [ $MASTER_CHANGED -eq 1 ]; then
    chmod 644 "$FILE_MST"
    cp "$FILE_CUR" "$FILE_MST"
    chmod 444 "$FILE_MST"
fi

systemctl restart dmrgateway.service mmdvmhost.service

# =====================================================================
# SUMMARY & LOGGING
# =====================================================================
echo -e "\n${YELLOW}=== ZUSAMMENFASSUNG & SPEICHERORTE ===${NC}"
echo -e "${CYAN}Ausgeführte Aktionen:${NC}"
echo -e "${ACTION_LOG}"

echo -e "${CYAN}Zustand der Dateien:${NC}"
echo -e "- Aktive Konfiguration : ${GREEN}$FILE_CUR${NC}"
echo -e "- Master-Vorlage       : ${BLUE}$FILE_MST${NC}"
echo -e "- Undo-Sicherung       : ${YELLOW}$FILE_BAK${NC}"
echo -e "- Historien-Log        : ${CYAN}$LOG_FILE${NC}"
echo -e "${YELLOW}======================================${NC}"

{
    echo "[$TIMESTAMP] dmr-chk LAUF BEENDET"
    echo -e "$ACTION_LOG" | sed '/^$/d'
    echo "- Dienste (DMRGateway, MMDVMHost) wurden neu gestartet."
    echo "--------------------------------------------------------"
} >> "$LOG_FILE"
chown pi-star:pi-star "$LOG_FILE"

# =====================================================================
# ROLLBACK CHECK
# =====================================================================
echo -e "\nBitte lade das Dashboard jetzt neu und prüfe, ob alles funktioniert."
echo -e "Falls etwas komplett schiefgegangen ist, können wir den Zustand"
echo -e "von vor dem Skript-Start jetzt sofort wiederherstellen."
read -p "Alles in Ordnung? [J]a, alles super / [N]ein, mach alles rückgängig!: " undo_ans < /dev/tty

if [[ "$undo_ans" =~ ^[nN] ]]; then
    echo -e "${RED}Leite sofortigen Rollback ein...${NC}"
    mv "$FILE_BAK" "$FILE_CUR"
    systemctl restart dmrgateway.service mmdvmhost.service
    echo -e "${GREEN}Zustand erfolgreich zurückgesetzt! Dienste neu gestartet.${NC}"
    
    {
        echo "[$TIMESTAMP] dmr-chk ROLLBACK"
        echo "- User hat Änderungen soeben rückgängig gemacht!"
        echo "--------------------------------------------------------"
    } >> "$LOG_FILE"
else
    echo -e "${GREEN}Perfekt. Saubere Arbeit!${NC}"
    rm -f "$FILE_BAK"
fi

rm -f /tmp/*.tmp
exit 0
EOF

# 2. Ausführungsrechte vergeben
chmod +x /usr/sbin/dmr-chk

# 3. Den unschönen lokalen Symlink entfernen (falls vorhanden)
rm -f /usr/local/sbin/dmr-chk

# Installer-Schreibschutz wieder aktivieren
mount -o remount,ro / || true

echo -e "${GREEN}Installation erfolgreich! Das Kommando 'dmr-chk' ist nun systemweit aktiv.${NC}"
echo -e "Starte den initialen Durchlauf...\n"

# 4. Direkt starten
/usr/sbin/dmr-chk
/usr/sbin/dmr-chk
