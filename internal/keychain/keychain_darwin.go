package keychain

/*
#cgo LDFLAGS: -framework Security -framework CoreFoundation
#include <stdlib.h>
#include <string.h>
#include <Security/Security.h>
#include <Security/AuthSession.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static CFStringRef str(const char *s) {
	return CFStringCreateWithCString(NULL, s, kCFStringEncodingUTF8);
}

static CFMutableDictionaryRef query(const char *service, const char *account) {
	CFMutableDictionaryRef q = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	CFStringRef s = str(service), a = str(account);
	CFDictionarySetValue(q, kSecClass, kSecClassGenericPassword);
	CFDictionarySetValue(q, kSecAttrService, s);
	CFDictionarySetValue(q, kSecAttrAccount, a);
	CFRelease(s);
	CFRelease(a);
	return q;
}

// The file-based login keychain ignores kSecUseAuthenticationUIFail: only
// this process-wide switch keeps its prompt away (the Go side serializes
// calls). With it off, what would prompt fails errSecInteractionNotAllowed.
static void prompts(int on) { SecKeychainSetUserInteractionAllowed(on ? true : false); }

// kc_delete goes through the older keychain calls, as `security
// delete-generic-password` does: SecItemDelete refuses an item an earlier
// build of Nushi made (errSecInvalidOwnerEdit); finding the item without
// its data and deleting it doesn't.
static OSStatus kc_delete(const char *service, const char *account, int *call) {
	SecKeychainItemRef item = NULL;
	prompts(0);
	*call = 1;
	OSStatus st = SecKeychainFindGenericPassword(NULL, (UInt32)strlen(service), service, (UInt32)strlen(account), account, NULL, NULL, &item);
	if (st == errSecSuccess) {
		*call = 2;
		st = SecKeychainItemDelete(item);
		CFRelease(item);
	}
	prompts(1);
	return st;
}

// kc_set deletes, then adds: an update needs the old item's access, which
// an earlier build of Nushi may hold; the new item is this build's.
static OSStatus kc_set(const char *service, const char *account, const char *label, const void *secret, int n, int *call) {
	OSStatus st = kc_delete(service, account, call);
	if (st != errSecSuccess && st != errSecItemNotFound) return st;
	*call = 3;
	CFMutableDictionaryRef q = query(service, account);
	CFDataRef data = CFDataCreate(NULL, secret, n);
	CFStringRef l = str(label);
	CFDictionarySetValue(q, kSecAttrLabel, l);
	CFDictionarySetValue(q, kSecValueData, data);
	prompts(0);
	st = SecItemAdd(q, NULL);
	prompts(1);
	CFRelease(l);
	CFRelease(data);
	CFRelease(q);
	return st;
}

// kc_get copies the secret into a buffer the caller frees.
static OSStatus kc_get(const char *service, const char *account, int ui, void **out, int *n, int *call) {
	*call = 4;
	CFMutableDictionaryRef q = query(service, account);
	CFDictionarySetValue(q, kSecReturnData, kCFBooleanTrue);
	CFDictionarySetValue(q, kSecMatchLimit, kSecMatchLimitOne);
	CFTypeRef res = NULL;
	prompts(ui);
	OSStatus st = SecItemCopyMatching(q, &res);
	prompts(1);
	CFRelease(q);
	if (st != errSecSuccess) return st;
	CFDataRef data = (CFDataRef)res;
	*n = (int)CFDataGetLength(data);
	*out = malloc(*n > 0 ? *n : 1);
	memcpy(*out, CFDataGetBytePtr(data), *n);
	CFRelease(res);
	return st;
}

// kc_gui says this process's security session can show macOS's prompts
// (the user's login session, not SSH's or a launchd job's before login).
static int kc_gui(void) {
	SecuritySessionId id = 0;
	SessionAttributeBits attrs = 0;
	if (SessionGetInfo(callerSecuritySession, &id, &attrs) != errSecSuccess) return 1; // can't tell: assume it can
	return (attrs & sessionHasGraphicAccess) != 0;
}

// kc_default is SecKeychainCopyDefault's status: whether there is a login
// keychain this process can find.
static OSStatus kc_default(void) {
	SecKeychainRef k = NULL;
	OSStatus st = SecKeychainCopyDefault(&k);
	if (k) CFRelease(k);
	return st;
}
*/
import "C"

import (
	"cmp"
	"context"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"sync"
	"syscall"
	"unsafe"
)

// noKeychain is ErrNoKeychain's text on the Mac.
const noKeychain = "macOS can't find your login keychain: check it in Keychain Access (File › Keychain List), then restart the daemon"

// calls are the Security calls the C side reports by number.
var calls = map[C.int]string{1: "SecKeychainFindGenericPassword", 2: "SecKeychainItemDelete", 3: "SecItemAdd", 4: "SecItemCopyMatching"}

// mu serializes calls: the prompt switch is the process's.
var mu sync.Mutex

// Set stores secret for account, replacing what was there; label is what
// Keychain Access shows. It never prompts. It checks first that there is
// a keychain to add to, since it deletes the old item before adding.
func (k Keychain) Set(account, label string, secret []byte) error {
	if st := C.kc_default(); st != C.errSecSuccess {
		return k.failed("SecKeychainCopyDefault", st)
	}
	s, a, l := C.CString(k.Service), C.CString(account), C.CString(label)
	defer free(s, a, l)
	p := C.CBytes(secret)
	defer func() {
		clear(unsafe.Slice((*byte)(p), len(secret)))
		C.free(p)
	}()
	var call C.int
	mu.Lock()
	defer mu.Unlock()
	if st := C.kc_set(s, a, l, p, C.int(len(secret)), &call); st != C.errSecSuccess {
		return k.failed(calls[call], st)
	}
	return nil
}

