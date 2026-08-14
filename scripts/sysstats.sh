#!/bin/bash
# omarchy-desktop-stats: system stats generator for a waybar "bottom" layer panel.
#
# Outputs a single JSON line ({"text": "..."}) for a waybar custom module.
# Progress bars use the lower-half-block glyph ("▄") at normal font size so
# their character width lines up exactly with the plain text lines (no
# font-size scaling tricks needed) - they are sized to the widest line so
# they reach the same right edge as the rest of the content.
#
# Every external tool (docker, tailscale, iwd/NetworkManager, curl, coretemp)
# is optional: if it's missing, that row is hidden or shown with a clear
# fallback instead of breaking the whole panel.

set -u

CACHE_DIR="$HOME/.cache/waybar-desktop-stats"
mkdir -p "$CACHE_DIR"

# --- Defaults (overridable via ~/.config/waybar/desktop-stats.conf) ---
WARN_THRESHOLD=60
CRIT_THRESHOLD=85
COLOR_OK="#33ff33"
COLOR_WARN="#ffa500"
COLOR_CRIT="#ff3333"
COLOR_LABEL="#4d9950"
COLOR_DIM="#3a3a3a"
DISK_PATH="/"
NET_IFACE=""        # empty = auto-detect
PUBLIC_IP_TTL=300    # seconds between public-IP lookups
PUBLIC_IP_URL="https://icanhazip.com"

USER_CONF="$HOME/.config/waybar/desktop-stats.conf"
[ -f "$USER_CONF" ] && source "$USER_CONF"

color_for_pct() {
  local p=$1
  if ((p < WARN_THRESHOLD)); then
    printf '%s' "$COLOR_OK"
  elif ((p < CRIT_THRESHOLD)); then
    printf '%s' "$COLOR_WARN"
  else
    printf '%s' "$COLOR_CRIT"
  fi
}

# Half-height progress bar: same glyph for filled/empty, only color differs,
# so character advance width == plain text width (monospace).
bar() {
  local pct=$1 width=$2
  ((pct < 0)) && pct=0
  ((pct > 100)) && pct=100
  ((width < 1)) && width=1
  local color; color=$(color_for_pct "$pct")
  local filled=$((pct * width / 100))
  local empty=$((width - filled))
  local f e
  f=$(for ((i = 0; i < filled; i++)); do printf '▄'; done)
  e=$(for ((i = 0; i < empty; i++)); do printf '▄'; done)
  printf "<span foreground='%s'>%s</span><span foreground='%s'>%s</span>" "$color" "$f" "$COLOR_DIM" "$e"
}

rule() {
  local width=$1
  local out=""
  for ((i = 0; i < width; i++)); do out+="─"; done
  printf "<span foreground='%s'>%s</span>" "$COLOR_DIM" "$out"
}

have() { command -v "$1" >/dev/null 2>&1; }

# --- Network interface: explicit override, else whatever owns the default route ---
if [ -z "$NET_IFACE" ]; then
  NET_IFACE=$(ip route show default 2>/dev/null | awk '/default/{print $5; exit}')
fi
IS_WIRELESS=0
[ -n "$NET_IFACE" ] && [ -d "/sys/class/net/$NET_IFACE/wireless" ] && IS_WIRELESS=1

# --- CPU usage + network throughput (sampled together over one window) ---
read -r _ u1 n1 s1 idle1 io1 irq1 sirq1 _ < /proc/stat
rx1=0; tx1=0
if [ -n "$NET_IFACE" ] && [ -r "/sys/class/net/$NET_IFACE/statistics/rx_bytes" ]; then
  rx1=$(cat "/sys/class/net/$NET_IFACE/statistics/rx_bytes")
  tx1=$(cat "/sys/class/net/$NET_IFACE/statistics/tx_bytes")
fi
sleep 0.4
read -r _ u2 n2 s2 idle2 io2 irq2 sirq2 _ < /proc/stat
rx2=$rx1; tx2=$tx1
if [ -n "$NET_IFACE" ] && [ -r "/sys/class/net/$NET_IFACE/statistics/rx_bytes" ]; then
  rx2=$(cat "/sys/class/net/$NET_IFACE/statistics/rx_bytes")
  tx2=$(cat "/sys/class/net/$NET_IFACE/statistics/tx_bytes")
