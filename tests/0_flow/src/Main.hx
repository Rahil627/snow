
import snow.Snow;

import snow.render.opengl.GL;

import snow.utils.ByteArray;
import snow.utils.UInt8Array;
import snow.utils.Float32Array;

import snow.window.Window;
import snow.input.Input;

import snow.types.Types;
import snow.assets.Assets;
import snow.assets.AssetImage;
import snow.App;

import snow.audio.Sound;

class Main extends snow.AppFixedTimestep {

    var imageUniform:GLUniformLocation;
    var modelViewMatrixUniform:GLUniformLocation;
    var projectionMatrixUniform:GLUniformLocation;
    var shaderProgram:GLProgram;
    var texCoordAttribute:Int;
    var texCoordBuffer:GLBuffer;
    var vertexAttribute:Int;
    var vertexBuffer:GLBuffer;
    var textures: Array<GLTexture>;
    var current_texture : GLTexture = null;
    var tex_index : Int = 0;
    var files : Array<String>;

    var size : Int = 128;
    var texture_time : Float = 1.0;
    var positionX : Float = 0;
    var positionY : Float = 0;
    var dirX : Float = 1;
    var speed : Float = 100;

    var projectionMatrix : Float32Array;
    var modelViewMatrix : Float32Array;

        //sound instances.
        //no need to track these,
        //just testing.
    var sound1 : Sound;
    var sound2 : Sound;
    var sound3 : Sound;
    var sound4 : Sound;
    var sound5 : Sound;

        //left or right pan?
    var left : Bool = false;

    override function config( config:AppConfig ) : AppConfig {

            //here we can change the config.window and config.runtime values
            //before they are used by the framework, i.e verifying the runtime config values
            //and rejecting/updating invalid ones

        if(config.runtime.window != null) {
            if(config.runtime.window.width != null) {
                config.window.width = Std.int(config.runtime.window.width);
            }
            if(config.runtime.window.height != null) {
                config.window.height = Std.int(config.runtime.window.height);
            }
        }

        return config;

    } //config

    override function on_event( _event:SystemEvent ) {

        if(_event.type == SystemEventType.filewatch) {
            var type = FileWatchEvents.typed(cast _event.filewatch.type);
            trace('File watch event type:${type}, path:${_event.filewatch.path} ts:${_event.filewatch.timestamp}');
        }

    } //on_event

    override function ready() {

        trace('/ HOST / ready');

        var r : EReg = ~/world/;
        var str = "hello world";
        trace(r.match(str)); // true : 'world' was found in the string
        trace(r.match("hello !")); // false

        trace("app config is loaded as : " + app.config.runtime );

        if(app.config.runtime.size != null) size = app.config.runtime.size;
        if(app.config.runtime.movespeed != null) speed = app.config.runtime.movespeed;
        if(app.config.runtime.texture_time != null) texture_time = app.config.runtime.texture_time;
        if(app.config.runtime.timescale != null) timescale = app.config.runtime.timescale;

        var dcount : Int = app.windowing.display_count();
        trace('A total of ${dcount} displays were found');
        for(i in 0 ... dcount) {
            var bounds = app.windowing.display_bounds(i);
            var name = app.windowing.display_name(i);
            trace('display ${i}, name: ${name} bounds: ${bounds} modes:' );

                //get list of modes for this display
            var modecount = app.windowing.display_mode_count(i);

            for(j in 0 ... modecount) {
                var mode = app.windowing.display_mode(i,j);
                trace('\t\t ${mode.width} x ${mode.height}  @  ${mode.refresh_rate}hz ');
            }

        }

        trace("desktop native resolution of primary display : " + app.windowing.display_native_mode(0) );

        trace("OpenGL reports version " + GL.versionString());
        trace("OpenGL reports extensions " + GL.getSupportedExtensions());

        initializeShaders();
        createBuffers();

        trace("done with shaders and buffers");

        textures = [];

        files = [
            'assets/test.bmp',
            'assets/test.gif',
            'assets/test.jpg',
            'assets/test.png',
            'assets/test.psd',
            'assets/test.tga',
        ];

        for(f in files) {
            app.assets.image( f, {
                onload:function(asset:AssetImage){
                    if(asset != null) {
                        trace('loaded $f with ${asset.image.width}x${asset.image.height}x${asset.image.bpp} (source bpp:${asset.image.bpp_source}) mem:${asset.image.data.length}');
                        textures.push( createTexture( asset ) );
                        if(current_texture == null) {
                            current_texture = textures[0];
                        }
                    }
                }
            });
        }

            //this is temp testing, just hook into the window render directly
        app.window.onrender = onrender;

        next_tex_tick = texture_time;

        positionY = (app.window.height - size) / 2;

        sound1 = app.audio.create("assets/sound.pcm");
        sound2 = app.audio.create("assets/sound.ogg", 'ogg');
        sound3 = app.audio.create("assets/sound.wav", 'wav');
        sound4 = app.audio.create("assets/music.wav", 'wav_stream', true);
        sound5 = app.audio.create("assets/music.ogg", 'ogg_stream', true);

        trace("sound1 : " + sound1.name);
        trace("sound2 : " + sound2.name);
        trace("sound3 : " + sound3.name);
        trace("sound4 : " + sound4.name);
        trace("sound5 : " + sound5.name);

        // sound4.loop();
        // sound5.loop();


        #if desktop
            app.io.system.watch_add('assets/');
        #end

    } //ready

