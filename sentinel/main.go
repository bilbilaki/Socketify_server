package main
/*
#include <stdint.h>
*/
import "C"
import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"image"
	"image/png"
	"math"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"
	"unsafe"

	bridge "bridge"

	"github.com/coreos/go-systemd/v22/dbus"
	"github.com/go-vgo/robotgo"
	"github.com/gorilla/websocket"
	hook "github.com/robotn/gohook"
	"github.com/shirou/gopsutil/v3/cpu"
	"github.com/shirou/gopsutil/v3/mem"
	"github.com/shirou/gopsutil/v3/net"
	"github.com/vcaesar/imgo"
	"github.com/vcaesar/keycode"
)
const (
	// KeyA define key "a"
	KeyA = "a"
	KeyB = "b"
	KeyC = "c"
	KeyD = "d"
	KeyE = "e"
	KeyF = "f"
	KeyG = "g"
	KeyH = "h"
	KeyI = "i"
	KeyJ = "j"
	KeyK = "k"
	KeyL = "l"
	KeyM = "m"
	KeyN = "n"
	KeyO = "o"
	KeyP = "p"
	KeyQ = "q"
	KeyR = "r"
	KeyS = "s"
	KeyT = "t"
	KeyU = "u"
	KeyV = "v"
	KeyW = "w"
	KeyX = "x"
	KeyY = "y"
	KeyZ = "z"
	//
	CapA = "A"
	CapB = "B"
	CapC = "C"
	CapD = "D"
	CapE = "E"
	CapF = "F"
	CapG = "G"
	CapH = "H"
	CapI = "I"
	CapJ = "J"
	CapK = "K"
	CapL = "L"
	CapM = "M"
	CapN = "N"
	CapO = "O"
	CapP = "P"
	CapQ = "Q"
	CapR = "R"
	CapS = "S"
	CapT = "T"
	CapU = "U"
	CapV = "V"
	CapW = "W"
	CapX = "X"
	CapY = "Y"
	CapZ = "Z"
	//
	Key0 = "0"
	Key1 = "1"
	Key2 = "2"
	Key3 = "3"
	Key4 = "4"
	Key5 = "5"
	Key6 = "6"
	Key7 = "7"
	Key8 = "8"
	Key9 = "9"

	// Backspace backspace key string
	Backspace = "backspace"
	Delete    = "delete"
	Enter     = "enter"
	Tab       = "tab"
	Esc       = "esc"
	Escape    = "escape"
	Up        = "up"    // Up arrow key
	Down      = "down"  // Down arrow key
	Right     = "right" // Right arrow key
	Left      = "left"  // Left arrow key
	Home      = "home"
	End       = "end"
	Pageup    = "pageup"
	Pagedown  = "pagedown"

	F1  = "f1"
	F2  = "f2"
	F3  = "f3"
	F4  = "f4"
	F5  = "f5"
	F6  = "f6"
	F7  = "f7"
	F8  = "f8"
	F9  = "f9"
	F10 = "f10"
	F11 = "f11"
	F12 = "f12"
	F13 = "f13"
	F14 = "f14"
	F15 = "f15"
	F16 = "f16"
	F17 = "f17"
	F18 = "f18"
	F19 = "f19"
	F20 = "f20"
	F21 = "f21"
	F22 = "f22"
	F23 = "f23"
	F24 = "f24"

	Cmd  = "cmd"  // is the "win" key for windows
	Lcmd = "lcmd" // left command
	Rcmd = "rcmd" // right command
	// "command"
	Alt     = "alt"
	Lalt    = "lalt" // left alt
	Ralt    = "ralt" // right alt
	Ctrl    = "ctrl"
	Lctrl   = "lctrl" // left ctrl
	Rctrl   = "rctrl" // right ctrl
	Control = "control"
	Shift   = "shift"
	Lshift  = "lshift" // left shift
	Rshift  = "rshift" // right shift
	// "right_shift"
	Capslock    = "capslock"
	Space       = "space"
	Print       = "print"
	Printscreen = "printscreen" // No Mac support
	Insert      = "insert"
	Menu        = "menu" // Windows only

	AudioMute    = "audio_mute"     // Mute the volume
	AudioVolDown = "audio_vol_down" // Lower the volume
	AudioVolUp   = "audio_vol_up"   // Increase the volume
	AudioPlay    = "audio_play"
	AudioStop    = "audio_stop"
	AudioPause   = "audio_pause"
	AudioPrev    = "audio_prev"    // Previous Track
	AudioNext    = "audio_next"    // Next Track
	AudioRewind  = "audio_rewind"  // Linux only
	AudioForward = "audio_forward" // Linux only
	AudioRepeat  = "audio_repeat"  //  Linux only
	AudioRandom  = "audio_random"  //  Linux only

	Num0    = "num0" // numpad 0
	Num1    = "num1"
	Num2    = "num2"
	Num3    = "num3"
	Num4    = "num4"
	Num5    = "num5"
	Num6    = "num6"
	Num7    = "num7"
	Num8    = "num8"
	Num9    = "num9"
	NumLock = "num_lock"

	NumDecimal = "num."
	NumPlus    = "num+"
	NumMinus   = "num-"
	NumMul     = "num*"
	NumDiv     = "num/"
	NumClear   = "num_clear"
	NumEnter   = "num_enter"
	NumEqual   = "num_equal"

	LightsMonUp     = "lights_mon_up"     // Turn up monitor brightness			No Windows support
	LightsMonDown   = "lights_mon_down"   // Turn down monitor brightness		No Windows support
	LightsKbdToggle = "lights_kbd_toggle" // Toggle keyboard backlight on/off		No Windows support
	LightsKbdUp     = "lights_kbd_up"     // Turn up keyboard backlight brightness	No Windows support
	LightsKbdDown   = "lights_kbd_down"
)

