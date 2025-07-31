//
// Copyright 2016-2021 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables
// Application Developer Agreement.
//

import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.WatchUi;

var Options_Dict = {};
var Options;
var defOptions;
var numOptions;
var Settings_ran = false;

enum {
  infiniteSecondOption = 0,
  secondDisplay = 1,
  secondHandOption = 2,
  dawnDuskMarkers = 3,

  showBattery = 4,
  showMinutes = 5,

  showDayMinutes = 6,
  showSteps = 7,
  showMove = 8,
  showDate = 9,
  showMonthDay = 10,
  hourNumbers = 11,
  hourHashes = 12,
  secondHashes = 13,
  aggressiveClear = 14,

  showBodyBattery = 15,

  //lastLoc_saved = 99,
}

//var infiniteSecondOptions=WatchUi.loadResource( $.Rez.JsonData.infiniteSecondOptions) as Array;
var infiniteSecondLengths =
  WatchUi.loadResource($.Rez.JsonData.infiniteSecondLengths) as Array;
//var infiniteSecondOptions_size = 8;
//var infiniteSecondOptions_default = 2;

//var secondDisplayOptions=WatchUi.loadResource( $.Rez.JsonData.secondDisplayOptions) as Array;
//var secondDisplayOptions_size = 3;
//var secondDisplayOptions_default = 0;

//var secondHandOptions=WatchUi.loadResource( $.Rez.JsonData.secondHandOptions) as Array;
//var secondHandOptions_size = 8;
//var secondHandOptions_default = 1;

//var dawnDuskOptions=WatchUi.loadResource( $.Rez.JsonData.dawnDuskOptions) as Array;
//var dawnDuskOptions_size = 5;
//var dawnDuskOptions_default = 0;

var infiniteSecondOptions;
var secondDisplayOptions;
var secondHandOptions;
var dawnDuskOptions;

//! The app settings menu
class ElegantAnaSettingsMenu extends WatchUi.Menu2 {
  //! Constructor
  public function initialize() {
    $.Settings_ran = true;

    var clockTime = System.getClockTime();
    System.println(
      clockTime.hour + ":" + clockTime.min + " - Settings running"
    );

    infiniteSecondOptions =
      WatchUi.loadResource($.Rez.JsonData.infiniteSecondOptions) as Array;
    secondDisplayOptions =
      WatchUi.loadResource($.Rez.JsonData.secondDisplayOptions) as Array;
    secondHandOptions =
      WatchUi.loadResource($.Rez.JsonData.secondHandOptions) as Array;
    dawnDuskOptions =
      WatchUi.loadResource($.Rez.JsonData.dawnDuskOptions) as Array;

    var OptionsLabels_man =
      WatchUi.loadResource($.Rez.JsonData.OptionsLabels_man) as Array;

    Menu2.initialize({ :title => OptionsLabels_man[0] });
    //var menu = new $.ElegantAnaSettingsMenu();
    //boolean = Storage.getValue("Second Hand On") ? true : false;
    //Menu2.addItem(new WatchUi.ToggleMenuItem("Second Hand: Off-On", null, "Second Hand On", boolean, null));

    //boolean = Storage.getValue("Infinite Second") ? true : false;
    //Menu2.addItem(new WatchUi.ToggleMenuItem("Second Hand after sleep: 2mins-Infinite", null, "Infinite Second", boolean, null));

    //if ($.Options_Dict[infiniteSecondOption] == null) { $.Options_Dict[infiniteSecondOption] = $.infiniteSecondOptions_default; }
    Menu2.addItem(
      new WatchUi.MenuItem(
        OptionsLabels_man[1],
        $.infiniteSecondOptions[$.Options_Dict[infiniteSecondOption]],
        infiniteSecondOption,
        {}
      )
    );

    //var boolean = Storage.getValue("Long Second") ? true : false;
    //Menu2.addItem(new WatchUi.ToggleMenuItem("Second Hand Length: Short-Long", null, "Long Second", boolean, null));

    //if ($.Options_Dict[secondDisplay] == null) { $.Options_Dict[secondDisplay] = $.secondDisplayOptions_default; }
    Menu2.addItem(
      new WatchUi.MenuItem(
        OptionsLabels_man[2],
        $.secondDisplayOptions[$.Options_Dict[secondDisplay]],
        secondDisplay,
        {}
      )
    );

    //if ($.Options_Dict[secondHandOption] == null) { $.Options_Dict[secondHandOption] = $.secondHandOptions_default; }
    Menu2.addItem(
      new WatchUi.MenuItem(
        OptionsLabels_man[3],
        $.secondHandOptions[$.Options_Dict[secondHandOption]],
        secondHandOption,
        {}
      )
    );

    //if ($.Options_Dict[dawnDuskMarkers] == null) { $.Options_Dict[dawnDuskMarkers] = $.dawnDuskOptions_default; }
    Menu2.addItem(
      new WatchUi.MenuItem(
        OptionsLabels_man[4],
        $.dawnDuskOptions[$.Options_Dict[dawnDuskMarkers]],
        dawnDuskMarkers,
        {}
      )
    );

    //boolean = Storage.getValue("Wide Second") ? true : false;
    //Menu2.addItem(new WatchUi.ToggleMenuItem("Second Hand Size: Narrow-Wide", null, "Wide Second", boolean, null));

    /*

        var boolean = Storage.getValue("Show Battery") ? true : false;
        Menu2.addItem(new WatchUi.ToggleMenuItem("Show Battery %: No-Yes", null, "Show Battery", boolean, null));

        boolean = Storage.getValue("Show Minutes") ? true : false;
        Menu2.addItem(new WatchUi.ToggleMenuItem("Show Wkly Activity Minutes: No-Yes", null, "Show Minutes", boolean, null));

        boolean = Storage.getValue("Show Day Minutes") ? true : false;
        Menu2.addItem(new WatchUi.ToggleMenuItem("Show Daily Activity Minutes: No-Yes", null, "Show Day Minutes", boolean, null));

        boolean = Storage.getValue("Show Steps") ? true : false;
        Menu2.addItem(new WatchUi.ToggleMenuItem("Show Daily Steps: No-Yes", null, "Show Steps", boolean, null));

        boolean = Storage.getValue("Show Move") ? true : false;
        Menu2.addItem(new WatchUi.ToggleMenuItem("Show Move Bar: No-Yes", null, "Show Move", boolean, null));


        boolean = Storage.getValue("Show Date") ? true : false;
        Menu2.addItem(new WatchUi.ToggleMenuItem("Show Date: No-Yes", null, "Show Date", boolean, null));

        boolean = Storage.getValue("Show Month/Day") ? true : false;
        Menu2.addItem(new WatchUi.ToggleMenuItem("Show Day of Week or Month", null, "Show Month/Day", boolean, null));



        boolean = Storage.getValue("Hour Numbers") ? true : false;
        Menu2.addItem(new WatchUi.ToggleMenuItem("Hour Numbers: Off-On", null, "Hour Numbers", boolean, null));

        boolean = Storage.getValue("Hour Hashes") ? true : false;
        Menu2.addItem(new WatchUi.ToggleMenuItem("Hour Hashes: Off-On", null, "Hour Hashes", boolean, null));

        boolean = Storage.getValue("Second Hashes") ? true : false;
        Menu2.addItem(new WatchUi.ToggleMenuItem("Second Hashes: Off-On", null, "Second Hashes", boolean, null));

        boolean = Storage.getValue("Aggressive Clear") ? true : false;
        Menu2.addItem(new WatchUi.ToggleMenuItem("Aggressive Screen Clear?", null, "Aggressive Clear", boolean, null));

        */

    var OptionsLabels =
      WatchUi.loadResource($.Rez.JsonData.OptionsLabels) as Array;

    for (var i = 4; i < numOptions; i++) {
      Menu2.addItem(
        new WatchUi.ToggleMenuItem(
          OptionsLabels[i - 4],
          null,
          Options[i],
          $.Options_Dict[Options[i]] == true,
          null
        )
      );
    }
  }
}

