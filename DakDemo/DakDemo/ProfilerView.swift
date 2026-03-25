//
//  ProfilerView.swift
//  DakDemo
//

import SwiftUI
import Darwin
import QuartzCore

@MainActor
@Observable
final class ProfilerStore {
    var rss: Double = 0          // MB
    var freeMemory: Double = 0   // MB
    var cpuUsage: Double = 0     // %
    var fps: Double = 0
    var thermalState: ProcessInfo.ThermalState = .nominal

    private var timer: Timer?
    private var fpsTracker: FPSTracker?

    func start() {
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.poll()
            }
        }
        fpsTracker = FPSTracker { [weak self] currentFps in
            MainActor.assumeIsolated {
                self?.fps = currentFps
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        fpsTracker?.stop()
        fpsTracker = nil
    }

    private func poll() {
        rss = Self.residentMemory()
        freeMemory = Self.freeMemoryMB()
        cpuUsage = Self.systemCPU()
        thermalState = ProcessInfo.processInfo.thermalState
    }

    // MARK: - RSS

    private static func residentMemory() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / 1_048_576
    }

    // MARK: - Free Memory

    private static func freeMemoryMB() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let pageSize = Double(vm_kernel_page_size)
        let free = Double(stats.free_count) * pageSize
        let purgeable = Double(stats.purgeable_count) * pageSize
        return (free + purgeable) / 1_048_576
    }

    // MARK: - CPU

    private static func systemCPU() -> Double {
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &numCPUInfo)
        guard result == KERN_SUCCESS, let cpuInfo else { return 0 }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.stride))
        }
        var totalUser: Int32 = 0
        var totalSystem: Int32 = 0
        var totalIdle: Int32 = 0
        for i in 0..<Int(numCPUs) {
            let base = Int(CPU_STATE_MAX) * i
            totalUser += cpuInfo[base + Int(CPU_STATE_USER)]
            totalSystem += cpuInfo[base + Int(CPU_STATE_SYSTEM)]
            totalIdle += cpuInfo[base + Int(CPU_STATE_IDLE)]
        }
        let total = totalUser + totalSystem + totalIdle
        guard total > 0 else { return 0 }
        return Double(totalUser + totalSystem) / Double(total) * 100
    }
}

// MARK: - FPS Tracker

private final class FPSTracker: @unchecked Sendable {
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount: Int = 0
    private let onUpdate: @Sendable (Double) -> Void

    init(onUpdate: @escaping @Sendable (Double) -> Void) {
        self.onUpdate = onUpdate
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
            return
        }
        frameCount += 1
        let elapsed = link.timestamp - lastTimestamp
        if elapsed >= 1.0 {
            let fps = Double(frameCount) / elapsed
            onUpdate(fps)
            frameCount = 0
            lastTimestamp = link.timestamp
        }
    }
}

// MARK: - View

struct ProfilerView: View {
    @State private var store = ProfilerStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "timer")
                    .foregroundStyle(.orange)
                Text("Profiler")
                    .font(.headline)
                Spacer()
                Text(thermalLabel)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(thermalColor.opacity(0.2), in: Capsule())
                    .foregroundStyle(thermalColor)
            }

            // Metrics grid
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                GridRow {
                    metricCell(icon: "memorychip", label: "RSS", value: formatMB(store.rss))
                    metricCell(icon: "circle.dotted", label: "Free", value: formatMB(store.freeMemory))
                }
                GridRow {
                    metricCell(icon: "cpu", label: "CPU", value: String(format: "%.0f%%", store.cpuUsage))
                    metricCell(icon: "gauge.with.dots.needle.33percent", label: "FPS", value: String(format: "%.1f", store.fps))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.separator.opacity(0.35), lineWidth: 0.5)
        )
        .onAppear { store.start() }
        .onDisappear { store.stop() }
    }

    private func metricCell(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title2.weight(.semibold).monospacedDigit())
            }
        }
    }

    private func formatMB(_ mb: Double) -> String {
        if mb >= 1000 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
    }

    private var thermalLabel: String {
        switch store.thermalState {
        case .nominal:  "Cool"
        case .fair:     "Fair"
        case .serious:  "Serious"
        case .critical: "Critical"
        @unknown default: "Unknown"
        }
    }

    private var thermalColor: Color {
        switch store.thermalState {
        case .nominal:  .green
        case .fair:     .yellow
        case .serious:  .orange
        case .critical: .red
        @unknown default: .gray
        }
    }
}

#Preview {
    ProfilerView()
        .padding()
}
