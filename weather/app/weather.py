"""Weather lookup against weatherapi.com.

Moved out of app.py so the worker can use it without importing Flask
or loading the ~32k cities list the web needs for autocomplete.
"""
import logging
import os
from datetime import datetime

import requests

log = logging.getLogger(__name__)


def get_weather(weather_location):
    """call the weather API for a location and return a filtered 7-day forecast, or None"""
    api_key = os.getenv("API_WEATHER")

    try:
        response = requests.get(
            "https://api.weatherapi.com/v1/forecast.json",
            params={"key": api_key, "q": weather_location, "days": 7},
            timeout=10,
        )
    except requests.exceptions.RequestException as e:
        log.error("weather API request failed: %s", type(e).__name__)
        return None

    try:
        data = response.json()
    except ValueError:
        log.error("weather API returned non-JSON (HTTP %s)", response.status_code)
        return None

    if not response.ok or "error" in data:
        log.warning("weather API error (HTTP %s): %s", response.status_code,
                    data.get("error", {}).get("message", "unknown"))
        return None

    return {
        "city": data["location"]["name"],
        "country": data["location"]["country"],
        "days": get_days_table(data),
    }


def get_day_month(date_str):
    """'2026-10-10' -> 'Saturday 10-10'"""
    return datetime.strptime(date_str, "%Y-%m-%d").strftime("%A %m-%d")


def get_days_table(data):
    """per day: date -> average/day/night temperature and humidity"""
    days = {}
    for day in data["forecast"]["forecastday"]:
        hours = day.get("hour", [])
        days[get_day_month(day["date"])] = {
            "average_temperature": day["day"]["avgtemp_c"],
            "average_humidity": day["day"]["avghumidity"],
            "day_temperature": hours[12]["temp_c"] if len(hours) > 12 else day["day"]["avgtemp_c"],
            "night_temperature": hours[0]["temp_c"] if hours else day["day"]["avgtemp_c"],
        }
    return days
