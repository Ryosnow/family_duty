import { appStore } from "./store/app-store";

App({
    onLaunch() {
        appStore.initialize().catch((error) => {
            console.error("无法加载家庭数据", error);
        });
    },
    onShow() {
        appStore.initialize()
            .then(() => appStore.refreshGeneratedTasks())
            .then(() => appStore.evaluateReminder())
            .then((reminder) => {
                if (!reminder) return;
                wx.showModal({ title: reminder.title, content: reminder.content, showCancel: false, confirmText: "知道了" });
            })
            .catch((error) => console.error("无法刷新家庭任务", error));
    }
});
