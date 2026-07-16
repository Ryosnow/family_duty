import { evaluateReminder, ensureTasks, ReminderResult } from "../domain/services";
import { AppStateV1, BackupPayloadV1, StorageUsage } from "../domain/types";
import { StorageRepository, WxStorageAdapter } from "../data/storage";

type Listener = (state: AppStateV1) => void;

export class AppStore {
    private state?: AppStateV1;
    private readyPromise?: Promise<AppStateV1>;
    private readonly listeners = new Set<Listener>();

    constructor(readonly repository: StorageRepository) {}

    initialize(): Promise<AppStateV1> {
        if (!this.readyPromise) {
            this.readyPromise = this.repository.load().then(async (state) => {
                this.state = state;
                const preview = JSON.parse(JSON.stringify(state)) as AppStateV1;
                if (ensureTasks(preview) > 0) {
                    await this.repository.transact((draft) => { ensureTasks(draft); });
                    this.state = await this.repository.load();
                }
                return this.getState();
            });
        }
        return this.readyPromise;
    }

    getState(): AppStateV1 {
        if (!this.state) throw new Error("应用数据尚未加载");
        return JSON.parse(JSON.stringify(this.state)) as AppStateV1;
    }

    async transact<T>(mutation: (draft: AppStateV1) => T): Promise<T> {
        await this.initialize();
        const result = await this.repository.transact(mutation);
        this.state = await this.repository.load();
        this.emit();
        return result;
    }

    async refreshGeneratedTasks(now: Date = new Date()): Promise<void> {
        if (!this.state) this.state = await this.repository.load();
        const preview = JSON.parse(JSON.stringify(this.state)) as AppStateV1;
        if (ensureTasks(preview, now) === 0) return;
        await this.transact((draft) => { ensureTasks(draft, now); });
    }

    async evaluateReminder(now: Date = new Date()): Promise<ReminderResult | undefined> {
        await this.initialize();
        const preview = this.getState();
        const result = evaluateReminder(preview, now);
        if (!result) return undefined;
        await this.transact((draft) => { evaluateReminder(draft, now); });
        return result;
    }

    async exportBackup(): Promise<BackupPayloadV1> {
        await this.initialize();
        return this.repository.exportBackup();
    }

    async replaceFromBackup(payload: BackupPayloadV1): Promise<void> {
        await this.repository.replaceFromBackup(payload);
        this.state = await this.repository.load();
        await this.refreshGeneratedTasks();
        this.emit();
    }

    async getStorageUsage(): Promise<StorageUsage> {
        return this.repository.getStorageUsage();
    }

    subscribe(listener: Listener): () => void {
        this.listeners.add(listener);
        return () => this.listeners.delete(listener);
    }

    private emit(): void {
        const state = this.getState();
        this.listeners.forEach((listener) => listener(state));
    }
}

export const appStore = new AppStore(new StorageRepository(new WxStorageAdapter()));
