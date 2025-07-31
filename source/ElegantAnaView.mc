//
// Copyright 2016-2021 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables
// Application Developer Agreement.
//

using Toybox.Complications;
using Toybox.Application;
using Toybox.System;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
using Toybox.Timer;
using Toybox.Graphics as Gfx;
using Toybox.Lang as Lang;
using Toybox.Math as Math;
using Toybox.Time.Gregorian as Calendar;
using Toybox.WatchUi as Ui;
using Toybox.Application as App;
import Toybox.Application.Storage;
import Toybox.ActivityMonitor;
using Toybox.System as Sys;
using Toybox.ActivityMonitor as Act;
using Toybox.Activity as Acty;

//! This implements an ElegantAna watch face
//! Original design by Austen Harbour
class ElegantAnaView extends WatchUi.WatchFace {
  private var _font as FontResource?;
  private var _isAwake as Boolean?;
  private var _screenShape as ScreenShape;
  private var _dndIcon as BitmapResource?;
  private var _offscreenBuffer as BufferedBitmap?;
  private var _hashMarksBuffer as BufferedBitmap?;
  private var _screenCenterPoint as Array<Number>?;
  private var _fullScreenRefresh as Boolean;
  private var _hashMarksDrawn as Boolean;
  private var _partialUpdatesAllowed as Boolean;
  public var _secondHandCounter as Number;

  //var showSecond = true;
  var background_color = Gfx.COLOR_BLACK;
  var sec_color = Gfx.COLOR_WHITE;
  var width_screen, height_screen, min_screen, max_screen;
  var sec_length, sec_width, sec_base, sec_type;
  var centerY_seconds,
    centerX_seconds,
    centerX_main,
    centerY_main,
    centerX_circle,
    centerY_circle,
    radius_circle;

  var hashMarksArray = new [24];

  var dateFont;
  var timeFont;
  var dateTextHeight;
  var timeTextHeight;

  var batt_width_rect = 12;
  var batt_height_rect = 6;
  var batt_width_rect_small = 2;
  var batt_height_rect_small = 4;
  var batt_x, batt_y, batt_x_small, batt_y_small;

  var dmd_w4;
  var dmd_yy, dmd_x;
  var dmd_w;
  var dmd_h;

  var activities_background_color = Graphics.COLOR_BLACK;
  // #ff3333
  //var lowBatteryColor = Graphics.COLOR_RED;
  var lowBatteryColor = 0xff3333;
  var activities_primaryColor;
  var activities_gap = 1;

  var stepGoal;
  var steps;
  var activeMinutesWeek, activeMinutesDay;
  var activeMinutesWeekGoal, activeMinutesDayGoal;
  var moveBarLevel, moveExpired;
  var info, si;
  var hasSubscreen = true;

  //! Initialize variables for this view
  public function initialize() {
    //System.println("5B");
    WatchFace.initialize();
    //var settings = Sys.getDeviceSettings();
    _screenShape = System.getDeviceSettings().screenShape;
    _fullScreenRefresh = true;
    _hashMarksDrawn = false;
    _partialUpdatesAllowed = WatchUi.WatchFace has :onPartialUpdate;
    _secondHandCounter = 0;
    _isAwake = true;
    si = new ElegantAna_SunInfo();
    readStorageValues();
    //System.println("5B");
  }

  //! Handle view being hidden
  public function onHide() as Void {}

  //! Restore the state of the app and prepare the view to be shown
  public function onShow() as Void {
    //we have been somewhere else, need to clean house...
    update_ran = false;
    $.Settings_ran = true;
    System.println("onShow");
  }

  //! Configure the layout of the watchface for this device
  //! @param dc Device context
  public function onLayout(dc as Dc) as Void {
    //System.println("1");
    // Load the custom font we use for drawing the 3, 6, 9, and 12 on the watchface.
    //_font = WatchUi.loadResource($.Rez.Fonts.id_font_black_diamond) as FontResource;

    // If this device supports the Do Not Disturb feature,
    // load the associated Icon into memory.
    /*
        if (System.getDeviceSettings() has :doNotDisturb) {
            _dndIcon = WatchUi.loadResource($.Rez.Drawables.DoNotDisturbIcon) as BitmapResource;
        } else {
            _dndIcon = null;
        }
        */

    var offscreenBufferOptions = {
      :width => dc.getWidth(),
      :height => dc.getHeight(),
      /*:palette=> [
                    //Graphics.COLOR_DK_GRAY,
                    //Graphics.COLOR_LT_GRAY,
                    Graphics.COLOR_BLACK,
                    Graphics.COLOR_WHITE
                ] */
    };
    //System.println("2");
    var hashMarksBufferOptions = {
      :width => dc.getWidth(),
      :height => dc.getHeight(),
      /*:palette=> [
                    //Graphics.COLOR_DK_GRAY,
                    //Graphics.COLOR_LT_GRAY,
                    Graphics.COLOR_BLACK,
                    Graphics.COLOR_WHITE
                ]*/
    };

    if (Graphics has :createBufferedBitmap) {
      // get() used to return resource as Graphics.BufferedBitmap
      _offscreenBuffer =
        Graphics.createBufferedBitmap(offscreenBufferOptions).get() as
        BufferedBitmap;

      _hashMarksBuffer =
        Graphics.createBufferedBitmap(hashMarksBufferOptions).get() as
        BufferedBitmap;
    } else if (Graphics has :BufferedBitmap) {
      // If this device supports BufferedBitmap, allocate the buffers we use for drawing
      // Allocate a full screen size buffer with a palette of only 4 colors to draw
      // the background image of the watchface.  This is used to facilitate blanking
      // the second hand during partial updates of the display
      _offscreenBuffer = new Graphics.BufferedBitmap(offscreenBufferOptions);

      // Allocate a buffer tall enough to draw the date into the full width of the
      // screen. This buffer is also used for blanking the second hand. This full
      // color buffer is needed because anti-aliased fonts cannot be drawn into
      // a buffer with a reduced color palette
      _hashMarksBuffer = new Graphics.BufferedBitmap(hashMarksBufferOptions);
    } else {
      _offscreenBuffer = null;
      _hashMarksBuffer = null;
    }
    //System.println("3");

    _screenCenterPoint = [dc.getWidth() / 2, dc.getHeight() / 2];
    //get screen dimensions
    width_screen = dc.getWidth();
    if (width_screen < 166) {
      width_screen -= 8;
    } //Instinct S adjustment bec. the right edge of the bezel ends a bit before the actual right screen edge
    height_screen = dc.getHeight();
    min_screen = width_screen < height_screen ? width_screen : height_screen;
    max_screen = width_screen < height_screen ? height_screen : width_screen;
    var hm_factor = -1.08;
    if (width_screen < 166) {
      hm_factor = -1.1;
    } //Instinct S adjustment

    if (width_screen > 176) {
      hm_factor = -0.95;
    } //Instinct S adjustment

    //center of dial for second hand
    centerX_seconds = width_screen / 2;
    centerY_seconds = height_screen / 2;
    centerX_main = width_screen / 2;
    centerY_main = height_screen / 2;
    centerX_circle = 145.5; //??
    centerY_circle = 32; //??
    radius_circle = 32;

    if (WatchUi has :getSubscreen) {
      var ss = WatchUi.getSubscreen();
      //System.println("Has subScreen:" + ss.height + " " + ss.width + " " + ss.x + " " + ss.y);
      hasSubscreen = true;
      radius_circle = ss.height / 2 + 1;
      centerX_circle = ss.x + radius_circle + 0.5;
      centerY_circle = ss.y + radius_circle;
    } else {
      //System.println("NO subScreen:");
      hasSubscreen = false;
      radius_circle = height_screen / 8.0;

      centerX_circle = centerX_main + centerX_main / 2 + 1;
      centerY_circle = centerY_main - centerY_main / 2 + 1;

      //System.println("NO subScreen:" + centerX_circle + " " + centerY_circle + " " + radius_circle);
    }
    //below is hand-tuned so just leaving it be INSTINCT 2S*********
    if (width_screen < 166) {
      //Instinct 2S 163 x 156
      /*centerX_circle =  133; //???? 54x54 & 109 from left
            centerY_circle = 28; //??????
            radius_circle = 22; */

      centerX_circle = 135; //???? 54x54 & 109 from left per docs
      centerY_circle = 27; //?????? 54x54 & x=108, y = 0 per call to getSubscreen()
      radius_circle = 26; //just give it one pixel...
    }

    //TEST
    //centerX_seconds = centerX_circle;
    //centerY_seconds = centerY_circle;

    //get hash marks position
    for (var i = 0; i < 12; i += 1) {
      hashMarksArray[i] = new [2];
      //if(i != 0 && i != 6 && i != 12 && i != 18)
      {
        hashMarksArray[i][0] = (i / 12.0) * Math.PI * 2;
        hashMarksArray[i][1] = (hm_factor * min_screen) / 2;
      }
    }

    /*

        //get battery icon position
        batt_x = (width_screen/2) - (batt_width_rect/2) - (batt_width_rect_small/2);
        batt_y = (height_screen* .74) - (batt_height_rect/2);
        batt_x_small = batt_x + batt_width_rect;
        batt_y_small = batt_y + ((batt_height_rect - batt_height_rect_small) / 2);

        //Figure Move Dot positions
        dmd_w4 =Math.ceil((batt_width_rect + batt_width_rect_small+3)/4);
        //dmd_yy = batt_y + 1.5 * batt_height_rect;
        dmd_yy = batt_y;
        dmd_w = Math.ceil((batt_width_rect + batt_width_rect_small+3)/4-1);
        dmd_h = batt_height_rect-3;
        dmd_x = centerX_main;

        //dmd_x = batt_x + (batt_width_rect + batt_width_rect_small - (4.5 * dmd_w4 -1))/2; //center the move dots under the battery.  If possible.
        */

    dateFont = Graphics.FONT_TINY;
    timeFont = Graphics.FONT_LARGE;
    dateTextHeight = dc.getFontHeight(dateFont);
    timeTextHeight = dc.getFontHeight(timeFont);

    //startAnimationTimer($.hz);

    batt_width_rect = Math.round(width_screen / 14.6).toNumber(); //12
    batt_height_rect = Math.round(height_screen / 29.2).toNumber(); //6;
    batt_width_rect_small = Math.round(batt_width_rect / 6.0).toNumber(); //2;
    batt_height_rect_small = Math.round(
      (batt_height_rect * 2) / 3.0
    ).toNumber(); //4;

    if ((batt_height_rect - batt_height_rect_small) % 2 != 0) {
      batt_height_rect_small++;
    }

    //get battery icon position
    batt_x =
      width_screen / 2.0 - batt_width_rect / 2.0 - batt_width_rect_small / 2.0;
    //batt_y = (screenHeight* .63) - (batt_height_rect/2);
    batt_y = Math.round(centerY_main + dateTextHeight + 2);
    batt_x_small = batt_x + batt_width_rect;
    batt_y_small = Math.floor(
      batt_y + (batt_height_rect - batt_height_rect_small) / 2.0
    );
    batt_x = Math.round(batt_x);

    //Figure Move Dot positions
    dmd_w4 = Math.ceil(
      (batt_width_rect + batt_width_rect_small + 3) / 4
    ).toNumber();
    //dmd_yy = batt_y + 1.5 * batt_height_rect;
    dmd_yy = Math.round(batt_y);
    dmd_w = Math.ceil(
      (batt_width_rect + batt_width_rect_small + 3) / 4.0 - 1
    ).toNumber();
    dmd_h = Math.round(batt_height_rect - 3).toNumber();
    dmd_x = centerX_main;

    //always make it a square of the larger size
    if (dmd_w % 2 == 0) {
      dmd_w++;
    } //makes the plus signs nicer if it's even
    if (dmd_h % 2 == 0) {
      dmd_h++;
    }
    dmd_w = dmd_w > dmd_h ? dmd_w : dmd_h;
    dmd_h = dmd_w;

    activities_gap = 1;
    if (centerY_main > 119) {
      activities_gap = 2;
    } //for whatever reason a couple of graphics things need to be +2 instead of +1 for some high-res devices like FR 965

    activities_background_color = Graphics.COLOR_BLACK;
    //lowBatteryColor = Graphics.COLOR_YELLOW;
    // #ff4488
    //lowBatteryColor = Graphics.COLOR_YELLOW;
    lowBatteryColor = 0xff6666;
    activities_primaryColor = Graphics.COLOR_LT_GRAY;

    sec_length = width_screen * 0.43; //this will be change @ runtime per Storage.getValue(secondDisplay), see below.
    //sec_length = width_screen*.23;
    sec_width = 2;
    sec_base = -5;
    sec_type = 2;

    setLayout(Rez.Layouts.WatchFace(dc));

    //System.println("2C");

    // We always want to refresh the full screen when we get a regular onUpdate call.

    //sec_length = $.Options_Dict["Long Second"] ? width_screen*.475 : width_screen*.175;
    //TEST circle
    //sec_length = 25; //for small circle
  }

