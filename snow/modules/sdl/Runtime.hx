package snow.modules.sdl;

import snow.api.Debug.*;
import snow.types.Types;
import sdl.SDL;

@:allow(snow.Snow)
class Runtime extends snow.runtime.Native {

    function new(_app:snow.Snow) {

        super(_app);
        name = 'sdl';

        app.config.runtime = {
            audio_buffer_length : 176400,
            audio_buffer_count : 4
        }

    } //new

    override function run() {

        log('runtime / sdl / run');
        var input = app.input;

        // while(!app.shutting_down) {

            while(SDL.hasAnEvent()) {

                var e = SDL.pollEvent();

                handle_input_ev(e);
                handle_window_ev(e);
                
                if(e.type == SDL_QUIT) {
                    app.onevent({ type:SystemEventType.quit });
                }

            } //SDL has event

            app.onevent({ type:SystemEventType.update });

        // } //!shutting down
        

    } //run

    override function shutdown() {

        log('runtime / sdl / shutdown');

    } //shutdown



//Window
    
    function handle_window_ev(e:sdl.Event) {

        if(e.type == SDL_WINDOWEVENT) {
            var _type:WindowEventType = WindowEventType.unknown;
            switch(e.window.event) {
                case SDL_WINDOWEVENT_SHOWN:
                    _type = WindowEventType.shown;
                case SDL_WINDOWEVENT_HIDDEN:
                    _type = WindowEventType.hidden;
                case SDL_WINDOWEVENT_EXPOSED:
                    _type = WindowEventType.exposed;
                case SDL_WINDOWEVENT_MOVED:
                    _type = WindowEventType.moved;
                case SDL_WINDOWEVENT_RESIZED:
                    _type = WindowEventType.resized;
                case SDL_WINDOWEVENT_SIZE_CHANGED:
                    _type = WindowEventType.size_changed;
                case SDL_WINDOWEVENT_MINIMIZED:
                    _type = WindowEventType.minimized;
                case SDL_WINDOWEVENT_MAXIMIZED:
                    _type = WindowEventType.maximized;
                case SDL_WINDOWEVENT_RESTORED:
                    _type = WindowEventType.restored;
                case SDL_WINDOWEVENT_ENTER:
                    _type = WindowEventType.enter;
                case SDL_WINDOWEVENT_LEAVE:
                    _type = WindowEventType.leave;
                case SDL_WINDOWEVENT_FOCUS_GAINED:
                    _type = WindowEventType.focus_gained;
                case SDL_WINDOWEVENT_FOCUS_LOST:
                    _type = WindowEventType.focus_lost;
                case SDL_WINDOWEVENT_CLOSE:
                    _type = WindowEventType.close;
                case SDL_WINDOWEVENT_NONE:
            } //switch

            if(_type != unknown) {
                app.onevent({
                    type:window, 
                    window:{
                        type: _type,
                        timestamp: e.window.timestamp/1000.0,
                        window_id: (cast e.window.windowID:Int),
                        data1: e.window.data1, 
                        data2: e.window.data2
                    }
                }); //onevent
            }
        }

    } //handle_window_ev

//Input
    
