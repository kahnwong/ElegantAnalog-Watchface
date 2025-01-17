//
// Copyright 2016-2021 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables
// Application Developer Agreement.
//

import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.WatchUi;

//! This app demonstrates a basic analog watch face. It also shows
//! a new page when a goal is met and has an app settings menu.
class AnalogWatch extends Application.AppBase {

    var mainView;

    //! Constructor
    public function initialize() {
        System.println("0A");
        AppBase.initialize();
        System.println("1A");
    }

    
    //! Handle app startup
    //! @param state Startup arguments
    public function onStart(state as Dictionary?) as Void {
        System.println("2A");
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
        System.println("4A");
        if (WatchUi has :WatchFaceDelegate) {
            var view = new $.AnalogView();
            mainView = view;
            var delegate = new $.AnalogDelegate(view);
            //var delegate2 = new $.AnalogInputDelegate(view);
            return [view, delegate];
        } else {
            return [new $.AnalogView()];
        }
    }

    
    //! This method runs when a goal is triggered and the goal view is started.
    //! @param goal The goal type that triggered
    //! @return The view to push
    //public function getGoalView(goal as GoalType) as [View]? {
    //    //System.println("5A");
    //    return [new $.AnalogGoalView(goal)];
    //}

    //! Return the settings view and delegate
    //! @return Array Pair [View, Delegate]
    public function getSettingsView() as [Views] or [Views, InputDelegates] or Null {
        System.println("6A");
        return [new $.AnalogSettingsMenu(), new $.AnalogSettingsMenuDelegate()];
    }

}