const (
	// Mleft mouse left button
	Mleft      = "left"
	Mright     = "right"
	Center     = "center"
	WheelDown  = "wheelDown"
	WheelUp    = "wheelUp"
	WheelLeft  = "wheelLeft"
	WheelRight = "wheelRight"
)
const (
	// Version get the robotgo version
	Version = "v1.00.0.1189, MT. Baker!"
)

var (
	// MouseSleep set the mouse default millisecond sleep time
	MouseSleep = 0
	// KeySleep set the key default millisecond sleep time
	KeySleep = 10

	// DisplayID set the screen display id
	DisplayID = -1

	// NotPid used the hwnd not pid in windows
	NotPid bool
	// Scale option the os screen scale
	Scale bool
)

var Special = keycode.Special

type taskRec struct {
	cancel context.CancelFunc
	done   chan struct{}
}

var (
	tasks    = map[int64]*taskRec{}
	tasksMu  sync.Mutex
	nextTask int64 // start from 0; atomic increment gives 1,2,...
)
var (
	registeredPort int64
	portMu         sync.RWMutex
)

type simpleResp struct {
	Op      string      `json:"op"`
	Success bool        `json:"success"`
	Error   string      `json:"error,omitempty"`
	Data    interface{} `json:"data,omitempty"`
}

func addTask(cancel context.CancelFunc) int64 {
	id := atomic.AddInt64(&nextTask, 1)
	entry := &taskRec{
		cancel: cancel,
		done:   make(chan struct{}),
	}
	tasksMu.Lock()
	tasks[id] = entry
	tasksMu.Unlock()
	return id
}

//export RegisterPort
func RegisterPort(port C.longlong) {
	portMu.Lock()
	registeredPort = int64(port)
	portMu.Unlock()
	bridge.SendStringToPort(int64(port), "registered")
}

//export UnregisterPort
func UnregisterPort() {
	portMu.Lock()
	p := registeredPort
	registeredPort = 0
	portMu.Unlock()
	if p != 0 {
		bridge.SendStringToPort(p, "unregistered")
	}
}

func getPortOrDefault(p C.longlong) int64 {
	if int64(p) != 0 {
		return int64(p)
	}
	portMu.RLock()
	defer portMu.RUnlock()
	return registeredPort
}

func sendToPort(port int64, r simpleResp) {
	b, _ := json.Marshal(r)
	bridge.SendStringToPort(port, string(b))
}

// ---- wrapper helpers ----
func safeOp(port int64, op string, fn func() (interface{}, error)) {
	defer func() {
		if r := recover(); r != nil {
			sendToPort(port, simpleResp{Op: op, Success: false, Error: fmt.Sprintf("panic: %v", r)})
		}
	}()
	res, err := fn()
	if err != nil {
		sendToPort(port, simpleResp{Op: op, Success: false, Error: err.Error()})
		return
	}
	sendToPort(port, simpleResp{Op: op, Success: true, Data: res})
}

//export BridgeInit
func BridgeInit(api unsafe.Pointer) {
	// panic-safe init
	defer func() {
		if r := recover(); r != nil {
			port := getPortOrDefault(0)
			if port != 0 {
				sendToPort(port, simpleResp{Op: "bridge_init", Success: false, Error: fmt.Sprintf("%v", r)})
			}
		}
	}()
	bridge.InitDartApi(api)
}

//export Move
func Move(x C.int, y C.int, port C.longlong) {
	p := getPortOrDefault(port)
	safeOp(p, "move", func() (interface{}, error) {
		robotgo.Move(int(x), int(y))
		lx, ly := robotgo.Location()
		return map[string]int{"x": lx, "y": ly}, nil
	})
}

//export MoveRelative
func MoveRelative(x C.int, y C.int, port C.longlong) {
	p := getPortOrDefault(port)
	safeOp(p, "move_relative", func() (interface{}, error) {
		robotgo.MoveRelative(int(x), int(y))
		lx, ly := robotgo.Location()
		return map[string]int{"x": lx, "y": ly}, nil
	})
}

//export Click
func Click(btn *C.char, dbl C.int, port C.longlong) {
	p := getPortOrDefault(port)
	button := C.GoString(btn)
	safeOp(p, "click", func() (interface{}, error) {
		if dbl != 0 {
			robotgo.Click(button, true)
		} else {
			robotgo.Click(button)
		}
		return button, nil
	})
}

