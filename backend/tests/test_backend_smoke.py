import asyncio
import importlib
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import AsyncMock, patch

from fastapi.testclient import TestClient


def _clear_app_modules() -> None:
    for module_name in list(sys.modules):
        if module_name == "app" or module_name.startswith("app."):
            sys.modules.pop(module_name, None)


class BackendSmokeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls._temp_dir = tempfile.TemporaryDirectory()
        sqlite_path = Path(cls._temp_dir.name) / "test_backend.db"

        os.environ["SQLITE_PATH"] = str(sqlite_path)
        os.environ["JWT_SECRET_KEY"] = "test-access-secret"
        os.environ["JWT_REFRESH_SECRET_KEY"] = "test-refresh-secret"
        os.environ["ADMIN_API_TOKEN"] = "test-admin-token"
        os.environ["OPENWEATHER_API_KEY"] = "test-weather-key"
        os.environ["HUGGING_FACE_API_KEY"] = "test-hf-key"
        os.environ["HUGGING_FACE_MODEL"] = "test-model"
        os.environ["HUGGING_FACE_API_URL"] = "https://example.test/chat"
        os.environ["RATE_LIMIT_GENERAL_PER_MINUTE"] = "500"
        os.environ["RATE_LIMIT_AUTH_PER_MINUTE"] = "500"
        os.environ["RATE_LIMIT_CHAT_PER_MINUTE"] = "500"
        os.environ["RATE_LIMIT_WRITE_PER_MINUTE"] = "500"

        _clear_app_modules()

        cls.app_main = importlib.import_module("app.main")
        cls.models = importlib.import_module("app.api.db.models")
        cls.database = importlib.import_module("app.api.db.database")
        cls.security = importlib.import_module("app.security")
        cls.weather = importlib.import_module("app.api.weather")
        cls.chat = importlib.import_module("app.api.chat")
        cls.treatments = importlib.import_module("app.api.treatments")

        cls.app_main.should_refresh = lambda: False

        async def _noop_refresh() -> dict:
            return {}

        cls.app_main.refresh_treatments_json = _noop_refresh

        cls._client_manager = TestClient(cls.app_main.app)
        cls.client = cls._client_manager.__enter__()

    @classmethod
    def tearDownClass(cls) -> None:
        cls._client_manager.__exit__(None, None, None)
        cls.database.engine.dispose()
        cls._temp_dir.cleanup()

    def setUp(self) -> None:
        with self.database.SessionLocal() as db:
            db.query(self.models.DiseaseReport).delete()
            db.query(self.models.User).delete()
            db.commit()

        self.security.rate_limiter._buckets.clear()
        self.weather._weather_cache.clear()

    def test_auth_report_and_sync_flow(self) -> None:
        register_response = self.client.post(
            "/api/v1/auth/register",
            json={"email": "farmer@example.com", "password": "Password123"},
        )
        self.assertEqual(register_response.status_code, 201)
        register_payload = register_response.json()
        access_token = register_payload["access_token"]
        refresh_token = register_payload["refresh_token"]

        me_response = self.client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        self.assertEqual(me_response.status_code, 200)
        self.assertEqual(me_response.json()["email"], "farmer@example.com")

        login_response = self.client.post(
            "/api/v1/auth/login",
            json={"email": "farmer@example.com", "password": "Password123"},
        )
        self.assertEqual(login_response.status_code, 200)

        refresh_response = self.client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": refresh_token},
        )
        self.assertEqual(refresh_response.status_code, 200)
        refreshed_access = refresh_response.json()["access_token"]
        auth_headers = {"Authorization": f"Bearer {refreshed_access}"}

        report_response = self.client.post(
            "/reports",
            headers=auth_headers,
            json={
                "crop": "tomato",
                "disease": "early_blight",
                "confidence": 0.91,
                "region": "Punjab",
                "device_id": "unit-test",
            },
        )
        self.assertEqual(report_response.status_code, 201)
        self.assertEqual(report_response.json()["crop"], "tomato")

        reports_response = self.client.get("/reports?limit=5", headers=auth_headers)
        self.assertEqual(reports_response.status_code, 200)
        self.assertEqual(len(reports_response.json()), 1)

        sync_status_response = self.client.get("/sync/status", headers=auth_headers)
        self.assertEqual(sync_status_response.status_code, 200)
        self.assertEqual(sync_status_response.json()["status"], "ok")

        sync_bulk_response = self.client.post(
            "/sync/bulk",
            headers=auth_headers,
            json=[
                {
                    "crop": "wheat",
                    "disease": "rust",
                    "confidence": 0.73,
                    "region": "Punjab",
                    "device_id": "unit-test",
                    "created_at": "2026-05-09T18:06:26.741800Z",
                }
            ],
        )
        self.assertEqual(sync_bulk_response.status_code, 200)
        self.assertEqual(sync_bulk_response.json()["saved"], 1)

    def test_password_hash_round_trip_uses_bcrypt(self) -> None:
        password_hash = self.security.hash_password("Password123")
        self.assertTrue(password_hash.startswith("$2"))
        self.assertTrue(
            self.security.verify_password("Password123", password_hash),
        )
        self.assertFalse(
            self.security.verify_password("WrongPassword", password_hash),
        )

    def test_register_rejects_passwords_over_bcrypt_limit(self) -> None:
        response = self.client.post(
            "/api/v1/auth/register",
            json={"email": "longpass@example.com", "password": "x" * 73},
        )
        self.assertEqual(response.status_code, 400)
        self.assertEqual(
            response.json()["detail"],
            "Password too long. Maximum 72 bytes.",
        )

    def test_weather_summary_combines_current_and_forecast(self) -> None:
        current_payload = {
            "name": "Ludhiana",
            "dt": 1778349515,
            "main": {
                "temp": 31.87,
                "feels_like": 30.46,
                "temp_min": 31.87,
                "temp_max": 31.87,
                "pressure": 1005,
                "humidity": 28,
            },
            "weather": [{"main": "Clear", "description": "clear sky"}],
            "wind": {"speed": 2.39, "deg": 94},
            "clouds": {"all": 0},
            "visibility": 10000,
            "sys": {"sunrise": 1778285161, "sunset": 1778334007},
        }
        forecast_payload = {
            "city": {"name": "Ludhiana"},
            "list": [
                {
                    "dt": 1778457600,
                    "main": {
                        "temp": 29.68,
                        "feels_like": 28.60,
                        "temp_min": 29.68,
                        "temp_max": 29.68,
                        "pressure": 1003,
                        "humidity": 32,
                    },
                    "weather": [{"main": "Clear", "description": "clear sky"}],
                    "wind": {"speed": 4.07, "deg": 129},
                    "clouds": {"all": 3},
                    "visibility": 10000,
                    "sys": {"pod": "n"},
                }
            ],
        }

        with patch.object(
            self.weather,
            "_forward",
            new=AsyncMock(side_effect=[current_payload, forecast_payload]),
        ) as mocked_forward:
            response = self.client.get(
                "/api/v1/weather/summary?city=Ludhiana&language=en",
            )

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["current"]["name"], "Ludhiana")
        self.assertEqual(payload["forecast"]["city"]["name"], "Ludhiana")
        self.assertEqual(mocked_forward.await_count, 2)

    def test_chat_and_quick_ask_return_provider_reply(self) -> None:
        class _FakeResponse:
            status_code = 200

            def raise_for_status(self) -> None:
                return None

            def json(self) -> dict:
                return {
                    "choices": [
                        {
                            "message": {
                                "content": "Water early morning to reduce evaporation.",
                            }
                        }
                    ],
                    "usage": {"total_tokens": 42},
                }

        class _FakeAsyncClient:
            def __init__(self, *args, **kwargs) -> None:
                pass

            async def __aenter__(self):
                return self

            async def __aexit__(self, exc_type, exc, tb) -> bool:
                return False

            async def post(self, *args, **kwargs):
                return _FakeResponse()

        with patch.object(self.chat.httpx, "AsyncClient", _FakeAsyncClient):
            chat_response = self.client.post(
                "/api/v1/chat",
                json={
                    "message": "Best time to water tomato plants?",
                    "language": "en",
                    "history": [],
                },
            )
            quick_ask_response = self.client.post(
                "/api/v1/quick-ask",
                json={
                    "question": "How often should I water tomato plants in heat?",
                    "language": "en",
                    "crop": "tomato",
                },
            )

        self.assertEqual(chat_response.status_code, 200)
        self.assertEqual(
            chat_response.json()["reply"],
            "Water early morning to reduce evaporation.",
        )
        self.assertEqual(quick_ask_response.status_code, 200)
        self.assertEqual(
            quick_ask_response.json()["reply"],
            "Water early morning to reduce evaporation.",
        )

    def test_public_treatments_endpoint_returns_known_entry(self) -> None:
        sample_treatments = {
            "early_blight": {
                "en": {
                    "name": "Early Blight",
                    "treatment": "Use the fallback treatment",
                    "source": "built-in",
                }
            }
        }

        with patch.object(
            self.treatments,
            "load_treatments",
            return_value=sample_treatments,
        ):
            response = self.client.get("/api/v1/treatments/early_blight")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["en"]["name"], "Early Blight")
        self.assertEqual(response.json()["en"]["source"], "built-in")

    def test_database_connection_uses_sqlite_in_smoke_tests(self) -> None:
        self.assertEqual(self.database.get_database_backend_name(), "sqlite")
        self.assertTrue(self.database.get_redacted_database_url().startswith("sqlite:///"))


if __name__ == "__main__":
    unittest.main()