  private function setSecondHandOptions() {
    switch ($.Options_Dict[secondDisplay]) {
      case 1: {
        sec_length = width_screen * 0.175;
        centerX_seconds = centerX_main;
        centerY_seconds = centerY_main;
        break;
      }
      case 2: {
        //sec_length = centerY_circle-5;
        sec_length = radius_circle - 5;
        centerX_seconds = centerX_circle;
        centerY_seconds = centerY_circle;
        break;
      }
      default: {
        sec_length = width_screen * 0.475;
        if (width_screen > 176) {
          sec_length = width_screen * 0.45;
        }
        centerX_seconds = centerX_main;
        centerY_seconds = centerY_main;
        break;
      }
    }

    //sec_width = $.Options_Dict["Wide Second"] ? 2 : 1;
    var sho = $.Options_Dict[secondHandOption];
    //sec_type:
    //    0=regular filled rectangle
    //    1=thin line
    //      2=triangle/point
    //      3 = rectangle outline
    //      4 = blanked rectangle outline
    //      5 = triangle outline
    //      6 = blanked triangle outline

    //System.println("ODSD: " + $.Options_Dict[secondDisplay]  + " : "+ sho);
    switch (sho) {
      case 1: {
        //Outline Pointer
        sec_width = 5; //in pixels
        if ($.Options_Dict[secondDisplay] != 0) {
          sec_width = 8;
        } //fat little pointer for the small center hand
        sec_base = -5; //how far from base to start shape - positive=opposite side of center; negative = same side of center
        if ($.Options_Dict[secondDisplay] == 2) {
          sec_base = -7;
        } //center circle smaller in inset circle
        sec_type = 6; //0 = rectangle; 1=line; 2= triangle
        if ($.Options_Dict[secondDisplay] == 2) {
          sec_type = 5;
        }
        break;
      }
      case 2: {
        //Big Blunt
        sec_width = 5; //in pixels
        sec_base = -5; //how far from base to start shape - positive=opposite side of center; negative = same side of center
        if ($.Options_Dict[secondDisplay] == 2) {
          sec_base = -7;
        } //center circle smaller in inset circle
        sec_type = 0; //0 = rectangle; 1=line; 2= triangle
        break;
      }
      case 3: {
        //Outline Blunt
        sec_width = 6; //in pixels
        sec_base = -5; //how far from base to start shape - positive=opposite side of center; negative = same side of center
        if ($.Options_Dict[secondDisplay] == 2) {
          sec_base = -7;
        } //center circle smaller in inset circle
        sec_type = 4; //0 = rectangle; 1=line; 2= triangle
        if ($.Options_Dict[secondDisplay] == 2) {
          sec_type = 3;
        }
        break;
      }

      case 4: {
        //Big Needle
        sec_width = 1; //in pixels
        sec_base = -5; //how far from base to start shape - positive=opposite side of center; negative = same side of center
        if ($.Options_Dict[secondDisplay] == 2) {
          sec_base = -7;
        } //center circle smaller in inset circle
        sec_type = 1; //0 = rectangle; 1=line; 2= triangle, = outline, 4=blanked outline
        break;
      }
      case 5: {
        //Small Block
        sec_width = 10; //in pixels

        sec_base = 12 - sec_length; //how far from base to start shape - positive=opposite side of center; negative = same side of center

        if ($.Options_Dict[secondDisplay] != 0) {
          sec_width = 6;
          sec_base = 10 - sec_length;
        } //fat little pointer for the small center hand
        sec_type = 0; //0 = rectangle; 1=line; 2= triangle

        break;
      }
      case 6: {
        //Small Pointer
        sec_width = 10; //in pixels
        sec_base = 12 - sec_length; //how far from base to start shape - positive=opposite side of center; negative = same side of center
        sec_type = 2; //0 = rectangle; 1=line; 2= triangle

        break;
      }
      case 7: {
        //Small Needle
        sec_width = 1; //in pixels
        sec_base = 10 - sec_length; //how far from base to start shape - positive=opposite side of center; negative = same side of center
        sec_type = 1; //0 = rectangle; 1=line; 2= triangle

        break;
      }
      default: {
        //Big Pointer (Case 0)
        sec_width = 4; //in pixels
        if ($.Options_Dict[secondDisplay] != 0) {
          sec_width = 8;
        } //fat little pointer for the small center hand
        sec_base = -5; //how far from base to start shape - positive=opposite side of center; negative = same side of center
        if ($.Options_Dict[secondDisplay] == 2) {
          sec_base = -7;
        } //center circle smaller in inset circle
        sec_type = 2; //0 = rectangle; 1=line; 2= triangle
        break;
      }
    }
  }

  //! This function is used to generate the coordinates of the 4 corners of the polygon
  //! used to draw a watch hand. The coordinates are generated with specified length,
  //! tail length, and width and rotated around the center point at the provided angle.
  //! 0 degrees is at the 12 o'clock position, and increases in the clockwise direction.
  //! @param centerPoint The center of the clock
  //! @param angle Angle of the hand in radians
  //! @param handLength The length of the hand from the center to point
  //! @param tailLength The length of the tail of the hand
  //! @param width The width of the watch hand
  //! @return The coordinates of the watch hand
  private function generateHandCoordinates(
    centerPoint as Array<Number>,
    angle as Float,
    handLength as Number,
    tailLength as Number,
    width as Number
  ) as Array<[Numeric, Numeric]> {
    // Map out the coordinates of the watch hand
    var coords = [
      [-(width / 2), tailLength],
      [-(width / 2), -handLength],
      [width / 2, -handLength],
      [width / 2, tailLength],
    ];
    var result = new Array<[Numeric, Numeric]>[4];
    var cos = Math.cos(angle);
    var sin = Math.sin(angle);

    // Transform the coordinates
    for (var i = 0; i < 4; i++) {
      var x = coords[i][0] * cos - coords[i][1] * sin + 0.5;
      var y = coords[i][0] * sin + coords[i][1] * cos + 0.5;

      result[i] = [centerPoint[0] + x, centerPoint[1] + y];
    }

    return result;
  }

  /*
    //! Draws the clock tick marks around the outside edges of the screen.
    //! @param dc Device context
    private function drawHashMarksOld(dc as Dc) as Void {
        return;
        /*
        var width = dc.getWidth();
        var height = dc.getHeight();

        // Draw hashmarks differently depending on screen geometry.
        if (System.SCREEN_SHAPE_ROUND == _screenShape) {
            var outerRad = width / 2;
            var innerRad = outerRad - 10;
            // Loop through each 15 minute block and draw tick marks.
            for (var i = Math.PI / 6; i <= 11 * Math.PI / 6; i += (Math.PI / 3)) {
                // Partially unrolled loop to draw two tickmarks in 15 minute block.
                var sY = outerRad + innerRad * Math.sin(i);
                var eY = outerRad + outerRad * Math.sin(i);
                var sX = outerRad + innerRad * Math.cos(i);
                var eX = outerRad + outerRad * Math.cos(i);
                dc.drawLine(sX, sY, eX, eY);
                i += Math.PI / 6;
                sY = outerRad + innerRad * Math.sin(i);
                eY = outerRad + outerRad * Math.sin(i);
                sX = outerRad + innerRad * Math.cos(i);
                eX = outerRad + outerRad * Math.cos(i);
                dc.drawLine(sX, sY, eX, eY);
            }
        } else {
            var coords = [0, width / 4, (3 * width) / 4, width];
            for (var i = 0; i < coords.size(); i++) {
                var dx = ((width / 2.0) - coords[i]) / (height / 2.0);
                var upperX = coords[i] + (dx * 10);
                // Draw the upper hash marks.
                dc.fillPolygon([[coords[i] - 1, 2],
                                [upperX - 1, 12],
                                [upperX + 1, 12],
                                [coords[i] + 1, 2]]);
                // Draw the lower hash marks.
                dc.fillPolygon([[coords[i] - 1, height - 2],
                                [upperX - 1, height - 12],
                                [upperX + 1, height - 12],
                                [coords[i] + 1, height - 2]]);
            }
        }
        */
  //}

  var _getActivityData_inited = false;

  private function getActivityData() {
    _getActivityData_inited = true;

    info = Toybox.ActivityMonitor.getInfo();

    //if ($.Options_Dict[showMove]) {

    stepGoal = info.stepGoal;
    steps = info.steps;
    if (stepGoal == null || stepGoal == 0) {
      stepGoal = 1500;
    }
    if (steps == null) {
      steps = 0;
    }
    if (steps instanceof Lang.String) {
      steps = steps.toFloat();
    }

    activeMinutesWeek = info.activeMinutesWeek.total;
    activeMinutesWeekGoal = info.activeMinutesWeekGoal;
    if (activeMinutesWeekGoal == null || activeMinutesWeekGoal == 0) {
      activeMinutesWeekGoal = 150;
    }
    if (activeMinutesWeek == null) {
      activeMinutesWeek = 0;
    }

    activeMinutesDay = info.activeMinutesDay.total;
    activeMinutesDayGoal = activeMinutesWeekGoal / 7.0;
    if (activeMinutesDay == null) {
      activeMinutesDay = 0;
    }
  }

  //var testMBL = 0; //for testing

  var update_ran = false;
  var dawnDusk_ran = false;
  var dawnDusk_info = null;
  var dawnDusk_info24 = null;
  //! Handle the update event
  //! @param dc Device context
  public function onUpdate(dc as Dc) as Void {
    var clockTime = System.getClockTime();
    var targetDc = null;
    var avoidCircle;

    //var inf_sec = ($.Options_Dict["Infinite Second"] == $.infiniteSecondOptions_size-1);
    var sec_on = $.Options_Dict[infiniteSecondOption] > 0;

    if (!sec_on) {
      _secondHandCounter = 10000000;
    } else if (_secondHandCounter >= 10000000) {
      //sec_on was off but has been turned on via the menu
      _secondHandCounter = 0;
    }

    //System.println ("oud1");

    show_sec = true;
    if (!_isAwake) {
      _secondHandCounter += 1;
    }
    if (
      (!_isAwake &&
        _secondHandCounter >
          $.infiniteSecondLengths[$.Options_Dict[infiniteSecondOption]]) ||
      $.Options_Dict[infiniteSecondOption] == 0
    ) {
      show_sec = false;
    }

    if ($.Settings_ran || !update_ran) {
      setSecondHandOptions();
      dawnDusk_ran = false;
    }

    if (!_isAwake && clockTime.sec < 1) {
      //System.println(clockTime.hour +":" + clockTime.min +" - current second hand counter = " + _secondHandCounter);
    }

    //when woken up we don't need to do draw anaything on the main screen;
    //only at the top of the minute as usual.  So, except for the top
    //of the minute, skip it all & just update seconds.
    //however, sometimes this leads to a dirty screen
    //(returning from a toast or some other app)
    //so we leave this as an option
    if (
      _isAwake &&
      update_ran &&
      !$.Settings_ran &&
      clockTime.sec > 0 &&
      !$.Options_Dict[aggressiveClear]
    ) {
      onPartialUpdate(dc);
      return;
    }
    update_ran = true;

    //System.println ("oud2");
    //Storage.getValue("Wide Second") = Storage.getValue("Wide Second") ? true : false;

    //System.println("oud2");

    _fullScreenRefresh = true;

    avoidCircle =
      $.Options_Dict[showDate] ||
      $.Options_Dict[secondDisplay] == 2 ||
      $.Options_Dict[dawnDuskMarkers] == 2 ||
      $.Options_Dict[dawnDuskMarkers] == 3
        ? true
        : false;

    var squeeze = true;
    if (width_screen > 176) {
      squeeze = false;
    }

    dc.clearClip();
    if (!_hashMarksDrawn || $.Settings_ran) {
      $.Settings_ran = false; //reset all the hash marks whenever settings are changed
      //because some settings will change hashmarks
      //system.println("oud2a");
      if (null != _hashMarksBuffer) {
        // If we have an offscreen buffer that we are using to draw the background,
        // set the draw context of that buffer as our target.
        targetDc = _hashMarksBuffer.getDc();
        //dc.clearClip();
        _hashMarksDrawn = true;
      } else {
        targetDc = dc;
        _hashMarksDrawn = false;
      }

      //system.println("oud2a");

      //System.println(clockTime.hour +":" + clockTime.min + " - Drawing all hashmarks");

      //var width = targetDc.getWidth();
      //if (width < 176) { screen -=5; } //Instinct S adjustment
      //var height = targetDc.getHeight();

      // Fill the entire background with Black.
      targetDc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
      //targetDc.fillRectangle(0, 0, targetDc.getWidth(), targetDc.getHeight());
      targetDc.clear();
      targetDc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
      // Draw a grey triangle over the upper right half of the screen.
      //targetDc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_DK_GRAY);
      //targetDc.fillPolygon([[0, 0],
      //                      [targetDc.getWidth(), 0],
      //                      [targetDc.getWidth(), targetDc.getHeight()],
      //                      [0, 0]]);

      // Draw the tick marks around the edges of the screen
      //drawHashMarks(targetDc);
      //targetDc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
      //drawHashMarks(targetDc);

      // Draw the do-not-disturb icon if we support it and the setting is enabled
      //if (System.getDeviceSettings().doNotDisturb && (null != _dndIcon)) {
      //    targetDc.drawBitmap(width * 0.75, height / 2 - 15, _dndIcon);
      //}

      /*
            // Use white to draw the hour and minute hands
            targetDc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

            if (_screenCenterPoint != null) {
                // Draw the hour hand. Convert it to minutes and compute the angle.
                var hourHandAngle = (((clockTime.hour % 12) * 60) + clockTime.min);
                hourHandAngle = hourHandAngle / (12 * 60.0);
                hourHandAngle = hourHandAngle * Math.PI * 2;
                targetDc.fillPolygon(generateHandCoordinates(_screenCenterPoint, hourHandAngle, dc.getHeight() / 6, 0, dc.getWidth() / 80));
            }

            if (_screenCenterPoint != null) {
                // Draw the minute hand.
                var minuteHandAngle = (clockTime.min / 60.0) * Math.PI * 2;
                targetDc.fillPolygon(generateHandCoordinates(_screenCenterPoint, minuteHandAngle, dc.getHeight() / 3, 0, dc.getWidth() / 120));
            }



            // Draw the arbor in the center of the screen.
            targetDc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            targetDc.fillCircle(width / 2, height / 2, 7);
            targetDc.setColor(Graphics.COLOR_BLACK,Graphics.COLOR_BLACK);
            targetDc.drawCircle(width / 2, height / 2, 7);

            // Draw the 3, 6, 9, and 12 hour labels.
            var font = _font;
            if (font != null) {
                targetDc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_DK_GRAY);
                targetDc.drawText(width / 2, 2, font, "12", Graphics.TEXT_JUSTIFY_CENTER);
                targetDc.drawText(width - 2, (height / 2) - 15, font, "3", Graphics.TEXT_JUSTIFY_RIGHT);
                targetDc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
                targetDc.drawText(width / 2, height - 30, font, "6", Graphics.TEXT_JUSTIFY_CENTER);
                targetDc.drawText(2, (height / 2) - 15, font, "9", Graphics.TEXT_JUSTIFY_LEFT);
            }
            */

      //system.println("oud2c");

      targetDc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
      //System.println ("oud3");
      var drawHashes = true;
      var drawHours = true;


      //system.println("oud2d");

      if (
        ($.Options_Dict[secondHashes] && $.Options_Dict[secondDisplay] == 0) ||
        !$.Options_Dict[hourHashes]
      ) {
        drawHashes = false;
      } //Don't draw hour hashes if LONG SECOND HAND on MAIN DISPLAY & SECOND HASHES (they overlap) OR if they are just turned off.

      if (!$.Options_Dict[hourNumbers]) {
        drawHours = false;
      }

      //Small circle for center of inset circle, when seconds are there
      //System.println("SD: " + $.Options_Dict[secondDisplay])
      if ($.Options_Dict[secondDisplay] == 2) {
        targetDc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_WHITE);
        targetDc.fillCircle(centerX_circle, centerY_circle, 8);
        //targetDc.fillCircle(50, 70, 6);

        //targetDc.fillCircle(90, 20, 6);

        //targetDc.fillCircle(160, 15, 6);
      }

      drawHashMarks(targetDc, drawHashes, drawHours, avoidCircle, squeeze);
      //System.println ("oud4");

      //system.println("oud2e");

      if ($.Options_Dict[secondHashes]) {
        if (sec_length < width_screen / 3.0) {
          //[:dc=dc, :radius=radius, :includeOnes=include, length1, width1, includeFives, length5, width5, avoidCircle,squeezeX, squeezeY]
          //system.println("oud2ee");
          drawSecondHashMarks({
            :dc => targetDc,
            :radius => sec_length + 5,
            :includeOnes => true,
            :length1 => 2,
            :width1 => 1,
            :includeFives => true,
            :length5 => 5,
            :width5 => 2,
            :avoidCircle => false,
            :squeezeX => false,
            :squeezeY => false,
            :centerX => centerX_seconds,
            :centerY => centerY_seconds,
          });
        } else {
          var l = 100;
          var sub1 = 14;
          var sub2 = 10;
          var sub3 = 11;

          //system.println("oud2ef");
          if (width_screen < 166) {
            //Instinct 2S
            l = 85;
            sub1 = 14;
            sub2 = 7;
            sub3 = 11;
            //squeeze = true;
          } else if (width_screen > 176) {
            //larger watches/circular
            //l = centerX_secondsse+9;
            l = sec_length + 4;
            sub1 = 14;
            sub2 = 30;
            sub3 = sec_length / 20.0;
            //squeeze = false;
          }
          //var ac = $.Options_Dict[showDate] ? true : false;
          //drawSecondHashMarks(targetDc, l, true, l - sec_length - 15, 1, true, l-sec_length-12, 2, true, true, true);
          //system.println("oud2eg");
          drawSecondHashMarks({
            :dc => targetDc,
            :radius => l,
            :includeOnes => true,
            :length1 => l - sec_length - sub1,
            :width1 => 2,
            :includeFives => true,
            :length5 => l - sec_length - sub2,
            :length36912 => l - sec_length - sub2 + sub3,

            :width5 => 6,
            :avoidCircle => avoidCircle,
            :squeezeX => squeeze,
            :squeezeY => squeeze,
            :centerX => centerX_seconds,
            :centerY => centerY_seconds,
          });
          //system.println("oud2eg2");
        }
        //drawSecondHashMarks(dc, radius, includeOnes, length1, width1, includeFives, length5, width5)
      }
      //system.println("oud2f");
    }
    //system.println("oud3");

