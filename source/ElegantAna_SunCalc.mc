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
using Toybox.Weather as Weather;
using Toybox.Activity as Activity;
import Toybox.Application.Storage;

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
  NUM_RESULTS,
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
    ASTRO_DUSK,
  ];
  /*
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
    */

  hidden const PI = Math.PI,
    RAD = Math.PI / 180.0,
    PI2 = Math.PI * 2.0,
    DAYS = Time.Gregorian.SECONDS_PER_DAY,
    J1970 = 2440588,
    J2000 = 2451545,
    J0 = 0.0009;

  public const TIMES = [
    -18 * RAD, // ASTRO_DAWN
    -12 * RAD, // NAUTIC_DAWN
    -6 * RAD, // DAWN
    -4 * RAD, // BLUE_HOUR
    -0.833 * RAD, // SUNRISE
    -0.3 * RAD, // SUNRISE_END
    6 * RAD, // GOLDEN_HOUR_AM
    null, // NOON
    6 * RAD,
    -0.3 * RAD,
    -0.833 * RAD,
    -4 * RAD,
    -6 * RAD,
    -12 * RAD,
    -18 * RAD,
  ];

  var lastD, lastLng;
  var n, ds, M, sinM, C, L, sin2L, dec, Jnoon;

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
      C =
        (1.9148 * sinM + 0.02 * Math.sin(2 * M) + 0.0003 * Math.sin(3 * M)) *
        RAD;
      L = M + C + 1.796593063 + PI;
      sin2L = Math.sin(2 * L);
      dec = Math.asin(0.397783703 * Math.sin(L));
      Jnoon = J2000 + ds + 0.0053 * sinM - 0.0069 * sin2L;
      lastD = d;
      lastLng = lng;
    }

    if (what == NOON) {
      return fromJulian(Jnoon);
    }

    var x =
      (Math.sin(TIMES[what]) - Math.sin(lat) * Math.sin(dec)) /
      (Math.cos(lat) * Math.cos(dec));

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

    var tinfo = Time.Gregorian.info(
      new Time.Moment(moment.value() + 30),
      Time.FORMAT_SHORT
    );
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
    var days = (
      (moment.value() - today.value()) /
      Time.Gregorian.SECONDS_PER_DAY
    ).toNumber();

    if (moment.value() > today.value()) {
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
    return (
      info.day.format("%02d") +
      "." +
      info.month.format("%02d") +
      "." +
      info.year.toString() +
      " " +
      info.hour.format("%02d") +
      ":" +
      info.min.format("%02d") +
      ":" +
      info.sec.format("%02d")
    );
  }
  /*
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
    */
}

class ElegantAna_SunInfo {
  /*
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
    */

  var sc;
  var now;
  var lastLoc;
  var lastCalcExpires_sec;
  var savedRet;
  //var is24HOur;

  function initialize() {
    sc = new ElegantAna_SunCalc();
    lastCalcExpires_sec = 0;
    savedRet = null;
    //now = Time.now();
    // for testing now = new Time.Moment(1483225200);
    lastLoc = null;
    //is24Hour = Sys.getDeviceSettings().is24Hour;
  }

  //Urggh.
  //Check if location was saved in past 5 days, us it.
  //If not, check Position, XXXXthen WeatherXXXX, the Activity for a good position, use it.
  //Otherwise, use geo center of continental U.S. as location

