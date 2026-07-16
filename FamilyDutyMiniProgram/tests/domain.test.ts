import { describe, expect, it } from "vitest";
import { addDays, startOfWeek, swiftWeekday, toDayISO } from "../miniprogram/domain/calendar";
import { createID } from "../miniprogram/domain/id";
import {
    adjustTask,
    assigneeForRule,
    completeTask,
    createOnboardingData,
    createTemporaryTask,
    dailyDataPoints,
    ensureTasks,
    evaluateReminder,
    filterHistory,
    isOverdue,
    latestRecords,
    plannedSummaries,
    reportSummaries,
    saveRule,
    undoCompletion
} from "../miniprogram/domain/services";
import { AppStateV1, createDefaultState } from "../miniprogram/domain/types";

function stateWithMembers(): AppStateV1 {
    const state = createDefaultState();
    state.members = [
        { id: createID(), name: "小明", colorName: "blue", sortOrder: 0 },
        { id: createID(), name: "小红", colorName: "green", sortOrder: 1 }
    ];
    return state;
}

describe("轮班与任务生成", () => {
    it("按起始周和 participantOrder 每周轮换，并保持生成幂等", () => {
        const state = stateWithMembers();
        const now = new Date(2026, 6, 13, 9);
        const rule = saveRule(state, {
            title: "洗碗",
            weekday: swiftWeekday(now),
            startOfRotationWeek: toDayISO(startOfWeek(now)),
            participantIDs: state.members.map((member) => member.id),
            participantOrder: [state.members[1]!.id, state.members[0]!.id],
            isEnabled: true,
            score: 2
        }, now);
        expect(assigneeForRule(state, rule, now)).toBe(state.members[1]!.id);
        expect(assigneeForRule(state, rule, addDays(now, 7))).toBe(state.members[0]!.id);
        const count = state.tasks.length;
        expect(ensureTasks(state, now)).toBe(0);
        expect(state.tasks).toHaveLength(count);
        expect(state.tasks.every((task) => task.score === 2)).toBe(true);
    });

    it("改期后的单次任务以 sourceScheduledDate 防止重复生成", () => {
        const state = stateWithMembers();
        const now = new Date(2026, 6, 13, 9);
        saveRule(state, { title: "扫地", weekday: swiftWeekday(now), startOfRotationWeek: toDayISO(startOfWeek(now)), participantIDs: state.members.map((member) => member.id), isEnabled: true, score: 1 }, now);
        const task = state.tasks[0]!;
        const source = task.sourceScheduledDate;
        adjustTask(state, task.id, { assigneeID: task.assigneeID, scheduledDate: toDayISO(addDays(task.scheduledDate, 2)), score: 3 });
        expect(task.isOneOffOverride).toBe(true);
        expect(task.sourceScheduledDate).toBe(source);
        const count = state.tasks.length;
        ensureTasks(state, now);
        expect(state.tasks).toHaveLength(count);
    });
});

describe("任务生命周期", () => {
    it("临时任务不关联规则，Deadline 次日才逾期", () => {
        const state = stateWithMembers();
        const scheduled = new Date(2026, 6, 15);
        const task = createTemporaryTask(state, { title: "擦桌子", scheduledDate: toDayISO(scheduled), score: 1 });
        expect(task.ruleID).toBeUndefined();
        expect(isOverdue(task, new Date(2026, 6, 15, 23, 59))).toBe(false);
        expect(isOverdue(task, new Date(2026, 6, 16))).toBe(true);
    });

    it("完成会快照实际完成人、工作日和分值，撤销仅删除最新记录", () => {
        const state = stateWithMembers();
        const task = createTemporaryTask(state, { title: "拖地", scheduledDate: toDayISO(new Date(2026, 6, 15)), score: 4, assigneeID: state.members[0]!.id });
        const record = completeTask(state, task.id, state.members[1]!.id, new Date(2026, 6, 16, 10));
        expect(task.status).toBe("completed");
        expect(record.completedByName).toBe("小红");
        expect(record.score).toBe(4);
        expect(record.workDate).toBe(toDayISO(new Date(2026, 6, 15)));
        undoCompletion(state, task.id);
        expect(task.status).toBe("pending");
        expect(state.records).toHaveLength(0);
    });
});

describe("报表、历史与提醒", () => {
    it("按任务保留最新完成记录并按 workDate 聚合", () => {
        const state = stateWithMembers();
        const workDay = new Date(2026, 6, 15);
        const task = createTemporaryTask(state, { title: "倒垃圾", scheduledDate: toDayISO(workDay), score: 2, assigneeID: state.members[0]!.id });
        const first = completeTask(state, task.id, state.members[0]!.id, new Date(2026, 6, 15, 9));
        const duplicate = { ...first, id: createID(), completedAt: new Date(2026, 6, 15, 10).toISOString(), score: 5 };
        state.records.push(duplicate);
        expect(latestRecords(state.records)).toEqual([duplicate]);
        const summaries = reportSummaries(state, { kind: "day", anchor: toDayISO(workDay) });
        expect(summaries[0]).toMatchObject({ memberName: "小明", completedCount: 1, totalScore: 5 });
        expect(dailyDataPoints(state, { kind: "week", anchor: toDayISO(workDay) })[0]!.totalScore).toBe(5);
        expect(plannedSummaries(state, toDayISO(workDay))[0]).toMatchObject({ assignedCount: 1, plannedScore: 2 });
        expect(filterHistory(state, { dateScope: "today", titleQuery: "垃圾" }, workDay)).toHaveLength(1);
    });

    it("同一天同类应用内提醒只返回一次", () => {
        const state = stateWithMembers();
        const now = new Date(2026, 6, 16, 20);
        createTemporaryTask(state, { title: "收衣服", scheduledDate: toDayISO(addDays(now, -1)), score: 1 });
        state.reminderPreferences.overdueTime = "19:00";
        expect(evaluateReminder(state, now)?.kind).toBe("overdue");
        expect(evaluateReminder(state, now)).toBeUndefined();
    });

    it("首次引导原子创建成员、规则和八周任务", () => {
        const state = createDefaultState();
        createOnboardingData(state, ["小明", "小红"], ["blue", "green"], "洗碗", new Date(2026, 6, 16));
        expect(state.members).toHaveLength(2);
        expect(state.rules).toHaveLength(1);
        expect(state.tasks.length).toBeGreaterThanOrEqual(8);
    });
});
