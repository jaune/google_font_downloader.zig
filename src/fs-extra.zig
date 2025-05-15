const std = @import("std");
const builtin = @import("builtin");

pub fn ensureDirAbsolute(dir_absolute: []const u8) !void {
    if (!try existsAbsolute(dir_absolute)) {
        try std.fs.cwd().makePath(dir_absolute);
    }
}

pub fn existsAbsolute(absolutePath: []const u8) !bool {
    if (!std.fs.path.isAbsolute(absolutePath)) {
        return error.NotAbsolute;
    }
    return exists(absolutePath);
}

// TODO: this should be in std lib somewhere
pub fn exists(path: []const u8) !bool {
    std.fs.cwd().access(path, .{}) catch |e| switch (e) {
        error.FileNotFound => return false,
        error.PermissionDenied => return e,
        error.InputOutput => return e,
        error.SystemResources => return e,
        error.SymLinkLoop => return e,
        error.FileBusy => return e,
        error.Unexpected => unreachable,
        error.InvalidUtf8 => return e,
        error.InvalidWtf8 => return e,
        error.ReadOnlyFileSystem => unreachable,
        error.NameTooLong => unreachable,
        error.BadPathName => unreachable,
    };
    return true;
}
