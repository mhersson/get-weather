# README: get-weather 🌞

get-weather is a small program written in the [Zig](https://ziglang.org)
programming language intended to be used as a custom
[Waybar](https://github.com/Alexays/Waybar) module. It requires you to have a
API key from [OpenWeatherMap](https://www.openweathermap.org) (don't worry it's
free), and it requires the API key to be available as an environment variable
called `OPEN_WEATHER_MAP_API_KEY` at runtime. Program takes 2 arguments
latitude and longitude.

Example Waybar config for get-weather

``` json

  "custom/weather": {
    "exec": "$XDG_CONFIG_HOME/waybar/get-weather 40.73 -73.93",
    "return-type": "json",
    "format": "{}",
    "tooltip": true,
    "interval": 3600
  },
```

You can test get-weather by running it in a terminal:

``` sh
$ ~/.config/waybar/get-weather 40.73 -73.93
{"text":"🌞 +13.7°C", "tooltip":"Long Island City: 🌞 clear sky 🌡️+13.7°C  🌬️ 2.6m/s"}
```

## Install instructions

You need to have Zig installed - I used `0.12.0-dev.1270+6c9d34bce` when
writing this, so at least as new as that. Take a look at the [Zig download
page](https://ziglang.org/download/) for instructions. Then just clone this
repository, and run `zig build`. (If the size of the executable matters to you;
e.g if you plan on adding it to a dotfiles repository together with you Waybar
config, you can run `zig build -Doptimize=ReleaseSmall`, and the size of the
executable will be only ~150K.) Copy the `get-weather` executable from
`zig-out/bin/get-weather` to e.g your waybar config folder like in the example
above, and you're all set.

## Why Zig

My weather module at the time used [wttr.in](https://wttr.in), but it wasn't
very accurate for the place I live. I wanted to try Zig, and this seemed like a
nice first project. I needed to implement a HTTP GET call, perform JSON
parsing, and handle other frequently required tasks. Once started it also gave
me a little bonus. I first implemented the API call by using the http module
from the Zig standard library, but then found out that the module only supports
TLS1.3, and the OpenWeatherMap API uses TLS1.2, so that didn't work. I then
decided to use libcurl, which meant I also got to try using C libraries with my
Zig code. Very cool!