fi

busy1=$((u1+n1+s1+io1+irq1+sirq1)); total1=$((busy1+idle1))
busy2=$((u2+n2+s2+io2+irq2+sirq2)); total2=$((busy2+idle2))
denom=$((total2 - total1))
cpu=0
((denom > 0)) && cpu=$(( (100*(busy2-busy1)) / denom ))

down_kbs=$(awk -v a="$rx1" -v b="$rx2" 'BEGIN{printf "%.0f", (b-a)/1024/0.4}')
up_kbs=$(awk -v a="$tx1" -v b="$tx2" 'BEGIN{printf "%.0f", (b-a)/1024/0.4}')

# --- Memory / swap / disk ---
mem_total_kb=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
mem_avail_kb=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
mem_used_kb=$((mem_total_kb - mem_avail_kb))
mem_used_gib=$(awk -v k="$mem_used_kb" 'BEGIN{printf "%.2f", k/1024/1024}')
mem_total_gib=$(awk -v k="$mem_total_kb" 'BEGIN{printf "%.2f", k/1024/1024}')
mem_pct=0
((mem_total_kb > 0)) && mem_pct=$(( 100 * mem_used_kb / mem_total_kb ))

swap_total_kb=$(awk '/^SwapTotal:/{print $2}' /proc/meminfo)
swap_free_kb=$(awk '/^SwapFree:/{print $2}' /proc/meminfo)
swap_used_kb=$((swap_total_kb - swap_free_kb))
swap_used_gib=$(awk -v k="$swap_used_kb" 'BEGIN{printf "%.2f", k/1024/1024}')
swap_total_gib=$(awk -v k="$swap_total_kb" 'BEGIN{printf "%.2f", k/1024/1024}')
swap_pct=0
((swap_total_kb > 0)) && swap_pct=$(( 100 * swap_used_kb / swap_total_kb ))

disk_pct=0
disk_used_gib=0
disk_total_gib=0
if [ -e "$DISK_PATH" ]; then
  read -r disk_used disk_total <<< "$(df -B1 "$DISK_PATH" 2>/dev/null | awk 'NR==2{print $3, $2}')"
  if [ -n "${disk_total:-}" ] && [ "$disk_total" -gt 0 ]; then
    disk_used_gib=$(awk -v b="$disk_used" 'BEGIN{printf "%.0f", b/1024/1024/1024}')
    disk_total_gib=$(awk -v b="$disk_total" 'BEGIN{printf "%.0f", b/1024/1024/1024}')
    disk_pct=$(( 100 * disk_used / disk_total ))
  fi
fi

# --- CPU temperatures: any hwmon chip that looks like a CPU sensor ---
# Intel -> coretemp (Package id N / Core N), AMD -> k10temp/zenpower (Tctl/Tdie).
# Falls back to a single thermal_zone reading, and is hidden entirely if
# nothing usable is found instead of printing a blank "°C".
pkg_temp=""
core_temp_line=""
for d in /sys/class/hwmon/hwmon*; do
  [ -f "$d/name" ] || continue
  chip=$(cat "$d/name" 2>/dev/null)
  case "$chip" in
    coretemp|k10temp|zenpower) ;;
    *) continue ;;
  esac
  for label_file in "$d"/temp*_label; do
    [ -f "$label_file" ] || continue
    n=${label_file##*/temp}; n=${n%_label}
    label=$(cat "$label_file" 2>/dev/null)
    val=$(cat "$d/temp${n}_input" 2>/dev/null)
    [ -z "$val" ] && continue
    c=$(( val / 1000 ))
    case "$label" in
      Package*|Tdie|Tctl) [ -z "$pkg_temp" ] && pkg_temp="$c" ;;
      Core*) core_temp_line+="${core_temp_line:+  }${label}: ${c}°C" ;;
    esac
  done
  [ -n "$pkg_temp" ] && break
