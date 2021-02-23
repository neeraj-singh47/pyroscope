// +build ebpfspy

// Package ebpfspy provides integration with Linux eBPF. It is a rough copy of profile.py from BCC tools:
//   https://github.com/iovisor/bcc/blob/master/tools/profile.py
package ebpfspy

import (
	"sync"

	"github.com/pyroscope-io/pyroscope/pkg/agent/spy"
)

type EbpfSpy struct {
	resetMutex sync.Mutex
	reset      bool

	profilingSession *session
}

func Start(pid int) (spy.Spy, error) {
	s := newSession()
	err := s.Start()
	if err != nil {
		return nil, err
	}
	return &EbpfSpy{
		profilingSession: s,
	}, nil
}

func (s *EbpfSpy) Stop() error {
	return nil
}

func (s *EbpfSpy) Snapshot(cb func([]byte, uint64, error)) {
	s.resetMutex.Lock()
	defer s.resetMutex.Unlock()

	if !s.reset {
		return
	}

	s.reset = false
	s.profilingSession.Reset(func(name []byte, v uint64) {
		cb(name, v, nil)
	})
}

func (s *EbpfSpy) Reset() {
	s.resetMutex.Lock()
	defer s.resetMutex.Unlock()

	s.reset = true
}

func init() {
	spy.RegisterSpy("ebpfspy", Start)
}
