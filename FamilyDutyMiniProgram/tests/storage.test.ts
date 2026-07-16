import { describe, expect, it } from "vitest";
import { MemoryStorageAdapter, StorageRepository } from "../miniprogram/data/storage";
import { createID } from "../miniprogram/domain/id";
import { createTemporaryTask } from "../miniprogram/domain/services";
import { BackupPayloadV1 } from "../miniprogram/domain/types";

async function repositoryWithMember() {
    const adapter = new MemoryStorageAdapter();
    const repository = new StorageRepository(adapter);
    const memberID = createID();
    await repository.transact((state) => state.members.push({ id: memberID, name: "小明", colorName: "blue", sortOrder: 0 }));
    return { adapter, repository, memberID };
}

describe("版本化本地仓库", () => {
    it("事务写入失败时保留旧状态", async () => {
        const { adapter, repository } = await repositoryWithMember();
        adapter.failNextSet = true;
        await expect(repository.transact((state) => state.members[0]!.name = "错误名称")).rejects.toThrow("模拟存储失败");
        expect((await repository.load()).members[0]!.name).toBe("小明");
    });

    it("活动快照损坏时回退上一份完整快照", async () => {
        const { adapter, repository, memberID } = await repositoryWithMember();
        await repository.transact((state) => { state.members[0]!.name = "第二版"; createTemporaryTask(state, { title: "扫地", scheduledDate: new Date().toISOString(), score: 1, assigneeID: memberID }); });
        const activeID = adapter.values.get("family-duty:active-snapshot") as string;
        adapter.values.set(`family-duty:snapshot:${activeID}:chunk:0`, "损坏数据");
        const recovered = await new StorageRepository(adapter).load();
        expect(recovered.members[0]!.name).toBe("小明");
        expect(recovered.tasks).toHaveLength(0);
    });

    it("导入导出保持 iPad schema version 1 字段兼容", async () => {
        const { repository, memberID } = await repositoryWithMember();
        await repository.transact((state) => createTemporaryTask(state, { title: "洗碗", scheduledDate: new Date(2026, 6, 16).toISOString(), score: 3, assigneeID: memberID }));
        const payload = await repository.exportBackup();
        expect(payload.schemaVersion).toBe(1);
        expect(payload.tasks[0]).toMatchObject({ title: "洗碗", statusRaw: "pending", isTemporary: true });

        const target = new StorageRepository(new MemoryStorageAdapter());
        await target.replaceFromBackup(payload);
        expect((await target.exportBackup()).tasks).toEqual(payload.tasks);
    });

    it("非法关系备份不会替换现有数据", async () => {
        const { repository } = await repositoryWithMember();
        const invalid: BackupPayloadV1 = { schemaVersion: 1, members: [], rules: [], tasks: [], records: [{ id: createID(), completedAt: new Date().toISOString(), workDate: new Date().toISOString(), score: 1, taskID: createID(), completedByID: createID() }] };
        await expect(repository.replaceFromBackup(invalid)).rejects.toThrow("完成记录任务引用不存在");
        expect((await repository.load()).members[0]!.name).toBe("小明");
    });
});
