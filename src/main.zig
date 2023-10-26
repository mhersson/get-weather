const std = @import("std");
const os = @import("std").os;
const http = @import("std").http;
const mem = @import("std").mem;
const cURL = @cImport({
    @cInclude("curl/curl.h");
});

const Allocator = mem.Allocator;

const apiURL = "https://api.openweathermap.org/data/2.5/weather/?lat={s}&lon={s}&appid={s}";

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len != 3) {
        std.debug.print("Program takes exactly 2 arguments (longitude and latitude). {} given\n", .{args[1..].len});

        return;
    }

    const latitude = args[1];
    const longitude = args[2];

    const api_key = os.getenv("OPEN_WEATHER_API_KEY") orelse {
        return error.APIKeyNotFound;
    };

    const api = try std.fmt.allocPrint(allocator, apiURL, .{ latitude, longitude, api_key });

    var response_buffer = std.ArrayList(u8).init(allocator);
    defer response_buffer.deinit();

    response_buffer = try curlRequest(allocator, api);

    // std.log.info("Got response of {d} bytes", .{response_buffer.items.len});
    std.debug.print("{s}\n", .{response_buffer.items});
}

fn curlRequest(allocator: Allocator, api: []const u8) !std.ArrayList(u8) {
    const url = try std.fmt.allocPrintZ(allocator, "{s}", .{api});

    // global curl init, or fail
    if (cURL.curl_global_init(cURL.CURL_GLOBAL_ALL) != cURL.CURLE_OK)
        return error.CURLGlobalInitFailed;
    defer cURL.curl_global_cleanup();

    // curl easy handle init, or fail
    const handle = cURL.curl_easy_init() orelse return error.CURLHandleInitFailed;
    defer cURL.curl_easy_cleanup(handle);

    var response_buffer = std.ArrayList(u8).init(allocator);
    errdefer response_buffer.deinit();

    if (cURL.curl_easy_setopt(handle, cURL.CURLOPT_URL, url.ptr) != cURL.CURLE_OK)
        return error.CouldNotSetURL;

    // set write function callbacks
    if (cURL.curl_easy_setopt(handle, cURL.CURLOPT_WRITEFUNCTION, writeToArrayListCallback) != cURL.CURLE_OK)
        return error.CouldNotSetWriteCallback;
    if (cURL.curl_easy_setopt(handle, cURL.CURLOPT_WRITEDATA, &response_buffer) != cURL.CURLE_OK)
        return error.CouldNotSetWriteCallback;

    // perform
    if (cURL.curl_easy_perform(handle) != cURL.CURLE_OK)
        return error.FailedToPerformRequest;

    return response_buffer;
}

fn writeToArrayListCallback(data: *anyopaque, size: c_uint, nmemb: c_uint, user_data: *anyopaque) callconv(.C) c_uint {
    var buffer: *std.ArrayList(u8) = @alignCast(@ptrCast(user_data));
    var typed_data: [*]u8 = @ptrCast(data);
    buffer.appendSlice(typed_data[0 .. nmemb * size]) catch return 0;
    return nmemb * size;
}
