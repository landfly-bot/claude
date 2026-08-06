const storage = require('../../utils/storage')
const dateUtil = require('../../utils/date')

const app = getApp()
const RANGES = [7, 30]

Page({
  data: {
    ranges: RANGES,
    rangeIndex: 0,
    goal: 2000,
    days: [],
    total: 0,
    average: 0,
    reachedDays: 0,
    streak: 0,
    bestDay: null,
    goalLine: 0
  },

  onShow() {
    this.refresh()
  },

  onPullDownRefresh() {
    this.refresh()
    wx.stopPullDownRefresh()
  },

  onRangeTap(e) {
    this.setData({ rangeIndex: Number(e.currentTarget.dataset.index) }, () => this.refresh())
  },

  refresh() {
    const settings = app.getSettings()
    const goal = settings.goal
    const size = RANGES[this.data.rangeIndex]
    const today = dateUtil.todayStr()

    const raw = dateUtil.lastNDays(size).map(date => ({
      date,
      total: storage.getTotal(date)
    }))

    const max = Math.max(goal, ...raw.map(d => d.total))
    const days = raw.map(d => ({
      date: d.date,
      label: dateUtil.formatDateLabel(d.date),
      weekday: dateUtil.weekdayLabel(d.date),
      shortLabel: size <= 7 ? dateUtil.weekdayLabel(d.date) : String(Number(d.date.split('-')[2])),
      total: d.total,
      height: max ? Math.max(Math.round((d.total / max) * 100), d.total > 0 ? 4 : 0) : 0,
      reached: d.total >= goal,
      isToday: d.date === today
    }))

    const total = raw.reduce((sum, d) => sum + d.total, 0)
    const activeDays = raw.filter(d => d.total > 0).length
    const reachedDays = raw.filter(d => d.total >= goal).length
    const best = raw.reduce((a, b) => (b.total > a.total ? b : a), raw[0])

    this.setData({
      goal,
      days,
      total,
      average: activeDays ? Math.round(total / activeDays) : 0,
      reachedDays,
      streak: this.calcStreak(goal),
      bestDay: best && best.total > 0
        ? { label: dateUtil.formatDateLabel(best.date), total: best.total }
        : null,
      goalLine: max ? Math.round((goal / max) * 100) : 0
    })
  },

  /** 连续达标天数：今天还在进行中，未达标也不算中断 */
  calcStreak(goal) {
    let streak = 0
    const base = new Date()
    base.setHours(0, 0, 0, 0)
    for (let i = 0; i < 365; i++) {
      const date = dateUtil.formatDate(new Date(base.getTime() - i * 86400000))
      if (storage.getTotal(date) >= goal) {
        streak++
        continue
      }
      if (i === 0) continue
      break
    }
    return streak
  },

  onBarTap(e) {
    const day = this.data.days[Number(e.currentTarget.dataset.index)]
    if (!day) return
    wx.showToast({
      title: `${day.label} ${day.weekday}：${day.total} mL`,
      icon: 'none'
    })
  }
})
