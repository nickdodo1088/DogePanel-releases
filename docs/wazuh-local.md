# Wazuh 本机漏洞检测与告警接入

## 拓扑

每台需要 Wazuh 漏洞检测的节点安装官方 Wazuh Manager 和单节点 Indexer。Manager 自带的 Syscollector 收集本机软件清单。打开 Manager 自扫描后，Vulnerability Detection 使用 Wazuh CTI 在本机匹配漏洞，将结果写入本地 Indexer 中的主机编号 `000`。CTI 汇总 Canonical、Debian、NVD、OSV 和其他厂商及公共数据。DogePanel 使用独立的只读账号读取结果，继续通过节点签名向安全中心单向上报。 [Wazuh 漏洞检测原理](https://documentation.wazuh.com/current/user-manual/capabilities/vulnerability-detection/how-it-works.html) [Manager 自扫描](https://documentation.wazuh.com/current/user-manual/capabilities/vulnerability-detection/configuring-scans.html)

| 进程 | 地址与权限 |
| --- | --- |
| Wazuh Manager | 只监测所在主机。关闭远程注册、集群、主动响应及远程命令。单机配置下 API 和通信服务仅限回环。CTI 由节点访问 Wazuh 官方 HTTPS 源。 |
| Wazuh Indexer | 单机运行，HTTP 与内部传输只绑定回环。使用本机 CA 和 TLS。目录由 Indexer 系统账号管理。 |
| DogePanel 巡检 | 只访问回环 Indexer 的指定漏洞索引，只查询本机 `000`。工作进程用临时低权限 UID，禁止监听。读密钥只传给该进程。 |
| DogePanel 安全中心 | 在选定的 DogePanel 上启用主控。凭每台节点的公钥验证签名，使用主控面板登录查看汇总记录。 |

Indexer 的最低建议是 4 GB 内存，Manager 也需要内存和磁盘处理 CTI 快照。单机接入使用 Manager 和 Indexer，DogePanel 提供汇总页面。小内存节点可继续使用原有的发行版安全检查。应用商店中从源码或私有包安装的应用仍由面板应用补丁检查覆盖。 [Indexer 资源需求](https://documentation.wazuh.com/current/installation-guide/wazuh-indexer/index.html) [Manager 资源需求](https://documentation.wazuh.com/current/installation-guide/wazuh-server/index.html)

## 实施

1. 在专用隔离环境使用官方签名的 Wazuh 4.14 软件包验证 Manager 自扫描、CTI 获取、Index 数据和本机告警。安装由节点管理员管理。
2. 在 `dgpctl security-report wazuh` 增加只读连接配置。节点管理员提供 Indexer 端口、指定漏洞索引、CA 和受保护的密码文件。面板页面显示来源状态，不读取凭据。
3. 将漏洞结果、认证和文件完整性告警写入现有签名报告。只上报包版本、CVE、级别和事件摘要。账号信息、索引凭据、原始日志、文件路径与软件清单留在节点。
4. 恢复以晚于上次发现的 Wazuh `Solved` 事件为证据，并在当前索引按包名和 CVE 查询全部匹配项。恢复查询独立于显示的结果数量。同一包和 CVE 仍有匹配，或索引暂不可用时，原记录继续待处理。巡检读取当前告警文件末尾最多 1 MiB，按最新时间保留最多 256 条修复证据。Wazuh 停机期间安装补丁或告警已轮换时，安全中心可能缺少相应的修复证据。 [Wazuh 告警生成条件](https://documentation.wazuh.com/current/user-manual/capabilities/vulnerability-detection/how-it-works.html#alert-generation)
5. 先更新主控面板，再在节点启用 Wazuh。旧节点报告仍可被接收。启用时使用 Wazuh 检查漏洞和主机事件，APT 更新候选和面板应用补丁分别展示。

## 验收

Ubuntu 24.04 隔离节点使用官方签名软件包安装 Wazuh `4.14.10`。首次 CTI 初始化后，本机漏洞索引包含 677 条记录，CTI 本地数据目录约 10 GiB。签名上报验证了 CVE、文件变动告警、回环监听、Index 查询账号对写入和无关索引的拒绝。

通过 APT 将 OpenSSL 和关联库更新至 `3.0.13-0ubuntu3.16` 后，Wazuh 产生 86 条明确的修复事件。本次索引逐条复查全部事件，汇总端把其中已上报的 12 条发现标为「已恢复」，包括 `CVE-2024-5535`。停止 Indexer 后，新报告的 Wazuh 来源显示暂不可用，其他待处理项保留。浏览器回归验证了 CTI 链接、仍在评估的提示和告警展示。

## 在节点接入

1. 从 Wazuh 的官方签名软件源安装相同版本的 Manager 和 Indexer。接入验收使用 `4.14.10`。按 Wazuh 单节点安装文档生成独立 CA 和证书，Indexer 的证书须包含 IP 地址 `127.0.0.1`。在对外网络可用前完成下面的监听和账号配置。 [Indexer 官方安装](https://documentation.wazuh.com/current/installation-guide/wazuh-indexer/step-by-step.html) [Manager 官方安装](https://documentation.wazuh.com/current/installation-guide/wazuh-server/step-by-step.html)
2. 在 Indexer 的 `opensearch.yml` 设置 `network.host: "127.0.0.1"` 与 `discovery.type: single-node`，按单节点方式初始化安全索引。Manager 使用单独的写入凭据，放在 Manager 自己的 keystore。DogePanel 仅持有下文的读取账号。
3. 在 Manager 的 `etc/ossec.conf` 保留一个本地 `remote` 通信节。设置 `connection=secure`、`protocol=tcp`、`port=1514`、`local_ip=127.0.0.1`。关闭 `auth`、`cluster` 和 `active-response`。在 API 的 `api.yaml` 设置 `host: ['127.0.0.1']`，通过 Wazuh 自带的 `rbac_control change-password` 设置默认角色的 API 密码。保留本机日志及需要的 FIM 目录。
4. 开启 `syscollector` 的 `os` 和 `packages`，推荐 `interval=1h`。启用 `vulnerability-detection` 及 `index-status`。Manager 的 Indexer connector 指向 `https://127.0.0.1:9200` 并使用该 Indexer 的 CA 和本机客户端证书。Manager 自己连官方 CTI 获取更新，也支持官方离线快照。在 `etc/local_internal_options.conf` 设置 `vulnerability-detection.disable_scan_manager=0`、`logcollector.remote_commands=0`、`wazuh_command.remote_commands=0`。 [Manager 通信配置](https://documentation.wazuh.com/current/user-manual/reference/ossec-conf/remote.html) [Indexer connector](https://documentation.wazuh.com/current/user-manual/manager/indexer-integration.html) [离线漏洞库](https://documentation.wazuh.com/current/user-manual/capabilities/vulnerability-detection/configuring-scans.html#offline-vulnerability-detection)
5. 用具备本地 Indexer 管理权限的账号查看漏洞索引实际名称。生成独立密码，将用户 `dgp-report-reader` 映射至只允许查询该索引的角色。移除该用户从通配用户名映射继承的写权限。以下示例以 `wazuh-states-vulnerabilities-node01` 为索引名，使用实际名称替换。可以进一步按 `agent.id=000` 约束文档。 [OpenSearch 最小搜索权限](https://docs.opensearch.org/latest/security/access-control/permissions/)

   ```yaml
   dgp_report_reader:
     cluster_permissions: []
     index_permissions:
       - index_patterns: ['wazuh-states-vulnerabilities-node01']
         allowed_actions: ['indices:data/read/search*']
   ```

6. 启动 Wazuh 服务后，通过 `ss -lntup` 核对服务端口只绑定到回环。等待 CTI 完成初始化。将 CA 和密码文件放在节点管理员的工作目录。密码文件须由 root 所有，权限为 `0600`，密码至少 16 位。接入命令先验证 TLS 和实际搜索权限，再保存节点配置。

   ```bash
   sudo dgpctl security-report wazuh enable 9200 wazuh-states-vulnerabilities-node01 wazuh-ca.pem wazuh-reader.password
   sudo dgpctl security-report wazuh status
   ```

7. 先更新安全中心，再登记节点。打开「安全检测 → 巡检上报」查看 Wazuh CVE 和告警，或运行 `sudo dgpctl security-report run` 立即读取 Wazuh 当前结果。补丁状态随 Wazuh 的软件清单扫描和 CTI 同步更新。一次汇总读取最多 768 条索引记录，按评分展示前 56 条漏洞，并上报最近 56 条本机告警摘要。完整漏洞列表可在本机 Indexer 查询。停用 Wazuh 上报用 `sudo dgpctl security-report wazuh disable`。 [安全中心部署指南](security-reporting.md#部署和接入)
