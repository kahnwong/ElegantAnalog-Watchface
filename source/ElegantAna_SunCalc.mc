/***************************************************
*
* SunCalc.mc from the SunCalc Garmin App by haraldh
* https://apps.garmin.com/en-US/apps/87b86650-a443-43ea-9dcb-29e4051a5722
* https://github.com/haraldh/SunCalc/blob/master/source/SunCalc.mc
*
* License: Lesser GPL (LGPL-2.1)
* https://github.com/haraldh/SunCalc?tab=LGPL-2.1-1-ov-file
*
*
****************************************************/
using Toybox.Math as Math;
using Toybox.Time as Time;
using Toybox.Time.Gregorian;
using Toybox.Position as Pos;
using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;

    enum {
        ASTRO_DAWN,
        NAUTIC_DAWN,
        DAWN,
        BLUE_HOUR_AM,
        SUNRISE,
        SUNRISE_END,
        GOLDEN_HOUR_AM,
        NOON,
        GOLDEN_HOUR_PM,
        SUNSET_START,
        SUNSET,
        BLUE_HOUR_PM,
        DUSK,
        NAUTIC_DUSK,
        ASTRO_DUSK,
        NUM_RESULTS
    }

class ElegantAna_SunCalc {

    var sunEvents = [
        ASTRO_DAWN,
        NAUTIC_DAWN,
        DAWN,
        BLUE_HOUR_AM,
        SUNRISE,
        SUNRISE_END,
        GOLDEN_HOUR_AM,
        NOON,
        GOLDEN_HOUR_PM,
        SUNSET_START,
        SUNSET,
        BLUE_HOUR_PM,
        DUSK,
        NAUTIC_DUSK,
        ASTRO_DUSK
    ];

    var sunEventNames = {
        ASTRO_DAWN => ["ASTRO_DAWN",  "Astronomical Dawn"],
        NAUTIC_DAWN => ["NAUTIC_DAWN",  "Nautical Dawn"],
        DAWN => ["DAWN",  "Civil Dawn"],
        BLUE_HOUR_AM => ["BLUE_HOUR_AM",  "Morning Blue Hour"],
        SUNRISE => ["SUNRISE",  "Sunrise"],
        SUNRISE_END => ["SUNRISE_END",  "End of Sunrise"],
        GOLDEN_HOUR_AM => ["GOLDEN_HOUR_AM",  "Morning Golden Hour"],
        NOON => ["NOON",  "Noon"],
        GOLDEN_HOUR_PM => ["GOLDEN_HOUR_PM",  "Evening Golden Hour"],
        SUNSET_START => ["SUNSET_START",  "Start of Sunset"],
        SUNSET => ["SUNSET",  "Sunset"],
        BLUE_HOUR_PM => ["BLUE_HOUR_PM",  "Evening Blue HOur"],
        DUSK => ["DUSK",  "Civil Dusk"],
        NAUTIC_DUSK => ["NAUTIC_DUSK",  "Nautical Dusk"],
        ASTRO_DUSK  => ["ASTRO_DUSK",  "Astronomical Dusk"],
    };

    hidden const PI   = Math.PI,
        RAD  = Math.PI / 180.0,
        PI2  = Math.PI * 2.0,
        DAYS = Time.Gregorian.SECONDS_PER_DAY,
        J1970 = 2440588,
        J2000 = 2451545,
        J0 = 0.0009;

    hidden const TIMES = [
        -18 * RAD,    // ASTRO_DAWN
        -12 * RAD,    // NAUTIC_DAWN
        -6 * RAD,     // DAWN
        -4 * RAD,     // BLUE_HOUR
        -0.833 * RAD, // SUNRISE
        -0.3 * RAD,   // SUNRISE_END
        6 * RAD,      // GOLDEN_HOUR_AM
        null,         // NOON
        6 * RAD,
        -0.3 * RAD,
        -0.833 * RAD,
        -4 * RAD,
        -6 * RAD,
        -12 * RAD,
        -18 * RAD
        ];

