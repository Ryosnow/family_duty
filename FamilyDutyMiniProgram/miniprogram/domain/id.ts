export function createID(): string {
    let seed = Date.now() + Math.floor(Math.random() * 0x100000000);
    const template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx";
    return template.replace(/[xy]/g, (character) => {
        seed = (seed * 1664525 + 1013904223) >>> 0;
        const random = (seed ^ Math.floor(Math.random() * 16)) & 0xf;
        const value = character === "x" ? random : (random & 0x3) | 0x8;
        return value.toString(16);
    });
}