  function setPositionAndTime() {
    var curr_pos = null;
    now = Time.now();
    //System.println ("sc1");

    //From activity is the PREFERRED way for watch faces
    if (curr_pos == null) {
      var a_info = Activity.getActivityInfo();
      var a_pos = null;
      System.println(
        "sc1.2:Activity a_info==Null3? " + (a_info == null) + " " + a_info
      );

      if (
        a_info != null &&
        a_info has :currentLocation &&
        a_info.currentLocation != null
      ) {
        a_pos = a_info.currentLocation;
      }
      System.println(
        "sc1.2:Activity a_pos==Null3? " + (a_pos == null) + " " + a_pos
      );
      //System.println ("setPosition4");
      if (a_pos != null) {
        System.println(
          "Position: Got from Activity.getActivityInfo() currentLocation" +
            a_pos +
            " " +
            a_pos.toDegrees()
        );
        curr_pos = a_pos;
      }
    }

    if (curr_pos == null) {
      if (
        $.Options_Dict.hasKey("Location") &&
        $.Options_Dict["Location"] != null &&
        now.value() - $.Options_Dict["Location"][1] <
          0.5 * Time.Gregorian.SECONDS_PER_DAY
      ) {
        self.lastLoc = $.Options_Dict["Location"][0];
        //System.println ("sc0: Options_Dict " + ($.Options_Dict["Location"][0]) + " now: " + now.value() + " saved: " + $.Options_Dict["Location"][1] );
        //System.println ("lastLoc final saved: " + self.lastLoc + Math.toDegrees(self.lastLoc[0]) + "," + Math.toDegrees(self.lastLoc[1]));
        if (self.lastLoc != null) {
          return;
        }
      }
    }

    /* //Weather POS just gives a lot of trouble/errors
        if (curr_pos == null) {
            var wcc = Weather.getCurrentConditions();

            var w_pos = wcc.observationLocationPosition;

            System.println ("sc1.1: weather w_pos == Null2? " + (w_pos==null));
            if (w_pos != null ) {
                System.println ("sc1.1: winfo " + w_pos.toDegrees());
                curr_pos = w_pos;
            }

            temp = curr_pos.toDegrees()[0];
            if ( temp == 180 || temp == 0 ) {curr_pos = null;} //bad data
        }
        */

    //use old stored value if that's what we have
    if (curr_pos == null) {
      if (
        $.Options_Dict.hasKey("Location") &&
        $.Options_Dict["Location"] != null
      ) {
        self.lastLoc = $.Options_Dict["Location"][0];
        System.println(
          "sc01: Options_Dict " +
            $.Options_Dict["Location"][0] +
            " now: " +
            now.value() +
            " saved: " +
            $.Options_Dict["Location"][1]
        );
        System.println(
          "lastLoc saved but stale: " +
            self.lastLoc +
            Math.toDegrees(self.lastLoc[0]) +
            "," +
            Math.toDegrees(self.lastLoc[1])
        );
        if (self.lastLoc != null) {
          return;
        }
      }
    }

    //very last resort, try getting position directly.  This is not really
    //supposed to be allowed for watches, but it seems to work just fine?
    //This is just reading whatever value it will give us now, vs requesting GPS to turn on & get a new fix.
    if (curr_pos == null) {
      var pinfo = Position.getInfo();
      System.println("sc1: Null? " + (pinfo == null));
      if (pinfo != null) {
        System.println("sc1: pinfo " + pinfo.position.toDegrees());
      }

      //var curr_pos = null;
      if (pinfo.position != null) {
        curr_pos = pinfo.position;
      }

      var temp = curr_pos.toDegrees()[0];
      if ((temp - 180).abs() < 0.1 || temp.abs() < 0.1) {
        curr_pos = null;
      } //bad data
    }

    //System.println ("sc1a:");
    //In case position info not available, we'll use either the previously obtained value OR the geog center of 48 US states as default.
    //|| info.accuracy == Pos.QUALITY_NOT_AVAILABLE
    if (curr_pos == null) {
      if (self.lastLoc == null) {
        self.lastLoc = (
          new Pos.Location({
            :latitude => 39.833333,
            :longitude => -98.583333,
            :format => :degrees,
          })
        ).toRadians();
        System.println("sc1b: " + self.lastLoc);
      }
    } else {
      var loc = curr_pos.toRadians();
      self.lastLoc = loc;
      System.println("sc1c:" + curr_pos.toDegrees());
      //System.println ("sc1c");
    }

    //System.println ("sc2");

    $.Options_Dict["Location"] = [self.lastLoc, now.value()];
    Storage.setValue("Location", $.Options_Dict["Location"]);
    //System.println ("sc3");
    /* For testing
           now = new Time.Moment(1483225200);
           self.lastLoc = new Pos.Location(
            { :latitude => 70.6632359, :longitude => 23.681726, :format => :degrees }
            ).toRadians();
        */
    System.println(
      "lastLoc final saved: " +
        self.lastLoc +
        Math.toDegrees(self.lastLoc[0]) +
        "," +
        Math.toDegrees(self.lastLoc[1])
    );
  }

  //gets all sunevent times for yesterday, today, tomorrow
  //which = array with #s of desired calculations
  //today =0, so startDay=-1, endDay=1 gets yest, today,tomor..
  function calcAllSunTimes(which, startDay, endDay) {
    var sunTimes = {};

    setPositionAndTime();
    //var currmom =new Time.Moment(now.value());// + day * Time.Gregorian.SECONDS_PER_DAY
    var nowval = now.value();
    //System.println ("sc4");
    var sc_size = sc.sunEvents.size();
    var count = 0;
    for (var day = startDay; day <= endDay; day++) {
      for (var i = 0; i < sc.sunEvents.size(); i++) {
        //var what = DISPLAY[i][0];
        if (which.indexOf(i) == -1) {
          continue;
        }
        var mom = new Time.Moment(
          nowval + day * Time.Gregorian.SECONDS_PER_DAY
        );

        var event = sc.sunEvents[i];
        var sunTime = sc.calculate(mom, lastLoc, i);
        //System.println("SunCalc: "+ i + " " + event  + " " + sunTime);

        //var g1 = Gregorian.info(mom, Time.FORMAT_LONG);
        //var g2=Gregorian.info(sunTime, Time.FORMAT_LONG);

        //sunTimes[(day+1)*sc.sunEvents.size()  + i]=sunTime;
        //var idx = [day,i];
        sunTimes[count] = [day, event, sunTime.value()];
        //System.println(sunTimes[count]);
        count++;
        //System.println(mom.value());
        //System.println(sunTimes);
        //System.println(g1.day + "  " + g1.hour + "  " +  g1.min + "  " +  g1.sec + "  " +  mom.value());
        //System.println(g2.day + "  " + g2.hour + "  " +  g2.min + "  " +  g2.sec + "  " +  sunTime.value() + " " + sc.sunEventNames[event][0] + " " + sc.sunEventNames[event][1]);
      }

      //System.println ("sc5");
    }
    //var idx = [0, 1];
    //System.println("SunCalc2: "+ sunTimes);
    //System.println ("sc6");
    return sunTimes;
  }