        //default is true in config
    var vsync = true;
        //default is shown obv
    var cursor = true;

    var window2 : Window;

    override function onkeydown( keycode:Int, _,_,_,_,_ ) {

        // trace("key down : " + event);

            //console scan code should be universally next to 1
        if(keycode == Key.KEY_e) {
            sound1.play();
        }

        if(keycode == Key.KEY_h) {
            if(window2 != null && window2.handle != null) {
                if(window2.closed) {
                    window2.show();
                } else {
                    window2.close();
                }
            }
        }

        if(keycode == Key.KEY_q) {
            left = !left;
            sound2.pan = left ? -1 : 1;
            sound2.play();
        }

        if(keycode == Key.KEY_w) {
            app.audio.pitch('wav', 1.5);
            sound3.play();

            if(window2 != null) {
                window2.destroy();
                window2 = null;
            }

            window2 = app.windowing.create({
                resizable : true,
                width : 200+Std.random(200), height:200+Std.random(200),
                x : 0x1FFF0000, y:0x1FFF0000,
                title:'window ' + app.time
            });
        }

        if(keycode == Key.KEY_p) {
            sound5.toggle();
        }

        if(keycode == Key.KEY_m) {
            cursor = !cursor;
            app.windowing.enable_cursor( cursor );
            trace("cursor enabled : " + cursor );
        }

        if(keycode == Key.KEY_v) {
            vsync = !vsync;
            app.windowing.enable_vsync( vsync );
            trace("vsync enabled : " + vsync );
        }

        if(keycode == Key.KEY_b) {
            var w = app.windowing.create({
                resizable : true, borderless:true,
                width : 200, height:200,
                x : 0x1FFF0000, y:0x1FFF0000,
                title:'window ' + app.time
            });
        }

        if(keycode == Key.KEY_r) {
            sound5.position = 0;
            trace('music reset');
        }

        if(keycode == Key.KEY_u) {
            app.io.url_open("http://snowkit.org/");
        }

        if(keycode == Key.KEY_o) {
            #if desktop
                trace(app.io.system.dialog_open());
                trace(app.io.system.dialog_save());
                trace(app.io.system.dialog_folder());
            #end
        }

        if(keycode == Key.KEY_t) {
            var t = (sound5.duration*0.75);
            sound5.time = t;
            trace('set to ${sound5.duration}*0.75 | music 75% ' + t);
        }

        if(keycode == Key.BACKQUOTE) {
            app.audio.pitch('wav', 0.5);
            sound3.play();
        }

    } //onkeydown

