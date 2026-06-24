# 联机架构

## 模式决策

正式联机模式为两人对战，不开发三人以上同桌。核心原因是百金池、共享读牌、一次性手牌和当前暗牌推理都是一对一零和结构；多人模式会产生围攻、串通、等待时间和信息归属争议。未来可以在现有协议上增加观战、好友和锦标赛，而不改变战斗规则。

## 回合协议

1. 双方提交服务器校验后的密封意图。
2. 两边都提交后进入洞察阶段。
3. 玩家可以抢用全局共享读牌，并在最终锁定前改招。
4. 双方锁定后由服务器结算并广播完整揭示。
5. 双方都确认准备后开始下一轮。

所有手牌、钻石、契约限制、金币、惩罚、失忆和胜负均由服务器维护。客户端无法直接提交分数或结果。

## 生产环境

- WebSocket：`wss://tucao.aixiaolv.icu/ws`
- Docker 服务：`/opt/devils-game`
- 数据库：`/opt/devils-game/data/devils_game.db`
- OpenResty 反代：`/opt/1panel/www/sites/tucao.aixiaolv.icu/proxy/devils-game.conf`
- 原站点配置备份：`/opt/devils-game/backups/`

服务提供公开匹配、私人房间、90 秒断线续局、认输、SQLite WAL 持久化、Elo 排名、健康检查和日志轮转。

## 1.1.1 Hotfix

- 修复胜负回合结算时服务端使用错误胜者编号导致的 WebSocket 异常关闭。
- 客户端每 20 秒发送一次 `ping` 心跳，服务端返回 `pong`。
- OpenResty WebSocket 读写超时提高到 3600 秒，避免长时间思考或等待房间时被反代关闭。
