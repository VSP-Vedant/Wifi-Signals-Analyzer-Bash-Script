#!/bin/bash
# Advanced Wireless Network Scanner with Detailed Output via airodump-ng and tshark
# This script collects advanced Wi‑Fi details. When complete, it reverts your interface back to managed mode.
# Run as root: sudo ./networkscan.sh

# ---------------------------
# Check for root privileges
# ---------------------------
if [ "$EUID" -ne 0 ]; then
    echo "This script requires root privileges. Please run with sudo."
    exit 1
fi

# ---------------------------
# Check for required tools
# ---------------------------
for tool in airodump-ng tshark iwconfig airmon-ng timeout; do
    if ! command -v "$tool" &> /dev/null; then
        echo "Error: $tool is required. Please install it first."
        exit 1
    fi
done

# ---------------------------
# Global Variables & Defaults
# ---------------------------
ORIG_INTERFACE=""         # To store the original (managed) interface.
INTERFACE=""              # The working (monitor-mode) interface.
OUTPUT_FILE="advanced_network_details.txt"
CAPTURE_DURATION=15       # Default capture duration in seconds.
VERBOSE=0

# ---------------------------
# Functions
# ---------------------------

# Display the interactive menu.
display_menu() {
    echo "-------------------------------------------------"
    echo "  Advanced Wireless Network Scanner"
    echo "-------------------------------------------------"
    echo "Please provide the required inputs for the scan."
    echo ""
}

# Revert the wireless interface back to managed mode.
revert_managed_mode() {
    # If our working interface is different from the original,
    # assume monitor mode was enabled.
    if [ "$INTERFACE" != "$ORIG_INTERFACE" ]; then
        echo "Reverting monitor mode..."
        airmon-ng stop "$INTERFACE" > /dev/null 2>&1
        echo "$ORIG_INTERFACE restored to managed mode."
    fi
}

# Cleanup temporary files.
cleanup() {
    rm -f temp_capture* tshark_summary.csv tshark_error.log 2> /dev/null
}

# Ensure cleanup and reverting managed mode when the script exits.
trap "cleanup; revert_managed_mode" EXIT

# ---------------------------
# Interactive Prompts
# ---------------------------
display_menu

read -p "Enter the wireless interface (e.g., wlan0): " INTERFACE
if [ -z "$INTERFACE" ]; then
    echo "No interface provided. Exiting."
    exit 1
fi
ORIG_INTERFACE="$INTERFACE"  # Save the original interface.

read -p "Enter the output file name [default: advanced_network_details.txt]: " tmp_out
OUTPUT_FILE=${tmp_out:-advanced_network_details.txt}

read -p "Enter the capture duration in seconds (default: 15): " tmp_duration
CAPTURE_DURATION=${tmp_duration:-15}

read -p "Enable verbose mode? (y/n) [default: n]: " tmp_verbose
if [[ "$tmp_verbose" =~ ^([Yy][Ee][Ss]|[Yy])$ ]]; then
    VERBOSE=1
else
    VERBOSE=0
fi

echo ""
echo "Scanning methods available:"
echo "  1) airodump-ng (for AP details)"
echo "  2) tshark (deep packet capture summary)"
read -p "Choose scanning method [default: 1]: " SCAN_METHOD
SCAN_METHOD=${SCAN_METHOD:-1}

# ---------------------------
# Switch to Monitor Mode if Needed
# ---------------------------
if ! iwconfig "$INTERFACE" 2>/dev/null | grep -q "Mode:Monitor"; then
    echo "Switching $INTERFACE to monitor mode using airmon-ng..."
    airmon-ng start "$INTERFACE" > /dev/null
    # The new monitor interface is usually named by appending "mon".
    NEW_INTERFACE="${INTERFACE}mon"
    if ! iwconfig "$NEW_INTERFACE" 2>/dev/null | grep -q "Mode:Monitor"; then
        echo "Failed to enable monitor mode on $INTERFACE. Exiting."
        exit 1
    fi
    INTERFACE="$NEW_INTERFACE"
    echo "Monitor mode enabled on $INTERFACE."
fi

# Clear out the output file.
> "$OUTPUT_FILE"