    if (null != _offscreenBuffer) {
      // If we have an offscreen buffer that we are using to draw the background,
      // set the draw context of that buffer as our target.
      targetDc = _offscreenBuffer.getDc();
    } else {
      //dc.clearClip();
      targetDc = dc;
    }

    if (null != _hashMarksBuffer) {
      targetDc.drawBitmap(0, 0, _hashMarksBuffer);
    }
    //system.println("oud4");

    //refreshed move,steps,activity mins every 2 mod 6 mins
    if (!_getActivityData_inited || clockTime.sec == 0) {
      getActivityData();
    }
    //Get the move info every minute...
    moveBarLevel = info.moveBarLevel;
    if (moveBarLevel == null) {
      moveBarLevel = 0;
    }
    moveExpired = moveBarLevel != null && moveBarLevel >= 5;
    //System.println ("oud5");

    //if (!(activeMinutesWeek instanceof Lang.Float) ) { activeMinutesWeek =
    //activeMinutesWeek.toFloat();}
    //if (!(activeMinutesWeekGoal instanceof Lang.Float )) { activeMinutesWeekGoal = activeMinutesWeekGoal.toFloat();}

    //System.println("Goals: " + steps.toString() + " " + stepGoal.toString()  + " " + activeMinutesWeek.toString() + " " + activeMinutesWeekGoal.toString()  + " " + moveBarLevel +  " " + moveExpired);

    //FOR TESTING
    /*
            testMBL += 1;
            if (testMBL > 5) {testMBL=0;}
            moveExpired  = false;
            if (testMBL>=5) { moveExpired = true; }
            moveBarLevel = testMBL;
            */
    //FOR TESTING

    //system.println("oud5");
    //moveExpired = true; //for testing
    if ($.Options_Dict[showMove] && moveExpired) {
      var stats = System.getSystemStats();
      var battery = stats.battery;
      var batteryInDays = 100;
      if (stats has :batteryInDays && stats.batteryInDays != null) {
        batteryInDays = stats.batteryInDays;
      }
      //deBug("batmove", [battery, batteryInDays]);
      var index = 0;
      if (
        $.Options_Dict[showBattery] ||
        battery < 12.0 ||
        batteryInDays < 1.1
      ) {
        drawBattery(
          targetDc,
          Gfx.COLOR_WHITE,
          lowBatteryColor,
          Gfx.COLOR_WHITE
        );
        index += 2.6;
      }
      drawMove(targetDc, Gfx.COLOR_WHITE, index);
      //drawMoveDots(targetDc, info.moveBarLevel, Gfx.COLOR_WHITE);
      if (
        $.Options_Dict[showDate] &&
        $.Options_Dict[secondDisplay] != 2 &&
        $.Options_Dict[dawnDuskMarkers] != 2 &&
        $.Options_Dict[dawnDuskMarkers] != 3
      ) {
        drawDateInset(targetDc, Gfx.COLOR_WHITE, true);
      } else if ($.Options_Dict[showDate]) {
        drawDateMain(targetDc, Gfx.COLOR_WHITE, true);
      }
    } else {
      var index = 0;
      //drawMove(targetDc, Gfx.COLOR_WHITE);
      var stats = System.getSystemStats();
      var battery = stats.battery;
      var batteryInDays = 100;
      if (stats has :batteryInDays && stats.batteryInDays != null) {
        batteryInDays = stats.batteryInDays;
      }
      //deBug("bat", [battery, batteryInDays]);
      if (
        $.Options_Dict[showBattery] ||
        battery < 12.0 ||
        batteryInDays < 1.1
      ) {
        drawBattery(
          targetDc,
          Gfx.COLOR_WHITE,
          lowBatteryColor,
          Gfx.COLOR_WHITE
        );
        index += 1.75;
      }
      if ($.Options_Dict[showBodyBattery]) {
        // I'm too lazy to change the name, so here it stays
        drawBodyBattery(targetDc, Gfx.COLOR_WHITE);
        drawStress(targetDc, Gfx.COLOR_WHITE);
        drawHeartRate(targetDc, Gfx.COLOR_WHITE);
        drawNextEvent(targetDc, Gfx.COLOR_WHITE);
      }
      if ($.Options_Dict[showMinutes]) {
        drawMoveDots(
          targetDc,
          activeMinutesWeek,
          activeMinutesWeekGoal,
          index,
          Gfx.COLOR_WHITE
        );
        index += 1;
      }
      if ($.Options_Dict[showDayMinutes]) {
        drawMoveDots(
          targetDc,
          activeMinutesDay,
          activeMinutesDayGoal,
          index,
          Gfx.COLOR_WHITE
        );
        index += 1;
      }
      if ($.Options_Dict[showSteps]) {
        drawMoveDots(targetDc, steps, stepGoal, index, Gfx.COLOR_WHITE);
        index += 1;
      }
      if ($.Options_Dict[showMove]) {
        drawMoveDots(targetDc, moveBarLevel, 5, index, Gfx.COLOR_WHITE);
        index += 1;
      }

      if ($.Options_Dict[showDate]) {
        var rev = false;
        if ($.Options_Dict[showMove] && moveExpired) {
          rev = true;
        }

        //drawdate in inset circle
        if (
          $.Options_Dict[secondDisplay] != 2 &&
          $.Options_Dict[dawnDuskMarkers] != 2 &&
          $.Options_Dict[dawnDuskMarkers] != 3
        ) {
          drawDateInset(targetDc, Gfx.COLOR_WHITE, rev);
        } else {
          //inset circle is filled so put it on the main display

          drawDateMain(targetDc, Gfx.COLOR_WHITE, rev);
        }
      }
    }

    //System.println("SUBSCRE!");
    //DRAW THE FAKE INSET CIRCLE IF NEEDED
    //draw circle around inset area if
    //    - on device with no subscreen
    //    - sojmething is being drawn in the inset circle
    //    - that something doesn't include the second hashes
    if (
      !hasSubscreen &&
      avoidCircle &&
      !(
        $.Options_Dict[infiniteSecondOption] > 0 &&
        $.Options_Dict[secondDisplay] == 2 &&
        $.Options_Dict[secondHashes]
      ) &&
      !(
        $.Options_Dict[dawnDuskMarkers] == 2 ||
        $.Options_Dict[dawnDuskMarkers] == 3
      )
    ) {
      //System.println("SUBSCRE2222!");
      targetDc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
      targetDc.setPenWidth(6);
      targetDc.drawArc(
        centerX_circle,
        centerY_circle,
        radius_circle + 4,
        Gfx.ARC_CLOCKWISE,
        0,
        360
      );
      targetDc.setPenWidth(1);
    }

    //drawDate(targetDc, Gfx.COLOR_WHITE);
    drawHands(
      targetDc,
      clockTime.hour,
      clockTime.min,
      clockTime.sec,
      Gfx.COLOR_WHITE,
      Gfx.COLOR_WHITE,
      Gfx.COLOR_WHITE
    );

    targetDc.setPenWidth(1);
    targetDc.setClip(0, height_screen / 2 - 20, width_screen, 40);
    // Draw the inner circle (at center of the 3 hands)
    targetDc.setColor(Gfx.COLOR_WHITE, background_color);
    targetDc.fillCircle(width_screen / 2, height_screen / 2, 6);
    targetDc.setColor(background_color, background_color);
    targetDc.drawCircle(width_screen / 2, height_screen / 2, 6);

