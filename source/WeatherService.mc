import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.Position;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

// Fetches the Open-Meteo forecast for the current position and keeps the
// last good result in memory and in Application.Storage.
class WeatherService {
    const URL = "https://api.open-meteo.com/v1/forecast";
    const REFRESH_SEC = 900;
    // Minimum gap between automatic attempts, so errors don't hammer the phone link
    const RETRY_SEC = 60;
    // Enough to reach sunset from early morning; the view cuts the list at sunset
    const FORECAST_HOURS = 18;
    const STORAGE_KEY = "wind";

    var data as WindData? = null;
    // Empty when the last fetch succeeded
    var status as String = "Пошук GPS";

    private var _lat as Double? = null;
    private var _lon as Double? = null;
    private var _busy as Boolean = false;
    private var _lastAttempt as Number = 0;
    // First fix after launch always refetches: we may be at a different site than the cache
    private var _firstFix as Boolean = true;

    function initialize() {
        var cached = Application.Storage.getValue(STORAGE_KEY);
        if (cached instanceof Dictionary) {
            data = new WindData(cached);
        }
    }

    function onPosition(info as Position.Info) as Void {
        if (takePosition(info)) {
            refresh(_firstFix);
        }
    }

    // Forecast grid is kilometres wide, so any valid coordinate will do, whatever
    // the reported accuracy (the simulator reports none after Set Position).
    private function takePosition(info as Position.Info) as Boolean {
        var loc = info.position;
        if (loc == null) {
            return false;
        }
        var deg = loc.toDegrees();
        var lat = deg[0].toDouble();
        var lon = deg[1].toDouble();
        // 180/180 is the "no position" placeholder
        if (lat.abs() > 90.0 || lon.abs() > 180.0 || (lat == 0.0d && lon == 0.0d)) {
            return false;
        }
        _lat = lat;
        _lon = lon;
        return true;
    }

    // force=false only fetches when the data is older than REFRESH_SEC
    function refresh(force as Boolean) as Void {
        if (_busy) {
            return;
        }
        if (_lat == null) {
            takePosition(Position.getInfo());
        }
        var lat = _lat;
        var lon = _lon;
        if (lat == null || lon == null) {
            status = "Пошук GPS";
            WatchUi.requestUpdate();
            return;
        }
        var now = Time.now().value();
        var cached = data;
        if (!force && (now - _lastAttempt < RETRY_SEC
                || (cached != null && now - cached.fetchedAt() < REFRESH_SEC))) {
            return;
        }
        _lastAttempt = now;
        _busy = true;
        _firstFix = false;
        status = "Завантаження";
        Communications.makeWebRequest(
            URL,
            {
                "latitude" => lat.format("%.3f"),
                "longitude" => lon.format("%.3f"),
                "hourly" => WindData.hourlyFields(),
                "wind_speed_unit" => "ms",
                "forecast_hours" => FORECAST_HOURS,
                "daily" => "sunset",
                "forecast_days" => 2,
                "timezone" => "auto",
                "timeformat" => "unixtime"
            },
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onResponse)
        );
        WatchUi.requestUpdate();
    }

    function onResponse(code as Number, body as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        _busy = false;
        System.println("Open-Meteo response: " + code);
        if (code == 200 && body instanceof Dictionary) {
            var parsed = WindData.fromJson(body, Time.now().value());
            if (parsed != null) {
                data = parsed;
                status = "";
                Application.Storage.setValue(STORAGE_KEY, parsed.toDict());
            } else {
                status = "Помилка даних";
            }
        } else {
            status = errorText(code);
        }
        WatchUi.requestUpdate();
    }

    private function errorText(code as Number) as String {
        if (code == Communications.BLE_CONNECTION_UNAVAILABLE) {
            return "Немає телефону";
        }
        if (code == Communications.NETWORK_REQUEST_TIMED_OUT) {
            return "Таймаут";
        }
        return "Помилка " + code;
    }
}
