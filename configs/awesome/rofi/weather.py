#!/usr/bin/env python3
"""
Waybar Weather Script - Day/Night Aware
Location: Odendaalsrus, Free State, South Africa
"""

import json
import requests
import os
from datetime import datetime, timedelta
import warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)

# ===== CONFIGURATION =====
API_KEY = "8bcd81d07c9ef5a23dd709885254d64c"
LAT = -27.7333
LON = 27.0667
UNITS = "metric"
LANG = "en"
CITY_NAME = "Odendaalsrus"
CACHE_FILE = "/tmp/waybar-weather-cache.json"
CACHE_DURATION = 300

# Day icons
WEATHER_ICONS_DAY = {
    200: "⛈️", 201: "⛈️", 202: "⛈️", 300: "🌦️", 301: "🌦️", 302: "🌧️",
    500: "🌦️", 501: "🌧️", 502: "🌧️", 503: "🌧️", 504: "🌧️", 511: "🌨️",
    600: "🌨️", 601: "❄️", 602: "❄️", 611: "🌨️", 612: "🌨️", 613: "🌨️",
    701: "🌫️", 711: "🌫️", 721: "🌫️", 731: "🌫️", 741: "🌫️", 751: "🌫️",
    800: "☀️", 801: "🌤️", 802: "⛅", 803: "☁️", 804: "☁️"
}

# Night icons (moon instead of sun)
WEATHER_ICONS_NIGHT = {
    200: "⛈️", 201: "⛈️", 202: "⛈️", 300: "🌦️", 301: "🌦️", 302: "🌧️",
    500: "🌦️", 501: "🌧️", 502: "🌧️", 503: "🌧️", 504: "🌧️", 511: "🌨️",
    600: "🌨️", 601: "❄️", 602: "❄️", 611: "🌨️", 612: "🌨️", 613: "🌨️",
    701: "🌫️", 711: "🌫️", 721: "🌫️", 731: "🌫️", 741: "🌫️", 751: "🌫️",
    800: "🌙", 801: "☁️", 802: "⛅", 803: "☁️", 804: "☁️"
}

def get_cached_data():
    try:
        if os.path.exists(CACHE_FILE):
            with open(CACHE_FILE, 'r') as f:
                cache = json.load(f)
            if datetime.now().timestamp() - cache.get('timestamp', 0) < CACHE_DURATION:
                return cache.get('data')
    except: pass
    return None

def save_cache(data):
    try:
        with open(CACHE_FILE, 'w') as f:
            json.dump({'timestamp': datetime.now().timestamp(), 'data': data}, f)
    except: pass

def wind_direction(deg):
    directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", 
                  "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
    try:
        return directions[int((float(deg) + 11.25) / 22.5) % 16]
    except:
        return "N"

def get_moon_phase(date=None):
    if date is None:
        date = datetime.now()
    known_new_moon = datetime(2000, 1, 6, 18, 14, 0)
    synodic_month = 29.53058867
    delta = date - known_new_moon
    days = delta.total_seconds() / 86400
    phase = (days % synodic_month) / synodic_month
    
    phases = [
        (0.00, 0.03, "🌑", "New Moon"), (0.03, 0.22, "🌒", "Waxing Crescent"),
        (0.22, 0.28, "🌓", "First Quarter"), (0.28, 0.47, "🌔", "Waxing Gibbous"),
        (0.47, 0.53, "🌕", "Full Moon"), (0.53, 0.72, "🌖", "Waning Gibbous"),
        (0.72, 0.78, "🌗", "Last Quarter"), (0.78, 0.97, "🌘", "Waning Crescent"),
        (0.97, 1.00, "🌑", "New Moon"),
    ]
    for start, end, emoji, name in phases:
        if start <= phase < end:
            return phase, emoji, name
    return phase, "🌙", "Unknown"

def is_nighttime(sunrise, sunset, tz_offset=0):
    """Check if current time is between sunset and sunrise."""
    try:
        now = datetime.now()
        sunrise_dt = datetime.utcfromtimestamp(sunrise) + timedelta(seconds=tz_offset)
        sunset_dt = datetime.utcfromtimestamp(sunset) + timedelta(seconds=tz_offset)
        
        current_mins = now.hour * 60 + now.minute
        sunrise_mins = sunrise_dt.hour * 60 + sunrise_dt.minute
        sunset_mins = sunset_dt.hour * 60 + sunset_dt.minute
        
        if current_mins >= sunset_mins or current_mins < sunrise_mins:
            return True
        return False
    except:
        return False

def format_time(timestamp, tz_offset=0):
    try:
        utc_time = datetime.utcfromtimestamp(timestamp)
        local_time = utc_time + timedelta(seconds=tz_offset)
        return local_time.strftime("%H:%M")
    except:
        return "??:??"

