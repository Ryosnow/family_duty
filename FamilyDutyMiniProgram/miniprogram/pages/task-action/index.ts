import { claimTask, completeTask } from "../../domain/services";
import { appStore } from "../../store/app-store";
import { showError, showSuccess } from "../../utils/page";

Page({
    data: { ready: false, mode: "complete", taskID: "", taskTitle: "", members: [] as any[], memberIndex: 0 },
    async onLoad(query: Record<string, string>) {
        try {
            await appStore.initialize(); const state = appStore.getState(); const task = state.tasks.find((item) => item.id === query.taskID); if (!task) throw new Error("找不到这项任务");
            const defaultIndex = Math.max(0, state.members.findIndex((member) => member.id === task.assigneeID));
            this.setData({ ready: true, mode: query.mode === "claim" ? "claim" : "complete", taskID: task.id, taskTitle: task.title, members: state.members, memberIndex: defaultIndex });
        } catch (error) { showError(error, "无法打开任务"); }
    },
    selectMember(event: any) { this.setData({ memberIndex: Number(event.detail.value) }); },
    submit() {
        const member = this.data.members[this.data.memberIndex]; if (!member) return;
        const title = this.data.mode === "claim" ? "确认领取？" : "确认完成？";
        const content = this.data.mode === "claim" ? `${member.name} 将负责“${this.data.taskTitle}”` : `记录 ${member.name} 为实际完成人`;
        wx.showModal({ title, content, success: (result) => {
            if (!result.confirm) return;
            appStore.transact((state) => { if (this.data.mode === "claim") claimTask(state, this.data.taskID, member.id); else completeTask(state, this.data.taskID, member.id); })
                .then(() => { showSuccess(this.data.mode === "claim" ? "领取成功" : "已完成"); setTimeout(() => wx.navigateBack(), 500); }).catch((error) => showError(error));
        }});
    }
});
