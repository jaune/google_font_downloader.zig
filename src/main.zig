const std = @import("std");

const downloadFontFiles = @import("google_font_downloader").downloadFontFiles;

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip(); // skip arg 0

    const family = args.next() orelse {
        return error.MissingArgumentFamily;
    };

    const input_output_path = args.next() orelse {
        return error.MissingArgumentOutputPath;
    };

    if (std.fs.path.isAbsolute(input_output_path)) {
        return error.AbsolutePath;
    }

    const cwd_path = try std.fs.cwd().realpathAlloc(allocator, ".");
    defer allocator.free(cwd_path);

    const resolved_path_file = try std.fs.path.resolve(allocator, &[_][]const u8{ cwd_path, input_output_path });
    defer allocator.free(resolved_path_file);

    try downloadFontFiles(allocator, family, resolved_path_file);
}
