package main

/*
#include <stdint.h>
*/
import "C"
import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"strconv"
	"sync"
	"sync/atomic"
	"unsafe"

	bridge "bridge"

	socks5 "github.com/txthinking/socks5"
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
	Server *socks5.Server
	ID     int64
}

type ProxyHandler struct {
	ProxyAddr string
	ProxyUser string
	ProxyPass string
}

func (h *ProxyHandler) TCPHandle(s *socks5.Server, c *net.TCPConn, r *socks5.Request) error {
	client, err := socks5.NewClient(h.ProxyAddr, h.ProxyUser, h.ProxyPass, 0, 0)
	if err != nil {
		return err
	}
	defer client.Close()

	conn, err := client.Dial("tcp", r.Address())
	if err != nil {
		return err
	}
	defer conn.Close()

	// Reply success
	rep := socks5.NewReply(socks5.RepSuccess, socks5.ATYPIPv4, []byte{0, 0, 0, 0}, []byte{0, 0})
	if _, err := rep.WriteTo(c); err != nil {
		return err
	}

	// Forward data
	go io.Copy(conn, c)
	io.Copy(c, conn)
	return nil
}

func (h *ProxyHandler) UDPHandle(s *socks5.Server, addr *net.UDPAddr, d *socks5.Datagram) error {
	// For simplicity, handle as direct; full UDP proxy through another SOCKS5 requires additional forwarding logic
	dh := &socks5.DefaultHandle{}
	return dh.UDPHandle(s, addr, d)
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
		server, err := socks5.NewClassicServer(":"+strconv.Itoa(lPort), "", uName, pwd, 0, 0)
		if err != nil {
			return nil, err
		}
		server.Handle = &socks5.DefaultHandle{}
		id := atomic.AddInt64(&nextSrvID, 1)
		wrapper := &Socks5ServerWrapper{
			Server: server,
			ID:     id,
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
	// Same as TCP since the library handles both
	return CreateDirectServerTCP(listenPort, username, password, port)
}

//export CreateProxyToSocks5ServerTCP
func CreateProxyToSocks5ServerTCP(listenPort C.int, username *C.char, password *C.char, proxyAddr *C.char, proxyUser *C.char, proxyPass *C.char, port C.longlong) C.longlong {
	p := getPortOrDefault(port)
	lPort := int(listenPort)
	uName := C.GoString(username)
	pwd := C.GoString(password)
	pxAddr := C.GoString(proxyAddr)
	pxUser := C.GoString(proxyUser)
	pxPwd := C.GoString(proxyPass)

	safeOp(p, "create_proxy_to_socks5_server_tcp", func() (interface{}, error) {
		server, err := socks5.NewClassicServer(":"+strconv.Itoa(lPort), "", uName, pwd, 0, 0)
		if err != nil {
			return nil, err
		}
		server.Handle = &ProxyHandler{
			ProxyAddr: pxAddr,
			ProxyUser: pxUser,
			ProxyPass: pxPwd,
		}
		id := atomic.AddInt64(&nextSrvID, 1)
		wrapper := &Socks5ServerWrapper{
			Server: server,
			ID:     id,
		}
		socks5SrvMu.Lock()
		socks5Servers[id] = wrapper
		socks5SrvMu.Unlock()
		return id, nil
	})
	return 0
}

//export CreateProxyToSocks5ServerUDP
func CreateProxyToSocks5ServerUDP(listenPort C.int, username *C.char, password *C.char, proxyAddr *C.char, proxyUser *C.char, proxyPass *C.char, port C.longlong) C.longlong {
	// Placeholder as direct; full UDP proxy not implemented
	log.Println("UDP proxy through another SOCKS5 not fully implemented; using direct.")
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
			w.Server.Shutdown()
		}()

		err := w.Server.ListenAndServe(w.Server.Handle)
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
	err := wrapper.Server.Shutdown()
	if err != nil {
		sendToPort(p, simpleResp{Op: "stop_socks5_server", Success: false, Error: fmt.Sprintf("shutdown error: %v", err)})
		return
	}
	socks5SrvMu.Lock()
	delete(socks5Servers, id)
	socks5SrvMu.Unlock()
	sendToPort(p, simpleResp{Op: "stop_socks5_server", Success: true, Data: id})
}

// ---- SOCKS5 Client Exports ----

//export ConnectDirectTCP
func ConnectDirectTCP(socksAddr *C.char, username *C.char, password *C.char, targetAddr *C.char, port C.longlong) C.longlong {
	p := getPortOrDefault(port)
	sAddr := C.GoString(socksAddr)
	uName := C.GoString(username)
	pwd := C.GoString(password)
	tAddr := C.GoString(targetAddr)

	safeOp(p, "connect_direct_tcp", func() (interface{}, error) {
		client, err := socks5.NewClient(sAddr, uName, pwd, 0, 0)
		if err != nil {
			return nil, err
		}
		conn, err := client.Dial("tcp", tAddr)
		if err != nil {
			return nil, err
		}
		// In a real scenario, you might want to return the connection or handle it; here just confirm
		conn.Close() // Close immediately for simplicity
		return "connected", nil
	})
	return 0
}

//export ConnectDirectUDP
func ConnectDirectUDP(socksAddr *C.char, username *C.char, password *C.char, port C.longlong) C.longlong {
	p := getPortOrDefault(port)
	sAddr := C.GoString(socksAddr)
	uName := C.GoString(username)
	pwd := C.GoString(password)

	safeOp(p, "connect_direct_udp", func() (interface{}, error) {
		client, err := socks5.NewClient(sAddr, uName, pwd, 0, 0)
		if err != nil {
			return nil, err
		}
		conn, err := client.Dial("udp", "") // Empty addr for associate
		if err != nil {
			return nil, err
		}
		conn.Close()
		return "connected", nil
	})
	return 0
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

func main() {}