//export Toggle
func Toggle(btn *C.char, dir *C.char, port C.longlong) {
	p := getPortOrDefault(port)
	button := C.GoString(btn)
	var direction string
	if dir != nil {
		direction = C.GoString(dir)
	}
	safeOp(p, "toggle", func() (interface{}, error) {
		if direction == "" {
			robotgo.Toggle(button)
			return button, nil
		}
		robotgo.Toggle(button, direction)
		return map[string]string{"button": button, "dir": direction}, nil
	})
}

//export Scroll
func Scroll(x C.int, y C.int, port C.longlong) {
	p := getPortOrDefault(port)
	safeOp(p, "scroll", func() (interface{}, error) {
		robotgo.Scroll(int(x), int(y))
		return map[string]int{"x": int(x), "y": int(y)}, nil
	})
}

//export ScrollDir
func ScrollDir(amount C.int, dir *C.char, port C.longlong) {
	p := getPortOrDefault(port)
	goDir := C.GoString(dir)
	safeOp(p, "scrolldir", func() (interface{}, error) {
		robotgo.ScrollDir(int(amount), goDir)
		return map[string]interface{}{"amount": int(amount), "dir": goDir}, nil
	})
}

//export GetLocation
func GetLocation(port C.longlong) {
	p := getPortOrDefault(port)
	safeOp(p, "location", func() (interface{}, error) {
		lx, ly := robotgo.Location()
		return map[string]int{"x": lx, "y": ly}, nil
	})
}

//export SetMouseSleep
func SetMouseSleep(ms C.int, port C.longlong) {
	p := getPortOrDefault(port)
	safeOp(p, "set_mouse_sleep", func() (interface{}, error) {
		robotgo.MouseSleep = int(ms)
		return robotgo.MouseSleep, nil
	})
}

//export MilliSleep
func MilliSleep(ms C.int, port C.longlong) {
	p := getPortOrDefault(port)
	safeOp(p, "milli_sleep", func() (interface{}, error) {
		time.Sleep(time.Duration(ms) * time.Millisecond)
		return ms, nil
	})
}
func finishTask(id int64) {
	tasksMu.Lock()
	if e, ok := tasks[id]; ok {
		close(e.done)
		delete(tasks, id)
	}
	tasksMu.Unlock()
}

//export StopTask
func StopTask(taskID C.longlong, port C.longlong) {
	id := int64(taskID)
	p := getPortOrDefault(port)
	tasksMu.Lock()
	entry, ok := tasks[id]
	if ok {
		delete(tasks, id)
	}
	tasksMu.Unlock()
	if !ok {
		sendToPort(p, simpleResp{Op: "stop", Success: false, Error: fmt.Sprintf("task %d not found", id)})
		return
	}
	entry.cancel()
	<-entry.done
	sendToPort(p, simpleResp{Op: "stop", Success: true, Data: id})
}

// ---- cancellable / long-running ops (return task id) ----
//
//export MoveSmoothStart
func MoveSmoothStart(x C.int, y C.int, port C.longlong) C.longlong {
	p := getPortOrDefault(port)
	ctx, cancel := context.WithCancel(context.Background())
	id := addTask(cancel)

	go func(tid int64) {
		defer finishTask(tid)
		defer func() {
			if r := recover(); r != nil {
				sendToPort(p, simpleResp{Op: "move_smooth", Success: false, Error: fmt.Sprintf("%v", r)})
			}
		}()

		startX, startY := robotgo.GetMousePos()
		tx := int(x)
		ty := int(y)

		// Steps based on distance for smoother motion
		dist := math.Max(math.Abs(float64(tx-startX)), math.Abs(float64(ty-startY)))
		steps := int(dist / 10.0)
		if steps < 10 {
			steps = 10
		}
		if steps > 120 {
			steps = 120
		}

		dx := float64(tx-startX) / float64(steps)
		dy := float64(ty-startY) / float64(steps)

		for i := 1; i <= steps; i++ {
			select {
			case <-ctx.Done():
				sendToPort(p, simpleResp{Op: "move_smooth", Success: false, Error: "canceled", Data: tid})
				return
			default:
				nx := int(math.Round(float64(startX) + dx*float64(i)))
				ny := int(math.Round(float64(startY) + dy*float64(i)))
				robotgo.Move(nx, ny)
				time.Sleep(8 * time.Millisecond)
			}
		}
		// Ensure exact final position
		robotgo.Move(tx, ty)
		lx, ly := robotgo.Location()
		sendToPort(p, simpleResp{Op: "move_smooth", Success: true, Data: map[string]int{"x": lx, "y": ly}})
	}(id)

	return C.longlong(id)
}

