"""VITA Backend — FastAPI application with lifespan management."""

from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.database import init_db
from app.services.kitchen_fsm import KitchenFSM
from app.database import async_session


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup: init DB, ensure kitchen FSM initial state. Shutdown: stop workers."""
    await init_db()

    # Ensure kitchen FSM has an initial state
    async with async_session() as session:
        fsm = KitchenFSM(session)
        await fsm.ensure_initial_state()

    yield

    # Shutdown: workers would be stopped here when enabled


app = FastAPI(title="VITA Backend", version="0.2.0", lifespan=lifespan)


# Register routers
from app.api.appliances import router as appliances_router
from app.api.grocery import router as grocery_router
from app.api.kitchen import router as kitchen_router
from app.api.meals import router as meals_router
from app.api.notifications import router as notifications_router
from app.api.sync import router as sync_router

app.include_router(appliances_router)
app.include_router(meals_router)
app.include_router(kitchen_router)
app.include_router(grocery_router)
app.include_router(sync_router)
app.include_router(notifications_router)


@app.get("/health")
async def health():
    return {"status": "ok"}