    //DAWN DUSK MARKERS
    //Draw this AFTER the hands so that if in the inset circle, will cover
    //up hands inside there to prevent interference.
    //System.println ("oud6");
    var ddm = $.Options_Dict[dawnDuskMarkers];
    if (ddm < 4) {
      //only run every 10 mins OR if it hasn't run before, settings run, etc
      //it's a rather expensive run...
      if (!dawnDusk_ran || clockTime.min % 10 == 0) {
        //System.println ("oud7");
        dawnDusk_ran = true;
        var which = [DAWN, DUSK];
        if (ddm == 1 || ddm == 3) {
          which = [SUNRISE, SUNSET];
        }
        // var res = si.getDayNightPosition();
        //System.println ("Current conditions: " + res);
        dawnDusk_info = si.getNextDawnDusk(which);
        //System.println ("getNextDawnDusk: " + dawnDusk_info + " "  + which );
        //drawArc(x, y, r, attr, degreeStart, degreeEnd)
      }

      //        var options = {:dc=>targetDc, :angle=>res[1],:length=>width_screen*.6 , :width=>10,:overheadLine=>-width_screen*.4, :drawCircleOnTop=>false, :shape=>5,:squeezeX=>true, :squeezeY=>true, :centerX=>centerX_main, :centerY=>centerY_main};

      //drawHand(options);

      if (dawnDusk_info != null) {
        //LITTLE MARKS ON THE MAIN CLOCK
        if (ddm < 2) {
          for (var i = 0; i < dawnDusk_info.size(); i++) {
            //System.println ("Current conditions: " + res);
            //System.println ("Current conditions: " + res[0]);
            //System.println ("Current conditions: " + res[0].equals("Dawn"));

            //System.println ("oud8");

            //drawHandplain (targetDc, res[1], width_screen*.47, 8, -width_screen * .5, 5);

            /*
                        //Little triangles - works pretty well, squashed when along bottom

                        for (var i = 0; i<dawnDusk_info.size(); i++) {
                        var sh = 5;
                        if (dawnDusk_info[i][0].equals("Dusk")) {sh = 2;}

                        var ohl = -width_screen*.53 ;
                        var ln =  width_screen*.49 ;
                        if (($.Options_Dict[secondHashes] && $.Options_Dict[secondDisplay] == 0) || $.Options_Dict[hourHashes] ) {
                            ohl = -width_screen*.5 ;
                            ln =  width_screen*.47 ;
                        }
                        //System.println ("oud9");
                        //System.println ("getNextDawnDusk2: " + dawnDusk_info);
                        //System.println ("getNextDawnDusk3: " + dawnDusk_info[1] + " " + ohl + " " + ln);

                        //System.println ("oud10");

                        var options = {:dc=>targetDc, :angle=>dawnDusk_info[i][1],:length=> ln, :width=>8,:overheadLine=>ohl, :drawCircleOnTop=>false, :shape=>sh,:squeezeX=>true, :squeezeY=>true, :centerX=>centerX_main, :centerY=>centerY_main};
                        drawHand(options);
                        */

            //Trying little circles

            var sh = 7; //filled circle
            if (dawnDusk_info[i][0].equals("Dusk")) {
              sh = 9;
            } //open circle
            //sh = 9;

            var radius = 2;

            var ln = width_screen * 0.48;
            if (
              ($.Options_Dict[secondHashes] &&
                $.Options_Dict[secondDisplay] == 0) ||
              $.Options_Dict[hourHashes]
            ) {
              ln = width_screen * 0.48;
            }
            if (width_screen > 176) {
              ln = width_screen * 0.43;
            }
            //System.println ("mainscreen dawn/dusk #" + i);
            //System.println ("getNextDawnDusk2: " + dawnDusk_info);
            //System.println ("getNextDawnDusk3: " + dawnDusk_info[1] + " " + ohl + " " + ln);
            //System.println ("getNextDawnDusk3: " + dawnDusk_info[i] + " " + ln);

            //System.println ("getNextDawnDusk3: " + mod(dawnDusk_info[i][1], Math.PI * 2.0) + " "  + Math.toDegrees(mod(dawnDusk_info[i][1], Math.PI * 2.0)) + " "  + Math.toDegrees(mod(dawnDusk_info[i][1], Math.PI * 2.0)/15.0) );

            //so this sends back a RADIANS ANGLE suitable to send straight to drawHand

            //var ang_rad_tonoon = mod(dawnDusk_info[i][1] * 2.0 + Math.PI, (Math.PI * 2));
            var ang_rad_clock = mod(dawnDusk_info[i][1], Math.PI * 2);

            //System.println ("ang_rad_noon " + i + " " + ang_rad_clock);

            var options = {
              :dc => targetDc,
              :angle => ang_rad_clock,
              :length => ln,
              :width => 8,
              :overheadLine => radius,
              :drawCircleOnTop => false,
              :shape => sh,
              :squeezeX => squeeze,
              :squeezeY => squeeze,
              :centerX => centerX_main,
              :centerY => centerY_main,
            };
            //System.println ("ang_rad_noon " + options);
            drawHand(options);

            /*
                        var in = {
                        :hour => 0
                        };
                        var date = Time.Gregorian.moment(in);
                        var out = Time.Gregorian.info(date, Time.FORMAT_SHORT);
                        System.println(">>>" + out.hour);
                        */
            //System.println ("oud11");
          }
        } else if (ddm < 4) {
          //dawnDusk_info24 = si.getNextDawnDusk(which,24);

          //so this sends back a RADIANS ANGLE suitable to send straight to drawHand
          //but since the small circle is a 24 hr SOLAR CLOCK that is a slight different sit.
          //conversions:

          var dawnAngle_rad = dawnDusk_info[0][1] / 2.0;
          var duskAngle_rad = dawnDusk_info[1][1] / 2.0;
          if (dawnDusk_info[0][0].equals("Dusk")) {
            dawnAngle_rad = dawnDusk_info[1][1] / 2.0;
            duskAngle_rad = dawnDusk_info[0][1] / 2.0;
          }
          dawnAngle_rad = mod(dawnAngle_rad, Math.PI * 2);
          duskAngle_rad = mod(duskAngle_rad, Math.PI * 2);

          var now = Time.now();
          var mid_date = Time.today();

          var currTimeAngle_rad =
            ((now.value().toDouble() - mid_date.value().toDouble()) /
              Time.Gregorian.SECONDS_PER_DAY) *
            Math.PI *
            2.0;

          //System.println ("getNextDawnDusk: " + dawnDusk_info);
          //System.println("getNextDawnDusk2: " + currTimeAngle_rad + " " + now.value() + " " + mid_date.value());

          drawDayNight_animation(
            targetDc,
            dawnAngle_rad,
            duskAngle_rad,
            currTimeAngle_rad,
            centerX_circle,
            centerY_circle,
            radius_circle * 0.8,
            radius_circle + 4
          );
        }
      }
    }

    //System.println ("oud12");

    // Output the offscreen buffers to the main display if required.
    drawBackground(dc);

    // Draw analog time

    // Draw the battery percentage directly to the main screen.
    //var dataString = (System.getSystemStats().battery + 0.5).toNumber().toString() + "%";
    //dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
    //dc.drawText(width / 2, 3 * height / 4, Graphics.FONT_TINY, dataString, Graphics.TEXT_JUSTIFY_CENTER);

    if (_partialUpdatesAllowed && sec_on) {
      // If this device supports partial updates and they are currently
      // allowed run the onPartialUpdate method to draw the second hand.
      onPartialUpdate(dc); //apparently this is a double call (the OS will do the partial update??!!?)
    } else if (_isAwake && sec_on) {
      // Otherwise, if we are out of sleep mode, draw the second hand
      // directly in the full update method.
      /*
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            var secondHand = (clockTime.sec / 60.0) * Math.PI * 2;

            if (_screenCenterPoint != null) {
                dc.fillPolygon(generateHandCoordinates(_screenCenterPoint, secondHand, dc.getHeight() / 4, 20, dc.getWidth() / 120));
            }
            */
      var secondHand = (clockTime.sec / 60.0) * Math.PI * 2;

      // Draw the seconds

      //sec = ( clock_sec / 60.0) *  Math.PI * 2;
      dc.setColor(sec_color, Gfx.COLOR_TRANSPARENT);
      //drawHand(dc, secondHand, sec_length, sec_width, -5, false, sec_width, false, false);
      drawHandplain(dc, secondHand, sec_length, sec_width, sec_base, sec_type);
      //drawHand(dc, secondHand, -15, sec_width, 7, false, true);
    }

