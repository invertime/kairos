/*
* Copyright (c) 2022 Fyra Labs
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

[GtkTemplate (ui = "/com/fyralabs/Kairos/weatherpage.ui")]
public class Kairos.WeatherPage : He.Bin {
    private string color_primary = "";
    private string color_secondary = "";
    private string graphic = "";

    public Bis.Carousel car {get; set;}
    public GWeather.Info weather_info;
    public GWeather.Location location {get; construct;}
    public MainWindow win {get; construct;}
    public string dew {get; set;}
    public string pressure {get; set;}
    public string temphilo {get; set;}
    public string wind {get; set;}

    private const int ONE_HOUR = 60 * 60 * 1000 * 1000;
    private const int TWENTY_FOUR_HOURS = 24 * ONE_HOUR;

    private GLib.SList<weak GWeather.Info> hourly_info = new GLib.SList<weak GWeather.Info> ();
    private bool has_forecast_info = false;

    [GtkChild]
    unowned Gtk.Image weather_icon;
    [GtkChild]
    unowned Gtk.Label weather_label;
    [GtkChild]
    unowned Gtk.Label temp_label;
    [GtkChild]
    unowned Gtk.Label kudos_label;
    [GtkChild]
    unowned Gtk.Box timeline;
    [GtkChild]
    unowned Gtk.Box humidity_timeline;
    [GtkChild]
    unowned Gtk.Box graph;
    [GtkChild]
    unowned He.DisclosureButton refresh_button;

    public WeatherPage (MainWindow win, GWeather.Location location) {
        Object (
            win: win,
            location: location
        );
    }

    construct {
        this.add_css_class ("window-bg");
        win.add_css_class ("side-window-bg");
        refresh_button.add_css_class ("block-button");
        win.menu_button.add_css_class ("block-button");
        win.listbox2.add_css_class ("block-row");
        win.sidebar.add_css_class ("block-sidebar");

        weather_info = new GWeather.Info (location);
        weather_info.set_contact_info ("https://raw.githubusercontent.com/tau-OS/kairos/main/com.fyralabs.Kairos.doap");
        weather_info.set_enabled_providers (GWeather.Provider.METAR | GWeather.Provider.MET_NO | GWeather.Provider.OWM);

        set_info (location);
        weather_info.update ();
        set_style (location);

        refresh_button.clicked.connect (() => {
            set_info (location);
            set_style (location);
            update_timeline (weather_info);
            weather_info.update ();
        });

        weather_info.updated.connect (() => {
            set_info (location);
            update_timeline (weather_info);
            weather_info.update ();
        });

        car = win.carousel;
        car.page_changed.connect ((page) => {
            set_info (location);
            set_style (location);
            update_timeline (weather_info);
            weather_info.update ();
        });

        has_forecast_info = false;
    }

    public GLib.SList<GWeather.Info> preprocess (
                                                 GLib.DateTime now,
                                                 GWeather.Info forecast_info,
                                                 GLib.SList<weak GWeather.Info> infos
    ) {
        GLib.SList<GWeather.Info> combo_info = new GLib.SList<GWeather.Info> ();
        combo_info.append (forecast_info);
        foreach (var ib in infos) {
            combo_info.append (ib);
        }
        return combo_info;
    }
    public void add_hour_entry (GWeather.Info info, bool now) {
        string time_label; string time_format;
        long date; info.get_value_update (out date);
        var datetime = new GLib.DateTime.from_unix_utc (date).to_local ();

        if (now) {
            time_label = _("Now");
        } else {
            time_format = "%R";
            time_label = datetime.format (time_format);
        }

        var entry = new WeatherRow (info, time_label);
        timeline.append (entry);
    }
    public void add_humidity_entry (GWeather.Info info, bool now) {
        string time_label; string time_format;
        long date; info.get_value_update (out date);
        var datetime = new GLib.DateTime.from_unix_utc (date).to_local ();

        if (now) {
            time_label = _("Now");
        } else {
            time_format = "%R";
            time_label = datetime.format (time_format);
        }

        var entry = new WeatherHumidityRow (info, time_label);
        humidity_timeline.append (entry);
    }
    public void add_graph (GLib.SList<GWeather.Info> hourlyinfo) {
        var entry = new WeatherGraph (hourlyinfo);
        graph.prepend (entry);
    }
    public void update_timeline (GWeather.Info info) {
        var forecasts = info.get_forecast_list ().copy ();
        var now = new GLib.DateTime.now_local ();

        GLib.SList<GWeather.Info> hourlyinfo = preprocess (now, info, forecasts);
        uint length = hourlyinfo.length ();
        if (length > 1 && has_forecast_info == false) {
            for (var i = 0; i <= 24; i++) {
                var inf = hourlyinfo.nth (i).data;
                var is_now = hourlyinfo.index (inf) == 1;
                if (hourlyinfo.index (inf) > 0)
                    add_hour_entry (inf, is_now);
                    has_forecast_info = true;
                    add_humidity_entry (inf, is_now);
                    has_forecast_info = true;
            }
            add_graph (hourlyinfo);
            has_forecast_info = true;
        }

        this.hourly_info = hourlyinfo.copy ();
    }

    public void set_info (GWeather.Location? loc) {
        if (loc == null) {
            return;
        }

        weather_icon.icon_name = weather_info.get_symbolic_icon_name ().replace ("-symbolic", "");
        weather_label.label = dgettext ("libgweather", weather_info.get_sky ());

        temp_label.label = _("%s").printf (weather_info.get_temp_summary ());

        temphilo = weather_info.get_temp_summary ();

        wind = "%s".printf (weather_info.get_wind ());
        dew = "%s".printf (weather_info.get_dew ());
        pressure = _("%s").printf (weather_info.get_pressure ());

        kudos_label.label = weather_info.get_attribution ();
    }

    public void set_style (GWeather.Location? loc) {
        var provider = new Gtk.CssProvider ();
        switch (weather_info.get_symbolic_icon_name ()) {
            case "weather-clear-night-symbolic":
            case "weather-few-clouds-night-symbolic":
                color_primary = "#2d2d2d";
                color_secondary = "#fafafa";
                graphic = "resource://com/fyralabs/Kairos/night.svg";
                break;
            case "weather-few-clouds-symbolic":
            case "weather-overcast-symbolic":
            case "weather-fog-symbolic":
                color_primary = "#828282";
                color_secondary = "#fafafa";
                graphic = "resource://com/fyralabs/Kairos/cloudy.svg";
                break;
            case "weather-showers-symbolic":
            case "weather-showers-scattered-symbolic":
            case "weather-storm-symbolic":
                color_primary = "#828282";
                color_secondary = "#fafafa";
                graphic = "resource://com/fyralabs/Kairos/rain.svg";
                break;
            case "weather-snow-symbolic":
                color_primary = "#efefef";
                color_secondary = "#2d2d2d";
                graphic = "resource://com/fyralabs/Kairos/snow.svg";
                break;
            case "weather-clear-symbolic":
                color_primary = "#268ef9";
                color_secondary = "#fafafa";
                graphic = "resource://com/fyralabs/Kairos/sunny.svg";
                break;
            default:
                color_primary = "#fafafa";
                color_secondary = "#2d2d2d";
                graphic = "";
                break;
        }

        string css = """
        @define-color color_primary %s;
        @define-color color_secondary %s;

        .window-bg {
            background-image: url(%s), linear-gradient(0deg, @color_primary, mix(black, @color_primary, 0.88) 50%, @color_primary);
            background-position: center;
            background-repeat: repeat;
            background-size: cover;
            color: @color_secondary;
            transition: all 600ms ease-in-out;
        }
        """.printf(color_primary,color_secondary, graphic);
        provider.load_from_data (css.data);
        this.get_style_context().add_provider_for_display (win.get_display (), provider, 999);
    }

    [GtkCallback]
    string get_wind_label () {
        return wind;
    }
    [GtkCallback]
    string get_dew_label () {
        return dew;
    }
    [GtkCallback]
    string get_temphilo_label () {
        return (_("Feels like ")) + temphilo;
    }
    [GtkCallback]
    string get_pressure_label () {
        return pressure;
    }
}
