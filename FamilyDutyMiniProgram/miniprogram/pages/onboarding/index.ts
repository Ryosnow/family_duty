import { createID } from "../../domain/id";
import { createOnboardingData } from "../../domain/services";
import { appStore } from "../../store/app-store";
import { showError } from "../../utils/page";

interface MemberDraft { id: string; name: string; colorName: string }

Page({
    data: {
        drafts: [
            { id: createID(), name: "", colorName: "blue" },
            { id: createID(), name: "", colorName: "green" }
        ] as MemberDraft[],
        colors: [
            { name: "blue", title: "海蓝" }, { name: "purple", title: "葡萄紫" },
            { name: "orange", title: "暖橙" }, { name: "green", title: "青草绿" },
            { name: "pink", title: "樱花粉" }, { name: "teal", title: "湖水青" }
        ],
        firstRuleTitle: "",
        saving: false
    },
    async onLoad() {
        try {
            await appStore.initialize();
            if (appStore.getState().members.length) wx.switchTab({ url: "/pages/dashboard/index" });
        } catch (error) { showError(error, "无法加载数据"); }
    },
    updateName(event: any) {
        const index = Number(event.currentTarget.dataset.index);
        this.setData({ [`drafts[${index}].name`]: event.detail.value });
    },
    updateColor(event: any) {
        const index = Number(event.currentTarget.dataset.index);
        const colorIndex = Number(event.detail.value);
        const color = this.data.colors[colorIndex];
        if (color) this.setData({ [`drafts[${index}].colorName`]: color.name });
    },
    updateRuleTitle(event: any) { this.setData({ firstRuleTitle: event.detail.value }); },
    addMember() {
        const next = this.data.colors[this.data.drafts.length % this.data.colors.length];
        this.setData({ drafts: this.data.drafts.concat({ id: createID(), name: "", colorName: next ? next.name : "blue" }) });
    },
    removeMember(event: any) {
        if (this.data.drafts.length <= 1) return;
        const id = String(event.currentTarget.dataset.id);
        this.setData({ drafts: this.data.drafts.filter((draft) => draft.id !== id) });
    },
    async finish() {
        if (this.data.saving) return;
        this.setData({ saving: true });
        try {
            const drafts = this.data.drafts;
            await appStore.transact((state) => createOnboardingData(
                state,
                drafts.map((draft) => draft.name),
                drafts.map((draft) => draft.colorName),
                this.data.firstRuleTitle
            ));
            wx.switchTab({ url: "/pages/dashboard/index" });
        } catch (error) {
            showError(error, "无法完成设置");
        } finally {
            this.setData({ saving: false });
        }
    }
});
