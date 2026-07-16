import {
    addDays,
    addWeeks,
    endOfMonth,
    inHalfOpenRange,
    localDayKey,
    sameDay,
    startOfLocalDay,
    startOfMonth,
    startOfWeek,
    swiftWeekday,
    toDayISO,
    weeksBetween
} from "./calendar";
import { createID } from "./id";
import {
    AppStateV1,
    ChoreRule,
    ChoreTask,
    CompletionRecord,
    FamilyMember,
    TaskStatus
} from "./types";
import { DomainError, requireScore, requireTitle } from "./validation";

export interface RuleInput {
    id?: string;
    title: string;
    weekday: number;
    startOfRotationWeek: string;
    participantIDs: string[];
    participantOrder?: string[];
    isEnabled: boolean;
    score: number;
}

export interface TaskInput {
    title: string;
    scheduledDate: string;
    deadline?: string;
    score: number;
    assigneeID?: string;
}

export interface TaskAdjustmentInput {
    assigneeID?: string;
    scheduledDate: string;
    deadline?: string;
    score: number;
    cancellationReason?: string;
}

export interface ReportPeriod {
    kind: "day" | "week" | "month";
    anchor: string;
}

export interface MemberSummary {
    memberID?: string;
    memberName: string;
    completedCount: number;
    totalScore: number;
}

export interface DailyDataPoint extends MemberSummary {
    date: string;
}

export interface PlannedSummary {
    memberID: string;
    memberName: string;
    assignedCount: number;
    plannedScore: number;
}

export interface HistoryFilter {
    dateScope: "all" | "today" | "last7" | "month" | "custom";
    memberID?: string;
    historicalName?: string;
    titleQuery?: string;
    startDate?: string;
    endDate?: string;
}

export interface ReminderResult {
    kind: "daily" | "overdue";
    title: string;
    content: string;
}

function memberByID(state: AppStateV1, id?: string): FamilyMember | undefined {
    return id ? state.members.find((member) => member.id === id) : undefined;
}

function taskByID(state: AppStateV1, id: string): ChoreTask {
    const task = state.tasks.find((item) => item.id === id);
    if (!task) throw new DomainError("找不到这项任务");
    return task;
}

export function effectiveDeadline(task: ChoreTask): Date {
    return startOfLocalDay(task.deadline || task.scheduledDate);
}

export function isOverdue(task: ChoreTask, now: Date = new Date()): boolean {
    return task.status === "pending" && startOfLocalDay(now).getTime() > effectiveDeadline(task).getTime();
}

export function validateDeadline(deadline: string | undefined, scheduledDate: string): void {
    if (deadline && startOfLocalDay(deadline).getTime() < startOfLocalDay(scheduledDate).getTime()) {
        throw new DomainError("Deadline 不能早于任务日期");
    }
}

export function assigneeForRule(state: AppStateV1, rule: ChoreRule, date: Date | string): string | undefined {
    if (!rule.isEnabled || !rule.participantOrder.length) return undefined;
    const validOrder = rule.participantOrder.filter((id) => rule.participantIDs.includes(id) && !!memberByID(state, id));
    if (!validOrder.length) return undefined;
    const weeks = weeksBetween(rule.startOfRotationWeek, date);
    const index = ((weeks % validOrder.length) + validOrder.length) % validOrder.length;
    return validOrder[index];
}

function nextOccurrence(weekday: number, onOrAfter: Date): Date {
    const difference = (weekday - swiftWeekday(onOrAfter) + 7) % 7;
    return addDays(onOrAfter, difference);
}

