// Package keychain keeps secrets as generic passwords in the user's login
// keychain, through the Security framework (cgo): the secret goes to and
// from the framework in this process's memory only, never through a
// command line, a file or another process. An item's access list is the
// one macOS gives it: the program that made it. Another program (an agent
// running `security find-generic-password -w`, or the next build of Nushi,
// which ad-hoc signing makes a new program) gets macOS's prompt.
package keychain

/*
#cgo LDFLAGS: -framework Security -framework CoreFoundation
#include <stdlib.h>
#include <string.h>
#include <Security/Security.h>

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
static OSStatus kc_delete(const char *service, const char *account) {
	SecKeychainItemRef item = NULL;
	prompts(0);
	OSStatus st = SecKeychainFindGenericPassword(NULL, (UInt32)strlen(service), service, (UInt32)strlen(account), account, NULL, NULL, &item);
	if (st == errSecSuccess) {
		st = SecKeychainItemDelete(item);
		CFRelease(item);
	}
	prompts(1);
	return st;
}

// kc_set deletes, then adds: an update needs the old item's access, which
// an earlier build of Nushi may hold; the new item is this build's.
static OSStatus kc_set(const char *service, const char *account, const char *label, const void *secret, int n) {
	OSStatus st = kc_delete(service, account);
	if (st != errSecSuccess && st != errSecItemNotFound) return st;
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
static OSStatus kc_get(const char *service, const char *account, int ui, void **out, int *n) {
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
*/
import "C"

import (
	"errors"
	"fmt"
	"sync"
	"unsafe"
)

var (
	// ErrNotFound is a missing item.
	ErrNotFound = errors.New("not in the keychain")
	// ErrNeedsOK is an item this program may read only once the user says
	// so in macOS's prompt, read without the prompt; or the user said no.
	ErrNeedsOK = errors.New("the keychain needs your OK to read it")
)

// mu serializes calls: the prompt switch is the process's.
var mu sync.Mutex

// Keychain is the items of one service.
type Keychain struct {
	Service string
}

// Set stores secret for account, replacing what was there; label is what
// Keychain Access shows. It never prompts.
func (k Keychain) Set(account, label string, secret []byte) error {
	s, a, l := C.CString(k.Service), C.CString(account), C.CString(label)
	defer free(s, a, l)
	p := C.CBytes(secret)
	defer func() {
		clear(unsafe.Slice((*byte)(p), len(secret)))
		C.free(p)
	}()
	mu.Lock()
	defer mu.Unlock()
	return status(C.kc_set(s, a, l, p, C.int(len(secret))))
}

// Get reads account's secret. With prompt, macOS may ask the user first
// (and Get waits for the answer); without, that fails with ErrNeedsOK.
func (k Keychain) Get(account string, prompt bool) ([]byte, error) {
	s, a := C.CString(k.Service), C.CString(account)
	defer free(s, a)
	ui := C.int(0)
	if prompt {
		ui = 1
	}
	var out unsafe.Pointer
	var n C.int
	mu.Lock()
	err := status(C.kc_get(s, a, ui, &out, &n))
	mu.Unlock()
	if err != nil {
		return nil, err
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
	mu.Lock()
	defer mu.Unlock()
	if err := status(C.kc_delete(s, a)); err != nil && !errors.Is(err, ErrNotFound) {
		return err
	}
	return nil
}

func free(ps ...*C.char) {
	for _, p := range ps {
		C.free(unsafe.Pointer(p))
	}
}

func status(st C.OSStatus) error {
	switch st {
	case C.errSecSuccess:
		return nil
	case C.errSecItemNotFound:
		return ErrNotFound
	case C.errSecInteractionNotAllowed, C.errSecAuthFailed, C.errSecUserCanceled:
		return ErrNeedsOK
	}
	msg := C.SecCopyErrorMessageString(st, nil)
	if msg == 0 {
		return fmt.Errorf("keychain: OSStatus %d", int(st))
	}
	defer C.CFRelease(C.CFTypeRef(msg))
	var buf [256]C.char
	C.CFStringGetCString(msg, &buf[0], C.CFIndex(len(buf)), C.kCFStringEncodingUTF8)
	return fmt.Errorf("keychain: %s (%d)", C.GoString(&buf[0]), int(st))
}
