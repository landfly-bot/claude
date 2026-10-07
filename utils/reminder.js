/**
 * 提醒调度逻辑。
 *
 * 说明：小程序退到后台后 JS 定时器会被挂起，因此这里做的是
 *   1) 前台轮询提醒（打开小程序时立即判断一次，之后每 20 秒检查一次）；
 *   2) 通过订阅消息把「到点提醒」交给微信推送（需服务端下发，见 README）。
 *
 * 提醒基准时间 = max(今天最后一次喝水, 上次提醒, 今天提醒时段的开始时间)，
 * 基准时间 + 提醒间隔就是下一次该提醒的时刻。
 */

const dateUtil = require('./date')
const storage = require('./storage')

const MINUTE = 60 * 1000

/** 提醒时段是否跨零点，比如 22:00 - 02:00 */
function isOvernight(settings) {
  return dateUtil.timeToMinutes(settings.endTime) < dateUtil.timeToMinutes(settings.startTime)
}

/** 当前是否处于提醒时段内 */
function inWindow(settings, now) {
  const d = now ? new Date(now) : new Date()
  const cur = d.getHours() * 60 + d.getMinutes()
  const start = dateUtil.timeToMinutes(settings.startTime)
  const end = dateUtil.timeToMinutes(settings.endTime)
  return isOvernight(settings) ? cur >= start || cur <= end : cur >= start && cur <= end
}

/** 当前所处（或即将到来的）提醒时段的开始时间戳 */
function windowStartTs(settings, now) {
  const nowTs = now || Date.now()
  const start = dateUtil.todayTimestampOf(settings.startTime)
  // 跨零点时段里的凌晨时刻，属于昨天开始的那一段
  if (isOvernight(settings) && nowTs <= dateUtil.todayTimestampOf(settings.endTime)) {
    return start - 86400000
  }
  return start
}

/** 下一次应该提醒的时间戳 */
function nextRemindTs(settings, now) {
  const nowTs = now || Date.now()
  const start = windowStartTs(settings, nowTs)
  if (nowTs < start) return start // 今天的提醒时段还没开始

  const base = Math.max(
    start,
    storage.getLastDrinkTs(dateUtil.todayStr()),
    storage.getLastRemindTs()
  )
  return base + settings.interval * MINUTE
}

/** 现在是否该提醒了 */
function shouldRemind(settings, now) {
  const nowTs = now || Date.now()
  if (!settings.remindEnabled) return false
  if (!inWindow(settings, nowTs)) return false
  if (storage.getTotal(dateUtil.todayStr()) >= settings.goal) return false // 已达标就不再打扰
  return nowTs >= nextRemindTs(settings, nowTs)
}

/** 下一次提醒的展示文案 */
function nextRemindText(settings) {
  if (!settings.remindEnabled) return '提醒已关闭'
  if (storage.getTotal(dateUtil.todayStr()) >= settings.goal) return '今日已达标，好好休息'
  const ts = nextRemindTs(settings)
  if (ts <= Date.now()) return '该喝水啦'
  const diff = Math.round((ts - Date.now()) / MINUTE)
  const clock = dateUtil.formatTime(new Date(ts))
  return diff < 60 ? `下次提醒 ${clock}（约 ${diff} 分钟后）` : `下次提醒 ${clock}`
}

/** 弹出提醒；调用方负责判断 shouldRemind */
function fire(settings, onDrink) {
  storage.setLastRemindTs(Date.now())
  if (settings.vibrate) {
    wx.vibrateShort({ type: 'medium', fail: () => {} })
  }
  wx.showModal({
    title: '该喝水啦 💧',
    content: `已经 ${settings.interval} 分钟没喝水了，来一杯 ${settings.cups[1] || 250} mL 吧`,
    confirmText: '喝了',
    cancelText: '待会儿',
    success: res => {
      if (res.confirm && typeof onDrink === 'function') {
        onDrink(settings.cups[1] || 250)
      }
    }
  })
}

module.exports = {
  MINUTE,
  inWindow,
  nextRemindTs,
  nextRemindText,
  shouldRemind,
  fire
}
