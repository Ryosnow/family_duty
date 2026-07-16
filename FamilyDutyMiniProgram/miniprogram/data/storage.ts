import { AppStateV1, BackupPayloadV1, StorageUsage, createDefaultState } from "../domain/types";
import { validateBackup, validateState } from "../domain/validation";

const ACTIVE_KEY = "family-duty:active-snapshot";
const PREVIOUS_KEY = "family-duty:previous-snapshot";
const SNAPSHOT_PREFIX = "family-duty:snapshot:";
const MAX_CHUNK_BYTES = 750 * 1024;
const WARNING_BYTES = 8 * 1024 * 1024;

interface SnapshotManifest {
    id: string;
    chunks: number;
    checksum: string;
    createdAt: string;
}

export interface StorageInfo {
    currentSizeKB: number;
    limitSizeKB: number;
}

export interface StorageAdapter {
    get<T>(key: string): Promise<T | undefined>;
    set(key: string, value: unknown): Promise<void>;
    remove(key: string): Promise<void>;
    info(): Promise<StorageInfo>;
}

export class WxStorageAdapter implements StorageAdapter {
    get<T>(key: string): Promise<T | undefined> {
        return new Promise((resolve) => {
            wx.getStorage({
                key,
                success: (result) => resolve(result.data as T),
                fail: () => resolve(undefined)
            });
        });
    }

    set(key: string, value: unknown): Promise<void> {
        return new Promise((resolve, reject) => {
            wx.setStorage({ key, data: value, success: () => resolve(), fail: (error) => reject(new Error(error.errMsg)) });
        });
    }

    remove(key: string): Promise<void> {
        return new Promise((resolve) => {
            wx.removeStorage({ key, complete: () => resolve() });
        });
    }

    info(): Promise<StorageInfo> {
        return new Promise((resolve, reject) => {
            wx.getStorageInfo({
                success: (result) => resolve({ currentSizeKB: result.currentSize, limitSizeKB: result.limitSize }),
                fail: (error) => reject(new Error(error.errMsg))
            });
        });
    }
}

export class MemoryStorageAdapter implements StorageAdapter {
    readonly values = new Map<string, unknown>();
    limitSizeKB = 10 * 1024;
    failNextSet = false;

    async get<T>(key: string): Promise<T | undefined> {
        return this.values.get(key) as T | undefined;
    }

    async set(key: string, value: unknown): Promise<void> {
        if (this.failNextSet) {
            this.failNextSet = false;
            throw new Error("模拟存储失败");
        }
        this.values.set(key, value);
    }

    async remove(key: string): Promise<void> {
        this.values.delete(key);
    }

    async info(): Promise<StorageInfo> {
        let bytes = 0;
        this.values.forEach((value, key) => { bytes += utf8ByteLength(key) + utf8ByteLength(JSON.stringify(value)); });
        return { currentSizeKB: Math.ceil(bytes / 1024), limitSizeKB: this.limitSizeKB };
    }
}

export class StorageRepository {
    private state?: AppStateV1;
    private queue: Promise<void> = Promise.resolve();

    constructor(private readonly adapter: StorageAdapter) {}

    async load(): Promise<AppStateV1> {
        if (this.state) return clone(this.state);
        const activeID = await this.adapter.get<string>(ACTIVE_KEY);
        let loaded = activeID ? await this.readSnapshot(activeID) : undefined;
        if (!loaded) {
            const previousID = await this.adapter.get<string>(PREVIOUS_KEY);
            loaded = previousID ? await this.readSnapshot(previousID) : undefined;
            if (loaded && previousID) await this.adapter.set(ACTIVE_KEY, previousID);
        }
        this.state = loaded || createDefaultState();
        validateState(this.state);
        return clone(this.state);
    }

    async transact<T>(mutation: (draft: AppStateV1) => T): Promise<T> {
        const operation = this.queue.then(async () => {
            const current = await this.load();
            const draft = clone(current);
            const result = mutation(draft);
            validateState(draft);
            await this.persist(draft);
            this.state = draft;
            return result;
        });
        this.queue = operation.then(() => undefined, () => undefined);
        return operation;
    }

    async replaceFromBackup(payload: BackupPayloadV1): Promise<void> {
        validateBackup(payload);
        await this.transact((draft) => {
            draft.members = clone(payload.members);
            draft.rules = clone(payload.rules);
            draft.tasks = payload.tasks.map((task) => ({
                id: task.id,
                title: task.title,
                scheduledDate: task.scheduledDate,
                sourceScheduledDate: task.sourceScheduledDate,
                deadline: task.deadline,
                score: task.score,
                isTemporary: task.isTemporary,
                isOneOffOverride: task.isOneOffOverride === undefined ? !!task.adjustmentNote : task.isOneOffOverride,
                status: task.statusRaw,
                adjustmentNote: task.adjustmentNote,
                assigneeID: task.assigneeID,
                ruleID: task.ruleID
            }));
            draft.records = clone(payload.records);
        });
    }