    var lastD, lastLng;
    var	n, ds, M, sinM, C, L, sin2L, dec, Jnoon;

    function initialize() {
        lastD = null;
        lastLng = null;
    }

    function fromJulian(j) {
        return new Time.Moment((j + 0.5 - J1970) * DAYS);
    }

    function round(a) {
        if (a > 0) {
            return (a + 0.5).toNumber().toFloat();
        } else {
            return (a - 0.5).toNumber().toFloat();
        }
    }

    // lat and lng in radians
    function calculate(moment, pos, what) {
        var lat = pos[0];
        var lng = pos[1];

        var d = moment.value().toDouble() / DAYS - 0.5 + J1970 - J2000;
        if (lastD != d || lastLng != lng) {
            n = round(d - J0 + lng / PI2);
//			ds = J0 - lng / PI2 + n;
            ds = J0 - lng / PI2 + n - 1.1574e-5 * 68;
            M = 6.240059967 + 0.0172019715 * ds;
            sinM = Math.sin(M);
            C = (1.9148 * sinM + 0.02 * Math.sin(2 * M) + 0.0003 * Math.sin(3 * M)) * RAD;
            L = M + C + 1.796593063 + PI;
            sin2L = Math.sin(2 * L);
            dec = Math.asin( 0.397783703 * Math.sin(L) );
            Jnoon = J2000 + ds + 0.0053 * sinM - 0.0069 * sin2L;
            lastD = d;
            lastLng = lng;
        }

        if (what == NOON) {
            return fromJulian(Jnoon);
        }

        var x = (Math.sin(TIMES[what]) - Math.sin(lat) * Math.sin(dec)) / (Math.cos(lat) * Math.cos(dec));

        if (x > 1.0 || x < -1.0) {
            return null;
        }

        var ds = J0 + (Math.acos(x) - lng) / PI2 + n - 1.1574e-5 * 68;

        var Jset = J2000 + ds + 0.0053 * sinM - 0.0069 * sin2L;
        if (what > NOON) {
            return fromJulian(Jset);
        }

        var Jrise = Jnoon - (Jset - Jnoon);

        return fromJulian(Jrise);
    }

    function momentToString(moment, is24Hour) {

        if (moment == null) {
            return "--:--";
        }

        var tinfo = Time.Gregorian.info(new Time.Moment(moment.value() + 30), Time.FORMAT_SHORT);
        var text;
        if (is24Hour) {
            text = tinfo.hour.format("%02d") + ":" + tinfo.min.format("%02d");
        } else {
            var hour = tinfo.hour % 12;
            if (hour == 0) {
                hour = 12;
            }
            text = hour.format("%02d") + ":" + tinfo.min.format("%02d");
            // wtf... get used to 24 hour format...
            if (tinfo.hour < 12 || tinfo.hour == 24) {
                text = text + " AM";
            } else {
                text = text + " PM";
            }
        }
        var today = Time.today();
        var days = ((moment.value() - today.value()) / Time.Gregorian.SECONDS_PER_DAY).toNumber();

        if (moment.value() > today.value() ) {
            if (days > 0) {
                text = text + " +" + days;
            }
        } else {
            days = days - 1;
            text = text + " " + days;
        }
        return text;
    }

    static function printMoment(moment) {
        var info = Time.Gregorian.info(moment, Time.FORMAT_SHORT);
        return info.day.format("%02d") + "." + info.month.format("%02d") + "." + info.year.toString()
            + " " + info.hour.format("%02d") + ":" + info.min.format("%02d") + ":" + info.sec.format("%02d");
    }

