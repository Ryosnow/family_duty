Component({
    data: {
        selected: 0,
        list: [
            { pagePath: "/pages/dashboard/index", text: "首页" },
            { pagePath: "/pages/task-board/index", text: "任务" },
            { pagePath: "/pages/reports/index", text: "报表" },
            { pagePath: "/pages/rotation/index", text: "轮班" },
            { pagePath: "/pages/settings/index", text: "设置" }
        ]
    },
    methods: {
        switchTab(event: WechatMiniprogram.TouchEvent) {
            const index = Number(event.currentTarget.dataset.index);
            const item = this.data.list[index];
            if (!item || index === this.data.selected) return;
            wx.switchTab({ url: item.pagePath });
        }
    }
});