export function ensureTasks(state: AppStateV1, now: Date = new Date(), horizonWeeks = 8): number {
    const today = startOfLocalDay(now);
    const endDate = addWeeks(now, Math.max(horizonWeeks, 1));
    const existingKeys = new Set<string>();
    state.tasks.forEach((task) => {
        if (task.ruleID) existingKeys.add(`${task.ruleID}|${toDayISO(task.sourceScheduledDate || task.scheduledDate)}`);
    });
    let created = 0;
    state.rules.filter((rule) => rule.isEnabled).forEach((rule) => {
        let date = nextOccurrence(rule.weekday, today);
        while (date.getTime() <= endDate.getTime()) {
            const dateISO = toDayISO(date);
            const key = `${rule.id}|${dateISO}`;
            if (!existingKeys.has(key)) {
                state.tasks.push({
                    id: createID(),
                    title: rule.title,
                    scheduledDate: dateISO,
                    sourceScheduledDate: dateISO,
                    score: rule.score,
                    isTemporary: false,
                    isOneOffOverride: false,
                    status: "pending",
                    assigneeID: assigneeForRule(state, rule, date),
                    ruleID: rule.id
                });
                existingKeys.add(key);
                created += 1;
            }
            date = addWeeks(date, 1);
        }
    });
    return created;
}

export function saveRule(state: AppStateV1, input: RuleInput, now: Date = new Date()): ChoreRule {
    const title = requireTitle(input.title);
    requireScore(input.score);
    if (input.weekday < 1 || input.weekday > 7) throw new DomainError("请选择有效星期");
    const participantIDs = Array.from(new Set(input.participantIDs));
    if (!participantIDs.length) throw new DomainError("请至少选择一名家庭成员");
    if (participantIDs.some((id) => !memberByID(state, id))) throw new DomainError("参与成员不存在");
    const requestedOrder = input.participantOrder || participantIDs;
    const participantOrder = requestedOrder.filter((id) => participantIDs.includes(id));
    participantIDs.forEach((id) => {
        if (!participantOrder.includes(id)) participantOrder.push(id);
    });

    let rule: ChoreRule | undefined;
    if (input.id) rule = state.rules.find((item) => item.id === input.id);
    if (input.id && !rule) throw new DomainError("找不到这条轮班规则");
    if (rule) {
        const today = startOfLocalDay(now).getTime();
        state.tasks = state.tasks.filter((task) => {
            if (task.ruleID !== rule!.id || task.status !== "pending") return true;
            if (startOfLocalDay(task.scheduledDate).getTime() < today) return true;
            return task.isOneOffOverride || !!task.adjustmentNote || !!task.deadline || task.score !== rule!.score || (task.sourceScheduledDate && task.sourceScheduledDate !== task.scheduledDate);
        });
        rule.title = title;
        rule.weekday = input.weekday;
        rule.startOfRotationWeek = toDayISO(startOfWeek(input.startOfRotationWeek));
        rule.participantIDs = participantIDs;
        rule.participantOrder = participantOrder;
        rule.isEnabled = input.isEnabled;
        rule.score = input.score;
    } else {
        rule = {
            id: createID(),
            title,
            weekday: input.weekday,
            startOfRotationWeek: toDayISO(startOfWeek(input.startOfRotationWeek)),
            participantIDs,
            participantOrder,
            isEnabled: input.isEnabled,
            score: input.score
        };
        state.rules.push(rule);
    }
    ensureTasks(state, now);
    return rule;
}

export function createTemporaryTask(state: AppStateV1, input: TaskInput): ChoreTask {
    const title = requireTitle(input.title);
    requireScore(input.score);
    validateDeadline(input.deadline, input.scheduledDate);
    if (input.assigneeID && !memberByID(state, input.assigneeID)) throw new DomainError("负责人不存在");
    const task: ChoreTask = {
        id: createID(),
        title,
        scheduledDate: toDayISO(input.scheduledDate),
        deadline: input.deadline ? toDayISO(input.deadline) : undefined,
        score: input.score,
        isTemporary: true,
        isOneOffOverride: false,
        status: "pending",
        assigneeID: input.assigneeID
    };
    state.tasks.push(task);
    return task;
}