// Get reads account's secret. With prompt, macOS may ask the user first
// (and Get waits for the answer); without, that fails with ErrNeedsOK.
// A process macOS can't ask for the user's OK (ErrRestart) doesn't try:
// what the user allowed would be another program's.
func (k Keychain) Get(account string, prompt bool) ([]byte, error) {
	if prompt {
		if why := cantAsk(); why != "" {
			slog.Warn("keychain prompt not tried", "service", k.Service, "why", why)
			return nil, &Error{Call: "SecItemCopyMatching", Kind: ErrRestart, Why: why}
		}
	}
	s, a := C.CString(k.Service), C.CString(account)
	defer free(s, a)
	ui := C.int(0)
	if prompt {
		ui = 1
	}
	var out unsafe.Pointer
	var n, call C.int
	mu.Lock()
	st := C.kc_get(s, a, ui, &out, &n, &call)
	mu.Unlock()
	if st != C.errSecSuccess {
		return nil, k.failed(calls[call], st)
	}
	b := C.GoBytes(out, n)
	clear(unsafe.Slice((*byte)(out), int(n)))
	C.free(out)
	return b, nil
}

// Delete removes account's item; a missing one is no error. It never
// prompts.
func (k Keychain) Delete(account string) error {
	s, a := C.CString(k.Service), C.CString(account)
	defer free(s, a)
	var call C.int
	mu.Lock()
	defer mu.Unlock()
	if st := C.kc_delete(s, a, &call); st != C.errSecSuccess && st != C.errSecItemNotFound {
		return k.failed(calls[call], st)
	}
	return nil
}

func free(ps ...*C.char) {
	for _, p := range ps {
		C.free(unsafe.Pointer(p))
	}
}

// failed is a call's failure, logged with its status (never an account
// or a secret).
func (k Keychain) failed(call string, st C.OSStatus) error {
	e := &Error{Call: call, Status: int(st), Msg: message(st), Kind: kind(int(st))}
	if errors.Is(e.Kind, ErrRestart) {
		e.Why = cmp.Or(cantAsk(), "macOS can't find the daemon's program")
	}
	level := slog.LevelWarn
	switch {
	case errors.Is(e.Kind, ErrNotFound):
		level = slog.LevelDebug
	case errors.Is(e.Kind, ErrNeedsOK):
		level = slog.LevelInfo // after every new build
	}
	slog.Log(context.Background(), level, "keychain call failed", "service", k.Service, "call", call, "status", e.Status, "msg", e.Msg,
		"kind", kindName(e.Kind), "why", e.Why)
	return e
}

// kind says what a status means here. One the user's OK would cure is
// ErrRestart instead when this process can't ask for it; errno ENOENT
// (100002, UNIX[No such file or directory]) is what an OK asked for by a
// process whose program was removed meets.
func kind(status int) error {
	switch st := C.OSStatus(status); st {
	case C.errSecItemNotFound:
		if !hasKeychain() {
			return ErrNoKeychain // nothing is found without a keychain
		}
		return ErrNotFound
	case C.errSecInteractionNotAllowed, C.errSecAuthFailed, C.errSecUserCanceled:
		if asking() != "" {
			return ErrRestart
		}
		return ErrNeedsOK
	case errnoBase + C.OSStatus(syscall.ENOENT):
		if !hasKeychain() {
			return ErrNoKeychain
		}
		return ErrRestart
	case C.errSecNoDefaultKeychain, C.errSecNoSuchKeychain, C.errSecNotAvailable:
		return ErrNoKeychain
	}
	return nil
}

// hasKeychain says there is a login keychain this process can find, and
// asking says why it can't ask for the user's OK (cantAsk): kind's two
// looks at the machine, which a test replaces so that it never asks the
// real keychain.
var (
	hasKeychain = func() bool { return C.kc_default() == C.errSecSuccess }
	asking      = cantAsk
)

// errnoBase is where the Security framework's statuses for a Unix errno
// start (errSecErrnoBase): 100000 + errno.
const errnoBase = 100000

func message(st C.OSStatus) string {
	msg := C.SecCopyErrorMessageString(st, nil)
	if msg == 0 {
		return fmt.Sprintf("OSStatus %d", int(st))
	}
	defer C.CFRelease(C.CFTypeRef(msg))
	var buf [256]C.char
	C.CFStringGetCString(msg, &buf[0], C.CFIndex(len(buf)), C.kCFStringEncodingUTF8)
	return C.GoString(&buf[0])
}

// started is this process's program as it was when it started.
var started = program()

func program() os.FileInfo {
	exe, err := os.Executable()
	if err != nil {
		return nil
	}
	fi, _ := os.Stat(exe)
	return fi
}

// cantAsk says why macOS can't ask the user about this process's access
// to the keychain, "" when it can: its program was removed or replaced
// since it started (macOS then fails the prompt, or names another
// program in it), or its session has no screen to ask on.
func cantAsk() string {
	if now := program(); started != nil && (now == nil || !os.SameFile(started, now)) {
		return "it was started from a build of Nushi that has been replaced or removed since (an install while it ran)"
	}
	if C.kc_gui() == 0 {
		return "it runs outside your login session (started over SSH, or by launchd before you logged in)"
	}
	return ""
}