done
if [ -z "$pkg_temp" ]; then
  for zone in /sys/class/thermal/thermal_zone*; do
    [ -f "$zone/type" ] || continue
    case "$(cat "$zone/type" 2>/dev/null)" in
      *cpu*|*Cpu*|*CPU*|x86_pkg_temp)
        val=$(cat "$zone/temp" 2>/dev/null)
        [ -n "$val" ] && pkg_temp=$(( val / 1000 )) && break
        ;;
    esac
  done
fi

uptime_str=$(awk '{
  u=$1;
  d=int(u/86400); h=int((u%86400)/3600); m=int((u%3600)/60);
  if (d>0) printf "%dd %dh %dm", d, h, m;
  else printf "%dh %dm", h, m;
}' /proc/uptime)

# --- Wi-Fi / IP (iwd, falling back to NetworkManager), Tailscale, public IP ---
ssid=""
if ((IS_WIRELESS)); then
  if have iwctl; then
    ssid=$(iwctl station "$NET_IFACE" show 2>/dev/null | awk -F'Connected network' '/Connected network/{print $2}' | xargs)
  fi
  if [ -z "$ssid" ] && have nmcli; then
    ssid=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '$1=="yes"{print $2; exit}')
  fi
  [ -z "$ssid" ] && ssid="(disconnected)"
fi

