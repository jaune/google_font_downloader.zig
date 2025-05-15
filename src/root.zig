const std = @import("std");

const fsx = @import("./fs-extra.zig");

pub fn downloadFontFiles(allocator: std.mem.Allocator, family: []const u8, output_dir_path: []const u8) !void {
    if (!std.fs.path.isAbsolute(output_dir_path)) {
        return error.NotAbsolutePath;
    }

    const zip_manifest_parsed = try fetchDownloadList(allocator, family);
    defer zip_manifest_parsed.deinit();

    for (zip_manifest_parsed.value.manifest.files) |file| {
        const resolved_path_file = try std.fs.path.resolve(allocator, &[_][]const u8{ output_dir_path, file.filename });
        defer allocator.free(resolved_path_file);

        try writeAbsoluteFile(resolved_path_file, file.contents);
    }

    for (zip_manifest_parsed.value.manifest.fileRefs) |file_ref| {
        const resolved_path_file = try std.fs.path.resolve(allocator, &[_][]const u8{ output_dir_path, file_ref.filename });
        defer allocator.free(resolved_path_file);

        try downloadAbsoluteFile(allocator, file_ref.url, resolved_path_file);
    }
}

fn fetchDownloadList(allocator: std.mem.Allocator, family: []const u8) !std.json.Parsed(DownloadListJson) {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var resp = std.ArrayList(u8).init(allocator);
    defer resp.deinit();

    const url = try std.fmt.allocPrint(allocator, "https://fonts.google.com/download/list?family={s}", .{family});
    defer allocator.free(url);

    var fetch_res = client.fetch(.{
        .location = .{ .url = url },
        .response_storage = .{ .dynamic = &resp },
        .max_append_size = 50 * 1024 * 1024,
    }) catch |err| {
        std.log.err("unable to fetch: error: {s}", .{@errorName(err)});
        return error.FetchFailed;
    };
    if (fetch_res.status.class() != .success) {
        std.log.err("unable to fetch: HTTP {}", .{fetch_res.status});
        return error.FetchFailed;
    }

    // NOTE: remove google's weird padding
    const index_start_json = std.mem.indexOfScalar(u8, resp.items, '{') orelse {
        return error.FetchFailed;
    };

    const zip_manifest_parsed = try std.json.parseFromSlice(DownloadListJson, allocator, resp.items[index_start_json..], .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = true,
    });

    return zip_manifest_parsed;
}

const DownloadListFileJson = struct {
    contents: []const u8,
    filename: []const u8,
};

const DownloadListFileRefJson = struct {
    url: []const u8,
    filename: []const u8,
};

const DownloadListJson = struct {
    zipName: []const u8,
    manifest: struct {
        fileRefs: []const DownloadListFileRefJson,
        files: []const DownloadListFileJson,
    },
};

fn downloadAbsoluteFile(
    allocator: std.mem.Allocator,
    url: []const u8,
    output_file_path: []const u8,
) !void {
    if (!std.fs.path.isAbsolute(output_file_path)) {
        return error.NotAbolutePath;
    }

    std.log.info("downloading {s} => {s}", .{ url, output_file_path });
    var resp = std.ArrayList(u8).init(allocator);
    defer resp.deinit();
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var fetch_res = client.fetch(.{
        .location = .{ .url = url },
        .response_storage = .{ .dynamic = &resp },
        .max_append_size = 50 * 1024 * 1024,
    }) catch |err| {
        std.log.err("unable to fetch: error: {s}", .{@errorName(err)});
        return error.FetchFailed;
    };
    if (fetch_res.status.class() != .success) {
        std.log.err("unable to fetch: HTTP {}", .{fetch_res.status});
        return error.FetchFailed;
    }

    try writeAbsoluteFile(output_file_path, resp.items);
}

fn writeAbsoluteFile(
    output_file_path: []const u8,
    contents: []const u8,
) !void {
    if (!std.fs.path.isAbsolute(output_file_path)) {
        return error.NotAbolutePath;
    }

    const output_dir_path = std.fs.path.dirname(output_file_path) orelse {
        return error.DirnameFailed;
    };

    try fsx.ensureDirAbsolute(output_dir_path);

    var file = try std.fs.createFileAbsolute(output_file_path, .{});
    defer file.close();

    try file.writeAll(contents);
}