    function handle_input_ev(e:sdl.Event) {

        switch(e.type) {

            //keys

                case SDL_KEYDOWN:
                    app.input.dispatch_key_down_event(
                        e.key.keysym.sym,
                        e.key.keysym.scancode,
                        e.key.repeat,
                        to_key_mod(e.key.keysym.mod),
                        e.key.timestamp/1000.0,
                        cast e.key.windowID
                    );
                case SDL_KEYUP:
                    app.input.dispatch_key_up_event(
                        e.key.keysym.sym,
                        e.key.keysym.scancode,
                        e.key.repeat,
                        to_key_mod(e.key.keysym.mod),
                        e.key.timestamp/1000.0,
                        cast e.key.windowID
                    );
                case SDL_TEXTEDITING:
                    app.input.dispatch_text_event(
                        e.edit.text,
                        e.edit.start,
                        e.edit.length,
                        TextEventType.edit,
                        e.edit.timestamp/1000.0,
                        cast e.edit.windowID
                    );
                case SDL_TEXTINPUT:
                    app.input.dispatch_text_event(
                        e.text.text,
                        0,
                        0,
                        TextEventType.input,
                        e.text.timestamp/1000.0,
                        cast e.text.windowID
                    );

            //mouse

                case SDL_MOUSEMOTION:
                    app.input.dispatch_mouse_move_event(
                        e.motion.x,
                        e.motion.y,
                        e.motion.xrel,
                        e.motion.yrel,
                        e.motion.timestamp/1000.0,
                        cast e.motion.windowID
                    );
                case SDL_MOUSEBUTTONDOWN:
                    app.input.dispatch_mouse_down_event(
                        e.button.x,
                        e.button.y,
                        e.button.button,
                        e.button.timestamp/1000.0,
                        cast e.button.windowID
                    );
                case SDL_MOUSEBUTTONUP:
                    app.input.dispatch_mouse_up_event(
                        e.button.x,
                        e.button.y,
                        e.button.button,
                        e.button.timestamp/1000.0,
                        cast e.button.windowID
                    );
                case SDL_MOUSEWHEEL:
                    app.input.dispatch_mouse_wheel_event(
                        e.wheel.x,
                        e.wheel.y,
                        e.wheel.timestamp/1000.0,
                        cast e.wheel.windowID
                    );

            //touch

                case SDL_FINGERDOWN:
                    app.input.dispatch_touch_down_event(
                        e.tfinger.x,
                        e.tfinger.y,
                        cast e.tfinger.touchId,
                        e.tfinger.timestamp/1000.0
                    );
                case SDL_FINGERUP:
                    app.input.dispatch_touch_up_event(
                        e.tfinger.x,
                        e.tfinger.y,
                        cast e.tfinger.touchId,
                        e.tfinger.timestamp/1000.0
                    );
                case SDL_FINGERMOTION:
                    app.input.dispatch_touch_move_event(
                        e.tfinger.x,
                        e.tfinger.y,
                        e.tfinger.dx,
                        e.tfinger.dy,
                        cast e.tfinger.touchId,
                        e.tfinger.timestamp/1000.0
                    );

            //joystick:todo:
            //gamepad

                case SDL_CONTROLLERAXISMOTION:
                     //(range: -32768 to 32767)
                    var _val:Float = (e.caxis.value+32768)/(32767+32768);
                    var _normalized_val = (-0.5 + _val) * 2.0;
                    app.input.dispatch_gamepad_axis_event(
                        e.caxis.which,
                        e.caxis.axis,
                        _normalized_val,
                        e.caxis.timestamp/1000.0
                    );
                case SDL_CONTROLLERBUTTONDOWN:
                    app.input.dispatch_gamepad_button_down_event(
                        e.cbutton.which,
                        e.cbutton.button,
                        1,
                        e.cbutton.timestamp/1000.0
                    );
                case SDL_CONTROLLERBUTTONUP:
                    app.input.dispatch_gamepad_button_up_event(
                        e.cbutton.which,
                        e.cbutton.button,
                        0,
                        e.cbutton.timestamp/1000.0
                    );
                case SDL_CONTROLLERDEVICEADDED:
                    app.input.dispatch_gamepad_device_event(
                        e.cdevice.which,
                        SDL.gameControllerNameForIndex(e.cdevice.which),
                        GamepadDeviceEventType.device_added,
                        e.cdevice.timestamp/1000.0
                    );
                case SDL_CONTROLLERDEVICEREMOVED:
                    app.input.dispatch_gamepad_device_event(
                        e.cdevice.which,
                        SDL.gameControllerNameForIndex(e.cdevice.which),
                        GamepadDeviceEventType.device_removed,
                        e.cdevice.timestamp/1000.0
                    );
                case SDL_CONTROLLERDEVICEREMAPPED:
                    app.input.dispatch_gamepad_device_event(
                        e.cdevice.which,
                        SDL.gameControllerNameForIndex(e.cdevice.which),
                        GamepadDeviceEventType.device_remapped,
                        e.cdevice.timestamp/1000.0
                    );
                case _:

        } //switch

    } //handle_input_ev

    /** Helper to return a `ModState` (shift, ctrl etc) from a given `InputEvent` */
    function to_key_mod( mod_value:Int ) : ModState {

        return {

            none    : mod_value == KMOD_NONE,

            lshift  : mod_value == KMOD_LSHIFT,
            rshift  : mod_value == KMOD_RSHIFT,
            lctrl   : mod_value == KMOD_LCTRL,
            rctrl   : mod_value == KMOD_RCTRL,
            lalt    : mod_value == KMOD_LALT,
            ralt    : mod_value == KMOD_RALT,
            lmeta   : mod_value == KMOD_LGUI,
            rmeta   : mod_value == KMOD_RGUI,

            num     : mod_value == KMOD_NUM,
            caps    : mod_value == KMOD_CAPS,
            mode    : mod_value == KMOD_MODE,

            ctrl    : mod_value == KMOD_CTRL,
            shift   : mod_value == KMOD_SHIFT,
            alt     : mod_value == KMOD_ALT,
            meta    : mod_value == KMOD_GUI

        };

    } //to_key_mod

    function empty_key_mod() {
        return {
            none:true,
            lshift:false,   rshift:false,
            lctrl:false,    rctrl:false,
            lalt:false,     ralt:false,
            lmeta:false,    rmeta:false,
            num:false,      caps:false,     mode:false,
            ctrl:false,     shift:false,    alt:false,  meta:false
        };
    }




} //Runtime


typedef RuntimeConfig = {

        /** The default length of a single stream buffer in bytes. default:176400, This is ~1 sec in 16 bit mono. */
    @:optional var audio_buffer_length : Int;

        /** The default number of audio buffers to use for a single stream. Set no less than 2, as it's a queue. See `Audio` docs. default:4 */
    @:optional var audio_buffer_count : Int;

}