    _fullScreenRefresh = false;
  }

  /*

    //! Draw the date string into the provided buffer at the specified location
    //! @param dc Device context
    //! @param x The x location of the text
    //! @param y The y location of the text
    private function drawDateString(dc as Dc, x as Number, y as Number, reverse as Boolean) as Void {
        var info = Gregorian.info(Time.now(), Time.FORMAT_LONG);
        var dateStr = Lang.format("$1$ $2$ $3$", [info.day_of_week, info.month, info.day]);

        //$.Options_Dict[secondDisplay]
        //$.Options_Dict[dawnDuskMarkers]
        if (reverse) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            if (width_screen >= 166)  {
                dc.drawCircle(144, 34, 34);
            } else {
                dc.drawCircle(130, 27, 27);  //Instinct S, smaller screen & weird. center of circle is about  128,26 & radius 26
            }
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y, Graphics.FONT_MEDIUM, dateStr, Graphics.TEXT_JUSTIFY_CENTER);
        } else {

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y, Graphics.FONT_MEDIUM, dateStr, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
    */

  //var sec_colorset = false;
  //var sec_set = false;
  var sec_counter = 0;
  var show_sec = true;

  //! Handle the partial update event
  //! @param dc Device context
  public function onPartialUpdate(dc as Dc) as Void {
    // If we're not doing a full screen refresh we need to re-draw the background
    // before drawing the updated second hand position. Note this will only re-draw
    // the background in the area specified by the previously computed clipping region.

    //system.println("3C1");
    if (!show_sec) {
      return;
    }

    //system.println("3C2");
    if (!_fullScreenRefresh) {
      drawBackground(dc);
    }
    // else {

    //System.println("Ref Clock sec: " + System.getClockTime().sec + " : " + _fullScreenRefresh);
    /*
        //Setting the color takes an amazing amt of CPU cycles. Therefore we set it once only
        //after the main update method has run & messed it up
        if (update_ran ) {
            dc.setColor(sec_color, Gfx.COLOR_TRANSPARENT);
            sec_counter = System.getClockTime().sec;
            //System.println("Clock sec: " + sec_counter);
        } else {
            sec_counter +=1;
            //System.println("Counter sec: " + sec_counter);
            sec_counter = sec_counter % 60;
            //System.println("Mod sec: " + sec_counter);
        }
        update_ran = false;
        */

    //system.println("3D");

    dc.setColor(sec_color, Gfx.COLOR_TRANSPARENT);
    sec_counter = System.getClockTime().sec;
    //if (sec_counter ==0 && !_fullScreenRefresh) {return;}

    if (_screenCenterPoint != null) {
      var secondHand = (sec_counter / 60.0) * Math.PI * 2;
      //drawHand(dc, secondHand, 105, 2, 15, true);
      //var secondHandPoints = generateHandCoordinates(_screenCenterPoint, secondHand,sec_length, 15, sec_width_clipbox);

      //So, it turns out it is FAR quicker to just blit the entire background in place & then
      //draw the second hand.  All this bound box calculation, getting the clip, etc, is quite slow.
      // Update the clipping rectangle to the new location of the second hand.
      //var curClip = getBoundingBox(secondHandPoints);
      //var bBoxWidth = curClip[1][0] - curClip[0][0] + 1;
      //var bBoxHeight = curClip[1][1] - curClip[0][1] + 1;
      //dc.setClip(curClip[0][0], curClip[0][1], bBoxWidth, bBoxHeight);

      // Draw the second hand to the screen.
      //dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
      //dc.fillPolygon(secondHandPoints);

      //drawHands(dc, clockTime.hour, clockTime.min, clockTime.sec, Gfx.COLOR_WHITE, Gfx.COLOR_WHITE, Gfx.COLOR_WHITE);

      // Draw the seconds

      //dc.setClip(47, 47, 128,128);
      //sec = ( clock_sec / 60.0) *  Math.PI * 2;
      /*
            switch (sec_counter) {
                case (sec_counter <= 15):
                {
                    dc.setClip(85,5,170,90);
                    break;
                }
                case (sec_counter > 15 && sec_counter <=30):
                {
                    dc.setClip(85, 85, 170,170);
                    break;
                }
                case (sec_counter > 30 && sec_counter <=45):
                {
                    dc.setClip(5, 86, 90,170);
                    break;
                }
                case (sec_counter <=45):
                {
                    dc.setClip(5, 5, 89,89);
                    break;
                }

            }
            */
      //System.println("sec: " + sec_counter);
      /*

             if (sec_length> 170) {
             if (sec_counter  == 0 )
                {
                    dc.setClip(85,5,170,90);

                }
            else if (sec_counter ==16 )
                {
                    dc.setClip(85, 85, 170,170);

                }
            else if (sec_counter ==31)
                {
                    dc.setClip(5, 84, 90,170);

                }
            else if (sec_counter ==46)
                {
                    dc.setClip(5, 5, 89,89);

                }
             } else {
                if (sec_counter  == 0 )
                    {
                        dc.setClip(85,35,90,40);

                    }
                else if (sec_counter ==16 )
                    {
                        dc.setClip(85, 85, 140,140);

                    }
                else if (sec_counter==31)
                    {
                        dc.setClip(45, 84, 90,140);

                    }
                else if (sec_counter ==46)
                    {
                        dc.setClip(45, 45, 89,89);

                    }


             }
             */

      //dc.setClip(47, 47, 128,128);

      //drawHand(dc, secondHand,sec_length, 1, 15, true);
      //drawHand(dc, secondHand, sec_length, sec_width, -5, false, sec_width,false, false);
      //drawHandplain(dc, secondHand, sec_length, 3 , 7 - sec_length, 0); //small triangles/squares ***** BEST NEW OPTION
      //drawHandplain(dc, secondHand, sec_length, 2 , 2 - sec_length, 0); //small squares * ALSO OK NEW OPTION
      //drawHandplain(dc, secondHand, sec_length, sec_width , -5, 0); //regular arrows ****** ORIGINAL

      //system.println("3F");

      drawHandplain(dc, secondHand, sec_length, sec_width, sec_base, sec_type);

      //function drawHandplain (dc, angle, length, width, overheadLine, shape)
      //drawHand(dc, angle, length, width, overheadLine, drawCircleOnTop, 2, squeezeX, squeezeY)

      //drawHand(dc, secondHand, -15, sec_width, 7, false);
      //dc.clearClip(); //not good, spikes display time...

      // Draw the inner circle
      //dc.setColor(Gfx.COLOR_WHITE, background_color);
      //dc.fillCircle(width_screen/2, height_screen/2, 6);
      //dc.setColor(background_color,background_color);
      //dc.drawCircle(width_screen/2, height_screen/2, 6);
    }
  }

  //! Compute a bounding box from the passed in points
  //! @param points Points to include in bounding box
  //! @return The bounding box points
  private function getBoundingBox(
    points as Array<[Numeric, Numeric]>
  ) as Array<[Numeric, Numeric]> {
    var min = [9999, 9999];
    var max = [0, 0];

    for (var i = 0; i < points.size(); ++i) {
      if (points[i][0] < min[0]) {
        min[0] = points[i][0];
      }

      if (points[i][1] < min[1]) {
        min[1] = points[i][1];
      }

      if (points[i][0] > max[0]) {
        max[0] = points[i][0];
      }

      if (points[i][1] > max[1]) {
        max[1] = points[i][1];
      }
    }
    min[0] -= 3;
    min[1] -= 3;
    max[0] += 3;
    max[1] += 3;

    return [min, max];
  }

  //! Draw the watch face background
  //! onUpdate uses this method to transfer newly rendered Buffered Bitmaps
  //! to the main display.
  //! onPartialUpdate uses this to blank the second hand from the previous
  //! second before outputting the new one.
  //! @param dc Device context
  private function drawBackground(dc as Dc) as Void {
    //var width = dc.getWidth();
    //var height = dc.getHeight();

    // If we have an offscreen buffer that has been written to
    // draw it to the screen.
    if (null != _offscreenBuffer) {
      dc.drawBitmap(0, 0, _offscreenBuffer);
    }
    /*
        // Draw the date
        if (null != _hashMarksBuffer) {
            // If the date is saved in a Buffered Bitmap, just copy it from there.
            dc.drawBitmap(dc.getWidth()*2/3, 0, _hashMarksBuffer);
        } else {
            // Otherwise, draw it from scratch.
            //drawDateString(dc, width / 2, height / 4);
            drawDate(dc, Gfx.COLOR_WHITE);
        }
        */
    //drawDate(dc, Gfx.COLOR_WHITE);
  }

  //! This method is called when the device re-enters sleep mode.
  //! Set the isAwake flag to let onUpdate know it should stop rendering the second hand.
  public function onEnterSleep() as Void {
    _isAwake = false;
    _secondHandCounter = 0;
    _getActivityData_inited = false; //we retrieve this data whenever the user looks @ the watch, or once per minute otherwise
    //system.println(":"+System.getClockTime().min.format("%02d") + " - Enter Sleep, second hand counter = " + _secondHandCounter);
  }

  //! This method is called when the device exits sleep mode.
  //! Set the isAwake flag to let onUpdate know it should render the second hand.
  public function onExitSleep() as Void {
    _isAwake = true;
    _secondHandCounter = 0; //lets the 2nd hand run for 2 mins *only* after going to sleep
    _getActivityData_inited = false; //we retrieve this data whenever the user looks @ the watch, or once per minute otherwise
    //system.println(":"+System.getClockTime().min.format("%02d") + " - Exit Sleep, second hand counter = " + _secondHandCounter);
  }

  /*

    //read stored settings & set default values if nothing stored
    public function readStorageValues() as Void {

        var temp = Storage.getValue(infiniteSecondOption);
        $.Options_Dict[infiniteSecondOption] = temp  != null ? temp : $.infiniteSecondOptions_default;
        if ($.Options_Dict[infiniteSecondOption]>$.infiniteSecondOptions_size-1) {$.Options_Dict[infiniteSecondOption] = $.infiniteSecondOptions_default;}
        if ($.Options_Dict[infiniteSecondOption]<0) {$.Options_Dict[infiniteSecondOption] = $.infiniteSecondOptions_default;}
        Storage.setValue(infiniteSecondOption,$.Options_Dict[infiniteSecondOption]);

        temp = Storage.getValue(secondDisplay);
        $.Options_Dict[secondDisplay] = temp  != null ? temp : $.secondDisplayOptions_default;
        if ($.Options_Dict[secondDisplay]>$.secondDisplayOptions_size-1) {$.Options_Dict[secondDisplay] = $.secondDisplayOptions_default;}
        if ($.Options_Dict[secondDisplay]<0) {$.Options_Dict[secondDisplay] = $.secondDisplayOptions_default;}
        Storage.setValue(secondDisplay,$.Options_Dict[secondDisplay]);

        temp = Storage.getValue(secondHandOption);
        $.Options_Dict[secondHandOption] = temp  != null ? temp : $.secondHandOptions_default;
        if ($.Options_Dict[secondHandOption]>$.secondHandOptions_size-1) {$.Options_Dict[secondHandOption] = $.secondHandOptions_default;}
        if ($.Options_Dict[secondHandOption]<0) {$.Options_Dict[secondHandOption] = $.secondHandOptions_default;}
        Storage.setValue(secondHandOption,$.Options_Dict[secondHandOption]);

        temp = Storage.getValue(dawnDuskMarkers);
        $.Options_Dict[dawnDuskMarkers] = temp  != null ? temp : $.dawnDuskOptions_default;
        if ($.Options_Dict[dawnDuskMarkers]>$.dawnDuskOptions_size-1) {$.Options_Dict[dawnDuskMarkers] = $.dawnDuskOptions_default;}
        if ($.Options_Dict[dawnDuskMarkers]<0) {$.Options_Dict[dawnDuskMarkers] = $.dawnDuskOptions_default;}
        Storage.setValue(dawnDuskMarkers,$.Options_Dict[dawnDuskMarkers]);

        temp = Storage.getValue(showBattery);
        $.Options_Dict[showBattery] = temp  != null ? temp : true;
        Storage.setValue(showBattery,$.Options_Dict[showBattery]);

        temp = Storage.getValue(showMinutes);
        $.Options_Dict[showMinutes] = temp  != null ? temp : true;
        Storage.setValue(showMinutes,$.Options_Dict[showMinutes]);

        temp = Storage.getValue(showDayMinutes);
        $.Options_Dict[showDayMinutes] = temp  != null ? temp : true;
        Storage.setValue(showDayMinutes,$.Options_Dict[showDayMinutes]);

        temp = Storage.getValue(showSteps);
        $.Options_Dict[showSteps] = temp  != null ? temp : true;
        Storage.setValue(showSteps,$.Options_Dict[showSteps]);

        temp = Storage.getValue(showMove);
        $.Options_Dict[showMove] = temp  != null ? temp : true;
        Storage.setValue(showMove,$.Options_Dict[showMove]);

        temp = Storage.getValue(showMonthDay);
        $.Options_Dict[showMonthDay] = temp  != null ? temp : true;
        Storage.setValue(showMonthDay,$.Options_Dict[showMonthDay]);

        temp = Storage.getValue(showDate);
        $.Options_Dict[showDate] = temp  != null ? temp : true;
        Storage.setValue(showDate,$.Options_Dict[showDate]);

        temp = Storage.getValue(hourNumbers);
        $.Options_Dict[hourNumbers] = temp  != null ? temp : false;
        Storage.setValue(hourNumbers,$.Options_Dict[hourNumbers]);

        temp = Storage.getValue(hourHashes);
        $.Options_Dict[hourHashes] = temp  != null ? temp : true;
        Storage.setValue(hourHashes,$.Options_Dict[hourHashes]);


        temp = Storage.getValue(secondHashes);
        $.Options_Dict[secondHashes] = temp  != null ? temp : false;
        Storage.setValue(secondHashes,$.Options_Dict[secondHashes]);

        temp = Storage.getValue(aggressiveClear);
        $.Options_Dict[aggressiveClear] = temp  != null ? temp : false;
        Storage.setValue(aggressiveClear,$.Options_Dict[aggressiveClear]);

        temp = Storage.getValue("Location");
        $.Options_Dict["Location"] = temp  != null ? temp : null;
        Storage.setValue("Location",$.Options_Dict["Location"]);

        //temp = Storage.getValue("Wide Second");
        //$.Options_Dict["Wide Second"] = temp  != null ? temp : false;
        //Storage.setValue("Wide Second",$.Options_Dict["Wide Second"]);
        */

  /*
        temp = Storage.getValue("Long Second");
        $.Options_Dict["Long Second"] = temp  != null ? temp : true;
        Storage.setValue("Long Second",$.Options_Dict["Long Second"]);

        temp = Storage.getValue("Infinite Second");
        $.Options_Dict["Infinite Second"] = temp  != null ? temp : true;
        Storage.setValue("Infinite Second",$.Options_Dict["Infinite Second"]);
        */

  //}

  //! Turn off partial updates
  public function resetSecondHandCounter() as Void {
    _secondHandCounter = 0;
  }

  //! Turn off partial updates
  public function turnPartialUpdatesOff() as Void {
    _partialUpdatesAllowed = false;
  }

  public function drawDayNight_animation(
    dc,
    dawnAngle_rad,
    duskAngle_rad,
    currTimeAngle_rad,
    centerX,
    centerY,
    radius,
    blankradius
  ) {
    //For ARC drawing purposes 0 deg is 3 o'clock & the circle proceeds around
    //counterclockwise.  This is the opposite direction & 90 degrees
    //offset from our usual clock angle
    var dawnAngle_rad2 = Math.PI / 2 + dawnAngle_rad;
    var duskAngle_rad2 = Math.PI / 2 + duskAngle_rad;
    var currTimeAngle_rad2 = Math.PI / 2 + currTimeAngle_rad;

    var dawnAngle_deg = 270 - Math.toDegrees(dawnAngle_rad);
    var duskAngle_deg = 270 - Math.toDegrees(duskAngle_rad);
    var currTimeAngle_deg = 90 - Math.toDegrees(currTimeAngle_rad);

    //System.println ("getNextDawnDusk: " + dawnAngle_deg + " " + duskAngle_deg + " " +currTimeAngle_rad2);

    dc.setClip(
      0,
      centerY - blankradius - 2,
      width_screen,
      centerY + blankradius + 2
    );

    if (blankradius > 0) {
      dc.setColor(Gfx.COLOR_BLACK, background_color);
      dc.fillCircle(centerX, centerY, blankradius);
    }

    dc.setColor(Gfx.COLOR_WHITE, background_color);

    dc.setPenWidth(4);

    dc.drawArc(
      centerX,
      centerY,
      radius,
      Graphics.ARC_CLOCKWISE,
      dawnAngle_deg,
      duskAngle_deg
    );

    dc.setPenWidth(1);

    dc.drawArc(
      centerX,
      centerY,
      radius,
      Graphics.ARC_CLOCKWISE,
      duskAngle_deg,
      dawnAngle_deg
    );

    var now_radius = radius - 1;
    var smallcircle_radius = 5;

    var nowX = Math.cos(currTimeAngle_rad2) * now_radius + centerX;
    var nowY = Math.sin(currTimeAngle_rad2) * radius + centerY;

    //if (currTimeAngle_rad > dawnAngle_rad && currTimeAngle_rad <= duskAngle_rad) {
    //            dc.fillCircle(nowX,nowY, smallcircle_radius);
    //} else {
    dc.setColor(Gfx.COLOR_BLACK, background_color);
    dc.fillCircle(nowX, nowY, smallcircle_radius);
    dc.setColor(Gfx.COLOR_WHITE, background_color);
    dc.drawCircle(nowX, nowY, smallcircle_radius);
    //}
  }

  //! Draw the watch hand
  //! @param dc Device Context to Draw
  //! @param angle Angle to draw the watch hand
  //! @param length Length of the watch hand
  //! @param width Width of the watch hand
  //! @param draw a circle @ the end
  //! @param draw it as a line instead of polygon
  //! @param shape:
  //    0=regular filled rectangle
  //    1=thin line
  //      2=triangle/point
  //      3 = rectangle outline
  //      4 = blanked rectangle outline
  //      5 = triangle outline
  //      6 = blanked triangle outline
  //      7 = filled circle  [overheadline = radius]
  //      8 = outline circle
  //      9 = blanked outline circle

  //[:dc=dc, :angle=angle,:length=length, :width=width,:overheadLine=overheadLine, :drawCircleOnTop=drawCircleOnTop, :shape=shape,:squeezeX=squeezeX, :squeezeY=squeezeY, :centerX=centerX, :centerY=centerY]

  function drawHand(options) {
    var dc = options[:dc];
    var angle = options[:angle];
    var length = options[:length];
    var width = options[:width];
    var overheadLine = options[:overheadLine];
    var drawCircleOnTop = options[:drawCircleOnTop];
    var shape = options[:shape];
    var squeezeX = options[:squeezeX];
    var squeezeY = options[:squeezeY];
    var centerX = options[:centerX];
    var centerY = options[:centerY];

    // Map out the coordinates of the watch hand
    var count = 4;
    var coords = new [count];

    if (shape == 1) {
      coords = [
        [0, 0 + overheadLine],
        [0, -length],
      ];
      count = 2;
    } else if (shape == 2 || shape == 5 || shape == 6) {
      //TRIANGLE/pointer

      var mult = 1;
      if ($.Options_Dict[secondDisplay] != 0) {
        mult = 4;
      }

      coords = [
        [-(width / 2) * mult, 0 + overheadLine],
        [0, -length],
        [(width / 2) * mult, 0 + overheadLine],
      ];
      count = 3;
    } else if (shape >= 7 && shape <= 9) {
      coords = [[0, -length]];
      count = 1;
    } else {
      coords = [
        [-(width / 2), 0 + overheadLine],
        [-(width / 2), -length],
        [width / 2, -length],
        [width / 2, 0 + overheadLine],
      ];
      count = 4;
    }

    var result = new [count];
    //var centerX = width_screen / 2;
    //var centerY = height_screen / 2;
    //little hand-entry of angle=PI, to make it exact
    var cos = -1;
    var sin = 0;
    //System.println("angle: " + angle);
    if ((Math.PI - angle).abs() > 0.001) {
      cos = Math.cos(angle);
      sin = Math.sin(angle);
    }

    var minY = height_screen;
    var maxY = 0;
    //var minX = width_screen;
    //var maxX = 0;

    // Transform the coordinates
    for (var i = 0; i < count; i += 1) {
      var x = coords[i][0] * cos - coords[i][1] * sin;
      var y = coords[i][0] * sin + coords[i][1] * cos;

      var X = centerX + x;
      var Y = centerY + y;
      var squeezeX_amt = 3;
      var squeezeY_amt = 2;
      //for circles we make sure the whole circle is in frame
      if (shape >= 7 && shape <= 9) {
        squeezeX_amt = 5 + overheadLine;
        squeezeY_amt = 4 + overheadLine;
      }

      if (squeezeX) {
        if (i == 0 || i == count - 1) {
          if (X > width_screen - squeezeX_amt) {
            X = width_screen - squeezeX_amt;
            if (Y < height_screen / 2 - 4) {
              Y += 1;
            } else if (Y > height_screen / 2 + 4) {
              Y -= 1;
            }
          }
          if (X < squeezeX_amt) {
            X = squeezeX_amt;
            if (Y < height_screen / 2 - 4) {
              Y += 1;
            } else if (Y > height_screen / 2 + 4) {
              Y -= 1;
            }
          }
        } else {
          //if ( X>width_screen ) {X = width_screen;}
          //if (X<1) {X=1;}
        }
      }
      if (squeezeY) {
        if (i == 0 || i == count - 1) {
          if (Y > height_screen - squeezeY_amt) {
            Y = height_screen - squeezeY_amt;
            if (X < width_screen / 2 - 4) {
              X += 1;
            } else if (X > width_screen / 2 + 4) {
              X -= 1;
            }
          }
          if (Y < squeezeY_amt) {
            Y = squeezeY_amt;
            if (X < width_screen / 2 - 4) {
              X += 1;
            } else if (X > width_screen / 2 - 4) {
              X -= 1;
            }
          }
        } else {
          //if ( Y>height_screen ) {Y = height_screen;}
          //if (Y<1) {Y=1;}
        }
      }

      result[i] = [X, Y];
      if (Y < minY) {
        minY = Y;
      }
      if (Y > maxY) {
        maxY = Y;
      }
      //if (X<minX) {minX = X;}
      //if (X>maxX) {maxX = X;}

      /*
            if(drawCircleOnTop)
            {
                if(i == 0)
                {
                    var xCircle = ((coords[i][0]+(width/2)) * cos) - ((coords[i][1] + 1) * sin);
                    var yCircle = ((coords[i][0]+(width/2)) * sin) + ((coords[i][1] + 1) * cos);
                    dc.fillCircle(centerX + xCircle, centerY + yCircle, (width/2));
                }
                else if(i == 1)
                {
                    var xCircle = ((coords[i][0]+(width/2)) * cos) - ((coords[i][1] + 1) * sin);
                    var yCircle = ((coords[i][0]+(width/2)) * sin) + ((coords[i][1] + 1) * cos);
                    dc.fillCircle(centerX + xCircle, centerY + yCircle, (width/2));
                }

            }
            */
    }
    //        dc.setClip(minX  -4 ,minY -4,maxX-minX + 8,maxY-minY + 8);

    if (shape >= 7 && shape <= 9) {
      dc.setClip(
        0,
        minY - overheadLine - 2,
        width_screen,
        2 * overheadLine + 4
      );
    } else {
      dc.setClip(0, minY - 3, width_screen, maxY - minY + 6); //don't need clip on X axis as it doesnt affect graphics/display energy usage.
    }
    //System.println("polygon:" + result);
    // Draw the polygon
    /*
        if (shape== 1) {
            dc.drawLine(result[0][0], result[0][1], result[1][0], result[1][1]);
        }
        else if (shape == 2 ){
            //dc.drawLine(result[0][0], result[0][1], result[1][0], result[1][1]);
            //if (shape>1) { dc.shape(result[3][0], result[3][1], result[1][0], result[1][1]);}
            //dc.fillPolygon([[result[0][0], result[0][1]],[result[1][0], result[1][1]],[result[2][0], result[2][1]]]);

            dc.fillPolygon(result);

        } else {
             dc.fillPolygon(result);
        }*/
    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

    if (shape == 1) {
      dc.drawLine(result[0][0], result[0][1], result[1][0], result[1][1]);
    } else if (shape == 3 || shape == 5) {
      //outline poly
      drawPolygon(dc, result, false);
    } else if (shape == 4 || shape == 6) {
      //black/blank outline poly
      drawPolygon(dc, result, true);
    } else if (shape == 7) {
      //filled white circle
      dc.fillCircle(result[0][0], result[0][1], overheadLine);
    } else if (shape == 8) {
      dc.drawCircle(result[0][0], result[0][1], overheadLine); //white circle non-filled/non-blanked
    } else if (shape == 9) {
      //white circle blanked
      dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
      dc.fillCircle(result[0][0], result[0][1], overheadLine);
      dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
      dc.drawCircle(result[0][0], result[0][1], overheadLine);
    } else {
      //regular filled poly
      dc.fillPolygon(result);
    }

    //dc.fillPolygon(result);
    return result;
  }

  //! Draw the watch hand
  //! @param dc Device Context to Draw
  //! @param angle Angle to draw the watch hand
  //! @param length Length of the watch hand
  //! @param width Width of the watch hand
  //! @param draw a circle @ the end
  //! @param shape:
  //    0=regular filled rectangle
  //    1=thin line
  //      2=triangle/point
  //      3 = rectangle outline
  //      4 = blanked rectangle outline
  //      5 = triangle outline
  //      6 = blanked triangle outline

  function drawHandplain(dc, angle, length, width, overheadLine, shape) {
    // Map out the coordinates of the watch hand
    var count = 7;
    var coords = new [7];
    //var centerX_seconds = width_screen / 2;
    //var centerY_seconds = height_screen / 2;

    if (shape == 1) {
      //LINE

      coords = [
        [0, overheadLine],
        [0, -length],
      ];
      count = 2;
    } else if (shape == 2 || shape == 5 || shape == 6) {
      //TRIANGLE/pointer

      //var mult = 1;
      //if (!$.Options_Dict["Long Second"]) {mult = 4;}

      coords = [
        [-(width / 2), overheadLine],
        [0, -length],
        [width / 2, overheadLine],
        //[0, overheadLine],
        //[0,overheadLine + 3],
        //[0, overheadLine],
      ];
      count = 3;
    } else {
      //RECTANGLE

      coords = [
        [-(width / 2), overheadLine],
        [-(width / 2), -length],
        [width / 2, -length],
        [width / 2, overheadLine],
        //[0, overheadLine],
        //[0,overheadLine + 3],
        //[0, overheadLine],
      ];
      count = 4;
    }

    var result = new [count];

    //little hand-entry of angle=PI, to make it exact
    var cos = -1;
    var sin = 0;
    //System.println("angle: " + angle);
    if ((Math.PI - angle).abs() > 0.001) {
      cos = Math.cos(angle);
      sin = Math.sin(angle);
    }

    var minY = height_screen;
    var maxY = 0;
    //var minX = width_screen;
    //var maxX = 0;

    // Transform the coordinates
    for (var i = 0; i < count; i += 1) {
      var X = coords[i][0] * cos - coords[i][1] * sin + centerX_seconds;
      var Y = coords[i][0] * sin + coords[i][1] * cos + centerY_seconds;

      result[i] = [X, Y];
      if (Y < minY) {
        minY = Y;
      }
      if (Y > maxY) {
        maxY = Y;
      }
      //if (i<count-3 && Y<minY) {minY = Y;}
      //if (i<count-3 && Y>maxY) {maxY = Y;}
      //if (X<minX) {minX = X;}
      //if (X>maxX) {maxX = X;}
    }
    //dc.setClip(minX  - 1.5 ,minY -1.5,maxX-minX + 3,maxY-minY + 3);
    dc.setClip(0, minY - 1.5, width_screen, maxY - minY + 3);
    //System.println ("result: " + result);
    //System.println ("clip  :" + (minX  -1) + ", " + (minY -1) + ", " + (maxX-minX + 2) + ", " + (maxY-minY + 2));

    if (shape == 1) {
      dc.drawLine(result[0][0], result[0][1], result[1][0], result[1][1]);
    } else if (shape == 3 || shape == 5) {
      //outline poly
      drawPolygon(dc, result, false);
    } else if (shape == 4 || shape == 6) {
      //black/blank outline poly
      drawPolygon(dc, result, true);
    } else {
      //regular filled poly
      dc.fillPolygon(result);
    }
  }

  function drawPolygon(dc, points, blank) {
    if (blank) {
      dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
      dc.fillPolygon(points);
      dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
    }
    //System.println("points: " + points);
    for (var i = 0; i < points.size(); i += 1) {
      var p2 = (i + 1) % points.size();
      dc.drawLine(points[i][0], points[i][1], points[p2][0], points[p2][1]);
    }
  }

  function drawHands(
    dc,
    clock_hour,
    clock_min,
    clock_sec,
    hour_color,
    min_color,
    sec_color
  ) {
    var hour, min;

    // Draw the hour. Convert it to minutes and
    // compute the angle.
    hour = (clock_hour % 12) * 60 + clock_min;
    hour = hour / (12 * 60.0);
    hour = hour * Math.PI * 2;
    dc.setColor(hour_color, Gfx.COLOR_TRANSPARENT);
    var hr_width = 5;
    var min_width = 4;
    if (width_screen > 176) {
      hr_width = (5 / 176.0) * max_screen;
      min_width = (4 / 176.0) * max_screen;
    }

    var options = {
      :dc => dc,
      :angle => hour,
      :length => width_screen * 0.41 * 0.6,
      :width => hr_width,
      :overheadLine => 15,
      :drawCircleOnTop => false,
      :shape => 0,
      :squeezeX => false,
      :squeezeY => false,
      :centerX => centerX_main,
      :centerY => centerY_main,
    };
    //drawHand(dc, hour, width_screen*.41 * .6, 5, 15, false, 0,false, false);
    drawHand(options);

    // Draw the minute
    min = (clock_min / 60.0) * Math.PI * 2;
    dc.setColor(min_color, Gfx.COLOR_TRANSPARENT);

    options = {
      :dc => dc,
      :angle => min,
      :length => width_screen * 0.41,
      :width => min_width,
      :overheadLine => 15,
      :drawCircleOnTop => false,
      :shape => 0,
      :squeezeX => false,
      :squeezeY => false,
      :centerX => centerX_main,
      :centerY => centerY_main,
    };
    //drawHand(dc, min, width_screen*.41, 4, 15, false, 0,false, false);
    drawHand(options);

    //System.println("hr,min:" + hour + ", " + min);

    /*
        // Draw the seconds
        if(showSecond){
            sec = ( clock_sec / 60.0) *  Math.PI * 2;
            dc.setColor(sec_color, Gfx.COLOR_TRANSPARENT);
            drawHand(dc, sec, 105, 2, 15, true);
        }

        // Draw the inner circle
        dc.setColor(Gfx.COLOR_WHITE, background_color);
        dc.fillCircle(width_screen/2, height_screen/2, 6);
        dc.setColor(background_color,background_color);
        dc.drawCircle(width_screen/2, height_screen/2, 6);
        */
  }

  //! Draw the hash mark symbols on the watch
  //! @param dc Device context
  function drawHashMarks(dc, drawHashes, drawHours, avoidCircle, squeeze) {
    if (drawHours) {
      // Draw the numbers
      var font = Gfx.FONT_LARGE;
      var adj1 = -1;
      var adj2 = 1;
      if (width_screen < 166) {
        adj1 = -3;
        adj2 = 0;
      }
      var adj12 = 1;
      var adj6 = -32;
      if (width_screen > 176) {
        var fact = width_screen / 25;
        adj12 = fact;
        adj6 = -dc.getFontHeight(font) - fact;
        adj1 = -fact;
        adj2 = fact;
      }

      dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
      dc.drawText(width_screen / 2, adj12, font, "12", Gfx.TEXT_JUSTIFY_CENTER);
      dc.drawText(
        width_screen + adj1,
        height_screen / 2,
        font,
        "3 ",
        Gfx.TEXT_JUSTIFY_RIGHT + Gfx.TEXT_JUSTIFY_VCENTER
      );
      dc.drawText(
        width_screen / 2,
        height_screen + adj6,
        font,
        "6",
        Gfx.TEXT_JUSTIFY_CENTER
      );
      dc.drawText(
        adj2,
        height_screen / 2,
        font,
        " 9",
        Gfx.TEXT_JUSTIFY_LEFT + Gfx.TEXT_JUSTIFY_VCENTER
      );
    }

    if (drawHashes) {
      var devset = System.getDeviceSettings();
      for (var i = 0; i < 12; i += 1) {
        if (
          (!drawHours || (i != 0 && i != 3 && i != 6 && i != 9)) &&
          (!avoidCircle || (i != 1 && i != 2))
        ) {
          if (
            devset.screenShape == System.SCREEN_SHAPE_SEMI_OCTAGON &&
            i % 3 == 0
          ) {
            continue;
          } //skip the hour hashes 3, 6, 9, 12 for Instinct ; looks better that way

          var adder = 0;
          var width_adder = 0;
          if (width_screen < 166) {
            if (i == 1) {
              adder = 3;
              width_adder = 4;
            }
            if (i == 2) {
              adder = -7;
            }
          } else if (width_screen <= 176) {
            if (i == 1) {
              adder = -4;
              width_adder = 0;
            }
            if (i == 2) {
              adder = -3;
            }
          }

          if (i % 3 == 0) {
            //adder = max_screen/12.0;
            adder = 15;
          }
          //if (width_screen > 176) {adder +=-75;}
          //drawHand(dc, hashMarksArray[i][0], 100, 2 + width_adder, hashMarksArray[i][1]+adder, false, 0, false, false);
          var options = {
            :dc => dc,
            :angle => hashMarksArray[i][0],
            :length => max_screen * 0.55,
            :width => 2 + width_adder,
            :overheadLine => hashMarksArray[i][1] + adder,
            :drawCircleOnTop => false,
            :shape => 0,
            :squeezeX => squeeze,
            :squeezeY => squeeze,
            :centerX => centerX_main,
            :centerY => centerY_main,
          };

          //system.println("option" + options);

          drawHand(options);

          //drawHand(dc, angle, length, width, overheadLine, drawCircleOnTop)
        }
      }
    }
  }

  //! Draw the hash mark symbols on the watch
  //! @param dc Device context
  // [:dc=dc, :radius=radius, :includeOnes=include, length1, width1, includeFives, length5, width5, avoidCircle,squeezeX, squeezeY, centerX, centerY]
  function drawSecondHashMarks(options) {
    //system.println("dshh1");

    for (var i = 0; i < 60; i += 1) {
      //system.println("dshh2");
      if (options[:avoidCircle] && i > 2 && i < 13) {
        continue;
      }
      //System.println("SecondHash: " + i/5);
      var angle = (i / 60.0) * Math.PI * 2;
      if (i % 5 == 0) {
        //system.println("dshh3");
        if (options[:includeFives]) {
          var shape = 0;
          if (options[:width5] == 1) {
            shape = 1;
          }

          //drawHand(options[:dc], angle, options[:radius], options[:width5], options[:length5] - options[:radius], false, shape,options[:squeezeX],options[:squeezeY],options[:centerX],options[:centerY]);

          var length = options[:length5];
          if (i % 3 == 0 && options[:length36912] != null) {
            length = options[:length36912];
          }

          var newoptions = {
            :dc => options[:dc],
            :angle => angle,
            :length => options[:radius],
            :width => options[:width5],
            :overheadLine => length - options[:radius],
            :drawCircleOnTop => false,
            :shape => shape,
            :squeezeX => options[:squeezeX],
            :squeezeY => options[:squeezeY],
            :centerX => options[:centerX],
            :centerY => options[:centerY],
          };
          //system.println("dh1");
          drawHand(newoptions);
          //system.println("dh1a");
          //drawHand(dc, angle, length, width, overheadLine, drawCircleOnTop, shape, squeezeX, squeezeY)
        }
      } else {
        //system.println("dshh3");
        if (options[:includeOnes]) {
          var shape = 0;
          if (options[:width5] == 1) {
            shape = 1;
          }

          //drawHand(options[:dc], angle, options[:radius], options[:width1], options[:length1] - options[:radius], false, shape,options[:squeezeX],options[:squeezeY]);

          var newoptions = {
            :dc => options[:dc],
            :angle => angle,
            :length => options[:radius],
            :width => options[:width1],
            :overheadLine => options[:length1] - options[:radius],
            :drawCircleOnTop => false,
            :shape => shape,
            :squeezeX => options[:squeezeX],
            :squeezeY => options[:squeezeY],
            :centerX => options[:centerX],
            :centerY => options[:centerY],
          };
          //system.println("dh2");
          drawHand(newoptions);
          //system.println("dh2a");
        }
      }
    }
  }

  /*

    function drawBattery(dc, primaryColor, lowBatteryColor, fullBatteryColor)
    {
        var battery = Sys.getSystemStats().battery;

        if(battery < 15.0)
        {
            primaryColor = lowBatteryColor;
        }
        //else if(battery == 100.0)
        //{
        //    primaryColor = fullBatteryColor;
        //}

        dc.setColor(primaryColor, Gfx.COLOR_TRANSPARENT);
        dc.drawRectangle(batt_x, batt_y, batt_width_rect, batt_height_rect);
        dc.setColor(background_color, Gfx.COLOR_TRANSPARENT);
        dc.drawLine(batt_x_small-1, batt_y_small+1, batt_x_small-1, batt_y_small + batt_height_rect_small-1);

        dc.setColor(primaryColor, Gfx.COLOR_TRANSPARENT);
        dc.drawRectangle(batt_x_small, batt_y_small, batt_width_rect_small, batt_height_rect_small);
        dc.setColor(background_color, Gfx.COLOR_TRANSPARENT);
        dc.drawLine(batt_x_small, batt_y_small+1, batt_x_small, batt_y_small + batt_height_rect_small-1);

        dc.setColor(primaryColor, Gfx.COLOR_TRANSPARENT);
        dc.fillRectangle(batt_x, batt_y, (batt_width_rect * battery / 100), batt_height_rect);
        if(battery == 100.0)
        {
            dc.fillRectangle(batt_x_small, batt_y_small, batt_width_rect_small, batt_height_rect_small);
        }
    }
    */

  function drawBattery(dc, primaryColor, lowBatteryColor, fullBatteryColor) {
    var battery = System.getSystemStats().battery;

    if (battery < 15.0) {
      primaryColor = lowBatteryColor;
    }
    //else if(battery == 100.0)
    //{
    //    primaryColor = fullBatteryColor;
    //}
    //deBug("color", [primaryColor, lowBatteryColor, fullBatteryColor]);
    dc.setPenWidth(1);
    dc.setColor(primaryColor, Graphics.COLOR_TRANSPARENT);
    dc.drawRectangle(batt_x, batt_y, batt_width_rect, batt_height_rect);
    //dc.setColor(activities_background_color, Graphics.COLOR_TRANSPARENT);
    //dc.drawLine(batt_x_small-1, batt_y_small+1, batt_x_small-1, batt_y_small + batt_height_rect_small-1);
    //return;

    dc.setColor(primaryColor, Graphics.COLOR_TRANSPARENT);
    dc.drawRectangle(
      batt_x_small,
      batt_y_small,
      batt_width_rect_small,
      batt_height_rect_small
    );
    dc.setColor(activities_background_color, Graphics.COLOR_TRANSPARENT);
    dc.drawLine(
      batt_x_small,
      batt_y_small + 1,
      batt_x_small,
      batt_y_small + batt_height_rect_small - activities_gap
    );

    dc.setColor(primaryColor, Graphics.COLOR_TRANSPARENT);
    dc.fillRectangle(
      batt_x,
      batt_y,
      Math.ceil((batt_width_rect * battery) / 100.0f),
      batt_height_rect
    );
    if (battery == 100.0) {
      dc.fillRectangle(
        batt_x_small,
        batt_y_small,
        batt_width_rect_small,
        batt_height_rect_small
      );
    }
  }

  function drawMove(dc, text_color, index) {
    var dateStr1 = "MOVE!";
    dc.setColor(text_color, Gfx.COLOR_BLACK);

    dc.drawText(
      width_screen * 0.5,
      batt_y + (index - 1.4) * batt_height_rect,
      Gfx.FONT_SYSTEM_XTINY,
      dateStr1,
      Gfx.TEXT_JUSTIFY_CENTER
    );
  }

  function getBodyBatteryIterator() {
    // Check device for SensorHistory compatibility
    if (
      Toybox has :SensorHistory &&
      Toybox.SensorHistory has :getBodyBatteryHistory
    ) {
      // Set up the method with parameters
      return Toybox.SensorHistory.getBodyBatteryHistory({ :period => 1 });
    }
    return null;
  }
  function drawBodyBattery(dc, text_color) {
    var bbValue = "--";

    try {
      var bbIterator = getBodyBatteryIterator();
      if (bbIterator != null) {
        var sample = bbIterator.next();
        if (sample != null && sample.data != null) {
          bbValue = sample.data.toNumber().toString();
        }
      }
    } catch (ex) {
      // Handle any exceptions gracefully
      bbValue = "--";
    }
    dc.setColor(text_color, Gfx.COLOR_BLACK);

    dc.drawText(
      width_screen * 0.5 - 40,
      height_screen * 0.5 + 25,
      Gfx.FONT_SYSTEM_XTINY,
      "BB: " + bbValue,
      Gfx.TEXT_JUSTIFY_CENTER
    );
  }

  private function getStress() {
    // developer.garmin.com/.../SensorHistory.html
    if (
      Toybox has :SensorHistory &&
      Toybox.SensorHistory has :getStressHistory
    ) {
      var history = Toybox.SensorHistory.getStressHistory({
        :period => 1,
        :order => Toybox.SensorHistory.ORDER_NEWEST_FIRST,
      });
      var sample = history.next();
      if (
        sample != null &&
        sample.data != null &&
        sample.data >= 0 &&
        sample.data <= 100
      ) {
        return sample.data.format("%02d");
      }
    }
    return "--";
  }
  function drawStress(dc, text_color) {
    dc.setColor(text_color, Gfx.COLOR_BLACK);
    dc.drawText(
      width_screen * 0.5 + 40,
      height_screen * 0.5 + 25, // 125 is a line after BodyBattery
      Gfx.FONT_SYSTEM_XTINY,
      "S: " + getStress(),
      Gfx.TEXT_JUSTIFY_CENTER
    );
  }

  private function getHeartRate() {
    var heartRate = null;

    // Check if Activity has currentHeartRate information
    var activityInfo = Acty.getActivityInfo();
    if (activityInfo != null && activityInfo has :currentHeartRate) {
      heartRate = activityInfo.currentHeartRate;
    }

    // If currentHeartRate is null, try to get it from heart rate history
    if (heartRate == null) {
      if (Act has :getHeartRateHistory) {
        var heartRateHistory = Act.getHeartRateHistory(1, true); // Get the most recent sample, excluding future samples
        if (heartRateHistory != null) {
          var heartRateSample = heartRateHistory.next(); // Get the actual sample

          if (
            heartRateSample != null &&
            heartRateSample.heartRate != Act.INVALID_HR_SAMPLE
          ) {
            heartRate = heartRateSample.heartRate;
          }
        }
      }
    }

    // Format the heart rate for display
    if (heartRate != null) {
      return heartRate.toString();
    } else {
      return "--";
    }
  }
  function drawHeartRate(dc, text_color) {
    dc.setColor(text_color, Gfx.COLOR_BLACK);
    dc.drawText(
      width_screen * 0.5 - 40,
      height_screen * 0.5 - 35,
      Gfx.FONT_SYSTEM_XTINY,
      "HR: " + getHeartRate(),
      Gfx.TEXT_JUSTIFY_CENTER
    );
  }

  private function getNextEvent() {
    var nextEventTime = "";

    var myEventID = new Complications.Id(
      Complications.COMPLICATION_TYPE_CALENDAR_EVENTS
    );
    var complication = Complications.getComplication(myEventID);

    if (complication.value != null) {
      nextEventTime = complication.value as String;
    } else {
      nextEventTime = ""; // No event or data not available
    }

    return nextEventTime;
  }
  function drawNextEvent(dc, text_color) {
    dc.setColor(text_color, Gfx.COLOR_BLACK);
    dc.drawText(
      60,
      30,
      Gfx.FONT_SYSTEM_XTINY,
      getNextEvent(),
      Gfx.TEXT_JUSTIFY_CENTER
    );
  }

  /*
    function drawMoveDots(dc, num, goal, index, text_color)
    {
        //System.println("dMD: " + num + " " + goal  + " " + index);

        //System.println("dMD: " + (num instanceof Lang.Object) + " " + (goal instanceof Lang.Object)  + " " + index);
        if (goal ==0 ) { goal =100; }
        var numDots = num * 1.0/ (goal * 1.0) * 5 + 0.00001; //to avoid 4.9999 type situations when we round by .floor() later
        var numD_floor = Math.floor(numDots);
        var partial = numDots - numD_floor;

        if (numDots==0 && partial < 0.33 ) { return; }
        if ( numDots>6 ) { numDots = 6; partial = 0;  }
        numD_floor = Math.floor(numDots);
        if (partial <0.3333) {partial = 0;}

        var squares = numD_floor;
        var partial_mx = Math.floor (partial * 3);
        if (numDots < 6 && partial >= 0.3333) { squares +=1; }

        //var x_start = dmd_x - (numDots*dmd_w + numDots -1)/2; //Dots will be centered under the battery;
        var fact = numD_floor*dmd_w + squares -1;
        if (partial >= 0.3333) { fact = fact + partial;}

        var x_start = dmd_x - (fact)/2; //Dots will be centered under the battery;

        //System.println("dMD: " + numDots + " " + partial  + " " + squares);

        dc.setColor(text_color, Gfx.COLOR_TRANSPARENT);

        for (var i = 0; i < squares; i++) {
            //var xx = x_start + i * dmd_w4;
            var xx = x_start + i * 4;
            var yy = dmd_yy + index * (dmd_h + 1);
            if (i < 5 || (i==5 && partial > 0)) {
                var mx = 3;
                if (i == numD_floor) { mx = partial_mx; }

                //System.println("dMD: " + numDots + " " + partial  + " " + squares + " " + i + " " + mx);

                //dc.fillRectangle(xx, yy, dmd_w, dmd_h);
                for (var j=0; j<mx; j++) {
                    dc.drawLine(xx + j, yy,xx +j ,yy + dmd_h);
                }
                //} else { //the partial square
                //    dc.fillRectangle(xx, yy, dmd_w * partial, dmd_h);
                //}
            } else {
                //plus sign
                //dc.drawRectangle(xx, yy, dmd_w, dmd_h);
                dc.drawLine(xx + dmd_w/2, yy,xx + dmd_w/2 ,yy + dmd_h);
                dc.drawLine(xx, yy + dmd_h/2 ,xx + dmd_w , yy + dmd_h/2);
            }
        }



    }
    */

  function drawMoveDots(dc, num, goal, index, text_color) {
    dc.setPenWidth(1);
    //System.println("dMD: " + num + " " + goal  + " " + index);

    //System.println("dMD: " + (num instanceof Lang.Object) + " " + (goal instanceof Lang.Object)  + " " + index);
    if (goal == 0) {
      goal = 100;
    }
    var numDots = ((num * 1.0) / (goal * 1.0)) * 5 + 0.00001; //to avoid 4.9999 type situations when we round by .floor() later
    var numD_floor = Math.floor(numDots);
    var partial = numDots - numD_floor;

    var part = 1f / dmd_w;

    if (numDots > 6) {
      numDots = 6;
      partial = 0;
    }
    numD_floor = Math.floor(numDots).toNumber();
    if (partial < part) {
      partial = 0;
    }

    var squares = numD_floor;
    var partial_mx = Math.floor(partial * dmd_w);
    if (numDots < 6 && partial >= part) {
      squares += 1;
    }

    //var x_start = dmd_x - (numDots*dmd_w + numDots -1)/2; //Dots will be centered under the battery;
    var fact = numD_floor * dmd_w + squares - 1;
    if (partial >= part) {
      fact = fact + partial;
    }

    var x_start = Math.round(dmd_x - fact / 2.0); //Dots will be centered under the battery;

    dc.setColor(text_color, Graphics.COLOR_TRANSPARENT);

    //deBug("numDs", [numDots, partial, dmd_w, 1f/dmd_w]);

    //If this activity hasn't started yet/nothing registered they get a littly
    //TALLY just as a placeholder
    if (numD_floor == 0 && partial < 1f / dmd_w) {
      var xx = Math.round(x_start).toNumber(); //4
      var yy = Math.round(dmd_yy + index * (dmd_h + activities_gap)).toNumber();

      //var x_add = xx + (dmd_w)/2.0;
      //var y_add = yy + (dmd_h)/2.0;
      //dc.drawLine(x_add, yy,x_add ,yy + dmd_h);
      //deBug("NOTHING dots", [xx, yy ,yy + dmd_h ]);
      //dc.drawLine(xx, y_add ,xx + dmd_w , y_add);
      dc.drawLine(xx, yy, xx, yy + dmd_h);
      return;
    }
    //System.println("dMD: " + numDots + " " + partial  + " " + squares);

    //deBug("col", [text_color, Graphics.COLOR_TRANSPARENT]);

    //dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

    //deBug("col", [squares]);
    for (var i = 0; i < squares; i++) {
      //var xx = x_start + i * dmd_w4;
      var xx = Math.round(x_start + i * (dmd_w + 1)).toNumber(); //4
      var yy = Math.round(dmd_yy + index * (dmd_h + activities_gap)).toNumber();
      if (i < 5 || (i == 5 && partial > 0)) {
        var mx = dmd_w; //3;
        if (i == numD_floor) {
          mx = partial_mx;
        }

        //System.println("dMD: " + numDots + " " + partial  + " " + squares + " " + i + " " + mx);

        //dc.fillRectangle(xx, yy, dmd_w, dmd_h);
        for (var j = 0; j < mx; j++) {
          dc.drawLine(xx + j, yy, xx + j, yy + dmd_h);
          //deBug("drawline", [xx + j, yy,xx +j ,yy + dmd_h]);
          //deBug("drawline", [xx, yy,dmd_h]);
        }
        //} else { //the partial square
        //    dc.fillRectangle(xx, yy, dmd_w * partial, dmd_h);
        //}
      } else {
        //plus sign
        //dc.drawRectangle(xx, yy, dmd_w, dmd_h);
        //deBug("plus", [xx, yy,dmd_h, dmd_w]);
        var x_add = xx + dmd_w / 2.0;
        var y_add = yy + dmd_h / 2.0;
        dc.drawLine(x_add, yy, x_add, yy + dmd_h);
        dc.drawLine(xx, y_add, xx + dmd_w, y_add);
      }
    }
  }

  function drawDateInset(dc, text_color, reverse as Boolean) {
    var now = Time.now();
    var info = Calendar.info(now, Time.FORMAT_LONG);
    //var dateStr = Lang.format("$1$ $2$ $3$", [info.day_of_week, info.month, info.day]);
    //System.println("DATEDATEDATE");

    //dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_TRANSPARENT);
    //dc.drawRectangle(0,0,dc.getWidth(),dc.getHeight());

    var dateStr2 = Lang.format("$1$", [info.day.format("%02d")]);
    var dateStr1 = Lang.format("$1$", [info.day_of_week]);
    if ($.Options_Dict[showMonthDay]) {
      dateStr1 = Lang.format("$1$", [info.month]);
    }

    if (reverse) {
      dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
      /*if (width_screen >= 175)  {
                dc.fillCircle(144, 34, 34);
            } else if (width_screen >= 166)  {
                dc.fillCircle(144, 34, 34);
            } else {
                dc.fillCircle(130, 27, 30);  //Instinct S, smaller screen & weird. center of circle is about  131,27 & radius 27
            }*/
      dc.fillCircle(centerX_circle, centerY_circle, radius_circle + 2);
      dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
      //dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE); //This works better on sim but worse on real watch
    } else {
      dc.setColor(text_color, Gfx.COLOR_TRANSPARENT);
      //dc.setColor(text_color, Gfx.COLOR_BLACK);//This works better on sim but worse on real watch
    }

    //dc.drawText(width_screen * .15 , (height_screen * -.04), Gfx.FONT_SYSTEM_NUMBER_THAI_HOT, dateStr2, Gfx.TEXT_JUSTIFY_CENTER);
    //dc.drawText(width_screen * .15 , (height_screen * .22), Gfx.FONT_SYSTEM_MEDIUM, dateStr1, Gfx.TEXT_JUSTIFY_CENTER);

    //var f1 = Gfx.FONT_SYSTEM_NUMBER_MEDIUM;
    //deBug ("FONT size", [radius_circle,dc.getFontHeight(Gfx.FONT_SYSTEM_LARGE),
    //dc.getFontHeight(Gfx.FONT_SYSTEM_NUMBER_MEDIUM), dc.getFontHeight(Gfx.FONT_SYSTEM_NUMBER_MILD), dc.getFontHeight(Gfx.FONT_SYSTEM_NUMBER_MEDIUM
    //) ]);

    var f1 = Gfx.FONT_SYSTEM_NUMBER_MEDIUM; //good for instinct

    if (dc.getFontHeight(Gfx.FONT_SYSTEM_NUMBER_MEDIUM) > radius_circle * 1.4) {
      if (dc.getFontHeight(Gfx.FONT_SYSTEM_LARGE) < radius_circle * 1.35) {
        f1 = Gfx.FONT_SYSTEM_LARGE; //for for 965 & some/most others?!?!?!?!?
      } else if (
        dc.getFontHeight(Gfx.FONT_SYSTEM_MEDIUM) <
        radius_circle * 1.35
      ) {
        f1 = Gfx.FONT_SYSTEM_MEDIUM; //Just in case???!~???
      } else {
        f1 = Gfx.FONT_SYSTEM_SMALL;
      }
    }
    //var f1 = Gfx.FONT_SYSTEM_LARGE; //for for 965 & some/most others?!?!?!?!?
    //var f1 = Gfx.FONT_SYSTEM_NUMBER_MEDIUM; //good for instinct
    //var f2 = Gfx.FONT_SYSTEM_SMALL;
    var f2 = Gfx.FONT_SYSTEM_TINY;

    if (width_screen <= 176) {
      var ws = 0.82;
      //var hs1 = -.03;
      var hs1 = 0.0;
      var hs2 = 0.21;

      if (width_screen < 166) {
        //case of Instinct S, smaller screen
        ws = 0.86;
        hs1 = -0.01;
        hs2 = 0.2;
        f1 = Gfx.FONT_SYSTEM_NUMBER_MEDIUM;
        f2 = Gfx.FONT_SYSTEM_TINY;
      }

      //dc.drawText(width_screen * ws , (height_screen * hs2), f2, dateStr1, Gfx.TEXT_JUSTIFY_CENTER);      //better for sim this first
      dc.drawText(
        width_screen * ws,
        height_screen * hs1,
        f1,
        dateStr2,
        Gfx.TEXT_JUSTIFY_CENTER
      );
      dc.drawText(
        width_screen * ws,
        height_screen * hs2,
        f2,
        dateStr1,
        Gfx.TEXT_JUSTIFY_CENTER
      ); //better for watch, this first
    } else {
      //LARGER SCREENS & AMOLED

      var f1_h = dc.getFontHeight(f1);
      var f2_h = dc.getFontHeight(f2);

      dc.drawText(
        centerX_circle,
        centerY_circle + f1_h * 0.075 + 2,
        f2,
        dateStr1,
        Gfx.TEXT_JUSTIFY_CENTER
      ); //better for watch, this first\
      dc.drawText(
        centerX_circle,
        centerY_circle - f1_h * 0.8,
        f1,
        dateStr2,
        Gfx.TEXT_JUSTIFY_CENTER
      );
    }
  }

  function drawDateMain(dc, text_color, reverse as Boolean) {
    var now = Time.now();
    var info = Calendar.info(now, Time.FORMAT_LONG);
    //var dateStr = Lang.format("$1$ $2$ $3$", [info.day_of_week, info.month, info.day]);
    //System.println("DATEDATEDATEMAIN");

    //dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_TRANSPARENT);
    //dc.drawRectangle(0,0,dc.getWidth(),dc.getHeight());

    var dateStr2 = Lang.format("$1$", [info.day.format("%02d")]);
    var dateStr1 = Lang.format("$1$", [info.day_of_week]);
    if ($.Options_Dict[showMonthDay]) {
      dateStr1 = Lang.format("$1$", [info.month]);
    }
    //dateStr1 += " " + dateStr2;

    if (reverse) {
      /*
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            if (width_screen >= 166)  {
                dc.fillCircle(144, 34, 34);
            } else {
                dc.fillCircle(130, 27, 30);  //Instinct S, smaller screen & weird. center of circle is about  131,27 & radius 27
            }
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            //dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE); //This works better on sim but worse on real watch
            */
    } else {
      //dc.setColor(text_color, Gfx.COLOR_TRANSPARENT);
      dc.setColor(text_color, Gfx.COLOR_BLACK); //This works better on sim but worse on real watch
    }

    //dc.drawText(width_screen * .15 , (height_screen * -.04), Gfx.FONT_SYSTEM_NUMBER_THAI_HOT, dateStr2, Gfx.TEXT_JUSTIFY_CENTER);
    //dc.drawText(width_screen * .15 , (height_screen * .22), Gfx.FONT_SYSTEM_MEDIUM, dateStr1, Gfx.TEXT_JUSTIFY_CENTER);
    var f1 = Gfx.FONT_SMALL;
    //var f1 = Gfx.FONT_SYSTEM_NUMBER_THAI_HOT;
    //var f2 = Gfx.FONT_SYSTEM_SMALL;
    var f2 = Gfx.FONT_SMALL;

    var th = dc.getFontHeight(f2);

    //System.println("TH" + th);

    //small second hand main display CENTER

    /*

            var ws1 = .23;
            var ws2 = .23;
            //var hs1 = -.03;
            var hs1 =.7;
            var hs2 = hs1 + 0.8* th.toFloat()/height_screen;
            var just1 = Gfx.TEXT_JUSTIFY_CENTER;
            var just2 = just1;
            */

    //Second hand small circle (above) OR whole watchface main (below)
    //if ($.Options_Dict[secondDisplay] != 1) {
    f1 = Gfx.FONT_MEDIUM;
    f2 = f1;
    th = dc.getFontHeight(f2);
    var just1 = Gfx.TEXT_JUSTIFY_LEFT;
    var just2 = Gfx.TEXT_JUSTIFY_RIGHT;
    var ws1 = 0.051;
    var ws2 = 0.965;
    /*if (!$.Options_Dict[hourNumbers]) {
                ws1 = .23;
                ws2 = .77;
            }*/

    //var hs1 = -.03;
    var hs1 = 0.49;
    var hs2 = hs1;

    if (!$.Options_Dict[hourNumbers]) {
      dateStr1 += " " + dateStr2;
      dateStr2 = "";
    }

    //}

    var tw1 = dc.getTextWidthInPixels(dateStr1, f1);
    var tw2 = dc.getTextWidthInPixels(dateStr2, f2);

    /*if (width_screen < 166) {  //case of Instinct S, smaller screen
            ws = .86;
            hs1 = -.01;
            hs2 = .20;
            f1 = Gfx.FONT_SYSTEM_NUMBER_MEDIUM;
            f2 = Gfx.FONT_SYSTEM_TINY;
        }*/

    //dc.drawText(width_screen * ws , (height_screen * hs2), f2, dateStr1, Gfx.TEXT_JUSTIFY_CENTER);      //better for sim this first

    //And...2S needs boxes raised 2 pixels FOR SOME REASON...
    var rect_cor_top = 0;
    var rect_cor_bot = 0;
    if (width_screen < 166) {
      rect_cor_top = -2;
      rect_cor_bot = 1;
      hs1 += 0.005;
      hs2 += 0.005;
      //ws2 += .005;
    }

    dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);

    //if ($.Options_Dict[hourNumbers]) {
    dc.fillRectangle(
      width_screen * ws1 - 2,
      height_screen * hs1 - th / 2.0 + 4 + rect_cor_top,
      tw1 + 3,
      th - 3 + rect_cor_bot
    );

    dc.fillRectangle(
      width_screen * ws2 - 2 - tw2 + 1,
      height_screen * hs2 - th / 2.0 + 4 + rect_cor_top,
      tw2 + 3,
      th - 3 + rect_cor_bot
    );
    //}

    dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);

    dc.drawText(
      width_screen * ws2,
      height_screen * hs2,
      f2,
      dateStr2,
      just2 | Gfx.TEXT_JUSTIFY_VCENTER
    );
    dc.drawText(
      width_screen * ws1,
      height_screen * hs1,
      f1,
      dateStr1,
      just1 | Gfx.TEXT_JUSTIFY_VCENTER
    );

    dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);

    if ($.Options_Dict[hourNumbers]) {
      dc.drawRectangle(
        width_screen * ws1 - 2,
        height_screen * hs1 - th / 2.0 + 4 + rect_cor_top,
        tw1 + 3,
        th - 3 + rect_cor_bot
      );

      dc.drawRectangle(
        width_screen * ws2 - 2 - tw2 + 1,
        height_screen * hs2 - th / 2.0 + 4 + rect_cor_top,
        tw2 + 3,
        th - 3 + rect_cor_bot
      );
    }
  }

  function mod(x, y) {
    var part = x / y - Math.floor(x / y);
    return part * y;
  }
}