    (:test) static function testCalc(logger) {

        var testMatrix = [
            [ 1496310905, 48.1009616, 11.759784, NOON, 1496315468 ],
            [ 1496310905, 70.6632359, 23.681726, NOON, 1496312606 ],
            [ 1496310905, 70.6632359, 23.681726, SUNSET, null ],
            [ 1496310905, 70.6632359, 23.681726, SUNRISE, null ],
            [ 1496310905, 70.6632359, 23.681726, ASTRO_DAWN, null ],
            [ 1496310905, 70.6632359, 23.681726, NAUTIC_DAWN, null ],
            [ 1496310905, 70.6632359, 23.681726, DAWN, null ],
            [ 1483225200, 70.6632359, 23.681726, SUNRISE, null ],
            [ 1483225200, 70.6632359, 23.681726, NOON, 1483266532 ],
            [ 1483225200, 70.6632359, 23.681726, ASTRO_DAWN, 1483247635 ],
            [ 1483225200, 70.6632359, 23.681726, NAUTIC_DAWN, 1483252565 ],
            [ 1483225200, 70.6632359, 23.681726, DAWN, 1483259336 ]
            ];

        var sc = new SunCalc();
        var moment;

        for (var i = 0; i < testMatrix.size(); i++) {
            moment = sc.calculate(new Time.Moment(testMatrix[i][0]),
                                  new Pos.Location(
                                      { :latitude => testMatrix[i][1], :longitude => testMatrix[i][2], :format => :degrees }
                                      ).toRadians(),
                                  testMatrix[i][3]);

            if (   (moment == null  && testMatrix[i][4] != moment)
                   || (moment != null && moment.value().toLong() != testMatrix[i][4])) {
                var val;

                if (moment == null) {
                    val = "null";
                } else {
                    val = moment.value().toLong();
                }

                logger.debug("Expected " + testMatrix[i][4] + " but got: " + val);
                logger.debug(printMoment(moment));
                return false;
            }
        }

        return true;
    }
}

class ElegantAna_SunInfo {


var DISPLAY = [
    [ "Astr. Dawn", ASTRO_DAWN, :Astro, :AM, null],
    [ "Nautic Dawn", NAUTIC_DAWN, :Nautic, :AM, null],
    [ "Blue Hour", BLUE_HOUR_AM, :Blue, :AM, null],
    [ "Civil Dawn", DAWN, :Civil, :AM, null],
    [ "Sunrise", SUNRISE, :Sunrise, :AM, null],
    [ "Golden Hour", GOLDEN_HOUR_AM, :Golden, :AM, null],
    [ "Noon", NOON, :Noon, :AM, null],
    [ "Golden Hour", GOLDEN_HOUR_PM, :Golden, :PM, null],
    [ "Sunset", SUNSET, :Sunrise, :PM, null],
    [ "Civil Dusk", DUSK, :Civil, :PM, null],
    [ "Blue Hour", BLUE_HOUR_PM, :Blue, :PM, null],
    [ "Nautic Dusk", NAUTIC_DUSK, :Nautic, :PM, null],
    [ "Astr. Dusk", ASTRO_DUSK, :Astro, :PM, null],
    ];

    var sc;    
    var now;
    var lastLoc;
    //var is24HOur;


    function initialize() {
        sc = new ElegantAna_SunCalc();
        //now = Time.now();
        // for testing now = new Time.Moment(1483225200);
        lastLoc = null;
        //is24Hour = Sys.getDeviceSettings().is24Hour;
    }

    function setPositionAndTime () {

        var info = Pos.getInfo();
        //In case position info not available, we'll use either the previously obtained value OR the geog center of 48 US states as default.
        if (info == null || info.accuracy == Pos.QUALITY_NOT_AVAILABLE) {
           if (self.lastLoc == null) { 
                self.lastLoc = new Pos.Location(            
                    { :latitude => 39.833333, :longitude => -98.583333, :format => :degrees }
                    ).toRadians();
           }
        } else {

            var loc = info.position.toRadians();
            self.lastLoc = loc;
        }
        now = Time.now();
        /* For testing
           now = new Time.Moment(1483225200);
           self.lastLoc = new Pos.Location(
            { :latitude => 70.6632359, :longitude => 23.681726, :format => :degrees }
            ).toRadians();
        */
        System.println ("lastLoc: " + info.position.toDegrees() );
    }

