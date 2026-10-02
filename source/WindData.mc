import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Forecast for one location, stored as a plain Dictionary so it can be
// persisted in Application.Storage as-is.
//   "t"  => Array of hour start times (unix seconds)
//   "e"  => model ground elevation (m MSL)
//   "f"  => fetch time (unix seconds)
//   "ss" => Array of daily sunset times (unix seconds), may be null in old caches
//   "lv" => Array of levels, highest first: { "h" => heights[], "s" => speeds[], "d" => dirs[], "g" => gusts[] }
//           surface level has no "h"
// Highest first, so rows are drawn top-down like a sounding
const PRESSURE_LEVELS = ["700hPa", "800hPa", "850hPa", "925hPa"] as Array<String>;

class WindData {
    private var _d as Dictionary;

    function initialize(d as Dictionary) {
        _d = d;
    }

    static function hourlyFields() as String {
        var fields = "wind_speed_10m,wind_direction_10m,wind_gusts_10m";
        for (var i = 0; i < PRESSURE_LEVELS.size(); i++) {
            var p = PRESSURE_LEVELS[i];
            fields += ",wind_speed_" + p + ",wind_direction_" + p + ",geopotential_height_" + p;
        }
        return fields;
    }

    static function fromJson(json as Dictionary, now as Number) as WindData? {
        var hourly = json["hourly"];
        if (!(hourly instanceof Dictionary) || !(hourly["time"] instanceof Array)) {
            return null;
        }
        var levels = [];
        for (var i = 0; i < PRESSURE_LEVELS.size(); i++) {
            var p = PRESSURE_LEVELS[i];
            levels.add({
                "h" => hourly["geopotential_height_" + p],
                "s" => hourly["wind_speed_" + p],
                "d" => hourly["wind_direction_" + p]
            });
        }
        levels.add({
            "s" => hourly["wind_speed_10m"],
            "d" => hourly["wind_direction_10m"],
            "g" => hourly["wind_gusts_10m"]
        });
        var daily = json["daily"];
        return new WindData({
            "t" => hourly["time"],
            "e" => json["elevation"],
            "f" => now,
            "ss" => daily instanceof Dictionary ? daily["sunset"] : null,
            "lv" => levels
        });
    }

    function toDict() as Dictionary {
        return _d;
    }

    function fetchedAt() as Number {
        return _d["f"] as Number;
    }

    // Index of the hour that contains `now`; stale cache entries are skipped
    function firstIndex(now as Number) as Number {
        var times = _d["t"] as Array;
        for (var i = 0; i < times.size(); i++) {
            if ((times[i] as Number) + 3600 > now) {
                return i;
            }
        }
        return times.size();
    }

    function size() as Number {
        return (_d["t"] as Array).size();
    }

    // Next sunset after `now` (unix seconds), or null if unknown
    function nextSunset(now as Number) as Number? {
        var sunsets = _d["ss"];
        if (!(sunsets instanceof Array)) {
            return null;
        }
        for (var i = 0; i < sunsets.size(); i++) {
            var s = sunsets[i];
            if (s instanceof Number && s > now) {
                return s;
            }
        }
        return null;
    }

    // Number of hours from `base` that start before `until`
    function hoursBefore(base as Number, until as Number) as Number {
        var times = _d["t"] as Array;
        var count = 0;
        for (var i = base; i < times.size() && (times[i] as Number) < until; i++) {
            count++;
        }
        return count;
    }

    function timeLabel(idx as Number) as String {
        return clockLabel((_d["t"] as Array)[idx] as Number);
    }

    static function clockLabel(t as Number) as String {
        var info = Gregorian.info(new Time.Moment(t), Time.FORMAT_SHORT);
        return (info.hour as Number).format("%02d") + ":" + (info.min as Number).format("%02d");
    }

    // Pressure-level rows for hour `idx`, highest first: [label, speed m/s, direction deg (from)].
    // Levels that lie below the ground are skipped.
    function aloftAt(idx as Number) as Array<Array> {
        var rows = [] as Array<Array>;
        var elev = _d["e"];
        var levels = _d["lv"] as Array;
        for (var i = 0; i < levels.size(); i++) {
            var lv = levels[i] as Dictionary;
            if (lv["h"] == null) {
                continue;
            }
            var speed = valueAt(lv["s"], idx);
            var dir = valueAt(lv["d"], idx);
            var h = valueAt(lv["h"], idx);
            if (speed == null || dir == null || h == null || (elev != null && h < elev)) {
                continue;
            }
            rows.add([(((h + 5) / 10).toNumber() * 10).toString() + "м", speed, dir]);
        }
        return rows;
    }

    // Wind 10 m above ground for hour `idx`: [speed m/s, direction deg (from), gust m/s or null], or null
    function groundAt(idx as Number) as Array? {
        var levels = _d["lv"] as Array;
        for (var i = 0; i < levels.size(); i++) {
            var lv = levels[i] as Dictionary;
            if (lv["h"] != null) {
                continue;
            }
            var speed = valueAt(lv["s"], idx);
            var dir = valueAt(lv["d"], idx);
            if (speed == null || dir == null) {
                return null;
            }
            return [speed, dir, valueAt(lv["g"], idx)];
        }
        return null;
    }

    // Ground elevation of the forecast point, m MSL
    function elevation() as Numeric? {
        return _d["e"] as Numeric?;
    }

    private static function valueAt(arr, idx as Number) {
        if (!(arr instanceof Array) || idx >= arr.size()) {
            return null;
        }
        return arr[idx];
    }
}