# ---------------------------
# Method 1: airodump-ng for AP Details
# ---------------------------
if [ "$SCAN_METHOD" -eq 1 ]; then
    echo "Scanning wireless networks with airodump-ng on $INTERFACE for $CAPTURE_DURATION seconds..."
    if (( VERBOSE )); then
        echo "Running: airodump-ng --write-interval 1 --output-format csv --write temp_capture $INTERFACE"
    fi
    airodump-ng --write-interval 1 --output-format csv --write temp_capture "$INTERFACE" &> /dev/null &
    AIRODUMP_PID=$!
    sleep "$CAPTURE_DURATION"
    kill "$AIRODUMP_PID" > /dev/null 2>&1

    CSV_FILE="temp_capture-01.csv"
    if [ -f "$CSV_FILE" ]; then
        echo "" >> "$OUTPUT_FILE"
        echo "=== AP Details (from airodump-ng) ===" >> "$OUTPUT_FILE"
        # The expected CSV fields (columns):
        # 1: BSSID, 2: First time seen, 3: Last time seen, 4: Channel,
        # 5: Speed, 6: Privacy, 7: Cipher, 8: Authentication,
        # 9: Power, 10: # beacons, 11: # IV, 12: LAN IP, 13: ID-length, 14: ESSID
        awk -F',' '
        BEGIN {
            printf "%-20s %-20s %-20s %-8s %-8s %-12s %-30s %-25s\n", "BSSID", "First Seen", "Last Seen", "Ch", "Power", "#Beacons", "ESSID", "Encryption";
            print "---------------------------------------------------------------------------------------------------------------------------";
        }
        NR==1 { next }  # Skip CSV header.
        ($1 ~ /^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/) {
            for(i=1; i<=NF; i++){
                gsub(/^[ \t]+|[ \t]+$/, "", $i);
            }
            bssid     = $1;
            firstSeen = $2;
            lastSeen  = $3;
            channel   = $4;
            power     = $9;
            beacons   = $10;
            encryption = $6 " / " $7 " / " $8;
            essid     = $14;
            if(essid == "") {
                essid = "Hidden";
            }
            printf "%-20s %-20s %-20s %-8s %-8s %-12s %-30s %-25s\n", bssid, firstSeen, lastSeen, channel, power, beacons, essid, encryption;
        }
        ' "$CSV_FILE" >> "$OUTPUT_FILE"
    else
        echo "Error: airodump-ng CSV output ($CSV_FILE) not found." >> "$OUTPUT_FILE"
    fi

# ---------------------------
# Method 2: tshark (Deep Packet Capture)
# ---------------------------
elif [ "$SCAN_METHOD" -eq 2 ]; then
    # Prompt for channel since tshark does not hop channels automatically.
    read -p "Enter the channel to capture from (default: 6): " capture_channel
    capture_channel=${capture_channel:-6}
    echo "Setting interface $INTERFACE to channel $capture_channel..."
    iwconfig "$INTERFACE" channel "$capture_channel"

    echo "Starting deep packet capture with tshark on $INTERFACE for $CAPTURE_DURATION seconds..."
    TSHARK_FILE="tshark_capture.pcap"
    if (( VERBOSE )); then
        echo "Running: tshark -I -i \"$INTERFACE\" -a duration:$CAPTURE_DURATION -w \"$TSHARK_FILE\""
    fi
    # Use tshark's own duration option.
    tshark -I -i "$INTERFACE" -a duration:$CAPTURE_DURATION -w "$TSHARK_FILE" 2> tshark_error.log
    # Wait a few seconds to allow file flushing.
    sleep 3
    if [ -f "$TSHARK_FILE" ] && [ -s "$TSHARK_FILE" ]; then
        echo "Packet capture saved as $TSHARK_FILE." >> "$OUTPUT_FILE"
        echo "--- Deep Packet Summary ---" >> "$OUTPUT_FILE"
        tshark -r "$TSHARK_FILE" -T fields \
            -e wlan.sa -e wlan.da -e wlan.fc.type_subtype -e radiotap.dbm_antsignal \
            -E header=y -E separator=, >> "$OUTPUT_FILE"
    else
        echo "Error: tshark capture file not found or is empty." >> "$OUTPUT_FILE"
        if (( VERBOSE )); then
            echo "Tshark error details:" >> "$OUTPUT_FILE"
            cat tshark_error.log >> "$OUTPUT_FILE"
            echo "Listing current directory:" >> "$OUTPUT_FILE"
            ls -lh .
        fi
    fi

else
    echo "Invalid scanning method selected. Exiting."
    exit 1
fi

echo ""
echo "Scan complete. Detailed results saved to $OUTPUT_FILE."

