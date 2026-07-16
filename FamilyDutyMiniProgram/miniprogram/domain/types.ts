export type ISODateString = string;
export type TaskStatus = "pending" | "completed" | "cancelled";

export interface FamilyMember {
    id: string;
    name: string;
    colorName: string;
    sortOrder: number;
}

export interface ChoreRule {
    id: string;
    title: string;
    weekday: number;
    startOfRotationWeek: ISODateString;
    isEnabled: boolean;
    score: number;
    participantIDs: string[];
    participantOrder: string[];
}

export interface ChoreTask {
    id: string;
    title: string;
    scheduledDate: ISODateString;
    sourceScheduledDate?: ISODateString;
    deadline?: ISODateString;
    score: number;
    isTemporary: boolean;
    isOneOffOverride: boolean;
    status: TaskStatus;
    adjustmentNote?: string;
    assigneeID?: string;
    ruleID?: string;
}

export interface CompletionRecord {
    id: string;
    completedAt: ISODateString;
    workDate: ISODateString;
    score: number;
    completedByName?: string;
    taskID: string;
    completedByID: string;
}

export interface ReminderPreferences {
    enabled: boolean;
    dailyTime: string;
    overdueTime: string;
    lastDailyReminderDay?: string;
    lastOverdueReminderDay?: string;
}

export interface AppStateV1 {
    schemaVersion: 1;
    members: FamilyMember[];
    rules: ChoreRule[];
    tasks: ChoreTask[];
    records: CompletionRecord[];
    reminderPreferences: ReminderPreferences;
}

export interface BackupPayloadV1 {
    schemaVersion: 1;
    members: FamilyMember[];
    rules: ChoreRule[];
    tasks: Array<{
        id: string;
        title: string;
        scheduledDate: ISODateString;
        sourceScheduledDate?: ISODateString;
        deadline?: ISODateString;
        score: number;
        isTemporary: boolean;
        isOneOffOverride?: boolean;
        statusRaw: TaskStatus;
        adjustmentNote?: string;
        assigneeID?: string;
        ruleID?: string;
    }>;
    records: CompletionRecord[];
}

export interface StorageUsage {
    currentBytes: number;
    limitBytes: number;
    warning: boolean;
}

export function createDefaultState(): AppStateV1 {
    return {
        schemaVersion: 1,
        members: [],
        rules: [],
        tasks: [],
        records: [],
        reminderPreferences: {
            enabled: true,
            dailyTime: "08:00",
            overdueTime: "19:00"
        }
    };
}
