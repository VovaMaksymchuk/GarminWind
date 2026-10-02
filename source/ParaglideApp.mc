import Toybox.Application;
import Toybox.Lang;
import Toybox.Position;
import Toybox.Sensor;
import Toybox.WatchUi;

class ParaglideApp extends Application.AppBase {
    private var _service as WeatherService?;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        var service = new WeatherService();
        _service = service;
        // Last known position gives a quick first fetch while GPS warms up
        service.onPosition(Position.getInfo());
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        // Keeps the compass running so Sensor.getInfo().heading stays current
        Sensor.enableSensorEvents(method(:onSensor));
    }

    function onStop(state as Dictionary?) as Void {
        Sensor.enableSensorEvents(null);
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
    }

    function onSensor(info as Sensor.Info) as Void {
        WatchUi.requestUpdate();
    }

    function onPosition(info as Position.Info) as Void {
        var service = _service;
        if (service != null) {
            service.onPosition(info);
        }
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var service = _service as WeatherService;
        var view = new MainView(service);
        return [view, new MainDelegate(view, service)];
    }
}