local_ip="n/a"
[ -n "$NET_IFACE" ] && local_ip=$(ip -4 -o addr show "$NET_IFACE" 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
[ -z "$local_ip" ] && local_ip="n/a"

ts_ip=""
if have tailscale; then
  ts_ip=$(tailscale ip -4 2>/dev/null)
  [ -z "$ts_ip" ] && ts_ip="offline"
fi

pub_ip="n/a"
if have curl; then
  pub_ip_cache="$CACHE_DIR/public_ip"
  if [ -f "$pub_ip_cache" ] && [ "$(( $(date +%s) - $(stat -c %Y "$pub_ip_cache") ))" -lt "$PUBLIC_IP_TTL" ]; then
    pub_ip=$(cat "$pub_ip_cache")
  else
    fetched=$(curl -s --max-time 1.5 "$PUBLIC_IP_URL" 2>/dev/null | tr -d '[:space:]')
    if [ -n "$fetched" ]; then
      pub_ip="$fetched"
      printf '%s' "$pub_ip" > "$pub_ip_cache"
    elif [ -f "$pub_ip_cache" ]; then
      pub_ip=$(cat "$pub_ip_cache")
    fi
  fi
fi

# --- Docker containers: distinguish "not installed" from "none running" ---
docker_lines=()
docker_available=0
if have docker; then
  if docker_ps_output=$(docker ps --format '{{.Names}} ({{.Status}})' 2>/dev/null); then
    docker_available=1
    if [ -n "$docker_ps_output" ]; then
      mapfile -t docker_lines <<< "$docker_ps_output"
    else
      docker_lines=("(no containers running)")
    fi
  else
    docker_lines=("(docker daemon unavailable)")
  fi
else
  docker_lines=("(docker not installed)")
fi

# --- Top 3 CPU-consuming processes ---
# Processes younger than 2s are excluded: ps's %cpu (cputime/etime) is
# noisy/inflated for just-started processes, which would otherwise make
# this script's own short-lived helpers (ps, awk, itself) show up.
top_proc_lines=()
if have ps; then
  mapfile -t top_proc_lines < <(ps -eo comm,%cpu,etimes --sort=-%cpu --no-headers |
    awk '$3>=2 {printf "%s: %s%%\n", $1, $2}' | head -n 3)
fi

# --- Build plain-text lines to measure the widest one ---
cpu_line="CPU: ${cpu}%"
ram_line="RAM: ${mem_used_gib} / ${mem_total_gib} GiB (${mem_pct}%)"
swap_line="Swap: ${swap_used_gib} / ${swap_total_gib} GiB (${swap_pct}%)"
disk_line="Disk (${DISK_PATH}): ${disk_used_gib} / ${disk_total_gib} GiB (${disk_pct}%)"
uptime_line="Uptime: ${uptime_str}"
temp_pkg_line="CPU Temp: ${pkg_temp}°C"
ssid_line="SSID: ${ssid}"
ip_line="IP: ${local_ip}"
vps_line="VPS: ${pub_ip}"
ts_line="Tailscale: ${ts_ip}"
net_line="Up: ${up_kbs} KB/s  Down: ${down_kbs} KB/s"

max_len=0
for line in "$cpu_line" "$ram_line" "$swap_line" "$disk_line" "$uptime_line" \
            "$temp_pkg_line" "$core_temp_line" \
            "$ssid_line" "$ip_line" "$vps_line" "$ts_line" "$net_line" \
            "${docker_lines[@]}" "${top_proc_lines[@]}"; do
  len=${#line}
  ((len > max_len)) && max_len=$len
done
((max_len < 20)) && max_len=20

cpu_bar=$(bar "$cpu" "$max_len")
mem_bar=$(bar "$mem_pct" "$max_len")
swap_bar=$(bar "$swap_pct" "$max_len")
disk_bar=$(bar "$disk_pct" "$max_len")
rule_line=$(rule "$max_len")

# --- Assemble the markup, section by section, skipping anything unavailable ---
# Each element is one visual line; an empty element renders as a blank line.
lines=()

if [ -n "$pkg_temp" ]; then
  lines+=("<span foreground='$COLOR_LABEL'>CPU Temp:</span> ${pkg_temp}°C")
  [ -n "$core_temp_line" ] && lines+=("<span foreground='$COLOR_LABEL'>${core_temp_line}</span>")
  lines+=("")
fi

lines+=(
  "<span foreground='$COLOR_LABEL'>CPU:</span> ${cpu}%"
  "$cpu_bar"
  ""
  "<span foreground='$COLOR_LABEL'>RAM:</span> ${mem_used_gib} / ${mem_total_gib} GiB (${mem_pct}%)"
  "$mem_bar"
  ""
  "<span foreground='$COLOR_LABEL'>Swap:</span> ${swap_used_gib} / ${swap_total_gib} GiB (${swap_pct}%)"
  "$swap_bar"
  ""
  "<span foreground='$COLOR_LABEL'>Disk (${DISK_PATH}):</span> ${disk_used_gib} / ${disk_total_gib} GiB (${disk_pct}%)"
  "$disk_bar"
  ""
  "<span foreground='$COLOR_LABEL'>Uptime:</span> ${uptime_str}"
  ""
  "$rule_line"
)

((IS_WIRELESS)) && lines+=("<span foreground='$COLOR_LABEL'>SSID:</span> ${ssid}")
lines+=("<span foreground='$COLOR_LABEL'>IP:</span> ${local_ip}")
lines+=("<span foreground='$COLOR_LABEL'>VPS:</span> ${pub_ip}")
[ -n "$ts_ip" ] && lines+=("<span foreground='$COLOR_LABEL'>Tailscale:</span> ${ts_ip}")
lines+=("<span foreground='$COLOR_LABEL'>Up:</span> ${up_kbs} KB/s  <span foreground='$COLOR_LABEL'>Down:</span> ${down_kbs} KB/s")
lines+=("")
lines+=("$rule_line")

for line in "${docker_lines[@]}"; do
  color="$COLOR_OK"
  [ "$docker_available" -eq 0 ] && color="$COLOR_DIM"
  lines+=("<span foreground='${color}'>${line}</span>")
done

if [ ${#top_proc_lines[@]} -gt 0 ]; then
  lines+=("")
  lines+=("$rule_line")
  lines+=("<span foreground='$COLOR_LABEL'>Top Processes:</span>")
  for line in "${top_proc_lines[@]}"; do
    lines+=("<span foreground='$COLOR_OK'>${line}</span>")
  done
fi

out=""
first=1
for l in "${lines[@]}"; do
  if [ "$first" -eq 1 ]; then
    out="$l"
    first=0
  else
    out+="\\n$l"
  fi
done

printf '{"text":"%s"}\n' "$out"
