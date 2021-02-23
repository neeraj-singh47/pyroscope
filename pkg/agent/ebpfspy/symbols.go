// +build ebpfspy

// Package ebpfspy provides integration with Linux eBPF. It is a rough copy of profile.py from BCC tools:
//   https://github.com/iovisor/bcc/blob/master/tools/profile.py
package ebpfspy

import (
	"unsafe"
) // import "fmt"

// import "encoding/hex"

// import "github.com/iovisor/gobpf/pkg/ksym"

/*
#cgo CFLAGS: -I/usr/include/bcc/compat
#cgo LDFLAGS: -lbcc
#include <bcc/bcc_common.h>
#include <bcc/libbpf.h>
#include <bcc/bcc_syms.h>
*/
import "C"

var globalCache *symbolCache

func init() {
	globalCache = newSymbolCache()
}

type bccSymbol struct {
	name         *C.char
	demangleName *C.char
	module       *C.char
	offset       C.ulonglong
}

type bccSymbolOption struct {
	useDebugFile      int
	checkDebugFileCrc int
	useSymbolType     uint32
}

const bufferLength = 40000

type symbolCache struct {
	cachePerPid map[uint64]*C.struct_bcc_symcache
}

func newSymbolCache() *symbolCache {

	return &symbolCache{
		cachePerPid: make(map[uint64]*C.struct_bcc_symcache),
	}
}

func (sc *symbolCache) cache(pid uint64) *C.struct_bcc_symcache {
	if cache, ok := sc.cachePerPid[pid]; ok {
		return cache
	}
	pidC := C.int(pid)
	if pid == 0 {
		pidC = C.int(-1)
	}
	symbolOpt := &bccSymbolOption{}
	symbolOptC := (*C.struct_bcc_symbol_option)(unsafe.Pointer(symbolOpt))
	cache := C.bcc_symcache_new(pidC, symbolOptC)
	sc.cachePerPid[pid] = (*C.struct_bcc_symcache)(cache)
	return sc.cachePerPid[pid]
}

func (sc *symbolCache) bccResolve(pid, addr uint64) (string, uint64, string) {
	symbol := &bccSymbol{}
	symbolC := (*C.struct_bcc_symbol)(unsafe.Pointer(symbol))

	// cache := C.bcc_symcache_new(pidC, symbolOptC)
	// defer C.bcc_free_symcache(cache, pidC)

	cache := sc.cache(pid)
	var res C.int
	if pid == 0 {
		res = C.bcc_symcache_resolve_no_demangle(unsafe.Pointer(cache), C.ulong(addr), symbolC)
	} else {
		res = C.bcc_symcache_resolve(unsafe.Pointer(cache), C.ulong(addr), symbolC)
		// log.Printf("res %q %q %q %d",  C.GoString(symbol.name),  C.GoString(symbol.demangleName), C.GoString(symbol.module), res)
	}

	// if res < 0 {
	// 	return "", fmt.Errorf("unable to locate symbol %x %d, %q", addr, res, symbol)
	// }

	if res < 0 {
		if symbol.offset > 0 {
			return "", uint64(symbol.offset), C.GoString(symbol.module)
		}
		return "", addr, ""
	}

	if pid == 0 {
		return C.GoString(symbol.name), uint64(symbol.offset), C.GoString(symbol.module)
	} else {
		return C.GoString(symbol.demangleName), uint64(symbol.offset), C.GoString(symbol.module)
	}
}

func (sc *symbolCache) sym(pid, addr uint64) string {
	name, _, _ := sc.bccResolve(pid, addr)
	if name == "" {
		name = "[unknown]"
	}
	return name
}
