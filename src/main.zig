const std = @import("std");
const posix = @import("std").posix;
const http = @import("std").http;
const mem = @import("std").mem;
const cURL = @cImport({
    @cInclude("curl/curl.h");
});

const Allocator = mem.Allocator;

const apiURL = "https://api.openweathermap.org/data/2.5/weather/?lat={s}&lon={s}&appid={s}";

const Response = struct {
    name: []const u8,
    weather: []struct {
        id: i64,
        main: []const u8,
        description: []const u8,
        icon: []const u8,
    },
    main: struct {
        temp: f32,
    },
    wind: struct {
        speed: f32,
    },
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const stdout = std.io.getStdOut().writer();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len != 3) {
        std.debug.print("Program takes exactly 2 arguments (longitude and latitude). {} given\n", .{args[1..].len});
        return;
    }

    const latitude = args[1];
    const longitude = args[2];

    const api_key = posix.getenv("OPEN_WEATHER_MAP_API_KEY") orelse {
        try stdout.print("{{\"text\":\"missing key\"}}\n", .{});
        return;
    };

    const api = try std.fmt.allocPrint(allocator, apiURL, .{ latitude, longitude, api_key });

    var response_buffer = std.ArrayList(u8).init(allocator);
    defer response_buffer.deinit();

    response_buffer = curlRequest(allocator, api) catch {
        try stdout.print("{{\"text\":\"error\"}}\n", .{});
        return;
    };

    const options = std.json.ParseOptions{ .ignore_unknown_fields = true };

    const response = try std.json.parseFromSlice(Response, allocator, response_buffer.items, options);
    defer response.deinit();

    if (response.value.weather.len == 0) {
        try stdout.print("{{\"text\":\"no weather data\"}}\n", .{});
        return;
    }

    var temp = response.value.main.temp - 273.15;

    var tempPrefix = "+";
    if (temp < 0) {
        temp *= -1;
        tempPrefix = "-";
    }

    const icon = getIcon(response.value.weather[0].id);

    try stdout.print("{{\"text\":\"{s} {s}{d:2.1}°C\", \"tooltip\":\"{s}: {s} {s} 🌡️{s}{d:2.1}°C  🌬️ {d:2.1}m/s\"}}\n", .{
        icon,
        tempPrefix,
        temp,
        response.value.name,
        icon,
        response.value.weather[0].description,
        tempPrefix,
        temp,
        response.value.wind.speed,
    });
}

fn getIcon(id: i64) []const u8 {
    switch (id) {
        200...299 => return "🌩",
        300...399, 501...599 => return "☔",
        500 => return "🌦",
        600...699 => return "⛄",
        700...799 => return "🌫",
        800 => return "🌞",
        801 => return "⛅",
        802...804 => return "☁",
        else => return "",
    }
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
