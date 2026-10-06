test "all product module roots compile through their declared imports" {
    _ = @import("foundation");
    _ = @import("text");
    _ = @import("workspace");
    _ = @import("commands");
    _ = @import("application");
    _ = @import("ports");
    _ = @import("adapters");
    _ = @import("ui");
    _ = @import("composition");
}