//export DragSmoothStart
func DragSmoothStart(x C.int, y C.int, port C.longlong) C.longlong {
	p := getPortOrDefault(port)
	ctx, cancel := context.WithCancel(context.Background())
	id := addTask(cancel)

	go func(tid int64) {
		defer finishTask(tid)
		defer func() {
			if r := recover(); r != nil {
				sendToPort(p, simpleResp{Op: "drag_smooth", Success: false, Error: fmt.Sprintf("%v", r)})
			}
		}()

		robotgo.Toggle("down")
		startX, startY := robotgo.GetMousePos()
		tx := int(x)
		ty := int(y)

		dist := math.Max(math.Abs(float64(tx-startX)), math.Abs(float64(ty-startY)))
		steps := int(dist / 10.0)
		if steps < 10 {
			steps = 10
		}
		if steps > 120 {
			steps = 120
		}

		dx := float64(tx-startX) / float64(steps)
		dy := float64(ty-startY) / float64(steps)

		for i := 1; i <= steps; i++ {
			select {
			case <-ctx.Done():
				robotgo.Toggle("up")
				sendToPort(p, simpleResp{Op: "drag_smooth", Success: false, Error: "canceled", Data: tid})
				return
			default:
				nx := int(math.Round(float64(startX) + dx*float64(i)))
				ny := int(math.Round(float64(startY) + dy*float64(i)))
				robotgo.Move(nx, ny)
				time.Sleep(8 * time.Millisecond)
			}
		}
		robotgo.Move(tx, ty)
		robotgo.Toggle("up")
		lx, ly := robotgo.Location()
		sendToPort(p, simpleResp{Op: "drag_smooth", Success: true, Data: map[string]int{"x": lx, "y": ly}})
	}(id)

	return C.longlong(id)
}

//export ScrollSmoothStart
func ScrollSmoothStart(x C.int, y C.int, port C.longlong) C.longlong {
	p := getPortOrDefault(port)
	ctx, cancel := context.WithCancel(context.Background())
	id := addTask(cancel)

	go func(tid int64) {
		defer finishTask(tid)
		defer func() {
			if r := recover(); r != nil {
				sendToPort(p, simpleResp{Op: "scroll_smooth", Success: false, Error: fmt.Sprintf("%v", r)})
			}
		}()

		steps := 20
		dx := int(x) / steps
		dy := int(y) / steps
		for i := 0; i < steps; i++ {
			select {
			case <-ctx.Done():
				sendToPort(p, simpleResp{Op: "scroll_smooth", Success: false, Error: "canceled", Data: tid})
				return
			default:
				robotgo.Scroll(dx, dy)
				time.Sleep(10 * time.Millisecond)
			}
		}
		sendToPort(p, simpleResp{Op: "scroll_smooth", Success: true, Data: map[string]int{"x": int(x), "y": int(y)}})
	}(id)

	return C.longlong(id)
}

//export TypeStr
func TypeStr(text *C.char, port C.longlong) {
	p := getPortOrDefault(port)
	s := C.GoString(text)
	safeOp(p, "type_str", func() (interface{}, error) {
		robotgo.TypeStr(s)
		return nil, nil
	})
}

// allows calling robotgo.TypeStr(s, int1, int2) (some usages pass additional ints)
//
//export TypeStrWithInts
func TypeStrWithInts(text *C.char, arg1 C.int, arg2 C.int, port C.longlong) {
	p := getPortOrDefault(port)
	s := C.GoString(text)
	a1 := int(arg1)
	a2 := int(arg2)
	safeOp(p, "type_str_with_ints", func() (interface{}, error) {
		robotgo.TypeStr(s, a1, a2)
		return map[string]int{"arg1": a1, "arg2": a2}, nil
	})
}

//export GoSleep
func GoSleep(seconds C.int, port C.longlong) {
	p := getPortOrDefault(port)
	secs := int(seconds)
	safeOp(p, "sleep", func() (interface{}, error) {
		robotgo.Sleep(secs)
		return secs, nil
	})
}

//export SetKeySleep
func SetKeySleep(ms C.int, port C.longlong) {
	p := getPortOrDefault(port)
	n := int(ms)
	safeOp(p, "set_key_sleep", func() (interface{}, error) {
		robotgo.KeySleep = n
		return robotgo.KeySleep, nil
	})
}

// mods: comma separated modifiers string like "alt,cmd" or NULL for none
//
//export KeyTap
func KeyTap(key *C.char, mods *C.char, port C.longlong) {
	p := getPortOrDefault(port)
	k := C.GoString(key)
	var modsSlice []interface{}
	if mods != nil {
		ms := C.GoString(mods)
		ms = strings.TrimSpace(ms)
		if ms != "" {
			// split by comma and trim each
			parts := strings.Split(ms, ",")
			for _, part := range parts {
				part = strings.TrimSpace(part)
				if part != "" {
					modsSlice = append(modsSlice, part)
				}
			}
		}
	}
	safeOp(p, "key_tap", func() (interface{}, error) {
		if len(modsSlice) == 0 {
			robotgo.KeyTap(k)
		} else {
			robotgo.KeyTap(k, modsSlice...)
		}
		return map[string]interface{}{"key": k, "mods": modsSlice}, nil
	})
}

//export KeyTapArr
func KeyTapArr(key *C.char, modsJson *C.char, port C.longlong) {
	p := getPortOrDefault(port)
	k := C.GoString(key)
	var modsSlice []interface{}
	if modsJson != nil {
		js := C.GoString(modsJson)
		_ = json.Unmarshal([]byte(js), &modsSlice) // ignore error -> empty slice if malformed
	}
	safeOp(p, "key_tap_arr", func() (interface{}, error) {
		if len(modsSlice) == 0 {
			robotgo.KeyTap(k)
		} else {
			robotgo.KeyTap(k, modsSlice...)
		}
		return map[string]interface{}{"key": k, "mods": modsSlice}, nil
	})
}

