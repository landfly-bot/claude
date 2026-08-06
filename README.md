# 喝水提醒 · 微信小程序

一个记录每日饮水量并按间隔提醒喝水的小程序。所有数据保存在手机本地（`wx.setStorageSync`），不上传、不需要后端即可运行。

## 功能

- **今日饮水**：水杯形状的进度动画，实时显示已喝水量、目标完成度和剩余量
- **快速记录**：四个可自定义的杯量按钮 + 任意毫升数输入，误操作可长按或点「删除」撤销
- **喝水提醒**：在设定时段内，距离上次喝水超过设定间隔就弹窗提醒（可震动），当日达标后自动停止打扰
- **饮水统计**：最近 7 / 30 天柱状图（带目标线）、总量、日均、达标天数、连续达标天数、最佳单日
- **设置**：每日目标、快捷杯量、提醒时段与间隔、震动开关、清空数据

## 目录结构

```
├── app.js / app.json / app.wxss   全局配置与设置缓存
├── pages/
│   ├── index/      今日饮水（水杯进度、快速记录、今日记录）
│   ├── stats/      饮水统计（柱状图与汇总指标）
│   └── settings/   设置
├── utils/
│   ├── date.js     日期与时间格式化
│   ├── storage.js  本地存储数据层
│   └── reminder.js 提醒调度逻辑
└── project.config.json
```

## 运行

1. 用[微信开发者工具](https://developers.weixin.qq.com/miniprogram/dev/devtools/download.html)导入本目录
2. AppID 选「测试号」即可运行；正式发布时把 `project.config.json` 里的 `appid` 换成自己的
3. 编译预览

## 提醒是怎么工作的

小程序退到后台后 JS 定时器会被系统挂起，所以提醒分两层：

1. **前台提醒（已实现，开箱即用）**
   打开小程序时立即判断一次，之后每 20 秒检查一次。判定规则见 `utils/reminder.js`：

   ```
   基准时间 = max(今天最后一次喝水, 上次提醒时间, 今天提醒时段开始时间)
   下次提醒 = 基准时间 + 提醒间隔
   ```

   仅在提醒时段内触发，当天喝够目标后不再提醒。

2. **微信推送提醒（需要一次性配置）**
   要在小程序关闭时也收到提醒，必须使用**订阅消息**：

   - 在小程序后台「功能 → 订阅消息」申请一个提醒类模板（例如「喝水提醒」）
   - 把模板 ID 填到 `pages/settings/settings.js` 顶部的 `TEMPLATE_ID`
   - 在设置页点「开启微信推送提醒」拿到用户授权（一次授权 = 一次推送额度，可引导用户多次点击累积）
   - 由服务端或云函数在到点时调用 [`subscribeMessage.send`](https://developers.weixin.qq.com/miniprogram/dev/api-backend/open-api/subscribe-message/subscribeMessage.send.html) 下发

   云函数示例（`cloudfunctions/remind/index.js`）：

   ```js
   const cloud = require('wx-server-sdk')
   cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV })

   exports.main = async (event) => {
     return cloud.openapi.subscribeMessage.send({
       touser: event.openid,
       templateId: 'YOUR_TEMPLATE_ID',
       page: 'pages/index/index',
       data: {
         thing1: { value: '该喝水啦' },
         time2: { value: event.time }
       }
     })
   }
   ```

   下发时机可以用云开发的[定时触发器](https://developers.weixin.qq.com/miniprogram/dev/wxcloud/guide/functions/triggers.html)，按用户设置的时段和间隔轮询。

## 数据存储

| Key | 说明 |
| --- | --- |
| `wr_settings` | 设置对象（目标、杯量、提醒时段等） |
| `wr_days` | 有记录的日期列表 |
| `wr_records_<YYYY-MM-DD>` | 当天记录 `[{ id, amount, ts }]` |
| `wr_last_remind` | 上次提醒时间戳 |

清空记录只删除上表中除 `wr_settings` 外的内容；「恢复默认设置」只重置 `wr_settings`。
