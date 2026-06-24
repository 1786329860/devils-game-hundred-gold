from __future__ import annotations

import asyncio
import json

import websockets

URL = "wss://tucao.aixiaolv.icu/ws"


async def send(socket, message_type: str, **payload) -> None:
    await socket.send(json.dumps({"type": message_type, **payload}, ensure_ascii=False))


async def receive_until(socket, wanted: str) -> dict:
    for _ in range(30):
        message = json.loads(await asyncio.wait_for(socket.recv(), timeout=10))
        if message.get("type") == "error":
            raise AssertionError(message)
        if message.get("type") == wanted:
            return message
    raise AssertionError(f"did not receive {wanted}")


async def connect_player(name: str):
    socket = await websockets.connect(URL, open_timeout=10)
    await send(socket, "hello", name=name, client_version="e2e")
    welcome = await receive_until(socket, "welcome")
    assert welcome["resume_token"]
    return socket, welcome


def first_available(state: dict) -> int:
    hand = state["hand"]
    for piece in range(5):
        status = hand[str(piece)]
        if status["available"] and not status["banned"]:
            return piece
    raise AssertionError("no available piece")


async def main() -> None:
    player_a, welcome_a = await connect_player("E2E-A")
    player_b, welcome_b = await connect_player("E2E-B")
    try:
        await send(player_a, "room_create", contract_id="standard")
        room = await receive_until(player_a, "room_created")
        await send(player_b, "room_join", code=room["code"])
        await receive_until(player_a, "match_started")
        await receive_until(player_b, "match_started")
        round_a = await receive_until(player_a, "round_started")
        round_b = await receive_until(player_b, "round_started")
        rounds = 0
        while True:
            rounds += 1
            available_a = [int(piece) for piece, status in round_a["state"]["hand"].items() if status["available"] and not status["banned"]]
            available_b = [int(piece) for piece, status in round_b["state"]["hand"].items() if status["available"] and not status["banned"]]
            piece_a = max(available_a)
            piece_b = min(available_b)
            await send(player_a, "intent_submit", action={"piece": piece_a, "upgrade": 0, "display": piece_a})
            await send(player_b, "intent_submit", action={"piece": piece_b, "upgrade": 0, "display": piece_b})
            await receive_until(player_a, "insight_started")
            await receive_until(player_b, "insight_started")
            await send(player_a, "action_lock", action={"piece": piece_a, "upgrade": 0, "display": piece_a})
            await send(player_b, "action_lock", action={"piece": piece_b, "upgrade": 0, "display": piece_b})
            result_a = await receive_until(player_a, "round_resolved")
            await receive_until(player_b, "round_resolved")
            if result_a["state"]["match_over"]:
                finished_a = await receive_until(player_a, "match_finished")
                await receive_until(player_b, "match_finished")
                assert finished_a["state"]["remaining_gold"] == 0
                break
            await send(player_a, "next_round_ready")
            await send(player_b, "next_round_ready")
            round_a = await receive_until(player_a, "round_started")
            round_b = await receive_until(player_b, "round_started")
        assert rounds <= 5
        print(json.dumps({"ok": True, "rounds": rounds, "players": [welcome_a["player_id"], welcome_b["player_id"]]}))
    finally:
        await player_a.close()
        await player_b.close()


if __name__ == "__main__":
    asyncio.run(main())