def fetch_weather_data():
    try:
        current_url = f"https://api.openweathermap.org/data/2.5/weather?lat={LAT}&lon={LON}&appid={API_KEY}&units={UNITS}&lang={LANG}"
        current_response = requests.get(current_url, timeout=10)
        
        if current_response.status_code != 200:
            return None, None, f"API Error: {current_response.status_code}"
        
        current = current_response.json()
        if current.get("cod") != 200:
            return None, None, current.get("message", "Unknown error")
        
        forecast_url = f"https://api.openweathermap.org/data/2.5/forecast?lat={LAT}&lon={LON}&appid={API_KEY}&units={UNITS}&lang={LANG}"
        forecast_response = requests.get(forecast_url, timeout=10)
        forecast = forecast_response.json() if forecast_response.status_code == 200 else None
        
        return current, forecast, None
    except Exception as e:
        return None, None, str(e)

def process_daily_forecast(forecast_data, tz_offset):
    if not forecast_data or "list" not in forecast_data:
        return []
    
    daily_data = {}
    for item in forecast_data["list"]:
        dt = datetime.utcfromtimestamp(item["dt"]) + timedelta(seconds=tz_offset)
        day_key = dt.strftime("%Y-%m-%d")
        
        if day_key not in daily_data:
            daily_data[day_key] = {
                "date": dt.strftime("%a %d"),
                "temp_min": item["main"]["temp_min"],
                "temp_max": item["main"]["temp_max"],
                "weather": item["weather"][0],
                "icon": WEATHER_ICONS_DAY.get(item["weather"][0]["id"], "🌡️"),
                "description": item["weather"][0]["description"].title()
            }
        else:
            daily_data[day_key]["temp_min"] = min(daily_data[day_key]["temp_min"], item["main"]["temp_min"])
            daily_data[day_key]["temp_max"] = max(daily_data[day_key]["temp_max"], item["main"]["temp_max"])
    
    return list(daily_data.values())[:5]

def main():
    cached = get_cached_data()
    if cached:
        print(json.dumps(cached))
        return
    
    current, forecast, error = fetch_weather_data()
    
    if error:
        print(json.dumps({"text": "🔗 --°", "tooltip": f"Weather Error: {error[:100]}"}))
        return
    
    if not current:
        print(json.dumps({"text": "🔗 --°", "tooltip": "Weather API Error: No data received"}))
        return
    
    try:
        main_data = current["main"]
        wind_data = current.get("wind", {})
        weather = current["weather"][0]
        sys_data = current.get("sys", {})
        
        temp = main_data.get("temp", 0)
        feels_like = main_data.get("feels_like", temp)
        humidity = main_data.get("humidity", 0)
        pressure = main_data.get("pressure", 0)
        
        wind_speed_ms = wind_data.get("speed", 0)
        wind_speed_kmh = round(wind_speed_ms * 3.6, 1)
        wind_deg = wind_data.get("deg", 0)
        wind_dir = wind_direction(wind_deg)
        
        weather_code = weather.get("id", 800)
        tz_offset = current.get("timezone", 0)
        
        # Check if it's nighttime
        sunrise_ts = sys_data.get("sunrise", 0)
        sunset_ts = sys_data.get("sunset", 0)
        is_night = is_nighttime(sunrise_ts, sunset_ts, tz_offset)
        
        # Get appropriate icon for day/night
        if is_night:
            weather_icon = WEATHER_ICONS_NIGHT.get(weather_code, "🌡️")
        else:
            weather_icon = WEATHER_ICONS_DAY.get(weather_code, "🌡️")
        
        weather_desc = weather.get("description", "Unknown").title()
        sunrise = format_time(sys_data.get("sunrise", 0), tz_offset)
        sunset = format_time(sys_data.get("sunset", 0), tz_offset)
        
        moon_phase_val, moon_emoji, moon_name = get_moon_phase()
        daily_forecast = process_daily_forecast(forecast, tz_offset)
        
        output = {}
        output["text"] = f"{weather_icon} {temp:.0f}°"
        
        day_night = "🌙 Night" if is_night else "☀️ Day"
        tooltip = f"<b>📍 {CITY_NAME}</b>\n"
        tooltip += f"<b>{day_night}</b>\n"
        tooltip += f"<b>{weather_icon} {weather_desc}</b> • {temp:.0f}°C\n"
        tooltip += f"Feels like: {feels_like:.0f}°C\n"
        tooltip += f"💧 Humidity: {humidity}%\n"
        tooltip += f"🌡️ Pressure: {pressure} hPa\n"
        tooltip += f"🌬️ Wind: {wind_dir} {wind_speed_kmh} km/h\n"
        tooltip += f"🌅 Sunrise: {sunrise} • 🌇 Sunset: {sunset}\n"
        tooltip += f"{moon_emoji} {moon_name}\n"
        
        if daily_forecast:
            tooltip += f"\n<b>📅 5-Day Forecast:</b>\n"
            for day in daily_forecast:
                tooltip += f"{day['date']} {day['icon']} {day['temp_min']:.0f}°/{day['temp_max']:.0f}° {day['description'][:15]}\n"
        
        tooltip += f"\n<i>Last updated: {datetime.now().strftime('%H:%M:%S')}</i>"
        
        output["tooltip"] = tooltip
        
        save_cache(output)
        print(json.dumps(output))
        
    except Exception as e:
        print(json.dumps({"text": "❌", "tooltip": f"Parse Error: {str(e)[:100]}"}))

if __name__ == "__main__":
    main()
