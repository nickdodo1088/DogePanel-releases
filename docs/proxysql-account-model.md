# ProxySQL 业务账号与多库配置修正

> 文件位置采用逻辑相对路径；执行历史示例前，请按[路径约定](path-conventions.md)替换为当前机器配置。

## 账号边界

`admin-admin_credentials` 是面板管理 ProxySQL 的私有管理凭据；`mysql-monitor_username/password` 用于后台探测；`mysql_users` 是应用连接 ProxySQL、代理再连接后端的业务认证配置。普通模式使用与目标 MySQL 一致的业务凭据，不建立一个可任意映射所有后端账号的面板“逻辑账号”。

不同应用、数据库可使用不同账号密码。读写分离的一组主从需要提供相同业务账号及相应库的权限；独立服务器使用独立主机组，业务账号的 `default_hostgroup` 决定默认目标。`default_schema` 只是初始选库，不授予或限制权限；授权必须在 MySQL 管理中配置。同一实例不能因为默认数据库不同，就重复创建同名、不同密码的前端业务账号。

## 本轮实现

1. 初始化向导分成数据库地址、业务账号与健康监控、检查配置三个明确步骤。支持添加多条业务账号，各自配置用户名、密码、默认数据库、连接上限、备注。单库连接池也支持多账号。
2. 对每个账号逐一验证目标主库 / 从库和数据库可访问性，不以一个账号的成功代替其他账号验证。默认使用独立 Monitor 账号，不自动创建后端 MySQL 账号或修改授权、数据、复制关系。
3. 初始化仍只写空配置，不能覆盖既有配置。该向导初始化一组后端；其他独立后端和账号通过服务器、账号页配置主机组。已有账号管理保留按账号指定主机组与默认库的能力。
4. 新模板读写规则限定业务用户名，不将一个数据库组的全局 `^SELECT` 规则套给未来添加的其他数据库账号。规则命中、运行时生效和持久化均需校验，失败恢复快照。
5. 保留旧客户端单账号请求兼容；新请求使用 `accounts` 数组。账号、密码不得进入日志、错误、快照说明或截图。

## 验证

覆盖两个业务库、两个不同密码的账号、重复用户名、无效数据库、第二账号验证失败时零写入、模板限定账号以及单库模式。先在隔离实例验证，再更新本机面板；不修改宿主机数据库账号或 ProxySQL 配置。

## 官方依据

- [MySQL 用户配置与主机组](https://proxysql.com/documentation/main-runtime/mysql-tables/#mysql_users)
- [认证方法](https://proxysql.com/documentation/authentication-methods/)
- [配置的内存、运行时与磁盘层](https://proxysql.com/documentation/configuring-proxysql/)

## 本轮验证结果

- 初始化向导已支持多个业务账号，各自独立填写密码、默认数据库、连接上限和备注，专用监控账号单独配置。旧的单账号 API 请求继续兼容。
- 隔离 Debian 12 中复用已验证的 ProxySQL 3.1.12 程序，使用两个 MySQL 后端、两个业务数据库和不同密码的账号，实测普通 SELECT 走读库、锁定读与 UPDATE 走写库。第二个账号错误密码时初始化失败、配置仍为空；第二账号也未获得第一个数据库的权限。
- 浏览器回归包含多账号填写及实际提交结构；不在宿主机创建数据库账号或导入测试后端。
- 本机已更新现有 Core / Agent，版本保持 `v2.3.2-dp.44`。回退点为 `PRIVATE_DIR/dogepanel-handoff/codex-website-create-https-20261116/before-update/` 和 `verified-update/`；面板外业务进程和 41 份原生配置保持一致。

本机实际登录检查已通过，相关 API 无失败请求。创建页、HTTPS 免费证书页和 ProxySQL 第二步业务账号表单均已保存并人工检查截图。本轮清理完成任务的重复程序和旧回退副本约 1.13 GiB，保留最新两份完整配套回退、最近两版升级 original、源码差异、测试结果、脚本和依赖缓存。清单：私有工作目录下 `cleanup.json`。

正式发布与本机部署已完成：[dp.45 发布记录](release-dp45.md)。当前配套回退统一保留在 `PRIVATE_DIR/dogepanel-handoff/codex-release-dp45-20261117/` 的 `before-update/` 和 `verified-update/`；上文旧本机预览回退已按清理策略替换。
