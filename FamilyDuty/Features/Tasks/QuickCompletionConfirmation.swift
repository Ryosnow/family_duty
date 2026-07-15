import SwiftUI

struct QuickCompletionConfirmation: ViewModifier {
    @Binding var task: ChoreTask?
    @Binding var isPresented: Bool
    let onConfirm: (ChoreTask) -> Void

    func body(content: Content) -> some View {
        content.alert("确认完成？", isPresented: $isPresented) {
            Button("确认完成") {
                guard let task else { return }
                onConfirm(task)
                self.task = nil
            }
            Button("取消", role: .cancel) {
                task = nil
            }
        } message: {
            Text("确认将“\(task?.title ?? "这项任务")”标记为已完成。")
        }
    }
}

extension View {
    func quickCompletionConfirmation(
        task: Binding<ChoreTask?>,
        isPresented: Binding<Bool>,
        onConfirm: @escaping (ChoreTask) -> Void
    ) -> some View {
        modifier(
            QuickCompletionConfirmation(
                task: task,
                isPresented: isPresented,
                onConfirm: onConfirm
            )
        )
    }
}
