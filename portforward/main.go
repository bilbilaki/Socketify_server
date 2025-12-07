package main

/*
#include <stdint.h>
*/
import "C"
import (
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"os"
	"strings"
	"sync"
	"sync/atomic"
	"unsafe"

	bridge "bridge"

	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/portforward"
)

const (
	// Placeholder constants; adjust as needed
	Version = "v1.00.0.0001, PortForwarder"
)

var (
	// Placeholder for global state, if needed
	portForwarders = make(map[int64]*PortForwarderWrapper)
	portFWsMu      sync.Mutex
	nextPFID       int64 // atomic increment
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

type PortForwarderWrapper struct {
	PF       *portforward.PortForwarder
	Ready    <-chan struct{}
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

// ---- Port Forwarder Exports ----

//export CreatePortForwarder
func CreatePortForwarder(urlStr *C.char, portsStr *C.char, addressStr *C.char, port C.longlong) C.longlong {
	p := getPortOrDefault(port)
	goURL := C.GoString(urlStr)
	goPorts := strings.Split(C.GoString(portsStr), ",")
	for i, portStr := range goPorts {
		goPorts[i] = strings.TrimSpace(portStr)
	}
	goAddresses := []string{}
	if addressStr != nil {
		addrStr := C.GoString(addressStr)
		if addrStr != "" {
			goAddresses = strings.Split(addrStr, ",")
			for i, addr := range goAddresses {
				goAddresses[i] = strings.TrimSpace(addr)
			}
		}
	}
	if len(goAddresses) == 0 {
		goAddresses = []string{"localhost"} // default to localhost
	}

	safeOp(p, "create_port_forwarder", func() (interface{}, error) {
		u, err := url.Parse(goURL)
		if err != nil {
			return nil, fmt.Errorf("invalid URL: %v", err)
		}
		config := &rest.Config{
			Host: u.Host,
			// Assume some defaults; in real use, load from kubeconfig or provide more params
			TLSClientConfig: rest.TLSClientConfig{
				Insecure: true, // For simplicity, adjust as needed
			},
		}
		dialer, err := portforward.NewSPDYOverWebsocketDialer(u, config)
		if err != nil {
			return nil, fmt.Errorf("failed to create dialer: %v", err)
		}

		stopChan := make(chan struct{})
		readyChan := make(chan struct{})
		out := os.Stdout
		errOut := os.Stderr

		var pf *portforward.PortForwarder
		if len(goAddresses) > 0 {
			pf, err = portforward.NewOnAddresses(dialer, goAddresses, goPorts, stopChan, readyChan, out, errOut)
		} else {
			pf, err = portforward.New(dialer, goPorts, stopChan, readyChan, out, errOut)
		}
		if err != nil {
			return nil, fmt.Errorf("failed to create port forwarder: %v", err)
		}

		id := atomic.AddInt64(&nextPFID, 1)
		wrapper := &PortForwarderWrapper{
			PF:       pf,
			Ready:    readyChan,
			StopChan: stopChan,
			ID:       id,
		}
		portFWsMu.Lock()
		portForwarders[id] = wrapper
		portFWsMu.Unlock()

		return id, nil
	})
	return 0 // Task ID not used here; returns the PF ID in response
}

//export StartForwardPorts
func StartForwardPorts(pfID C.longlong, port C.longlong) C.longlong {
	p := getPortOrDefault(port)
	id := int64(pfID)
	portFWsMu.Lock()
	wrapper, ok := portForwarders[id]
	portFWsMu.Unlock()
	if !ok {
		sendToPort(p, simpleResp{Op: "start_forward_ports", Success: false, Error: fmt.Sprintf("port forwarder %d not found", id)})
		return 0
	}

	_, cancel := context.WithCancel(context.Background())
	taskID := addTask(cancel)

	go func(tid int64, w *PortForwarderWrapper) {
		defer finishTask(tid)
		defer func() {
			if r := recover(); r != nil {
				sendToPort(p, simpleResp{Op: "start_forward_ports", Success: false, Error: fmt.Sprintf("%v", r)})
			}
		}()
		defer func() {
			portFWsMu.Lock()
			delete(portForwarders, w.ID)
			portFWsMu.Unlock()
			close(w.StopChan)
			w.PF.Close()
		}()

		err := w.PF.ForwardPorts()
		if err != nil {
			sendToPort(p, simpleResp{Op: "start_forward_ports", Success: false, Error: err.Error()})
			return
		}
		sendToPort(p, simpleResp{Op: "start_forward_ports", Success: true, Data: tid})
	}(taskID, wrapper)

	return C.longlong(taskID)
}

//export StopForwardPorts
func StopForwardPorts(pfID C.longlong, port C.longlong) {
	p := getPortOrDefault(port)
	id := int64(pfID)
	portFWsMu.Lock()
	wrapper, ok := portForwarders[id]
	portFWsMu.Unlock()
	if !ok {
		sendToPort(p, simpleResp{Op: "stop_forward_ports", Success: false, Error: fmt.Sprintf("port forwarder %d not found", id)})
		return
	}
	close(wrapper.StopChan)
	wrapper.PF.Close()
	portFWsMu.Lock()
	delete(portForwarders, id)
	portFWsMu.Unlock()
	sendToPort(p, simpleResp{Op: "stop_forward_ports", Success: true, Data: id})
}

//export GetForwardedPorts
func GetForwardedPorts(pfID C.longlong, port C.longlong) {
	p := getPortOrDefault(port)
	id := int64(pfID)
	portFWsMu.Lock()
	wrapper, ok := portForwarders[id]
	portFWsMu.Unlock()
	if !ok {
		sendToPort(p, simpleResp{Op: "get_forwarded_ports", Success: false, Error: fmt.Sprintf("port forwarder %d not found", id)})
		return
	}
	safeOp(p, "get_forwarded_ports", func() (interface{}, error) {
		ports, err := wrapper.PF.GetPorts()
		if err != nil {
			return nil, err
		}
		var res []map[string]uint16
		for _, port := range ports {
			res = append(res, map[string]uint16{"local": port.Local, "remote": port.Remote})
		}
		return res, nil
	})
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