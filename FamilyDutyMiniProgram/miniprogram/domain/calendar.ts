import { ISODateString } from "./types";

export function startOfLocalDay(value: Date | string): Date {
    const date = typeof value === "string" ? new Date(value) : new Date(value.getTime());
    date.setHours(0, 0, 0, 0);
    return date;
}

export function toDayISO(value: Date | string): ISODateString {
    return startOfLocalDay(value).toISOString();
}

export function dateFromInput(value: string): Date {
    const parts = value.split("-").map(Number);
    return new Date(parts[0] || 1970, (parts[1] || 1) - 1, parts[2] || 1);
}

export function toInputDate(value: Date | string): string {
    const date = typeof value === "string" ? new Date(value) : value;
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, "0");
    const day = String(date.getDate()).padStart(2, "0");
    return `${year}-${month}-${day}`;
}

export function addDays(value: Date | string, days: number): Date {
    const result = startOfLocalDay(value);
    result.setDate(result.getDate() + days);
    return result;
}

export function addWeeks(value: Date | string, weeks: number): Date {
    return addDays(value, weeks * 7);
}

export function startOfWeek(value: Date | string): Date {
    const result = startOfLocalDay(value);
    const mondayOffset = (result.getDay() + 6) % 7;
    result.setDate(result.getDate() - mondayOffset);
    return result;
}

export function startOfMonth(value: Date | string): Date {
    const result = startOfLocalDay(value);
    result.setDate(1);
    return result;
}

export function endOfMonth(value: Date | string): Date {
    const result = startOfMonth(value);
    result.setMonth(result.getMonth() + 1);
    return result;
}

export function sameDay(first: Date | string, second: Date | string): boolean {
    return startOfLocalDay(first).getTime() === startOfLocalDay(second).getTime();
}

export function swiftWeekday(value: Date | string): number {
    const date = typeof value === "string" ? new Date(value) : value;
    return date.getDay() + 1;
}

export function daysBetween(first: Date | string, second: Date | string): number {
    const milliseconds = startOfLocalDay(second).getTime() - startOfLocalDay(first).getTime();
    return Math.round(milliseconds / 86400000);
}

export function weeksBetween(first: Date | string, second: Date | string): number {
    return Math.round(daysBetween(startOfWeek(first), startOfWeek(second)) / 7);
}

export function inHalfOpenRange(value: Date | string, start: Date, end: Date): boolean {
    const time = new Date(value).getTime();
    return time >= start.getTime() && time < end.getTime();
}

export function formatDate(value: Date | string, includeYear = false): string {
    const date = typeof value === "string" ? new Date(value) : value;
    const prefix = includeYear ? `${date.getFullYear()}年` : "";
    return `${prefix}${date.getMonth() + 1}月${date.getDate()}日`;
}

export function formatDateTime(value: Date | string): string {
    const date = typeof value === "string" ? new Date(value) : value;
    const hour = String(date.getHours()).padStart(2, "0");
    const minute = String(date.getMinutes()).padStart(2, "0");
    return `${formatDate(date, true)} ${hour}:${minute}`;
}

export function localDayKey(value: Date | string): string {
    return toInputDate(value);
}
