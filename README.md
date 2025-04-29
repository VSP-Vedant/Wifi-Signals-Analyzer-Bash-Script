# Wifi-Signals-Analyzer-Bash-Script

## Introduction
Wifi-Signals-Analyzer is an advanced Bash script designed to analyze wireless networks using `airodump-ng` and `tshark`. It provides detailed information about Access Points (APs) and wireless packet activity by switching the wireless interface into monitor mode. Once the scan completes, the script restores the interface to managed mode.

This tool is useful for network administrators, security researchers, and penetration testers who need a lightweight, command-line-based Wi-Fi analysis tool.

## Features
- Uses `airodump-ng` for AP scanning.
- Uses `tshark` for deep packet capture analysis.
- Automatically switches the interface to monitor mode and reverts it back to managed mode when done.
- Captures details such as signal strength, encryption methods, ESSIDs, and packet summaries.
- Generates a detailed output file for later review.

## Requirements
Before running the script, ensure you have the required dependencies installed:

```bash
sudo apt update
sudo apt install aircrack-ng tshark
```
Alternatively, you can use the following requirements.txt to install them:
```bash
aircrack-ng
tshark
```
## How to Use
Clone the repository:
```bash
git clone https://github.com/yourusername/Wifi-Signals-Analyzer-Bash-Script.git
cd Wifi-Signals-Analyzer-Bash-Script
```
Make the script executable:
```bash
chmod +x networkscan.sh
```
Run the script with root privileges:
```bash
sudo ./networkscan.sh
```
## Input Parameters (Interactive Mode)
Upon running the script, you will be prompted for the following inputs:
Wireless Interface
- Enter the name of the wireless interface you wish to use (e.g., `wlan0`).
- The script checks if the interface is already in monitor mode; if not, it switches it automatically.

Output File Name
- Specify the name of the output file (default: `advanced_network_details.txt`).
- This file will store the results of the scan.

Capture Duration
- Enter the scan duration in seconds (default: `15`).
- The script collects data for this specified time before stopping.

Verbose Mode
- Choose whether to enable verbose mode (`y/n`, default: `n`).
- If enabled, the script provides detailed execution logs, including the commands run.

Scanning Method
- Select the scanning method:-
- `1` (Default): Uses `airodump-ng` to scan for access points.
- `2`: Uses `tshark` to capture packets for deeper analysis.
Channel Selection (For tshark mode)
- If tshark mode is selected, specify the Wi-Fi channel to capture packets from (default: 6).
- This is required since tshark does not automatically hop channels.

5. Scan Execution
- The script runs the selected scanning method for the specified duration.
- If using `airodump-ng`, it captures details about nearby networks.
- If using `tshark`, it saves packet captures for later analysis.

6. Cleanup and Results
- Once the scan is complete, the script reverts the wireless interface to managed mode.
- The results are stored in the specified output file.


Notes
- Ensure your wireless card supports monitor mode.
- Use this tool responsibly and legally.
- Running this script may require administrative privileges (`sudo`).
- Scanning wireless networks without permission may violate laws or ethical guidelines.
