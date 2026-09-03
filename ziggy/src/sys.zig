const std = @import("std");

pub const O_RDONLY: c_int = 0x0000;
pub const O_WRONLY: c_int = 0x0001;
pub const O_RDWR: c_int = 0x0002;
pub const O_CREAT: c_int = 0x0200;
pub const O_TRUNC: c_int = 0x0400;
pub const O_APPEND: c_int = 0x0008;

pub const Stat = extern struct {
    st_dev: i32,
    st_mode: u16,
    st_nlink: u16,
    st_ino: u64,
    st_uid: u32,
    st_gid: u32,
    st_rdev: i32,
    st_atime: i64,
    st_atimensec: i64,
    st_mtime: i64,
    st_mtimensec: i64,
    st_ctime: i64,
    st_ctimensec: i64,
    st_birthtime: i64,
    st_birthtimensec: i64,
    st_size: i64,
    st_blocks: i64,
    st_blksize: i32,
    st_flags: u32,
    st_gen: u32,
    st_lspare: i32,
    st_qspare: [2]i64,
};

pub const Timespec = extern struct {
    tv_sec: i64,
    tv_nsec: c_long,
};

pub const Termios = extern struct {
    c_iflag: c_ulong,
    c_oflag: c_ulong,
    c_cflag: c_ulong,
    c_lflag: c_ulong,
    c_cc: [20]u8,
    c_ispeed: c_ulong,
    c_ospeed: c_ulong,
};

pub const DARWIN_ICANON: c_ulong = 0x00000100;
pub const DARWIN_ECHO: c_ulong = 0x00000008;
pub const DARWIN_ISIG: c_ulong = 0x00000080;
pub const DARWIN_IEXTEN: c_ulong = 0x00000400;
pub const VMIN: usize = 16;
pub const VTIME: usize = 17;
pub const TCSANOW: c_int = 0;

pub const Sys = struct {
    pub extern fn open(path: [*:0]const u8, flags: c_int, ...) c_int;
    pub extern fn close(fd: c_int) c_int;
    pub extern fn read(fd: c_int, buf: [*]u8, count: usize) isize;
    pub extern fn write(fd: c_int, buf: [*]const u8, count: usize) isize;
    pub extern fn unlink(path: [*:0]const u8) c_int;
    pub extern fn mkdir(path: [*:0]const u8, mode: c_uint) c_int;
    pub extern fn stat(path: [*:0]const u8, buf: *Stat) c_int;
    pub extern fn nanosleep(req: *const Timespec, rem: ?*Timespec) c_int;
    pub extern fn tcgetattr(fd: c_int, termios_p: *Termios) c_int;
    pub extern fn tcsetattr(fd: c_int, optional_actions: c_int, termios_p: *const Termios) c_int;
    pub extern fn isatty(fd: c_int) c_int;
    pub extern fn system(command: [*:0]const u8) c_int;
    pub extern fn popen(command: [*:0]const u8, mode: [*:0]const u8) ?*anyopaque;
    pub extern fn pclose(stream: *anyopaque) c_int;
    pub extern fn fread(ptr: [*]u8, size: usize, nmemb: usize, stream: *anyopaque) usize;
    pub extern fn clock_gettime(clk_id: c_int, tp: *Timespec) c_int;
    pub extern fn getenv(name: [*:0]const u8) ?[*:0]const u8;
};

pub fn currentTimestamp() i64 {
    var ts: Timespec = undefined;
    _ = Sys.clock_gettime(0, &ts);
    return ts.tv_sec;
}

pub fn nanoTimestamp() i128 {
    var ts: Timespec = undefined;
    _ = Sys.clock_gettime(0, &ts); // CLOCK_REALTIME = 0
    return @as(i128, ts.tv_sec) * 1_000_000_000 + ts.tv_nsec;
}

pub fn sleepMs(ms: u64) void {
    const sec: i64 = @intCast(ms / 1000);
    const nsec: c_long = @intCast((ms % 1000) * 1_000_000);
    const req = Timespec{ .tv_sec = sec, .tv_nsec = nsec };
    _ = Sys.nanosleep(&req, null);
}