    override function onkeyup( keycode:Int, _,_, mod:ModState, _,_ ) {

        // trace("onkeyup " + event);

            //alt enter to toggle fullscreen test
        if( keycode == Key.RETURN && mod.alt ) {
            app.window.fullscreen = !app.window.fullscreen;
        }

            //ctrl enter to toggle pointer lock test
        if( keycode == Key.RETURN && mod.ctrl ) {
            app.window.grab = !app.window.grab;
        }

        if( keycode == Key.ESCAPE ) {
            app.shutdown();
        }

        if( keycode == Key.KEY_c ) {
            noclamp = !noclamp;
            trace("no clamp: " + noclamp);
        }

    } //onkeyup

    var noclamp : Bool = true;

    override public function ontextinput( text:String, start:Int, length:Int, type:TextEventType, timestamp:Float, window_id:Int ) {
        // trace('text event; text:$text / start: $start / length: $length / type:$type / timestamp:${timestamp} / window: ${window_id}');
    } //ontextinput

    override function ontouchdown( x:Float, y:Float, touch_id:Int, timestamp:Float ) {
        trace('touch down; $x / $y / $touch_id / $timestamp');
    }

    override function ontouchup( x:Float, y:Float, touch_id:Int, timestamp:Float ) {
        trace('touch up; $x / $y / $touch_id / $timestamp');
        sound1.play();

        if(touch_id > 1) {
            app.io.url_open("http://snowkit.org/");
        }
    }

    override function ontouchmove( x:Float, y:Float, dx:Float, dy:Float, touch_id:Int, timestamp:Float ) {

        trace('touch move; $x / $y / $dx / $dy / $touch_id / $timestamp ');

            //touches are in NDC, so we convert to window size
        positionX = (app.window.width*x) - (size/2);
        positionY = (app.window.height*y) - (size/2);
        phys_posx = positionX;

    } //ontouchmove

    override function onmousemove( x:Int, y:Int, xrel:Int, yrel:Int, timestamp:Float, window_id:Int ) {

        // trace('move $x / $y / $xrel / $yrel / $timestamp / $window_id');

        if(app.input.keydown(Key.SPACE)) {
            positionY = y - (size/2);
            positionX = x - (size/2);
            phys_posx = positionX;
        }

    } //onmousemove

    override function onmouseup( x:Int, y:Int, button:Int, timestamp:Float, window_id:Int ) {

        // trace('mouse up $x $y $button $timestamp $window_id');

        #if !mobile
            positionY = y - (size/2);
            positionX = x - (size/2);
            phys_posx = positionX;
        #end

    } //onmouseup

    override function onmousedown( x:Int, y:Int, button:Int, timestamp:Float, window_id:Int ) {
        // trace('mouse down $x $y $button $timestamp $window_id');
    } //onmousedown

    override function onmousewheel(  x:Int, y:Int, timestamp:Float, window_id:Int ) {
        // trace('mouse wheel $x $y $timestamp $window_id');
    } //onmousewheel


    override function ongamepadaxis( gamepad:Int, axis:Int, value:Float, timestamp:Float ) {
        if(Math.abs(value) > 0.2 || noclamp) {
            trace('axis; device: ${gamepad}, axis: ${axis}, value: ${value} timestamp: ${timestamp}');
        }
    } //ongamepadaxis

    override function ongamepadbuttonup( gamepad:Int, button:Int, value:Float, timestamp:Float ) {
        trace('button up; device: ${gamepad}, button: ${button} value: ${value} timestamp:  ${timestamp}');
    } //ongamepadbuttonup

    override function ongamepadbuttondown( gamepad:Int, button:Int, value:Float, timestamp:Float ) {
        trace('button down; device: ${gamepad}, button: ${button} value: ${value} timestamp:  ${timestamp}');
    } //ongamepadbuttondown

    override function ongamepaddevice( gamepad:Int, type:GamepadDeviceEventType, timestamp:Float ) {
        trace('device event; device: ${gamepad}, type: ${type} timestamp: ${timestamp}');
    } //ongamepaddevice


    var next_tex_tick : Float = 0;
    var phys_posx : Float = 0;

