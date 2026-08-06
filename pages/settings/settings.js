const storage = require('../../utils/storage')
const reminder = require('../../utils/reminder')

const app = getApp()

// 订阅消息模板 ID：在小程序后台「订阅消息」里申请后填在这里，
// 并配合服务端/云函数下发，详见 README。留空时按钮会给出提示。
const TEMPLATE_ID = ''

const INTERVAL_OPTIONS = [30, 45, 60, 90, 120]

Page({
  data: {
    settings: null,
    intervalOptions: INTERVAL_OPTIONS.map(m => `${m} 分钟`),
    intervalIndex: 2,
    nextText: '',
    version: '1.0.0'
  },

  onShow() {
    this.refresh()
  },

  refresh() {
    const settings = app.getSettings()
    const idx = INTERVAL_OPTIONS.indexOf(settings.interval)
    this.setData({
      settings,
      intervalIndex: idx === -1 ? 2 : idx,
      nextText: reminder.nextRemindText(settings)
    })
  },

  update(patch) {
    app.updateSettings(patch)
    this.refresh()
  },

  onGoalChange(e) {
    this.update({ goal: Number(e.detail.value) })
  },

  onGoalPreset(e) {
    this.update({ goal: Number(e.currentTarget.dataset.goal) })
  },

  onCupInput(e) {
    const index = Number(e.currentTarget.dataset.index)
    const value = parseInt(e.detail.value, 10)
    const cups = this.data.settings.cups.slice()
    cups[index] = !value || value <= 0 ? storage.DEFAULT_SETTINGS.cups[index] : Math.min(value, 3000)
    this.update({ cups })
  },

  onRemindToggle(e) {
    this.update({ remindEnabled: e.detail.value })
  },

  onVibrateToggle(e) {
    this.update({ vibrate: e.detail.value })
  },

  onStartTimeChange(e) {
    this.update({ startTime: e.detail.value })
  },

  onEndTimeChange(e) {
    this.update({ endTime: e.detail.value })
  },

  onIntervalChange(e) {
    this.update({ interval: INTERVAL_OPTIONS[Number(e.detail.value)] })
  },

  /** 申请订阅消息授权，让微信在小程序关闭时也能推送提醒 */
  onSubscribe() {
    if (!TEMPLATE_ID) {
      wx.showModal({
        title: '还需要一步配置',
        content: '请在小程序后台申请「喝水提醒」订阅消息模板，把模板 ID 填入 pages/settings/settings.js 的 TEMPLATE_ID，并部署 README 里的下发服务。',
        showCancel: false
      })
      return
    }
    wx.requestSubscribeMessage({
      tmplIds: [TEMPLATE_ID],
      success: res => {
        const accepted = res[TEMPLATE_ID] === 'accept'
        wx.showToast({
          title: accepted ? '已开启推送提醒' : '未授权，仅在打开小程序时提醒',
          icon: 'none'
        })
      },
      fail: () => {
        wx.showToast({ title: '订阅失败，请稍后再试', icon: 'none' })
      }
    })
  },

  onClearRecords() {
    wx.showModal({
      title: '清空所有饮水记录？',
      content: '记录只保存在本机，删除后无法恢复。',
      confirmColor: '#eb5757',
      success: res => {
        if (!res.confirm) return
        storage.clearRecords()
        wx.showToast({ title: '已清空', icon: 'none' })
        this.refresh()
      }
    })
  },

  onResetSettings() {
    wx.showModal({
      title: '恢复默认设置？',
      content: '饮水记录不会被删除。',
      success: res => {
        if (!res.confirm) return
        storage.resetSettings()
        app.globalData.settings = storage.getSettings()
        wx.showToast({ title: '已恢复默认', icon: 'none' })
        this.refresh()
      }
    })
  }
})
