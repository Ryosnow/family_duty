import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct DataManagementView: View {
    @Environment(\.modelContext) private var context
    @State private var exportDocument = FamilyDutyBackupDocument()
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var pendingRestoreData: Data?
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("离线备份") {
                Text("备份包含成员、轮班规则、任务和完成记录，只保存在你选择的位置。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("导出备份", systemImage: "square.and.arrow.up") { prepareExport() }
                    .frame(minHeight: FamilyDutyTheme.minimumHitSize, alignment: .leading)
                    .accessibilityIdentifier("data-export-backup")

                Button("恢复备份", systemImage: "arrow.clockwise") { isImporting = true }
                    .frame(minHeight: FamilyDutyTheme.minimumHitSize, alignment: .leading)
                    .accessibilityIdentifier("data-import-backup")
            }

            if let statusMessage {
                Section("状态") {
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("数据管理")
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "家庭值日备份"
        ) { result in
            switch result {
            case .success:
                statusMessage = "备份已导出"
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false,
            onCompletion: handleImport
        )
        .alert("替换当前数据？", isPresented: Binding(
            get: { pendingRestoreData != nil },
            set: { if !$0 { pendingRestoreData = nil } }
        )) {
            Button("恢复", role: .destructive) { restorePendingData() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("恢复会替换当前 iPad 上的家庭数据，请确认已经选择了正确的备份文件。")
        }
        .alert("数据操作失败", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "未知错误")
        }
    }

    private func prepareExport() {
        do {
            exportDocument = FamilyDutyBackupDocument(data: try LocalBackupService(context: context).exportData())
            isExporting = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing { url.stopAccessingSecurityScopedResource() }
            }
            pendingRestoreData = try Data(contentsOf: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restorePendingData() {
        guard let pendingRestoreData else { return }
        do {
            try LocalBackupService(context: context).restore(from: pendingRestoreData)
            self.pendingRestoreData = nil
            statusMessage = "备份已恢复"
        } catch {
            self.pendingRestoreData = nil
            errorMessage = error.localizedDescription
        }
    }
}
