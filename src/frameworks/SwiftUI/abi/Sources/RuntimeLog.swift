// Runtime diagnostics requested by SDK-built SwiftUI app code.
import os.log


public enum Log {
    public static var runtimeIssuesLog: OSLog {
        darlingRuntimeLog("com.apple.SwiftUI", "Runtime Issues")
    }
}