// direction: NULL for default, or "up" / "down"
//
//export KeyToggle
func KeyToggle(key *C.char, direction *C.char, port C.longlong) {
	p := getPortOrDefault(port)
	k := C.GoString(key)
	dir := ""
	if direction != nil {
		dir = C.GoString(direction)
	}
	safeOp(p, "key_toggle", func() (interface{}, error) {
		if dir == "" {
			robotgo.KeyToggle(k)
			return map[string]string{"key": k}, nil
		}
		robotgo.KeyToggle(k, dir)
		return map[string]string{"key": k, "dir": dir}, nil
	})
}

//export WriteAll
func WriteAll(text *C.char, port C.longlong) {
	p := getPortOrDefault(port)
	s := C.GoString(text)
	safeOp(p, "write_all", func() (interface{}, error) {
		robotgo.WriteAll(s)
		return s, nil
	})
}

//export ReadAll
func ReadAll(port C.longlong) {
	p := getPortOrDefault(port)
	safeOp(p, "read_all", func() (interface{}, error) {
		txt, err := robotgo.ReadAll()
		if err != nil {
			return nil, err
		}
		return txt, nil
	})
}

//export TypeStrStart
func TypeStrStart(text *C.char, port C.longlong) C.longlong {
	p := getPortOrDefault(port)
	s := C.GoString(text)
	ctx, cancel := context.WithCancel(context.Background())
	id := addTask(cancel)

	go func(tid int64, c context.Context) {
		defer finishTask(tid)
		defer func() {
			if r := recover(); r != nil {
				sendToPort(p, simpleResp{Op: "type_str_async", Success: false, Error: fmt.Sprintf("%v", r)})
			}
		}()

		for _, r := range s {
			select {
			case <-c.Done():
				sendToPort(p, simpleResp{Op: "type_str_async", Success: false, Error: "canceled", Data: tid})
				return
			default:
				robotgo.TypeStr(string(r))
				time.Sleep(time.Duration(robotgo.KeySleep) * time.Millisecond)
			}
		}
		sendToPort(p, simpleResp{Op: "type_str_async", Success: true, Data: s})
	}(id, ctx)

	return C.longlong(id)
}

//export GetPixelColor
func GetPixelColor(x C.int, y C.int, port C.longlong) {
	p := getPortOrDefault(port)
	safeOp(p, "get_pixel_color", func() (interface{}, error) {
		col := robotgo.GetPixelColor(int(x), int(y))
		return map[string]interface{}{"x": int(x), "y": int(y), "color": col}, nil
	})
}

//export GetScreenSize
func GetScreenSize(port C.longlong) {
	p := getPortOrDefault(port)
	safeOp(p, "get_screen_size", func() (interface{}, error) {
		sx, sy := robotgo.GetScreenSize()
		return map[string]int{"width": sx, "height": sy}, nil
	})
}

// path: file path to save (PNG). If path is NULL, generates a temp file and returns its path.

//export CaptureScreenSave
func CaptureScreenSave(x C.int, y C.int, w C.int, h C.int, path *C.char, port C.longlong) {
	p := getPortOrDefault(port)
	safeOp(p, "capture_screen_save", func() (interface{}, error) {
		bit := robotgo.CaptureScreen(int(x), int(y), int(w), int(h))
		if bit == nil {
			return nil, fmt.Errorf("capture returned nil bitmap")
		}
		defer robotgo.FreeBitmap(bit)

		img := robotgo.ToImage(bit)
		if img == nil {
			return nil, fmt.Errorf("failed to convert bitmap to image")
		}

		goPath := ""
		if path == nil || C.GoString(path) == "" {
			tmp, err := os.CreateTemp("", "capture-*.png")
			if err != nil {
				return nil, err
			}
			goPath = tmp.Name()
			tmp.Close()
		} else {
			goPath = C.GoString(path)
		}

		// Use imgo.Save which handles PNG/JPEG per extension
		if err := imgo.Save(goPath, img); err != nil {
			return nil, err
		}
		return map[string]string{"path": goPath}, nil
	})
}

// returns a base64-encoded PNG of the captured region in the "data" response field.
//
//export CaptureScreenBase64
func CaptureScreenBase64(x C.int, y C.int, w C.int, h C.int, port C.longlong) {
	p := getPortOrDefault(port)
	safeOp(p, "capture_screen_base64", func() (interface{}, error) {
		bit := robotgo.CaptureScreen(int(x), int(y), int(w), int(h))
		if bit == nil {
			return nil, fmt.Errorf("capture returned nil bitmap")
		}
		defer robotgo.FreeBitmap(bit)

		img := robotgo.ToImage(bit)
		if img == nil {
			return nil, fmt.Errorf("failed to convert bitmap to image")
		}

		var buf bytes.Buffer
		if err := png.Encode(&buf, img); err != nil {
			return nil, err
		}
		encoded := base64.StdEncoding.EncodeToString(buf.Bytes())
		return map[string]string{"base64_png": encoded}, nil
	})
}

//export DisplaysNum
func DisplaysNum(port C.longlong) {
	p := getPortOrDefault(port)
	safeOp(p, "displays_num", func() (interface{}, error) {
		n := robotgo.DisplaysNum()
		return n, nil
	})
}

