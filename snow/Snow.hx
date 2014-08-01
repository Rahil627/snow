package snow;


import snow.App;
import snow.types.Types;
import snow.utils.ByteArray;
import snow.utils.Timer;

import snow.assets.Assets;
import snow.input.Input;
import snow.audio.Audio;
import snow.window.Windowing;
import snow.window.Window;

    //the platform core bindings
import snow.Core;

class Snow {

//Property accessors

        /** The current timestamp */
    public var time (get,never) : Float;
        /** Generate a unique ID to use */
    public var uniqueid (get,never) : String;


//State management

        /** The host application */
    public var host : App;
        /** The application configuration specifics (like window, runtime, and asset lists) */
    public var config : AppConfig;
        /** The configuration for snow itself, set via build project flags */
    public var snow_config : SnowConfig;

//Sub systems

        /** The window manager */
    public var windowing : Windowing;
        /** The input system */
    public var input : Input;
        /** The audio system */
    public var audio : Audio;
        /** The asset system */
    public var assets : Assets;

        /** Set if shut down has commenced */
    public var shutting_down : Bool = false;
        /** Set if shut dow has completed  */
    public var has_shutdown : Bool = false;
        /** If the config specifies a default window, this is it */
    public var window : Window;

//Internal values

        //if already passed the ready state
    var was_ready : Bool = false;
        //if ready has completed, so systems can begin safely
    var is_ready : Bool = false;
        //the core platform instance to bind us
    @:noCompletion public static var core : Core;

    @:noCompletion public function new() {

            //We create the core as a concrete platform version of the core
        core = new Core( this );

    } //new

//Internal API

    @:noCompletion public function init( _snow_config:SnowConfig, _host : App ) {

        snow_config = _snow_config;

        config = {
            has_window : true,
            runtime : {},
            window : null,
            assets : [],
            web : {
                no_context_menu : true
            },
            native : {
                audio_buffer_length : 176400,
                audio_buffer_count : 4
            }
        };

        host = _host;
        host.app = this;

        core.init( on_event );

    } //init

        /** Shutdown the engine and quit */
    public function shutdown() {

        shutting_down = true;

        host.destroyed();
        audio.destroy();
        input.destroy();
        windowing.destroy();

        core.shutdown();

        has_shutdown = true;

    } //shutdown

    function get_time() : Float {

        return core.timestamp();

    } //time getter

    function on_snow_init() {

        _debug('/ snow / initializing - ', true);

            //ensure that we are in the correct location for asset loading

        #if snow_native

            var app_path = core.app_path();

            _debug('/ snow / setting up app path ${app_path}', true);

            Sys.setCwd( app_path );

            #if !mobile
                _debug('/ snow / setting up pref path', true);
                core.pref_path('snow','default');
            #end //mobile

        #end //snow_native

        _debug('/ snow / pre ready, init host', true);

            //any app pre ready init can be handled in here
        host.on_internal_init();

    } //on_snow_init

    function on_snow_ready() {

        if(was_ready) {
            _debug("/ snow / firing ready event repeatedly is not ideal...");
            return;
        }


        _debug('/ snow / ready, setting up additional systems...');


                //create the sub systems
            windowing = new Windowing( this );
            input = new Input( this );
            audio = new Audio( this );
            assets = new Assets( this );


        if(!snow_config.config_custom_assets){

                //load the correct asset path from the snow config
            assets.manifest_path = snow_config.config_assets_path;

                //
            _debug('/ snow / fetching asset list "${assets.manifest_path}"' , true);

                //we fetch the a list from the manifest
            config.assets = default_asset_list();
                //then we add the list for the asset manager
            assets.add( config.assets );

        } //custom assets

        if(!snow_config.config_custom_runtime) {
                //fetch from a config file, the custom
            config.runtime = default_runtime_config();
        }

        config.window = default_window_config();

        _debug('/ snow / fetching user config', true);

            //request config changes, if any
        config = host.config( config );

            //disllow re-entry
        was_ready = true;

        _debug('/ snow / creating default window', true);

            //now if they requested a window, let's open one
        if(config.has_window == true) {

            window = windowing.create( config.window );

                //failed to create?
            if(window.handle == null) {
                throw "/ snow / requested default window cannot be created. Cannot continue.";
            }

        } //has_window

            //now ready
        is_ready = true;

            //tell the host app we are done
        host.ready();

    } //on_snow_ready

    @:noCompletion public function do_internal_update( dt:Float ) {

        input.update();
        audio.update();
        host.update( dt );

    } //do_internal_update

