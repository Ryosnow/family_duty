import { filterHistory } from "../../domain/services";
import { presentRecord } from "../../domain/selectors";
import { appStore } from "../../store/app-store";
import { showError } from "../../utils/page";

Page({
    data: {
        ready: false,
        query: "",
        dateScope: "all",
        dateScopes: [{ id: "all", title: "全部日期" }, { id: "today", title: "今天" }, { id: "last7", title: "最近 7 天" }, { id: "month", title: "本月" }, { id: "custom", title: "自定义" }],
        dateScopeIndex: 0,
        startDate: "",
        endDate: "",
        members: [{ id: "", name: "全部成员" }] as Array<{ id: string; name: string }>,
        memberIndex: 0,
        rows: [] as any[]
    },
    async onShow() {
        try {
            await appStore.initialize();
            const state = appStore.getState();
            this.setData({ ready: true, members: [{ id: "", name: "全部成员" }].concat(state.members.map((member) => ({ id: member.id, name: member.name }))) }, () => this.reload());
        } catch (error) { showError(error, "无法加载历史记录"); }
    },
    updateQuery(event: any) { this.setData({ query: event.detail.value }, () => this.reload()); },
    selectDateScope(event: any) { const index = Number(event.detail.value); const scope = this.data.dateScopes[index]; if (scope) this.setData({ dateScopeIndex: index, dateScope: scope.id }, () => this.reload()); },
    selectMember(event: any) { this.setData({ memberIndex: Number(event.detail.value) }, () => this.reload()); },
    updateStart(event: any) { this.setData({ startDate: event.detail.value }, () => this.reload()); },
    updateEnd(event: any) { this.setData({ endDate: event.detail.value }, () => this.reload()); },
    reload() {
        const member = this.data.members[this.data.memberIndex];
        const records = filterHistory(appStore.getState(), { dateScope: this.data.dateScope as any, memberID: member && member.id || undefined, titleQuery: this.data.query, startDate: this.data.startDate || undefined, endDate: this.data.endDate || undefined });
        const state = appStore.getState();
        this.setData({ rows: records.map((record) => presentRecord(state, record)) });
    },
    openDetail(event: any) { wx.navigateTo({ url: `/pages/history-detail/index?recordID=${event.currentTarget.dataset.id}` }); }
});