    override function update( delta:Float ) {

        positionX = phys_posx;

        phys_posx += (speed * dirX * delta);

        if(current_texture != null) {

            if(current_time > next_tex_tick) {

                next_tex_tick = current_time + texture_time;

                tex_index++;

                if(tex_index == textures.length) {
                    tex_index = 0;
                }

                current_texture = textures[tex_index];

            }

        } else {

            next_tex_tick = current_time + texture_time;

        } //current_texture != null

        if(app.input.keyreleased(Key.SPACE)) {
            trace('space released');
        }

        if(app.input.keypressed(Key.SPACE)) {
            trace('space pressed');
        }

    } //update


    function onrender( window:Window ) {

        //"update"
        //this is to test the fix-your-timestep thing
        //essentially app.frame_time is a fixed timestep, alpha time is how far we are between a frame and the next,
        //allowing us to render the mid frame placement smoothly

        var prevx = positionX;

        positionX = (phys_posx * alpha) + prevx * ( 1.0 - alpha );

        if(positionX >= (app.window.width - size)) {
            positionX = (app.window.width - size);
            dirX = -1;
        } else if(positionX <= 0) {
            positionX = 0;
            dirX = 1;
        }

        // Sys.println('alpha:${alpha} dt:${delta_time} delta_sim:${delta_sim}');

        render();

    } //onrender hook

    function createTexture( asset:AssetImage ):GLTexture {

        var texture = GL.createTexture();

            GL.bindTexture (GL.TEXTURE_2D, texture);
            GL.texImage2D (GL.TEXTURE_2D, 0, GL.RGBA, asset.image.width, asset.image.height, 0, GL.RGBA, GL.UNSIGNED_BYTE, asset.image.data );
            GL.texParameteri (GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.NEAREST);
            GL.texParameteri (GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.NEAREST);
            GL.bindTexture (GL.TEXTURE_2D, null);

        return texture;

    } //createTexture

    function initializeShaders ():Void {

        var vertexShaderSource = "";

        #if (android || snow_html5)
            vertexShaderSource += "precision mediump float;";
        #end

        vertexShaderSource +=
            "attribute vec3 aVertexPosition;
            attribute vec2 aTexCoord;
            varying vec2 vTexCoord;

            uniform mat4 uModelViewMatrix;
            uniform mat4 uProjectionMatrix;

            void main(void) {
                vTexCoord = aTexCoord;
                gl_Position = uProjectionMatrix * uModelViewMatrix * vec4 (aVertexPosition, 1.0);
            }";

        trace("about to create a shader");
        var vertexShader = GL.createShader (GL.VERTEX_SHADER);


            GL.shaderSource (vertexShader, vertexShaderSource);
            GL.compileShader (vertexShader);

        trace("shader created without issue");

        if (GL.getShaderParameter (vertexShader, GL.COMPILE_STATUS) == 0) {

            var shader_log = GL.getShaderInfoLog(vertexShader);
            throw "Error compiling vertex shader" + shader_log;

        }

        var fragmentShaderSource = "";

        #if (mobile || snow_html5)
            fragmentShaderSource += "precision mediump float;";
        #end

        fragmentShaderSource +=
            "varying vec2 vTexCoord;
            uniform sampler2D uImage0;

            void main(void) {
                gl_FragColor = texture2D (uImage0, vTexCoord);
            }";

        var fragmentShader = GL.createShader (GL.FRAGMENT_SHADER);
            GL.shaderSource (fragmentShader, fragmentShaderSource);
            GL.compileShader (fragmentShader);

        if (GL.getShaderParameter (fragmentShader, GL.COMPILE_STATUS) == 0) {

            var shader_log = GL.getShaderInfoLog(fragmentShader);
            throw "Error compiling fragment shader" + shader_log;

        }

        shaderProgram = GL.createProgram ();

        GL.attachShader (shaderProgram, vertexShader);
        GL.attachShader (shaderProgram, fragmentShader);
        GL.linkProgram (shaderProgram);

        if (GL.getProgramParameter (shaderProgram, GL.LINK_STATUS) == 0) {

            throw "Unable to initialize the shader program.";

        }

        vertexAttribute = GL.getAttribLocation (shaderProgram, "aVertexPosition");
        texCoordAttribute = GL.getAttribLocation (shaderProgram, "aTexCoord");
        projectionMatrixUniform = GL.getUniformLocation (shaderProgram, "uProjectionMatrix");
        modelViewMatrixUniform = GL.getUniformLocation (shaderProgram, "uModelViewMatrix");
        imageUniform = GL.getUniformLocation (shaderProgram, "uImage0");

    } //initializeShaders

