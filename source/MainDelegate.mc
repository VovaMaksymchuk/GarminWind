import Toybox.Lang;
import Toybox.WatchUi;

// UP/DOWN (and swipes) step through forecast hours, START/tap refetches
class MainDelegate extends WatchUi.BehaviorDelegate {
    private var _view as MainView;
    private var _service as WeatherService;

    function initialize(view as MainView, service as WeatherService) {
        BehaviorDelegate.initialize();
        _view = view;
        _service = service;
    }

    function onNextPage() as Boolean {
        _view.shiftHour(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.shiftHour(-1);
        return true;
    }

    function onSelect() as Boolean {
        _service.refresh(true);
        return true;
    }
}
