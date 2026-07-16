import { formatDate, formatDateTime } from "../../domain/calendar";
import { appStore } from "../../store/app-store";
import { showError } from "../../utils/page";

Page({
    data: { ready: false, recordID: "", title: "", memberName: "", completedAt: "", workDate: "", score: 0 },
    async onLoad(query: Record<string, string>) {
        try {
            await appStore.initialize();
            const state = appStore.getState();
            const record = state.records.find((item) => item.id === query.recordID);
            if (!record) throw new Error("找不到这条完成记录");
            const task = state.tasks.find((item) => item.id === record.taskID);
            const member = state.members.find((item) => item.id === record.completedByID);
            this.setData({ ready: true, recordID: record.id, title: task ? task.title : "已删除任务", memberName: member ? member.name : (record.completedByName || "未知成员"), completedAt: formatDateTime(record.completedAt), workDate: formatDate(record.workDate, true), score: record.score });
        } catch (error) { showError(error, "无法打开详情"); }
    },
    recreate() { wx.navigateTo({ url: `/pages/task-editor/index?mode=create&recordID=${this.data.recordID}` }); }
});
