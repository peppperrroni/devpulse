import Testing
import Darwin
@testable import DevPulseCore

struct ProcessSamplerTests {
    @Test func findsGradleDaemonMainClass() {
        let args = ["/opt/jdk/bin/java", "-Xmx2g", "-Dfile.encoding=UTF-8", "-cp",
                    "/Users/u/.gradle/wrapper/gradle-launcher-8.10.jar",
                    "org.gradle.launcher.daemon.bootstrap.GradleDaemon", "8.10"]
        #expect(ProcessNaming.javaMainClass(arguments: args) == "GradleDaemon")
    }

    @Test func findsJarName() {
        let args = ["java", "-jar", "/tmp/tools/kotlin-lsp.jar", "--stdio"]
        #expect(ProcessNaming.javaMainClass(arguments: args) == "kotlin-lsp.jar")
    }

    @Test func noMainClassReturnsNil() {
        #expect(ProcessNaming.javaMainClass(arguments: ["java", "-version"]) == nil)
    }

    @Test func currentProcessIsListedWithMemory() {
        let sampler = ProcessSampler()
        let rows = sampler.sample(apps: [:])
        let me = rows.first { $0.pid == getpid() }
        #expect(me != nil)
        #expect((me?.memory ?? 0) > 0)
        #expect(me?.isApp == false)
        #expect(rows == rows.sorted { $0.memory > $1.memory })
    }

    @Test func secondSampleHasNonNegativeCPU() {
        let sampler = ProcessSampler()
        _ = sampler.sample(apps: [:])
        var x = 0.0
        for i in 0..<2_000_000 { x += Double(i).squareRoot() }   // burn a little CPU
        #expect(x > 0)
        let me = sampler.sample(apps: [:]).first { $0.pid == getpid() }
        #expect((me?.cpuPercent ?? -1) >= 0)
    }

    @Test func appNameOverridesExecutableName() {
        let rows = ProcessSampler().sample(apps: [getpid(): "Тест"])
        let me = rows.first { $0.pid == getpid() }
        #expect(me?.name == "Тест")
        #expect(me?.isApp == true)
    }

    @Test func readsOwnArguments() {
        let args = ProcessNaming.arguments(pid: getpid())
        #expect(!args.isEmpty)
        #expect(args.first == CommandLine.arguments.first)
    }
}
