# 喝水提醒 · iOS App

SwiftUI 版本的喝水提醒。和仓库根目录的微信小程序功能一致，但提醒交给系统本地通知（`UNUserNotificationCenter`）调度——**App 关掉、锁屏、后台，提醒都会准时到**，而且不需要任何服务端。这正是小程序版本做不到的地方。

## 环境要求

- Xcode 16 或更新（工程用了 file system synchronized group，新增文件不用改工程文件）
- iOS 17.0+（用到了 Swift Charts 与 `onChange` 的双参数写法）

低版本 Xcode 打不开 `WaterReminder.xcodeproj` 的话，装 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 后在本目录执行 `xcodegen generate`，用 `project.yml` 重新生成一份。

## 运行

1. Xcode 打开 `ios/WaterReminder.xcodeproj`
2. 在 target 的 Signing & Capabilities 里选自己的开发者账号，把 `PRODUCT_BUNDLE_IDENTIFIER` 换成自己的（默认 `com.example.WaterReminder`）
3. 选模拟器或真机，⌘R

首次启动会请求通知权限，拒绝的话首页会显示一张提示卡片，点进系统设置可以再开。

## 功能

| 页面 | 内容 |
| --- | --- |
| 喝水 | 水杯波浪动画（水位跟进度涨落）、四个可自定义的快捷杯量 + 任意毫升输入、今日记录（点垃圾桶或长按删除）、下次提醒时间 |
| 统计 | Swift Charts 柱状图（最近 7 / 30 天，带目标虚线、达标日高亮）、总量 / 日均 / 达标天数 / 连续达标 / 最佳单日 |
| 设置 | 每日目标（滑块 + 常用值）、快捷杯量、提醒开关与时段、提醒间隔、达标后停止提醒、清空数据 |

达标瞬间会有一次成功触感反馈，平时记录是轻触感。

## 提醒是怎么排的

`NotificationManager.fireDates(...)` 一次性把未来 7 天的提醒时刻算出来，注册成 `UNCalendarNotificationTrigger`：

- 只在设定时段内提醒，支持跨零点的时段（如 22:00 – 02:00）
- 今天的第一条从「最后一次喝水 + 间隔」算起，**刚喝过水会自动顺延**
- 当天达标后跳过今天剩下的提醒（可在设置里关掉这个行为）
- 系统单 App 最多 64 条待触发通知，这里上限取 56；每次喝水、改设置、App 回到前台都会重排

通知上有两个快捷操作，不用打开 App：

- **喝了一杯** — 直接按默认杯量记一笔（走 `AppDelegate` 的 `didReceive response`）
- **15 分钟后提醒** — 单独排一条延后通知

想让提醒穿透「专注模式」，在 target 上勾选 Time Sensitive Notifications 能力，然后打开 `NotificationManager` 里那行注释掉的 `interruptionLevel = .timeSensitive`。

## 代码结构

```
WaterReminder/
├── WaterReminderApp.swift      入口，回到前台时重排提醒
├── AppDelegate.swift           通知代理：前台横幅 + 两个快捷操作
├── Models/
│   ├── DrinkRecord.swift       单条记录 / 按天汇总
│   └── AppSettings.swift       设置（时间存成「零点起的分钟数」，宽松解码兼容旧存档）
├── Store/DrinkStore.swift      ObservableObject，UserDefaults 持久化，统计口径都在这
├── Notifications/NotificationManager.swift   权限、时刻计算、注册与取消
└── Views/                      Theme / RootView / TodayView / CupView / StatsView / SettingsView
```

数据存在 `UserDefaults` 的 `wr.records` 和 `wr.settings` 两个 key 里，JSON 编码，不联网、不上传。

## 已知没做的事

- 没有 App 图标图片，`AppIcon.appiconset` 是空占位（不影响编译运行）
- 没有接 HealthKit。如果想把饮水写进「健康」App，加 HealthKit 能力后在 `DrinkStore.addDrink` 里同步写一条 `HKQuantityType(.dietaryWater)` 即可
- 没有 Widget / 灵动岛
- 这份代码是在没有 macOS 的环境里写的，**没有经过 Xcode 编译验证**；调度逻辑单独做过等价验证，但首次构建如果有小的编译报错，属于预期内