//export GetDisplayBounds
func GetDisplayBounds(index C.int, port C.longlong) {
	p := getPortOrDefault(port)
	safeOp(p, "get_display_bounds", func() (interface{}, error) {
		x, y, w, h := robotgo.GetDisplayBounds(int(index))
		return map[string]int{"index": int(index), "x": x, "y": y, "w": w, "h": h}, nil
	})
}

// capture entire display specified by index and save to given path (if path NULL, create temp file)
//
//export CaptureDisplaySave
func CaptureDisplaySave(index C.int, path *C.char, port C.longlong) {
	p := getPortOrDefault(port)
	safeOp(p, "capture_display_save", func() (interface{}, error) {
		robotgo.DisplayID = int(index)
		img, err := robotgo.CaptureImg()
		if err != nil || img == nil {
			return nil, fmt.Errorf("capture img error: %v", err)
		}

		goPath := ""
		if path == nil || C.GoString(path) == "" {
			tmp, err := os.CreateTemp("", "display-"+strconv.Itoa(int(index))+"-*.png")
			if err != nil {
				return nil, err
			}
			goPath = tmp.Name()
			tmp.Close()
		} else {
			goPath = C.GoString(path)
		}

		if err := imgo.Save(goPath, img); err != nil {
			return nil, err
		}
		return map[string]string{"path": goPath}, nil
	})
}

// capture specific region on current display (or after setting DisplayID) and save
//
//export CaptureDisplayRegionSave
func CaptureDisplayRegionSave(index C.int, x C.int, y C.int, w C.int, h C.int, path *C.char, port C.longlong) {
	p := getPortOrDefault(port)
	safeOp(p, "capture_display_region_save", func() (interface{}, error) {
		robotgo.DisplayID = int(index)
		img, err := robotgo.CaptureImg(int(x), int(y), int(w), int(h))
		if err != nil || img == nil {
			return nil, fmt.Errorf("capture img region error: %v", err)
		}

		goPath := ""
		if path == nil || C.GoString(path) == "" {
			tmp, err := os.CreateTemp("", "disp-"+strconv.Itoa(int(index))+"-region-*.png")
			if err != nil {
				return nil, err
			}
			goPath = tmp.Name()
			tmp.Close()
		} else {
			goPath = C.GoString(path)
		}

		if err := imgo.Save(goPath, img); err != nil {
			return nil, err
		}
		return map[string]string{"path": goPath}, nil
	})
}

// save an image.Image (captured via CaptureImg) to jpeg with quality (0-100).
// Here we accept path and quality; we capture entire display at robotgo.DisplayID.
//
//export SaveImageJpeg
func SaveImageJpeg(path *C.char, quality C.int, port C.longlong) {
	p := getPortOrDefault(port)
	safeOp(p, "save_image_jpeg", func() (interface{}, error) {
		goPath := C.GoString(path)
		if goPath == "" {
			return nil, fmt.Errorf("path is empty")
		}
		img, err := robotgo.CaptureImg()
		if err != nil || img == nil {
			return nil, fmt.Errorf("capture img error: %v", err)
		}
		if err := robotgo.SaveJpeg(img, goPath, int(quality)); err != nil {
			return nil, err
		}
		return map[string]interface{}{"path": goPath, "quality": int(quality)}, nil
	})
}

// capture current display and save PNG to path
//
//export SaveImagePNGFromCaptureImg
func SaveImagePNGFromCaptureImg(path *C.char, port C.longlong) {
	p := getPortOrDefault(port)
	safeOp(p, "save_image_png_from_capture", func() (interface{}, error) {
		goPath := C.GoString(path)
		if goPath == "" {
			return nil, fmt.Errorf("path is empty")
		}
		img, err := robotgo.CaptureImg()
		if err != nil || img == nil {
			return nil, fmt.Errorf("capture img error: %v", err)
		}
		if err := imgo.Save(goPath, img); err != nil {
			return nil, err
		}
		return map[string]string{"path": goPath}, nil
	})
}

// To avoid unused import warnings when building as separate file, keep a tiny reference to unsafe.
var _ = unsafe.Pointer(nil)


//export SaveBitmapToFile
func SaveBitmapToFile(x C.int, y C.int, w C.int, h C.int, path *C.char, port C.longlong) {
	p := getPortOrDefault(port)
	safeOp(p, "save_bitmap_to_file", func() (interface{}, error) {
		bit := robotgo.CaptureScreen(int(x), int(y), int(w), int(h))
		if bit == nil {
			return nil, fmt.Errorf("capture returned nil bitmap")
		}
		defer robotgo.FreeBitmap(bit)

		img := robotgo.ToImage(bit)
		if img == nil {
			return nil, fmt.Errorf("ToImage returned nil")
		}
		goPath := C.GoString(path)
		if goPath == "" {
			return nil, fmt.Errorf("path empty")
		}
		if err := robotgo.Save(img, goPath); err != nil {
			return nil, err
		}
		return map[string]string{"path": goPath}, nil
	})
}

// tiny reference to unsafe to avoid unused import if required elsewhere
var _ = unsafe.Pointer(nil)

