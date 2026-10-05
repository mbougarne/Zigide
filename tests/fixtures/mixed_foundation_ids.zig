const foundation = @import("foundation");

test "operation IDs cannot be assigned to correlation IDs" {
    const operation: foundation.ids.OperationId = @enumFromInt(1);
    const correlation: foundation.ids.CorrelationId = operation;
    _ = correlation;
}
