"""
System Settings Endpoint — provides dynamic monetization control panel variables,
pricing settings, founder caps, and announcement banners.
"""

from fastapi import APIRouter
from app.db import supabase

router = APIRouter(prefix="/settings", tags=["settings"])

DEFAULT_SETTINGS = {
    "monetization_enabled": "false",
    "growth_phase_duration_days": "365",
    "founder_cap_per_city": "20",
    "flagship_annual_price_usd": "9.99",
    "group_one_time_fee_usd": "4.99",
    "announcement_banner_enabled": "false",
    "announcement_banner_text": "",
}


@router.get("")
def get_app_settings():
    """Fetch complete dictionary of dynamic app settings and monetization controls."""
    settings = dict(DEFAULT_SETTINGS)
    try:
        res = supabase.table("app_settings").select("key, value").execute()
        if res.data:
            for row in res.data:
                k = row.get("key")
                v = row.get("value")
                if k and v is not None:
                    settings[k] = str(v)
    except Exception as e:
        print("Note on app_settings fetch:", e)

    return settings