//! Input handler for the app settings menu
class ElegantAnaSettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
  var mainView;
  //! Constructor
  public function initialize() {
    Menu2InputDelegate.initialize();
    mainView = $.ElegantAnaView;
  }

  //! Handle a menu item being selected
  //! @param menuItem The menu item selected
  public function onSelect(menuItem as MenuItem) as Void {
    if (menuItem instanceof ToggleMenuItem) {
      Storage.setValue(menuItem.getId() as String, menuItem.isEnabled());
      $.Options_Dict[menuItem.getId() as String] = menuItem.isEnabled();
      $.Settings_ran = true;
    }

    var id = menuItem.getId();
    if (id.equals(infiniteSecondOption)) {
      $.Options_Dict[id] =
        ($.Options_Dict[id] + 1) % infiniteSecondOptions.size();
      menuItem.setSubLabel($.infiniteSecondOptions[$.Options_Dict[id]]);

      Storage.setValue(id as String, $.Options_Dict[id]);
      $.Settings_ran = true;
      //MySettings.writeKey(MySettings.backgroundKey,MySettings.backgroundIdx);
      //MySettings.background=MySettings.getColor(null,null,null,MySettings.backgroundIdx);
    }

    if (id.equals(secondDisplay)) {
      $.Options_Dict[id] =
        ($.Options_Dict[id] + 1) % secondDisplayOptions.size();
      menuItem.setSubLabel($.secondDisplayOptions[$.Options_Dict[id]]);

      Storage.setValue(id as String, $.Options_Dict[id]);
      $.Settings_ran = true;
      //MySettings.writeKey(MySettings.backgroundKey,MySettings.backgroundIdx);
      //MySettings.background=MySettings.getColor(null,null,null,MySettings.backgroundIdx);
    }

    if (id.equals(secondHandOption)) {
      $.Options_Dict[id] = ($.Options_Dict[id] + 1) % secondHandOptions.size();
      menuItem.setSubLabel($.secondHandOptions[$.Options_Dict[id]]);

      Storage.setValue(id as String, $.Options_Dict[id]);
      $.Settings_ran = true;
      //MySettings.writeKey(MySettings.backgroundKey,MySettings.backgroundIdx);
      //MySettings.background=MySettings.getColor(null,null,null,MySettings.backgroundIdx);
    }

    if (id.equals(dawnDuskMarkers)) {
      $.Options_Dict[id] = ($.Options_Dict[id] + 1) % dawnDuskOptions.size();
      menuItem.setSubLabel($.dawnDuskOptions[$.Options_Dict[id]]);

      Storage.setValue(id as String, $.Options_Dict[id]);
      $.Settings_ran = true;
      //MySettings.writeKey(MySettings.backgroundKey,MySettings.backgroundIdx);
      //MySettings.background=MySettings.getColor(null,null,null,MySettings.backgroundIdx);
    }
  }

  function onBack() {
    System.println("onBack");
    infiniteSecondOptions = null;
    secondDisplayOptions = null;
    secondHandOptions = null;
    dawnDuskOptions = null;
    WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    return false;
  }
}
