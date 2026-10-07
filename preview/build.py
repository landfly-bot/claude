"""把小程序的真实 .wxss 转成浏览器可用的 CSS（rpx -> px，750rpx = 375px），
套上静态示例数据生成预览页。运行: python3 preview/build.py"""
import re, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = pathlib.Path(__file__).resolve().parent

def css(path):
    text = (ROOT / path).read_text(encoding="utf-8")
    text = re.sub(r"(-?\d+(?:\.\d+)?)rpx", lambda m: f"{float(m.group(1))/2:g}px", text)
    text = re.sub(r"(^|\n)page\s*\{", r"\1body {", text)
    text = re.sub(r"\.page\s*\{", ".page {", text)
    return text

SHELL = """<!doctype html><html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>{title}</title>
<style>
*{{box-sizing:border-box}} html{{background:#dfe5ee}}
body{{margin:0}}
view,.v{{display:block}} text{{display:inline}}
.phone{{width:375px;height:812px;margin:0 auto;position:relative;overflow:hidden;background:#000;border-radius:0}}
.nav{{height:88px;padding-top:44px;background:#2f80ed;color:#fff;text-align:center;font-size:17px;font-weight:600;line-height:44px;position:absolute;top:0;left:0;right:0;z-index:5}}
.status{{position:absolute;top:0;left:0;right:0;height:44px;z-index:6;display:flex;justify-content:space-between;padding:14px 26px 0;color:#fff;font-size:14px;font-weight:600}}
.scroll{{position:absolute;top:88px;bottom:56px;left:0;right:0;overflow-y:auto;
  background:linear-gradient(180deg,#eef5ff 0%,#f7fbff 45%,#f7f8fa 100%);
  --brand:#2f80ed;--brand-light:#56ccf2;--text:#1f2733;--text-weak:#8a94a6;--card:#fff;color:#1f2733;
  font-family:-apple-system,"PingFang SC","Noto Sans CJK SC","Helvetica Neue",sans-serif}}
.tabbar{{position:absolute;bottom:0;left:0;right:0;height:56px;background:#fff;border-top:1px solid #eee;display:flex;z-index:5}}
.tabbar div{{flex:1;text-align:center;font-size:11px;color:#8a94a6;padding-top:8px}}
.tabbar div b{{display:block;font-size:20px;line-height:24px;font-weight:400}}
.tabbar .on{{color:#2f80ed}}
input.cup-input,.slider-fake{{font-family:inherit}}
{css}
{extra}
</style></head><body>
<div class="phone"><div class="status"><span>9:41</span><span>5G ▮▮▮</span></div>
<div class="nav">{title}</div>
<div class="scroll"><div class="page">{body}</div></div>
<div class="tabbar">{tabs}</div></div></body></html>"""

def tabs(active):
    items = [("💧", "喝水"), ("📊", "统计"), ("⚙️", "设置")]
    return "".join(f'<div class="{"on" if i==active else ""}"><b>{ic}</b>{t}</div>' for i,(ic,t) in enumerate(items))

# ---------------- 首页 ----------------
index_body = """
<view class="header"><view><text class="date">10月7日</text><text class="weekday">周三</text></view>
<text class="next">下次提醒 15:20（约 42 分钟后）</text></view>
<view class="cup-card"><view class="cup">
 <view class="water" style="height:60%"><view class="wave"></view><view class="wave wave-2"></view></view>
 <view class="cup-info"><view class="amount-line"><text class="amount">1200</text><text class="unit">mL</text></view>
 <text class="goal-line">目标 2000 mL · 60%</text></view></view>
 <text class="remaining">还差 800 mL，加把劲</text></view>
<view class="card"><view class="card-title">快速记录</view><view class="cups">
 <view class="cup-btn"><text class="cup-icon">🥤</text><text class="cup-amount">150 mL</text></view>
 <view class="cup-btn"><text class="cup-icon">🥤</text><text class="cup-amount">250 mL</text></view>
 <view class="cup-btn"><text class="cup-icon">🥤</text><text class="cup-amount">350 mL</text></view>
 <view class="cup-btn"><text class="cup-icon">🥤</text><text class="cup-amount">500 mL</text></view>
 <view class="cup-btn custom"><text class="cup-icon">✏️</text><text class="cup-amount">自定义</text></view></view></view>
<view class="card"><view class="row"><text class="card-title" style="margin-bottom:0">今日记录</text><text class="muted">共 4 次</text></view>
""" + "".join(f'<view class="record"><text class="record-time">{t}</text><text class="record-amount">{a} mL</text><text class="record-del">删除</text></view>'
              for t,a in [("14:38",250),("12:05",350),("10:20",250),("08:15",350)]) + """
<text class="muted tips">长按记录也可以删除</text></view>
"""

