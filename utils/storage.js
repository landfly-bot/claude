/**
 * 本地数据层：全部使用 wx.setStorageSync 保存在本机，不上传任何数据。
 *
 * 存储结构：
 *   wr_settings          -> 设置对象
 *   wr_days              -> 有记录的日期数组 ['2026-08-06', ...]
 *   wr_records_<日期>    -> 当天的饮水记录数组 [{ id, amount, ts }]
 *   wr_last_remind       -> 上次提醒的时间戳
 */

const SETTINGS_KEY = 'wr_settings'
const DAYS_KEY = 'wr_days'
const RECORD_PREFIX = 'wr_records_'
const LAST_REMIND_KEY = 'wr_last_remind'

const DEFAULT_SETTINGS = {
  goal: 2000, // 每日目标（mL）
  cups: [150, 250, 350, 500], // 快捷杯量
  remindEnabled: true, // 是否开启提醒
  startTime: '08:00', // 提醒开始时间
  endTime: '22:00', // 提醒结束时间
  interval: 60, // 提醒间隔（分钟）
  vibrate: true // 提醒时震动
}

function getSettings() {
  const saved = wx.getStorageSync(SETTINGS_KEY) || {}
  return Object.assign({}, DEFAULT_SETTINGS, saved)
}

function saveSettings(patch) {
  const next = Object.assign({}, getSettings(), patch)
  wx.setStorageSync(SETTINGS_KEY, next)
  return next
}

function resetSettings() {
  wx.removeStorageSync(SETTINGS_KEY)
  return getSettings()
}

function recordKey(dateStr) {
  return RECORD_PREFIX + dateStr
}

function getDays() {
  return wx.getStorageSync(DAYS_KEY) || []
}

function rememberDay(dateStr) {
  const days = getDays()
  if (days.indexOf(dateStr) === -1) {
    days.push(dateStr)
    days.sort()
    wx.setStorageSync(DAYS_KEY, days)
  }
}

function forgetDay(dateStr) {
  const days = getDays().filter(d => d !== dateStr)
  wx.setStorageSync(DAYS_KEY, days)
}

/** 某天的记录，按时间正序 */
function getRecords(dateStr) {
  return wx.getStorageSync(recordKey(dateStr)) || []
}

function saveRecords(dateStr, records) {
  if (records.length) {
    wx.setStorageSync(recordKey(dateStr), records)
    rememberDay(dateStr)
  } else {
    wx.removeStorageSync(recordKey(dateStr))
    forgetDay(dateStr)
  }
}

/** 新增一条饮水记录，返回该记录 */
function addRecord(dateStr, amount, ts) {
  const record = {
    id: `${ts || Date.now()}_${Math.floor(Math.random() * 1000)}`,
    amount: amount,
    ts: ts || Date.now()
  }
  const records = getRecords(dateStr)
  records.push(record)
  records.sort((a, b) => a.ts - b.ts)
  saveRecords(dateStr, records)
  return record
}

function removeRecord(dateStr, id) {
  const records = getRecords(dateStr).filter(r => r.id !== id)
  saveRecords(dateStr, records)
  return records
}

/** 某天的饮水总量（mL） */
function getTotal(dateStr) {
  return getRecords(dateStr).reduce((sum, r) => sum + r.amount, 0)
}

/** 某天最后一次喝水的时间戳，没有则返回 0 */
function getLastDrinkTs(dateStr) {
  const records = getRecords(dateStr)
  return records.length ? records[records.length - 1].ts : 0
}

function getLastRemindTs() {
  return wx.getStorageSync(LAST_REMIND_KEY) || 0
}

function setLastRemindTs(ts) {
  wx.setStorageSync(LAST_REMIND_KEY, ts)
}

/** 清空所有饮水记录，保留设置 */
function clearRecords() {
  getDays().forEach(d => wx.removeStorageSync(recordKey(d)))
  wx.removeStorageSync(DAYS_KEY)
  wx.removeStorageSync(LAST_REMIND_KEY)
}

module.exports = {
  DEFAULT_SETTINGS,
  getSettings,
  saveSettings,
  resetSettings,
  getDays,
  getRecords,
  addRecord,
  removeRecord,
  getTotal,
  getLastDrinkTs,
  getLastRemindTs,
  setLastRemindTs,
  clearRecords
}
