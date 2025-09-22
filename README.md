# Skybound Courier

一个使用 **Phaser 3 + Vite + TypeScript** 重建的 2D 街机风格小游戏。玩家控制飞行员在天空竞技场中收集能量球并躲避红色风暴，目标是在 90 秒内尽可能获得更高分数。

## 核心玩法

- 使用键盘方向键操控主角，全方位飞行。
- 收集金色能量球提升分数并触发轻微的速度冲刺感。
- 躲避持续出现并巡航的红色风暴（敌对体）。被命中会损失护盾，护盾归零则任务失败。
- 存活 90 秒即可顺利完成任务，并根据表现给出统计面板。

## 技术栈与架构

| 层级 | 说明 |
| --- | --- |
| 游戏引擎 | [Phaser 3](https://phaser.io/phaser3) Arcade Physics，实现 2D 场景、碰撞与动画。 |
| 构建工具 | [Vite](https://vitejs.dev/) + TypeScript，提供现代化开发体验与热更新。 |
| 组织结构 | `scenes/` 管理 Boot/Menu/Game/UI 四个场景；`entities/` 存放主角实体；`utils/` 封装工具方法与常量。 |
| 资源处理 | 通过 `BootScene` 动态绘制并生成纹理，减少静态资源依赖，便于快速迭代。 |

## 快速开始

```bash
npm install
npm run dev
```

开发服务器启动后访问命令行输出的地址（默认 `http://localhost:5173`），即可试玩。

### 生产构建

```bash
npm run build
npm run preview
```

- `npm run build` 会生成优化后的产物。
- `npm run preview` 提供本地静态预览服务。

## 代码风格

- TypeScript + ESLint 默认规则（由 Vite 模板提供）。
- 充分利用 Phaser 的事件系统，`GameScene` 与 `UIScene` 之间通过事件通讯，保持关注点分离。

## 后续优化方向

- 增加多种敌人行为模式与技能。
- 引入音效、粒子特效，丰富临场感。
- 使用 Zustand 等状态管理工具，实现关卡编辑器或回放功能。

欢迎在此基础上继续扩展更多玩法！
