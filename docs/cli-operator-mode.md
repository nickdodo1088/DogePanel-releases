# 命令行管理员与面板普通运维模式

> 文件位置采用逻辑相对路径；执行历史示例前，请按[路径约定](path-conventions.md)替换为当前机器配置。

## 目标与信任边界

服务器管理员使用 root/sudo 执行 `dgpctl`，决定网页能够执行的操作。普通运维模式
是主机策略，优先于网页账号、API Key 和 MFA；网页只显示状态，不提供解除入口。
没有标记文件时保持当前行为，升级不会自行封锁现有面板。

由 `dgpctl` 原子建立 `<PANEL_DIR>DATA_DIR/security/operator-restricted`，目录 root:root
0700、标记 0600。逐级检查属主、权限和符号链接；标记损坏或权限不安全时，高风险
操作拒绝执行。关闭模式只能由本机 root CLI 删除标记。运行时重新核对，不仅启动时读取。
此机制限制网页经正常接口取得主机权限，不宣称能抵抗已经控制 root Agent 的任意代码执行。

## 操作矩阵

| 操作 | 普通运维模式 |
| --- | --- |
| 本机、SSH、容器终端及脚本库执行 | 禁止；已有终端在授权复核时关闭 |
| 文件管理 | 即使已验证 MFA，仍通过网站目录内的 chroot/上传 UID 分发；禁止越界、危险链接和提权操作 |
| Nginx、PHP、MySQL、Redis 等参数 | 保留受管表单和安全配置修改；代码加载、运行身份、任意宿主路径等变化禁止 |
| 安装受信软件、服务启停及普通网站管理 | 保留；自定义 Compose、镜像构建、任意模块/脚本等已有高风险入口禁止 |
| Shell 任务新增、导入、执行内容及身份修改 | 仅 root CLI；网页只读，不得用任务类型伪装或导入绕过 |
| CLI 审核过的 Shell 任务 | 网页可改时间、启停、查看记录及执行既定任务；执行定义必须与 root 审核摘要相同 |
| 旧 Shell 任务 | 不自动视为管理员审核；root 在 CLI 查看并批准后可在受限模式运行 |
| 证书额外 Shell 钩子、Supervisor 自定义命令、主机高风险管理 | 禁止网页创建/更改；普通证书续期与受管服务操作保留 |
| 主机网络/DNS/hosts、防火墙规则写入、任意 PID 终止、SSH 密钥删除、SSH 审计清理 | 仅服务器管理员；状态、日志及受管服务正常启停仍可查看/操作 |
| 公共文件分享及网站文件前缀变更 | 受限模式禁止，防止用旧分享能力或重设前缀绕过文件范围；普通网站目录内管理保留 |

Shell 审核摘要覆盖脚本快照、解释器、用户、容器、命令及其他执行参数，保存在
root Agent 数据库。网页调度更新使用独立、字段受限的入口，只改时间，不走全量任务
更新；运行时重新读取任务及核对摘要，旧调度闭包不能继续执行被替换的定义。
CLI 管理的任务无需依赖面板账号开启 MFA；其他现有授权行为维持原规则。
新 CLI 任务默认使用 `nobody`，实际业务优先选择对应的独立服务用户；需要 root 时
显式指定 `--user root`。审核覆盖脚本快照，不会证明其读取的外部脚本/程序也可信；
root 任务不得执行普通运维或网站用户可写的脚本、配置或可替换路径。
低权限运行不开放面板私有目录：快照暂存于 `<WWW_DIR>/server/dogepanel-cron/`，
父目录由 root 管理，执行目录/文件仅向目标服务组开放读取，执行后删除脚本文件。

## 实施顺序

1. 实现标记文件的安全读写和错误时拒绝；加入中文默认的 dgpctl 菜单、英文选项、
   状态/启用/关闭命令，离线也能恢复策略。
2. Agent 在实际路由与资源边界执行限制，复用逐路由授权目录；Core 返回只读状态并
   拒绝危险传输，MFA 证明不能覆盖主机限制。检查私有 RPC、已连接终端与后台钩子。
