import { startOfWeek, toInputDate } from "../../domain/calendar";
import { saveRule } from "../../domain/services";
import { appStore } from "../../store/app-store";
import { showError, showSuccess } from "../../utils/page";

Page({
    data: {
        ready: false, ruleID: "", title: "", weekdays: ["周日", "周一", "周二", "周三", "周四", "周五", "周六"], weekdayIndex: 1,
        startDate: toInputDate(startOfWeek(new Date())), score: 1, enabled: true,
        members: [] as any[], selectedIDs: [] as string[], order: [] as string[]
    },
    async onLoad(query: Record<string, string>) {
        try {
            await appStore.initialize();
            const state = appStore.getState();
            const rule = query.ruleID && state.rules.find((item) => item.id === query.ruleID);
            this.setData({
                ready: true,
                ruleID: rule ? rule.id : "",
                title: rule ? rule.title : "",
                weekdayIndex: rule ? rule.weekday - 1 : 1,
                startDate: rule ? toInputDate(rule.startOfRotationWeek) : this.data.startDate,
                score: rule ? rule.score : 1,
                enabled: rule ? rule.isEnabled : true,
                members: state.members.map((member) => ({ ...member, selected: rule ? rule.participantIDs.includes(member.id) : true })),
                selectedIDs: rule ? rule.participantIDs : state.members.map((member) => member.id),
                order: rule ? rule.participantOrder : state.members.map((member) => member.id)
            });
        } catch (error) { showError(error, "无法打开规则"); }
    },
    updateTitle(event: any) { this.setData({ title: event.detail.value }); },
    updateWeekday(event: any) { this.setData({ weekdayIndex: Number(event.detail.value) }); },
    updateStart(event: any) { this.setData({ startDate: event.detail.value }); },
    updateScore(event: any) { this.setData({ score: Number(event.detail.value) }); },
    updateEnabled(event: any) { this.setData({ enabled: event.detail.value }); },
    toggleMember(event: any) {
        const id = String(event.currentTarget.dataset.id);
        const selected = this.data.selectedIDs.includes(id);
        const selectedIDs = selected ? this.data.selectedIDs.filter((item) => item !== id) : this.data.selectedIDs.concat(id);
        let order = this.data.order.filter((item) => selectedIDs.includes(item));
        selectedIDs.forEach((item) => { if (!order.includes(item)) order.push(item); });
        this.setData({ selectedIDs, order, members: this.data.members.map((member) => ({ ...member, selected: selectedIDs.includes(member.id) })) });
    },
    moveMember(event: any) {
        const index = Number(event.currentTarget.dataset.index);
        const delta = Number(event.currentTarget.dataset.delta);
        const destination = index + delta;
        if (destination < 0 || destination >= this.data.order.length) return;
        const order = this.data.order.slice();
        const item = order[index];
        if (!item) return;
        order.splice(index, 1); order.splice(destination, 0, item);
        this.setData({ order });
    },
    memberName(id: string): string { const member = this.data.members.find((item) => item.id === id); return member ? member.name : ""; },
    async save() {
        try {
            await appStore.transact((state) => saveRule(state, { id: this.data.ruleID || undefined, title: this.data.title, weekday: this.data.weekdayIndex + 1, startOfRotationWeek: this.data.startDate, participantIDs: this.data.selectedIDs, participantOrder: this.data.order, isEnabled: this.data.enabled, score: Number(this.data.score) }));
            showSuccess("已保存");
            setTimeout(() => wx.navigateBack(), 500);
        } catch (error) { showError(error, "无法保存规则"); }
    }
});
