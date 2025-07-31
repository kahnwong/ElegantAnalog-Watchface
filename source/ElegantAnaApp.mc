//
// Copyright 2016-2021 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables
// Application Developer Agreement.
//

import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.WatchUi;

//! This app demonstrates a basicElegantAna watch face. It also shows
//! a new page when a goal is met and has an app settings menu.
class ElegantAnaWatch extends Application.AppBase {
  var mainView;

  //! Constructor
  public function initialize() {
    //System.println("0A");
    AppBase.initialize();
    //System.println("1A");

    Options = [
      infiniteSecondOption,
      secondDisplay,
      secondHandOption,
      dawnDuskMarkers,

      showBattery,
      showMinutes,

      showDayMinutes,
      showSteps,
      showMove,
      showDate,
      showMonthDay,
      hourNumbers,
      hourHashes,
      secondHashes,
      aggressiveClear,

      showBodyBattery,

      //lastLoc_saved9,
    ];

    numOptions = Options.size();

    defOptions = {
      infiniteSecondOption => 2,
      secondDisplay => 0,
      secondHandOption => 1,
      dawnDuskMarkers => 0,

      showBattery => false,
      showMinutes => false,

      showDayMinutes => false,
      showSteps => false,
      showMove => true,
      showDate => true,
      showMonthDay => false,
      hourNumbers => false,
      hourHashes => true,
      secondHashes => false,
      aggressiveClear => false,

      showBodyBattery => false,

      //lastLoc_saved => [38, -94],
    };

    readStorageValues();
    defOptions = null;
  }

  //! Handle app startup
  //! @param state Startup arguments
  public function onStart(state as Dictionary?) as Void {
    //System.println("2A");
    //Get the stored value of the settings if it exists, OR set to defaul
  }

  //! Handle app shutdown
  //! @param state Shutdown arguments
  public function onStop(state as Dictionary?) as Void {
    //System.println("3A");
  }

  //! Return the initial view for the app
  //! @return Array Pair [View, Delegate] or Array [View]
  public function getInitialView() as [Views] or [Views, InputDelegates] {
    //System.println("4A");
    if (WatchUi has :WatchFaceDelegate) {
      var view = new $.ElegantAnaView();
      mainView = view;
      var delegate = new $.ElegantAnaDelegate(view);
      //var delegate2 = new $.ElegantAnaInputDelegate(view);
      return [view, delegate];
    } else {
      return [new $.ElegantAnaView()];
    }
  }

  //! This method runs when a goal is triggered and the goal view is started.
  //! @param goal The goal type that triggered
  //! @return The view to push
  //public function getGoalView(goal as GoalType) as [View]? {
  //    //System.println("5A");
  //    return [new $.ElegantAnaGoalView(goal)];
  //}

  //! Return the settings view and delegate
  //! @return Array Pair [View, Delegate]
  public function getSettingsView() as [Views] or
    [Views, InputDelegates] or
    Null {
    System.println("6A");
    return [
      new $.ElegantAnaSettingsMenu(),
      new $.ElegantAnaSettingsMenuDelegate(),
    ];
  }
}

public function readStorageValues() as Void {
  if (!(Application has :Storage)) {
    $.Options_Dict = defOptions;
    return;
  }

  var temp;

  for (var i = 0; i < numOptions; i++) {
    temp = Storage.getValue(Options[i]);
    $.Options_Dict[Options[i]] = temp != null ? temp : defOptions[Options[i]];
    Storage.setValue(Options[i], $.Options_Dict[Options[i]]);
  }
}
