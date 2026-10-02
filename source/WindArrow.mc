import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

module WindArrow {
    // Arrow outline pointing up (towards 12 o'clock), unit size
    const SHAPE = [[0.0, -1.0], [-0.6, 0.65], [0.0, 0.3], [0.6, 0.65]];

    // Filled arrow centred at (cx, cy), rotated clockwise by `angle` radians from up
    function draw(dc as Dc, cx as Numeric, cy as Numeric, size as Numeric, angle as Float) as Void {
        var c = Math.cos(angle);
        var s = Math.sin(angle);
        var pts = [] as Array<Point2D>;
        for (var i = 0; i < SHAPE.size(); i++) {
            var x = SHAPE[i][0] * size;
            var y = SHAPE[i][1] * size;
            pts.add([cx + x * c - y * s, cy + x * s + y * c]);
        }
        dc.fillPolygon(pts);
    }
}
