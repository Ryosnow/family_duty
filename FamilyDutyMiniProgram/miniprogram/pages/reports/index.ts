import { addDays, formatDate, startOfWeek, toInputDate } from "../../domain/calendar";
import { dailyDataPoints, plannedSummaries, reportSummaries } from "../../domain/services";
import { appStore } from "../../store/app-store";
import { prepareTabPage, showError } from "../../utils/page";

type ReportKind = "day" | "week" | "month";

Page({
    data: {
        ready: false,
        kind: "week" as ReportKind,
        anchorInput: toInputDate(new Date()),
        periodTitle: "",
        summaries: [] as any[],
        planned: [] as any[],
        points: [] as any[],
        totalCount: 0,
        totalScore: 0
    },
    async onShow() {
        try { if (!await prepareTabPage(this, 2)) return; this.reload(); } catch (error) { showError(error, "无法加载报表"); }
    },
    selectKind(event: any) { this.setData({ kind: event.currentTarget.dataset.kind as ReportKind }, () => this.reload()); },
    updateAnchor(event: any) { this.setData({ anchorInput: event.detail.value }, () => this.reload()); },
    movePeriod(event: any) {
        const direction = Number(event.currentTarget.dataset.value);
        const date = new Date(`${this.data.anchorInput}T00:00:00`);
        if (this.data.kind === "day") date.setDate(date.getDate() + direction);
        else if (this.data.kind === "week") date.setDate(date.getDate() + direction * 7);
        else date.setMonth(date.getMonth() + direction);
        this.setData({ anchorInput: toInputDate(date) }, () => this.reload());
    },
    reload() {
        const state = appStore.getState();
        const anchor = new Date(`${this.data.anchorInput}T00:00:00`);
        const period = { kind: this.data.kind, anchor: anchor.toISOString() };
        const summaries = reportSummaries(state, period);
        const rawPoints = dailyDataPoints(state, period);
        const points = rawPoints.map((point) => ({ ...point, dateText: formatDate(point.date), scoreText: `${point.totalScore} 分` }));
        let periodTitle = formatDate(anchor, true);
        if (this.data.kind === "week") periodTitle = `${formatDate(startOfWeek(anchor), true)} – ${formatDate(addDays(startOfWeek(anchor), 6))}`;
        if (this.data.kind === "month") periodTitle = `${anchor.getFullYear()}年${anchor.getMonth() + 1}月`;
        this.setData({
            ready: true,
            summaries,
            planned: plannedSummaries(state, anchor.toISOString()),
            points,
            periodTitle,
            totalCount: summaries.reduce((sum, item) => sum + item.completedCount, 0),
            totalScore: summaries.reduce((sum, item) => sum + item.totalScore, 0)
        }, () => { if (this.data.kind !== "day") this.drawTrend(rawPoints); });
    },
    drawTrend(points: ReturnType<typeof dailyDataPoints>) {
        wx.nextTick(() => {
            const query = wx.createSelectorQuery();
            query.select("#trendCanvas").fields({ node: true, size: true }).exec((result: any[]) => {
                const field = result && result[0];
                if (!field || !field.node) return;
                const canvas = field.node;
                const context = canvas.getContext("2d");
                const ratio = wx.getWindowInfo ? wx.getWindowInfo().pixelRatio : 2;
                canvas.width = field.width * ratio;
                canvas.height = field.height * ratio;
                context.scale(ratio, ratio);
                context.clearRect(0, 0, field.width, field.height);
                if (!points.length) return;
                const padding = 24;
                const maxScore = Math.max(1, ...points.map((point) => point.totalScore));
                const orderedDates = Array.from(new Set(points.map((point) => point.date))).sort();
                const colors = ["#2E7D5B", "#E89B29", "#C7483D", "#3979A9", "#A16A3A", "#4C8B8D"];
                const members = Array.from(new Set(points.map((point) => point.memberName)));
                context.strokeStyle = "#D9E1DC";
                context.lineWidth = 1;
                context.beginPath(); context.moveTo(padding, field.height - padding); context.lineTo(field.width - padding, field.height - padding); context.stroke();
                members.forEach((memberName, memberIndex) => {
                    const memberPoints = points.filter((point) => point.memberName === memberName);
                    context.strokeStyle = colors[memberIndex % colors.length];
                    context.fillStyle = context.strokeStyle;
                    context.lineWidth = 2.5;
                    context.beginPath();
                    memberPoints.forEach((point, pointIndex) => {
                        const dateIndex = orderedDates.indexOf(point.date);
                        const x = padding + (orderedDates.length === 1 ? (field.width - padding * 2) / 2 : dateIndex / (orderedDates.length - 1) * (field.width - padding * 2));
                        const y = field.height - padding - point.totalScore / maxScore * (field.height - padding * 2);
                        if (pointIndex === 0) context.moveTo(x, y); else context.lineTo(x, y);
                    });
                    context.stroke();
                    memberPoints.forEach((point) => {
                        const dateIndex = orderedDates.indexOf(point.date);
                        const x = padding + (orderedDates.length === 1 ? (field.width - padding * 2) / 2 : dateIndex / (orderedDates.length - 1) * (field.width - padding * 2));
                        const y = field.height - padding - point.totalScore / maxScore * (field.height - padding * 2);
                        context.beginPath(); context.arc(x, y, 4, 0, Math.PI * 2); context.fill();
                    });
                });
            });
        });
    },
    openHistory() { wx.navigateTo({ url: "/pages/history/index" }); }
});