  function getDayNightPosition() {
    var which = [DAWN, DUSK];
    var times = calcAllSunTimes(which, -1, 1);
    //System.println("SunCalc3: "+ times);

    var nowval = now.value();
    var pos = -1;

    for (var i = 0; i < times.size(); i++) {
      if (nowval < times[i][2]) {
        pos = i;
        break;
      }
    }

    if (pos < 1) {
      return null;
    }

    var nd = "Night";
    if (times[pos][1] == 12) {
      nd = "Day";
    }

    var duration = times[pos][2] - times[pos - 1][2];
    var now_length = nowval - times[pos - 1][2];
    var percent = now_length / duration;

    //System.println ("Current conditions: " + nd + " " + percent);

    return [nd, percent];
  }

  //which is an array of the items you want to check for. As in the enum above,
  //ASTRO_DAWN, NAUTIC_DAWN, DAWN, DUSK, SUNRISE, SUNSET, etc
  //returns array with string "Dawn" or "Dusk" to indicate morning/night and the
  //angle in radians where the event can be placed on a 12-hour clock.
  function getNextDawnDusk_calc(which) {
    //System.println ("sc7");
    //var which = [  DAWN,DUSK,];
    var times = calcAllSunTimes(which, 0, 1);
    //System.println("SunCalc3: "+ times);

    var nowval = now.value();
    var pos = -1;
    //System.println ("sc8");
    for (var i = 0; i < times.size(); i++) {
      if (nowval < times[i][2]) {
        pos = i;
        break;
      }
    }
    //System.println ("sc9");
    if (pos < 0) {
      return null;
    }

    var nd = "Dawn";
    if (times[pos][1] > 6) {
      nd = "Dusk";
    }

    //System.println ("next event sec: " + times[pos][1] + " " + times[pos][2]);

    //var info = Time.Gregorian.info(times[pos][2], Time.FORMAT_SHORT);
    /*
        var ttime = new Time.Moment(times[pos][2]);
        var tinfo = Gregorian.info(ttime, Time.FORMAT_SHORT);
        var angle = (tinfo.hour * 60.0 + tinfo.min )/720.0 * Math.PI * 2.0;
        System.println ("next event time: " + tinfo.day + " " + tinfo.hour + ":"+tinfo.min);
        System.println ("next event angle: " + angle + " " + Math.toDegrees(angle));
        */
    /*
        System.println ("sc10");
        var now_info = Gregorian.info(now, Time.FORMAT_SHORT);

        var mid_options = {
            :year   => now_info.year,
            :month  => now_info.month,
            :day    => now_info.day,
            :hour   => 0
            };
        var mid_date = Gregorian.moment(mid_options);
        */

    //System.println ("sc11");
    var mid_date = Time.today(); //midnight today.  Aarrgh.

    //System.println ("next event times: " + times[pos][2] + " " + mid_date.value().toDouble());

    //System.println ("next event times: " + (times[pos][2] - mid_date.value().toDouble())/Time.Gregorian.SECONDS_PER_DAY * 24.0);

    //System.println(which);

    var angle =
      ((times[pos][2] - mid_date.value().toDouble()) /
        (Time.Gregorian.SECONDS_PER_DAY / 2.0)) *
      Math.PI *
      2.0;
    var ret = [[nd, angle, times[pos][2]]];

    if (pos + 1 < times.size()) {
      pos++;

      nd = "Dawn";
      if (times[pos][1] > 6) {
        nd = "Dusk";
      }

      //System.println ("next event times: " + (times[pos][2] - (mid_date.value().toDouble()))/Time.Gregorian.SECONDS_PER_DAY * 24.0);

      angle =
        ((times[pos][2] - mid_date.value().toDouble()) /
          (Time.Gregorian.SECONDS_PER_DAY / 2.0)) *
        Math.PI *
        2.0;

      ret.add([nd, angle, times[pos][2]]);
    }

    return ret;
  }

  //Cache the last calculated dawn/dusk array until the next dawn/dusk
  //event, OR 2 hours, whichever is less
  function getNextDawnDusk(which) {
    now = Time.now();
    //deBug("GNDD", [now.value(), lastCalcExpires_sec, savedRet]);
    if (now.value() > lastCalcExpires_sec || savedRet == null) {
      var ret = getNextDawnDusk_calc(which);
      if (ret[0] != null && ret[0][2] != null) {
        savedRet = ret;
        lastCalcExpires_sec = ret[0][2];
        if (lastCalcExpires_sec - now.value() > 3600 * 2) {
          lastCalcExpires_sec = now.value() + 3600 * 2;
        }
      }
      //deBug("GNDD after return new", [now.value(), lastCalcExpires_sec, ret]);
      return ret;
    }

    //deBug("GNDD after return cached", [now.value(), lastCalcExpires_sec, savedRet]);

    return savedRet;
  }
}