# ---------------- 统计 ----------------
vals = [1500,1800,2100,1650,2200,2050,1200]
wk = ["周四","周五","周六","周日","周一","周二","周三"]
maxv = max(2000, *vals)
bars = "".join(
 f'<view class="bar-item"><view class="bar-track"><view class="bar {"reached" if v>=2000 else ""} {"today" if i==6 else ""}" style="height:{round(v/maxv*100)}%"></view></view></view>'
 for i,v in enumerate(vals))
labels = "".join(f'<text class="bar-label">{w}</text>' for w in wk)
stats_body = f"""
<view class="tabs"><view class="tab active">最近 7 天</view><view class="tab">最近 30 天</view></view>
<view class="card"><view class="card-title">饮水趋势</view><view class="chart">
<view class="plot"><view class="goal-line" style="bottom:{round(2000/maxv*100)}%"><text class="goal-tag">目标 2000</text></view>
<view class="bars">{bars}</view></view><view class="labels">{labels}</view></view><text class="muted chart-tip">点击柱子查看当天饮水量</text></view>
<view class="card"><view class="card-title">这段时间</view><view class="grid">
<view class="grid-item"><text class="grid-value">11500</text><text class="grid-label">总饮水量 (mL)</text></view>
<view class="grid-item"><text class="grid-value">1643</text><text class="grid-label">有记录日均 (mL)</text></view>
<view class="grid-item"><text class="grid-value">3</text><text class="grid-label">达标天数</text></view>
<view class="grid-item"><text class="grid-value">0</text><text class="grid-label">连续达标 (天)</text></view></view>
<view class="best">喝得最多的一天：10月3日 · 2200 mL</view></view>
"""
# 统计页的 .goal-line 与首页同名但在各自页面里独立，这里不会冲突

# ---------------- 设置 ----------------
def sw(on=True):
    bg = "#2f80ed" if on else "#ddd"; x = "22px" if on else "2px"
    return f'<span style="display:inline-block;width:46px;height:26px;border-radius:13px;background:{bg};position:relative"><i style="position:absolute;top:2px;left:{x};width:22px;height:22px;border-radius:50%;background:#fff"></i></span>'
settings_body = f"""
<view class="card"><view class="row"><text class="card-title" style="margin-bottom:0">每日目标</text><text class="value">2000 mL</text></view>
<div class="slider-fake" style="margin:14px 4px 6px;height:4px;background:#e5e5e5;border-radius:2px;position:relative"><div style="width:33%;height:4px;background:#2f80ed;border-radius:2px"></div><i style="position:absolute;left:33%;top:-9px;margin-left:-11px;width:22px;height:22px;border-radius:50%;background:#fff;box-shadow:0 1px 4px rgba(0,0,0,.3)"></i></div>
<view class="presets" style="margin-top:20px"><view class="preset">1500</view><view class="preset">2000</view><view class="preset">2500</view><view class="preset">3000</view></view>
<text class="muted">一般建议每天 1500 - 2500 mL，运动量大或天气炎热可适当增加。</text></view>
<view class="card"><view class="card-title">快捷杯量 (mL)</view><view class="cup-inputs">
<div class="cup-input">150</div><div class="cup-input">250</div><div class="cup-input">350</div><div class="cup-input">500</div></view>
<text class="muted">首页「快速记录」按钮的水量，修改后立即生效。</text></view>
<view class="card"><view class="card-title">提醒</view>
<view class="item"><text class="item-label">开启提醒</text>{sw()}</view>
<view class="item"><text class="item-label">开始时间</text><text class="value">08:00 ›</text></view>
<view class="item"><text class="item-label">结束时间</text><text class="value">22:00 ›</text></view>
<view class="item"><text class="item-label">提醒间隔</text><text class="value">60 分钟 ›</text></view>
<view class="item"><text class="item-label">提醒时震动</text>{sw()}</view>
<view class="item last"><text class="item-label">下次提醒</text><text class="muted">下次提醒 15:20（约 42 分钟后）</text></view>
<view class="action">开启微信推送提醒</view>
<text class="muted">小程序退到后台后定时器会暂停，授权订阅消息后才能在关闭小程序时收到提醒。</text></view>
<view class="card"><view class="card-title">数据</view>
<view class="item"><text class="item-label">恢复默认设置</text><text class="value">›</text></view>
<view class="item last"><text class="item-label danger">清空饮水记录</text><text class="value">›</text></view>
<text class="muted">所有数据仅保存在本机，不会上传。</text></view>
<view class="footer">喝水提醒 v1.0.0</view>
"""

base = css("app.wxss")
pages = [
 ("index",    "今日饮水", index_body,    css("pages/index/index.wxss"),       0),
 ("stats",    "饮水统计", stats_body,    css("pages/stats/stats.wxss"),       1),
 ("settings", "设置",     settings_body, css("pages/settings/settings.wxss"), 2),
]
for name, title, body, extra, active in pages:
    html = SHELL.format(title=title, css=base, extra=extra, body=body, tabs=tabs(active))
    (OUT / f"mp-{name}.html").write_text(html, encoding="utf-8")
    print("wrote", f"mp-{name}.html")