//export SaveCaptureRegion
func SaveCaptureRegion(path *C.char, x C.int, y C.int, w C.int, h C.int, port C.longlong) {
	p := getPortOrDefault(port)
	safeOp(p, "save_capture_region", func() (interface{}, error) {
		goPath := C.GoString(path)
		if goPath == "" {
			return nil, fmt.Errorf("path empty")
		}
		robotgo.SaveCapture(goPath, int(x), int(y), int(w), int(h))
		return map[string]interface{}{"path": goPath, "x": int(x), "y": int(y), "w": int(w), "h": int(h)}, nil
	})
}

//export SaveCaptureFull
func SaveCaptureFull(path *C.char, port C.longlong) {
	p := getPortOrDefault(port)
	safeOp(p, "save_capture_full", func() (interface{}, error) {
		goPath := C.GoString(path)
		if goPath == "" {
			return nil, fmt.Errorf("path empty")
		}
		robotgo.SaveCapture(goPath)
		return map[string]interface{}{"path": goPath}, nil
	})
}

// //export GcvFindImgFile
// func GcvFindImgFile(templatePath *C.char, targetPath *C.char, port C.longlong) {
// 	p := getPortOrDefault(port)
// 	tp := C.GoString(templatePath)
// 	targ := C.GoString(targetPath)
// 	safeOp(p, "gcv_find_img_file", func() (interface{}, error) {
// 		res := gcv.FindImgFile(tp, targ)
// 		return fmt.Sprintf("%v", res), nil
// 	})
// }

// helper to decode image files via robotgo.DecodeImg
func decodeImageFile(path string) (image.Image, error) {
	img, _, err := robotgo.DecodeImg(path)
	if err != nil {
		return nil, err
	}
	return img, nil
}



var (
	hookStarted   bool
	hookStartMu   sync.Mutex
	hookEventQuit chan struct{}
)

// small helper to marshal hook.Event to a JSON-able map
func hookEventToMap(e hook.Event) map[string]interface{} {
	return map[string]interface{}{
		"kind":    e.Kind,
		"rawcode": e.Rawcode,
		"keychar": e.Keychar,
		"keycode": e.Keycode,
		"mask":    e.Mask,
		"ctrl":    Ctrl,
		"alt":     Alt,
		"shift":   Shift,
		"x":       e.X,
		"y":       e.Y,
	}
}

//export HookRegisterCombo
func HookRegisterCombo(mods *C.char, key *C.char, port C.longlong) {
	p := getPortOrDefault(port)
	modsStr := C.GoString(mods)
	keyStr := C.GoString(key)
	// parse mods comma-separated
	var modsSlice []string
	if modsStr != "" {
		// split by comma and trim
		for _, m := range splitAndTrim(modsStr) {
			if m != "" {
				modsSlice = append(modsSlice, m)
			}
		}
	}
	// register a callback that sends event to port
	hook.Register(hook.KeyDown, append([]string{keyStr}, modsSlice...), func(e hook.Event) {
		b, _ := json.Marshal(map[string]interface{}{"type": "hotkey", "key": keyStr, "mods": modsSlice, "event": hookEventToMap(e)})
		bridge.SendStringToPort(p, string(b))
	})
	bridge.SendStringToPort(p, fmt.Sprintf("registered-hotkey %s + %v", keyStr, modsSlice))
}

// helper to split comma separated and trim spaces
func splitAndTrim(s string) []string {
	var out []string
	cur := ""
	for _, ch := range s {
		if ch == ',' {
			if cur != "" {
				out = append(out, trimSpaces(cur))
				cur = ""
			}
			continue
		}
		cur += string(ch)
	}
	if cur != "" {
		out = append(out, trimSpaces(cur))
	}
	return out
}
func trimSpaces(s string) string {
	start := 0
	end := len(s)
	for start < end && (s[start] == ' ' || s[start] == '\t') {
		start++
	}
	for end > start && (s[end-1] == ' ' || s[end-1] == '\t') {
		end--
	}
	return s[start:end]
}

//export HookStart
func HookStart(port C.longlong) {
	p := getPortOrDefault(port)
	hookStartMu.Lock()
	if hookStarted {
		hookStartMu.Unlock()
		bridge.SendStringToPort(p, "hook already started")
		return
	}
	hookStarted = true
	hookStartMu.Unlock()

	evChan := hook.Start()
	hookEventQuit = make(chan struct{})
	go func() {
		bridge.SendStringToPort(p, "hook_started")
		for {
			select {
			case e, ok := <-evChan:
				if !ok {
					bridge.SendStringToPort(p, "hook_event_channel_closed")
					hookEndCleanup()
					return
				}
				b, _ := json.Marshal(map[string]interface{}{"type": "event", "event": hookEventToMap(e)})
				bridge.SendStringToPort(p, string(b))
			case <-hookEventQuit:
				bridge.SendStringToPort(p, "hook_event_loop_quit")
				return
			}
		}
	}()
	// let caller know
	bridge.SendStringToPort(p, "hook_start_request_sent")
}

// internal cleanup used by stop
func hookEndCleanup() {
	hookStartMu.Lock()
	hookStarted = false
	closeIfExists := hookEventQuit
	hookEventQuit = nil
	hookStartMu.Unlock()
	if closeIfExists != nil {
		close(closeIfExists)
	}
}

