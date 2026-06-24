from __future__ import annotations

import asyncio
import json
import os
import random
import re
import secrets
import time
import uuid
from dataclasses import dataclass

from fastapi import FastAPI, WebSocket, WebSocketDisconnect

from game_rules import CONTRACTS, OnlineMatch
from storage import Storage

APP_VERSION = "1.1.1"
NAME_PATTERN = re.compile(r"^[\w\u4e00-\u9fff -]{1,16}$")
ROOM_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
storage = Storage(os.environ.get("DATABASE_PATH", "/data/devils_game.db"))
app = FastAPI(title="Devils Game Multiplayer", version=APP_VERSION)


@dataclass
class Client:
    player_id: str
    name: str
    token: str
    socket: WebSocket
    match_id: str = ""
    room_code: str = ""


clients: dict[str, Client] = {}
matches: dict[str, OnlineMatch] = {}
rooms: dict[str, dict] = {}
queue: list[str] = []
queue_contracts: dict[str, str] = {}
active_assignments: dict[str, str] = {}
disconnect_deadlines: dict[str, float] = {}
state_lock = asyncio.Lock()


@app.get("/health")
async def health() -> dict:
    return {"ok": True, "version": APP_VERSION, "online": len(clients), "matches": len(matches)}


@app.get("/stats")
async def stats() -> dict:
    return {**storage.stats(), "online": len(clients), "active_matches": len(matches)}


@app.get("/leaderboard")
async def leaderboard() -> dict:
    return {"season": "zero", "entries": storage.leaderboard()}


async def send(client: Client, message_type: str, **payload) -> None:
    await client.socket.send_text(json.dumps({"type": message_type, **payload}, ensure_ascii=False))


async def send_error(client: Client, code: str, message: str) -> None:
    await send(client, "error", code=code, message=message)


async def broadcast_match(match: OnlineMatch, message_type: str, **payload) -> None:
    for player_id in match.players:
        client = clients.get(player_id)
        if client:
            await send(client, message_type, **payload, state=match.private_state(match.players.index(player_id)))


def clean_name(value) -> str:
    name = str(value or "旅人").strip()
    return name if NAME_PATTERN.fullmatch(name) else "旅人-" + secrets.token_hex(2)


def create_room_code() -> str:
    while True:
        code = "".join(secrets.choice(ROOM_ALPHABET) for _ in range(6))
        if code not in rooms:
            return code


async def begin_match(player_ids: list[str], contract_id: str) -> OnlineMatch:
    match_id = uuid.uuid4().hex
    names = [clients[player_id].name for player_id in player_ids]
    match = OnlineMatch(match_id, player_ids, names, contract_id, random.SystemRandom().randint(1, 2**31 - 1))
    matches[match_id] = match
    for player_id in player_ids:
        clients[player_id].match_id = match_id
        clients[player_id].room_code = ""
        active_assignments[player_id] = match_id
    match.start_round()
    await broadcast_match(match, "match_started")
    await broadcast_match(match, "round_started")
    return match


async def handle_message(client: Client, message: dict) -> None:
    message_type = str(message.get("type", ""))
    async with state_lock:
        if message_type == "ping":
            await send(client, "pong", server_time=int(time.time()))
            return
        if message_type == "profile_update":
            client.name = clean_name(message.get("name"))
            storage.upsert_player(client.player_id, client.name, client.token)
            return await send(client, "profile_updated", name=client.name)
        if message_type == "queue_join":
            if client.match_id:
                return await send_error(client, "already_in_match", "你已经在对局中。")
            if client.player_id not in queue:
                queue.append(client.player_id)
            contract_id = str(message.get("contract_id", "standard"))
            if contract_id not in CONTRACTS:
                contract_id = "standard"
            queue_contracts[client.player_id] = contract_id
            await send(client, "queue_status", position=queue.index(client.player_id) + 1)
            available = [pid for pid in queue if pid != client.player_id and pid in clients and not clients[pid].match_id and queue_contracts.get(pid) == contract_id]
            if available:
                pair = [available[0], client.player_id]
                for pid in pair:
                    if pid in queue:
                        queue.remove(pid)
                    queue_contracts.pop(pid, None)
                await begin_match(pair, contract_id)
            return
        if message_type == "queue_leave":
            if client.player_id in queue:
                queue.remove(client.player_id)
            queue_contracts.pop(client.player_id, None)
            return await send(client, "queue_status", position=0)
        if message_type == "room_create":
            code = create_room_code()
            contract_id = str(message.get("contract_id", "standard"))
            rooms[code] = {"host": client.player_id, "contract_id": contract_id if contract_id in CONTRACTS else "standard"}
            client.room_code = code
            return await send(client, "room_created", code=code)
        if message_type == "room_join":
            code = str(message.get("code", "")).strip().upper()
            room = rooms.get(code)
            if not room or room["host"] not in clients:
                return await send_error(client, "room_not_found", "房间不存在或已过期。")
            if room["host"] == client.player_id:
                return await send_error(client, "room_self_join", "不能加入自己创建的房间。")
            host_id = room["host"]
            rooms.pop(code, None)
            await begin_match([host_id, client.player_id], room["contract_id"])
            return
        if not client.match_id or client.match_id not in matches:
            return await send_error(client, "not_in_match", "当前没有可操作的联机对局。")
        match = matches[client.match_id]
        player = match.players.index(client.player_id)
        if message_type == "intent_submit":
            if not match.submit_intent(player, message.get("action", {})):
                return await send_error(client, "invalid_intent", "意图无效或已经提交。")
            await send(client, "intent_accepted", state=match.private_state(player))
            opponent = clients.get(match.players[1 - player])
            if opponent:
                await send(opponent, "opponent_intent", submitted=True)
            if match.phase == "insight":
                await broadcast_match(match, "insight_started")
            return
        if message_type == "reading_use":
            try:
                reading = match.use_reading(player)
            except ValueError:
                return await send_error(client, "reading_unavailable", "当前无法使用读牌。")
            await send(client, "reading_result", reading=reading, state=match.private_state(player))
            opponent = clients.get(match.players[1 - player])
            if opponent:
                await send(opponent, "shared_reading_used", state=match.private_state(1 - player))
            return
        if message_type == "action_lock":
            try:
                result = match.lock_action(player, message.get("action"))
            except ValueError:
                return await send_error(client, "invalid_lock", "最终行动无效或已经锁定。")
            await broadcast_match(match, "lock_status", locked=match.locked)
            if result is not None:
                await broadcast_match(match, "round_resolved", result=result)
                if match.match_over:
                    storage.record_match(match)
                    await broadcast_match(match, "match_finished")
                    for player_id in match.players:
                        active_assignments.pop(player_id, None)
                    matches.pop(match.match_id, None)
            return
        if message_type == "next_round_ready":
            if match.phase != "resolved":
                return await send_error(client, "round_not_resolved", "当前不能进入下一回合。")
            match.ready_next[player] = True
            await broadcast_match(match, "next_round_status", ready=match.ready_next)
            if all(match.ready_next):
                match.start_round()
                await broadcast_match(match, "round_started")
            return
        if message_type == "state_request":
            return await send(client, "state_sync", state=match.private_state(player))
        if message_type == "surrender":
            match.winner = 1 - player
            match.match_over = True
            match.phase = "finished"
            match.remaining_gold = 0
            storage.record_match(match)
            await broadcast_match(match, "match_finished", surrendered=player)
            for player_id in match.players:
                active_assignments.pop(player_id, None)
            matches.pop(match.match_id, None)
            return
        await send_error(client, "unknown_message", "未知协议消息。")


