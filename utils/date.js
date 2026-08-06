/** 日期与时间相关的小工具，全部使用本地时区 */

function pad(n) {
  return n < 10 ? '0' + n : '' + n
}

/** Date -> 'YYYY-MM-DD' */
function formatDate(date) {
  const d = date || new Date()
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
}

/** Date -> 'HH:mm' */
function formatTime(date) {
  const d = date || new Date()
  return `${pad(d.getHours())}:${pad(d.getMinutes())}`
}

/** 'YYYY-MM-DD' -> 'M月D日' */
function formatDateLabel(dateStr) {
  const parts = dateStr.split('-')
  return `${Number(parts[1])}月${Number(parts[2])}日`
}

/** 'YYYY-MM-DD' -> '周一' */
function weekdayLabel(dateStr) {
  const names = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']
  const parts = dateStr.split('-').map(Number)
  return names[new Date(parts[0], parts[1] - 1, parts[2]).getDay()]
}

function todayStr() {
  return formatDate(new Date())
}

/** 最近 n 天的日期字符串，从旧到新，最后一个是今天 */
function lastNDays(n) {
  const list = []
  const base = new Date()
  base.setHours(0, 0, 0, 0)
  for (let i = n - 1; i >= 0; i--) {
    const d = new Date(base.getTime() - i * 86400000)
    list.push(formatDate(d))
  }
  return list
}

/** 'HH:mm' -> 从零点开始的分钟数 */
function timeToMinutes(hhmm) {
  const parts = String(hhmm).split(':')
  return Number(parts[0]) * 60 + Number(parts[1])
}

/** 今天的 'HH:mm' 对应的时间戳 */
function todayTimestampOf(hhmm) {
  const d = new Date()
  const parts = String(hhmm).split(':')
  d.setHours(Number(parts[0]), Number(parts[1]), 0, 0)
  return d.getTime()
}

module.exports = {
  pad,
  formatDate,
  formatTime,
  formatDateLabel,
  weekdayLabel,
  todayStr,
  lastNDays,
  timeToMinutes,
  todayTimestampOf
}