    function createBuffers ():Void {

        var vertices = [

            size, size, 0,
            0, size, 0,
            size, 0, 0,
            0, 0, 0

        ];

        vertexBuffer = GL.createBuffer ();
        GL.bindBuffer (GL.ARRAY_BUFFER, vertexBuffer);
        GL.bufferData (GL.ARRAY_BUFFER, new Float32Array (cast vertices), GL.STATIC_DRAW);
        GL.bindBuffer (GL.ARRAY_BUFFER, null);

        var texCoords = [

            1, 1,
            0, 1,
            1, 0,
            0, 0,

        ];

        texCoordBuffer = GL.createBuffer ();
        GL.bindBuffer (GL.ARRAY_BUFFER, texCoordBuffer);
        GL.bufferData (GL.ARRAY_BUFFER, new Float32Array (cast texCoords), GL.STATIC_DRAW);
        GL.bindBuffer (GL.ARRAY_BUFFER, null);

    } //createBuffers

    function render(){

        GL.viewport (0, 0, app.window.width, app.window.height);

        GL.clearColor(1.0, 0.5, 0.2, 1.0);
        GL.clear (GL.COLOR_BUFFER_BIT);

        projectionMatrix = createOrthoMatrix( 0, app.window.width, app.window.height, 0, 1000, -1000 );
        modelViewMatrix = create2DMatrix( positionX, positionY, 1, 0 );

        GL.useProgram (shaderProgram);
        GL.enableVertexAttribArray (vertexAttribute);
        GL.enableVertexAttribArray (texCoordAttribute);

        if(current_texture != null) {
            GL.activeTexture (GL.TEXTURE0);
            GL.bindTexture (GL.TEXTURE_2D, current_texture);
        }

        GL.bindBuffer (GL.ARRAY_BUFFER, vertexBuffer);
        GL.vertexAttribPointer (vertexAttribute, 3, GL.FLOAT, false, 0, 0);
        GL.bindBuffer (GL.ARRAY_BUFFER, texCoordBuffer);
        GL.vertexAttribPointer (texCoordAttribute, 2, GL.FLOAT, false, 0, 0);

        GL.uniformMatrix4fv( projectionMatrixUniform, false, projectionMatrix );
        GL.uniformMatrix4fv( modelViewMatrixUniform, false, modelViewMatrix );
        GL.uniform1i( imageUniform, 0 );

        GL.drawArrays (GL.TRIANGLE_STRIP, 0, 4);

        GL.bindBuffer (GL.ARRAY_BUFFER, null);
        GL.bindTexture (GL.TEXTURE_2D, null);

        GL.disableVertexAttribArray (vertexAttribute);
        GL.disableVertexAttribArray (texCoordAttribute);
        GL.useProgram (null);

    } //render


    function createOrthoMatrix( x0:Float, x1:Float,  y0:Float, y1:Float, zNear:Float, zFar:Float ) : Float32Array {

        var sx = 1.0 / (x1 - x0);
        var sy = 1.0 / (y1 - y0);
        var sz = 1.0 / (zFar - zNear);

        return new Float32Array([
            2.0*sx,         0,              0,                  0,
            0,              2.0*sy,         0,                  0,
            0,              0,              -2.0*sz,            0,
            - (x0+x1)*sx,   - (y0+y1)*sy,   - (zNear+zFar)*sz,  1,
        ]);

    } //createOrthoMatrix

    function create2DMatrix( x:Float, y:Float, scale:Float = 1, rotation:Float = 0 ) {

        var theta = rotation * Math.PI / 180.0;
        var c = Math.cos(theta);
        var s = Math.sin(theta);

        return new Float32Array([
            c*scale,  -s*scale,     0,      0,
            s*scale,  c*scale,      0,      0,
            0,        0,            1,      0,
            x,        y,            0,      1
        ]);

    } //create2DMatrix

} //Main