export function claimTask(state: AppStateV1, taskID: string, memberID: string): void {
    const task = taskByID(state, taskID);
    if (task.status !== "pending") throw new DomainError("只有待处理任务可以领取");
    if (task.assigneeID) throw new DomainError("这项任务已经有人负责");
    if (!memberByID(state, memberID)) throw new DomainError("家庭成员不存在");
    task.assigneeID = memberID;
}

export function adjustTask(state: AppStateV1, taskID: string, input: TaskAdjustmentInput): void {
    const task = taskByID(state, taskID);
    if (task.status !== "pending") throw new DomainError("只有待处理任务可以调整");
    if (input.assigneeID && !memberByID(state, input.assigneeID)) throw new DomainError("负责人不存在");
    if (input.cancellationReason !== undefined) {
        const reason = input.cancellationReason.trim();
        if (!reason) throw new DomainError("请输入取消原因");
        if (task.ruleID && !task.sourceScheduledDate) task.sourceScheduledDate = task.scheduledDate;
        task.status = "cancelled";
        task.isOneOffOverride = true;
        task.adjustmentNote = reason;
        return;
    }

    requireScore(input.score);
    validateDeadline(input.deadline, input.scheduledDate);
    const normalizedDate = toDayISO(input.scheduledDate);
    const normalizedDeadline = input.deadline ? toDayISO(input.deadline) : undefined;
    const changes: string[] = [];
    if (task.assigneeID !== input.assigneeID) changes.push("改派");
    if (!sameDay(task.scheduledDate, normalizedDate)) changes.push("改期");
    if ((task.deadline || "") !== (normalizedDeadline || "")) changes.push("截止日期");
    if (task.score !== input.score) changes.push("分值");
    if (task.ruleID && changes.length && !task.sourceScheduledDate) task.sourceScheduledDate = task.scheduledDate;
    task.assigneeID = input.assigneeID;
    task.scheduledDate = normalizedDate;
    task.deadline = normalizedDeadline;
    task.score = input.score;
    task.status = "pending";
    if (changes.length) {
        task.isOneOffOverride = true;
        task.adjustmentNote = changes.join("、");
    }
}

export function completeTask(state: AppStateV1, taskID: string, memberID: string, completedAt: Date = new Date()): CompletionRecord {
    const task = taskByID(state, taskID);
    const member = memberByID(state, memberID);
    if (task.status !== "pending") throw new DomainError("只有待处理任务可以完成");
    if (!member) throw new DomainError("实际完成人不存在");
    task.status = "completed";
    const record: CompletionRecord = {
        id: createID(),
        completedAt: completedAt.toISOString(),
        workDate: toDayISO(task.scheduledDate),
        score: task.score,
        completedByName: member.name,
        taskID: task.id,
        completedByID: member.id
    };
    state.records.push(record);
    return record;
}

export function undoCompletion(state: AppStateV1, taskID: string): void {
    const task = taskByID(state, taskID);
    if (task.status !== "completed") throw new DomainError("只有已完成任务可以撤销完成");
    const matching = state.records.filter((record) => record.taskID === taskID).sort((first, second) => {
        const dateOrder = new Date(second.completedAt).getTime() - new Date(first.completedAt).getTime();
        return dateOrder || second.id.localeCompare(first.id);
    });
    const latest = matching[0];
    if (!latest) throw new DomainError("找不到这项任务的完成记录");
    state.records = state.records.filter((record) => record.id !== latest.id);
    task.status = "pending";
}