    //gets all sunevent times for yesterday, today, tomorrow
    //which = array with #s of desired calculations
    //today =0, so startDay=-1, endDay=1 gets yest, today,tomor..
    function calcAllSunTimes(which, startDay, endDay) {

        var sunTimes= {};

        setPositionAndTime();
        //var currmom =new Time.Moment(now.value());// + day * Time.Gregorian.SECONDS_PER_DAY
        var nowval = now.value();

        var sc_size = sc.sunEvents.size();
        var count = 0;
        for (var day = startDay ; day <= endDay; day++) {
            for (var i = 0; i< sc.sunEvents.size(); i++) {
                //var what = DISPLAY[i][0];
                if (which.indexOf(i)==-1) {continue;}
                var mom =new Time.Moment(nowval + day * Time.Gregorian.SECONDS_PER_DAY);

                var event = sc.sunEvents[i];
                var sunTime = sc.calculate(mom, lastLoc, i);
                //System.println("SunCalc: "+ i + " " + event  + " " + sunTime);

                //var g1 = Gregorian.info(mom, Time.FORMAT_LONG);
                //var g2=Gregorian.info(sunTime, Time.FORMAT_LONG);

                //sunTimes[(day+1)*sc.sunEvents.size()  + i]=sunTime;
                //var idx = [day,i];
                sunTimes[count]=[day, event, sunTime.value()];
                //System.println(sunTimes[count]);
                count ++;
                //System.println(mom.value());
                //System.println(sunTimes);
                //System.println(g1.day + "  " + g1.hour + "  " +  g1.min + "  " +  g1.sec + "  " +  mom.value());
                //System.println(g2.day + "  " + g2.hour + "  " +  g2.min + "  " +  g2.sec + "  " +  sunTime.value() + " " + sc.sunEventNames[event][0] + " " + sc.sunEventNames[event][1]);
            }
        }
        var idx = [0, 1];
        //System.println("SunCalc2: "+ sunTimes);
        
        return sunTimes;

    }


    function getDayNightPosition(){
     
        var which = [  DAWN,            
                DUSK,
            ];   
        var times = calcAllSunTimes(which, -1, 1);
        System.println("SunCalc3: "+ times);

        var nowval = now.value();
        var pos = -1;

        for (var i=0; i<times.size(); i++) {
            if (nowval < times[i][2]) {
                pos = i;
                break;
            }
        }

        if (pos < 1) {return null;}

        var nd = "Night";
        if (times[pos][1] == 12) {nd = "Day";}

        var duration = times[pos][2] - times[pos-1] [2];
        var now_length = nowval - times[pos-1] [2];
        var percent = now_length/duration;

        System.println ("Current conditions: " + nd + " " + percent);

        return [nd, percent];
    }

    function getNextDawnDusk(){
     
        var which = [  DAWN,            
                DUSK,
            ];   
        var times = calcAllSunTimes(which, 0, 1);
        //System.println("SunCalc3: "+ times);

        var nowval = now.value();
        var pos = -1;

        for (var i=0; i<times.size(); i++) {
            if (nowval < times[i][2]) {
                pos = i;
                break;
            }
        }

        if (pos < 1) {return null;}

        var nd = "Dawn";
        if (times[pos][1] == 12) {nd = "Dusk";}

        System.println ("next event sec: " + times[pos][1] + " " + times[pos][2]);

        //var info = Time.Gregorian.info(times[pos][2], Time.FORMAT_SHORT);
        var ttime = new Time.Moment(times[pos][2]);
        var tinfo = Gregorian.info(ttime, Time.FORMAT_SHORT);
        var angle = (tinfo.hour * 60.0 + tinfo.min )/720.0 * Math.PI * 2.0;        
        System.println ("next event time: " + tinfo.day + " " + tinfo.hour + ":"+tinfo.min);
        System.println ("next event angle: " + angle + " " + Math.toDegrees(angle));

        return [nd, angle];
    }


        


    
}

