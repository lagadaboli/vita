"""Application configuration via pydantic-settings."""

from pathlib import Path

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """VITA backend configuration. Values can be overridden via environment variables."""

    # Database
    database_url: str = "sqlite+aiosqlite:///./vita.db"

    # Polling intervals (seconds)
    rotimatic_poll_interval: float = 30.0
    instant_pot_poll_interval: float = 15.0
    idle_poll_interval: float = 300.0

    # Retry
    max_retry_backoff: float = 3600.0  # 1 hour cap
    base_retry_delay: float = 5.0

    # Grocery worker
    grocery_fetch_interval: float = 21600.0  # 6 hours

    # Kitchen FSM timeouts (seconds)
    cooking_timeout: float = 14400.0  # 4 hours
    meal_ready_timeout: float = 7200.0  # 2 hours
    meal_consumed_auto_reset: float = 1800.0  # 30 minutes

    # Rotimatic
    rotimatic_base_url: str = ""
    rotimatic_mdns_type: str = "_rotimatic._tcp.local."

    # Instant Pot / Instant Connect
    instant_connect_api_url: str = "https://api.instantconnect.com"
    instant_connect_token: str = ""

    # Grocery scraping
    instacart_session_cookie: str = ""
    doordash_session_cookie: str = ""

    model_config = {"env_prefix": "VITA_"}


settings = Settings()
