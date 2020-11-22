const std = @import("std");
const gpa = std.heap.c_allocator;

const u = @import("index.zig");

//
//

const b = 1;
const kb = b * 1024;
const mb = kb * 1024;

pub const Module = struct {
    name: []const u8,
    main: []const u8,
    c_include_dirs: [][]const u8,
    c_source_flags: [][]const u8,
    c_source_files: [][]const u8,

    deps: []Module,
    clean_path: []const u8,

    pub fn from(dep: u.Dep) !Module {
        return Module{
            .name = dep.name,
            .main = dep.main,
            .c_include_dirs = dep.c_include_dirs,
            .c_source_flags = dep.c_source_flags,
            .c_source_files = dep.c_source_files,
            .deps = &[_]Module{},
            .clean_path = try dep.clean_path(),
        };
    }

    pub fn eql(self: Module, another: Module) bool {
        return std.mem.eql(u8, self.clean_path, another.clean_path);
    }

    pub fn get_hash(self: Module, cdpath: []const u8) ![]const u8 {
        const file_list_1 = &std.ArrayList([]const u8).init(gpa);
        try u.file_list(try u.concat(&[_][]const u8{cdpath, "/", self.clean_path}), file_list_1);

        const file_list_2 = &std.ArrayList([]const u8).init(gpa);
        for (file_list_1.items) |item| {
            const _a = u.trim_prefix(item, cdpath)[1..];
            const _b = u.trim_prefix(_a, self.clean_path)[1..];
            if (_b[0] == '.') continue;
            try file_list_2.append(_b);
        }

        std.sort.sort([]const u8, file_list_2.items, void{}, struct {
            pub fn lt(context: void, lhs: []const u8, rhs: []const u8) bool {
                return std.mem.lessThan(u8, lhs, rhs);
            }
        }.lt);

        const h = &std.crypto.hash.Blake3.init(.{});
        for (file_list_2.items) |item| {
            const abs_path = try u.concat(&[_][]const u8{cdpath, "/", self.clean_path, "/", item});
            const file = try std.fs.openFileAbsolute(abs_path, .{});
            defer file.close();
            const input = try file.reader().readAllAlloc(gpa, mb);
            h.update(input);
        }
        var out: [32]u8 = undefined;
        h.final(&out);
        const hex = try std.fmt.allocPrint(gpa, "{x}", .{out});
        return hex;
    }
};
