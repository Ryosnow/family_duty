import { createID } from "../../domain/id";
import { requireTitle } from "../../domain/validation";
import { appStore } from "../../store/app-store";
import { showError, showSuccess } from "../../utils/page";

Page({
    data: { ready: false, memberID: "", name: "", initial: "家", colorName: "blue", colors: [{ name: "blue", title: "海蓝" }, { name: "purple", title: "葡萄紫" }, { name: "orange", title: "暖橙" }, { name: "green", title: "青草绿" }, { name: "pink", title: "樱花粉" }, { name: "teal", title: "湖水青" }] },
    async onLoad(query: Record<string, string>) {
        try { await appStore.initialize(); const member = query.memberID && appStore.getState().members.find((item) => item.id === query.memberID); this.setData({ ready: true, memberID: member ? member.id : "", name: member ? member.name : "", initial: member ? member.name.slice(0, 1) : "家", colorName: member ? member.colorName : "blue" }); } catch (error) { showError(error); }
    },
    updateName(event: any) { const name = event.detail.value; this.setData({ name, initial: name.trim().slice(0, 1) || "家" }); },
    selectColor(event: any) { this.setData({ colorName: event.currentTarget.dataset.name }); },
    async save() {
        try {
            const name = requireTitle(this.data.name, "请输入成员姓名");
            await appStore.transact((state) => {
                const existing = this.data.memberID && state.members.find((item) => item.id === this.data.memberID);
                if (existing) { existing.name = name; existing.colorName = this.data.colorName; }
                else state.members.push({ id: createID(), name, colorName: this.data.colorName, sortOrder: state.members.length });
            });
            showSuccess("已保存"); setTimeout(() => wx.navigateBack(), 500);
        } catch (error) { showError(error, "无法保存成员"); }
    }
});
