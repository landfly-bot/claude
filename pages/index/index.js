const storage = require('../../utils/storage')
const dateUtil = require('../../utils/date')
const reminder = require('../../utils/reminder')

const app = getApp()
const CHECK_INTERVAL = 20 * 1000

Page({
  data: {
    dateLabel: '',
    weekday: '',
    total: 0,
    goal: 2000,
    percent: 0, // 用于水位高度，最大 100
    percentText: 0, // 真实百分比，可超过 100
    remaining: 0,
    cups: [],
    records: [],
    nextText: '',
    showCustom: false,
    customValue: ''
  },

  onShow() {
    this.refresh()
    this.checkRemind()
    this.startTimer()
  },

  onHide() {
    this.stopTimer()
  },

  onUnload() {
    this.stopTimer()
  },

  onPullDownRefresh() {
    this.refresh()
    wx.stopPullDownRefresh()
  },

  startTimer() {
    this.stopTimer()
    this.timer = setInterval(() => {
      this.setData({ nextText: reminder.nextRemindText(app.getSettings()) })
      this.checkRemind()
    }, CHECK_INTERVAL)
  },

  stopTimer() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  },

  checkRemind() {
    const settings = app.getSettings()
    if (!reminder.shouldRemind(settings)) return
    reminder.fire(settings, amount => this.addWater(amount))
    this.setData({ nextText: reminder.nextRemindText(settings) })
  },

  refresh() {
    const settings = app.getSettings()
    const today = dateUtil.todayStr()
    const total = storage.getTotal(today)
    const percentText = Math.round((total / settings.goal) * 100)

    this.setData({
      dateLabel: dateUtil.formatDateLabel(today),
      weekday: dateUtil.weekdayLabel(today),
      total,
      goal: settings.goal,
      percent: Math.min(percentText, 100),
      percentText,
      remaining: Math.max(settings.goal - total, 0),
      cups: settings.cups,
      records: storage.getRecords(today)
        .slice()
        .reverse()
        .map(r => ({
          id: r.id,
          amount: r.amount,
          time: dateUtil.formatTime(new Date(r.ts))
        })),
      nextText: reminder.nextRemindText(settings)
    })
  },

  addWater(amount) {
    const value = Number(amount)
    if (!value || value <= 0) return
    const before = this.data.total
    storage.addRecord(dateUtil.todayStr(), value)
    this.refresh()

    const goal = this.data.goal
    if (before < goal && this.data.total >= goal) {
      wx.showToast({ title: '今日目标达成 🎉', icon: 'none' })
      wx.vibrateShort({ type: 'heavy', fail: () => {} })
    } else {
      wx.showToast({ title: `+${value} mL`, icon: 'none', duration: 1200 })
    }
  },

  onQuickTap(e) {
    this.addWater(e.currentTarget.dataset.amount)
  },

  openCustom() {
    this.setData({ showCustom: true, customValue: '' })
  },

  closeCustom() {
    this.setData({ showCustom: false })
  },

  onCustomInput(e) {
    this.setData({ customValue: e.detail.value })
  },

  confirmCustom() {
    const value = parseInt(this.data.customValue, 10)
    if (!value || value <= 0 || value > 3000) {
      wx.showToast({ title: '请输入 1 - 3000 之间的数字', icon: 'none' })
      return
    }
    this.setData({ showCustom: false })
    this.addWater(value)
  },

  onDeleteRecord(e) {
    const id = e.currentTarget.dataset.id
    wx.showModal({
      title: '删除这条记录？',
      success: res => {
        if (!res.confirm) return
        storage.removeRecord(dateUtil.todayStr(), id)
        this.refresh()
      }
    })
  },

  goSettings() {
    wx.switchTab({ url: '/pages/settings/settings' })
  }
})
