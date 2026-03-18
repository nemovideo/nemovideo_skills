# Changelog

All notable changes to NemoVideo Skill are documented in this file.

## [1.5] - 2026-03-18

### Added
- 任务详情链接新增 `skill_name`、`skill_version`、`skill_source` 查询参数，支持归因追踪
- `$SKILL_SOURCE` 运行时动态检测（按优先级：环境变量 → 安装路径 → git remote → `unknown`）

### Fixed
- **导出 402 错误**：修复 §3.5 render/export、§3.2 upload、§3.3 credits、§3.4 state 的 curl 示例缺少归因 header（`X-Skill-Source` 等），导致后端无法识别 Skill 请求，匿名用户积分耗尽后导出被拒

### Changed
- 归因变量 `$SKILL_NAME`、`$SKILL_VERSION`、`$SKILL_SOURCE` 统一定义，所有 header 和链接引用变量而非硬编码
- 归因 header 说明从 "All API requests MUST include" 升级为 **CRITICAL** 级别，明确标注缺失会导致导出失败
- frontmatter `name` 从 `nemo_video` 改为 `nemo-video`（与实际 kebab-case 一致）
- 移除 frontmatter 中硬编码的 `source` 字段，改由 agent 运行时推断

## [1.4] - 2025-03-18

### Changed
- 任务详情页链接格式改为 `/workspace/claim?token=...&task=...&session=...`，支持免登录直接打开项目

## [1.3] - 2025-03-10

### Added
- SSE 请求体新增 `user_id` 字段，改善用户标识
- 新增 `X-Client-Id` 持久化建议，避免频繁触发 IP 级限流

### Changed
- 明确只需 `NEMO_TOKEN` + `session_id` 即可发起请求

## [1.2] - 2025-03-03

### Added
- 视频导出后自动附带任务详情链接，用户可在浏览器中打开项目

## [1.1] - 2025-02-25

### Added
- 新增 `NEMO_WEB_URL` 环境变量，支持自定义前端地址
- 创建会话后自动提供浏览器打开链接

### Changed
- 优化 API 请求 header 说明

## [1.0] - 2025-02-18

### Added
- 建立版本管理体系（`VERSION` 文件 + SKILL.md frontmatter 同步）
- `bump-version.sh` 脚本自动更新所有版本号

### Changed
- API 路径统一使用 `me` 代替硬编码 user_id
- 简化 Token 和 Session 管理说明
- 明确匿名 Token 不过期

## [0.x] - Pre-release

### Added
- 初始发布：SSE 对话、视频生成、编辑、导出全流程
- 匿名账号自动创建（100 免费积分）
- 归因 header（`X-Skill-Source`, `X-Skill-Version`, `X-Skill-Platform`）
- `X-Client-Id` 支持与匿名 Token 申请
- Lambda 分布式渲染导出
- GUI 翻译层：拦截后端 GUI 指令，转为 API 操作
- SSE 断线恢复机制
- 静默响应兜底（无文本时自动查询状态并汇报）
