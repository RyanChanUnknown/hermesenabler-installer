# V2EX 发帖草稿

## 标题

```
[分享] 写了个 macOS 工具，用免费 Apple ID 把手表 App 连同 App Group 一起装进 Apple Watch
```

## 正文

```
前段时间想把 HermesEnabler 装到手表上（就是那个启用 Hermès 表盘的项目），
结果在"手表端拿不到 App Group"这一步卡了很久，最后发现是侧载工具的一个 bug。
顺手做了个 GUI，把整个流程包起来了。

先说结论：现在双击一个 App，填 Apple ID 和密码，六位验证码输完，
手机和手表会一起装好，表盘能正常启用。

## 之前为什么会卡

试过的几条路：

- Sideloadly（免费账号）：只签 iOS 那半边，Watch 的 UDID 根本不会写进
  provisioning profile，所以手表那半边永远是 0xe8008015
- AltStore / SideStore：同样的问题，Watch UDID 缺失
- Xcode 直接开工程：免费团队不给 com.apple.security.application-groups，
  签名阶段就报 entitlement 不匹配
- 自己用 isideload：能签名能装手机，但装完手表一打开就提示
  "MobileGestalt 访问失败 / App Group ID 可能丢失"

最后一条是根因。翻 isideload 的源码，sideloader.rs 里给每个 App ID
关联 App Group 的循环，第一行是这样：

    for app_id in app_ids.iter_mut() {
        if watch_bundle_ids.contains(&app_id.identifier) {
            continue;          // ← watch app 被跳过了
        }
        app_id.ensure_group_feature(...).await?;
        self.dev_session.assign_app_group(&team, &app_group, app_id, None).await?;

主 App 有 App Group，Watch App 没有。把两份 profile 导出来对比：

    main app  : group.com.example.HermesEnabler...   ← 有
    watch app : None                                  ← 没有

App Group 缺失之后，BQCore 里那个 BQGroupRoot() 返回 nil，
后面所有 MobileGestalt 的读写全部落空，App 一启动就报错。

## 除了这个还踩了几个坑

1. rustls 0.23 的 rustls-no-provider 特性，第一次 HTTPS 请求直接 panic，
   要在 main 里手动 install_default()
2. apple-codesign 的 git 依赖 HEAD 已经解析不了了，得 pin 到某个 revision
3. 免费账号只能有 1 张开发证书，撞到 7460 得先吊销旧的
4. 手机不暴露 legacy 的 companion-proxy 服务，读不到配对手表列表，
   改成直接调 developer API 注册 watch UDID
5. 老式的 watch lockdown 转发同样不通，最后用 xcrun devicectl 推手表
   （就是 Xcode 自己用的那条 CoreDevice 通道）

## 现在长这样

GUI 是个 SwiftUI 壳，底下是我写的 Rust CLI：

    src/main.rs          登录 → 签名 → 装手机 → devicectl 推手表
    gui/main.swift       SwiftUI 外壳
    vendor/isideload/    打过补丁的 isideload

第一次打开要右键 → 打开（ad-hoc 签名，没做公证）。

## 几个必须提前说的限制

- 免费证书 7 天过期，到期 App 打不开，重跑一次安装器续签，Bundle ID 不变
  所以数据不丢
- 免费账号只能有 1 张开发证书，安装器会自动吊销旧的，用旧证书签的 App
  会失效
- 改完 MobileGestalt 之后不要再点 Backup MG，会覆盖掉干净备份
- 需要能访问 gsa.apple.com / idmsa.apple.com / developerservices2.apple.com
  和一个 anisette 服务，域名被墙的话得挂代理

## 地址

仓库：https://github.com/RyanChanUnknown/hermesenabler-installer

直接下载：https://github.com/RyanChanUnknown/hermesenabler-installer/releases/download/v1.0/HermesEnabler-Installer-1.0.dmg

MIT，代码和那两个补丁的说明都在仓库里（docs/PATCHES.md）。
HermesEnabler 本体是 pookjw 的，IPA 请去他那边下，我不分发。

有踩过同样坑的欢迎交流，特别是手表那边如果还有别的失败方式，
可以把报错贴出来。
```

## 发布注意事项

- V2EX 的「分享创造」或「Apple」节点
- 标题别带"破解""免费"这类词，容易被降权，用"侧载""签名"更稳
- 正文里的代码块用 V2EX 的语法：行首四个空格，不要用 markdown 反引号
- 发之前确认仓库是 public（已经是）
- 附一张 GUI 截图和一张手表成功的截图，回复率会高很多
