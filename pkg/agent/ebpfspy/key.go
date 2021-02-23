// +build ebpfspy

// Package ebpfspy provides integration with Linux eBPF. It is a rough copy of profile.py from BCC tools:
//   https://github.com/iovisor/bcc/blob/master/tools/profile.py
package ebpfspy

import (
	"bytes"
	"encoding/binary"
)

type Key struct {
	pid             uint32
	kernel_ip       uint64
	kernel_ret_ip   uint64
	user_stack_id   int64
	kernel_stack_id int64
	name            []byte
}

func Unpack(b []byte) *Key {
	buf := bytes.NewBuffer(b)
	g := Key{}
	binary.Read(buf, binary.LittleEndian, &g.pid)
	binary.Read(buf, binary.LittleEndian, &g.kernel_ip)
	binary.Read(buf, binary.LittleEndian, &g.kernel_ret_ip)
	binary.Read(buf, binary.LittleEndian, &g.user_stack_id)
	binary.Read(buf, binary.LittleEndian, &g.kernel_stack_id)
	return &g
}

type KeyBytes struct {
	pid             []byte
	kernel_ip       []byte
	kernel_ret_ip   []byte
	user_stack_id   []byte
	kernel_stack_id []byte
	name            []byte
}

func UnpackKeyBytes(b []byte) *KeyBytes {
	g := KeyBytes{}
	g.pid = b[:8]                // 4
	g.kernel_ip = b[8:16]        // 8
	g.kernel_ret_ip = b[16:24]   // 8
	g.user_stack_id = b[24:28]   // 4
	g.kernel_stack_id = b[28:32] // 4
	g.name = b[32:]              // 8
	i := bytes.Index(g.name, []byte{0})
	if i >= 0 {
		g.name = g.name[:i]
	}
	return &g
}
