import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 12) {
            connectionStrip
            statusGrid
            controls
            if !model.lastError.isEmpty {
                Text(model.lastError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            logPanel
        }
        .padding(16)
        .frame(minWidth: 880, minHeight: 620)
        .task {
            await model.refreshStatus()
        }
    }

    private var connectionStrip: some View {
        GroupBox("Connection") {
            HStack(spacing: 10) {
                TextField("amulecmd path", text: $model.commandPath)
                    .textFieldStyle(.roundedBorder)
                TextField("Host", text: $model.host)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                TextField("Port", value: $model.port, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                SecureField("Password", text: $model.password)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
            }
        }
    }

    private var statusGrid: some View {
        GroupBox("Status") {
            HStack(alignment: .top, spacing: 30) {
                statusRow("eD2k", model.status.ed2k)
                statusRow("Kad", model.status.kad)
                statusRow("Download", model.status.downloadSpeed)
                statusRow("Upload", model.status.uploadSpeed)
                statusRow("Queue", model.status.queue)
                statusRow("Sources", model.status.sources)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var controls: some View {
        HStack {
            Button("Connect") {
                model.connectAll()
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isBusy)

            Button("Disconnect") {
                model.disconnectAll()
            }
            .buttonStyle(.bordered)
            .disabled(model.isBusy)

            Button("Refresh Status") {
                Task { await model.refreshStatus() }
            }
            .buttonStyle(.bordered)
            .disabled(model.isBusy)

            Spacer()

            if model.isBusy {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var logPanel: some View {
        GroupBox("Command Log") {
            ScrollView {
                Text(model.outputLog.isEmpty ? "No command output yet." : model.outputLog)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack {
                Spacer()
                Button("Clear Log") {
                    model.resetLog()
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func statusRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(2)
        }
        .frame(width: 120, alignment: .leading)
    }
}