@app.websocket("/ws")
async def websocket_endpoint(socket: WebSocket) -> None:
    await socket.accept()
    client: Client | None = None
    try:
        raw = await asyncio.wait_for(socket.receive_text(), timeout=15)
        hello = json.loads(raw)
        if hello.get("type") != "hello":
            await socket.close(code=4001, reason="hello required")
            return
        token = str(hello.get("resume_token", ""))
        existing = storage.find_by_token(token) if token else None
        player_id = existing["player_id"] if existing else uuid.uuid4().hex
        name = clean_name(hello.get("name", existing["display_name"] if existing else "旅人"))
        token = existing["resume_token"] if existing else secrets.token_urlsafe(32)
        old = clients.get(player_id)
        if old:
            await old.socket.close(code=4002, reason="reconnected elsewhere")
        match_id = old.match_id if old else active_assignments.get(player_id, "")
        client = Client(player_id, name, token, socket, match_id, old.room_code if old else "")
        clients[player_id] = client
        disconnect_deadlines.pop(player_id, None)
        storage.upsert_player(player_id, name, token)
        await send(client, "welcome", player_id=player_id, resume_token=token, version=APP_VERSION, profile=storage.player_profile(player_id))
        if client.match_id in matches:
            match = matches[client.match_id]
            await send(client, "state_sync", state=match.private_state(match.players.index(player_id)))
        while True:
            raw = await socket.receive_text()
            try:
                message = json.loads(raw)
            except json.JSONDecodeError:
                await send_error(client, "invalid_json", "消息格式错误。")
                continue
            await handle_message(client, message)
    except (WebSocketDisconnect, asyncio.TimeoutError):
        pass
    finally:
        if client and clients.get(client.player_id) is client:
            clients.pop(client.player_id, None)
            if client.player_id in queue:
                queue.remove(client.player_id)
            queue_contracts.pop(client.player_id, None)
            for code, room in list(rooms.items()):
                if room["host"] == client.player_id:
                    rooms.pop(code, None)
            if client.match_id in matches and not matches[client.match_id].match_over:
                disconnect_deadlines[client.player_id] = time.time() + 90
                match = matches[client.match_id]
                opponent = clients.get(match.players[1 - match.players.index(client.player_id)])
                if opponent:
                    await send(opponent, "opponent_disconnected", reconnect_seconds=90)


@app.on_event("startup")
async def start_disconnect_guard() -> None:
    asyncio.create_task(disconnect_guard())


async def disconnect_guard() -> None:
    while True:
        await asyncio.sleep(5)
        async with state_lock:
            now = time.time()
            expired = [player_id for player_id, deadline in disconnect_deadlines.items() if deadline <= now]
            for player_id in expired:
                disconnect_deadlines.pop(player_id, None)
                match_id = active_assignments.get(player_id, "")
                match = matches.get(match_id)
                if not match or match.match_over:
                    continue
                loser = match.players.index(player_id)
                match.winner = 1 - loser
                match.match_over = True
                match.phase = "finished"
                match.remaining_gold = 0
                storage.record_match(match)
                await broadcast_match(match, "match_finished", disconnected_forfeit=loser)
                for participant in match.players:
                    active_assignments.pop(participant, None)
                matches.pop(match.match_id, None)
