import { AppStateV1, BackupPayloadV1, TaskStatus } from "./types";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const VALID_STATUSES: TaskStatus[] = ["pending", "completed", "cancelled"];

export class DomainError extends Error {
    constructor(message: string) {
        super(message);
        this.name = "DomainError";
    }
}

export function requireTitle(value: string, message = "请输入任务名称"): string {
    const title = value.trim();
    if (!title) throw new DomainError(message);
    return title;
}

export function requireScore(value: number): number {
    if (!Number.isInteger(value) || value < 1) throw new DomainError("得分必须是大于等于 1 的整数");
    return value;
}

function requireUnique(values: string[], label: string): void {
    if (new Set(values).size !== values.length) throw new DomainError(`备份中存在重复的${label}标识`);
}

function requireISODate(value: string, label: string): void {
    if (!value || Number.isNaN(new Date(value).getTime())) throw new DomainError(`${label}日期无效`);
}

function requireID(value: string, label: string): void {
    if (!UUID_PATTERN.test(value)) throw new DomainError(`${label}标识无效`);
}

export function validateState(state: AppStateV1): void {
    if (state.schemaVersion !== 1) throw new DomainError(`不支持的数据版本：${state.schemaVersion}`);
    const payload = stateToBackupShape(state);
    validateBackup(payload);
}

export function validateBackup(payload: BackupPayloadV1): void {
    if (!payload || payload.schemaVersion !== 1) {
        const version = payload && payload.schemaVersion;
        throw new DomainError(`不支持的备份版本：${String(version)}`);
    }
    requireUnique(payload.members.map((item) => item.id), "成员");
    requireUnique(payload.rules.map((item) => item.id), "规则");
    requireUnique(payload.tasks.map((item) => item.id), "任务");
    requireUnique(payload.records.map((item) => item.id), "完成记录");

    const memberIDs = new Set(payload.members.map((item) => item.id));
    const ruleIDs = new Set(payload.rules.map((item) => item.id));
    const taskIDs = new Set(payload.tasks.map((item) => item.id));
    payload.members.forEach((member) => {
        requireID(member.id, "成员");
        requireTitle(member.name, "成员姓名不能为空");
    });
    payload.rules.forEach((rule) => {
        requireID(rule.id, "规则");
        requireTitle(rule.title, "规则标题不能为空");
        requireISODate(rule.startOfRotationWeek, "轮换起始周");
        requireScore(rule.score);
        if (rule.weekday < 1 || rule.weekday > 7) throw new DomainError("规则星期无效");
        if (!rule.participantIDs.length) throw new DomainError("规则至少需要一名参与成员");
        if (new Set(rule.participantIDs).size !== rule.participantIDs.length) throw new DomainError("规则参与成员重复");
        if (rule.participantIDs.some((id) => !memberIDs.has(id))) throw new DomainError("规则参与成员引用不存在");
        if (rule.participantOrder.length !== rule.participantIDs.length || rule.participantOrder.some((id) => !rule.participantIDs.includes(id))) {
            throw new DomainError("规则参与成员顺序无效");
        }
    });
    payload.tasks.forEach((task) => {
        requireID(task.id, "任务");
        requireTitle(task.title);
        requireISODate(task.scheduledDate, "任务计划");
        if (task.sourceScheduledDate) requireISODate(task.sourceScheduledDate, "任务来源");
        if (task.deadline) requireISODate(task.deadline, "任务截止");
        requireScore(task.score);
        if (!VALID_STATUSES.includes(task.statusRaw)) throw new DomainError("任务状态无效");
        if (task.assigneeID && !memberIDs.has(task.assigneeID)) throw new DomainError("任务负责人引用不存在");
        if (task.ruleID && !ruleIDs.has(task.ruleID)) throw new DomainError("任务规则引用不存在");
        if (task.isTemporary && task.ruleID) throw new DomainError("临时任务不能关联固定规则");
    });
    payload.records.forEach((record) => {
        requireID(record.id, "完成记录");
        requireISODate(record.completedAt, "完成时间");
        requireISODate(record.workDate, "工作日");
        requireScore(record.score);
        if (!taskIDs.has(record.taskID)) throw new DomainError("完成记录任务引用不存在");
        if (!memberIDs.has(record.completedByID)) throw new DomainError("完成记录成员引用不存在");
    });
}

function stateToBackupShape(state: AppStateV1): BackupPayloadV1 {
    return {
        schemaVersion: 1,
        members: state.members,
        rules: state.rules,
        tasks: state.tasks.map((task) => ({
            id: task.id,
            title: task.title,
            scheduledDate: task.scheduledDate,
            sourceScheduledDate: task.sourceScheduledDate,
            deadline: task.deadline,
            score: task.score,
            isTemporary: task.isTemporary,
            isOneOffOverride: task.isOneOffOverride,
            statusRaw: task.status,
            adjustmentNote: task.adjustmentNote,
            assigneeID: task.assigneeID,
            ruleID: task.ruleID
        })),
        records: state.records
    };
}
