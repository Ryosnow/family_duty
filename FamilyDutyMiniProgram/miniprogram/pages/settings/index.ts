import { deleteMember } from "../../domain/services";
import { BackupPayloadV1 } from "../../domain/types";
import { appStore } from "../../store/app-store";
import { prepareTabPage, showError, showSuccess } from "../../utils/page";

Page({
    data: {
        ready: false, members: [] as any[], reminderEnabled: true, dailyTime: "08:00", overdueTime: "19:00",
        storageText: "", storageWarning: false
    },
    async onShow() {
        try { if (!await prepareTabPage(this, 4)) return; await this.reload(); } catch (error) { showError(error, "无法加载设置"); }
    },
    async reload() {
        const state = appStore.getState();
        const usage = await appStore.getStorageUsage();
        this.setData({
            ready: true,
            members: state.members.slice().sort((a, b) => a.sortOrder - b.sortOrder).map((member) => ({ ...member, initial: member.name.slice(0, 1) })),
            reminderEnabled: state.reminderPreferences.enabled,
            dailyTime: state.reminderPreferences.dailyTime,
            overdueTime: state.reminderPreferences.overdueTime,
            storageText: `${(usage.currentBytes / 1024 / 1024).toFixed(2)} MB / ${(usage.limitBytes / 1024 / 1024).toFixed(0)} MB`,
            storageWarning: usage.warning
        });
    },
    addMember() { wx.navigateTo({ url: "/pages/member-editor/index" }); },
    editMember(event: any) { wx.navigateTo({ url: `/pages/member-editor/index?memberID=${event.currentTarget.dataset.id}` }); },
    deleteMember(event: any) {
        const id = String(event.currentTarget.dataset.id);
        const member = this.data.members.find((item) => item.id === id);
        wx.showModal({ title: "删除家庭成员？", content: member ? `确认删除“${member.name}”？有关联数据时会自动阻止。` : "确认删除？", confirmColor: "#C7483D", success: (result) => {
            if (!result.confirm) return;
            appStore.transact((state) => deleteMember(state, id)).then(() => { showSuccess("已删除"); this.reload(); }).catch((error) => showError(error, "暂时不能删除"));
        }});
    },
    moveMember(event: any) {
        const id = String(event.currentTarget.dataset.id);
        const delta = Number(event.currentTarget.dataset.delta);
        appStore.transact((state) => {
            const ordered = state.members.slice().sort((a, b) => a.sortOrder - b.sortOrder);
            const index = ordered.findIndex((item) => item.id === id);
            const destination = index + delta;
            if (index < 0 || destination < 0 || destination >= ordered.length) return;
            const first = ordered[index]; const second = ordered[destination];
            if (!first || !second) return;
            const order = first.sortOrder; first.sortOrder = second.sortOrder; second.sortOrder = order;
        }).then(() => this.reload()).catch((error) => showError(error));
    },
    updateReminderEnabled(event: any) { this.saveReminder({ enabled: event.detail.value }); },
    updateDailyTime(event: any) { this.saveReminder({ dailyTime: event.detail.value }); },
    updateOverdueTime(event: any) { this.saveReminder({ overdueTime: event.detail.value }); },
    saveReminder(values: { enabled?: boolean; dailyTime?: string; overdueTime?: string }) {
        appStore.transact((state) => {
            if (values.enabled !== undefined) state.reminderPreferences.enabled = values.enabled;
            if (values.dailyTime) state.reminderPreferences.dailyTime = values.dailyTime;
            if (values.overdueTime) state.reminderPreferences.overdueTime = values.overdueTime;
        }).then(() => this.reload()).catch((error) => showError(error, "无法保存提醒设置"));
    },
    async exportBackup() {
        try {
            const payload = await appStore.exportBackup();
            const data = JSON.stringify(payload, null, 2);
            const name = `family-duty-backup-${Date.now()}.json`;
            const filePath = `${wx.env.USER_DATA_PATH}/${name}`;
            const manager = wx.getFileSystemManager();
            await new Promise<void>((resolve, reject) => manager.writeFile({ filePath, data, encoding: "utf8", success: () => resolve(), fail: (error) => reject(new Error(error.errMsg)) }));
            wx.shareFileMessage({ filePath, fileName: name, fail: (error) => showError(error, "无法转发备份") });
        } catch (error) { showError(error, "无法导出备份"); }
    },
    importBackup() {
        wx.chooseMessageFile({ count: 1, type: "file", extension: ["json"], success: (result) => {
            const file = result.tempFiles[0];
            if (!file) return;
            wx.getFileSystemManager().readFile({ filePath: file.path, encoding: "utf8", success: (readResult) => {
                try {
                    const payload = JSON.parse(String(readResult.data)) as BackupPayloadV1;
                    wx.showModal({ title: "替换当前数据？", content: "恢复会完整替换当前成员、规则、任务和完成记录。", confirmColor: "#C7483D", success: (confirmResult) => {
                        if (!confirmResult.confirm) return;
                        appStore.replaceFromBackup(payload).then(() => { showSuccess("恢复成功"); this.reload(); }).catch((error) => showError(error, "备份无效"));
                    }});
                } catch (error) { showError(error, "无法读取 JSON 备份"); }
            }, fail: (error) => showError(error, "无法读取备份文件") });
        }, fail: (error) => { if (!error.errMsg.includes("cancel")) showError(error, "无法选择备份文件"); } });
    }
});
