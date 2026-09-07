# powercontext-dsh · PowerContext for DeepSeek Harness

[PowerContext](https://github.com/oceanbase/powercontext) 的 DeepSeek Harness 常驻插件（官方 `integrations/dsh` 集成的独立发行副本）。

一键把会话工作移交与项目记忆接入 dsh：模型每步前自动召回有界上下文（预置注入），19 个 `pc_*` 工具覆盖记忆/交接/经验/技能/审阅，`/pc doctor` 检查连通性。Server 不可用时 fail-open，绝不阻塞正常工作。

English: a thin DeepSeek Harness plugin that connects to a running PowerContext Server over HTTP — bounded context recall before each model step, `pc_*` tools for memory/handoff/experience/skills, and `/pc doctor` for liveness. Fail-open by design.

## 安装 / Install

```sh
dsh plugin --profile web add dsh-powercontext
```

或从本仓库目录：`dsh plugin --profile web add <本目录>`

前置条件（一次性）：

```powershell
# 1) PowerContext Server（Python/uv）
uv tool install --force "powercontext[cli,server] @ git+https://github.com/oceanbase/powercontext.git@master"
powercontext server run   # 默认 http://127.0.0.1:8000（SQLite 本地存储）

# 2)（推荐）Server 常驻看门狗：登录自启 + 每分钟巡检自动拉起
#    见 scripts/server-watchdog.ps1（本仓库附带），注册为计划任务：
$wd = "<repo>\scripts\server-watchdog.ps1"
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$wd`""
$tLogon  = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$tRepeat = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration (New-TimeSpan -Days 3650)
Register-ScheduledTask -TaskName 'PowerContext-Server-Watchdog' -Action $action -Trigger $tLogon,$tRepeat -Force
```

## 能力 / What you get

- **自动召回**：`agent/pre-step` 每模型步前 `POST /v1/context/prepare` 注入有界上下文；当前输入自动捕获为 Source 证据（`POWERCONTEXT_DSH_CAPTURE_PROMPTS=false` 可关）
- **19 个 pc_\* 工具**：memory（remember/list/get/revise/retire）、handoff（activate/prepare/finalize/commit/continue）、experience/skill（generate/get）、search、review（list/get）
- **`/pc` 命令**：`/pc doctor` 连通性与就绪检查
- **安全边界**：审阅类变更为显式人工 `/pc review` 命令；破坏性与管理类 OpenAPI 操作不暴露为模型工具
- **fail-open**：Server 不可用时不阻塞 DSH 正常工作

## 配置

patch config（cordis.patch.yml）：`baseUrl` / `timeoutMs` / `requestTimeoutMs` / `maxBytes` / `capturePrompts` / `flushOnCapture`；环境变量前缀 `POWERCONTEXT_DSH_`（`BASE_URL` / `AUTHORIZATION` / `SCOPE_ID` / `CAPTURE_PROMPTS` / `FLUSH_ON_CAPTURE`）。召回返回的上下文按**不可信历史**标注——当前用户、仓库与系统指令始终优先。

## Windows 常驻适配说明

本副本附带 `scripts/server-watchdog.ps1`（PowerContext Server 计划任务看门狗：登录自启 + 每分钟健康巡检 + 崩溃自动拉起），并在插件内以 node_modules junction 指向宿主 dsh 部署的 `@deepseek-ai/*` 官方包实例（不向 profile node_modules 复制官方包）。其余与上游一致，跟随上游更新。

## 上游与许可

- 上游项目：https://github.com/oceanbase/powercontext （Apache-2.0）
- 本仓库为官方 `integrations/dsh` 插件的独立发行副本，跟随上游更新
