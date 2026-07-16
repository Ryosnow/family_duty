import { dashboardSections, RecordPresentation, TaskPresentation } from "../../domain/selectors";
import { appStore } from "../../store/app-store";
import { prepareTabPage, showError } from "../../utils/page";

Page({
    data: {
        ready: false,
        dateText: "",
        sections: { overdue: [] as TaskPresentation[], today: [] as TaskPresentation[], later: [] as TaskPresentation[], temporary: [] as TaskPresentation[], recent: [] as RecordPresentation[], progress: { completed: 0, total: 0, percent: 0 } }
    },
    async onShow() {
        try {
            if (!await prepareTabPage(this, 0)) return;
            this.reload();
        } catch (error) { showError(error, "无法加载首页"); }
    },
    onPullDownRefresh() {
        appStore.refreshGeneratedTasks().then(() => this.reload()).catch((error) => showError(error)).finally(() => wx.stopPullDownRefresh());
    },
    reload() {
        const now = new Date();
        this.setData({ ready: true, dateText: now.toLocaleDateString("zh-CN", { month: "long", day: "numeric", weekday: "long" }), sections: dashboardSections(appStore.getState(), now) });
    },
    addTemporary() { wx.navigateTo({ url: "/pages/task-editor/index?mode=create" }); },
    openHistory() { wx.navigateTo({ url: "/pages/history/index" }); },
    openRecord(event: any) { wx.navigateTo({ url: `/pages/history-detail/index?recordID=${event.currentTarget.dataset.id}` }); },
    taskAction(event: any) {
        const detail = event.detail;
        if (detail.action === "adjust") wx.navigateTo({ url: `/pages/task-editor/index?mode=adjust&taskID=${detail.taskID}` });
        else wx.navigateTo({ url: `/pages/task-action/index?mode=${detail.action}&taskID=${detail.taskID}` });
    }
});