3. 增加 root-only Shell 任务管理 RPC、CLI 菜单/命令与审核摘要；网页提供只读执行
   定义及独立调度编辑，导入/克隆/类型变更均不能创建新的可执行 Shell。
4. 前端显示模式及操作原因；文件、终端、任务及配置继续由后端校验。增加所有受影响
   语言包，避免提示用户去启用 MFA 解除主机策略。
5. 按影响范围测试：真实注册路由、伪造头、MFA、符号链接/权限损坏、越界文件、
   Shell 字段篡改、热切换与旧任务迁移。隔离环境做 Core→Agent 和 CLI/浏览器冒烟，
   再更新本机预览，版本不变；不重编译原生应用或发行版矩阵。

## 参考依据

- [OWASP 授权指南](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html)：
  默认拒绝、每次请求校验，并验证实际资源与操作，不能只隐藏按钮。
- [Cockpit 权限设计](https://cockpit-project.org/guide/latest/privileges)及
  [Polkit 应用指南](https://www.freedesktop.org/software/polkit/docs/latest/polkit-apps.html)：
  非特权界面与特权机制分离。本项目复用已有私有 Agent，不新增可任意执行命令的代理。
- [Saltzer/Schroeder 权限设计论文](https://www.andrew.cmu.edu/course/18-330/2025s/reading/Saltzer_Schroeder_Protection_of_Information_in_Computer_Systems.pdf)：
  最小权限、完整仲裁、权限分离；本轮通过 root CLI 与网页角色分开落实这些原则。
- [systemd 执行隔离](https://www.freedesktop.org/software/systemd/man/latest/systemd.exec)：
  保持非 root Web 和现有写目录限制；只读目录仍可能包含可连接的 Unix socket，
  所以私有 Agent 必须独立授权，不能只依赖文件系统只读挂载。

## Debian 同版本每日维护

### dgpctl 语言与动态密码管理

`dgpctl` 默认中文，与系统 locale、面板网页语言独立；数字菜单 34 或 `--language en`
切换本次调用语言，升级不覆盖已有面板语言。升级包替换控制脚本和语言文件，保留安装
目录、端口、入口及账号配置，旧面板无需重装即可使用新菜单。

数字菜单 24 提供 Google 动态密码状态、当前二维码、绑定、动态码测试、重新绑定和
关闭。命令为 `dgpctl mfa status|show|bind|verify|reset|disable`；`reset` 生成新绑定，
只有新动态码验证成功才替换旧密钥。`reset mfa` 保留旧命令兼容，表示关闭并清除绑定。

仅本机 root 可以通过受 SO_PEERCRED 检查的私有 Agent 接口操作。显示二维码、生成
绑定及输入验证码要求真实终端；密钥和验证码不进入命令行参数、普通日志或网页接口。
绑定使用加密随机密钥，标准 6 位、30 秒 TOTP；测试不消耗登录验证码，不签发网页
高权限凭证。取消或验证失败保留旧绑定；成功变更撤销原有高权限凭证、关闭网页终端，
重启 Core 以退出旧会话，业务服务不重启。关闭动态密码不解除服务器上的普通运维模式。

### 实施前复核修订

本次复核补充下列约束，后续实现以本节为准：

- 使用面板独立的官方 `.sources`、APT 配置、索引和下载目录，不覆盖 `SYSTEM_DIR/etc/apt` 的
  管理员/云厂商/第三方源。保留系统 dpkg 状态与 hold/pinning，来源限定 Debian 官方
  archive keyring；仓库的 Origin 文本不能代替签名信任。
- 使用独立 systemd 一次性服务执行维护，面板重启不终止它。启用时记录并暂停原生
  `apt-daily-upgrade.timer`，停用后恢复其原先状态；保留原生包事务与锁。不能杀掉正在
  升级的服务，也不能让两套安装定时器同时生效。定时检查只使用本机 root 策略。
- 启用所需的 Debian 原生组件由独立准备任务安装并模拟验证；准备失败不启动每日
  定时器。网页只有状态、历史及增量日志接口；安装组件、启停策略和手动运行均为
  root CLI 操作，网页的 MFA、API Key 和普通运维权限都不能代替 OS peer UID。
- 管理员启用一次后，普通软件包每日自动维护，不需要面板逐次确认。自动维护明确排除
  内核、引导器、initramfs 工具、固件/微码及 DKMS；相关依赖不能绕过原生升级器黑名单。
- 更新阶段的中止采用上游支持的步骤边界退出，不对 dpkg 使用硬超时或 SIGKILL；
  缓存刷新和只读探测可以有超时。进度持久化，进程异常退出显示中断待检查。
- 启动预检查逐项报告通过/失败/无法确认，容器、未知引导器、未知 Secure Boot 状态
  不得合成为“可以安全重启”。本功能不提供自动重启或跨大版本升级入口。
- 独立任务日志、上游 dpkg 日志均限制体积和保留天数；网页读取有游标和批次上限。
  当前任务不能被保留策略删掉；过期日志在任务边界清理，不增加高频全盘扫描。

### 版本、范围与授权

识别 Debian 11/bullseye、12/bookworm、13/trixie 的真实发行版与架构，锁定代号，
禁止使用会随发布变化的 `stable/oldstable` 作为自动维护目标；只更新当前大版本的
官方软件包，不自动进行 11→12、12→13 或切换第三方发行版。主机管理员通过 CLI
启用每日维护、指定维护窗口和源策略；普通运维只查看状态、候选、进度及错误日志。
首次启用先做只读检查与升级模拟，不在开发宿主直接运行 apt 安装/升级。

**支持期限必须准确显示**：Debian 官方公告确认 11 的 LTS 已于 2026-08-31 结束，
不再提供后续官方安全更新。仍可识别并报告其已配置源中的更新，但不能把“无候选”
标成安全、自动接入付费第三方 ELTS 或跳过签名/有效期检查。12 的 LTS 到 2028-06-30；
13 的完整支持到 2028-08-09，LTS 到 2030-06-30，支持架构按当前官方资料核对。
过期、架构不受支持均单独提示；软件包是否仍有修复不能仅凭发行版支持期限推断，
引导管理员安排跨版本升级。依据：[Debian 11 官方终止公告](https://www.debian.org/News/2026/20260831)、
[Debian LTS](https://wiki.debian.org/LTS)。

### HTTPS 镜像策略

自动判断使用主机配置的公网出口 IP 与本地 GeoIP 数据，不用访问者 IP 或系统语言
推断；提供 CLI 的 `auto/cn/global` 覆盖，记录判断依据。无法可靠判断时使用官方 HTTPS
源并显示结果。大陆候选为 `https://mirrors.aliyun.com/debian` 与
`https://mirrors.aliyun.com/debian-security`；海外使用 `https://deb.debian.org/debian`、
`https://security.debian.org/debian-security`。

识别传统 sources.list 和 deb822 .sources；独立来源保留需要的组件与当前架构，固定
Debian 官方 Signed-By，不整文件覆盖云厂商/管理员配置。候选必须通过 HTTPS 证书、
官方 InRelease 签名、代号和架构校验；独立配置原子写入。镜像无对应版本时报告失败，不能
改成 HTTP、关闭签名、忽略过期或擅自切换发行版。参考：[阿里云 Debian 镜像说明](https://developer.aliyun.com/mirror/debian/)。

HTTPS 之外仍由 APT 验证签名、索引与软件包校验和；不能把换到 HTTPS 镜像视为完成
来源认证。保留 `Check-Date`、`Check-Valid-Until`；时钟异常、元数据过期、代号变化或
签名失败均暂停并报告，不用 `trusted=yes`、`--allow-unauthenticated` 或关闭日期检查
绕过。镜像返回旧索引不能显示为本次成功检查；记录最后成功刷新时间，区分未刷新与
没有更新。参考：[apt-secure](https://manpages.debian.org/trixie/apt/apt-secure.8.en.html)、
[sources.list](https://manpages.debian.org/trixie/apt/sources.list.5.en.html)。

### 每日执行与交互处理

优先复用 Debian 的 unattended-upgrades/APT 机制，不另造包依赖解析器；使用单实例
systemd timer/service，与 apt-daily、dpkg 锁协调，随机错峰。先模拟目标、依赖和删除
清单，拒绝跨发行版、未认证包和意外移除关键包；不强杀持锁进程，不循环重试失败任务。
维护模式覆盖当前版本官方安全与稳定更新；管理员可进一步选择仅安全更新。

配置使用独立的本地配置，保留发行包自带文件。覆盖 `Origins-Pattern` 等列表时
先显式清空原列表再设置当前代号的官方来源，避免列表追加意外放行第三方源或其他
发行版；尊重管理员的 hold/pinning。检测现有 apt-daily 调度和升级进程，选择单一执行
入口，不能留下两套每日安装器。[上游 README](https://github.com/mvo5/unattended-upgrades/blob/main/README.md)
说明了本地覆盖、来源列表合并与最小升级步骤的具体行为。

使用非交互 debconf、保留现有配置的 dpkg 策略（`--force-confdef --force-confold`），
针对实际安装版本检查 needrestart 配置，以只列出需重启服务的方式避免提示框等待。
保留 `.dpkg-dist/.dpkg-old` 信息供人工合并。不能假定这些参数会禁止每个软件包的
维护脚本重启服务；模拟及维护窗口须明确列出可能受影响的服务，特殊交互包转为待人工
处理。SSH、网络和正在运行的业务不以通用脚本粗暴停用。

APT/dpkg 更新不是原子事务；中断后记录具体失败包与 dpkg 状态，不宣称能整体回滚，
不自动执行不受限的 `dist-upgrade`、强制依赖修复、清空锁文件或删除旧内核。
依据：[Debian 自动维护](https://wiki.debian.org/PeriodicUpdates)、
[unattended-upgrades 手册](https://manpages.debian.org/trixie/unattended-upgrades/unattended-upgrade.8.en.html)。

### 内核与重启门禁

强制 `Automatic-Reboot=false`；每日维护不安装内核及启动链更新，候选包单独计数。
管理员另行安装内核后才产生“内核已安装／需要人工重启”状态，绝不从每日维护任务
重启主机。面板显示运行内核、已安装候选、失败原因和需重启服务。
重启仍是服务器管理员操作，不因允许普通任务启停而向运维开放。

提供只读启动预检查：dpkg 无未完成配置；`BOOT_DIR` 与 EFI 分区空间/挂载正常；目标
vmlinuz、模块目录、initramfs 均存在且可读取；initramfs 可列出且含当前存储/根文件系统
所需模块；DKMS 无失败；GRUB/实际 bootloader 的目标与引导条目匹配；已知 Secure Boot
状态与签名要求不冲突。保留正在运行及最近已验证内核，不自动删作回退的引导项。

预检查失败或无法识别定制引导/云平台启动方式时，标记“未通过／无法确认”，禁止面板
给出“可以安全重启”的结论，建议通过云控制台/带外入口人工处理。文件检查不能保证
真实硬件一定能启动；不得用容器验收代替虚拟机的 BIOS/UEFI 实际启动、失败内核和
回退测试。参考：[Debian 13 内核升级说明](https://www.debian.org/releases/trixie/release-notes/upgrading.en.html)。

### 日志、资源及验收

实时日志采用带游标的有界增量读取，记录阶段、包版本、退出码、耗时及失败摘要；
断线后可恢复查看，不能每次重读整份 apt/dpkg 日志。隐藏源 URL 中的账号/令牌；
日志轮换、保留天数和总量有上限，界面区分“检查完成／已下载／已安装／需重启／失败”。
后台无页面访问也会每日执行，页面只读取，不自行触发重复扫描。

先在隔离 Debian 11/12/13 验证源选择、过期支持、锁竞争、非交互配置、磁盘满、
网络/签名错误、失败维护脚本和日志恢复；内核在专用虚拟机验证启动与回退。完成这些
检查后再单独实施及授权开启真实主机每日升级，不能和本轮权限预览混为已经部署。

### 已研读的上游实现与落地约束

本轮实际下载并阅读上游文件，记录 URL、文件大小和 SHA-256 到私有研究回执
`PRIVATE_DIR/dogepanel-handoff/codex-operator-policy-20261117/research/sources.json`；这些是
研究快照，不作为安装时可变 master 分支的执行来源。实施时按目标 Debian 包版本适配。

| 一手资料/代码 | 重点及采用方式 |
| --- | --- |
| [unattended-upgrades README](https://github.com/mvo5/unattended-upgrades/blob/master/README.md)、`unattended-upgrade`、Debian 默认配置 | 读取最小升级步骤、配置提示检测、自动重启、清理与中断修复分支；复用其包事务，额外限制危险默认值 |
| [APT 定时服务](https://github.com/Debian/apt/blob/main/debian/apt-daily-upgrade.service)、[apt.systemd.daily](https://github.com/Debian/apt/blob/main/debian/apt.systemd.daily) | 已有调度、锁和时间戳，不能另起并发升级器，也不能用删锁解决冲突 |
| [Debian 管理员手册](https://www.debian.org/doc/manuals/debian-handbook/sect.regular-upgrades.en.html)、[dpkg 官方 FAQ](https://wiki.debian.org/Teams/Dpkg/FAQ) | 使用官方周期更新组件；锁文件存在不等于正在持锁，删除锁文件可能破坏包数据库 |
| [needrestart 源码](https://github.com/liske/needrestart/blob/master/needrestart)、[批处理协议](https://github.com/liske/needrestart/blob/master/README.batch.md) | 批处理明确不弹窗、不重启；解析运行/预期内核、服务和微码状态；未知状态保持未知 |
| [dpkg 手册](https://manpages.debian.org/trixie/dpkg/dpkg.1.en.html)、[ucf 手册](https://manpages.debian.org/trixie/ucf/ucf.1.en.html) | dpkg 配置和维护脚本生成配置是两条路径；保留旧配置也需覆盖 ucf，不能只设置 DEBIAN_FRONTEND |
| [Debian Security](https://www.debian.org/security/)、[官方维护手册](https://www.debian.org/doc/manuals/securing-debian-manual/index.en.html) | 区分软件包更新成功、仍运行旧库、尚无修复的漏洞及发行版结束维护；不能统一显示“已安全” |
| [NixOS 原始论文](https://nixos.org/~eelco/pubs/nixos-icfp2008-final.pdf) | 原子切换与回退需要完整系统模型支持；不能套用到原地 APT 更新，保留配置/内核不等于完整系统回滚 |
| [A Look In the Mirror，CCS 2008](https://theupdateframework.io/papers/attacks-on-package-managers-ccs2008.pdf)、[Mercury，USENIX ATC 2017](https://theupdateframework.io/papers/prevention-rollback-attacks-atc2017.pdf) | 学习镜像重放、冻结与回退攻击的威胁模型；结合当前 APT 日期/有效期机制落实，不把历史论文中的旧版 APT 缺陷当作当前结论 |

源码审查明确了以下必须显式设置、不能依赖默认值的事项：

1. `Automatic-Reboot=false`；`Remove-Unused-Kernel-Packages=false`、
   `Remove-New-Unused-Dependencies=false`、`Remove-Unused-Dependencies=false`，保留
   已验证回退内核；不自动 autoremove 或清除启动项。上游的旧内核自动清理默认可能开启。
2. `AutoFixInterruptedDpkg=false`；检测到中断状态转为失败待处理，不让上游默认分支
   隐式执行 `dpkg --configure -a`。管理员修复后重新模拟，再继续维护。
3. 在本次升级进程环境使用 `DEBIAN_FRONTEND=noninteractive`、
   `NEEDRESTART_MODE=l`、`APT_LISTCHANGES_FRONTEND=none`、`UCF_FORCE_CONFFOLD=1`，
   并检查实际 needrestart/ucf 版本与已有配置；不把这些变量永久写进全局系统环境。
4. 维护结束再执行一次 `needrestart -b`，解析 `KSTA=0` 为无法确认，`2/3` 为有待应用
   的内核变化；不依赖单个 `RUNTIME_DIR/reboot-required` 文件判断所有 Debian 内核。
5. 使用最小升级步骤，仅在安全的步骤边界暂停；超时不直接 SIGKILL 正在运行的 dpkg。
   APT 锁等待有上限，锁冲突成为可重试状态，配置/签名/dpkg 错误转为待人工处理。
6. 采集现有原生日志与任务退出状态，增量查看、限制缓存和轮换；不在网页打开时重新
   扫描全部进程或包。日志包含执行顺序及失败包，避免只保留最后一条笼统错误。

优先采用 Debian 原生无人值守组件，面板负责主机授权、保守配置、状态与日志。
不采用“每天 apt upgrade -y 然后 reboot”、自动跨大版本或自造依赖解析/内核回退工具。

### 后续实施拆分与验收门槛

1. 先提供只读环境/源/支持期限检查与模拟结果，建立执行状态、游标日志和失败分类。
2. 实现 root CLI 策略与原生无人值守组件集成；源、定时窗口和包范围的修改不能由普通
   网页运维提交任意命令或配置片段。默认关闭，启用前完成预检查。
3. 接入面板状态、实时日志、失败原因与内核待重启提示；新增页面不触发升级扫描。
4. 隔离 Debian 环境验收锁竞争、镜像故障、dpkg/ucf 交互、磁盘满和执行中断；虚拟机
   验收实际启动、失败内核与回退。只有通过对应检查后才能启用真实机器每日维护。

Debian 实现、验证结果及实际部署状态在完成后追加；研究与模拟不等于真实系统已升级。

## 普通运维模式实施与用法

已实现主机标记、Core/Agent 权限上限、已有终端关闭、网站文件范围、Shell 快照审核、
网页调度专用入口及中英文 CLI。升级保留既有行为；管理员主动启用后，即使面板账号
已通过动态密码验证，也不能解除主机上限。

运行 `sudo dgpctl`，数字菜单 **32** 管理普通运维模式、**33** 管理 Shell 任务、
**34** 切换本次菜单语言。默认中文；也支持 `sudo dgpctl --language en`。

```bash
sudo dgpctl security status
sudo dgpctl security enable
sudo dgpctl cron create --name nightly-report --spec '0 3 * * *' \
    --file PRIVATE_DIR/maintenance/report.sh --user nobody --timeout 300
sudo dgpctl cron list
sudo dgpctl cron show --id 12
sudo dgpctl cron approve --id 12
sudo dgpctl security disable
```

`approve` 仅用于查看并确认可信的旧任务；新建/更新通过 CLI 保存的快照直接审核。
`cron update` 要明确提交任务名、时间与脚本文件，重新替换审核定义；脚本内容不放入
命令行参数。脚本应选择实际所需的服务用户，只有确需系统管理时才使用 `--user root`。

实际验收：Agent/Core Go 测试、相关竞态检查、前端类型检查/单元测试及 ESLint 通过；
浏览器权限测试 9 项、安装器/CLI 检查 356 项通过。隔离容器的 22 项真实联调覆盖
密码及 TOTP 会话、MFA 不越权、文件 CRUD/越界、旧任务批准、调度字段伪造拒绝、
root 与 nobody 实际执行、非 root 伪造私有 RPC 失败，以及关闭模式后恢复原 MFA 权限。

本机已更新 Core、Agent、dgpctl 及中英文菜单，保持 `v2.3.2-dp.49`，没有正式发布。
真实浏览器重新登录和普通管理冒烟通过，无失败请求；Core 仍为 `dgp-panel-web` 并保持
`NoNewPrivileges`。业务服务主进程和受管配置哈希未变化，普通运维模式默认未启用。
部署时的首轮校验误将既有英文输出当作中文检查，已自动回退；改为显式选中文后重新
部署和验证通过，未改变原有语言设置。保留两份程序、数据库与配置配套回退备份；
测试、研究快照与本机验证回执位于 `PRIVATE_DIR/dogepanel-handoff/codex-operator-policy-20261117/`。

## Debian 维护实施记录

### 已实现的执行与权限边界

| 项目 | 实现 |
| --- | --- |
| 策略与任务状态 | `<PANEL_DIR>DATA_DIR/os-maintenance/`，root 私有目录；策略、历史和游标日志独立保存，不使用 Web 数据库授予权限 |
| APT 上下文 | `<WWW_DIR>/server/dogepanel-maintenance/`；独立官方源、索引、缓存和配置，保留系统 dpkg 状态、hold/pinning 与外来架构，不覆盖原有源 |
| 下载权限 | 公共 APT 元数据由 root 管理，仅 `lists/partial`、`archives/partial` 交给 `_apt`；不放宽公共父目录或面板私有目录 |
| 准备与模拟 | 检查真实 Debian 代号、dpkg 架构、支持期限、包管理锁及磁盘；准备 `unattended-upgrades`、`needrestart`，随后模拟；失败不启用每日调度 |
| 执行服务 | `dgpanel-os-maintenance.service`；准备、模拟、内核检查各用独立一次性服务；每日定时器按本地时间执行并最多错峰 10 分钟，错过窗口不会开机立即补跑 |
| 原生调度 | 启用时保存并暂停 `apt-daily-upgrade.timer`；停用面板维护后恢复原设置。当前事务完成前不恢复第二个安装调度器，也不终止 dpkg |
| 资源与中止 | 低 CPU/IO 调度优先级；包事务没有 SIGKILL 或硬超时，收到停止请求时由原生升级器在步骤边界退出；缓存刷新和只读探测有超时 |
| 日志 | 单任务面板日志上限 8 MiB；两份原生日志运行期间监测、超过 8 MiB 截断，检查间隔内可能暂时超过阈值；默认保留 3 天、历史总量 64 MiB，最多 32 条历史 |
| 页面读取 | 工具箱新增 `/toolbox/maintenance`；仅查询已保存状态和增量日志。单页读取不超过 64 KiB，浏览器保留最近 256 KiB；切走停止轮询，日志按文本渲染 |
| 内核状态 | 读取 needrestart 批处理结果，检查镜像、模块、initramfs、启动空间/挂载、GRUB、DKMS 和固件信息；不能确认的项目明确标为未知，没有自动重启入口 |

日志在任务开始/结束清理，正在运行的任务不删除；维护暂停且没有新任务时不会额外
创建高频清理进程。准备失败、签名/网络/锁/dpkg 错误保留具体阶段与脱敏后的诊断；
不把“完成”“无候选软件包”写成“全部漏洞已修复”。同版本候选列表与最终由原生升级器
筛选的安全/稳定更新范围分开说明。

升级覆盖 Debian APT 管理的软件包；面板编译安装的 PHP、OpenResty 等应用仍由对应
软件管理功能维护。独立上下文不导入原有 APT 配置中的任意钩子；特殊代理、定制引导
及异常维护脚本需要管理员查看日志处理。不能保证所有第三方维护脚本都遵守非交互环境，
也不会因长时间无输出就强杀正在配置软件包的进程。

### 使用方式

执行 `sudo dgpctl`，进入数字菜单 **35：Debian 系统自动维护**，选择查看状态、
启用、停用、模拟、立即维护或内核检查。命令形式如下：

```bash
sudo dgpctl maintenance status
sudo dgpctl maintenance enable --at 03:00 --region auto --channel stable
sudo dgpctl maintenance enable --at 04:15 --region cn --channel security
sudo dgpctl maintenance check
sudo dgpctl maintenance run
sudo dgpctl maintenance kernel
sudo dgpctl maintenance logs --job <任务ID> --cursor 0
sudo dgpctl maintenance status --json
sudo dgpctl maintenance disable
```

`enable` 提交独立准备任务，成功后才启动每日定时器；`run` 需要策略已启用且准备完成。
`check` 只刷新索引、模拟并检查状态；不会安装候选更新。`disable` 暂停面板维护并恢复
原有系统调度，因此不等同于关闭管理员此前配置的全部系统自动更新。CLI 通过本机
Agent 的 root peer 入口操作，不依赖面板 MFA；网页、API Key 和伪造请求头不能使用它。

### 实际验证与边界

- Debian 12、13 隔离环境均完成原生组件准备、模拟及真实升级；安装中停用策略，
  当前事务正常完成后才恢复原调度。两边 dpkg 审计均正常，管理员源文件哈希保持不变。
- 两环境均验证真实 POSIX dpkg 锁冲突：报告忙碌，不杀持锁进程，不删除锁文件；
  管理员释放锁后重新检查正常。Debian 13 另外完成阿里云 HTTPS 源的签名索引检查。
- 真实面板会话的 26 项联调通过，包括未验证/已验证 MFA、普通运维模式、只读维护
  状态与游标日志、伪造 root 头、越界日志查询、root CLI 及原有 PHP/任务管理兼容性。
- 新执行器的 Go 测试及竞态检查通过；Agent/Core 完整 Go 回归通过，后续修改按影响
  包补测。安装器/CLI 363 项检查、前端类型检查、单元测试、ESLint 及浏览器相关回归通过。

Debian 11 的结束支持通过规则测试验证，不为已过期系统伪造安全更新；没有接入 ELTS。
容器验收不能代替真实 BIOS/UEFI 启动测试。本轮未重启开发宿主，没有完成硬件启动、
Secure Boot 签名链或失败内核回退的实机验收；检查结果保留未知状态，不能据此承诺
安全重启。实际启用生产维护前，应按本机启动方式确认恢复入口与回退内核。

源码、隔离测试与本机预览回执保存在
`PRIVATE_DIR/dogepanel-handoff/codex-debian-maintenance-20261117/`；本机仍使用 `v2.3.2-dp.49`，
自动维护默认关闭，APT 源、dpkg 状态与已有业务服务不因页面访问或本机预览而改变。

本机实际部署及真实浏览器重新登录验证通过，维护状态、PHP/RASP 和普通管理接口
无失败请求；Core 保持非 root 与 NoNewPrivileges。回执核对了业务主进程、受管配置、
APT 源和 dpkg 状态均未改变，且没有创建宿主系统维护策略或定时器。日志页面另用
中文长文本验证 UTF-8 字节上限；内核检查回归覆盖 init 入口、完整 GRUB 内核路径和
混合 DKMS 状态，避免用文本片段误判为通过。此阶段没有创建版本标签或正式发布。

### dp.001 发布前验收补充

自动维护排除内核和启动链包，黑名单由原生 unattended-upgrades 执行，连带依赖也受其
依赖求解器限制；网页候选数量单独列出暂缓项。Debian 12、13 分别安装旧版普通包与
内核元包进行真实升级，普通包升级成功，内核元包版本未变，未安装新内核镜像，dpkg
审计正常。全过程不等待面板确认。根策略仍需管理员首次启用，不替用户自动修改宿主系统。

新增的完整动态密码流程通过 11 项真实 PTY 验收，安装器 381 项检查、两个模块全套
Go 测试、相关竞态检查和 17 项浏览器检查通过。发布版本采用 `v2.3.3-dp.001`；前置
补丁版本上调保证 `v2.3.2-dp.49` 的现有比较器正常识别更新，1Panel 上游基线不变。

本轮测试、签名与发布回执保存在 `PRIVATE_DIR/dogepanel-handoff/codex-release-dp001-20261117/`。
Google 动态密码二维码参数参考 [Google Key URI](https://github.com/google/google-authenticator/wiki/Key-Uri-Format)
和 [RFC 6238](https://www.rfc-editor.org/rfc/rfc6238.html)。
