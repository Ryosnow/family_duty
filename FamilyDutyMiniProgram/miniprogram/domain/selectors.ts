import { addDays, formatDate, sameDay, startOfLocalDay, startOfWeek } from "./calendar";
import { isOverdue, latestRecords } from "./services";
import { AppStateV1, ChoreTask, CompletionRecord } from "./types";

export interface TaskPresentation {
    id: string;
    title: string;
    assignee: string;
    initial: string;
    assigneeID?: string;
    memberColor: string;
    dateText: string;
    deadlineText: string;
    scoreText: string;
    status: string;
    statusText: string;
    overdue: boolean;
    temporary: boolean;
    adjustmentNote: string;
}

export interface RecordPresentation {
    id: string;
    taskID: string;
    title: string;
    memberName: string;
    completedText: string;
    scoreText: string;
}

export function presentTask(state: AppStateV1, task: ChoreTask, now: Date = new Date()): TaskPresentation {
    const member = task.assigneeID && state.members.find((item) => item.id === task.assigneeID);
    const overdue = isOverdue(task, now);
    return {
        id: task.id,
        title: task.title,
        assignee: member ? member.name : "待领取",
        initial: (member ? member.name : "领").slice(0, 1),
        assigneeID: member && member.id,
        memberColor: member ? member.colorName : "green",
        dateText: `计划 ${formatDate(task.scheduledDate, true)}`,
        deadlineText: task.deadline ? `截止 ${formatDate(task.deadline, true)}` : `默认截止 ${formatDate(task.scheduledDate, true)}`,
        scoreText: `${task.score} 分`,
        status: task.status,
        statusText: overdue ? "已逾期" : task.status === "completed" ? "已完成" : task.status === "cancelled" ? "已取消" : "待处理",
        overdue,
        temporary: task.isTemporary,
        adjustmentNote: task.adjustmentNote || ""
    };
}

export function dashboardSections(state: AppStateV1, now: Date = new Date()): {
    overdue: TaskPresentation[];
    today: TaskPresentation[];
    later: TaskPresentation[];
    temporary: TaskPresentation[];
    recent: RecordPresentation[];
    progress: { completed: number; total: number; percent: number };
} {
    const todayStart = startOfLocalDay(now);
    const tomorrow = addDays(todayStart, 1);
    const endOfWeek = addDays(startOfWeek(now), 7);
    const pending = state.tasks.filter((task) => task.status === "pending").sort((a, b) => a.scheduledDate.localeCompare(b.scheduledDate));
    const overdueTasks = pending.filter((task) => isOverdue(task, now));
    const activeToday = state.tasks.filter((task) => task.status !== "cancelled" && sameDay(task.scheduledDate, now));
    const completed = activeToday.filter((task) => task.status === "completed").length;
    const present = (tasks: ChoreTask[]) => tasks.map((task) => presentTask(state, task, now));
    return {
        overdue: present(overdueTasks),
        today: present(pending.filter((task) => !task.isTemporary && sameDay(task.scheduledDate, now) && !isOverdue(task, now))),
        later: present(pending.filter((task) => !task.isTemporary && new Date(task.scheduledDate) >= tomorrow && new Date(task.scheduledDate) < endOfWeek)),
        temporary: present(pending.filter((task) => task.isTemporary && !isOverdue(task, now))),
        recent: latestRecords(state.records).sort((a, b) => b.completedAt.localeCompare(a.completedAt)).slice(0, 8).map((record) => presentRecord(state, record)),
        progress: { completed, total: activeToday.length, percent: activeToday.length ? Math.round(completed / activeToday.length * 100) : 0 }
    };
}

export function taskBoardSections(state: AppStateV1, now: Date = new Date()): {
    pending: TaskPresentation[];
    completed: TaskPresentation[];
    cancelled: TaskPresentation[];
} {
    const today = state.tasks.filter((task) => sameDay(task.scheduledDate, now));
    const recordsByTask = new Map(latestRecords(state.records).map((record) => [record.taskID, record]));
    const pending = today.filter((task) => task.status === "pending").sort((a, b) => {
        const first = new Date(a.deadline || a.scheduledDate).getTime();
        const second = new Date(b.deadline || b.scheduledDate).getTime();
        return first - second || a.title.localeCompare(b.title);
    });
    const completed = today.filter((task) => task.status === "completed").sort((a, b) => {
        const first = recordsByTask.get(a.id);
        const second = recordsByTask.get(b.id);
        return (second ? new Date(second.completedAt).getTime() : 0) - (first ? new Date(first.completedAt).getTime() : 0);
    });
    const cancelled = today.filter((task) => task.status === "cancelled").sort((a, b) => a.title.localeCompare(b.title));
    return {
        pending: pending.map((task) => presentTask(state, task, now)),
        completed: completed.map((task) => presentTask(state, task, now)),
        cancelled: cancelled.map((task) => presentTask(state, task, now))
    };
}

export function presentRecord(state: AppStateV1, record: CompletionRecord): RecordPresentation {
    const task = state.tasks.find((item) => item.id === record.taskID);
    const member = state.members.find((item) => item.id === record.completedByID);
    return {
        id: record.id,
        taskID: record.taskID,
        title: task ? task.title : "已删除任务",
        memberName: member ? member.name : (record.completedByName || "未知成员"),
        completedText: new Date(record.completedAt).toLocaleString("zh-CN", { hour12: false }),
        scoreText: `${record.score} 分`
    };
}
