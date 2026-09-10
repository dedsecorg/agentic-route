#!/usr/bin/env bash
# Enhanced Network and DNS Diagnostic Script
# Checks VPN separation: ProtonVPN=DNS only, NordVPN=data with fallback

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

print_header() {
    echo -e "\n${CYAN}[$1] $2${NC}"
}

echo "========================================"
echo -e "${CYAN} NETWORK DIAGNOSTICS${NC}"
echo "========================================"

print_header 1 "Checking Interfaces and IPs..."
ip -br addr

print_header 2 "Checking Default Routes and Policy Rules..."
ip route
echo -e "${CYAN}--- IP Rules ---${NC}"
ip rule

print_header 3 "Testing Raw IP Connectivity (ICMP)..."
if ping -4 -c 2 -W 2 1.1.1.1 > /dev/null 2>&1; then
    echo -e "IPv4 Egress (1.1.1.1): ${GREEN}SUCCESS${NC}"
else
    echo -e "IPv4 Egress (1.1.1.1): ${RED}FAILED${NC}"
fi

if ping -6 -c 2 -W 2 2606:4700:4700::1111 > /dev/null 2>&1; then
    echo -e "IPv6 Egress (Cloudflare): ${GREEN}SUCCESS${NC}"
else
    echo -e "IPv6 Egress (Cloudflare): ${RED}FAILED${NC}"
fi

print_header 4 "Checking Core Services Status..."
for svc in dnsdist pihole-FTL tailscaled nordvpnd wg-quick@proton0 agentic-route agentic-route-daemon; do
    if systemctl is-active --quiet "$svc"; then
        echo -e "$svc: ${GREEN}RUNNING${NC}"
    else
        echo -e "$svc: ${RED}STOPPED/FAILED${NC}"
    fi
done

print_header 5 "Testing DNS Resolution Paths..."
test_dns() {
    local name=$1
    local server=$2
    local port=$3
    local domain="google.com"
    local out=""
    
    if [ -n "$port" ]; then
        out=$(dig @"$server" -p "$port" "$domain" +short +time=2 +tries=1 2>/dev/null)
    elif [ -n "$server" ]; then
        out=$(dig @"$server" "$domain" +short +time=2 +tries=1 2>/dev/null)
    else
        out=$(dig "$domain" +short +time=2 +tries=1 2>/dev/null)
    fi

    # If output is NOT empty AND does NOT contain ';;' (dig's error indicator)
    if [ -n "$out" ] && ! echo "$out" | grep -q ';;'; then
        first_ip=$(echo "$out" | head -n 1)
        echo -e "- $name: ${GREEN}SUCCESS${NC} ($first_ip)"
    else
        echo -e "- $name: ${RED}FAILED${NC}"
    fi
}

test_dns "Host OS (resolv.conf)" "" ""
test_dns "Local port 53 (Pi-hole)" "127.0.0.1" ""
test_dns "Nebula mesh DNS (192.168.100.1)" "192.168.100.1" ""
test_dns "Local port 5330 (dnsdist)" "127.0.0.1" "5330"
test_dns "Upstream (Quad9)" "9.9.9.9" ""
test_dns "Unbound (port 5335)" "127.0.0.1" "5335"
test_dns "Stubby (port 5360)" "127.0.0.1" "5360"
test_dns "dnscrypt (port 5354)" "127.0.0.1" "5354"
test_dns "ProtonVPN DNS (10.2.0.1)" "10.2.0.1" ""

print_header 6 "Testing VPN Separation (DNS vs Data)..."

# ProtonVPN DNS path: DNS queries should go through proton0, not NordVPN
protonvpn_dns_ok=$(dig @10.2.0.1 google.com +short +time=3 +tries=1 2>/dev/null)
if [ -n "$protonvpn_dns_ok" ] && ! echo "$protonvpn_dns_ok" | grep -q ';;'; then
    protonvpn_ip=$(echo "$protonvpn_dns_ok" | head -1)
    echo -e "  ProtonVPN DNS (10.2.0.1 -> proton0): ${GREEN}SUCCESS${NC} ($protonvpn_ip)"
else
    echo -e "  ProtonVPN DNS (10.2.0.1 -> proton0): ${RED}FAILED${NC}"
fi

# Check that ProtonVPN DNS goes through proton0, not nordlynx
protonvpn_route=$(ip route get 10.2.0.1 2>/dev/null | grep -o "dev [a-z0-9]*" | head -1)
if echo "$protonvpn_route" | grep -q "proton0"; then
    echo -e "  ProtonVPN DNS route: ${GREEN}via proton0${NC}"
else
    echo -e "  ProtonVPN DNS route: ${RED}via $protonvpn_route (expected proton0)${NC}"
fi

# Check that DNS upstreams bypass NordVPN
for upstream in 1.1.1.1 9.9.9.9; do
    upstream_route=$(ip route get "$upstream" 2>/dev/null | head -1)
    if echo "$upstream_route" | grep -q "nordlynx"; then
        echo -e "  DNS upstream ($upstream): ${YELLOW}via nordlynx (should be eth0)${NC}"
    elif echo "$upstream_route" | grep -q "eth0"; then
        echo -e "  DNS upstream ($upstream): ${GREEN}via eth0 (bypassed NordVPN)${NC}"
    else
        echo -e "  DNS upstream ($upstream): ${YELLOW}route: $upstream_route${NC}"
    fi
done

# Check nebula mesh DNS
nebula_route=$(ip route get 192.168.100.1 2>/dev/null | head -1)
if echo "$nebula_route" | grep -q "nebula1" || echo "$nebula_route" | grep -qw "local"; then
    echo -e "  Nebula mesh DNS (192.168.100.1): ${GREEN}via nebula1 (local)${NC}"
else
    echo -e "  Nebula mesh DNS (192.168.100.1): ${YELLOW}via $nebula_route${NC}"
fi

# Check that general data traffic still goes through NordVPN
data_route=$(ip route get 8.8.8.8 2>/dev/null | head -1)
if echo "$data_route" | grep -q "nordlynx"; then
    echo -e "  Data egress (8.8.8.8): ${GREEN}via nordlynx (NordVPN active)${NC}"
else
    echo -e "  Data egress (8.8.8.8): ${YELLOW}via $data_route${NC}"
fi

# Check agentic-route health
print_header 7 "Routing State Health..."
if agentic_route_check_output=$(agentic-route check 2>&1); then
    echo "$agentic_route_check_output"
    echo -e "  Routing state: ${GREEN}PASS${NC}"
else
    agentic_route_check_status=$?
    echo "$agentic_route_check_output"
    echo -e "  Routing state: ${RED}FAIL (exit code: $agentic_route_check_status)${NC}"
fi

# Alert on ProtonVPN daemon rules
rogue_rules=$(ip rule show 2>/dev/null | grep -c -E "31298|31299|suppress_prefixlength 0|245447468" 2>/dev/null || true)
rogue_rules=${rogue_rules:-0}
rogue_rules=${rogue_rules//[^0-9]/}
rogue_rules=${rogue_rules:-0}
if [ "$rogue_rules" -gt 0 ]; then
    echo -e "  ${RED}WARNING: $rogue_rules ProtonVPN daemon rule(s) detected${NC}"
    ip rule show | grep -E "31298|31299|suppress_prefixlength 0|245447468" 2>&1
else
    echo -e "  ProtonVPN daemon rules: ${GREEN}none${NC}"
fi

echo ""
echo "========================================"
echo -e "${CYAN} DIAGNOSTICS COMPLETE${NC}"
echo "========================================"
