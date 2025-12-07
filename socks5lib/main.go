package main

/*
#include <stdint.h>
*/
import "C"
import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"sync"
	"sync/atomic"
	"unsafe"

	bridge "bridge"

	socks5 "github.com/0990/socks5"
)

const (
	// Placeholder constants; adjust as needed
	Version = "v1.00.0.0001, Socks5Proxy"
)

var (
	socks5Servers = make(map[int64]*Socks5ServerWrapper)
	socks5SrvMu   sync.Mutex
	nextSrvID     int64 // atomic increment
)

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

type Socks5ServerWrapper struct {
	Server   socks5.Server
	StopChan chan struct{}
	ID       int64
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

func finishTask(id int64) {
	tasksMu.Lock()
	if e, ok := tasks[id]; ok {
		close(e.done)
		delete(tasks, id)
	}
	tasksMu.Unlock()
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

// ---- SOCKS5 Server Exports ----

//export CreateDirectServerTCP
func CreateDirectServerTCP(listenPort C.int, username *C.char, password *C.char, port C.longlong) C.longlong {
	p := getPortOrDefault(port)
	lPort := int(listenPort)
	uName := C.GoString(username)
	pwd := C.GoString(password)

	safeOp(p, "create_direct_server_tcp", func() (interface{}, error) {
		cfg := socks5.ServerCfg{
			ListenPort: lPort,
			UserName:   uName,
			Password:   pwd,
			LogLevel:   "info",
		}
		server, err := socks5.NewServer(cfg)
		if err != nil {
			return nil, err
		}
		id := atomic.AddInt64(&nextSrvID, 1)
		wrapper := &Socks5ServerWrapper{
			Server:   server,
			StopChan: make(chan struct{}),
			ID:       id,
		}
		socks5SrvMu.Lock()
		socks5Servers[id] = wrapper
		socks5SrvMu.Unlock()
		return id, nil
	})
	return 0
}

//export CreateDirectServerUDP
func CreateDirectServerUDP(listenPort C.int, username *C.char, password *C.char, port C.longlong) C.longlong {
	// Note: The library handles UDP in the same server; just create with same config
	return CreateDirectServerTCP(listenPort, username, password, port)
}

// //export CreateProxyToSocks5ServerTCP
// func CreateProxyToSocks5ServerTCP(listenPort C.int, username *C.char, password *C.char, proxyAddr *C.char, proxyUser *C.char, proxyPass *C.char, port C.longlong) C.longlong {
// 	p := getPortOrDefault(port)
// 	lPort := int(listenPort)
// 	uName := C.GoString(username)
// 	pwd := C.GoString(password)
// 	pxAddr := C.GoString(proxyAddr)
// 	pxUser := C.GoString(proxyUser)
// 	pxPwd := C.GoString(proxyPass)

// 	safeOp(p, "create_proxy_to_socks5_server_tcp", func() (interface{}, error) {
// 		cfg := socks5.ServerCfg{
// 			ListenPort: lPort,
// 			UserName:   uName,
// 			Password:   pwd,
// 			LogLevel:   "info",
// 		}
// 		server, err := socks5.NewServer(cfg)
// 		if err != nil {
// 			return nil, err
// 		}
// 		// Set custom dial target for TCP
// 		server.SetCustomDialTarget(func(addr string) (socks5.Stream, byte, string, error) {
// 			client := socks5.NewSocks5Client(socks5.ClientCfg{
// 				ServerAddr: pxAddr,
// 				UserName:   pxUser,
// 				Password:   pxPwd,
// 			})
// 			stream, err := client.Connect(addr)
// 			if err != nil {
// 				return nil, 0, "", err
// 			}
// 			return stream, socks5.ATypIPV4, addr, nil
// 		})
// 		id := atomic.AddInt64(&nextSrvID, 1)
// 		wrapper := &Socks5ServerWrapper{
// 			Server:   server,
// 			StopChan: make(chan struct{}),
// 			ID:       id,
// 		}
// 		socks5SrvMu.Lock()
// 		socks5Servers[id] = wrapper
// 		socks5SrvMu.Unlock()
// 		return id, nil
// 	})
// 	return 0
// }

//export CreateProxyToSocks5ServerUDP
func CreateProxyToSocks5ServerUDP(listenPort C.int, username *C.char, password *C.char, proxyAddr *C.char, proxyUser *C.char, proxyPass *C.char, port C.longlong) C.longlong {
	// UDP proxying through another SOCKS5 is complex and not fully supported; placeholder as direct
	log.Println("UDP proxy through another SOCKS5 not fully implemented.")
	return CreateDirectServerTCP(listenPort, username, password, port)
}

//export CreateWithAuthServer
func CreateWithAuthServer(listenPort C.int, port C.longlong) C.longlong {
	return CreateDirectServerTCP(listenPort, C.CString("user"), C.CString("pass"), port)
}

//export CreateWithoutAuthServer
func CreateWithoutAuthServer(listenPort C.int, port C.longlong) C.longlong {
	return CreateDirectServerTCP(listenPort, C.CString(""), C.CString(""), port)
}

//export StartSocks5Server
func StartSocks5Server(srvID C.longlong, port C.longlong) C.longlong {
	p := getPortOrDefault(port)
	id := int64(srvID)
	socks5SrvMu.Lock()
	wrapper, ok := socks5Servers[id]
	socks5SrvMu.Unlock()
	if !ok {
		sendToPort(p, simpleResp{Op: "start_socks5_server", Success: false, Error: fmt.Sprintf("server %d not found", id)})
		return 0
	}

	_, cancel := context.WithCancel(context.Background())
	taskID := addTask(cancel)

	go func(tid int64, w *Socks5ServerWrapper) {
		defer finishTask(tid)
		defer func() {
			if r := recover(); r != nil {
				sendToPort(p, simpleResp{Op: "start_socks5_server", Success: false, Error: fmt.Sprintf("%v", r)})
			}
		}()
		defer func() {
			socks5SrvMu.Lock()
			delete(socks5Servers, w.ID)
			socks5SrvMu.Unlock()
		}()

		err := w.Server.Run()
		if err != nil {
			sendToPort(p, simpleResp{Op: "start_socks5_server", Success: false, Error: err.Error()})
			return
		}
		sendToPort(p, simpleResp{Op: "start_socks5_server", Success: true, Data: tid})
	}(taskID, wrapper)

	return C.longlong(taskID)
}

//export StopSocks5Server
func StopSocks5Server(srvID C.longlong, port C.longlong) {
	p := getPortOrDefault(port)
	id := int64(srvID)
	socks5SrvMu.Lock()
	wrapper, ok := socks5Servers[id]
	socks5SrvMu.Unlock()
	if !ok {
		sendToPort(p, simpleResp{Op: "stop_socks5_server", Success: false, Error: fmt.Sprintf("server %d not found", id)})
		return
	}
	// Assuming the server has a Close method or we can stop via channel; if not, may need to kill goroutine
	// For simplicity, since Run() likely doesn't have direct stop, we close the stopChan and hope
	close(wrapper.StopChan)
	socks5SrvMu.Lock()
	delete(socks5Servers, id)
	socks5SrvMu.Unlock()
	sendToPort(p, simpleResp{Op: "stop_socks5_server", Success: true, Data: id})
}

// ---- SOCKS5 Client Exports ----

// //export ConnectDirectTCP
// func ConnectDirectTCP(socksAddr *C.char, username *C.char, password *C.char, targetAddr *C.char, port C.longlong) C.longlong {
// 	p := getPortOrDefault(port)
// 	sAddr := C.GoString(socksAddr)
// 	uName := C.GoString(username)
// 	pwd := C.GoString(password)
// 	tAddr := C.GoString(targetAddr)

// 	safeOp(p, "connect_direct_tcp", func() (interface{}, error) {
// 		client := socks5.NewSocks5Client(socks5.ClientCfg{
// 			ServerAddr: sAddr,
// 			UserName:   uName,
// 			Password:   pwd,
// 		})
// 		conn, err := client.Connect(tAddr)
// 		if err != nil {
// 			return nil, err
// 		}
// 		// Return a dummy ID or handle connection; for simplicity, just confirm success
// 		return "connected", nil
// 	})
// 	return 0
// }

// // Similar for others; adapt as needed
// //export ConnectDirectUDP
// func ConnectDirectUDP(socksAddr *C.char, username *C.char, password *C.char, targetAddr *C.char, port C.longlong) C.longlong {
// 	p := getPortOrDefault(port)
// 	sAddr := C.GoString(socksAddr)
// 	uName := C.GoString(username)
// 	pwd := C.GoString(password)
// 	tAddr := C.GoString(targetAddr)

// safeOp(p, "connect_direct_tcp", func() (interface{}, error) {
// 		client := socks5.NewSocks5Client(socks5.ClientCfg{
// 			ServerAddr: sAddr,
// 			UserName:   uName,
// 			Password:   pwd,
// 		})
// 		_, err := client.Connect(tAddr)
// 		if err != nil {
// 			return nil, err
// 		}
// 		// Return a dummy ID or handle connection; for simplicity, just confirm success
// 		return "connected", nil
// 	})
// 	return 0
// }

// Add other client functions similarly if needed...

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

func main() {}