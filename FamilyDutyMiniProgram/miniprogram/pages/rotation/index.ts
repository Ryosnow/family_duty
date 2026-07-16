import { addDays, formatDate, swiftWeekday } from "../../domain/calendar";
import { assigneeForRule, ensureTasks } from "../../domain/services";
import { appStore } from "../../store/app-store";
import { prepareTabPage, showError } from "../../utils/page";

const WEEKDAYS = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"];

Page({
    data: { ready: false, rules: [] as any[] },
    async onShow() {
        try { if (!await prepareTabPage(this, 3)) return; this.reload(); } catch (error) { showError(error, "无法加载轮班"); }
    },
    reload() {
        const state = appStore.getState();
        const today = new Date();
        const rules = state.rules.map((rule) => {
            const difference = (rule.weekday - swiftWeekday(today) + 7) % 7;
            const nextDate = addDays(today, difference);
            const memberID = assigneeForRule(state, rule, nextDate);
            const member = state.members.find((item) => item.id === memberID);
            return { id: rule.id, title: rule.title, weekdayTitle: WEEKDAYS[rule.weekday - 1], enabled: rule.isEnabled, score: rule.score, nextDate: formatDate(nextDate), nextAssignee: member ? member.name : "暂无负责人", participantNames: rule.participantOrder.map((id) => { const found = state.members.find((item) => item.id === id); return found && found.name; }).filter(Boolean).join(" → ") };
        });
        this.setData({ ready: true, rules });
    },
    addRule() { wx.navigateTo({ url: "/pages/rule-editor/index" }); },
    stop() {},
    editRule(event: any) { wx.navigateTo({ url: `/pages/rule-editor/index?ruleID=${event.currentTarget.dataset.id}` }); },
    async toggleRule(event: any) {
        const id = String(event.currentTarget.dataset.id);
        try {
            await appStore.transact((state) => {
                const rule = state.rules.find((item) => item.id === id);
                if (!rule) throw new Error("找不到这条轮班规则");
                rule.isEnabled = event.detail.value;
                if (rule.isEnabled) ensureTasks(state);
            });
            this.reload();
        } catch (error) { showError(error, "无法更新规则"); }
    }
});
