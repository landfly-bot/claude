const storage = require('./utils/storage')

App({
  globalData: {
    settings: null
  },

  onLaunch() {
    // 首次启动写入一份默认设置，后续页面直接读取
    this.globalData.settings = storage.saveSettings({})
  },

  /** 页面改设置后调用，保证各页面拿到的是同一份 */
  updateSettings(patch) {
    this.globalData.settings = storage.saveSettings(patch)
    return this.globalData.settings
  },

  getSettings() {
    if (!this.globalData.settings) {
      this.globalData.settings = storage.getSettings()
    }
    return this.globalData.settings
  }
})
