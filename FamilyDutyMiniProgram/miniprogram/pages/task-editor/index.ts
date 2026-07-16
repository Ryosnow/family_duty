import { toInputDate } from "../../domain/calendar";
import { adjustTask, createTemporaryTask } from "../../domain/services";
import { appStore } from "../../store/app-store";
import { showError, showSuccess } from "../../utils/page";

Page({
    data: {
        ready: false, mode: "create", taskID: "", title: "", date: toInputDate(new Date()), deadlineEnabled: false, deadline: toInputDate(new Date()), score: 1,
        members: [{ id: "", name: "待领取" }] as Array<{ id: string; name: string }>, memberIndex: 0,
        presets: ["洗碗", "扫地", "拖地", "倒垃圾", "擦桌子", "整理房间", "浇花", "洗衣服"], cancellationReason: ""
    },
    async onLoad(query: Record<string, string>) {
        try {
            await appStore.initialize();
            const state = appStore.getState();
            const members = [{ id: "", name: "待领取" }].concat(state.members.map((member) => ({ id: member.id, name: member.name })));
            let title = ""; let score = 1; let date = this.data.date; let deadline = date; let deadlineEnabled = false; let memberIndex = 0;
            if (query.recordID) {
                const record = state.records.find((item) => item.id === query.recordID);
                const oldTask = record && state.tasks.find((item) => item.id === record.taskID);
                if (oldTask) { title = oldTask.title; score = oldTask.score; }
            }
            const task = query.taskID && state.tasks.find((item) => item.id === query.taskID);
            if (task) {
                title = task.title; score = task.score; date = toInputDate(task.scheduledDate); deadlineEnabled = !!task.deadline; deadline = task.deadline ? toInputDate(task.deadline) : date; memberIndex = Math.max(0, members.findIndex((item) => item.id === (task.assigneeID || "")));
            }
            this.setData({ ready: true, mode: task ? "adjust" : "create", taskID: task ? task.id : "", title, score, date, deadline, deadlineEnabled, members, memberIndex });
        } catch (error) { showError(error, "无法打开任务编辑器"); }
    },
    selectPreset(event: any) { this.setData({ title: event.currentTarget.dataset.title }); },
    updateTitle(event: any) { this.setData({ title: event.detail.value }); },
    updateDate(event: any) { this.setData({ date: event.detail.value, deadline: this.data.deadlineEnabled ? this.data.deadline : event.detail.value }); },
    toggleDeadline(event: any) { this.setData({ deadlineEnabled: event.detail.value, deadline: event.detail.value ? this.data.deadline || this.data.date : this.data.deadline }); },
    updateDeadline(event: any) { this.setData({ deadline: event.detail.value }); },
    updateScore(event: any) { this.setData({ score: Number(event.detail.value) }); },
    selectMember(event: any) { this.setData({ memberIndex: Number(event.detail.value) }); },
    updateCancellation(event: any) { this.setData({ cancellationReason: event.detail.value }); },
    async save() {
        try {
            const member = this.data.members[this.data.memberIndex];
            const input = { title: this.data.title, scheduledDate: this.data.date, deadline: this.data.deadlineEnabled ? this.data.deadline : undefined, score: Number(this.data.score), assigneeID: member && member.id || undefined };
            if (this.data.mode === "adjust") await appStore.transact((state) => adjustTask(state, this.data.taskID, input));
            else await appStore.transact((state) => createTemporaryTask(state, input));
            showSuccess("已保存"); setTimeout(() => wx.navigateBack(), 500);
        } catch (error) { showError(error, "无法保存任务"); }
    },
    cancelTask() {
        wx.showModal({ title: "只取消本次任务？", content: "不会影响固定规则和未来轮换。", success: (result) => {
            if (!result.confirm) return;
            const member = this.data.members[this.data.memberIndex];
            appStore.transact((state) => adjustTask(state, this.data.taskID, { scheduledDate: this.data.date, deadline: this.data.deadlineEnabled ? this.data.deadline : undefined, score: Number(this.data.score), assigneeID: member && member.id || undefined, cancellationReason: this.data.cancellationReason }))
                .then(() => { showSuccess("已取消"); setTimeout(() => wx.navigateBack(), 500); }).catch((error) => showError(error, "无法取消任务"));
        }});
    }
});
