import { MemberSummary, reportSummaries, undoCompletion } from "../../domain/services";
import { taskBoardSections, TaskPresentation } from "../../domain/selectors";
import { appStore } from "../../store/app-store";
import { prepareTabPage, showError, showSuccess } from "../../utils/page";

Page({
    data: { ready: false, sections: { pending: [] as TaskPresentation[], completed: [] as TaskPresentation[], cancelled: [] as TaskPresentation[] }, summaries: [] as MemberSummary[], totalCompleted: 0, totalScore: 0 },
    async onShow() {
        try { if (!await prepareTabPage(this, 1)) return; this.reload(); } catch (error) { showError(error, "无法加载任务面板"); }
    },
    reload() {
        const state = appStore.getState();
        const summaries = reportSummaries(state, { kind: "day", anchor: new Date().toISOString() });
        this.setData({
            ready: true,
            sections: taskBoardSections(state),
            summaries,
            totalCompleted: summaries.reduce((sum, item) => sum + item.completedCount, 0),
            totalScore: summaries.reduce((sum, item) => sum + item.totalScore, 0)
        });
    },
    openReports() { wx.switchTab({ url: "/pages/reports/index" }); },
    taskAction(event: any) {
        const detail = event.detail;
        if (detail.action === "undo") {
            wx.showModal({ title: "撤销完成？", content: "任务会重新回到待处理列表。", success: (result) => {
                if (!result.confirm) return;
                appStore.transact((state) => undoCompletion(state, detail.taskID)).then(() => { showSuccess("已撤销"); this.reload(); }).catch((error) => showError(error));
            }});
        } else if (detail.action === "adjust") wx.navigateTo({ url: `/pages/task-editor/index?mode=adjust&taskID=${detail.taskID}` });
        else wx.navigateTo({ url: `/pages/task-action/index?mode=${detail.action}&taskID=${detail.taskID}` });
    }
});
