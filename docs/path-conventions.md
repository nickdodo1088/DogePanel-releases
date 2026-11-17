# 文档路径与脱敏约定

文档中的仓库文件链接使用相对路径。部署与测试记录使用下列逻辑目录别名，不公开维护者机器上的真实绝对路径。

| 别名 | 含义 |
| --- | --- |
| `REPO_DIR` | 当前 DogePanel 源码仓库根目录 |
| `PANEL_DIR` | 当前服务器的面板安装目录 |
| `WWW_DIR` | 软件、备份和相关站点资源的管理目录 |
| `WEBSITE_ROOT` | 当前配置的网站根目录前缀 |
| `LEGACY_WEBSITE_ROOT` / `LEGACY_PANEL_DIR` | 迁移前的站点或面板目录 |
| `PRIVATE_DIR` | 维护者私有资料和验收回执目录，不属于公开部署内容 |
| `REFERENCE_DIR` | 外部参考项目所在的工作区目录 |
| `TESTBOX_DIR` | 隔离测试环境目录 |
| `TMP_DIR` / `RUNTIME_DIR` / `BOOT_DIR` | 当前系统的临时、运行时和启动目录 |
| `SYSTEM_DIR` | 当前系统文件树；后续部分保留配置或程序的相对位置 |
| `HOME_DIR` / `CACHE_DIR` | 当前用户目录和可复用缓存目录 |
| `SOFTWARE_DIR` / `DATA_DIR` / `MOUNT_DIR` | 其他软件、数据和挂载位置 |
| `WEBSITE_PARENT_DIR` / `COPY_REPO_DIR` | 网站前缀的父级目录及发布副本仓库 |
| `APPLICATION_DIR` / `SDK_DIR` / `NOLOGIN_HOME` | 应用源码、构建工具及不可登录账号的逻辑位置 |
| `SYSTEM_ROOT` / `JAIL_ROOT` | 系统文件树根和 SFTP 隔离环境内部的根 |
| `LEGACY_NGINX_DIR` / `LEGACY_RECYCLE_DIR` | 历史环境中的旧 Nginx 和回收站目录 |

例如 `PANEL_DIR/data/db`、`WWW_DIR/server/php/84`、`WEBSITE_ROOT/product/member_api` 均为逻辑相对路径。它们不是已经定义的 Shell 环境变量，也不是要求用户新建的同名目录。历史设计及验收记录中的示例，需先替换成当前机器的实际配置；新部署优先按[新手指南](deployment/DogePanel.md)通过面板和 `dgpctl` 操作。

HTTP 地址、API 路由、网站路由和协议格式不属于本机文件路径。不要为了转换路径而改动接口语义。

不在文档、截图、提交信息中写入密码、令牌、Cookie、私钥、真实安全入口或维护者私有文件内容。截图使用实际面板，隐藏敏感标识；性能回执中的路径可匿名化，测量数字与摘要不应伪造或改写。

JSON 性能记录中的目录也使用这些别名，数字和原始摘要保持原记录。匿名化后的记录供阅读，不能作为原始文件的逐字校验对象；复测应使用源脚本及管理员保留的原始回执。