export function deleteMember(state: AppStateV1, memberID: string): void {
    const member = memberByID(state, memberID);
    if (!member) throw new DomainError("家庭成员不存在");
    const reasons: string[] = [];
    if (state.rules.some((rule) => rule.participantIDs.includes(memberID))) reasons.push("仍参与固定轮班");
    if (state.tasks.some((task) => task.status === "pending" && task.assigneeID === memberID)) reasons.push("仍负责待处理任务");
    if (state.records.some((record) => record.completedByID === memberID)) reasons.push("仍关联完成记录");
    if (reasons.length) throw new DomainError(`暂时不能删除：${reasons.join("；")}`);
    state.members = state.members.filter((item) => item.id !== memberID);
    state.members.sort((first, second) => first.sortOrder - second.sortOrder).forEach((item, index) => { item.sortOrder = index; });
}

export function createOnboardingData(state: AppStateV1, names: string[], colorNames: string[], firstRuleTitle: string, now: Date = new Date()): void {
    if (state.members.length) throw new DomainError("家庭已经完成首次设置");
    const normalizedNames = names.map((name) => name.trim()).filter(Boolean);
    if (!normalizedNames.length) throw new DomainError("请至少添加一名家庭成员");
    normalizedNames.forEach((name, index) => {
        state.members.push({ id: createID(), name, colorName: colorNames[index] || "blue", sortOrder: index });
    });
    saveRule(state, {
        title: firstRuleTitle,
        weekday: swiftWeekday(now),
        startOfRotationWeek: toDayISO(startOfWeek(now)),
        participantIDs: state.members.map((member) => member.id),
        isEnabled: true,
        score: 1
    }, now);
}

export function latestRecords(records: CompletionRecord[]): CompletionRecord[] {
    const latest = new Map<string, CompletionRecord>();
    records.forEach((record) => {
        const existing = latest.get(record.taskID);
        if (!existing || existing.completedAt < record.completedAt || (existing.completedAt === record.completedAt && existing.id < record.id)) {
            latest.set(record.taskID, record);
        }
    });
    return Array.from(latest.values()).sort((first, second) => first.completedAt.localeCompare(second.completedAt) || first.id.localeCompare(second.id));
}

function reportInterval(period: ReportPeriod): { start: Date; end: Date } {
    const anchor = startOfLocalDay(period.anchor);
    if (period.kind === "day") return { start: anchor, end: addDays(anchor, 1) };
    if (period.kind === "week") {
        const start = startOfWeek(anchor);
        return { start, end: addDays(start, 7) };
    }
    return { start: startOfMonth(anchor), end: endOfMonth(anchor) };
}

export function reportSummaries(state: AppStateV1, period: ReportPeriod): MemberSummary[] {
    const interval = reportInterval(period);
    const accumulators = new Map<string, MemberSummary>();
    state.members.slice().sort((a, b) => a.sortOrder - b.sortOrder).forEach((member) => {
        accumulators.set(`member:${member.id}`, { memberID: member.id, memberName: member.name, completedCount: 0, totalScore: 0 });
    });
    latestRecords(state.records).filter((record) => inHalfOpenRange(record.workDate, interval.start, interval.end)).forEach((record) => {
        const member = memberByID(state, record.completedByID);
        const name = member ? member.name : (record.completedByName || "未知成员");
        const key = member ? `member:${member.id}` : `deleted:${name}`;
        const summary = accumulators.get(key) || { memberID: member && member.id, memberName: name, completedCount: 0, totalScore: 0 };
        summary.completedCount += 1;
        summary.totalScore += record.score;
        accumulators.set(key, summary);
    });
    return Array.from(accumulators.values());
}

export function dailyDataPoints(state: AppStateV1, period: ReportPeriod): DailyDataPoint[] {
    const interval = reportInterval(period);
    const points = new Map<string, DailyDataPoint>();
    latestRecords(state.records).filter((record) => inHalfOpenRange(record.workDate, interval.start, interval.end)).forEach((record) => {
        const member = memberByID(state, record.completedByID);
        const name = member ? member.name : (record.completedByName || "未知成员");
        const date = toDayISO(record.workDate);
        const key = `${date}|${member ? member.id : name}`;
        const point = points.get(key) || { date, memberID: member && member.id, memberName: name, completedCount: 0, totalScore: 0 };
        point.completedCount += 1;
        point.totalScore += record.score;
        points.set(key, point);
    });
    return Array.from(points.values()).sort((first, second) => first.date.localeCompare(second.date) || first.memberName.localeCompare(second.memberName));
}

