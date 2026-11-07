// Command fakeserver is a dev server for the servers feature's tests: it
// answers HTTP on localhost's PORT (or the port of --port N), after
// -delay, or never (-never), or prints and exits (-exit), and may leave a
// child that setsid out of its terminal (-child, its pid written there).
package main

import (
	"flag"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/exec"
	"strconv"
	"syscall"
	"time"
)

func main() {
	delay := flag.Duration("delay", 0, "wait so long before listening")
	never := flag.Bool("never", false, "never listen")
	exit := flag.Int("exit", -1, "print and exit with this code")
	child := flag.String("child", "", "start a child in a session of its own, its pid written to this file")
	sleep := flag.Bool("sleep", false, "only sleep (the child)")
	port := flag.String("port", "", "the port, else PORT")
	flag.Parse()
	if *sleep {
		time.Sleep(time.Hour)
		return
	}
	fmt.Println("fakeserver starting, args", os.Args[1:], "PORT", os.Getenv("PORT"))
	if *exit >= 0 {
		fmt.Println("boom: can't start")
		os.Exit(*exit)
	}
	if *child != "" {
		cmd := exec.Command(os.Args[0], "-sleep")
		cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
		if err := cmd.Start(); err != nil {
			panic(err)
		}
		if err := os.WriteFile(*child, []byte(strconv.Itoa(cmd.Process.Pid)), 0o600); err != nil {
			panic(err)
		}
	}
	if *never {
		time.Sleep(time.Hour)
		return
	}
	time.Sleep(*delay)
	p := *port
	if p == "" {
		p = os.Getenv("PORT")
	}
	ln, err := net.Listen("tcp", "localhost:"+p)
	if err != nil {
		fmt.Println("can't listen:", err)
		os.Exit(3)
	}
	fmt.Println("listening on", p)
	_ = http.Serve(ln, http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write([]byte("ok")) })) //nolint:gosec // a test's server
}