//! Receives watch face events
class ElegantAnaDelegate extends WatchUi.WatchFaceDelegate {
  private var _view as ElegantAnaView;

  //! Constructor
  //! @param view The analog view
  public function initialize(view as ElegantAnaView) {
    WatchFaceDelegate.initialize();
    _view = view;
  }

  //! The onPowerBudgetExceeded callback is called by the system if the
  //! onPartialUpdate method exceeds the allowed power budget. If this occurs,
  //! the system will stop invoking onPartialUpdate each second, so we notify the
  //! view here to let the rendering methods know they should not be rendering a
  //! second hand.
  //! @param powerInfo Information about the power budget
  public function onPowerBudgetExceeded(
    powerInfo as WatchFacePowerInfo
  ) as Void {
    System.println("Average execution time: " + powerInfo.executionTimeAverage);
    System.println("Allowed execution time: " + powerInfo.executionTimeLimit);
    _view.turnPartialUpdatesOff();
  }

  public function onKey(keyEvent) {
    _view.resetSecondHandCounter();
    return true;
  }
}

/*
//Note, below doesn't work as watchfaces can't receive button input @ all
class ElegantAnaInputDelegate extends WatchUi.InputDelegate {

    private var _view as ElegantAnaView;

    //! Constructor
    //! @param view The analog view
    public function initialize(view as ElegantAnaView) {
        InputDelegate.initialize();
        _view = view;
    }

    function onKey(keyEvent) {
        _view.resetSecondHandCounter();
        System.println("KEY PRESSED!!!!!");
        return false;
    }
}
*/

function deBug(label, ary) {
  System.println(label + ": " + ary);
}
