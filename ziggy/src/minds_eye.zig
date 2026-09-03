const std = @import("std");
const sys = @import("sys.zig");
const tui = @import("tui.zig");

pub const WindowInfo = struct {
    window_id: u32,
    app_name: []const u8,
    window_title: []const u8,
    x: i32,
    y: i32,
    width: u32,
    height: u32,
};

pub const ScreenCaptureResult = struct {
    success: bool,
    image_path: []const u8,
    width: u32,
    height: u32,
    timestamp: i64,
    error_msg: []const u8,
};

pub const MindsEye = struct {
    allocator: std.mem.Allocator,
    vision_dir: []const u8,

    pub fn init(allocator: std.mem.Allocator) MindsEye {
        const home = sys.Sys.getenv("HOME") orelse ".";
        const home_len = std.mem.sliceTo(home, 0).len;
        const vdir = std.fmt.allocPrint(allocator, "{s}/.ziggy/vision", .{home[0..home_len]}) catch ".";

        _ = sys.makeDirAll(vdir);

        return .{
            .allocator = allocator,
            .vision_dir = vdir,
        };
    }

    pub fn deinit(self: *MindsEye) void {
        self.allocator.free(self.vision_dir);
    }

    /// Capture high-resolution display snapshot via native macOS screencapture
    pub fn captureScreen(self: *MindsEye) ScreenCaptureResult {
        const ts = sys.currentTimestamp();
        const img_path = std.fmt.allocPrint(self.allocator, "{s}/screen_{d}.png", .{ self.vision_dir, ts }) catch {
            return .{ .success = false, .image_path = "", .width = 0, .height = 0, .timestamp = ts, .error_msg = "Allocation failure" };
        };

        var cmd_buf: [1024]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "screencapture -x \"{s}\"", .{img_path}) catch {
            return .{ .success = false, .image_path = "", .width = 0, .height = 0, .timestamp = ts, .error_msg = "Command buffer overflow" };
        };
        cmd_buf[cmd.len] = 0;

        const ret = sys.Sys.system(@ptrCast(&cmd_buf[0]));
        if (ret != 0) {
            return .{
                .success = false,
                .image_path = "",
                .width = 0,
                .height = 0,
                .timestamp = ts,
                .error_msg = "screencapture command failed or screen permission denied",
            };
        }

        // Query image dimensions using sips
        var dim_buf: [512]u8 = undefined;
        const sips_cmd = std.fmt.bufPrint(&dim_buf, "sips -g pixelWidth -g pixelHeight \"{s}\" 2>/dev/null", .{img_path}) catch "";
        dim_buf[sips_cmd.len] = 0;

        var width: u32 = 1920;
        var height: u32 = 1080;

        const pipe = sys.Sys.popen(@ptrCast(&dim_buf[0]), "r");
        if (pipe) |p| {
            var out_buf: [1024]u8 = undefined;
            const r = sys.Sys.fread(@ptrCast(&out_buf), 1, out_buf.len - 1, p);
            if (r > 0) {
                out_buf[r] = 0;
                var lines = std.mem.splitScalar(u8, out_buf[0..r], '\n');
                while (lines.next()) |line| {
                    if (std.mem.indexOf(u8, line, "pixelWidth:")) |idx| {
                        const val = std.mem.trim(u8, line[idx + 11 ..], " \t\r");
                        width = std.fmt.parseInt(u32, val, 10) catch 1920;
                    } else if (std.mem.indexOf(u8, line, "pixelHeight:")) |idx| {
                        const val = std.mem.trim(u8, line[idx + 12 ..], " \t\r");
                        height = std.fmt.parseInt(u32, val, 10) catch 1080;
                    }
                }
            }
            _ = sys.Sys.pclose(p);
        }

        return .{
            .success = true,
            .image_path = img_path,
            .width = width,
            .height = height,
            .timestamp = ts,
            .error_msg = "",
        };
    }

    /// Dispatch native mouse click event to coordinate (x, y)
    pub fn mouseClick(x: i32, y: i32) bool {
        var cmd_buf: [512]u8 = undefined;
        // Use cliclick if installed, otherwise AppleScript System Events
        const cmd = std.fmt.bufPrint(
            &cmd_buf,
            "osascript -e 'tell application \"System Events\" to click at {{{d}, {d}}}' 2>/dev/null || cliclick c:{d},{d} 2>/dev/null",
            .{ x, y, x, y },
        ) catch return false;
        cmd_buf[cmd.len] = 0;
        return sys.Sys.system(@ptrCast(&cmd_buf[0])) == 0;
    }

    /// Dispatch native keyboard typing into focused window
    pub fn keyboardType(text: []const u8) bool {
        var cmd_buf: [2048]u8 = undefined;
        const cmd = std.fmt.bufPrint(
            &cmd_buf,
            "osascript -e 'tell application \"System Events\" to keystroke \"{s}\"' 2>/dev/null",
            .{text},
        ) catch return false;
        cmd_buf[cmd.len] = 0;
        return sys.Sys.system(@ptrCast(&cmd_buf[0])) == 0;
    }

    /// Focus application window by name
    pub fn windowFocus(app_name: []const u8) bool {
        var cmd_buf: [512]u8 = undefined;
        const cmd = std.fmt.bufPrint(
            &cmd_buf,
            "osascript -e 'tell application \"{s}\" to activate' 2>/dev/null",
            .{app_name},
        ) catch return false;
        cmd_buf[cmd.len] = 0;
        return sys.Sys.system(@ptrCast(&cmd_buf[0])) == 0;
    }

    /// Enumerate visible system windows and layout bounds
    pub fn listWindows(self: *MindsEye, out_list: *std.ArrayList(WindowInfo)) void {
        const cmd = "osascript -e 'tell application \"System Events\" to get {name, bundle identifier} of every process whose background only is false' 2>/dev/null";
        const pipe = sys.Sys.popen(cmd, "r");
        if (pipe) |p| {
            var buf: [4096]u8 = undefined;
            const r = sys.Sys.fread(@ptrCast(&buf), 1, buf.len - 1, p);
            if (r > 0) {
                buf[r] = 0;
                // Parse process names
                var it = std.mem.splitScalar(u8, buf[0..r], ',');
                var win_id: u32 = 1;
                while (it.next()) |item| {
                    const clean_item = std.mem.trim(u8, item, " \t\r\n{}");
                    if (clean_item.len > 0) {
                        const dup_name = self.allocator.dupe(u8, clean_item) catch continue;
                        out_list.append(self.allocator, .{
                            .window_id = win_id,
                            .app_name = dup_name,
                            .window_title = dup_name,
                            .x = 0,
                            .y = 0,
                            .width = 1920,
                            .height = 1080,
                        }) catch {};
                        win_id += 1;
                    }
                }
            }
            _ = sys.Sys.pclose(p);
        }
    }
};
