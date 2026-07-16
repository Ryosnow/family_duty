import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";

const root = path.resolve(__dirname, "..");
const miniRoot = path.join(root, "miniprogram");

describe("小程序页面与组件契约", () => {
    it("注册五项纯文字自定义导航且每个页面文件完整", () => {
        const app = JSON.parse(fs.readFileSync(path.join(miniRoot, "app.json"), "utf8")) as { pages: string[]; tabBar: { custom: boolean; list: Array<{ pagePath: string; text: string }> } };
        expect(app.tabBar.custom).toBe(true);
        expect(app.tabBar.list.map((item) => item.text)).toEqual(["首页", "任务", "报表", "轮班", "设置"]);
        expect(app.tabBar.list).toHaveLength(5);
        app.pages.forEach((page) => ["ts", "json", "wxml", "wxss"].forEach((extension) => {
            expect(fs.existsSync(path.join(miniRoot, `${page}.${extension}`)), `${page}.${extension}`).toBe(true);
        }));
    });

    it("任务卡同时提供状态文字、可访问名称和完整操作入口", () => {
        const template = fs.readFileSync(path.join(miniRoot, "components/task-card/index.wxml"), "utf8");
        expect(template).toContain("aria-label");
        expect(template).toContain("task.statusText");
        expect(template).toContain('data-action="claim"');
        expect(template).toContain('data-action="complete"');
        expect(template).toContain('data-action="adjust"');
        expect(template).toContain('data-action="undo"');
    });

    it("所有绝对资源引用都指向随包提交的本地文件", () => {
        const templates: string[] = [];
        const visit = (directory: string) => fs.readdirSync(directory, { withFileTypes: true }).forEach((entry) => {
            const fullPath = path.join(directory, entry.name);
            if (entry.isDirectory()) visit(fullPath);
            else if (entry.name.endsWith(".wxml")) templates.push(fs.readFileSync(fullPath, "utf8"));
        });
        visit(miniRoot);
        const resources = templates.flatMap((template) => Array.from(template.matchAll(/src="(\/[^"]+)"/g)).map((match) => match[1]!));
        expect(resources.length).toBeGreaterThan(0);
        resources.forEach((resource) => expect(fs.existsSync(path.join(miniRoot, resource.slice(1))), resource).toBe(true));
    });
});
