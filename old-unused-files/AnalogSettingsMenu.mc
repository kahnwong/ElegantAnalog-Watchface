//
// Copyright 2016-2021 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables
// Application Developer Agreement.
//

import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.WatchUi;

//! The app settings menu
class AnalogSettingsMenu extends WatchUi.Menu2 {

    //! Constructor
    public function initialize() {
        
        var clockTime = System.getClockTime();
        System.println(clockTime.hour +":" + clockTime.min + " - Settings running");

        Menu2.initialize({:title=>"Settings"});
        //var menu = new $.AnalogSettingsMenu();
        //boolean = Storage.getValue("Second Hand On") ? true : false;
        //Menu2.addItem(new WatchUi.ToggleMenuItem("Second Hand: Off-On", null, "Second Hand On", boolean, null));

        //boolean = Storage.getValue("Infinite Second") ? true : false;
        //Menu2.addItem(new WatchUi.ToggleMenuItem("Second Hand after sleep: 2mins-Infinite", null, "Infinite Second", boolean, null));

        if ($.Options_Dict["Infinite Second Option"] == null) { $.Options_Dict["Infinite Second Option"] = $.infiniteSecondOptions_default; }
        Menu2.addItem(new WatchUi.MenuItem("Second Hand Run Time (after wake-up):",
            $.infiniteSecondOptions[$.Options_Dict["Infinite Second Option"]],"Infinite Second Option",{}));

        var boolean = Storage.getValue("Long Second") ? true : false;
        Menu2.addItem(new WatchUi.ToggleMenuItem("Second Hand Length: Short-Long", null, "Long Second", boolean, null));

        boolean = Storage.getValue("Wide Second") ? true : false;
        Menu2.addItem(new WatchUi.ToggleMenuItem("Second Hand Size: Narrow-Wide", null, "Wide Second", boolean, null));                

        boolean = Storage.getValue("Show Move") ? true : false;
        Menu2.addItem(new WatchUi.ToggleMenuItem("Show Move Bar: No-Yes", null, "Show Move", boolean, null));

        boolean = Storage.getValue("Show Battery") ? true : false;
        Menu2.addItem(new WatchUi.ToggleMenuItem("Show Battery %: No-Yes", null, "Show Battery", boolean, null));

        boolean = Storage.getValue("Show Date") ? true : false;
        Menu2.addItem(new WatchUi.ToggleMenuItem("Show Date: No-Yes", null, "Show Date", boolean, null));

        boolean = Storage.getValue("Hour Numbers") ? true : false;
        Menu2.addItem(new WatchUi.ToggleMenuItem("Hour Numbers: Off-On", null, "Hour Numbers", boolean, null));        

        boolean = Storage.getValue("Hour Hashes") ? true : false;
        Menu2.addItem(new WatchUi.ToggleMenuItem("Hour Hashes: Off-On", null, "Hour Hashes", boolean, null));        

        boolean = Storage.getValue("Second Hashes") ? true : false;
        Menu2.addItem(new WatchUi.ToggleMenuItem("Second Hashes: Off-On", null, "Second Hashes", boolean, null));                        
        
    }
}

//! Input handler for the app settings menu
class AnalogSettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    var mainView;
    //! Constructor
    public function initialize() {
        Menu2InputDelegate.initialize();
        mainView = $.AnalogView;
    }

    //! Handle a menu item being selected
    //! @param menuItem The menu item selected
    public function onSelect(menuItem as MenuItem) as Void {
        if (menuItem instanceof ToggleMenuItem) {
            Storage.setValue(menuItem.getId() as String, menuItem.isEnabled());
            $.Options_Dict[menuItem.getId() as String] = menuItem.isEnabled();
            $.Settings_ran = true;
        }

        var id=menuItem.getId();
        if(id.equals("Infinite Second Option")) {
            $.Options_Dict[id]=($.Options_Dict[id]+1)%infiniteSecondOptions_size;
            menuItem.setSubLabel($.infiniteSecondOptions[$.Options_Dict[id]]);

            Storage.setValue(id as String, $.Options_Dict[id]);            
            $.Settings_ran = true;
            //MySettings.writeKey(MySettings.backgroundKey,MySettings.backgroundIdx);
            //MySettings.background=MySettings.getColor(null,null,null,MySettings.backgroundIdx);
        }
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        //return false;
    }
}