pub fn makeDirAll(path: []const u8) bool {
    var buf: [1024]u8 = undefined;
    if (path.len >= buf.len - 1) return false;
    @memcpy(buf[0..path.len], path);
    buf[path.len] = 0;

    var i: usize = 0;
    while (i < path.len) : (i += 1) {
        if (buf[i] == '/' and i > 0) {
            buf[i] = 0;
            _ = Sys.mkdir(@ptrCast(&buf[0]), 0o755);
            buf[i] = '/';
        }
    }
    _ = Sys.mkdir(@ptrCast(&buf[0]), 0o755);
    return true;
}

pub fn writeEntireFile(path: []const u8, content: []const u8) bool {
    var c_path: [1024]u8 = undefined;
    if (path.len >= c_path.len - 1) return false;
    @memcpy(c_path[0..path.len], path);
    c_path[path.len] = 0;

    const fd = Sys.open(@ptrCast(&c_path[0]), O_WRONLY | O_CREAT | O_TRUNC, @as(c_uint, 0o644));
    if (fd < 0) return false;
    defer _ = Sys.close(fd);

    var written: usize = 0;
    while (written < content.len) {
        const res = Sys.write(fd, content.ptr + written, content.len - written);
        if (res <= 0) return false;
        written += @intCast(res);
    }
    return true;
}

pub fn readEntireFile(allocator: std.mem.Allocator, path: []const u8, max_bytes: usize) ?[]u8 {
    var c_path: [1024]u8 = undefined;
    if (path.len >= c_path.len - 1) return null;
    @memcpy(c_path[0..path.len], path);
    c_path[path.len] = 0;

    const fd = Sys.open(@ptrCast(&c_path[0]), O_RDONLY, @as(c_uint, 0));
    if (fd < 0) return null;
    defer _ = Sys.close(fd);

    var st: Stat = undefined;
    if (Sys.stat(@ptrCast(&c_path[0]), &st) != 0) return null;
    const file_size: usize = if (st.st_size > 0) @intCast(st.st_size) else 0;
    const to_read = if (file_size > max_bytes) max_bytes else file_size;

    const mem_buf = allocator.alloc(u8, to_read) catch return null;
    var total_read: usize = 0;
    while (total_read < to_read) {
        const res = Sys.read(fd, mem_buf.ptr + total_read, to_read - total_read);
        if (res <= 0) break;
        total_read += @intCast(res);
    }
    return mem_buf[0..total_read];
}

pub const F_GETFL: c_int = 3;
pub const F_SETFL: c_int = 4;
pub const O_NONBLOCK: c_int = 0x0004;

pub fn setStdinNonBlocking(nonblocking: bool) void {
    var raw: Termios = undefined;
    if (Sys.tcgetattr(0, &raw) != 0) return;
    if (nonblocking) {
        raw.c_lflag &= ~@as(c_ulong, 0x00000008 | 0x00000002); // ~ICANON, ~ECHO
        raw.c_cc[16] = 0; // VMIN = 0
        raw.c_cc[17] = 0; // VTIME = 0
    } else {
        raw.c_lflag |= (0x00000008 | 0x00000002); // ICANON, ECHO
    }
    _ = Sys.tcsetattr(0, 0, &raw);
}

pub fn checkEscapeOrSteering(buffer: []u8) ?[]const u8 {
    setStdinNonBlocking(true);
    defer setStdinNonBlocking(false);

    var temp_buf: [1024]u8 = undefined;
    const r = Sys.read(0, @ptrCast(&temp_buf), temp_buf.len);
    if (r <= 0) return null;

    const read_len: usize = @intCast(r);
    // Check if ESC (27)
    if (temp_buf[0] == 27 and read_len == 1) {
        return "\x1b";
    }

    const len = @min(read_len, buffer.len);
    @memcpy(buffer[0..len], temp_buf[0..len]);
    return buffer[0..len];
}