export function plannedSummaries(state: AppStateV1, anchor: string): PlannedSummary[] {
    const start = startOfWeek(anchor);
    const end = addDays(start, 7);
    const result = state.members.slice().sort((a, b) => a.sortOrder - b.sortOrder).map((member) => ({
        memberID: member.id,
        memberName: member.name,
        assignedCount: 0,
        plannedScore: 0
    }));
    const byMember = new Map(result.map((summary) => [summary.memberID, summary]));
    state.tasks.filter((task) => !!task.assigneeID && inHalfOpenRange(task.scheduledDate, start, end)).forEach((task) => {
        const summary = task.assigneeID && byMember.get(task.assigneeID);
        if (summary) {
            summary.assignedCount += 1;
            summary.plannedScore += task.score;
        }
    });
    return result;
}

export function filterHistory(state: AppStateV1, filter: HistoryFilter, now: Date = new Date()): CompletionRecord[] {
    let start: Date | undefined;
    let end: Date | undefined;
    if (filter.dateScope === "today") {
        start = startOfLocalDay(now); end = addDays(start, 1);
    } else if (filter.dateScope === "last7") {
        end = addDays(startOfLocalDay(now), 1); start = addDays(end, -7);
    } else if (filter.dateScope === "month") {
        start = startOfMonth(now); end = endOfMonth(now);
    } else if (filter.dateScope === "custom" && filter.startDate && filter.endDate) {
        const first = startOfLocalDay(filter.startDate);
        const second = startOfLocalDay(filter.endDate);
        start = first.getTime() <= second.getTime() ? first : second;
        end = addDays(first.getTime() <= second.getTime() ? second : first, 1);
    }
    const query = (filter.titleQuery || "").trim().toLocaleLowerCase();
    return latestRecords(state.records).filter((record) => {
        if (start && end && !inHalfOpenRange(record.workDate, start, end)) return false;
        if (filter.memberID && record.completedByID !== filter.memberID) return false;
        if (filter.historicalName && memberByID(state, record.completedByID)) return false;
        if (filter.historicalName && record.completedByName !== filter.historicalName) return false;
        const task = state.tasks.find((item) => item.id === record.taskID);
        return !query || !!task && task.title.toLocaleLowerCase().includes(query);
    }).sort((first, second) => second.completedAt.localeCompare(first.completedAt) || second.id.localeCompare(first.id));
}

export function evaluateReminder(state: AppStateV1, now: Date = new Date()): ReminderResult | undefined {
    const preferences = state.reminderPreferences;
    if (!preferences.enabled) return undefined;
    const day = localDayKey(now);
    const time = `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`;
    const overdue = state.tasks.filter((task) => isOverdue(task, now));
    if (overdue.length && time >= preferences.overdueTime && preferences.lastOverdueReminderDay !== day) {
        preferences.lastOverdueReminderDay = day;
        return { kind: "overdue", title: "有逾期任务", content: `${overdue.length} 项任务仍待处理：${overdue.slice(0, 3).map((task) => task.title).join("、")}` };
    }
    const todayPending = state.tasks.filter((task) => task.status === "pending" && sameDay(task.scheduledDate, now));
    if (todayPending.length && time >= preferences.dailyTime && preferences.lastDailyReminderDay !== day) {
        preferences.lastDailyReminderDay = day;
        return { kind: "daily", title: "今日任务提醒", content: `今天还有 ${todayPending.length} 项任务待处理` };
    }
    return undefined;
}

export function statusLabel(status: TaskStatus): string {
    if (status === "completed") return "已完成";
    if (status === "cancelled") return "已取消";
    return "待处理";
}