        /** Called for you by snow, unless configured otherwise. Only call this manually if your render_rate is 0! */
    public function render() {

        windowing.update();

    } //render

    function on_snow_update() {

        if(!is_ready) {
            return;
        }

            //first update timers
        Timer.update();

            //handle any internal updates
        host.on_internal_update();

    } //on_snow_update

    public function dispatch_system_event( _event:SystemEvent ) {

        on_event(_event);

    } //dispatch_system_event

    function on_event( _event:SystemEvent ) {

        if(Std.is(_event.type, Int)) {
            _event.type = SystemEvents.typed( cast _event.type );
        }

        if( _event.type != SystemEventType.update &&
            _event.type != SystemEventType.unknown &&
            _event.type != SystemEventType.window &&
            _event.type != SystemEventType.input

        ) {
            trace( "/ snow / system event : " + _event );
        }

            //all systems should get these basically...
            //cos of app lifecycles etc being here.
        if(is_ready) {
            audio.on_event( _event );
            windowing.on_event( _event );
            input.on_event( _event );
            host.on_event( _event );
        }

        switch(_event.type) {

            case SystemEventType.init: {
                on_snow_init();
            } //init

            case SystemEventType.ready: {
                on_snow_ready();
            } //ready

            case SystemEventType.update: {
                on_snow_update();
            } //update

            case SystemEventType.quit, SystemEventType.app_terminating: {
                shutdown();
            } //quit

            case SystemEventType.shutdown: {
                _debug('/ snow / Goodbye.');
            } //shutdown

            default: {

            } //default

        } //switch _event.type

    } //on_event



        /** handles the default method of parsing a runtime config json,
            To change this behavior override `get_runtime_config`. This is called by default in get_runtime_config. */
    function default_runtime_config() : Dynamic {

            //we want to load the runtime config from a json file by default
        var config_data = assets.text( snow_config.config_runtime_path );

            //only care if there is a config
        if(config_data != null && config_data.text != null) {

            try {

                var json = haxe.Json.parse( config_data.text );

                trace('/ snow / config / ok / default runtime config');

                return json;

            } catch(e:Dynamic) {

                trace('/ snow / config / failed / default runtime config failed to parse as JSON. cannot recover.');
                throw e;

            }
        }

        return {};

    } //default_runtime_config

        /** handles the default method of parsing the file manifest list as json, stored in an array and returned. */
    function default_asset_list() : Array<AssetInfo> {

        var asset_list : Array<AssetInfo> = [];
        var manifest_data = ByteArray.readFile( assets.assets_root + assets.manifest_path, false );

        if(manifest_data != null && manifest_data.length != 0) {

                var _list:Array<String> = haxe.Json.parse(manifest_data.toString());

                for(asset in _list) {

                    asset_list.push({
                        id : asset,
                        path : haxe.io.Path.join([assets.assets_root, asset]),
                        type : haxe.io.Path.extension(asset),
                        ext : haxe.io.Path.extension(asset)
                    });

                } //for each asset

            trace('/ snow / config / ok / default asset manifest');

        } else { //manifest_data != null

            trace('/ snow / config / failed / default asset manifest not found, or length was zero');

        }

        return asset_list;

    } //default_asset_list


        /** returns a default configured window config */
    function default_window_config() : WindowConfig {

        return {

            #if mobile
                fullscreen : true,
            #else
                fullscreen : false,
            #end

            resizable : true,
            borderless : false,
            antialiasing : 0,
            stencil_bits : 0,
            depth_bits : 0,

            x               : 0x1FFF0000,
            y               : 0x1FFF0000,
            width           : 960,
            height          : 640,
            title           : "snow app"

        };

    } //default_window_config


//Helpers

    function get_uniqueid() : String {

        return haxe.crypto.Md5.encode( Std.string( time * Math.random() ));

    } //uniqueid

        /** Loads a function out of a library */
    public static function load( library:String, method:String, args:Int = 0 ) : Dynamic {

        return snow.utils.Libs.load( library, method, args );

    } //load

//Debug helpers

    // #if debug

        @:noCompletion public var log : Bool = true;
        @:noCompletion public var verbose : Bool = true;
        @:noCompletion public var more_verbose : Bool = false;
        @:noCompletion public function _debug(value:Dynamic, _verbose:Bool = false, _more_verbose:Bool = false) {
            if(log) {
                if(verbose && _verbose && !_more_verbose) {
                    trace(value);
                } else
                if(more_verbose && _more_verbose) {
                    trace(value);
                } else {
                    if(!_verbose && !_more_verbose) {
                        trace(value);
                    }
                } //elses
            } //log
        } //_debug

    // #end //debug

} //Snow

