import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

class MainView extends WatchUi.View {
    // Speed colour thresholds, m/s
    const SPEED_OK = 4.0;
    const SPEED_STRONG = 7.0;
    const COMPASS_POINTS = ["Пн", "ПнСх", "Сх", "ПдСх", "Пд", "ПдЗх", "Зх", "ПнЗх"] as Array<String>;

    private var _service as WeatherService;
    private var _timer as Timer.Timer?;
    // Selected hour offset from now: 0.._maxHour
    private var _hour as Number = 0;
    // Last hour before sunset, recomputed on every draw
    private var _maxHour as Number = 0;

    function initialize(service as WeatherService) {
        View.initialize();
        _service = service;
    }

    function onShow() as Void {
        // Redraw every second so arrows follow the compass
        var timer = new Timer.Timer();
        timer.start(method(:onTick), 1000, true);
        _timer = timer;
    }

    function onHide() as Void {
        var timer = _timer;
        if (timer != null) {
            timer.stop();
            _timer = null;
        }
    }

    function onTick() as Void {
        // Also covers the case where no location events arrive (e.g. simulator Set Position)
        _service.refresh(false);
        WatchUi.requestUpdate();
    }

    function shiftHour(delta as Number) as Void {
        _hour += delta;
        if (_hour < 0) {
            _hour = 0;
        } else if (_hour > _maxHour) {
            _hour = _maxHour;
        }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var heading = Heading.get();
        if (heading != null) {
            drawNorthMarker(dc, w, h, heading);
        }

        var data = _service.data;
        var now = Time.now().value();
        var base = 0;
        var available = 0;
        var sunset = null;
        if (data != null) {
            base = data.firstIndex(now);
            // Daylight hours only; after sunset the next sunset is tomorrow, so the whole forecast is available
            sunset = data.nextSunset(now);
            available = sunset != null ? data.hoursBefore(base, sunset) : data.size() - base;
        }
        if (data == null || available <= 0) {
            drawNoData(dc, w, h);
            return;
        }
        _maxHour = available - 1;
        if (_hour > _maxHour) {
            _hour = _maxHour;
        }
        var idx = base + _hour;

        // Header: selected hour
        var title = (_hour == 0 ? "ЗАРАЗ" : "+" + _hour + " год") + "  " + data.timeLabel(idx);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.10, Graphics.FONT_TINY, title, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var headingDeg = heading != null ? Math.toDegrees(heading) : 0.0;
        drawAloft(dc, w, h, data.aloftAt(idx), headingDeg);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(w * 0.2, h * 0.515, w * 0.8, h * 0.515);

        var ground = data.groundAt(idx);
        if (ground != null) {
            drawGround(dc, w, h, ground, data.elevation(), headingDeg);
        }

        drawHourDots(dc, cx, h * 0.85, available, w * 0.6);
        drawFooter(dc, cx, h * 0.925, data, sunset);
        if (heading == null) {
            // No compass: arrows are north-up, shown where the north marker would be
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.04, Graphics.FONT_XTINY, "Пн угорі", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // Upper half: compact rows "3220м ↗ 8.3 Сх", spread evenly over the block
    private function drawAloft(dc as Dc, w as Number, h as Number, rows as Array<Array>, headingDeg as Float) as Void {
        var n = rows.size();
        if (n == 0) {
            return;
        }
        var top = h * 0.19;
        var step = n > 1 ? (h * 0.28) / (n - 1) : 0;
        if (step > h * 0.095) {
            step = h * 0.095;
        }
        var y = top;
        for (var i = 0; i < n; i++) {
            var row = rows[i];
            var speed = (row[1] as Numeric).toFloat();
            var dir = (row[2] as Numeric).toFloat();

            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w * 0.42, y, Graphics.FONT_TINY, row[0] as String, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(w * 0.70, y, Graphics.FONT_XTINY, compassPoint(dir), Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            WindArrow.draw(dc, w * 0.49, y, h * 0.03, arrowAngle(dir, headingDeg));

            dc.setColor(speedColor(speed), Graphics.COLOR_TRANSPARENT);
            dc.drawText(w * 0.55, y, Graphics.FONT_TINY, speed.format("%.1f"), Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            y += step;
        }
    }

    // Lower half: wind at launch, big — arrow, speed, gusts, compass point
    private function drawGround(dc as Dc, w as Number, h as Number, ground as Array, elev as Numeric?, headingDeg as Float) as Void {
        var speed = (ground[0] as Numeric).toFloat();
        var dir = (ground[1] as Numeric).toFloat();
        var gust = ground[2];
        var arrowX = w * 0.27;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var label = elev != null ? "G " + elev.toNumber() + "м" : "G";
        dc.drawText(arrowX, h * 0.565, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        WindArrow.draw(dc, arrowX, h * 0.69, h * 0.085, arrowAngle(dir, headingDeg));

        var textX = w * 0.42;
        var speedText = speed.format("%.1f");
        dc.setColor(speedColor(speed), Graphics.COLOR_TRANSPARENT);
        dc.drawText(textX, h * 0.635, Graphics.FONT_NUMBER_MEDIUM, speedText, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var unitX = textX + dc.getTextWidthInPixels(speedText, Graphics.FONT_NUMBER_MEDIUM) + 4;
        dc.drawText(unitX, h * 0.65, Graphics.FONT_XTINY, "м/с", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        var y2 = h * 0.755;
        if (gust != null) {
            var g = (gust as Numeric).toFloat();
            dc.setColor(speedColor(g), Graphics.COLOR_TRANSPARENT);
            dc.drawText(textX, y2, Graphics.FONT_SMALL, "до " + g.format("%.1f"), Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w * 0.72, y2, Graphics.FONT_TINY, compassPoint(dir), Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Meteo direction is where the wind comes FROM; the arrow shows where it blows TO,
    // relative to where the watch faces
    private function arrowAngle(dir as Float, headingDeg as Float) as Float {
        return Math.toRadians(dir + 180.0 - headingDeg).toFloat();
    }

    // Compass point the wind comes FROM (meteo convention: "Пн" = northerly wind)
    private function compassPoint(deg as Float) as String {
        var i = ((deg + 22.5) / 45.0).toNumber() % 8;
        return COMPASS_POINTS[i < 0 ? i + 8 : i];
    }

    private function speedColor(speed as Float) as Number {
        if (speed <= SPEED_OK) {
            return Graphics.COLOR_GREEN;
        }
        if (speed <= SPEED_STRONG) {
            return Graphics.COLOR_YELLOW;
        }
        return Graphics.COLOR_RED;
    }

    // Red triangle on the bezel pointing to magnetic/GPS north
    private function drawNorthMarker(dc as Dc, w as Number, h as Number, heading as Float) as Void {
        var a = -heading;
        var r = w / 2 - 10;
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        WindArrow.draw(dc, w / 2 + r * Math.sin(a), h / 2 - r * Math.cos(a), 8, a);
    }

    // One dot per hour; dots shrink and pack closer when the day is long
    private function drawHourDots(dc as Dc, cx as Number, y as Float, count as Number, maxWidth as Float) as Void {
        var spacing = 14.0;
        if (count > 1 && maxWidth / (count - 1) < spacing) {
            spacing = maxWidth / (count - 1);
        }
        var r = spacing >= 10 ? 3 : 2;
        var x = cx - (count - 1) * spacing / 2.0;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < count; i++) {
            if (i == _hour) {
                dc.fillCircle(x, y, r + 1);
            } else {
                dc.drawCircle(x, y, r);
            }
            x += spacing;
        }
    }

    // Status of the last fetch (or age of the data when everything is fine) and sunset time
    private function drawFooter(dc as Dc, cx as Number, y as Float, data as WindData, sunset as Number?) as Void {
        var text = _service.status;
        if (text.equals("")) {
            var age = (Time.now().value() - data.fetchedAt()) / 60;
            text = age.toString() + " хв";
        }
        if (sunset != null) {
            text += "  захід " + WindData.clockLabel(sunset);
        }
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawNoData(dc as Dc, w as Number, h as Number) as Void {
        var status = _service.status;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2, Graphics.FONT_MEDIUM, status.equals("") ? "Немає даних" : status, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.65, Graphics.FONT_XTINY, "START - оновити", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
