#!/bin/bash
# WeatherGemma Custom Script Example
# Fetches weather via Open-Meteo and outputs JSON for WeatherGemma.
# Usage:  ./weather-gemma-script.sh --lat 37.7749 --lon -122.4194 --units fahrenheit

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --lat)   LAT="$2";   shift ;;
        --lon)   LON="$2";   shift ;;
        --units) UNITS="$2"; shift ;;
        *) echo "{\"error\":\"unknown arg $1\"}"; exit 1 ;;
    esac
    shift
done

: "${LAT:=37.7749}"
: "${LON:=-122.4194}"
: "${UNITS:=fahrenheit}"

TEMP_UNIT="$UNITS"

curl -s --max-time 10 \
  "https://api.open-meteo.com/v1/forecast?latitude=$LAT&longitude=$LON&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m&temperature_unit=$TEMP_UNIT&wind_speed_unit=mph" \
| python3 -c "
import json, sys
try:
    raw = json.load(sys.stdin)
    c = raw['current']
    out = {
        'temperature':    c['temperature_2m'],
        'feelsLike':      c['apparent_temperature'],
        'humidity':       c['relative_humidity_2m'],
        'windSpeed':      c['wind_speed_10m'],
        'conditionCode':  c['weather_code']
    }
    print(json.dumps(out))
except Exception as e:
    print(json.dumps({'error': str(e)}), file=sys.stderr)
    sys.exit(1)
"
