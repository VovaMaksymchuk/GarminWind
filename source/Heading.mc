import Toybox.Lang;
import Toybox.Position;
import Toybox.Sensor;

module Heading {
    // Above this ground speed the GPS track is steadier than the magnetic compass
    const GPS_MIN_SPEED = 3.0;

    // Direction the watch is facing / moving, radians clockwise from north,
    // or null when neither GPS track nor compass is available.
    function get() as Float? {
        var pos = Position.getInfo();
        if (pos.speed != null && pos.heading != null && pos.speed > GPS_MIN_SPEED) {
            return pos.heading;
        }
        var sensor = Sensor.getInfo();
        if (sensor.heading != null) {
            return sensor.heading;
        }
        return null;
    }
}