    async exportBackup(): Promise<BackupPayloadV1> {
        const state = await this.load();
        return {
            schemaVersion: 1,
            members: state.members.slice().sort((a, b) => a.sortOrder - b.sortOrder || a.id.localeCompare(b.id)),
            rules: state.rules.slice().sort((a, b) => a.id.localeCompare(b.id)),
            tasks: state.tasks.slice().sort((a, b) => a.id.localeCompare(b.id)).map((task) => ({
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
            records: state.records.slice().sort((a, b) => a.id.localeCompare(b.id))
        };
    }

    async getStorageUsage(): Promise<StorageUsage> {
        const info = await this.adapter.info();
        const currentBytes = info.currentSizeKB * 1024;
        return { currentBytes, limitBytes: info.limitSizeKB * 1024, warning: currentBytes >= WARNING_BYTES };
    }

    private async persist(state: AppStateV1): Promise<void> {
        const previousActive = await this.adapter.get<string>(ACTIVE_KEY);
        const olderPrevious = await this.adapter.get<string>(PREVIOUS_KEY);
        const id = `v1-${Date.now()}-${Math.floor(Math.random() * 1000000)}`;
        const json = JSON.stringify(state);
        const chunks = chunkUtf8(json, MAX_CHUNK_BYTES);
        const writtenKeys: string[] = [];
        try {
            for (let index = 0; index < chunks.length; index += 1) {
                const key = chunkKey(id, index);
                await this.adapter.set(key, chunks[index]);
                writtenKeys.push(key);
            }
            const manifest: SnapshotManifest = { id, chunks: chunks.length, checksum: checksum(json), createdAt: new Date().toISOString() };
            await this.adapter.set(manifestKey(id), manifest);
            writtenKeys.push(manifestKey(id));
            if (previousActive) await this.adapter.set(PREVIOUS_KEY, previousActive);
            await this.adapter.set(ACTIVE_KEY, id);
        } catch (error) {
            await Promise.all(writtenKeys.map((key) => this.adapter.remove(key)));
            throw error;
        }
        if (olderPrevious && olderPrevious !== previousActive) await this.deleteSnapshot(olderPrevious);
    }

    private async readSnapshot(id: string): Promise<AppStateV1 | undefined> {
        try {
            const manifest = await this.adapter.get<SnapshotManifest>(manifestKey(id));
            if (!manifest || manifest.id !== id || manifest.chunks < 1) return undefined;
            const values: string[] = [];
            for (let index = 0; index < manifest.chunks; index += 1) {
                const chunk = await this.adapter.get<string>(chunkKey(id, index));
                if (typeof chunk !== "string") return undefined;
                values.push(chunk);
            }
            const json = values.join("");
            if (checksum(json) !== manifest.checksum) return undefined;
            const state = JSON.parse(json) as AppStateV1;
            validateState(state);
            return state;
        } catch (_error) {
            return undefined;
        }
    }

    private async deleteSnapshot(id: string): Promise<void> {
        const manifest = await this.adapter.get<SnapshotManifest>(manifestKey(id));
        if (manifest) {
            for (let index = 0; index < manifest.chunks; index += 1) await this.adapter.remove(chunkKey(id, index));
        }
        await this.adapter.remove(manifestKey(id));
    }
}

function clone<T>(value: T): T {
    return JSON.parse(JSON.stringify(value)) as T;
}

function manifestKey(id: string): string {
    return `${SNAPSHOT_PREFIX}${id}:manifest`;
}

function chunkKey(id: string, index: number): string {
    return `${SNAPSHOT_PREFIX}${id}:chunk:${index}`;
}

function utf8ByteLength(value: string): number {
    let bytes = 0;
    for (const character of value) {
        const code = character.codePointAt(0) || 0;
        bytes += code <= 0x7f ? 1 : code <= 0x7ff ? 2 : code <= 0xffff ? 3 : 4;
    }
    return bytes;
}

function chunkUtf8(value: string, maximumBytes: number): string[] {
    const result: string[] = [];
    let current = "";
    let currentBytes = 0;
    for (const character of value) {
        const bytes = utf8ByteLength(character);
        if (current && currentBytes + bytes > maximumBytes) {
            result.push(current);
            current = "";
            currentBytes = 0;
        }
        current += character;
        currentBytes += bytes;
    }
    if (current || !result.length) result.push(current);
    return result;
}

function checksum(value: string): string {
    let hash = 2166136261;
    for (let index = 0; index < value.length; index += 1) {
        hash ^= value.charCodeAt(index);
        hash = Math.imul(hash, 16777619);
    }
    return (hash >>> 0).toString(16).padStart(8, "0");
}
