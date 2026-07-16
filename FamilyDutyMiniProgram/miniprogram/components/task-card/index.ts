import { TaskPresentation } from "../../domain/selectors";

Component({
    properties: {
        task: { type: Object, value: {} as TaskPresentation },
        showUndo: { type: Boolean, value: false },
        readonly: { type: Boolean, value: false }
    },
    methods: {
        emitAction(event: WechatMiniprogram.TouchEvent) {
            this.triggerEvent("action", { action: event.currentTarget.dataset.action, taskID: this.data.task.id });
        }
    }
});
