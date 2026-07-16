import { appStore } from "../store/app-store";

export async function prepareTabPage(page: any, selected: number): Promise<boolean> {
    await appStore.initialize();
    const tabBarGetter = (page as unknown as { getTabBar?: () => WechatMiniprogram.Component.TrivialInstance }).getTabBar;
    if (tabBarGetter) {
        const tabBar = tabBarGetter.call(page);
        if (tabBar) tabBar.setData({ selected });
    }
    if (!appStore.getState().members.length) {
        wx.redirectTo({ url: "/pages/onboarding/index" });
        return false;
    }
    return true;
}

export function showError(error: unknown, title = "操作失败"): void {
    const message = error instanceof Error ? error.message : String(error);
    wx.showModal({ title, content: message, showCancel: false, confirmText: "好" });
}

export function showSuccess(title: string): void {
    wx.showToast({ title, icon: "success", duration: 1600 });
}