//export HookStop
func HookStop() {
	hookEndCleanup()
	hook.End()
}

//export HookAddEvent
func HookAddEvent(name *C.char, port C.longlong) {
	p := getPortOrDefault(port)
	n := C.GoString(name)
	ok := hook.AddEvent(n)
	bridge.SendStringToPort(p, fmt.Sprintf("add_event %s -> %v", n, ok))
}



// convenience debug helper: decode image file and return width/height
//
//export DecodeAndReportImageSize
func DecodeAndReportImageSize(path *C.char, port C.longlong) {
	p := getPortOrDefault(port)
	goPath := C.GoString(path)
	safeOp(p, "decode_image_size", func() (interface{}, error) {
		img, _, err := robotgo.DecodeImg(goPath)
		if err != nil || img == nil {
			return nil, fmt.Errorf("decode error: %v", err)
		}
		b := img.Bounds()
		return map[string]int{"width": b.Dx(), "height": b.Dy()}, nil
	})
}

// To silence unused import if needed
var _ = unsafe.Pointer(nil)



var (
	runningClients = make(map[string]context.CancelFunc)
	clientsMutex   sync.Mutex
)

// Config
var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true }, // Allow all origins (Dev only)
}

// Data Packet Structure
type SystemStats struct {
	CPUPercent float64 `json:"cpu"`
	MemPercent float64 `json:"mem"`
	NetSpeedRx uint64  `json:"rx_speed"` // Bytes per sec
	NetSpeedTx uint64  `json:"tx_speed"` // Bytes per sec
	TcpConns   int     `json:"tcp_count"`
	UdpConns   int     `json:"udp_count"`
}

func computeStats(prevNet []net.IOCountersStat) (SystemStats, []net.IOCountersStat) {
	var cpuPercent float64
	cpuP, _ := cpu.Percent(0, false)
	if len(cpuP) > 0 {
		cpuPercent = cpuP[0]
	}

	var memPercent float64
	vMem, _ := mem.VirtualMemory()
	memPercent = vMem.UsedPercent

	currNet, _ := net.IOCounters(false)
	rxSpeed := uint64(0)
	txSpeed := uint64(0)
	if len(currNet) > 0 && len(prevNet) > 0 {
		rxSpeed = currNet[0].BytesRecv - prevNet[0].BytesRecv
		txSpeed = currNet[0].BytesSent - prevNet[0].BytesSent
	}

	conns, _ := net.Connections("all")
	tcp := 0
	udp := 0
	for _, c := range conns {
		if c.Type == 1 {
			tcp++
		}
		if c.Type == 2 {
			udp++
		}
	}

	return SystemStats{
		CPUPercent: cpuPercent,
		MemPercent: memPercent,
		NetSpeedRx: rxSpeed,
		NetSpeedTx: txSpeed,
		TcpConns:   tcp,
		UdpConns:   udp,
	}, currNet
}

//export StartMonitor
func StartMonitor(port C.longlong) C.longlong {
	p := getPortOrDefault(port)
	ctx, cancel := context.WithCancel(context.Background())
	id := addTask(cancel)

	go func(tid int64) {
		defer finishTask(tid)
		defer func() {
			if r := recover(); r != nil {
				sendToPort(p, simpleResp{Op: "monitor_start", Success: false, Error: fmt.Sprintf("%v", r)})
			}
		}()

		var prevNet []net.IOCountersStat
		for {
			select {
			case <-ctx.Done():
				sendToPort(p, simpleResp{Op: "monitor_stopped", Success: true, Data: tid})
				return
			default:
				stats, newPrevNet := computeStats(prevNet)
				prevNet = newPrevNet
				resp := simpleResp{Op: "monitor_stats", Success: true, Data: stats}
				b, _ := json.Marshal(resp)
				bridge.SendStringToPort(p, string(b))
				time.Sleep(1 * time.Second)
			}
		}
	}(id)

	sendToPort(p, simpleResp{Op: "start_monitor", Success: true, Data: id})
	return C.longlong(id)
}

//export ControlService
func ControlService(name *C.char, action *C.char, port C.longlong) {
	p := getPortOrDefault(port)
	nameGo := C.GoString(name)
	actionGo := C.GoString(action)
	safeOp(p, "control_service", func() (interface{}, error) {
		conn, err := dbus.New()
		if err != nil {
			return nil, fmt.Errorf("systemd dbus error: %v", err)
		}
		defer conn.Close()

		responseChan := make(chan string, 1)
		var jobID int
		ctx := context.Background()
		switch actionGo {
		case "start":
			jobID, err = conn.StartUnitContext(ctx, nameGo, "replace", responseChan)
		case "stop":
			jobID, err = conn.StopUnitContext(ctx, nameGo, "replace", responseChan)
		case "restart":
			jobID, err = conn.RestartUnitContext(ctx, nameGo, "replace", responseChan)
		default:
			return nil, fmt.Errorf("unknown action: %s", actionGo)
		}
		if err != nil {
			return nil, fmt.Errorf("service error: %v", err)
		}
		return map[string]interface{}{
			"job_id": jobID,
			"service": nameGo,
			"action":  actionGo,
		}, nil
	})
}
func main(){

}